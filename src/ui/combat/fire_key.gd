class_name FireKey
extends Control
## The transmitter's fire key: a glossy red mushroom cap on a chrome collar,
## mounted on a square brushed-metal plate with four screws. Seen slightly from
## above, so the cap's side shows above its face; pressing sinks the cap into
## the collar and springs it back. Drawn only — the click area is the combat
## screen's invisible _resolve_btn, which calls press().

const RED := Color("d2291f")

var disabled := false:
	set(v):
		disabled = v
		queue_redraw()
var hovered := false:
	set(v):
		hovered = v
		queue_redraw()
## 0 = up, 1 = fully pressed.
var press_amount := 0.0:
	set(v):
		press_amount = v
		queue_redraw()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Press-and-release animation.
func press() -> void:
	var tw := create_tween()
	tw.tween_property(self, "press_amount", 1.0, 0.07).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.08)
	tw.tween_property(self, "press_amount", 0.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var plate := Rect2((size - Vector2(s, s)) * 0.5, Vector2(s, s))
	var c := plate.get_center()
	# Plate: shadow, brushed metal, bevelled rim.
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(int(s * 0.06))
	sb.bg_color = Color("9da3a8")
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 4)
	sb.border_width_top = 3
	sb.border_width_left = 2
	sb.border_color = Color("dfe3e6")
	draw_style_box(sb, plate)
	for i in 8:
		var y := plate.position.y + plate.size.y * (i + 0.5) / 8.0
		draw_line(Vector2(plate.position.x + 6, y), Vector2(plate.end.x - 6, y), Color(1, 1, 1, 0.06 + 0.04 * (i % 2)), plate.size.y / 10.0)
	draw_line(Vector2(plate.position.x + 4, plate.end.y - 2), Vector2(plate.end.x - 4, plate.end.y - 2), Color(0, 0, 0, 0.35), 3.0)
	for k in 4:
		var sp := plate.position + Vector2(s * (0.11 if k % 2 == 0 else 0.89), s * (0.11 if k < 2 else 0.89))
		draw_circle(sp, s * 0.035, Color("5d6368"))
		draw_circle(sp - Vector2(0.6, 0.6), s * 0.028, Color("c9ced2"))
		draw_line(sp - Vector2(s * 0.02, -s * 0.02), sp + Vector2(s * 0.02, -s * 0.02), Color("4b5054"), 1.5)
	# Recess and chrome collar (concentric rings, light from above).
	var rr := s * 0.4
	draw_circle(c, rr, Color("3b3f43"))
	draw_circle(c, rr * 0.92, Color("7b8287"))
	draw_arc(c, rr * 0.92, PI * 1.05, PI * 1.95, 24, Color(1, 1, 1, 0.55), 2.0, true)
	var collar := rr * 0.72
	draw_circle(c, collar, Color("c4cacf"))
	draw_circle(c, collar * 0.86, Color("80878c"))
	draw_arc(c, collar * 0.93, PI * 1.1, PI * 1.9, 24, Color(1, 1, 1, 0.8), 2.0, true)
	# Cap: a short red cylinder sticking out toward the operator. Seen from
	# above, its face sits lower than its base and the top of its side shows.
	var cap_r := s * 0.34
	var travel := s * 0.1 * (1.0 - press_amount * 0.75)
	var base := c - Vector2(0, travel * 0.15)
	var face := c + Vector2(0, travel * 0.55)
	var red := RED if not disabled else Color("7d5f58")
	if hovered and not disabled:
		red = red.lightened(0.1)
	# Cast shadow on the collar.
	draw_circle(face + Vector2(0, travel * 0.6 + 2), cap_r, Color(0, 0, 0, 0.3))
	var side := PackedVector2Array()
	for i in 33:
		var a := PI + PI * i / 32.0
		side.append(base + Vector2(cos(a), sin(a)) * cap_r)
	for i in 33:
		var a := TAU - PI * i / 32.0
		side.append(face + Vector2(cos(a), sin(a)) * cap_r)
	draw_colored_polygon(side, red.darkened(0.35))
	draw_circle(face, cap_r, red)
	# Dome shading: darker lower rim, soft gloss and a sharp highlight.
	draw_arc(face, cap_r * 0.9, PI * 0.15, PI * 0.85, 24, Color(red.darkened(0.3), 0.8), cap_r * 0.18, true)
	draw_circle(face + Vector2(-cap_r * 0.1, -cap_r * 0.25), cap_r * 0.62, Color(1, 1, 1, 0.1))
	draw_arc(face, cap_r * 0.72, PI * 1.15, PI * 1.55, 16, Color(1, 1, 1, 0.75 if not disabled else 0.3), cap_r * 0.1, true)
	draw_circle(face + Vector2(cap_r * 0.42, -cap_r * 0.42), cap_r * 0.07, Color(1, 1, 1, 0.6))
