class_name ScopeScreen
extends Control
## What is drawn on a bench oscilloscope's tube (rendered in a SubViewport and
## shown through tube.gdshader). Traces are straight segments between samples.

var track_length := 16
## Local x where the grid starts, and its width (matches the merged panel).
var grid_x0 := 0.0
var grid_w := 100.0
## [{track, color, width?, dashed?, from?, to?}]
var channels: Array = []
var tint_track := PackedInt32Array()
var tint_color := Color.TRANSPARENT
var highlight_cell := -1
var amp_scale := 10.0
## Resolve animation: traces slide toward the merged panel (dir +1 = down).
var launch := 0.0
var launch_dir := 1.0


func cell_width() -> float:
	return grid_w / track_length


func cell_center_x(t: float) -> float:
	return grid_x0 + (t + 0.5) * cell_width()


func _grid_rect() -> Rect2:
	return Rect2(grid_x0, 24, grid_w, size.y - 34)


func y_for(a: float) -> float:
	var r := _grid_rect()
	return r.get_center().y - a / amp_scale * r.size.y * 0.46


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var r := _grid_rect()
	var cw := cell_width()
	draw_rect(Rect2(Vector2.ZERO, size), Assets.color("screen"))
	for t in mini(tint_track.size(), track_length):
		if tint_track[t] != 0:
			draw_rect(Rect2(r.position.x + t * cw, r.position.y, cw, r.size.y), Color(tint_color, 0.08))
	if highlight_cell >= 0 and highlight_cell < track_length:
		draw_rect(Rect2(r.position.x + highlight_cell * cw, r.position.y, cw, r.size.y), Color(Assets.color("net_wave"), 0.07))
	var grid := Assets.color("grid")
	var major := Assets.color("grid_major")
	for t in range(track_length + 1):
		var x := r.position.x + t * cw
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), major if t % 4 == 0 else grid, 1.0)
	for i in range(-2, 3):
		var y := r.get_center().y + i * r.size.y * 0.46 / 2.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), major if i == 0 else grid, 2.0 if i == 0 else 1.0)
	var cy := r.get_center().y
	for t in range(track_length * 5 + 1):
		var x := r.position.x + t * cw / 5.0
		draw_line(Vector2(x, cy - 3), Vector2(x, cy + 3), major, 1.0)

	var shift := launch_dir * launch * r.size.y * 0.7
	var fade := 1.0 - launch * 0.85
	var x_of := func(t: int) -> float: return cell_center_x(t)
	var y_of := func(v: float) -> float: return y_for(v) + shift
	for ch in channels:
		var track: PackedInt32Array = ch["track"]
		var from: int = maxi(0, ch.get("from", 0))
		var to: int = mini(track_length - 1, ch.get("to", track_length - 1))
		var col: Color = ch["color"]
		col.a *= fade
		var pts := WaveDraw.line_points(track, from, to, x_of, y_of)
		WaveDraw.trace(self, pts, col, ch.get("width", 2.4), ch.get("dashed", false))
		if not ch.get("dashed", false):
			for t in range(from, to + 1):
				if track[t] != 0:
					draw_circle(Vector2(x_of.call(t), y_of.call(float(track[t]))), 3.4, col)
