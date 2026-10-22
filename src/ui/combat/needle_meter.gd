class_name NeedleMeter
extends Control
## Analog panel meter for line integrity: cream dial with a printed scale, a
## needle on a damped spring (swings and overshoots on change), a thin red
## ghost needle showing where the previewed damage would leave it, and a digit
## window underneath with the exact value (no captions: the ghost needle and
## the scope's counters already say what the preview costs).

var value := 0
var max_value := 1
var preview_loss := 0
var color := Color("4fd8ff")
var _angle := 0.0
var _vel := 0.0
var _init_done := false

const A0 := PI * 1.12
const A1 := PI * 1.88


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(p_value: int, p_max: int, p_loss: int) -> void:
	value = p_value
	max_value = maxi(1, p_max)
	preview_loss = clampi(p_loss, 0, p_value)


func _ratio_angle(v: float) -> float:
	return lerpf(A0, A1, clampf(v / max_value, 0.0, 1.0))


func _process(delta: float) -> void:
	var target := _ratio_angle(value)
	if not _init_done:
		_angle = target
		_init_done = true
	# Damped spring: the needle swings past the target and settles.
	_vel += (target - _angle) * 90.0 * delta
	_vel *= pow(0.02, delta)
	_angle += _vel * delta
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var dial_h := minf(size.y * 0.58, (size.x - 8) * 0.72)
	var dial := Rect2(4, 0, size.x - 8, dial_h)
	var face := StyleBoxFlat.new()
	face.bg_color = Color("ece5d2")
	face.set_corner_radius_all(InstrumentStyle.WINDOW_RADIUS)
	draw_style_box(face, dial)
	var pivot := Vector2(dial.get_center().x, dial.end.y - 14)
	var rad := minf(dial.size.x * 0.47, dial.size.y - 30)
	var ink := Color("2b2620")
	# Red zone for the lowest fifth of the scale.
	draw_arc(pivot, rad * 0.86, A0, lerpf(A0, A1, 0.2), 24, Color("c8352b"), 6.0, true)
	draw_arc(pivot, rad * 0.86, lerpf(A0, A1, 0.2), A1, 48, Color(ink, 0.7), 2.0, true)
	for i in 11:
		var a := lerpf(A0, A1, i / 10.0)
		var d := Vector2(cos(a), sin(a))
		var l := 12.0 if i % 5 == 0 else 6.0
		draw_line(pivot + d * (rad * 0.86 - l), pivot + d * rad * 0.86, ink, 2.0 if i % 5 == 0 else 1.0)
	for e in [[A0, "0"], [A1, str(max_value)]]:
		var d := Vector2(cos(e[0]), sin(e[0]))
		draw_string(font, pivot + d * rad * 0.62 + Vector2(-30, 6), e[1], HORIZONTAL_ALIGNMENT_CENTER, 60, Assets.fs(13), Color(ink, 0.75))
	if preview_loss > 0:
		var ga := _ratio_angle(value - preview_loss)
		draw_line(pivot, pivot + Vector2(cos(ga), sin(ga)) * rad * 0.9, Color("c8352b", 0.75), 2.0, true)
	draw_line(pivot + Vector2(2, 3), pivot + Vector2(cos(_angle), sin(_angle)) * rad * 0.92 + Vector2(2, 3), Color(0, 0, 0, 0.25), 3.0, true)
	draw_line(pivot, pivot + Vector2(cos(_angle), sin(_angle)) * rad * 0.92, ink, 3.0, true)
	draw_circle(pivot, 7.0, ink)
	draw_circle(pivot, 3.0, Color("8a8478"))
	# Digit window: exact value.
	var fs := Assets.fs(40)
	var y := dial_h + 14 + fs
	var big := str(value)
	var bw := font.get_string_size(big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var small := "/%d" % max_value
	var sw := font.get_string_size(small, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.5)).x
	var x := (size.x - bw - sw - 4) * 0.5
	draw_string(font, Vector2(x, y), big, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	draw_string(font, Vector2(x + bw + 4, y), small, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs * 0.5), Color(color, 0.7))
