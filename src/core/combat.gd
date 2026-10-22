class_name Combat
extends RefCounted
## One fight, independent of any UI. The UI calls these methods and re-reads
## state afterwards; preview() and resolve_turn() share the same Resolver path.

enum Outcome { ONGOING, WON, LOST }

var rules: RulesConfig
var rng := RandomNumberGenerator.new()
var deck: Deck
## Front enemy first. Dead enemies stay in the list but are skipped.
var enemies: Array[EnemyState] = []
var played: Array[PlayedCard] = []
var player_hp := 0
var player_max_hp := 0
var energy := 0
var turn := 0
var swap_interval := 0
var swap_countdown := 0
var outcome := Outcome.ONGOING
## Active relics (see Relic for the hook order). Set before start().
var relics: Array[Relic] = []


func _init(p_rules: RulesConfig, cards: Array[CardData], enemy_defs: Array[EnemyData], seed_value: int, p_swap_interval := 0, starting_hp := -1) -> void:
	rules = p_rules
	rng.seed = seed_value
	player_max_hp = rules.player_max_hp
	player_hp = player_max_hp if starting_hp < 0 else starting_hp
	var instances: Array[CardInstance] = []
	for c in cards:
		instances.append(CardInstance.new(c))
	deck = Deck.new(instances, rng)
	for e in enemy_defs:
		enemies.append(EnemyState.new(e))
	swap_interval = p_swap_interval
	swap_countdown = swap_interval


static func from_encounter(db: GameDatabase, encounter_id: String, seed_value: int, p_rules: RulesConfig, starting_hp := -1) -> Combat:
	var enc := db.encounter(encounter_id)
	return Combat.new(p_rules, db.starter_cards(), db.encounter_enemies(enc), seed_value, enc.swap_interval, starting_hp)


func start() -> void:
	for r in relics:
		r.on_combat_start(self)
	_begin_turn()


# --- Queries ---------------------------------------------------------------

func alive_enemies() -> Array[EnemyState]:
	var out: Array[EnemyState] = []
	for e in enemies:
		if e.is_alive():
			out.append(e)
	return out


func front_enemy() -> EnemyState:
	for e in enemies:
		if e.is_alive():
			return e
	return null


## Combined intent of all living enemies (twins interfere with each other here).
func enemy_track() -> PackedInt32Array:
	var track := WaveMath.empty_track(rules.track_length)
	for e in alive_enemies():
		track = WaveMath.add(track, e.intent)
	return track


func find_played(card: CardInstance) -> PlayedCard:
	for p in played:
		if p.card == card:
			return p
	return null


func can_play(card: CardInstance) -> bool:
	return outcome == Outcome.ONGOING and card in deck.hand and card.data.cost <= energy


func can_place_at(card: CardInstance, offset: int) -> bool:
	if rules.offtrack_mode == WaveMath.OFFTRACK_FORBID:
		return WaveMath.fits(card.data.wave, offset, rules.track_length)
	return true


func can_unplay(card: CardInstance) -> bool:
	# Cards with immediate effects (draw) are committed once played.
	return rules.allow_reposition_before_resolve and find_played(card) != null and not card.data.has_effect("draw")


## All placements on the track, optionally with a hypothetical extra card
## (used while dragging a card from hand, before it is actually played).
func placements(extra: PlayedCard = null) -> Array[WavePlacement]:
	var out: Array[WavePlacement] = []
	for p in played:
		out.append_array(p.placements())
	if extra != null:
		out.append_array(extra.placements())
	return out


func preview(extra: PlayedCard = null) -> TrackResult:
	var result := Resolver.resolve(enemy_track(), placements(extra), rules)
	for r in relics:
		r.modify_result(self, result)
	return result


## Turns until the twins swap (0 when no swapping applies).
func swap_in() -> int:
	return swap_countdown if swap_interval > 0 and alive_enemies().size() > 1 else 0


# --- Actions ---------------------------------------------------------------

func play(card: CardInstance, offset := 0, flipped := false) -> bool:
	if not can_play(card):
		return false
	if card.data.is_wave_card() and not can_place_at(card, offset):
		return false
	deck.hand.erase(card)
	energy -= card.data.cost
	if card.data.is_wave_card():
		played.append(PlayedCard.new(card, offset, flipped and card.data.has_keyword("flippable")))
	else:
		deck.discard_pile.append(card)
	if card.data.has_effect("draw"):
		deck.draw(card.data.effect_value("draw", "amount"), rules.max_hand_size)
	return true


func move_card(card: CardInstance, offset: int) -> bool:
	var p := find_played(card)
	if p == null or not rules.allow_reposition_before_resolve or not can_place_at(card, offset):
		return false
	p.offset = offset
	return true


func set_flipped(card: CardInstance, flipped: bool) -> bool:
	var p := find_played(card)
	if p == null or not card.data.has_keyword("flippable"):
		return false
	p.flipped = flipped
	return true


func unplay(card: CardInstance) -> bool:
	if not can_unplay(card):
		return false
	played.erase(find_played(card))
	deck.hand.append(card)
	energy += card.data.cost
	return true


func resolve_turn() -> TurnReport:
	var report := TurnReport.new()
	report.result = preview()
	report.target = front_enemy()
	report.player_hp_before = player_hp
	report.target_hp_before = report.target.hp

	player_hp = maxi(0, player_hp - report.result.to_player)
	# Overkill is wasted: it never carries over to the enemy behind.
	report.target.hp = maxi(0, report.target.hp - report.result.to_enemy)
	for r in relics:
		r.after_resolve(self, report)
	report.killed = not report.target.is_alive()

	var player_dead := player_hp <= 0
	var all_dead := alive_enemies().is_empty()
	if player_dead and (not all_dead or rules.simultaneous_death_is_loss):
		outcome = Outcome.LOST
	elif all_dead:
		outcome = Outcome.WON

	if outcome == Outcome.ONGOING:
		report.swapped = _end_turn()
		_begin_turn()
	report.outcome = outcome
	return report


# --- Turn flow -------------------------------------------------------------

func _begin_turn() -> void:
	turn += 1
	energy = rules.energy_per_turn
	deck.draw(rules.hand_size, rules.max_hand_size)
	for e in alive_enemies():
		e.roll_intent(rng, rules.track_length)
	for r in relics:
		r.on_turn_start(self)


## Returns true if the enemies swapped front/back.
func _end_turn() -> bool:
	for p in played:
		deck.discard_pile.append(p.card)
	played.clear()
	deck.discard_hand()
	if swap_interval <= 0 or alive_enemies().size() < 2:
		return false
	swap_countdown -= 1
	if swap_countdown > 0:
		return false
	swap_countdown = swap_interval
	enemies.reverse()
	return true
