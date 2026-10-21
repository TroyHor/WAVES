extends TestCase
## Validates every shipped data file, so a broken JSON fails CI immediately.


func test_project_data_loads_without_errors() -> void:
	var db := GameDatabase.load_default()
	assert_eq(db.errors.size(), 0, "\n".join(db.errors))


func test_expected_content_counts() -> void:
	var db := GameDatabase.load_default()
	assert_true(db.cards.size() >= 10, "at least 10 cards")
	assert_true(db.enemies.size() >= 3, "at least 3 enemies")
	assert_eq(db.starter_cards().size(), db.starter_deck.size())


func test_every_enemy_intent_fits_and_is_nonzero() -> void:
	var db := GameDatabase.load_default()
	var rules := RulesConfig.load_file()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for e: EnemyData in db.enemies.values():
		for m in e.moves:
			for i in 20:
				var intent := EnemyState.build_intent(m, rng, rules.track_length)
				assert_eq(intent.size(), rules.track_length)
				var any := false
				for v in intent:
					any = any or v != 0
				# Opposite-sign overlaps could cancel, but never every sample.
				assert_true(any, "%s/%s produced an empty intent" % [e.id, m.id])


func test_card_parsing_and_rules_text() -> void:
	var errors := PackedStringArray()
	var c := CardData.from_dict({"id": "x", "cost": 1.0, "wave": [1.0, -2.0], "keywords": ["flippable"],
		"effects": [{"type": "echo", "offset": 4.0}]}, errors)
	assert_eq(errors.size(), 0)
	assert_eq(c.wave, [1, -2])
	assert_eq(c.effect_value("echo", "offset"), 4)
	assert_true(c.rules_text().contains("4"))


func test_invalid_card_reports_errors() -> void:
	var errors := PackedStringArray()
	CardData.from_dict({"id": "bad", "keywords": ["nope"], "effects": [{"type": "teleport"}]}, errors)
	assert_true(errors.size() >= 2, str(errors))


func test_enemy_with_missing_next_move_reports_error() -> void:
	var errors := PackedStringArray()
	EnemyData.from_dict({"id": "e", "hp": 5, "moves": [{"id": "a", "next": "ghost", "waves": [{"shape": [1]}]}]}, errors)
	assert_eq(errors.size(), 1, str(errors))
