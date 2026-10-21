class_name CardView
extends Control
## A card drawn as a small instrument module with its own mini scope.

signal grabbed(view: CardView)

const CARD_SIZE := Vector2(176, 244)

var card: CardInstance
var playable := true
var flipped := false
## Ghost = the copy following the mouse while dragging.
var ghost := false
var _hovered := false


func _init(p_card: CardInstance) -> void:
	card = p_card
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if ghost else Control.MOUSE_FILTER_STOP
	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grabbed.emit(self)
		accept_event()


func _draw() -> void:
	var font := get_theme_default_font()
	var lift := -20.0 if _hovered and playable and not ghost else 0.0
	var accent := Assets.color("player_wave") if playable else Assets.color("disabled")
	var text := Assets.color("text") if playable else Assets.color("text_dim")
	var r := Rect2(Vector2(0, lift), CARD_SIZE)

	draw_rect(r, Color(Assets.color("panel"), 0.92 if ghost else 1.0))
	draw_rect(r, accent, false, 2.0 if not _hovered else 3.0)

	# Cost badge.
	var badge := Vector2(24, 24 + lift)
	draw_circle(badge, 17, Assets.color("energy") if playable else Assets.color("disabled"))
	draw_string(font, badge + Vector2(-17, 8), str(card.data.cost), HORIZONTAL_ALIGNMENT_CENTER, 34, 22, Assets.color("background"))
	draw_string(font, Vector2(50, 32 + lift), card.data.name, HORIZONTAL_ALIGNMENT_LEFT, 118, 22, text)

	# Mini scope with the waveform.
	var sr := Rect2(12, 50 + lift, CARD_SIZE.x - 24, 96)
	draw_rect(sr, Assets.color("screen"))
	draw_line(Vector2(sr.position.x, sr.get_center().y), Vector2(sr.end.x, sr.get_center().y), Assets.color("grid_major"), 1.0)
	var wave := card.data.wave
	if flipped:
		wave = WaveMath.invert(wave)
	if wave.is_empty():
		draw_string(font, Vector2(sr.position.x, sr.get_center().y + 8), "— 无波形 —", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 16, Assets.color("text_dim"))
	else:
		_draw_mini_wave(wave, sr, accent)

	var rules := card.data.rules_text()
	if rules != "":
		draw_multiline_string(font, Vector2(12, 172 + lift), rules, HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 24, 16, 3, Assets.color("text_dim"))
	if not wave.is_empty():
		var nums := ",".join(Array(wave).map(func(v: int) -> String: return str(v)))
		draw_string(font, Vector2(12, CARD_SIZE.y - 12 + lift), "[%s]" % nums, HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 24, 14, Color(accent, 0.7))


func _draw_mini_wave(wave: PackedInt32Array, sr: Rect2, color: Color) -> void:
	var m := 6.0
	for v in wave:
		m = maxf(m, absf(v))
	var step := sr.size.x / (wave.size() + 1)
	var pts := PackedVector2Array()
	for i in wave.size():
		var p := Vector2(sr.position.x + step * (i + 1), sr.get_center().y - wave[i] / m * sr.size.y * 0.44)
		pts.append(p)
		draw_line(Vector2(p.x, sr.get_center().y), p, Color(color, 0.45), 2.0)
		draw_circle(p, 3.0, color)
	if pts.size() > 1:
		draw_polyline(pts, color, 2.0, true)
