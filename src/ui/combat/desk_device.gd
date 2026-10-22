class_name DeskDevice
extends Control
## An instrument on the desk. Its face is laid out flat in `content` (rendered
## in a SubViewport at `flat_size`) and shown through a projective quad warp,
## so it can stand upright (top wider than bottom) or lie flat on the desk
## (far edge narrower). Effect positions and input are mapped through the same
## homography: flat_to_screen() / screen_to_flat().

const WARP_SHADER := preload("res://src/ui/crt/desk_warp.gdshader")

var flat_size := Vector2(1000, 500)
var content := Control.new()
## Screen-space corners TL, TR, BR, BL (in the parent's coordinates).
var quad := PackedVector2Array()
## Soft contact shadow cast onto the desk below the device.
var cast_shadow := true
var _vp: SubViewport
var _tex: TextureRect
var _mat: ShaderMaterial
var _h := []      ## flat uv (0..1) -> local pixel
var _hinv := []   ## local pixel -> flat uv
var _shake := 0.0
var _shake_t := 0.0
var _base_pos := Vector2.ZERO


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_vp = SubViewport.new()
	_vp.disable_3d = true
	_vp.transparent_bg = true
	_vp.gui_disable_input = true
	_vp.size = Vector2i(flat_size)
	add_child(_vp)
	content.theme = ThemeFactory.shared()
	content.size = flat_size
	_vp.add_child(content)
	_tex = TextureRect.new()
	_tex.texture = _vp.get_texture()
	_tex.stretch_mode = TextureRect.STRETCH_SCALE
	# The flat face is usually larger than its on-screen quad: never let the
	# texture size dictate the rect size.
	_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = WARP_SHADER
	_tex.material = _mat
	add_child(_tex)


## Places the device: `corners` are TL, TR, BR, BL in the parent's coordinates.
func set_quad(corners: PackedVector2Array) -> void:
	var lo := corners[0]
	var hi := corners[0]
	for c in corners:
		lo = lo.min(c)
		hi = hi.max(c)
	_base_pos = lo
	position = lo
	size = hi - lo
	quad = PackedVector2Array()
	for c in corners:
		quad.append(c - lo)
	_h = _square_to_quad(quad)
	_hinv = _invert(_h)
	if _tex != null:
		_tex.size = size
		_mat.set_shader_parameter("rect_size", size)
		_mat.set_shader_parameter("flat_size", flat_size)
		_mat.set_shader_parameter("inv_h", Basis(
			Vector3(_hinv[0], _hinv[3], _hinv[6]),
			Vector3(_hinv[1], _hinv[4], _hinv[7]),
			Vector3(_hinv[2], _hinv[5], _hinv[8])))
	queue_redraw()


## Flat face coordinates -> global screen position.
func flat_to_screen(p: Vector2) -> Vector2:
	return global_position + _apply(_h, p / flat_size)


## Global screen position -> flat face coordinates (may fall outside the face).
func screen_to_flat(p: Vector2) -> Vector2:
	return _apply(_hinv, p - global_position) * flat_size


func contains_screen(p: Vector2) -> bool:
	var f := screen_to_flat(p)
	return Rect2(Vector2.ZERO, flat_size).has_point(f)


## Screen-space bounding rect of a flat rect (for highlights / hit areas).
func flat_rect_to_screen(r: Rect2) -> Rect2:
	var pts := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	var lo: Vector2 = flat_to_screen(pts[0])
	var hi := lo
	for p in pts:
		var s := flat_to_screen(p)
		lo = lo.min(s)
		hi = hi.max(s)
	return Rect2(lo, hi - lo)


## Short damped tremble (e.g. the transmitter when power is full).
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)
	_shake_t = 0.0


func _process(delta: float) -> void:
	if _shake > 0.0:
		_shake_t += delta
		_shake = move_toward(_shake, 0.0, delta * 1.8)
		position = _base_pos + Vector2(sin(_shake_t * 55.0), cos(_shake_t * 47.0) * 0.4) * _shake * 6.0
	elif position != _base_pos:
		position = _base_pos


func _draw() -> void:
	if not cast_shadow or quad.size() < 4:
		return
	# Contact shadow: the footprint pushed down and spread a little.
	for i in 4:
		var g := 6.0 + i * 7.0
		var pts := PackedVector2Array()
		var c := (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
		for q in quad:
			pts.append(c + (q - c) * (1.0 + g / maxf(size.x, 1.0)) + Vector2(0, 10.0 + i * 3.0))
		draw_colored_polygon(pts, Color(0, 0, 0, 0.11))


# --- Homography helpers (3x3 row-major arrays) -------------------------------

static func _square_to_quad(q: PackedVector2Array) -> Array:
	var dx1 := q[1].x - q[2].x
	var dx2 := q[3].x - q[2].x
	var dx3 := q[0].x - q[1].x + q[2].x - q[3].x
	var dy1 := q[1].y - q[2].y
	var dy2 := q[3].y - q[2].y
	var dy3 := q[0].y - q[1].y + q[2].y - q[3].y
	var den := dx1 * dy2 - dx2 * dy1
	var g := 0.0
	var h := 0.0
	if absf(den) > 1e-9:
		g = (dx3 * dy2 - dx2 * dy3) / den
		h = (dx1 * dy3 - dx3 * dy1) / den
	return [
		q[1].x - q[0].x + g * q[1].x, q[3].x - q[0].x + h * q[3].x, q[0].x,
		q[1].y - q[0].y + g * q[1].y, q[3].y - q[0].y + h * q[3].y, q[0].y,
		g, h, 1.0]


static func _apply(m: Array, p: Vector2) -> Vector2:
	var w: float = m[6] * p.x + m[7] * p.y + m[8]
	return Vector2((m[0] * p.x + m[1] * p.y + m[2]) / w, (m[3] * p.x + m[4] * p.y + m[5]) / w)


static func _invert(m: Array) -> Array:
	var a: float = m[0]; var b: float = m[1]; var c: float = m[2]
	var d: float = m[3]; var e: float = m[4]; var f: float = m[5]
	var g: float = m[6]; var h: float = m[7]; var i: float = m[8]
	var A := e * i - f * h
	var B := -(d * i - f * g)
	var C := d * h - e * g
	var det := a * A + b * B + c * C
	if absf(det) < 1e-12:
		return [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0]
	var inv := 1.0 / det
	return [
		A * inv, -(b * i - c * h) * inv, (b * f - c * e) * inv,
		B * inv, (a * i - c * g) * inv, -(a * f - c * d) * inv,
		C * inv, -(a * h - b * g) * inv, (a * e - b * d) * inv]
