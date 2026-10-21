class_name HpBar
extends Control
## Segmented HP readout with a blinking "ghost" for previewed damage.

var value := 0
var max_value := 1
var preview_loss := 0
var color := Color.WHITE
var label := "HP"


func _process(_delta: float) -> void:
	if preview_loss > 0:
		queue_redraw()


func set_values(p_value: int, p_max: int, p_loss: int) -> void:
	value = p_value
	max_value = maxi(1, p_max)
	preview_loss = clampi(p_loss, 0, p_value)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var bar := Rect2(0, 26, size.x, size.y - 26)
	draw_rect(bar, Assets.color("screen"))
	var w := bar.size.x * value / max_value
	draw_rect(Rect2(bar.position, Vector2(w, bar.size.y)), Color(color, 0.85))
	if preview_loss > 0:
		var blink := 0.45 + 0.35 * sin(Time.get_ticks_msec() / 120.0)
		var gw := bar.size.x * preview_loss / max_value
		draw_rect(Rect2(bar.position + Vector2(w - gw, 0), Vector2(gw, bar.size.y)), Color(Assets.color("damage_to_player"), blink))
	# Segment ticks every 10 HP for the instrument look.
	for i in range(10, max_value, 10):
		var x := bar.position.x + bar.size.x * i / max_value
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), Assets.color("background"), 2.0)
	draw_rect(bar, Assets.color("panel_border"), false, 2.0)
	var text := "%s  %d/%d" % [label, value, max_value]
	if preview_loss > 0:
		text += "   预计 -%d" % preview_loss
	draw_string(font, Vector2(0, 20), text, HORIZONTAL_ALIGNMENT_LEFT, size.x, 20, color)
