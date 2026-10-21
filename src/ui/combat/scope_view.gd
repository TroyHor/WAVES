class_name ScopeView
extends Control
## One oscilloscope (the enemy's or the player's). Pure presentation. The
## enemy scope, collision strip and player scope share PAD_LEFT/PAD_RIGHT so
## their cell columns line up vertically.

const PAD_LEFT := 78.0
const PAD_RIGHT := 26.0
const PAD_TOP := 32.0
const PAD_BOTTOM := 8.0

var track_length := 16
## [{track: PackedInt32Array, color: Color, width?: float, dashed?: bool,
##   from?: int, to?: int}]  (from/to limit the drawn span)
var channels: Array = []
## [[text, color]] shown top-left.
var legend: Array = []
var info := ""
## Cells to tint (non-zero entries), e.g. the enemy's territory.
var tint_track := PackedInt32Array()
var tint_color := Color.TRANSPARENT
var highlight_cell := -1
## Shared amplitude scale so both scopes read the same.
var amp_scale := 10.0
## Resolve animation: traces fly toward the collision strip (dir +1 = down).
var launch := 0.0:
	set(v):
		launch = v
		queue_redraw()
var launch_dir := 1.0
var jitter := 0.0


func screen_rect() -> Rect2:
	return Rect2(PAD_LEFT, PAD_TOP, size.x - PAD_LEFT - PAD_RIGHT, size.y - PAD_TOP - PAD_BOTTOM)


func cell_width() -> float:
	return screen_rect().size.x / track_length


func cell_center_x(t: float) -> float:
	return screen_rect().position.x + (t + 0.5) * cell_width()


func cell_at(local: Vector2) -> int:
	return floori((local.x - screen_rect().position.x) / cell_width())


func y_for(a: float) -> float:
	var r := screen_rect()
	return r.get_center().y - a / amp_scale * r.size.y * 0.44


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var r := screen_rect()
	var cw := cell_width()
	draw_rect(Rect2(Vector2.ZERO, size), Assets.color("panel"))
	draw_rect(Rect2(Vector2.ZERO, size), Assets.color("panel_border"), false, 2.0)
	draw_rect(r, Assets.color("screen"))

	for t in mini(tint_track.size(), track_length):
		if tint_track[t] != 0:
			draw_rect(Rect2(r.position.x + t * cw, r.position.y, cw, r.size.y), Color(tint_color, 0.07))
	if highlight_cell >= 0 and highlight_cell < track_length:
		draw_rect(Rect2(r.position.x + highlight_cell * cw, r.position.y, cw, r.size.y), Color(Assets.color("net_wave"), 0.06))

	_draw_grid(r, cw, font)

	# Launch: shift toward the strip and fade, squashing slightly.
	var shift := launch_dir * launch * r.size.y * 0.55
	var fade := 1.0 - launch * 0.8
	var x_of := func(t: int) -> float: return cell_center_x(t)
	var y_of := func(v: float) -> float: return y_for(v * (1.0 - launch * 0.4)) + shift
	for ch in channels:
		var track: PackedInt32Array = ch["track"]
		var from: int = maxi(0, ch.get("from", 0))
		var to: int = mini(track_length - 1, ch.get("to", track_length - 1))
		var col: Color = ch["color"]
		col.a *= fade
		var pts := WaveDraw.smooth_points(track, from, to, x_of, y_of)
		WaveDraw.trace(self, pts, col, ch.get("width", 2.4), ch.get("dashed", false), jitter + launch * 3.0)
		if not ch.get("dashed", false):
			for t in range(from, to + 1):
				if track[t] != 0:
					draw_circle(Vector2(x_of.call(t), y_of.call(float(track[t]))), 3.2, col)

	_draw_legend(r, font)


func _draw_grid(r: Rect2, cw: float, font: Font) -> void:
	var grid := Assets.color("grid")
	var major := Assets.color("grid_major")
	for t in range(track_length + 1):
		var x := r.position.x + t * cw
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), major if t % 4 == 0 else grid, 1.0)
	for i in range(-2, 3):
		var y := r.get_center().y + i * r.size.y * 0.44 / 2.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), major if i == 0 else grid, 2.0 if i == 0 else 1.0)
		if i != 0:
			draw_string(font, Vector2(r.position.x - 64, y + 6), "%+.0f" % (-i * amp_scale / 2.0), HORIZONTAL_ALIGNMENT_RIGHT, 54, 14, Assets.color("text_dim"))
	var cy := r.get_center().y
	for t in range(track_length * 5 + 1):
		var x := r.position.x + t * cw / 5.0
		draw_line(Vector2(x, cy - 3), Vector2(x, cy + 3), major, 1.0)


func _draw_legend(r: Rect2, font: Font) -> void:
	var x := r.position.x
	var y := 22.0
	for e in legend:
		draw_line(Vector2(x, y - 6), Vector2(x + 24, y - 6), e[1], 3.0)
		draw_string(font, Vector2(x + 32, y), e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, e[1])
		x += 56 + font.get_string_size(e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
	if info != "":
		draw_string(font, Vector2(r.end.x - 420, y), info, HORIZONTAL_ALIGNMENT_RIGHT, 420, 16, Assets.color("text_dim"))
