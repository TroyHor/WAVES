extends TestCase


func _rules() -> RulesConfig:
	return RulesConfig.new()


func _card(d: Dictionary) -> CardData:
	var errors: Array[String] = []
	var c := CardData.from_dict(d, errors)
	assert_true(errors.is_empty(), str(errors))
	return c


func _enemy(d: Dictionary) -> EnemyData:
	var errors: Array[String] = []
	var e := EnemyData.from_dict(d, errors)
	assert_true(errors.is_empty(), str(errors))
	return e


func _dummy_enemy(hp := 50, shape := [2, 2]) -> EnemyData:
	return _enemy({"id": "dummy", "hp": hp, "moves": [{"id": "m", "waves": [{"shape": shape, "offset": 0}]}]})


func _combat(cards: Array, enemy: EnemyData = null, hp := 60) -> CombatState:
	var deck: Array[CardData] = []
	for c in cards:
		deck.append(c)
	var enemies: Array[EnemyData] = [enemy if enemy else _dummy_enemy()]
	var s := CombatState.new(_rules(), deck, enemies, hp, 7)
	s.start()
	return s


func _pulses(n: int) -> Array:
	var out := []
	for i in n:
		out.append(_card({"id": "pulse", "name": "p", "cost": 1, "wave": [2, 4, 2]}))
	return out


func test_turn_start_draws_hand_and_fills_energy() -> void:
	var s := _combat(_pulses(8))
	assert_eq(s.turn, 1)
	assert_eq(s.energy, 3)
	assert_eq(s.deck.hand.size(), 5)
	assert_eq(s.deck.draw_pile.size(), 3)


func test_play_spends_energy_and_cannot_overspend() -> void:
	var s := _combat(_pulses(8))
	var hand := s.deck.hand.duplicate()
	for i in 3:
		assert_ne(s.play(hand[i], 0, 4), null)
	assert_eq(s.energy, 0)
	assert_eq(s.play(hand[3], 0, 4), null, "no energy left")
	assert_eq(s.deck.hand.size(), 2)
	assert_eq(s.played.size(), 3)


func test_preview_matches_end_turn_damage() -> void:
	var s := _combat(_pulses(8))
	s.play(s.deck.hand[0], 0, 5)  # gap: 8 damage; enemy [2,2] at 0 unopposed: 4 to player
	var preview := s.preview()
	var report := s.end_turn()
	assert_eq(report.damage_to_player, preview.to_player)
	assert_eq(report.damage_to_enemies[0], preview.to_enemy_total())
	assert_eq(s.player_hp, 56)
	assert_eq(s.enemies[0].hp, 42)


func test_end_turn_discards_and_draws_new_hand() -> void:
	var s := _combat(_pulses(8))
	s.play(s.deck.hand[0], 0, 5)
	s.end_turn()
	assert_eq(s.turn, 2)
	assert_eq(s.deck.hand.size(), 5)
	assert_eq(s.played.size(), 0)
	assert_eq(s.deck.total_cards(), 8)


func test_ghost_preview_does_not_change_state() -> void:
	var s := _combat(_pulses(8))
	var ghost := PlayedCard.new(s.deck.hand[0], 0, 0)
	assert_eq(s.preview(ghost).to_player, 10, "ghost [2,4,2] at 0 amplifies enemy [2,2]: (2+2)+(4+2)")
	assert_eq(s.played.size(), 0)
	assert_eq(s.energy, 3)


func test_move_and_retract() -> void:
	var s := _combat(_pulses(8))
	var pc := s.play(s.deck.hand[0], 0, 0)
	assert_true(s.move(pc, 0, 10))
	assert_eq(pc.offset, 10)
	assert_true(s.retract(pc))
	assert_eq(s.energy, 3)
	assert_eq(s.deck.hand.size(), 5)
	assert_eq(s.played.size(), 0)


func test_flippable_card_inverts_and_plain_card_does_not() -> void:
	var flip := _card({"id": "bi", "name": "b", "cost": 1, "wave": [3, 3], "flippable": true})
	var s := _combat([flip] + _pulses(4))
	var flip_inst: CardInstance = null
	for c in s.deck.hand:
		if c.data == flip:
			flip_inst = c
	var pc := s.play(flip_inst, 0, 0, true)
	assert_eq(s.preview().lanes[0].net.slice(0, 2), [-1, -1])
	assert_true(s.set_inverted(pc, false))
	assert_eq(s.preview().lanes[0].net.slice(0, 2), [5, 5])
	var plain := s.play(s.deck.hand[0], 0, 8, true)
	assert_false(plain.inverted)
	assert_false(s.set_inverted(plain, true))


func test_echo_places_a_second_copy() -> void:
	var echo := _card({"id": "e", "name": "e", "cost": 1, "wave": [3, 2, 1], "echo": 5})
	var pc := PlayedCard.new(CardInstance.new(1, echo), 0, 2)
	var placements := pc.placements()
	assert_eq(placements.size(), 2)
	assert_eq(placements[1].offset, 7)
	assert_true(pc.covers(0, 8))
	assert_false(pc.covers(0, 5))


func test_draw_card_draws_and_cannot_be_retracted() -> void:
	var tune := _card({"id": "t", "name": "t", "cost": 0, "on_play": [{"type": "draw", "amount": 2}]})
	var s := _combat([tune, tune, tune, tune, tune] + _pulses(5))
	var t := s.deck.hand[0]
	for c in s.deck.hand:
		if c.data == tune:
			t = c
	var pc := s.play(t)
	assert_eq(s.deck.hand.size(), 6, "5 - 1 played + 2 drawn")
	assert_eq(s.played.size(), 0, "non-wave cards are not on the track")
	assert_false(s.retract(pc))


func test_chord_voices_go_to_consecutive_lanes() -> void:
	var chord := _card({"id": "c", "name": "c", "cost": 1, "waves": [[1], [-2]]})
	var pc := PlayedCard.new(CardInstance.new(1, chord), 1, 3)
	var p := pc.placements()
	assert_eq(p[0].lane, 1)
	assert_eq(p[1].lane, 2)
	assert_eq(p[1].wave, [-2])


func test_win_when_enemy_dies() -> void:
	var s := _combat(_pulses(8), _dummy_enemy(5))
	s.play(s.deck.hand[0], 0, 5)
	var report := s.end_turn()
	assert_eq(report.status, CombatState.Status.WON)
	assert_eq(s.status, CombatState.Status.WON)


func test_simultaneous_death_is_a_loss() -> void:
	var s := _combat(_pulses(8), _dummy_enemy(5, [3, 3]), 6)
	s.play(s.deck.hand[0], 0, 5)
	s.end_turn()
	assert_eq(s.enemies[0].hp, 0)
	assert_eq(s.player_hp, 0)
	assert_eq(s.status, CombatState.Status.LOST)


func test_no_actions_after_combat_ends() -> void:
	var s := _combat(_pulses(8), _dummy_enemy(5))
	s.play(s.deck.hand[0], 0, 5)
	s.end_turn()
	assert_eq(s.play(s.deck.hand[0] if not s.deck.hand.is_empty() else s.deck.discard_pile[0], 0, 0), null)


func test_forced_next_move() -> void:
	var e := _enemy({"id": "t", "hp": 10, "moves": [
		{"id": "charge", "weight": 1, "next": "tide", "waves": [{"shape": [1], "offset": 0}]},
		{"id": "tide", "weight": 0, "waves": [{"shape": [5], "offset": 0}]},
	]})
	var state := EnemyState.new(e)
	var rng := RandomNumberGenerator.new()
	var seq := []
	for i in 6:
		state.roll_intent(rng, 4)
		seq.append(state.current_move.id)
	assert_eq(seq, ["charge", "tide", "charge", "tide", "charge", "tide"])


func test_max_repeat_is_respected() -> void:
	var e := _enemy({"id": "r", "hp": 10, "moves": [
		{"id": "a", "weight": 1000, "max_repeat": 2, "waves": [{"shape": [1], "offset": 0}]},
		{"id": "b", "weight": 0.001, "waves": [{"shape": [1], "offset": 0}]},
	]})
	var state := EnemyState.new(e)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var run := 0
	for i in 50:
		state.roll_intent(rng, 4)
		run = run + 1 if state.current_move.id == "a" else 0
		assert_true(run <= 2, "move 'a' repeated %d times" % run)


func test_intent_offsets_stay_in_declared_range() -> void:
	var e := _enemy({"id": "o", "hp": 10, "moves": [{"id": "m", "waves": [{"shape": [9], "offset": [3, 5], "random_flip": true}]}]})
	var state := EnemyState.new(e)
	var rng := RandomNumberGenerator.new()
	for i in 100:
		state.roll_intent(rng, 16)
		var track := state.intent[0]
		for t in 16:
			if track[t] != 0:
				assert_true(t >= 3 and t <= 5, "spike at %d" % t)
				assert_eq(absi(track[t]), 9)


func test_same_seed_same_combat() -> void:
	var lib := ContentLibrary.load_default()
	var deck: Array[CardData] = []
	for id in lib.starter_deck:
		deck.append(lib.cards[id])
	var turns := []
	for run in 2:
		var enemies: Array[EnemyData] = [lib.enemies["shrieker"]]
		var s := CombatState.new(_rules(), deck, enemies, 60, 99)
		GreedyBot.new().play_combat(s)
		turns.append([s.turn, s.player_hp, s.status])
	assert_eq(turns[0], turns[1])
