class_name FigureView
extends Control
## Player / enemy portrait. Draws the Assets texture when it exists, otherwise a
## code-drawn vector placeholder (glowing outline, idle bob) chosen by `shape`.

var shape := "orb"
var color := Color.WHITE
var texture: Texture2D
var dead := false
## Back-row twin: drawn smaller and dimmer.
var back_row := false
var _flash := 0.0
var _shake := 0.0
var _shake_t := 0.0
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_t = randf() * 10.0


func hit(amount: int) -> void:
	_flash = 1.0
	_shake = clampf(amount / 6.0, 0.35, 1.0)
	_shake_t = 0.0


func center_global() -> Vector2:
	return global_position + size * 0.5


func _process(delta: float) -> void:
	_t += delta
	_flash = move_toward(_flash, 0.0, delta * 2.5)
	_shake = move_toward(_shake, 0.0, delta * 2.0)
	_shake_t += delta
	queue_redraw()


func _draw() -> void:
	var s := 0.78 if back_row else 1.0
	var bob := Vector2(0, sin(_t * 1.6) * 4.0) if not dead else Vector2.ZERO
	# Damped sway + squash on hit (smooth, no random jitter).
	var sway := Vector2(sin(_shake_t * 30.0) * _shake * 9.0, 0)
	var squash := 1.0 + sin(_shake_t * 22.0) * _shake * 0.12
	var c := size * 0.5 + bob + sway
	draw_set_transform(c, 0.0, Vector2(1.0 / squash, squash))
	c = Vector2.ZERO
	var r := minf(size.x, size.y) * 0.42 * s
	var col := color.lerp(Color.WHITE, _flash * 0.8)
	if dead:
		col = Color(Assets.color("disabled"), 0.8)
	elif back_row:
		col = Color(col, 0.55)
	if texture != null:
		var tr := Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
		draw_texture_rect(texture, tr, false, col)
		return
	# Floor glow.
	draw_circle(c + Vector2(0, r * 1.05), r * 0.55, Color(col, 0.06))
	match shape:
		"player": _draw_player(c, r, col)
		"star": _draw_star(c, r, col)
		"colossus": _draw_colossus(c, r, col)
		"crest": _draw_triangle(c, r, col, true)
		"trough": _draw_triangle(c, r, col, false)
		_: _draw_orb(c, r, col)
	if dead:
		draw_line(c - Vector2(r, r) * 0.7, c + Vector2(r, r) * 0.7, Assets.color("damage_to_player"), 3.0)
		draw_line(c + Vector2(-r, r) * 0.7, c + Vector2(r, -r) * 0.7, Assets.color("damage_to_player"), 3.0)


func _outline(pts: PackedVector2Array, col: Color, width := 3.0) -> void:
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_colored_polygon(pts, Color(col, 0.08))
	WaveDraw.trace(self, closed, col, width)


func _eye(p: Vector2, r: float, col: Color) -> void:
	var blink := 0.15 if fmod(_t, 4.0) < 0.12 else 1.0
	draw_rect(Rect2(p - Vector2(r, r * blink), Vector2(r * 2, r * 2 * blink)), col)


func _draw_orb(c: Vector2, r: float, col: Color) -> void:
	_outline(_circle_pts(c, r * 0.7, 32), col)
	for i in 2:
		var rr := r * (0.85 + 0.15 * i + 0.05 * sin(_t * 3.0 + i))
		WaveDraw.trace(self, _circle_pts(c, rr, 40, true), Color(col, 0.35), 1.5, true)
	_eye(c, r * 0.12, col)
	draw_line(c + Vector2(0, -r * 0.7), c + Vector2(0, -r * 1.05), col, 2.0)
	draw_circle(c + Vector2(0, -r * 1.08), 5, col)


func _draw_star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var ang := TAU * i / 20.0 - PI / 2
		var rr := r * (1.0 if i % 2 == 0 else 0.55) * (1.0 + 0.05 * sin(_t * 9.0 + i))
		pts.append(c + Vector2(cos(ang), sin(ang)) * rr)
	_outline(pts, col)
	_eye(c + Vector2(-r * 0.2, -r * 0.08), r * 0.08, col)
	_eye(c + Vector2(r * 0.2, -r * 0.08), r * 0.08, col)
	var mouth := PackedVector2Array()
	for i in 7:
		mouth.append(c + Vector2(-r * 0.25 + i * r * 0.083, r * 0.2 + (6 if i % 2 == 0 else -2)))
	draw_polyline(mouth, col, 2.0)


func _draw_colossus(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array([
		c + Vector2(-r * 0.55, -r * 0.85), c + Vector2(r * 0.55, -r * 0.85),
		c + Vector2(r * 1.0, r * 0.2), c + Vector2(r * 0.75, r * 0.9),
		c + Vector2(-r * 0.75, r * 0.9), c + Vector2(-r * 1.0, r * 0.2)])
	_outline(pts, col)
	for k in 3:
		var line := PackedVector2Array()
		for i in 21:
			var x := -r * 0.6 + i * r * 0.06
			line.append(c + Vector2(x, r * (0.15 + 0.22 * k) + sin(i * 0.6 + _t * 2.0 + k) * 5.0))
		draw_polyline(line, Color(col, 0.6), 2.0, true)
	_eye(c + Vector2(-r * 0.28, -r * 0.4), r * 0.09, col)
	_eye(c + Vector2(r * 0.28, -r * 0.4), r * 0.09, col)


func _draw_triangle(c: Vector2, r: float, col: Color, up: bool) -> void:
	var d := -1.0 if up else 1.0
	var pts := PackedVector2Array([c + Vector2(0, d * r), c + Vector2(r * 0.9, -d * r * 0.6), c + Vector2(-r * 0.9, -d * r * 0.6)])
	_outline(pts, col)
	_eye(c + Vector2(0, -d * r * 0.1), r * 0.1, col)


func _draw_player(c: Vector2, r: float, col: Color) -> void:
	# A little oscilloscope-headed operator.
	var body := Rect2(c + Vector2(-r * 0.6, r * 0.15), Vector2(r * 1.2, r * 0.85))
	_outline(PackedVector2Array([body.position, Vector2(body.end.x, body.position.y), body.end, Vector2(body.position.x, body.end.y)]), col)
	var head := Rect2(c + Vector2(-r * 0.75, -r * 0.85), Vector2(r * 1.5, r * 0.9))
	_outline(PackedVector2Array([head.position, Vector2(head.end.x, head.position.y), head.end, Vector2(head.position.x, head.end.y)]), col)
	var wave := PackedVector2Array()
	for i in 25:
		var x := head.position.x + r * 0.15 + i * (head.size.x - r * 0.3) / 24.0
		wave.append(Vector2(x, head.get_center().y + sin(i * 0.55 + _t * 4.0) * head.size.y * 0.25))
	WaveDraw.trace(self, wave, col, 2.0)
	draw_line(Vector2(c.x + r * 0.4, head.position.y), Vector2(c.x + r * 0.6, head.position.y - r * 0.35), col, 2.0)
	draw_circle(Vector2(c.x + r * 0.6, head.position.y - r * 0.38), 4, col)


func _circle_pts(c: Vector2, r: float, n: int, closed := false) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in (n + 1 if closed else n):
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang), sin(ang)) * r)
	return pts
