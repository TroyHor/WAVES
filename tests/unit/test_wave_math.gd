extends TestCase


func test_invert_negates_every_sample() -> void:
	assert_eq(WaveMath.invert(PackedInt32Array([2, 4, 2, 0, -2, -4, -2])), [-2, -4, -2, 0, 2, 4, 2])


func test_invert_twice_is_identity() -> void:
	var w := PackedInt32Array([1, -3, 0, 5])
	assert_eq(WaveMath.invert(WaveMath.invert(w)), w)


func test_stretch_interpolates_keeping_endpoints() -> void:
	assert_eq(WaveMath.stretch(PackedInt32Array([2, 4]), 2), [2, 3, 4])
	assert_eq(WaveMath.stretch(PackedInt32Array([2, 4, 2]), 2), [2, 3, 4, 3, 2])


func test_stretch_length_formula() -> void:
	var w := PackedInt32Array([1, 2, 3, 4, 5])
	assert_eq(WaveMath.stretch(w, 3).size(), (w.size() - 1) * 3 + 1)


func test_stretch_rounds_half_away_from_zero_symmetrically() -> void:
	assert_eq(WaveMath.stretch(PackedInt32Array([0, 1]), 2), [0, 1, 1])
	assert_eq(WaveMath.stretch(PackedInt32Array([0, -1]), 2), [0, -1, -1])


func test_stretch_commutes_with_invert() -> void:
	var w := PackedInt32Array([3, -1, 4, -1, 5])
	assert_eq(WaveMath.stretch(WaveMath.invert(w), 3), WaveMath.invert(WaveMath.stretch(w, 3)))


func test_stretch_single_sample_and_factor_one_unchanged() -> void:
	assert_eq(WaveMath.stretch(PackedInt32Array([7]), 3), [7])
	assert_eq(WaveMath.stretch(PackedInt32Array([1, 2]), 1), [1, 2])


func test_place_inside_track() -> void:
	assert_eq(WaveMath.place(PackedInt32Array([2, 4, 2]), 1, 6), [0, 2, 4, 2, 0, 0])


func test_place_truncates_both_edges() -> void:
	assert_eq(WaveMath.place(PackedInt32Array([1, 2, 3]), -1, 4), [2, 3, 0, 0])
	assert_eq(WaveMath.place(PackedInt32Array([1, 2, 3]), 3, 4), [0, 0, 0, 1])


func test_place_wraps_in_wrap_mode() -> void:
	assert_eq(WaveMath.place(PackedInt32Array([1, 2, 3]), 3, 4, WaveMath.OFFTRACK_WRAP), [2, 3, 0, 1])


func test_fits() -> void:
	var w := PackedInt32Array([1, 2, 3])
	assert_true(WaveMath.fits(w, 0, 3))
	assert_false(WaveMath.fits(w, 1, 3))
	assert_false(WaveMath.fits(w, -1, 16))


func test_add_sums_elementwise() -> void:
	assert_eq(WaveMath.add(PackedInt32Array([1, -2, 0]), PackedInt32Array([-1, -2, 5])), [0, -4, 5])
