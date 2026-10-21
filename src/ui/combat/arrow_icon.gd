class_name ArrowIcon
extends Control
## Chunky arrow used instead of words: up = toward the enemy, down = toward you.

var up := true
var color := Color.WHITE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS


func _draw() -> void:
	var c := size * 0.5
	var d := -1.0 if up else 1.0
	var w := size.x * 0.5
	var hh := size.y * 0.5
	var pts := PackedVector2Array([c + Vector2(0, hh * d), c + Vector2(-w, 0), c + Vector2(-w * 0.4, 0),
		c + Vector2(-w * 0.4, -hh * d), c + Vector2(w * 0.4, -hh * d), c + Vector2(w * 0.4, 0), c + Vector2(w, 0)])
	draw_circle(c, maxf(w, hh) * 1.3, Color(color, 0.08))
	draw_colored_polygon(pts, color)
