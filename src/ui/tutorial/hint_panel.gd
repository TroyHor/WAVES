class_name HintPanel
extends Control
## Tutorial hint: a pulsing frame around the anchored UI element plus a text
## box placed beside it. Only the box takes mouse input.

signal dismissed

var text := ""
var anchor_rect := Rect2()
var show_button := true
var _box: Panel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_box = Panel.new()
	_box.size = Vector2(700, 150)
	add_child(_box)
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.position = Vector2(22, 16)
	label.size = Vector2(_box.size.x - 44, 0)
	label.add_theme_font_size_override("font_size", Assets.fs(21))
	_box.add_child(label)
	var title := Label.new()
	title.text = "▸ 引导"
	title.add_theme_font_size_override("font_size", Assets.fs(15))
	title.add_theme_color_override("font_color", Assets.color("energy"))
	title.position = Vector2(22, -24)
	_box.add_child(title)
	await get_tree().process_frame
	var h := label.get_minimum_size().y + 40
	if show_button:
		var b := Button.new()
		b.text = "知道了"
		b.size = Vector2(150, 48)
		b.position = Vector2(_box.size.x - 170, h - 6)
		b.pressed.connect(func() -> void: dismissed.emit())
		_box.add_child(b)
		h += 54
	_box.size.y = h
	_place_box()


func _place_box() -> void:
	var view := size
	var x := clampf(anchor_rect.get_center().x - _box.size.x * 0.5, 20, view.x - _box.size.x - 20)
	var y := anchor_rect.end.y + 34
	if anchor_rect == Rect2() :
		y = view.y * 0.4
	elif y + _box.size.y > view.y - 20:
		y = anchor_rect.position.y - _box.size.y - 34
	_box.position = Vector2(x, clampf(y, 30, view.y - _box.size.y - 20))


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if anchor_rect == Rect2():
		return
	var a := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
	var col := Assets.color("energy")
	draw_rect(anchor_rect.grow(8 + a * 4), Color(col, 0.35 + a * 0.5), false, 3.0)
	draw_rect(anchor_rect.grow(16 + a * 6), Color(col, 0.15), false, 2.0)
