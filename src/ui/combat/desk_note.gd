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
	var ink := Color("3a3328")
	var lh := Assets.fs(22) + 10.0
	var y := 26.0
	draw_string(font, Vector2(18, y + 8), "值班记录", HORIZONTAL_ALIGNMENT_LEFT, -1, Assets.fs(16), Color(ink, 0.6))
	y += 22.0
	while y < size.y - 10:
		draw_line(Vector2(12, y + 8), Vector2(size.x - 12, y + 8), Color("9cb4c8", 0.5), 1.0)
		y += lh
	draw_line(Vector2(34, 6), Vector2(34, size.y - 6), Color("d98a8a", 0.5), 1.0)
	for i in lines.size():
		draw_string(font, Vector2(44, 48 + (i + 1) * lh - 6), lines[i], HORIZONTAL_ALIGNMENT_LEFT, size.x - 52, Assets.fs(22), ink)
