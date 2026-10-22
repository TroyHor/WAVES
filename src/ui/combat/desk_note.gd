class_name DeskNote
extends Control
## A slip of paper lying on the desk with the operator's shift notes (turn
## number, twins swap countdown). Part of the duty log look (art_direction P4).

const X0 := 30.0
const PAD_Y := 18.0

var lines: PackedStringArray = []
## Screen y of the slip's bottom edge: its height follows the text, growing
## upward from here.
var bottom_y := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fit()


func set_lines(p: PackedStringArray) -> void:
	lines = p
	_fit()


## Places the slip: width `w`, bottom edge at `bottom`; height from the text.
func place(x: float, bottom: float, w: float) -> void:
	position.x = x
	bottom_y = bottom
	size.x = w
	_fit()


## Largest handwriting (design size) that fits every line in the width.
func _font_size() -> int:
	var font := get_theme_default_font()
	if font == null:
		return Assets.fs(22)
	for d in range(22, 11, -1):
		var fs := Assets.fs(d)
		var fits := true
		for l in lines:
			if font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > size.x - X0 - 8:
				fits = false
		if fits:
			return fs
	return Assets.fs(12)


func _line_h(fs: int) -> float:
	return fs + 12.0


func _fit() -> void:
	var lh := _line_h(_font_size())
	size.y = maxi(lines.size(), 1) * lh + PAD_Y * 2
	position.y = bottom_y - size.y
	pivot_offset = size * 0.5
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, Color("e8dcc0"))
	# Small strip of tape holding it up.
	draw_rect(Rect2(size.x * 0.5 - 30, -8, 60, 18), Color(1, 1, 0.92, 0.45))
	var ink := Color("3a3328")
	var x0 := X0
	draw_line(Vector2(x0 - 8, 6), Vector2(x0 - 8, size.y - 6), Color("d98a8a", 0.5), 1.0)
	var fs := _font_size()
	var lh := _line_h(fs)
	# Ruled lines under each line of text.
	var y0 := PAD_Y
	var y := y0 - lh
	while y < size.y - 6:
		if y > 6:
			draw_line(Vector2(10, y + 6), Vector2(size.x - 10, y + 6), Color("9cb4c8", 0.5), 1.0)
		y += lh
	for i in lines.size():
		draw_string(font, Vector2(x0, y0 + (i + 1) * lh - 2), lines[i], HORIZONTAL_ALIGNMENT_LEFT, size.x - x0 - 6, fs, ink)
