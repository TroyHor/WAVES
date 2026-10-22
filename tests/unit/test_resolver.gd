extends TestCase

const O := TrackResult.Outcome


func _rules(length := 8) -> RulesConfig:
	var r := RulesConfig.new()
	r.track_length = length
	return r


func _pl(wave: Array, offset: int) -> WavePlacement:
	return WavePlacement.new(PackedInt32Array(wave), offset)


func test_design_doc_example() -> void:
	# docs/design.md 2.3
	var placements: Array[WavePlacement] = [_pl([-2, -6, -2], 2), _pl([2, 4, 2], 5)]
	var r := Resolver.resolve(PackedInt32Array([0, 0, 3, 5, 3, 0, 0, 0]), placements, _rules())
	assert_eq(r.net, [0, 0, 1, -1, 1, 2, 4, 2])
	assert_eq(r.outcome, [O.EMPTY, O.EMPTY, O.PLAYER_HIT, O.OVERFLOW, O.PLAYER_HIT, O.ENEMY_HIT, O.ENEMY_HIT, O.ENEMY_HIT])
	assert_eq(r.damage, [0, 0, 1, 1, 1, 2, 4, 2])
	assert_eq(r.to_player, 2)
	assert_eq(r.to_enemy, 9)
	assert_eq(r.overflow_damage, 1)


func test_design_doc_example_shifted_amplifies_enemy() -> void:
	var placements: Array[WavePlacement] = [_pl([-2, -6, -2], 2), _pl([2, 4, 2], 4)]
	var r := Resolver.resolve(PackedInt32Array([0, 0, 3, 5, 3, 0, 0, 0]), placements, _rules())
	assert_eq(r.damage[4], 3, "3 + -2 + 2 = 3 hits the player")
	assert_eq(r.outcome[4], O.PLAYER_HIT)


func test_perfect_cancel() -> void:
	var r := Resolver.resolve_track(PackedInt32Array([2, 4, 2]), PackedInt32Array([-2, -4, -2]))
	assert_eq(r.outcome, [O.CANCELLED, O.CANCELLED, O.CANCELLED])
	assert_eq(r.perfect_cancels, 3)
	assert_eq(r.to_player + r.to_enemy, 0)


func test_unopposed_enemy_wave_hits_player() -> void:
	var r := Resolver.resolve_track(PackedInt32Array([2, 4, 2]), PackedInt32Array([0, 0, 0]))
	assert_eq(r.to_player, 8)


func test_same_sign_player_wave_amplifies_damage_to_self() -> void:
	var r := Resolver.resolve_track(PackedInt32Array([3]), PackedInt32Array([2]))
	assert_eq(r.to_player, 5)
	assert_eq(r.to_enemy, 0)


func test_negative_enemy_wave_resolves_symmetrically() -> void:
	var r := Resolver.resolve_track(PackedInt32Array([-4, -4, -4]), PackedInt32Array([1, 4, 6]))
	assert_eq(r.outcome, [O.PLAYER_HIT, O.CANCELLED, O.OVERFLOW])
	assert_eq(r.to_player, 3)
	assert_eq(r.to_enemy, 2)


func test_player_waves_cancel_each_other_in_gaps() -> void:
	var placements: Array[WavePlacement] = [_pl([3, 3], 0), _pl([-3, -1], 0)]
	var r := Resolver.resolve(PackedInt32Array([0, 0, 0, 0]), placements, _rules(4))
	assert_eq(r.net, [0, 2, 0, 0])
	assert_eq(r.to_enemy, 2)


func test_gap_damage_ignores_sign() -> void:
	var r := Resolver.resolve_track(PackedInt32Array([0, 0]), PackedInt32Array([-5, 5]))
	assert_eq(r.to_enemy, 10)


func test_overflow_ratio_is_floored_per_cell() -> void:
	var r := Resolver.resolve_track(PackedInt32Array([1, 1]), PackedInt32Array([-2, -4]), 0.5)
	assert_eq(r.damage, [0, 1])
	assert_eq(r.to_enemy, 1)


func test_full_coverage_enemy_can_still_be_hurt_by_overflow() -> void:
	var enemy := WaveMath.empty_track(8)
	enemy.fill(2)
	var placements: Array[WavePlacement] = [_pl([-5, -5, -5], 0)]
	var r := Resolver.resolve(enemy, placements, _rules())
	assert_eq(r.to_enemy, 9)
	assert_eq(r.to_player, 10)


func test_offtrack_samples_are_truncated() -> void:
	var placements: Array[WavePlacement] = [_pl([5, 5, 5], 6)]
	var r := Resolver.resolve(WaveMath.empty_track(8), placements, _rules())
	assert_eq(r.to_enemy, 10)


func test_twin_waves_interfere_before_resolution() -> void:
	# Interference Twins: combat layer sums both intents; opposite-sign
	# overlaps cancel each other and the overlap cell becomes a gap.
	var crest := PackedInt32Array([0, 2, 2, 2, 0, 0])
	var trough := PackedInt32Array([0, 0, 0, -2, -5, 0])
	var combined := WaveMath.add(crest, trough)
	var r := Resolver.resolve_track(combined, PackedInt32Array([0, 0, 0, 3, 0, 0]))
	assert_eq(combined, [0, 2, 2, 0, -5, 0])
	assert_eq(r.outcome[3], O.ENEMY_HIT)
	assert_eq(r.to_player, 9)
	assert_eq(r.to_enemy, 3)


func test_resolution_is_order_independent() -> void:
	var enemy := PackedInt32Array([0, 2, 4, 2, 0, 0, -3, 0])
	var a: Array[WavePlacement] = [_pl([1, 2, 3], 0), _pl([-2, -4, -2], 2), _pl([5], 6)]
	var b: Array[WavePlacement] = [a[2], a[0], a[1]]
	assert_eq(Resolver.resolve(enemy, a, _rules()).damage, Resolver.resolve(enemy, b, _rules()).damage)


func test_opposing_wave_swing_is_linear_with_ratio_one() -> void:
	# Documented property (design.md 2.3): on a cell where P opposes E,
	# enemy damage - player damage == |P| - |E|, however well P matches E.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in 200:
		var e := rng.randi_range(1, 9) * (1 if rng.randf() < 0.5 else -1)
		var p := -signi(e) * rng.randi_range(0, 12)
		var r := Resolver.resolve_track(PackedInt32Array([e]), PackedInt32Array([p]))
		assert_eq(r.to_enemy - r.to_player, absi(p) - absi(e), "E=%d P=%d" % [e, p])


func test_blocked_breakdown() -> void:
	# partial block, overflow, amplify, gap, perfect cancel
	var r := Resolver.resolve_track(PackedInt32Array([4, 4, 3, 0, -2]), PackedInt32Array([-2, -6, 2, 5, 2]))
	assert_eq(r.blocked, [2, 4, 0, 0, 2])
	assert_eq(r.blocked_total, 8)


func test_blocked_plus_hit_equals_enemy_when_opposing() -> void:
	# On a cell where P opposes E: blocked + damage to player == |E| (unless overflowing).
	for p in range(0, 5):
		var r := Resolver.resolve_track(PackedInt32Array([4]), PackedInt32Array([-p]))
		assert_eq(r.blocked[0] + (r.damage[0] if r.outcome[0] == TrackResult.Outcome.PLAYER_HIT else 0), 4, "P=-%d" % p)
