class_name SlotBar
extends Control
## Face of the transmitter's foot (the horizontal leg of the L), laid out flat
## and shown lying on the desk by its DeskDevice. One card slot per cell, in
## the same columns as the transmitter screen above: a card inserted in slot t
## plays its wave from cell t to the right. The cards themselves stand in the
## slots and are drawn by SlotCards (screen space); this only draws the
## surface and the slits, lighting the slits a wave covers.

var track_length := 16
## Grid start / width in local coordinates (same columns as the screen above).
var grid_x0 := 0.0
var grid_w := 100.0
## Depth of the slit row on the foot (0 = far edge, 1 = near edge).
var slit_depth := 0.8
## Corner radii (TL, TR, BR, BL), matching the foot's DeskDevice.
var radii := Vector4(0, 0, InstrumentStyle.CASE_RADIUS, InstrumentStyle.CASE_RADIUS)
## Cells whose slits glow (the span of the hovered / dragged wave), [from, to).
var lit_from := 0
var lit_to := 0


func cell_width() -> float:
	return grid_w / track_length


## Slot under local point `p` (may be out of range).
func cell_at(p: Vector2) -> int:
	return floori((p.x - grid_x0) / cell_width())


## Left end of slot t's slit (local): a standing card's bottom-left corner.
func slit_point(t: int) -> Vector2:
	return Vector2(grid_x0 + t * cell_width() + 4.0, size.y * slit_depth)


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	InstrumentStyle.draw_case(self, r, InstrumentStyle.CASE_RADIUS, 0.0, null, false, radii)
	# Shade where the upright face meets the foot.
	for i in 6:
		draw_rect(Rect2(0, i * 6.0, size.x, 6.0), Color(0, 0, 0, 0.1 * (1.0 - i / 6.0)))
	var cw := cell_width()
	var y := size.y * slit_depth
	var lamp := Assets.color("energy")
	for t in track_length:
		var slit := Rect2(grid_x0 + t * cw + 4.0, y - 9.0, cw - 8.0, 18.0)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("16130f")
		sb.set_corner_radius_all(6)
		draw_style_box(sb, slit)
		# Catch-light on the near lip of the slit.
		draw_line(Vector2(slit.position.x + 4, slit.end.y + 2), Vector2(slit.end.x - 4, slit.end.y + 2), Color(1, 1, 1, 0.45), 2.0)
		if t >= lit_from and t < lit_to:
			draw_style_box(_glow(lamp), slit.grow(3))
	# Column marks every 4 cells, like the major divisions on the screen.
	for t in range(0, track_length + 1, 4):
		var x := grid_x0 + t * cw
		draw_line(Vector2(x, y + 22), Vector2(x, y + 40), Color(Assets.color("case_print"), 0.5), 2.0)


static func _glow(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(col, 0.0)
	sb.border_color = Color(col, 0.8)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(8)
	return sb
