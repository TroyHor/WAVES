class_name EnergyView
extends Control
## Transmit power as a row of glass bulbs on the transmitter case: lit bulbs
## (warm glow, bright filament) are available power, dark bulbs are spent.
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
	var n := maxi(max_energy, energy)
	var r := minf(size.y * 0.32, size.x / (n * 2.6))
	var step := size.x / n
	var lamp := Assets.color("energy")
	for i in n:
		var c := Vector2(step * (i + 0.5), size.y * 0.42)
		var lit := i < energy
		# Metal socket below the bulb.
		var base := Rect2(c.x - r * 0.45, c.y + r * 0.8, r * 0.9, r * 0.55)
		draw_rect(base, Assets.color("knob_cap"))
		for k in 3:
			draw_line(Vector2(base.position.x, base.position.y + 4 + k * 4), Vector2(base.end.x, base.position.y + 4 + k * 4), Color(0, 0, 0, 0.3), 1.0)
		if lit:
			var pulse := 0.9 + 0.1 * sin(_t * 3.0 + i)
			draw_circle(c, r * 2.0, Color(lamp, 0.10 * pulse))
			draw_circle(c, r * 1.4, Color(lamp, 0.18 * pulse))
			draw_circle(c, r, Color(lamp.lerp(Color.WHITE, 0.25), 0.95))
			draw_arc(c + Vector2(0, r * 0.15), r * 0.35, PI * 1.1, PI * 1.9, 10, Color(1, 1, 1, 0.9), 2.0, true)
		else:
			draw_circle(c, r, Color("3a3428"))
			draw_arc(c + Vector2(0, r * 0.15), r * 0.35, PI * 1.1, PI * 1.9, 10, Color("6b6150"), 1.5, true)
		# Glass highlight.
		draw_arc(c, r * 0.75, PI * 1.15, PI * 1.45, 8, Color(1, 1, 1, 0.45 if lit else 0.2), 2.0, true)
