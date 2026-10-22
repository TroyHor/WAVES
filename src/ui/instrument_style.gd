class_name InstrumentStyle
extends RefCounted
## Shared drawing for the workbench materials (docs/art_direction.md §3.1, §5):
## cream moulded-plastic cases, black recessed display windows, round
## observation ports and dark silkscreen print. Every instrument uses these so
## the whole screen reads as one set of hardware.

const CASE_RADIUS := 16


## Cream plastic shell with drop shadow, soft lower shading and a light lip.
static func draw_case(ci: CanvasItem, r: Rect2, radius := CASE_RADIUS, flash := 0.0) -> void:
	var shell := StyleBoxFlat.new()
	shell.bg_color = Assets.color("case").lerp(Color.WHITE, flash * 0.5)
	shell.set_corner_radius_all(radius)
	shell.border_color = Assets.color("case_edge")
	shell.set_border_width_all(2)
	shell.shadow_color = Color(0, 0, 0, 0.5)
	shell.shadow_size = 12
	shell.shadow_offset = Vector2(0, 6)
	ci.draw_style_box(shell, r)
	var shade := StyleBoxFlat.new()
	shade.bg_color = Color(Assets.color("case_dark"), 0.5)
	shade.corner_radius_bottom_left = radius
	shade.corner_radius_bottom_right = radius
	ci.draw_style_box(shade, Rect2(r.position.x + 2, r.get_center().y, r.size.x - 4, r.size.y * 0.5 - 2))
	ci.draw_line(Vector2(r.position.x + radius, r.position.y + 3), Vector2(r.end.x - radius, r.position.y + 3), Color(1, 1, 1, 0.55), 2.0)


## Black recessed window that screens and readouts sit in.
static func draw_window(ci: CanvasItem, r: Rect2, radius := 8) -> void:
	var w := StyleBoxFlat.new()
	w.bg_color = Assets.color("bezel")
	w.set_corner_radius_all(radius)
	w.border_color = Color(Assets.color("case_dark"), 1.0)
	w.set_border_width_all(3)
	ci.draw_style_box(w, r.grow(6))
	# Inner shadow along the top edge, catch-light along the bottom.
	ci.draw_line(Vector2(r.position.x + radius, r.position.y + 1), Vector2(r.end.x - radius, r.position.y + 1), Color(0, 0, 0, 0.7), 3.0)
	ci.draw_line(Vector2(r.position.x + radius, r.end.y + 5), Vector2(r.end.x - radius, r.end.y + 5), Color(1, 1, 1, 0.35), 1.0)


## Round observation port (enemy figures are only ever seen through these).
static func draw_round_window(ci: CanvasItem, c: Vector2, radius: float, glow: Color) -> void:
	ci.draw_circle(c + Vector2(0, 3), radius + 8, Color(0, 0, 0, 0.35))
	ci.draw_circle(c, radius + 7, Assets.color("case_dark"))
	ci.draw_circle(c, radius + 3, Assets.color("knob"))
	ci.draw_circle(c, radius, Assets.color("bezel"))
	ci.draw_circle(c, radius * 0.9, Color(glow, 0.06))
	# Glass highlight.
	ci.draw_arc(c, radius * 0.82, PI * 1.1, PI * 1.45, 16, Color(1, 1, 1, 0.18), 3.0, true)


## Silkscreen label printed on the case.
static func draw_print(ci: CanvasItem, font: Font, pos: Vector2, text: String, design_size: float,
		align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, col := Color(0, 0, 0, 0)) -> void:
	var c := Assets.color("case_print") if col.a == 0.0 else col
	ci.draw_string(font, pos, text, align, width, Assets.fs(design_size), c)
