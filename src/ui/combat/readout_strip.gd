class_name ReadoutStrip
extends Control
## Digital readout on the centre oscilloscope's case, under the tube: per-cell
## damage — green (top row) hits the enemy, red (bottom row) hits you, "="
## marks a perfect cancel. Numbers pop in with the bars.

var track_length := 16
var grid_x0 := 100.0
var grid_x1 := 900.0
var result: TrackResult
var reveal := 1.0
var highlight_cell := -1


func cell_width() -> float:
	return (grid_x1 - grid_x0) / track_length


func _process(_delta: float) -> void:
	queue_redraw()


func _pop(t: int) -> float:
	var k := clampf(reveal * 1.7 - float(t) / track_length * 0.7, 0.0, 1.0)
	return MergedScreen._ease_out_back(k) if k > 0.0 else 0.0


func _draw() -> void:
	var font := get_theme_default_font()
	var cw := cell_width()
	var panel := Rect2(grid_x0 - 8, 0, grid_x1 - grid_x0 + 16, size.y)
	draw_rect(panel, Assets.color("bezel"))
	draw_rect(panel, Color(Assets.color("case_edge"), 0.8), false, 2.0)
	if highlight_cell >= 0 and highlight_cell < track_length:
		draw_rect(Rect2(grid_x0 + highlight_cell * cw, 2, cw, size.y - 4), Color(Assets.color("net_wave"), 0.06))
	for t in range(1, track_length):
		var x := grid_x0 + t * cw
		draw_line(Vector2(x, 6), Vector2(x, size.y - 6), Color(Assets.color("grid"), 0.8), 1.0)
	draw_string(font, Vector2(grid_x0 - 64, 28), "→敌", HORIZONTAL_ALIGNMENT_LEFT, -1, Assets.fs(18), Assets.color("damage_to_enemy"))
	draw_string(font, Vector2(grid_x0 - 64, size.y - 10), "←我", HORIZONTAL_ALIGNMENT_LEFT, -1, Assets.fs(18), Assets.color("damage_to_player"))
	if result == null:
		return
	for t in track_length:
		var p := _pop(t)
		var fs := Assets.fs(28 * p)
		if fs < 6:
			continue
		var x := grid_x0 + t * cw
		match result.outcome[t]:
			TrackResult.Outcome.ENEMY_HIT, TrackResult.Outcome.OVERFLOW:
				draw_string(font, Vector2(x, 30), str(result.damage[t]), HORIZONTAL_ALIGNMENT_CENTER, cw, fs, Assets.color("damage_to_enemy"))
			TrackResult.Outcome.PLAYER_HIT:
				draw_string(font, Vector2(x, size.y - 8), str(result.damage[t]), HORIZONTAL_ALIGNMENT_CENTER, cw, fs, Assets.color("damage_to_player"))
			TrackResult.Outcome.CANCELLED:
				draw_string(font, Vector2(x, size.y * 0.5 + 9), "=", HORIZONTAL_ALIGNMENT_CENTER, cw, fs, Assets.color("cancelled"))
