extends TestCase


func _rules() -> RulesConfig:
	return RulesConfig.new()


func _card(id: String, wave: Array, cost := 1, extra := {}) -> CardData:
	var d := {"id": id, "cost": cost, "wave": wave}
	d.merge(extra)
	return CardData.from_dict(d, PackedStringArray())


func _enemy(id: String, hp: int, moves: Array) -> EnemyData:
	return EnemyData.from_dict({"id": id, "hp": hp, "moves": moves}, PackedStringArray())


## Enemy whose only move is `shape` at a fixed offset.
func _fixed_enemy(id: String, hp: int, shape: Array, offset: int) -> EnemyData:
	return _enemy(id, hp, [{"id": "m", "waves": [{"shape": shape, "offset": offset}]}])


func _combat(cards: Array[CardData], enemies: Array[EnemyData], swap := 0) -> Combat:
	var c := Combat.new(_rules(), cards, enemies, 42, swap)
	c.start()
	return c


func _many(card: CardData, n: int) -> Array[CardData]:
	var out: Array[CardData] = []
	for i in n:
		out.append(card)
	return out


func test_start_draws_hand_and_fills_energy() -> void:
	var c := _combat(_many(_card("p", [2, 4, 2]), 10), [_fixed_enemy("e", 20, [3], 0)])
	assert_eq(c.deck.hand.size(), 5)
	assert_eq(c.energy, 3)
	assert_eq(c.turn, 1)
	assert_eq(c.enemy_track()[0], 3)


func test_play_spends_energy_and_cannot_overspend() -> void:
	var c := _combat(_many(_card("p", [1], 2), 10), [_fixed_enemy("e", 20, [3], 0)])
	assert_true(c.play(c.deck.hand[0], 5))
	assert_eq(c.energy, 1)
	assert_false(c.play(c.deck.hand[0], 6), "only 1 energy left")
	assert_eq(c.played.size(), 1)


func test_unplay_refunds_and_returns_to_hand() -> void:
	var c := _combat(_many(_card("p", [1]), 10), [_fixed_enemy("e", 20, [3], 0)])
	var card := c.deck.hand[0]
	c.play(card, 4)
	assert_true(c.unplay(card))
	assert_eq(c.energy, 3)
	assert_true(card in c.deck.hand)
	assert_eq(c.played.size(), 0)


func test_move_card_changes_preview() -> void:
	var c := _combat(_many(_card("p", [-3]), 10), [_fixed_enemy("e", 20, [3], 0)])
	var card := c.deck.hand[0]
	c.play(card, 5)
	assert_eq(c.preview().to_player, 3)
	c.move_card(card, 0)
	assert_eq(c.preview().to_player, 0)


func test_preview_with_hypothetical_card_does_not_mutate() -> void:
	var c := _combat(_many(_card("p", [4]), 10), [_fixed_enemy("e", 20, [3], 0)])
	var r := c.preview(PlayedCard.new(c.deck.hand[0], 8))
	assert_eq(r.to_enemy, 4)
	assert_eq(c.played.size(), 0)
	assert_eq(c.energy, 3)


func test_flip_only_for_flippable_cards() -> void:
	var plain := _card("plain", [3])
	var flip := _card("flip", [3], 1, {"keywords": ["flippable"]})
	var c := _combat([plain, flip, plain, flip, plain], [_fixed_enemy("e", 20, [3], 0)])
	var a: CardInstance = null
	var b: CardInstance = null
	for h in c.deck.hand:
		if h.data.id == "plain" and a == null:
			a = h
		if h.data.id == "flip" and b == null:
			b = h
	c.play(a, 0)
	c.play(b, 0)
	assert_false(c.set_flipped(a, true))
	assert_true(c.set_flipped(b, true))
	# 3 (enemy) + 3 (plain) - 3 (flipped) = 3 -> player hit
	assert_eq(c.preview().to_player, 3)


func test_echo_places_a_second_copy() -> void:
	var echo := _card("echo", [3, 2, 1], 1, {"effects": [{"type": "echo", "offset": 5}]})
	var c := _combat(_many(echo, 5), [_fixed_enemy("e", 20, [1], 15)])
	c.play(c.deck.hand[0], 0)
	var r := c.preview()
	assert_eq(r.player.slice(0, 8), [3, 2, 1, 0, 0, 3, 2, 1])
	assert_eq(r.to_enemy, 12)


func test_draw_card_draws_and_is_committed() -> void:
	var tune := CardData.from_dict({"id": "tune", "cost": 0, "effects": [{"type": "draw", "amount": 2}]}, PackedStringArray())
	var deck: Array[CardData] = [tune]
	deck.append_array(_many(_card("p", [1]), 9))
	var c := _combat(deck, [_fixed_enemy("e", 20, [3], 0)])
	var t: CardInstance = null
	for i in 3:
		for h in c.deck.hand:
			if h.data.id == "tune":
				t = h
		if t != null:
			break
		c.resolve_turn()
	assert_ne(t, null, "tune should be drawn within a few turns")
	var hand_before := c.deck.hand.size()
	assert_true(c.play(t))
	assert_eq(c.deck.hand.size(), hand_before - 1 + 2)
	assert_false(c.can_unplay(t))
	assert_true(t in c.deck.discard_pile)


func test_resolve_applies_damage_and_advances_turn() -> void:
	var c := _combat(_many(_card("p", [5]), 10), [_fixed_enemy("e", 30, [4], 0)])
	c.play(c.deck.hand[0], 10)
	var rep := c.resolve_turn()
	assert_eq(rep.result.to_player, 4)
	assert_eq(rep.result.to_enemy, 5)
	assert_eq(c.player_hp, 56)
	assert_eq(c.front_enemy().hp, 25)
	assert_eq(c.turn, 2)
	assert_eq(c.energy, 3)
	assert_eq(c.deck.hand.size(), 5)
	assert_eq(c.played.size(), 0)
	assert_eq(c.deck.total_cards(), 10)


func test_win_when_enemy_dies() -> void:
	var c := _combat(_many(_card("p", [9]), 10), [_fixed_enemy("e", 20, [1], 0)])
	for i in 3:
		c.play(c.deck.hand[0], 8 + i)
	var rep := c.resolve_turn()
	assert_eq(rep.outcome, Combat.Outcome.WON)
	assert_true(rep.killed)


func test_simultaneous_death_is_a_loss() -> void:
	var c := Combat.new(_rules(), _many(_card("p", [9]), 10), [_fixed_enemy("e", 9, [5], 0)], 1, 0, 5)
	c.start()
	c.play(c.deck.hand[0], 8)
	assert_eq(c.resolve_turn().outcome, Combat.Outcome.LOST)


func test_damage_hits_only_front_twin_and_overkill_is_wasted() -> void:
	var front := _fixed_enemy("front", 5, [1], 0)
	var back := _fixed_enemy("back", 20, [1], 15)
	var c := _combat(_many(_card("p", [9]), 10), [front, back], 2)
	c.play(c.deck.hand[0], 8)
	var rep := c.resolve_turn()
	assert_eq(rep.target.data.id, "front")
	assert_true(rep.killed)
	assert_eq(c.front_enemy().data.id, "back")
	assert_eq(c.front_enemy().hp, 20, "overkill must not carry over")
	assert_eq(c.outcome, Combat.Outcome.ONGOING)


func test_twin_intents_are_summed() -> void:
	var a := _fixed_enemy("a", 20, [2, 2], 0)
	var b := _fixed_enemy("b", 20, [-2, -5], 1)
	var c := _combat(_many(_card("p", [1]), 10), [a, b], 2)
	assert_eq(c.enemy_track().slice(0, 3), [2, 0, -5])


func test_twins_swap_every_interval() -> void:
	var a := _fixed_enemy("a", 50, [1], 0)
	var b := _fixed_enemy("b", 50, [1], 15)
	var c := _combat(_many(_card("p", [1]), 10), [a, b], 2)
	assert_eq(c.swap_in(), 2)
	assert_false(c.resolve_turn().swapped)
	assert_eq(c.front_enemy().data.id, "a")
	assert_eq(c.swap_in(), 1)
	assert_true(c.resolve_turn().swapped)
	assert_eq(c.front_enemy().data.id, "b")
	assert_eq(c.swap_in(), 2)


func test_forced_next_move() -> void:
	var e := _enemy("e", 50, [
		{"id": "charge", "weight": 1, "next": "release", "waves": [{"shape": [1], "offset": 0}]},
		{"id": "release", "weight": 0, "waves": [{"shape": [9], "offset": 0}]},
	])
	var c := _combat(_many(_card("p", [1]), 10), [e])
	assert_eq(c.front_enemy().move.id, "charge")
	c.resolve_turn()
	assert_eq(c.front_enemy().move.id, "release")
	c.resolve_turn()
	assert_eq(c.front_enemy().move.id, "charge")


func test_max_repeat_is_respected() -> void:
	var e := _enemy("e", 500, [
		{"id": "a", "weight": 100, "max_repeat": 1, "waves": [{"shape": [1]}]},
		{"id": "b", "weight": 1, "waves": [{"shape": [-1]}]},
	])
	var c := _combat(_many(_card("p", [1]), 10), [e])
	var prev := c.front_enemy().move.id
	for i in 30:
		c.resolve_turn()
		var cur := c.front_enemy().move.id
		assert_false(prev == "a" and cur == "a", "move a repeated")
		prev = cur


func test_same_seed_same_intents() -> void:
	var db := GameDatabase.load_default()
	var a := Combat.from_encounter(db, "02_shrieker", 99, _rules())
	var b := Combat.from_encounter(db, "02_shrieker", 99, _rules())
	a.start()
	b.start()
	for i in 5:
		assert_eq(a.enemy_track(), b.enemy_track())
		a.resolve_turn()
		b.resolve_turn()


func test_bot_finishes_every_encounter() -> void:
	# Greedy bot: for each affordable card, try every offset (and flip) and keep
	# the placement with the best (enemy damage - player damage). Ensures every
	# shipped encounter terminates and the real data never crashes the rules.
	var db := GameDatabase.load_default()
	for enc_id in db.encounter_ids():
		var c := Combat.from_encounter(db, enc_id, 2024, RulesConfig.load_file())
		c.start()
		var guard := 0
		while c.outcome == Combat.Outcome.ONGOING and guard < 100:
			_bot_turn(c)
			c.resolve_turn()
			guard += 1
		assert_ne(c.outcome, Combat.Outcome.ONGOING, "%s did not finish" % enc_id)


func _bot_turn(c: Combat, hp_weight := 1.0) -> void:
	var progress := true
	while progress:
		progress = false
		var now := c.preview()
		var best_score := now.to_enemy - now.to_player * hp_weight
		var best: PlayedCard = null
		for card in c.deck.hand:
			if not c.can_play(card):
				continue
			if not card.data.is_wave_card():
				c.play(card)
				progress = true
				break
			for off in range(-2, c.rules.track_length):
				for flip in [false, true]:
					var pc := PlayedCard.new(card, off, flip and card.data.has_keyword("flippable"))
					var r := c.preview(pc)
					var score := r.to_enemy - r.to_player * hp_weight
					if score > best_score:
						best_score = score
						best = pc
		if progress:
			continue
		if best != null:
			c.play(best.card, best.offset, best.flipped)
			progress = true
