extends TestCase
## Validates every data file and runs bot fights against every enemy.


func test_all_content_loads_without_errors() -> void:
	var lib := ContentLibrary.load_default()
	assert_eq(lib.errors, [], "content errors")
	assert_true(lib.cards.size() >= 10)
	assert_true(lib.enemies.size() >= 3)


func test_starter_deck_has_balanced_signs() -> void:
	# Design Q5: the starter deck must be able to cancel both crests and troughs.
	var lib := ContentLibrary.load_default()
	var pos := 0
	var neg := 0
	for id in lib.starter_deck:
		var c: CardData = lib.cards[id]
		for w in c.waves:
			for v in w:
				if v > 0 or c.flippable:
					pos += absi(v)
				if v < 0 or c.flippable:
					neg += absi(v)
	assert_true(pos > 0 and neg > 0)
	assert_true(float(mini(pos, neg)) / maxi(pos, neg) > 0.6, "pos %d vs neg %d" % [pos, neg])


func test_every_intent_fits_on_track() -> void:
	var lib := ContentLibrary.load_default()
	var rules := RulesConfig.load_file()
	for e: EnemyData in lib.enemies.values():
		for m in e.moves:
			for w in m.waves:
				assert_true(w.offset_min >= 0 and w.offset_max + w.shape.size() <= rules.track_length,
					"%s/%s exceeds the track" % [e.id, m.id])


func test_bot_finishes_every_enemy() -> void:
	var lib := ContentLibrary.load_default()
	var rules := RulesConfig.load_file()
	var deck: Array[CardData] = []
	for id in lib.starter_deck:
		deck.append(lib.cards[id])
	for enemy_id in lib.enemy_ids():
		for seed_i in 3:
			var enemies: Array[EnemyData] = [lib.enemies[enemy_id]]
			var s := CombatState.new(rules, deck, enemies, rules.player_max_hp, seed_i)
			GreedyBot.new().play_combat(s, 60)
			assert_ne(s.status, CombatState.Status.ONGOING, "%s seed %d never ended" % [enemy_id, seed_i])
