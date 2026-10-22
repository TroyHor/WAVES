class_name DeskNote
extends Control
## A slip of duty-log paper (ruled lines, margin, tape). Used for the turn note
## taped to the scope unit and, with `wrap` on, for tutorial hint slips
## (HintSlip) — one family of paper (art_direction P4).

signal ticked

const X0 := 30.0
const PAD_Y := 18.0
## Tick box (design px) at the end of the last line when `tick_box` is on.
const TICK := 30.0

var lines: PackedStringArray = []
## Wrap each line (paragraph) to the width, breaking between characters.
var wrap := false
## Handwriting size range (design sizes): the largest that fits is used.
var max_design := 22
var min_design := 12
## With `wrap`: tallest the slip may get (the font shrinks to fit first).
var max_h := INF
## A box to tick ("seen"); clicking it emits `ticked`.
var tick_box := false
var is_ticked := false
## Screen y of the slip's bottom edge (grows upward), or of its top edge when
## `grow_down` (hangs from its tape).
var bottom_y := 0.0
var grow_down := false
var _shown: PackedStringArray = []
var _fs := 0
var _tick_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if tick_box:
		_tick_btn = Button.new()
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			_tick_btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
		_tick_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_tick_btn.pressed.connect(_on_tick)
		add_child(_tick_btn)
	_fit()


func set_lines(p: PackedStringArray) -> void:
	lines = p
	_fit()


## Places the slip: width `w`, bottom edge at `bottom` (top edge when
## `grow_down`); height from the text.
func place(x: float, bottom: float, w: float) -> void:
	position.x = x
	bottom_y = bottom
	size.x = w
	_fit()


## Height the slip needs at width `w` (for choosing where a hint fits).
func height_for(w: float) -> float:
	var old := size.x
	size.x = w
	var fs := _font_size()
	var h := _height(_layout(fs), fs)
	size.x = old
	return h


func tick_rect() -> Rect2:
	var t := TICK * Assets.FONT_SCALE
	var lh := _line_h(_fs)
	var base := PAD_Y + maxi(_shown.size(), 1) * lh
	return Rect2(size.x - t - 14.0, base - t + 2.0, t, t)


func _on_tick() -> void:
	if is_ticked:
		return
	is_ticked = true
	queue_redraw()
	ticked.emit()


func _text_w() -> float:
	return size.x - X0 - 10.0


## Lines as drawn at font size `fs` (wrapped when `wrap`).
func _layout(fs: int) -> PackedStringArray:
	if not wrap:
		return lines
	var font := get_theme_default_font()
	var out := PackedStringArray()
	for para in lines:
		var cur := ""
		for ch in para:
			var cand := cur + ch
			if cur == "" or font.get_string_size(cand, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= _text_w():
				cur = cand
			elif _closing(ch) and cur.length() > 1:
				# Closing punctuation never starts a line: take the character
				# before it along.
				out.append(cur.left(-1))
				cur = cur.right(1) + ch
			else:
				out.append(cur)
				cur = ch
		out.append(cur)
	# The tick box sits at the end of the last line; it gets its own if full.
	if tick_box and font.get_string_size(out[out.size() - 1], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x \
			> _text_w() - TICK * Assets.FONT_SCALE - 12.0:
		out.append("")
	return out


static func _closing(ch: String) -> bool:
	return ch in "，。、；：！？）」』”’》,.;:!?)"


func _font_size() -> int:
	var font := get_theme_default_font()
	if font == null:
		return Assets.fs(max_design)
	for d in range(max_design, min_design - 1, -1):
		var fs := Assets.fs(d)
		if wrap:
			if _height(_layout(fs), fs) <= max_h:
				return fs
			continue
		var fits := true
		for l in lines:
			if font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > _text_w():
				fits = false
		if fits:
			return fs
	return Assets.fs(min_design)


func _line_h(fs: int) -> float:
	return fs + 12.0


func _height(shown: PackedStringArray, fs: int) -> float:
	return maxi(shown.size(), 1) * _line_h(fs) + PAD_Y * 2


func _fit() -> void:
	_fs = _font_size()
	_shown = _layout(_fs)
	size.y = _height(_shown, _fs)
	position.y = bottom_y if grow_down else bottom_y - size.y
	pivot_offset = Vector2(size.x * 0.5, 0.0) if grow_down else size * 0.5
	if _tick_btn != null:
		_tick_btn.position = tick_rect().position
		_tick_btn.size = tick_rect().size
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var r := Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(r.position + Vector2(6, 8), r.size), Color(0, 0, 0, 0.3))
	draw_rect(r, Assets.color("paper"))
	# Small strip of tape holding it up.
	draw_rect(Rect2(size.x * 0.5 - 30, -8, 60, 18), Assets.color("tape"))
	var ink := Assets.color("paper_ink")
	var x0 := X0
	draw_line(Vector2(x0 - 8, 6), Vector2(x0 - 8, size.y - 6), Assets.color("paper_margin"), 1.0)
	var lh := _line_h(_fs)
	# Ruled lines under each line of text.
	var y0 := PAD_Y
	var y := y0 - lh
	while y < size.y - 6:
		if y > 6:
			draw_line(Vector2(10, y + 6), Vector2(size.x - 10, y + 6), Assets.color("paper_rule"), 1.0)
		y += lh
	for i in _shown.size():
		draw_string(font, Vector2(x0, y0 + (i + 1) * lh - 2), _shown[i], HORIZONTAL_ALIGNMENT_LEFT, size.x - x0 - 6, _fs, ink)
	if tick_box:
		var b := tick_rect()
		draw_rect(b, Color(ink, 0.85), false, 2.0)
		if is_ticked:
			var p := b.position
			var s := b.size.x
			draw_polyline(PackedVector2Array([p + Vector2(s * 0.15, s * 0.5), p + Vector2(s * 0.42, s * 0.8),
				p + Vector2(s * 1.05, -s * 0.15)]), ink, 3.5, true)
