class_name DeskNote
extends Control
## A slip of paper lying on the desk with the operator's shift notes (turn
## number, twins swap countdown). Part of the duty log look (art_direction P4).

var lines: PackedStringArray = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = size * 0.5


func set_lines(p: PackedStringArray) -> void:
	lines = p
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, Color("e8dcc0"))
	# Small strip of tape holding it up.
	draw_rect(Rect2(size.x * 0.5 - 30, -8, 60, 18), Color(1, 1, 0.92, 0.45))
	var ink := Color("3a3328")
	var x0 := 30.0
	draw_line(Vector2(x0 - 8, 6), Vector2(x0 - 8, size.y - 6), Color("d98a8a", 0.5), 1.0)
	# Largest handwriting that fits every line in the slip's width.
	var fs := Assets.fs(22)
	for d in range(22, 11, -1):
		fs = Assets.fs(d)
		var fits := true
		for l in lines:
			if font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - x0 - 8:
				fits = false
		if fits:
			break
	var lh := fs + 12.0
	# Ruled lines, with the text block centred vertically.
	var y0 := maxf(14.0, (size.y - lh * lines.size()) * 0.5)
	var y := y0 - lh
	while y < size.y - 6:
		if y > 6:
			draw_line(Vector2(10, y + 6), Vector2(size.x - 10, y + 6), Color("9cb4c8", 0.5), 1.0)
		y += lh
	for i in lines.size():
		draw_string(font, Vector2(x0, y0 + (i + 1) * lh - 2), lines[i], HORIZONTAL_ALIGNMENT_LEFT, size.x - x0 - 6, fs, ink)
