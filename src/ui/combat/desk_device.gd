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
## Visible case thickness above the face (pseudo-3D top surface), in pixels.
var depth := 0.0
## Visible thickness below the face (front lip of a part lying on the desk).
var front_depth := 0.0
## Corner radii of the case outline in flat units: TL, TR, BR, BL. Must match
## the face's InstrumentCase so the extruded body hugs its rounded corners.
var radii := Vector4(InstrumentStyle.CASE_RADIUS, InstrumentStyle.CASE_RADIUS, InstrumentStyle.CASE_RADIUS, InstrumentStyle.CASE_RADIUS)
var _vp: SubViewport
var _tex: TextureRect
var _mat: ShaderMaterial
var _h := []      ## flat uv (0..1) -> local pixel
var _hinv := []   ## local pixel -> flat uv
var _shake := 0.0
var _shake_t := 0.0
## Continuous tremble amplitude (0 = still), e.g. the overloaded transmitter.
var tremble := 0.0
var _tremble_t := 0.0
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


## Changes the face's flat size (e.g. a face whose width follows the layout).
## Call before set_quad.
func set_flat_size(v: Vector2) -> void:
	flat_size = v
	content.size = v
	if _vp != null:
		_vp.size = Vector2i(v)


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


## Current shake / tremble displacement (for things drawn with the device).
func jitter() -> Vector2:
	return position - _base_pos


## Short damped tremble (e.g. the transmitter when power is full).
func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)
	_shake_t = 0.0


func _process(delta: float) -> void:
	var offset := Vector2.ZERO
	if _shake > 0.0:
		_shake_t += delta
		_shake = move_toward(_shake, 0.0, delta * 1.8)
		offset += Vector2(sin(_shake_t * 55.0), cos(_shake_t * 47.0) * 0.4) * _shake * 6.0
	if tremble > 0.0:
		_tremble_t += delta
		# Fast, irregular hum: two incommensurate frequencies per axis.
		offset += Vector2(sin(_tremble_t * 71.0) + sin(_tremble_t * 43.0) * 0.6,
			cos(_tremble_t * 63.0) * 0.5 + sin(_tremble_t * 29.0) * 0.4) * tremble * 1.6
	position = _base_pos + offset


func _draw() -> void:
	if quad.size() < 4:
		return
	var outline := _outline()
	if cast_shadow:
		# Contact shadow: the footprint pushed down and spread a little.
		var c := (quad[0] + quad[1] + quad[2] + quad[3]) * 0.25
		for i in 4:
			var g := 6.0 + i * 7.0
			var pts := PackedVector2Array()
			for q in outline:
				pts.append(c + (q - c) * (1.0 + g / maxf(size.x, 1.0)) + Vector2(0, 10.0 + front_depth + i * 3.0))
			draw_colored_polygon(pts, Color(0, 0, 0, 0.11))
	var case_col := Assets.color("case")
	if depth > 0.0:
		# Top surface: the rounded outline swept upward (camera slightly above),
		# lit from above — brighter at the far edge.
		_extrude(outline, -depth, case_col.lightened(0.16), case_col.lightened(0.03))
	if front_depth > 0.0:
		# Front lip: the outline swept downward, in shade.
		_extrude(outline, front_depth, Assets.color("case_dark").darkened(0.18), Assets.color("case_dark"))


## Fills the body swept by `outline` moving `dy` pixels: the convex hull of the
## outline and its shifted copy (exact for convex rounded shapes, so the
## extrusion follows the face's rounded corners without seams). Colour runs
## from `far` (fully shifted side) to `near` (the face).
func _extrude(outline: PackedVector2Array, dy: float, far: Color, near: Color) -> void:
	var pts := PackedVector2Array(outline)
	for p in outline:
		pts.append(p + Vector2(0, dy))
	var hull := Geometry2D.convex_hull(pts)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	if hull.size() < 3:
		return
	var y_face := 0.0
	var y_far := 0.0
	var lo := INF
	var hi := -INF
	for p in outline:
		lo = minf(lo, p.y)
		hi = maxf(hi, p.y)
	y_face = lo if dy < 0.0 else hi
	y_far = y_face + dy
	var cols := PackedColorArray()
	for p in hull:
		cols.append(near.lerp(far, clampf((p.y - y_face) / (y_far - y_face), 0.0, 1.0)))
	draw_polygon(hull, cols)
	var closed := hull.duplicate()
	closed.append(hull[0])
	draw_polyline(closed, Color(Assets.color("case_edge"), 0.55), 1.5, true)


## The face's rounded outline in local pixels (corners from `radii`).
func _outline() -> PackedVector2Array:
	var f := flat_size
	var corners := [
		[Vector2(radii.x, radii.x), radii.x, PI],
		[Vector2(f.x - radii.y, radii.y), radii.y, PI * 1.5],
		[Vector2(f.x - radii.z, f.y - radii.z), radii.z, 0.0],
		[Vector2(radii.w, f.y - radii.w), radii.w, PI * 0.5],
	]
	var out := PackedVector2Array()
	for c in corners:
		var r: float = c[1]
		var steps := 8 if r > 0.0 else 1
		for k in steps:
			var a: float = c[2] + PI * 0.5 * k / maxf(1.0, steps - 1)
			out.append(_apply(_h, (c[0] + Vector2(cos(a), sin(a)) * r) / f))
	return out


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
