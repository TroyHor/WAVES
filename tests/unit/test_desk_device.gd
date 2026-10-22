extends TestCase
## Homography used to put flat instrument faces onto the desk in perspective.


func _quad() -> PackedVector2Array:
	# Upright device: top wider than bottom.
	return PackedVector2Array([Vector2(0, 0), Vector2(400, 0), Vector2(380, 200), Vector2(20, 200)])


func test_corners_map_exactly() -> void:
	var q := _quad()
	var h := DeskDevice._square_to_quad(q)
	var unit := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
	for i in 4:
		var p := DeskDevice._apply(h, unit[i])
		assert_true(p.distance_to(q[i]) < 0.001, "corner %d -> %s" % [i, p])


func test_inverse_round_trip() -> void:
	var h := DeskDevice._square_to_quad(PackedVector2Array([Vector2(30, 10), Vector2(370, 0), Vector2(400, 220), Vector2(0, 200)]))
	var inv := DeskDevice._invert(h)
	for uv in [Vector2(0.5, 0.5), Vector2(0.1, 0.9), Vector2(0.77, 0.23)]:
		var back := DeskDevice._apply(inv, DeskDevice._apply(h, uv))
		assert_true(back.distance_to(uv) < 0.0001, "round trip %s -> %s" % [uv, back])


func test_rectangle_is_affine() -> void:
	var h := DeskDevice._square_to_quad(PackedVector2Array([Vector2(0, 0), Vector2(200, 0), Vector2(200, 100), Vector2(0, 100)]))
	assert_true(DeskDevice._apply(h, Vector2(0.5, 0.5)).distance_to(Vector2(100, 50)) < 0.001)
