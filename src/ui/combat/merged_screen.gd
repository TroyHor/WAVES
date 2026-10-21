class_name MergedScreen
extends Control
## Drawn inside the centre oscilloscope's tube (over the flowing-wave backdrop):
## every wave overlaid like a MATH channel — enemy, each player wave, the
## player sum and the net result — with per-cell strength bars. Smooth curves;
## values at each cell are exact. Fields are pushed by MergedView.

var track_length := 16
## Grid start and width in local coordinates (set by OscilloscopeView).
var grid_x0 := 26.0
var grid_w := 800.0
## [{track, color, label}]
var enemy_channels: Array = []
var enemy_sum := PackedInt32Array()
## [{track, from, to, emphasis}]
var player_parts: Array = []
var result: TrackResult
var highlight_cell := -1
## Resolve animation: 0 = incoming lines still outside, 1 = in place.
var arrive := 1.0
## 0..1 staggered pop-in of bars, net curve and numbers.
var reveal := 1.0
## After impact the input waves dim so the result stands out.
var merge := 0.0
## 0..1 soft rings where waves cancelled.
var impact := 0.0
var _t := 0.0


func graph_rect() -> Rect2:
	return Rect2(grid_x0, 14, grid_w, size.y - 28)


func cell_width() -> float:
	return grid_w / track_length


func cell_center_x(t: float) -> float:
	return grid_x0 + (t + 0.5) * cell_width()


func _scale() -> float:
	var m := 8.0
	if result != null:
		for arr in [result.enemy, result.player, result.net]:
			for v in arr:
				m = maxf(m, absf(v))
	return m


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


static func _ease_out_back(x: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(x - 1.0, 3) + c1 * pow(x - 1.0, 2)


## Staggered left-to-right pop for cell t.
func _pop(t: int) -> float:
	var k := clampf(reveal * 1.7 - float(t) / track_length * 0.7, 0.0, 1.0)
	return _ease_out_back(k) if k > 0.0 else 0.0


func _draw() -> void:
	var font := get_theme_default_font()
	var g := graph_rect()
	var cw := cell_width()
	var scale := _scale()
	var cy := g.get_center().y
	var y_of := func(v: float) -> float: return cy - v / scale * g.size.y * 0.46
	var x_of := func(t: int) -> float: return cell_center_x(t)


	if result != null:
		for t in track_length:
			if result.enemy[t] != 0:
				draw_rect(Rect2(g.position.x + t * cw, g.position.y, cw, g.size.y), Color(_enemy_color_at(t), 0.06))
	if highlight_cell >= 0 and highlight_cell < track_length:
		draw_rect(Rect2(g.position.x + highlight_cell * cw, g.position.y, cw, g.size.y), Color(Assets.color("net_wave"), 0.06))

	for t in range(track_length + 1):
		var x := g.position.x + t * cw
		draw_line(Vector2(x, g.position.y), Vector2(x, g.end.y), Assets.color("grid_major") if t % 4 == 0 else Assets.color("grid"), 1.0)
	for i in range(-2, 3):
		var y := cy + i * g.size.y * 0.46 / 2.0
		draw_line(Vector2(g.position.x, y), Vector2(g.end.x, y), Assets.color("grid_major") if i == 0 else Assets.color("grid"), 2.0 if i == 0 else 1.0)
		if i != 0:
			draw_string(font, Vector2(g.position.x + 6, y - 4), "%+.0f" % (-i * scale / 2.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Assets.color("text_dim"))

	if result == null:
		return

	# Residual bars (strength per cell), popping in left to right.
	for t in track_length:
		var net := result.net[t]
		if net == 0:
			continue
		var p := _pop(t)
		if p <= 0.0:
			continue
		var col := _outcome_color(result.outcome[t])
		var y0: float = y_of.call(0.0)
		var y1: float = lerpf(y0, y_of.call(float(net)), p)
		var bar := Rect2(cell_center_x(t) - cw * 0.31, minf(y0, y1), cw * 0.62, absf(y1 - y0))
		draw_rect(bar, Color(col, 0.26))
		draw_rect(bar, Color(col, 0.75), false, 1.5)

	var in_off := (1.0 - arrive) * g.size.y * 0.9
	var in_alpha := clampf(arrive * 1.4, 0.0, 1.0) * (1.0 - merge * 0.55)
	# Enemy channels arrive from above.
	for ch in enemy_channels:
		var col: Color = ch["color"]
		var pts := WaveDraw.smooth_points(ch["track"], 0, track_length - 1, x_of, func(v: float) -> float: return y_of.call(v) - in_off)
		WaveDraw.trace(self, pts, Color(col, in_alpha), 3.0)
		WaveDraw.pulses(self, pts, Color(col, in_alpha * 0.8), 3.0, _t, 2, 0.22)
	if enemy_channels.size() > 1 and not enemy_sum.is_empty():
		var pts := WaveDraw.smooth_points(enemy_sum, 0, track_length - 1, x_of, func(v: float) -> float: return y_of.call(v) - in_off)
		WaveDraw.trace(self, pts, Color(Assets.color("enemy_ch1").lerp(Assets.color("enemy_ch3"), 0.5), in_alpha * 0.6), 1.6, true)
	# Player waves arrive from below.
	var pcol := Assets.color("player_wave")
	for part in player_parts:
		var from: int = maxi(0, part["from"])
		var to: int = mini(track_length - 1, part["to"])
		var pts := WaveDraw.smooth_points(part["track"], from, to, x_of, func(v: float) -> float: return y_of.call(v) + in_off)
		WaveDraw.trace(self, pts, Color(pcol, in_alpha * (0.95 if part["emphasis"] else 0.5)), 2.6 if part["emphasis"] else 1.8)
	if player_parts.size() > 1:
		var pts := WaveDraw.smooth_points(result.player, 0, track_length - 1, x_of, func(v: float) -> float: return y_of.call(v) + in_off)
		WaveDraw.trace(self, pts, Color(pcol, in_alpha), 3.0)
		WaveDraw.pulses(self, pts, Color(pcol, in_alpha * 0.8), 3.0, _t + 0.5, 2, 0.22)

	# Net result.
	if reveal > 0.0:
		var a := clampf(reveal * 1.5, 0.0, 1.0)
		var pts := WaveDraw.smooth_points(result.net, 0, track_length - 1, x_of, y_of)
		WaveDraw.trace(self, pts, Color(Assets.color("net_wave"), a), 4.2)
		WaveDraw.pulses(self, pts, Color(Assets.color("net_wave"), a), 4.2, _t, 3, 0.3)
		for t in track_length:
			if result.net[t] != 0:
				draw_circle(Vector2(x_of.call(t), y_of.call(float(result.net[t]))), 4.0 * _pop(t), Assets.color("net_wave"))

	if impact > 0.01:
		_draw_impact(cy)


## Smooth expanding rings where waves cancelled (no jagged sparks).
func _draw_impact(cy: float) -> void:
	for t in track_length:
		var e := absi(result.enemy[t])
		var p := absi(result.player[t])
		if e == 0 or p == 0:
			continue
		var cancelled := (e + p - absi(result.net[t])) / 2
		if cancelled <= 0:
			continue
		var c := Vector2(cell_center_x(t), cy)
		var k := 1.0 - impact
		var rad := 6.0 + k * (18.0 + cancelled * 6.0)
		draw_arc(c, rad, 0, TAU, 32, Color(Assets.color("net_wave"), impact * 0.9), 2.5, true)
		draw_arc(c, rad * 0.6, 0, TAU, 24, Color(Assets.color("energy"), impact * 0.6), 2.0, true)


func _enemy_color_at(t: int) -> Color:
	for ch in enemy_channels:
		if ch["track"][t] != 0:
			return ch["color"]
	return Assets.color("enemy_ch1")


func _outcome_color(o: int) -> Color:
	match o:
		TrackResult.Outcome.PLAYER_HIT:
			return Assets.color("damage_to_player")
		TrackResult.Outcome.ENEMY_HIT, TrackResult.Outcome.OVERFLOW:
			return Assets.color("damage_to_enemy")
	return Assets.color("cancelled")
