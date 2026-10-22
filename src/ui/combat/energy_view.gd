class_name EnergyView
extends Control
## Transmit power load as a vertical stack of glass bulbs on the transmitter.
## Each turn starts dark; every card loaded lights bulbs for its cost. All
## lit = power full (the transmitter trembles and refuses more cards).
## No number is shown.

var energy := 0
var max_energy := 3
var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "发射功率"


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var n := maxi(max_energy, 1)
	var used := clampi(max_energy - energy, 0, n)
	var step := size.y / n
	var r := minf(step * 0.34, size.x * 0.32)
	var lamp := Assets.color("energy")
	var full := used >= n
	for i in n:
		# Fill from the bottom up.
		var c := Vector2(size.x * 0.5, size.y - step * (i + 0.5))
		var lit := i < used
		var base := Rect2(c.x - r * 0.45, c.y + r * 0.8, r * 0.9, r * 0.45)
		draw_rect(base, Assets.color("knob_cap"))
		draw_line(Vector2(base.position.x, base.position.y + 4), Vector2(base.end.x, base.position.y + 4), Color(0, 0, 0, 0.3), 1.0)
		if lit:
			var pulse := 0.9 + 0.1 * sin(_t * (9.0 if full else 3.0) + i)
			draw_circle(c, r * 1.9, Color(lamp, 0.10 * pulse))
			draw_circle(c, r * 1.35, Color(lamp, 0.2 * pulse))
			draw_circle(c, r, Color(lamp.lerp(Color.WHITE, 0.25), 0.95))
			draw_arc(c + Vector2(0, r * 0.15), r * 0.35, PI * 1.1, PI * 1.9, 10, Color(1, 1, 1, 0.9), 2.0, true)
		else:
			draw_circle(c, r, Color("3a3428"))
			draw_arc(c + Vector2(0, r * 0.15), r * 0.35, PI * 1.1, PI * 1.9, 10, Color("6b6150"), 1.5, true)
		draw_arc(c, r * 0.75, PI * 1.15, PI * 1.45, 8, Color(1, 1, 1, 0.45 if lit else 0.2), 2.0, true)
