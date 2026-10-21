class_name WaveDraw
extends RefCounted
## Shared drawing helpers for smooth phosphor traces.

const SUBDIV := 10


## Smooth curve through (x_of(t), y_of(v[t])) for t in [from, to] using cosine
## interpolation: passes exactly through every sample and never overshoots, so
## what you see between two cells is never larger than either cell.
static func smooth_points(values: PackedInt32Array, from: int, to: int, x_of: Callable, y_of: Callable) -> PackedVector2Array:
	var pts := PackedVector2Array()
	if to < from:
		return pts
	for t in range(from, to):
		var a := float(values[t])
		var b := float(values[t + 1])
		for s in SUBDIV:
			var f := float(s) / SUBDIV
			var k := (1.0 - cos(f * PI)) * 0.5
			pts.append(Vector2(lerpf(x_of.call(t), x_of.call(t + 1), f), y_of.call(lerpf(a, b, k))))
	pts.append(Vector2(x_of.call(to), y_of.call(float(values[to]))))
	return pts


## Glowing trace. `jitter` adds per-point noise (used during collisions).
static func trace(ci: CanvasItem, pts: PackedVector2Array, color: Color, width: float, dashed := false, jitter := 0.0) -> void:
	if pts.size() < 2:
		return
	var p := pts
	if jitter > 0.0:
		p = pts.duplicate()
		for i in p.size():
			p[i].y += randf_range(-jitter, jitter)
	if dashed:
		for i in range(0, p.size() - 1, 2):
			ci.draw_line(p[i], p[i + 1], color, width, true)
		return
	ci.draw_polyline(p, Color(color, color.a * 0.16), width * 4.5, true)
	ci.draw_polyline(p, Color(color, color.a * 0.35), width * 2.0, true)
	ci.draw_polyline(p, color, width, true)
