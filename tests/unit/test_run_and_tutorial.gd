extends TestCase


func test_run_follows_order_and_carries_hp() -> void:
	var db := GameDatabase.load_default()
	var rules := RulesConfig.load_file()
	var run := RunState.new_run(db, rules, 5)
	assert_eq(run.current_encounter_id(), db.run_order[0])
	var c := run.make_combat(db, rules)
	c.start()
	c.player_hp = 37
	c.outcome = Combat.Outcome.WON
	run.complete_combat(c)
	assert_eq(run.index, 1)
	assert_eq(run.player_hp, 37)
	var next := run.make_combat(db, rules)
	assert_eq(next.player_hp, 37, "HP carries into the next fight")
	assert_eq(next.player_max_hp, rules.player_max_hp)


func test_run_loss_and_win() -> void:
	var db := GameDatabase.load_default()
	var rules := RulesConfig.load_file()
	var run := RunState.new_run(db, rules, 1)
	var c := run.make_combat(db, rules)
	c.outcome = Combat.Outcome.LOST
	run.complete_combat(c)
	assert_true(run.lost)
	assert_true(run.is_over())
	assert_false(run.is_won())

	run = RunState.new_run(db, rules, 1)
	for i in run.encounter_ids.size():
		var w := run.make_combat(db, rules)
		w.outcome = Combat.Outcome.WON
		run.complete_combat(w)
	assert_true(run.is_won())


func test_bot_can_play_the_whole_run() -> void:
	var db := GameDatabase.load_default()
	var rules := RulesConfig.load_file()
	var bot = load("res://tests/unit/test_combat.gd").new()
	var run := RunState.new_run(db, rules, 99)
	var guard := 0
	while not run.is_over() and guard < 10:
		var c := run.make_combat(db, rules)
		c.start()
		while c.outcome == Combat.Outcome.ONGOING and c.turn < 100:
			bot._bot_turn(c, 1.5)
			c.resolve_turn()
		run.complete_combat(c)
		guard += 1
	assert_true(run.is_over())


func _hint(id: String, trigger: Dictionary, after := "") -> Dictionary:
	return {"id": id, "text": "x", "anchor": "none", "trigger": trigger, "after": after}


func test_hint_conditions() -> void:
	var h := _hint("a", {"encounter": "e1", "turn": 1, "hand_keyword": "flippable"})
	var ctx := {"encounter": "e1", "turn": 1, "hand_keywords": ["flippable"]}
	assert_true(TutorialRules.matches(h, ctx, {}))
	assert_false(TutorialRules.matches(h, ctx, {"a": true}), "seen hints never repeat")
	ctx["turn"] = 2
	assert_false(TutorialRules.matches(h, ctx, {}))


func test_hint_after_chain_and_order() -> void:
	var hints: Array[Dictionary] = [_hint("first", {}), _hint("second", {}, "first")]
	assert_eq(TutorialRules.next_hint(hints, {}, {})["id"], "first")
	assert_eq(TutorialRules.next_hint(hints, {}, {"first": true})["id"], "second")
	assert_true(TutorialRules.next_hint(hints, {}, {"first": true, "second": true}).is_empty())


func test_preview_outcome_condition() -> void:
	var r := Resolver.resolve_track(PackedInt32Array([2, 0]), PackedInt32Array([-5, 0]))
	var ctx := {"preview_outcomes": TutorialRules.outcome_names(r)}
	assert_true(TutorialRules.matches(_hint("o", {"preview_outcome": "overflow"}), ctx, {}))
	assert_false(TutorialRules.matches(_hint("c", {"preview_outcome": "cancelled"}), ctx, {}))


func test_validate_catches_bad_hints() -> void:
	var bad: Array[Dictionary] = [
		{"id": "a", "text": "", "anchor": "moon", "trigger": {"weather": 1}},
		{"id": "b", "text": "t", "after": "ghost"},
	]
	assert_true(TutorialRules.validate(bad).size() >= 4)


func test_progress_round_trip() -> void:
	var path := "user://test_progress.json"
	var p := Progress.load_from(path)
	p.reset_hints()
	p.mark_seen("x")
	assert_true(Progress.load_from(path).seen_hints.has("x"))
	p.reset_hints()
	assert_false(Progress.load_from(path).seen_hints.has("x"))
	DirAccess.remove_absolute(path)
