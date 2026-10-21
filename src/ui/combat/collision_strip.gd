class_name CollisionStrip
extends Control
## The band between the two scopes where enemy and player waves collide.
## Shows the net (MATH) trace and per-cell results: green numbers above the
## centre line hit the enemy (who is above), red below hit the player.

var track_length := 16
var result: TrackResult
var highlight_cell := -1
## 0..1 flash + sparks at the moment of impact.
var impact := 0.0:
	set(v):
		impact = v
		queue_redraw()
## 0 = only the grid, 1 = everything visible.
var reveal := 1.0:
	set(v):
		reveal = v
		queue_redraw()
var _sparks_seed := 0


func screen_rect() -> Rect2:
	return Rect2(ScopeView.PAD_LEFT, 4, size.x - ScopeView.PAD_LEFT - ScopeView.PAD_RIGHT, size.y - 8)


func cell_width() -> float:
	return screen_rect().size.x / track_length


func cell_center_x(t: float) -> float:
	return screen_rect().position.x + (t + 0.5) * cell_width()


## Global position of a cell's damage readout (projectile origin).
func cell_global(t: int, to_enemy: bool) -> Vector2:
	var r := screen_rect()
	return global_position + Vector2(cell_center_x(t), r.position.y + r.size.y * (0.25 if to_enemy else 0.75))


func burst() -> void:
	_sparks_seed = randi()
	impact = 1.0


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var r := screen_rect()
	var cw := cell_width()
	var cy := r.get_center().y
	draw_rect(Rect2(Vector2.ZERO, size), Assets.color("background"))
	draw_rect(r, Color(Assets.color("screen"), 0.7))
	if highlight_cell >= 0 and highlight_cell < track_length:
		draw_rect(Rect2(r.position.x + highlight_cell * cw, r.position.y, cw, r.size.y), Color(Assets.color("net_wave"), 0.06))
	for t in range(track_length + 1):
		var x := r.position.x + t * cw
		draw_line(Vector2(x, r.position.y), Vector2(x, r.end.y), Assets.color("grid"), 1.0)
	draw_line(Vector2(r.position.x, cy), Vector2(r.end.x, cy), Assets.color("grid_major"), 1.0)
	draw_string(font, Vector2(4, r.position.y + 26), "→敌", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Assets.color("damage_to_enemy"))
	draw_string(font, Vector2(4, r.end.y - 10), "←我", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Assets.color("damage_to_player"))
	if result == null:
		return

	var limit := reveal * track_length
	var scale := 6.0
	for v in result.net:
		scale = maxf(scale, absf(v))
	var x_of := func(t: int) -> float: return cell_center_x(t)
	var y_of := func(v: float) -> float: return cy - v / scale * r.size.y * 0.42
	var last := clampi(int(ceil(limit)) - 1, -1, track_length - 1)
	if last >= 0:
		var pts := WaveDraw.smooth_points(result.net, 0, last, x_of, y_of)
		WaveDraw.trace(self, pts, Color(Assets.color("net_wave"), 0.55), 2.0, false, impact * 4.0)

	for t in track_length:
		if float(t) + 0.5 > limit:
			continue
		var x := r.position.x + t * cw
		var dmg := result.damage[t]
		match result.outcome[t]:
			TrackResult.Outcome.ENEMY_HIT, TrackResult.Outcome.OVERFLOW:
				draw_string(font, Vector2(x, r.position.y + 30), str(dmg), HORIZONTAL_ALIGNMENT_CENTER, cw, 28, Assets.color("damage_to_enemy"))
			TrackResult.Outcome.PLAYER_HIT:
				draw_string(font, Vector2(x, r.end.y - 8), str(dmg), HORIZONTAL_ALIGNMENT_CENTER, cw, 28, Assets.color("damage_to_player"))
			TrackResult.Outcome.CANCELLED:
				draw_string(font, Vector2(x, cy + 9), "=", HORIZONTAL_ALIGNMENT_CENTER, cw, 26, Assets.color("cancelled"))

	if impact > 0.01:
		_draw_impact(r, cw, cy)


## Flash plus sparks proportional to how much wave was cancelled in each cell.
func _draw_impact(r: Rect2, cw: float, cy: float) -> void:
	draw_rect(r, Color(Assets.color("net_wave"), impact * 0.14))
	var rng := RandomNumberGenerator.new()
	rng.seed = _sparks_seed
	for t in track_length:
		var e := absi(result.enemy[t])
		var p := absi(result.player[t])
		var cancelled := (e + p - absi(result.net[t])) / 2
		if e == 0 and p == 0:
			continue
		var c := Vector2(cell_center_x(t), cy)
		var n := 3 + cancelled * 2
		for i in n:
			var ang := rng.randf() * TAU
			var len := (8.0 + rng.randf() * 22.0 + cancelled * 5.0) * (1.2 - impact)
			var col := Assets.color("net_wave").lerp(Assets.color("energy"), rng.randf())
			draw_line(c, c + Vector2(cos(ang), sin(ang)) * len, Color(col, impact), 2.0, true)
		draw_circle(c, (4.0 + cancelled * 2.0) * impact, Color(Assets.color("net_wave"), impact))
