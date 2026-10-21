class_name ScopeView
extends Control
## Oscilloscope display of the wave track. Pure presentation: it draws whatever
## TrackResult / channel data the combat screen hands it.

const STRIP_H := 78.0
const PAD_LEFT := 78.0
const PAD_RIGHT := 26.0
const PAD_TOP := 44.0
const MIN_SCALE := 10.0

var track_length := 16
## [{track: PackedInt32Array, color: Color, label: String}]
var enemy_channels: Array = []
## [{track: PackedInt32Array (full length), start: int, end: int, emphasis: bool}]
var player_waves: Array = []
var result: TrackResult
var turn := 1
## -1 = no sweep; 0..1 = resolve sweep position (cells right of it are hidden).
var sweep := -1.0:
	set(v):
		sweep = v
		queue_redraw()


func screen_rect() -> Rect2:
	return Rect2(PAD_LEFT, PAD_TOP, size.x - PAD_LEFT - PAD_RIGHT, size.y - PAD_TOP - STRIP_H - 14.0)


func cell_width() -> float:
	return screen_rect().size.x / track_length


func cell_center_x(t: float) -> float:
	return screen_rect().position.x + (t + 0.5) * cell_width()


## Cell under a local point (may be outside 0..track_length-1).
func cell_at(local: Vector2) -> int:
	return floori((local.x - screen_rect().position.x) / cell_width())


## True if a local point is over the scope area where cards can be dropped.
func accepts_drop(local: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).grow(12).has_point(local)


func _amp_scale() -> float:
	var m := MIN_SCALE
	for ch in enemy_channels:
		for v in ch["track"]:
			m = maxf(m, absf(v))
	if result != null:
		for v in result.net:
			m = maxf(m, absf(v))
		for v in result.player:
			m = maxf(m, absf(v))
	return m


func _y(a: float, scale: float) -> float:
	var r := screen_rect()
	return r.get_center().y - a / scale * r.size.y * 0.46


func _process(_delta: float) -> void:
	queue_redraw()  # cheap; keeps the phosphor flicker alive


func _draw() -> void:
	var font := get_theme_default_font()
	var r := screen_rect()
	var cw := cell_width()
	var scale := _amp_scale()
	var n := track_length

	# Bezel and tube face.
	draw_rect(Rect2(Vector2.ZERO, size), Assets.color("panel"))
	draw_rect(Rect2(Vector2.ZERO, size), Assets.color("panel_border"), false, 2.0)
	draw_rect(r, Assets.color("screen"))

	# Enemy territory: faint tint on cells the enemy wave occupies.
	if result != null:
		for t in n:
			if result.enemy[t] != 0:
				var c := _enemy_color_at(t)
				draw_rect(Rect2(r.position.x + t * cw, r.position.y, cw, r.size.y), Color(c, 0.07))

	_draw_grid(r, cw, scale, font)

	# Per-cell residual bars, colored by who takes the damage.
	if result != null:
		for t in n:
			if not _revealed(t):
				continue
			var net := result.net[t]
			if net == 0:
				continue
			var col := _outcome_color(result.outcome[t])
			var y0 := _y(0, scale)
			var y1 := _y(net, scale)
			draw_rect(Rect2(cell_center_x(t) - cw * 0.3, minf(y0, y1), cw * 0.6, absf(y1 - y0)), Color(col, 0.22))

	for ch in enemy_channels:
		_trace(ch["track"], 0, n - 1, ch["color"], 2.4, scale)
	for pw in player_waves:
		var col: Color = Assets.color("player_wave")
		var width := 3.2 if pw["emphasis"] else 2.0
		if not pw["emphasis"]:
			col = Color(col, 0.75)
		_trace(pw["track"], maxi(pw["start"] - 1, 0), mini(pw["end"], n - 1), col, width, scale)
	if result != null:
		_trace(result.net, 0, n - 1, Assets.color("net_wave"), 3.6, scale)

	if sweep >= 0.0:
		var x := r.position.x + sweep * r.size.x
		draw_rect(Rect2(x - 10, r.position.y, 20, r.size.y), Color(Assets.color("net_wave"), 0.08))
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Assets.color("net_wave"), 2.0)

	_draw_strip(r, cw, font)
	_draw_legend(r, font, scale)


func _draw_grid(r: Rect2, cw: float, scale: float, font: Font) -> void:
	var grid := Assets.color("grid")
	var major := Assets.color("grid_major")
	for t in range(track_length + 1):
		var x := r.position.x + t * cw
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), major if t % 4 == 0 else grid, 1.0)
	# Horizontal divisions: 4 above and 4 below the zero line.
	for i in range(-4, 5):
		var y := r.get_center().y + i * r.size.y * 0.46 / 4.0
		draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), major if i == 0 else grid, 2.0 if i == 0 else 1.0)
		if i != 0:
			var amp := -i * scale / 4.0
			draw_string(font, Vector2(r.position.x - 60, y + 6), "%+.0f" % amp, HORIZONTAL_ALIGNMENT_RIGHT, 50, 15, Assets.color("text_dim"))
	# Tick marks on the zero line, like a real graticule.
	for t in range(track_length * 5 + 1):
		var x := r.position.x + t * cw / 5.0
		var cy := r.get_center().y
		draw_line(Vector2(x, cy - 4), Vector2(x, cy + 4), major, 1.0)
	for t in track_length:
		draw_string(font, Vector2(r.position.x + t * cw, r.end.y + 18), str(t + 1), HORIZONTAL_ALIGNMENT_CENTER, cw, 14, Assets.color("text_dim"))


## Readout strip below the tube: per-cell damage to the enemy (top row) and to
## the player (bottom row); "=" marks perfect cancellation.
func _draw_strip(r: Rect2, cw: float, font: Font) -> void:
	var top := r.end.y + 26
	var row1 := top + 22
	var row2 := top + 50
	draw_string(font, Vector2(8, row1), "→敌", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Assets.color("damage_to_enemy"))
	draw_string(font, Vector2(8, row2), "←我", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Assets.color("damage_to_player"))
	if result == null:
		return
	for t in track_length:
		if not _revealed(t):
			continue
		var x := r.position.x + t * cw
		var dmg := result.damage[t]
		match result.outcome[t]:
			TrackResult.Outcome.ENEMY_HIT, TrackResult.Outcome.OVERFLOW:
				draw_string(font, Vector2(x, row1), str(dmg), HORIZONTAL_ALIGNMENT_CENTER, cw, 24, Assets.color("damage_to_enemy"))
			TrackResult.Outcome.PLAYER_HIT:
				draw_string(font, Vector2(x, row2), str(dmg), HORIZONTAL_ALIGNMENT_CENTER, cw, 24, Assets.color("damage_to_player"))
			TrackResult.Outcome.CANCELLED:
				draw_string(font, Vector2(x, (row1 + row2) * 0.5), "=", HORIZONTAL_ALIGNMENT_CENTER, cw, 22, Assets.color("cancelled"))


func _draw_legend(r: Rect2, font: Font, scale: float) -> void:
	var x := r.position.x
	var y := 30.0
	var entries: Array = []
	for i in enemy_channels.size():
		entries.append(["CH%d %s" % [1 if i == 0 else 3, enemy_channels[i]["label"]], enemy_channels[i]["color"]])
	entries.append(["CH2 玩家", Assets.color("player_wave")])
	entries.append(["MATH 合成", Assets.color("net_wave")])
	for e in entries:
		draw_line(Vector2(x, y - 7), Vector2(x + 26, y - 7), e[1], 3.0)
		draw_string(font, Vector2(x + 34, y), e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, e[1])
		x += 60 + font.get_string_size(e[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
	var info := "T%02d   %.1f/div   %d cells" % [turn, scale / 4.0, track_length]
	draw_string(font, Vector2(r.end.x - 360, y), info, HORIZONTAL_ALIGNMENT_RIGHT, 360, 17, Assets.color("text_dim"))


func _trace(track: PackedInt32Array, from: int, to: int, color: Color, width: float, scale: float) -> void:
	if to < from:
		return
	var pts := PackedVector2Array()
	for t in range(from, to + 1):
		pts.append(Vector2(cell_center_x(t), _y(track[t], scale)))
	if pts.size() == 1:
		pts.append(pts[0] + Vector2(0.1, 0))
	draw_polyline(pts, Color(color, color.a * 0.18), width * 4.0, true)
	draw_polyline(pts, color, width, true)
	for t in range(from, to + 1):
		if track[t] != 0:
			draw_circle(Vector2(cell_center_x(t), _y(track[t], scale)), width * 1.3, color)


func _revealed(t: int) -> bool:
	if sweep < 0.0:
		return true
	return float(t) + 0.5 <= sweep * track_length


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
