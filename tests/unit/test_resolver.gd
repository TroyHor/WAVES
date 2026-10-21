extends TestCase

const O := LaneResult.Outcome


func _rules(length := 8) -> RulesConfig:
	var r := RulesConfig.new()
	r.track_length = length
	return r


func _lanes(arrays: Array) -> Array[PackedInt32Array]:
	var out: Array[PackedInt32Array] = []
	for a in arrays:
		out.append(PackedInt32Array(a))
	return out


func _pl(wave: Array, offset: int, lane := 0) -> WavePlacement:
	return WavePlacement.new(PackedInt32Array(wave), offset, lane)


func test_design_doc_example() -> void:
	# docs/design.md 2.3
	var placements: Array[WavePlacement] = [_pl([-2, -6, -2], 2), _pl([2, 4, 2], 5)]
	var res := Resolver.resolve(_lanes([[0, 0, 3, 5, 3, 0, 0, 0]]), placements, _rules())
	var lane := res.lanes[0]
	assert_eq(lane.net, [0, 0, 1, -1, 1, 2, 4, 2])
	assert_eq(lane.outcome, [O.EMPTY, O.EMPTY, O.PLAYER_HIT, O.OVERFLOW, O.PLAYER_HIT, O.ENEMY_HIT, O.ENEMY_HIT, O.ENEMY_HIT])
	assert_eq(lane.damage, [0, 0, 1, 1, 1, 2, 4, 2])
	assert_eq(res.to_player, 2)
	assert_eq(res.to_lane(0), 9)
	assert_eq(lane.overflow_damage, 1)


func test_design_doc_example_shifted_amplifies_enemy() -> void:
	var placements: Array[WavePlacement] = [_pl([-2, -6, -2], 2), _pl([2, 4, 2], 4)]
	var res := Resolver.resolve(_lanes([[0, 0, 3, 5, 3, 0, 0, 0]]), placements, _rules())
	assert_eq(res.lanes[0].damage[4], 3, "3 + -2 + 2 = 3 hits the player")
	assert_eq(res.lanes[0].outcome[4], O.PLAYER_HIT)


func test_perfect_cancel() -> void:
	var lr := Resolver.resolve_lane(PackedInt32Array([2, 4, 2]), PackedInt32Array([-2, -4, -2]))
	assert_eq(lr.outcome, [O.CANCELLED, O.CANCELLED, O.CANCELLED])
	assert_eq(lr.perfect_cancels, 3)
	assert_eq(lr.to_player + lr.to_enemy, 0)


func test_unopposed_enemy_wave_hits_player() -> void:
	var lr := Resolver.resolve_lane(PackedInt32Array([2, 4, 2]), PackedInt32Array([0, 0, 0]))
	assert_eq(lr.to_player, 8)


func test_same_sign_player_wave_amplifies_damage_to_self() -> void:
	var lr := Resolver.resolve_lane(PackedInt32Array([3]), PackedInt32Array([2]))
	assert_eq(lr.to_player, 5)
	assert_eq(lr.to_enemy, 0)


func test_negative_enemy_wave_resolves_symmetrically() -> void:
	var lr := Resolver.resolve_lane(PackedInt32Array([-4, -4, -4]), PackedInt32Array([1, 4, 6]))
	assert_eq(lr.outcome, [O.PLAYER_HIT, O.CANCELLED, O.OVERFLOW])
	assert_eq(lr.to_player, 3)
	assert_eq(lr.to_enemy, 2)


func test_player_waves_cancel_each_other_in_gaps() -> void:
	var placements: Array[WavePlacement] = [_pl([3, 3], 0), _pl([-3, -1], 0)]
	var res := Resolver.resolve(_lanes([[0, 0, 0, 0]]), placements, _rules(4))
	assert_eq(res.lanes[0].net, [0, 2, 0, 0])
	assert_eq(res.to_lane(0), 2)


func test_gap_damage_ignores_sign() -> void:
	var lr := Resolver.resolve_lane(PackedInt32Array([0, 0]), PackedInt32Array([-5, 5]))
	assert_eq(lr.to_enemy, 10)


func test_overflow_ratio_is_floored_per_cell() -> void:
	var lr := Resolver.resolve_lane(PackedInt32Array([1, 1]), PackedInt32Array([-2, -4]), 0.5)
	assert_eq(lr.damage, [0, 1])
	assert_eq(lr.to_enemy, 1)


func test_full_coverage_enemy_can_still_be_hurt_by_overflow() -> void:
	var enemy: Array = []
	enemy.resize(8)
	enemy.fill(2)
	var placements: Array[WavePlacement] = [_pl([-5, -5, -5], 0)]
	var res := Resolver.resolve(_lanes([enemy]), placements, _rules())
	assert_eq(res.to_lane(0), 9)
	assert_eq(res.to_player, 10)


func test_offtrack_samples_are_truncated() -> void:
	var placements: Array[WavePlacement] = [_pl([5, 5, 5], 6)]
	var res := Resolver.resolve(_lanes([[0, 0, 0, 0, 0, 0, 0, 0]]), placements, _rules())
	assert_eq(res.to_lane(0), 10)


func test_lanes_are_independent() -> void:
	var placements: Array[WavePlacement] = [_pl([-2], 0, 0), _pl([4], 1, 1)]
	var res := Resolver.resolve(_lanes([[2, 0], [0, 0]]), placements, _rules(2))
	assert_eq(res.to_lane(0), 0)
	assert_eq(res.to_lane(1), 4)
	assert_eq(res.to_enemy_total(), 4)
	assert_eq(res.to_player, 0)


func test_placements_on_missing_lanes_are_ignored() -> void:
	var placements: Array[WavePlacement] = [_pl([4], 0, 0), _pl([9], 0, 3)]
	var res := Resolver.resolve(_lanes([[0, 0]]), placements, _rules(2))
	assert_eq(res.lanes.size(), 1)
	assert_eq(res.to_lane(0), 4)


func test_resolution_is_order_independent() -> void:
	var enemy := _lanes([[0, 2, 4, 2, 0, 0, -3, 0]])
	var a: Array[WavePlacement] = [_pl([1, 2, 3], 0), _pl([-2, -4, -2], 2), _pl([5], 6)]
	var b: Array[WavePlacement] = [a[2], a[0], a[1]]
	var ra := Resolver.resolve(enemy, a, _rules())
	var rb := Resolver.resolve(enemy, b, _rules())
	assert_eq(ra.lanes[0].damage, rb.lanes[0].damage)


func test_opposing_wave_swing_is_linear_with_ratio_one() -> void:
	# Documented property (design.md 2.3): on a cell where P opposes E,
	# enemy damage - player damage == |P| - |E|, however well P matches E.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in 200:
		var e := rng.randi_range(1, 9) * (1 if rng.randf() < 0.5 else -1)
		var p := -signi(e) * rng.randi_range(0, 12)
		var lr := Resolver.resolve_lane(PackedInt32Array([e]), PackedInt32Array([p]))
		assert_eq(lr.to_enemy - lr.to_player, absi(p) - absi(e), "E=%d P=%d" % [e, p])
