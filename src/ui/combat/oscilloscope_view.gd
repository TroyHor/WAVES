class_name OscilloscopeView
extends Control
## A bench oscilloscope: drawn case, bezel, name plate, knobs and LED, around
## a CRT tube. The tube is a SubViewport (any `screen` Control with grid_x0 /
## grid_w properties) shown through tube.gdshader, so its edge distortion is
## local to this instrument. Optionally an ink-green flowing-wave backdrop
## glows behind the traces, and `bottom_pad` leaves case space for a readout.

const TUBE_SHADER := preload("res://src/ui/crt/tube.gdshader")
const FLOW_SHADER := preload("res://src/ui/crt/scope_flow.gdshader")
## Tube glass beyond the grid on each side (absorbs the barrel bulge).
const TUBE_MARGIN := 26.0
const TUBE_PAD_Y := 14.0

var title := ""
var accent := Color.WHITE
var screen: Control
var flow_background := false
## Case space reserved under the tube (e.g. for a readout strip).
var bottom_pad := 0.0
## Grid x-range in this control's local coordinates (set by the layout).
var grid_x0 := 100.0
var grid_x1 := 900.0
var _vp: SubViewport
var _tube: TextureRect
var _t := 0.0


var _flow: ColorRect


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.disable_3d = true
	_vp.transparent_bg = false
	_vp.gui_disable_input = true
	add_child(_vp)
	if flow_background:
		_flow = ColorRect.new()
		var fm := ShaderMaterial.new()
		fm.shader = FLOW_SHADER
		_flow.material = fm
		_vp.add_child(_flow)
	# Themes don't propagate through a SubViewport; set it explicitly.
	screen.theme = ThemeFactory.shared()
	_vp.add_child(screen)
	_tube = TextureRect.new()
	_tube.texture = _vp.get_texture()
	_tube.stretch_mode = TextureRect.STRETCH_SCALE
	_tube.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = TUBE_SHADER
	for key in Assets.TUBE:
		mat.set_shader_parameter(key, Assets.TUBE[key])
	_tube.material = mat
	add_child(_tube)
	resized.connect(layout_tube)
	layout_tube()


func tube_rect() -> Rect2:
	return Rect2(grid_x0 - TUBE_MARGIN, TUBE_PAD_Y, grid_x1 - grid_x0 + TUBE_MARGIN * 2, size.y - TUBE_PAD_Y * 2 - bottom_pad)


func layout_tube() -> void:
	if _tube == null:
		return
	var r := tube_rect()
	_tube.position = r.position
	_tube.size = r.size
	_vp.size = Vector2i(r.size)
	screen.size = r.size
	screen.set("grid_x0", TUBE_MARGIN)
	screen.set("grid_w", grid_x1 - grid_x0)
	if _flow != null:
		_flow.size = r.size
		(_flow.material as ShaderMaterial).set_shader_parameter("aspect", r.size.x / maxf(1.0, r.size.y))
	(_tube.material as ShaderMaterial).set_shader_parameter("tube_size", r.size)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var full := Rect2(Vector2.ZERO, size)
	# Case.
	draw_rect(full, Assets.color("case"))
	draw_rect(full, Assets.color("case_edge"), false, 3.0)
	draw_rect(full.grow(-6), Color(Assets.color("case_edge"), 0.35), false, 1.0)
	# Bezel around the tube.
	var tr := tube_rect()
	draw_rect(tr.grow(8), Assets.color("bezel"))
	draw_rect(tr.grow(8), Color(Assets.color("case_edge"), 0.8), false, 2.0)
	draw_rect(tr.grow(3), Color(0, 0, 0, 0.6), false, 3.0)
	# Screws.
	for p in [Vector2(12, 12), Vector2(size.x - 12, 12), Vector2(12, size.y - 12), Vector2(size.x - 12, size.y - 12)]:
		draw_circle(p, 4.0, Assets.color("knob"))
		draw_line(p - Vector2(3, 0), p + Vector2(3, 0), Assets.color("bezel"), 1.5)
	# Name plate (left of the tube).
	var plate := Rect2(14, tr.get_center().y - 34, tr.position.x - 34, 68)
	if plate.size.x > 30:
		draw_rect(plate, Color(Assets.color("plate"), 0.12))
		draw_rect(plate, Color(Assets.color("plate"), 0.35), false, 1.0)
		draw_string(font, Vector2(plate.position.x, plate.position.y + 28), title, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, Assets.fs(18), accent)
		draw_string(font, Vector2(plate.position.x, plate.position.y + 52), "OSC-16", HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, Assets.fs(13), Color(Assets.color("plate"), 0.6))
	# Knobs and LED (right of the tube).
	var kx := tr.end.x + 20
	var kw := size.x - kx - 14
	if kw > 40:
		var labels := ["V/DIV", "T/DIV"]
		for i in 2:
			var c := Vector2(kx + kw * 0.5, tr.position.y + tr.size.y * (0.3 + 0.42 * i))
			var rad := minf(kw * 0.32, 20.0)
			draw_circle(c, rad + 3, Assets.color("bezel"))
			draw_circle(c, rad, Assets.color("knob"))
			var ang := -2.2 + i * 1.3 + sin(_t * 0.3 + i) * 0.05
			draw_line(c, c + Vector2(cos(ang), sin(ang)) * rad * 0.85, Assets.color("plate"), 2.0)
			draw_string(font, Vector2(kx, c.y + rad + 16), labels[i], HORIZONTAL_ALIGNMENT_CENTER, kw, Assets.fs(11), Color(Assets.color("plate"), 0.5))
		var led := Vector2(kx + kw * 0.5, 14 + 6)
		draw_circle(led, 8, Color(accent, 0.18))
		draw_circle(led, 4, accent)
