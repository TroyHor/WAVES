class_name MergedScreen
extends Control
## Drawn inside the centre oscilloscope's tube (over the flowing-wave backdrop):
## every wave overlaid like a MATH channel — enemy, each player wave, the
## player sum and the net result — with per-cell strength bars. Smooth curves;
## values at each cell are exact. Fields are pushed by MergedView.

## Height of the per-cell damage-number row at the bottom of the tube
## (blue = to the enemy, red = to you, "=" = cancelled).
const READOUT_H := 52.0

var track_length := 16
## Grid start and width in local coordinates (set by OscilloscopeView).
var grid_x0 := 26.0
var grid_w := 800.0
## [{track, color, label}]
var enemy_channels: Array = []
var enemy_sum := PackedInt32Array()
## Player wave(s) to draw; currently just the combined wave. [{track, from, to, emphasis}]
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
	return Rect2(grid_x0, 14, grid_w, size.y - 28 - READOUT_H)


## Baseline-centre of cell t's damage number (local).
func readout_point(t: int) -> Vector2:
	return Vector2(cell_center_x(t), size.y - 14 - READOUT_H * 0.5)


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


	if highlight_cell >= 0 and highlight_cell < track_length:
		draw_rect(Rect2(g.position.x + highlight_cell * cw, g.position.y, cw, g.size.y), Color(Assets.color("graticule"), 0.06))
	_draw_graticule(g, cw, cy, scale, font)

	if result == null:
		return

	# Strength bars built on the enemy's original wave in each cell:
	# grey = cancelled, red = still hits you, blue = your damage to the enemy.
	var grey := Color(Assets.color("cancelled"), 0.28)
	var red := Color(Assets.color("damage_to_player"), 0.32)
	var blue := Color(Assets.color("damage_to_enemy"), 0.3)
	for t in track_length:
		var p := _pop(t)
		if p <= 0.0:
			continue
		var e := float(result.enemy[t])
		var n := float(result.net[t])
		match result.outcome[t]:
			TrackResult.Outcome.PLAYER_HIT:
				if absf(n) <= absf(e):
					_bar(t, n, e, grey, p, y_of)
				_bar(t, 0.0, n, red, p, y_of)
			TrackResult.Outcome.CANCELLED:
				_bar(t, 0.0, e, grey, p, y_of)
			TrackResult.Outcome.OVERFLOW:
				_bar(t, 0.0, e, grey, p, y_of)
				_bar(t, 0.0, n, blue, p, y_of)
			TrackResult.Outcome.ENEMY_HIT:
				_bar(t, 0.0, n, blue, p, y_of)

	# Input waves stay faint so the phosphor result reads first.
	var in_off := (1.0 - arrive) * g.size.y * 0.9
	var in_alpha := clampf(arrive * 1.4, 0.0, 1.0) * (0.45 - merge * 0.2)
	for ch in enemy_channels:
		var col: Color = ch["color"]
		var pts := WaveDraw.smooth_points(ch["track"], 0, track_length - 1, x_of, func(v: float) -> float: return y_of.call(v) - in_off)
		WaveDraw.trace(self, pts, Color(col, in_alpha), 2.4)
	if enemy_channels.size() > 1 and not enemy_sum.is_empty():
		var pts := WaveDraw.smooth_points(enemy_sum, 0, track_length - 1, x_of, func(v: float) -> float: return y_of.call(v) - in_off)
		WaveDraw.trace(self, pts, Color(Assets.color("enemy_ch1").lerp(Assets.color("enemy_ch3"), 0.5), in_alpha * 0.8), 1.6, true)
	var pcol := Assets.color("player_wave")
	for part in player_parts:
		var from: int = maxi(0, part["from"])
		var to: int = mini(track_length - 1, part["to"])
		var pts := WaveDraw.smooth_points(part["track"], from, to, x_of, func(v: float) -> float: return y_of.call(v) + in_off)
		WaveDraw.trace(self, pts, Color(pcol, in_alpha), 2.4)

	# Net result as a bright phosphor trace with a wide bloom and a hot core.
	if reveal > 0.0:
		var a := clampf(reveal * 1.5, 0.0, 1.0)
		var ph := Assets.color("phosphor")
		var pts := WaveDraw.smooth_points(result.net, 0, track_length - 1, x_of, y_of)
		draw_polyline(pts, Color(ph, a * 0.05), 40.0, true)
		draw_polyline(pts, Color(ph, a * 0.1), 20.0, true)
		WaveDraw.trace(self, pts, Color(ph, a), 4.5)
		draw_polyline(pts, Color(1, 1, 1, a * 0.55), 1.6, true)
		WaveDraw.pulses(self, pts, Color(1, 1, 1, a * 0.5), 3.0, _t, 2, 0.3)

	_draw_readout(font, cw)
	if reveal > 0.95:
		_draw_particles(g, cw, y_of)
	if impact > 0.01:
		_draw_impact(cy)


## Per-cell damage numbers in the bottom row, popping in left to right.
func _draw_readout(font: Font, cw: float) -> void:
	for t in track_length:
		var p := _pop(t)
		var fs := Assets.fs(30 * p)
		if fs < 6:
			continue
		var txt := str(result.damage[t])
		var col := Assets.color("damage_to_enemy")
		match result.outcome[t]:
			TrackResult.Outcome.PLAYER_HIT:
				col = Assets.color("damage_to_player")
			TrackResult.Outcome.CANCELLED:
				txt = "="
				col = Assets.color("cancelled")
		if result.damage[t] == 0 and txt != "=":
			continue
		var c := readout_point(t)
		draw_string(font, Vector2(c.x - cw * 0.5, c.y + fs * 0.35), txt, HORIZONTAL_ALIGNMENT_CENTER, cw, fs, col.lightened(0.15))


## One coloured section of a cell's strength bar, from value a to b.
func _bar(t: int, a: float, b: float, col: Color, pop: float, y_of: Callable) -> void:
	if is_equal_approx(a, b):
		return
	var cw := cell_width()
	var ya: float = y_of.call(a * pop)
	var yb: float = y_of.call(b * pop)
	var r := Rect2(cell_center_x(t) - cw * 0.3, minf(ya, yb), cw * 0.6, absf(yb - ya))
	draw_rect(r, col)
	draw_rect(r, Color(col, minf(1.0, col.a * 1.8)), false, 1.2)


## Etched graticule: fine lines per cell, major divisions, centre axes with
## minor ticks, like the engraved overlay on a real CRT.
func _draw_graticule(g: Rect2, cw: float, cy: float, scale: float, font: Font) -> void:
	var line := Color(Assets.color("graticule"), 0.24)
	var major := Color(Assets.color("graticule"), 0.4)
	for t in range(track_length + 1):
		var x := g.position.x + t * cw
		draw_line(Vector2(x, g.position.y), Vector2(x, g.end.y), major if t % 4 == 0 else line, 1.0)
	for i in range(-4, 5):
		var y := cy + i * g.size.y * 0.46 / 4.0
		draw_line(Vector2(g.position.x, y), Vector2(g.end.x, y), major if i % 2 == 0 else line, 1.0)
	# The readout row below the graph.
	draw_line(Vector2(g.position.x, g.end.y + 6), Vector2(g.end.x, g.end.y + 6), major, 1.0)
	var axis := Color(Assets.color("graticule"), 0.45)
	draw_line(Vector2(g.position.x, cy), Vector2(g.end.x, cy), axis, 1.5)
	for k in range(track_length * 5 + 1):
		var x := g.position.x + k * cw / 5.0
		draw_line(Vector2(x, cy - 4), Vector2(x, cy + 4), axis, 1.0)
	for i: int in [-4, -2, 2, 4]:
		var y := cy + i * g.size.y * 0.46 / 4.0
		draw_string(font, Vector2(g.position.x + 6, y - 4), "%+.0f" % (-i * scale / 4.0), HORIZONTAL_ALIGNMENT_LEFT, -1, Assets.fs(13), Color(Assets.color("graticule"), 0.5))


static func _hash(x: float) -> float:
	return fposmod(sin(x * 12.9898) * 43758.5453, 1.0)


## Ambient interference particles (stateless: derived from time + cell):
## blue sparks rise from your damage toward the enemy, red drips fall from
## damage that will hit you, grey glints twinkle where waves cancel.
func _draw_particles(g: Rect2, cw: float, y_of: Callable) -> void:
	for t in track_length:
		var dmg := result.damage[t]
		var o := result.outcome[t]
		var base_y: float = y_of.call(float(result.net[t]))
		if dmg > 0 and o != TrackResult.Outcome.PLAYER_HIT:
			_stream(t, mini(2 + dmg, 9), base_y, -1.0, g, cw, Assets.color("damage_to_enemy"))
		elif dmg > 0:
			_stream(t, mini(2 + dmg, 9), base_y, 1.0, g, cw, Assets.color("damage_to_player"))
		var blocked := result.blocked[t]
		if blocked > 0:
			var y0: float = y_of.call(0.0)
			var y1: float = y_of.call(float(result.enemy[t]))
			for i in mini(1 + blocked, 6):
				var seed := t * 31.7 + i * 7.3
				var tw := 0.5 + 0.5 * sin(_t * (3.0 + _hash(seed) * 4.0) + seed)
				var p := Vector2(cell_center_x(t) + (_hash(seed + 1.0) - 0.5) * cw * 0.55, lerpf(y0, y1, _hash(seed + 2.0)))
				var col := Color(Assets.color("cancelled"), 0.55 * tw)
				draw_line(p - Vector2(3, 0), p + Vector2(3, 0), col, 1.5)
				draw_line(p - Vector2(0, 3), p + Vector2(0, 3), col, 1.5)


## A column of particles drifting from `start_y` (dir -1 = up, +1 = down).
func _stream(t: int, count: int, start_y: float, dir: float, g: Rect2, cw: float, col: Color) -> void:
	var travel := g.size.y * 0.42
	for i in count:
		var seed := t * 17.3 + i * 3.1
		var phase := fposmod(_t * (0.35 + _hash(seed) * 0.3) + _hash(seed + 5.0), 1.0)
		var x := cell_center_x(t) + (_hash(seed + 1.0) - 0.5) * cw * 0.5 + sin(phase * 6.0 + seed) * 3.0
		var y := start_y + dir * phase * travel
		if y < g.position.y or y > g.end.y:
			continue
		var a := (1.0 - phase) * 0.85
		draw_circle(Vector2(x, y), 4.5 * (1.0 - phase * 0.5), Color(col, a * 0.25))
		draw_circle(Vector2(x, y), 2.0 * (1.0 - phase * 0.5), Color(col, a))


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
		draw_arc(c, rad, 0, TAU, 32, Color(Assets.color("phosphor"), impact * 0.9), 2.5, true)
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
