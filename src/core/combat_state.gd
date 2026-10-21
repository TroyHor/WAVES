class_name CombatState
extends RefCounted
## One combat, fully playable without any UI. The UI calls these methods and
## renders the state; previews go through preview(), which uses the same
## Resolver as end_turn().

enum Status { ONGOING, WON, LOST }

var rules: RulesConfig
var rng := RandomNumberGenerator.new()
var deck: Deck
var enemies: Array[EnemyState] = []
var played: Array[PlayedCard] = []
var player_hp := 0
var player_max_hp := 0
var energy := 0
var turn := 0
var status := Status.ONGOING
var _next_uid := 1


## `deck_cards` is the player's deck; `player_hp` carries over between combats.
func _init(p_rules: RulesConfig, deck_cards: Array[CardData], enemy_defs: Array[EnemyData], p_player_hp: int, p_seed := 0) -> void:
	rules = p_rules
	rng.seed = p_seed
	player_max_hp = rules.player_max_hp
	player_hp = p_player_hp
	var instances: Array[CardInstance] = []
	for c in deck_cards:
		instances.append(CardInstance.new(_next_uid, c))
		_next_uid += 1
	deck = Deck.new(instances, rng)
	var lane := 0
	for e in enemy_defs:
		enemies.append(EnemyState.new(e, lane))
		lane += e.lanes


func start() -> void:
	_start_turn()


func lane_count() -> int:
	var n := 0
	for e in enemies:
		n += e.data.lanes
	return n


func enemy_for_lane(lane: int) -> EnemyState:
	for e in enemies:
		if e.owns_lane(lane):
			return e
	return null


## A lane is open while its enemy is alive.
func is_lane_open(lane: int) -> bool:
	var e := enemy_for_lane(lane)
	return e != null and e.is_alive()


## Current enemy intent per lane (dead enemies' lanes are silent).
func enemy_lanes() -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	for e in enemies:
		for i in e.data.lanes:
			out.append(e.intent[i] if e.is_alive() and i < e.intent.size() else WaveMath.empty_track(rules.track_length))
	return out


func can_afford(card: CardInstance) -> bool:
	return status == Status.ONGOING and deck.hand.has(card) and energy >= card.data.cost


## True if `card` may be placed at (lane, offset).
func can_place(card: CardInstance, lane: int, offset: int) -> bool:
	if not card.data.has_wave():
		return true
	if not is_lane_open(lane):
		return false
	if rules.offtrack_mode == WaveMath.OFFTRACK_FORBID:
		var probe := PlayedCard.new(card, lane, offset)
		for p in probe.placements():
			if p.lane < lane_count() and not WaveMath.fits(p.wave, p.offset, rules.track_length):
				return false
	return true


## Plays a card from hand. Non-wave cards ignore lane/offset. Returns null if illegal.
func play(card: CardInstance, lane := 0, offset := 0, inverted := false) -> PlayedCard:
	if not can_afford(card) or not can_place(card, lane, offset):
		return null
	energy -= card.data.cost
	deck.hand.erase(card)
	var pc := PlayedCard.new(card, lane, offset, inverted and card.data.flippable)
	if card.data.has_wave():
		played.append(pc)
	else:
		deck.discard_pile.append(card)
	_apply_on_play(card)
	return pc


func can_reposition(pc: PlayedCard) -> bool:
	return status == Status.ONGOING and rules.allow_reposition_before_resolve and played.has(pc)


func move(pc: PlayedCard, lane: int, offset: int) -> bool:
	if not can_reposition(pc) or not can_place(pc.card, lane, offset):
		return false
	pc.lane = lane
	pc.offset = offset
	return true


func set_inverted(pc: PlayedCard, value: bool) -> bool:
	if not can_reposition(pc) or not pc.card.data.flippable:
		return false
	pc.inverted = value
	return true


func can_retract(pc: PlayedCard) -> bool:
	return can_reposition(pc) and pc.card.data.is_retractable()


## Takes a placed card back into the hand and refunds its energy.
func retract(pc: PlayedCard) -> bool:
	if not can_retract(pc):
		return false
	played.erase(pc)
	deck.hand.append(pc.card)
	energy += pc.card.data.cost
	return true


## Resolves the current placements (plus an optional not-yet-played ghost) without changing state.
func preview(ghost: PlayedCard = null) -> Resolution:
	var placements: Array[WavePlacement] = []
	for pc in played:
		placements.append_array(pc.placements())
	if ghost:
		placements.append_array(ghost.placements())
	return Resolver.resolve(enemy_lanes(), placements, rules)


## Per-enemy damage implied by a resolution.
func damage_by_enemy(res: Resolution) -> Array[int]:
	var out: Array[int] = []
	for e in enemies:
		var dmg := 0
		if e.is_alive():
			for i in e.data.lanes:
				dmg += res.to_lane(e.first_lane + i)
		out.append(dmg)
	return out


func end_turn() -> TurnReport:
	var report := TurnReport.new()
	report.turn = turn
	if status != Status.ONGOING:
		report.status = status
		return report
	var res := preview()
	report.resolution = res
	report.damage_to_player = res.to_player
	report.damage_to_enemies = damage_by_enemy(res)
	player_hp = maxi(player_hp - res.to_player, 0)
	for i in enemies.size():
		enemies[i].hp = maxi(enemies[i].hp - report.damage_to_enemies[i], 0)
	for pc in played:
		deck.discard_pile.append(pc.card)
	played.clear()
	deck.discard_hand()

	var all_dead := true
	for e in enemies:
		all_dead = all_dead and not e.is_alive()
	if player_hp <= 0 and (rules.simultaneous_death_is_loss or not all_dead):
		status = Status.LOST
	elif all_dead:
		status = Status.WON
	else:
		_start_turn()
	report.status = status
	return report


func _start_turn() -> void:
	turn += 1
	energy = rules.energy_per_turn
	for e in enemies:
		if e.is_alive():
			e.roll_intent(rng, rules.track_length)
	deck.draw(rules.hand_size, rules.max_hand_size)


func _apply_on_play(card: CardInstance) -> void:
	for effect in card.data.on_play:
		match effect.get("type"):
			"draw":
				deck.draw(int(effect.get("amount", 1)), rules.max_hand_size)
