class_name EnergyView
extends Control
## Energy as glowing cells only (no number): filled = available, outline = spent.

var energy := 0
var max_energy := 3
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "能量"


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var n := maxi(max_energy, energy)
	var r := minf(size.y * 0.42, size.x / (n * 2.4))
	var col := Assets.color("energy")
	for i in n:
		var c := Vector2(r * 1.2 + i * r * 2.4, size.y * 0.5)
		var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.8, 0), c + Vector2(0, r), c + Vector2(-r * 0.8, 0)])
		if i < energy:
			var pulse := 0.85 + 0.15 * sin(_t * 3.0 + i)
			draw_circle(c, r * 1.1, Color(col, 0.12 * pulse))
			draw_colored_polygon(pts, Color(col, pulse))
		else:
			var closed := pts.duplicate()
			closed.append(pts[0])
			draw_polyline(closed, Color(Assets.color("case_print"), 0.45), 2.0, true)
