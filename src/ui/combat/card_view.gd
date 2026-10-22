class_name CardView
extends Control
## A card drawn as a small instrument module with its own mini scope.

signal grabbed(view: CardView)

const CARD_SIZE := Vector2(156, 214)

var card: CardInstance
var playable := true
var flipped := false
## Ghost = the copy following the mouse while dragging.
var ghost := false
var _hovered := false
var _t := randf() * 10.0
## Resting scale: hand cards are held small, the enlarged card is big.
var base_scale := 1.0


func _init(p_card: CardInstance) -> void:
	card = p_card
	custom_minimum_size = CARD_SIZE
	size = CARD_SIZE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE if ghost else Control.MOUSE_FILTER_STOP
	# Scale from the bottom centre so held cards grow upward onto the desk.
	pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
	mouse_entered.connect(func() -> void: _hovered = true; queue_redraw())
	mouse_exited.connect(func() -> void: _hovered = false; queue_redraw())


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		grabbed.emit(self)
		accept_event()


## Gentle idle sway; hovering straightens the card and lifts it.
func _process(delta: float) -> void:
	_t += delta
	var target := 0.0 if (_hovered or ghost) else sin(_t * 1.3) * 0.025
	rotation = lerpf(rotation, target, minf(1.0, delta * 8.0))
	var s := base_scale * (1.12 if _hovered and not ghost else 1.0)
	scale = scale.lerp(Vector2(s, s), minf(1.0, delta * 12.0))


func _draw() -> void:
	var font := get_theme_default_font()
	var lift := -16.0 if _hovered and playable and not ghost else 0.0
	var accent := Assets.color("player_wave") if playable else Assets.color("disabled")
	var text := Assets.color("text") if playable else Assets.color("text_dim")
	var r := Rect2(Vector2(0, lift), CARD_SIZE)

	draw_rect(r, Color(Assets.color("panel"), 0.92 if ghost else 1.0))
	draw_rect(r, accent, false, 2.0 if not _hovered else 3.0)

	# Cost badge.
	var badge := Vector2(24, 24 + lift)
	draw_circle(badge, 17, Assets.color("energy") if playable else Assets.color("disabled"))
	draw_string(font, badge + Vector2(-17, 8), str(card.data.cost), HORIZONTAL_ALIGNMENT_CENTER, 34, Assets.fs(22), Assets.color("background"))
	draw_string(font, Vector2(48, 32 + lift), card.data.name, HORIZONTAL_ALIGNMENT_LEFT, 100, Assets.fs(20), text)

	# Mini scope with the waveform.
	var sr := Rect2(10, 48 + lift, CARD_SIZE.x - 20, 82)
	draw_rect(sr, Assets.color("screen"))
	draw_line(Vector2(sr.position.x, sr.get_center().y), Vector2(sr.end.x, sr.get_center().y), Assets.color("grid_major"), 1.0)
	var wave := card.data.wave
	if flipped:
		wave = WaveMath.invert(wave)
	if wave.is_empty():
		draw_string(font, Vector2(sr.position.x, sr.get_center().y + 8), "— 无波形 —", HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, Assets.fs(16), Assets.color("text_dim"))
	else:
		_draw_mini_wave(wave, sr, accent)

	var rules := card.data.rules_text()
	if rules != "":
		draw_multiline_string(font, Vector2(10, 152 + lift), rules, HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 20, Assets.fs(15), 3, Assets.color("text_dim"))
	if not wave.is_empty():
		var nums := ",".join(Array(wave).map(func(v: int) -> String: return str(v)))
		draw_string(font, Vector2(10, CARD_SIZE.y - 10 + lift), "[%s]" % nums, HORIZONTAL_ALIGNMENT_LEFT, CARD_SIZE.x - 20, Assets.fs(13), Color(accent, 0.7))


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
