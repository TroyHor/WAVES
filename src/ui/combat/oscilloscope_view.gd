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
## Embedded in a larger device face: skip the outer shell (hood, plate and
## knobs are still drawn).
var embedded := false
var show_plate := true
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
	_tube.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
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
	var tr := tube_rect()
	if not embedded:
		_draw_case(full)
	_draw_hood(tr)
	# Name plate on the left: black label with light print, like the badge
	# on vintage bench scopes.
	var plate := Rect2(16, tr.get_center().y - 40, tr.position.x - 40, 80)
	if show_plate and plate.size.x > 40:
		InstrumentStyle.draw_plate(self, plate)
		draw_string(font, Vector2(plate.position.x, plate.position.y + 34), title, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, Assets.fs(20), Assets.color("plate"))
		draw_string(font, Vector2(plate.position.x, plate.position.y + 62), "OSC-16", HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, Assets.fs(12), Color(Assets.color("plate"), 0.6))
	# Two knurled knobs and the power lamp on the right.
	var kx := tr.end.x + 26
	var kw := size.x - kx - 14
	if kw > 40:
		var rad := minf(kw * 0.34, 26.0)
		var labels := ["亮度", "聚焦"]
		for i in 2:
			var c := Vector2(kx + kw * 0.5, tr.position.y + tr.size.y * (0.3 + 0.42 * i))
			_draw_knob(c, rad, -2.3 + i * 1.4)
			draw_string(font, Vector2(kx - 8, c.y + rad + Assets.fs(12) + 4), labels[i], HORIZONTAL_ALIGNMENT_CENTER, kw + 16, Assets.fs(10), Assets.color("case_print"))
		var led := Vector2(kx + kw * 0.5, tr.position.y + 6)
		draw_circle(led, 9, Color(accent, 0.25))
		draw_circle(led, 5, accent)
		draw_circle(led + Vector2(-1.5, -1.5), 1.5, Color(1, 1, 1, 0.8))


func _draw_case(r: Rect2) -> void:
	InstrumentStyle.draw_case(self, r, InstrumentStyle.CASE_RADIUS, 0.0, Assets.texture("item_main_scope"))


## Dark recessed surround for the tube (no screws, kept simple).
func _draw_hood(tr: Rect2) -> void:
	var hood := StyleBoxFlat.new()
	hood.bg_color = Assets.color("bezel")
	hood.set_corner_radius_all(InstrumentStyle.WINDOW_RADIUS + 4)
	hood.border_color = Color(Assets.color("case_dark"), 1.0)
	hood.set_border_width_all(3)
	draw_style_box(hood, tr.grow(12))
	draw_rect(tr.grow(3), Color(0, 0, 0, 0.8), false, 3.0)


## Knurled black knob with a brushed silver cap and an indicator line.
func _draw_knob(c: Vector2, rad: float, angle: float) -> void:
	draw_circle(c + Vector2(2, 3), rad + 2, Color(0, 0, 0, 0.35))
	draw_circle(c, rad, Assets.color("knob"))
	for k in 28:
		var a := TAU * k / 28.0
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * rad * 0.82, c + d * rad, Color(1, 1, 1, 0.12), 1.5)
	draw_circle(c, rad * 0.58, Assets.color("knob_cap"))
	draw_circle(c - Vector2(rad, rad) * 0.15, rad * 0.3, Color(1, 1, 1, 0.25))
	draw_line(c, c + Vector2(cos(angle), sin(angle)) * rad * 0.55, Assets.color("knob"), 2.5)
