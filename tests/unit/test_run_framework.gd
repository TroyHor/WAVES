extends TestCase
## Run nodes, rewards, run effects and relic hooks.


## Test-only relic: heals 1 after each resolve and counts every hook call.
class CounterRelic extends Relic:
	var calls := {}

	func _hit(name: String) -> void:
		calls[name] = int(calls.get(name, 0)) + 1

	func on_combat_start(_combat: Combat) -> void:
		_hit("combat_start")

	func on_turn_start(_combat: Combat) -> void:
		_hit("turn_start")

	func modify_result(_combat: Combat, result: TrackResult) -> void:
		_hit("modify")
		# Doubles every hit on the enemy.
		for t in result.damage.size():
			if result.outcome[t] == TrackResult.Outcome.ENEMY_HIT:
				result.damage[t] *= 2
		result.recount()

	func after_resolve(combat: Combat, _report: TurnReport) -> void:
		_hit("after")
		combat.player_hp += 1


func _run_with(nodes: Array, p_seed := 11) -> RunState:
	var db := GameDatabase.load_default()
	var errors := PackedStringArray()
	db.run_nodes = GameDatabase.parse_run({"nodes": nodes}, errors)
	assert_eq(errors.size(), 0, "\n".join(errors))
	db.run_order.clear()
	for n in db.run_nodes:
		if n.kind == RunNodeData.FIGHT:
			db.run_order.append(n.encounter)
	return RunState.new_run(db, RulesConfig.load_file(), p_seed)


func _win(run: RunState, hp: int) -> void:
	var c := run.make_combat(GameDatabase.load_default(), RulesConfig.load_file())
	c.player_hp = hp
	c.outcome = Combat.Outcome.WON
	run.complete_combat(c)


# --- run.json ----------------------------------------------------------------

func test_legacy_encounter_list_becomes_fight_nodes() -> void:
	var errors := PackedStringArray()
	var nodes := GameDatabase.parse_run({"encounters": ["01_drone", "04_twins"]}, errors)
	assert_eq(errors.size(), 0)
	assert_eq(nodes.size(), 2)
	assert_eq(nodes[1].kind, RunNodeData.FIGHT)
	assert_eq(nodes[1].encounter, "04_twins")


func test_shipped_run_has_same_fights_as_before() -> void:
	var db := GameDatabase.load_default()
	assert_eq(Array(db.run_order), ["01_drone", "02_shrieker", "03_tide_colossus", "04_twins"])


func test_bad_nodes_are_reported() -> void:
	var errors := PackedStringArray()
	GameDatabase.parse_run({"nodes": [{"type": "shop"}, {"type": "fight"}, {"type": "event"},
		{"type": "reward", "size": 0}, 5]}, errors)
	assert_eq(errors.size(), 5, "\n".join(errors))
	var db := GameDatabase.load_default()
	db.run_nodes = GameDatabase.parse_run({"nodes": [{"type": "fight", "encounter": "ghost"},
		{"type": "reward", "pool": ["nope"]}, {"type": "rest", "effects": [{"type": "warp"}]}]}, errors)
	db.errors.clear()
	db._validate_refs()
	assert_eq(db.errors.size(), 3, "\n".join(db.errors))


# --- node flow ---------------------------------------------------------------

func test_run_walks_mixed_nodes_in_order() -> void:
	var run := _run_with([{"type": "fight", "encounter": "01_drone"}, {"type": "reward"},
		{"type": "rest"}, {"type": "event", "event": "e1"}, {"type": "fight", "encounter": "02_shrieker"}])
	assert_eq(run.current_kind(), "fight")
	_win(run, 40)
	assert_eq(run.current_kind(), "reward")
	assert_eq(run.index, 1)
	assert_eq(run.current_encounter_id(), "02_shrieker", "next fight ahead")
	var offer := run.make_reward_offer(GameDatabase.load_default(), RulesConfig.load_file())
	assert_true(run.skip_reward(offer))
	assert_eq(run.current_kind(), "rest")
	assert_false(run.complete_event(), "wrong node kind is refused")
	assert_true(run.complete_rest())
	assert_eq(run.player_hp, 40, "empty rest is a no-op")
	assert_true(run.complete_event())
	assert_eq(run.current_kind(), "fight")
	_win(run, 30)
	assert_true(run.is_won())
	assert_eq(run.current_kind(), "")


func test_rest_applies_its_effects() -> void:
	var run := _run_with([{"type": "rest", "effects": [{"type": "hp", "amount": -100}]},
		{"type": "fight", "encounter": "01_drone"}])
	assert_true(run.complete_rest())
	assert_true(run.lost, "dropping to 0 HP outside a fight ends the run")
	assert_eq(run.current_kind(), "")


func test_run_effects() -> void:
	var run := _run_with([{"type": "fight", "encounter": "01_drone"}])
	var before := run.deck_ids.size()
	run.player_hp = 50
	var fx: Array[Dictionary] = [{"type": "hp", "amount": 30}, {"type": "max_hp", "amount": -20},
		{"type": "add_card", "card": "spike"}, {"type": "remove_card", "card": "pulse"},
		{"type": "add_relic", "relic": "r1"}]
	RunEffects.apply(run, fx)
	assert_eq(run.player_max_hp, 40)
	assert_eq(run.player_hp, 40, "heal is capped, then clamped to the new max")
	assert_eq(run.deck_ids.size(), before)
	assert_true(run.deck_ids.has("spike"))
	assert_eq(Array(run.relic_ids), ["r1"])
	assert_eq(RunEffects.validate(fx, GameDatabase.load_default()).size(), 0)


# --- rewards -----------------------------------------------------------------

func test_card_offer_is_distinct_reproducible_and_weighted() -> void:
	var db := GameDatabase.load_default()
	var pool := db.sorted_cards()
	var a := Rewards.card_offer(pool, 3, 42)
	var b := Rewards.card_offer(pool, 3, 42)
	assert_eq(a.size(), 3)
	assert_eq(a, b, "same seed, same offer")
	assert_true(a[0] != a[1] and a[1] != a[2] and a[0] != a[2], "no duplicates")
	assert_eq(Rewards.card_offer(pool.slice(0, 2), 5, 1).size(), 2, "offer never exceeds the pool")
	var zero := CardData.new()
	zero.id = "zero"
	zero.reward_weight = 0.0
	var only: Array[CardData] = [zero, pool[0]]
	for s in 20:
		assert_eq(Rewards.card_offer(only, 2, s), [pool[0]], "weight 0 is never offered")


func test_reward_node_offer_and_choice() -> void:
	var run := _run_with([{"type": "reward"}, {"type": "reward", "size": 1, "pool": ["spike"]},
		{"type": "fight", "encounter": "01_drone"}])
	var db := GameDatabase.load_default()
	var rules := RulesConfig.load_file()
	var offer := run.make_reward_offer(db, rules)
	assert_eq(offer.cards.size(), rules.reward_offer_size)
	assert_eq(run.make_reward_offer(db, rules).cards, offer.cards, "re-asking gives the same offer")
	assert_false(run.choose_reward(offer, 99))
	var picked := offer.cards[1].id
	assert_true(run.choose_reward(offer, 1))
	assert_eq(run.deck_ids[run.deck_ids.size() - 1], picked)
	offer = run.make_reward_offer(db, rules)
	assert_eq(offer.cards.size(), 1)
	assert_eq(offer.cards[0].id, "spike", "node pool and size override the rules")
	rules.reward_allow_skip = false
	assert_false(run.skip_reward(run.make_reward_offer(db, rules)))
	assert_true(run.choose_reward(offer, 0))
	var c := run.make_combat(db, rules)
	assert_eq(c.deck.total_cards(), db.starter_deck.size() + 2, "rewards end up in the next fight's deck")


func test_reward_offers_depend_on_seed() -> void:
	var nodes := [{"type": "reward", "size": 4}, {"type": "fight", "encounter": "01_drone"}]
	var db := GameDatabase.load_default()
	var rules := RulesConfig.load_file()
	var seen := {}
	for s in 8:
		var ids := []
		for c in _run_with(nodes, s).make_reward_offer(db, rules).cards:
			ids.append(c.id)
		seen[str(ids)] = true
	assert_true(seen.size() > 1, "different run seeds give different offers")


func test_fight_seed_is_unchanged() -> void:
	var run := _run_with([{"type": "fight", "encounter": "01_drone"}], 5)
	assert_eq(run.node_seed(), 5, "first fight keeps seed + 0 * 7919")


# --- relics ------------------------------------------------------------------

func test_relic_hooks_fire_in_order_and_preview_matches() -> void:
	RelicRegistry.register("test_counter", func() -> Relic: return CounterRelic.new())
	var run := _run_with([{"type": "fight", "encounter": "01_drone"}])
	run.relic_ids.append("test_counter")
	var db := GameDatabase.load_default()
	var c := run.make_combat(db, RulesConfig.load_file())
	RelicRegistry.unregister("test_counter")
	assert_eq(c.relics.size(), 1)
	var relic: CounterRelic = c.relics[0]
	assert_eq(relic.id, "test_counter")
	c.start()
	assert_eq(relic.calls.get("combat_start"), 1)
	assert_eq(relic.calls.get("turn_start"), 1)

	# Put a wave into an empty cell so the doubling is visible.
	var card: CardInstance = null
	for h in c.deck.hand:
		if h.data.is_wave_card() and h.data.cost <= c.energy:
			card = h
			break
	var empty := -1
	var e := c.enemy_track()
	for t in e.size():
		if e[t] == 0:
			empty = t
			break
	assert_true(card != null and empty >= 0, "seed gives a playable card and an empty cell")
	if card == null or empty < 0:
		return
	c.play(card, empty)
	var raw := Resolver.resolve(c.enemy_track(), c.placements(), c.rules)
	var pv := c.preview()
	assert_true(pv.to_enemy > raw.to_enemy, "modify_result shows up in the preview")
	var hp_before := c.player_hp
	var enemy_before := c.front_enemy().hp
	var report := c.resolve_turn()
	assert_eq(report.result.to_enemy, pv.to_enemy, "resolution matches the preview")
	assert_eq(enemy_before - c.enemies[0].hp, mini(enemy_before, pv.to_enemy))
	assert_eq(c.player_hp, maxi(0, hp_before - pv.to_player) + 1, "after_resolve heal applied")
	assert_eq(relic.calls.get("after"), 1)


func test_unknown_relic_is_skipped() -> void:
	assert_false(RelicRegistry.has("ghost"))
	assert_eq(RelicRegistry.create_all(PackedStringArray()).size(), 0)
