class_name PunchCard
extends RefCounted
## Drawing of a waveform punch card (art_direction §5): manila card with a cut
## corner, cost pips, the waveform inked on graph paper, and a punched hole
## pattern that encodes the waveform (one column per sample: |v| holes above
## the centre row for crests, below for troughs). Shared by hand cards, slot
## stubs and piles so the card looks the same everywhere.

const PAPER := Color("e9dcbf")
const PAPER_DIM := Color("b8ac92")
const INK := Color("2d2a24")
const WAVE_INK := Color("1f3a5c")
const GRID := Color("8fb3cf")
const HOLE := Color("231e18")


static func outline(r: Rect2, cut := 14.0) -> PackedVector2Array:
	return PackedVector2Array([r.position + Vector2(cut, 0), Vector2(r.end.x, r.position.y), r.end,
		Vector2(r.position.x, r.end.y), r.position + Vector2(0, cut)])


## Full card face in rect `r` (design size 156x214, scaled by the caller).
static func draw_card(ci: CanvasItem, font: Font, r: Rect2, data: CardData, flipped: bool, playable: bool, alpha := 1.0) -> void:
	var paper := (PAPER if playable else PAPER_DIM)
	var pts := outline(r)
	ci.draw_colored_polygon(pts, Color(paper, alpha))
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, Color(INK, 0.55 * alpha), 1.5, true)
	# Name and cost pips.
	ci.draw_string(font, r.position + Vector2(18, 28), data.name, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 64, Assets.fs(19), Color(INK, alpha))
	var lamp := Assets.color("energy")
	for i in maxi(data.cost, 1):
		var c := Vector2(r.end.x - 14 - i * 16, r.position.y + 19)
		if data.cost == 0:
			ci.draw_arc(c, 6, 0, TAU, 16, Color(INK, 0.6 * alpha), 1.5, true)
		else:
			ci.draw_circle(c, 7, Color(INK, 0.7 * alpha))
			ci.draw_circle(c, 5, Color(lamp if playable else lamp.darkened(0.4), alpha))
	# Keyword marks.
	if data.has_keyword("flippable"):
		ci.draw_string(font, Vector2(r.end.x - 30, r.position.y + 50), "⇅", HORIZONTAL_ALIGNMENT_LEFT, -1, Assets.fs(16), Color(INK, 0.8 * alpha))
	# Waveform on graph paper.
	var plot := Rect2(r.position + Vector2(10, 40), Vector2(r.size.x - 20, 86))
	ci.draw_rect(plot, Color(1, 1, 1, 0.35 * alpha))
	for i in 9:
		var x := plot.position.x + plot.size.x * i / 8.0
		ci.draw_line(Vector2(x, plot.position.y), Vector2(x, plot.end.y), Color(GRID, 0.35 * alpha), 1.0)
	for i in 5:
		var y := plot.position.y + plot.size.y * i / 4.0
		ci.draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(GRID, (0.7 if i == 2 else 0.35) * alpha), 1.0)
	var wave := WaveMath.invert(data.wave) if flipped else data.wave
	if wave.is_empty():
		ci.draw_string(font, Vector2(plot.position.x, plot.get_center().y + 8), "—", HORIZONTAL_ALIGNMENT_CENTER, plot.size.x, Assets.fs(18), Color(INK, 0.5 * alpha))
	else:
		draw_wave(ci, plot.grow(-6), wave, Color(WAVE_INK, alpha))
	# Rules (only meaningful text).
	var rules := data.rules_text()
	if rules != "":
		ci.draw_multiline_string(font, r.position + Vector2(10, 146), rules, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20, Assets.fs(14), 2, Color(INK, 0.85 * alpha))
	# Punched holes encoding the wave.
	draw_holes(ci, Rect2(r.position + Vector2(12, r.size.y - 50), Vector2(r.size.x - 24, 40)), wave, alpha)


static func draw_wave(ci: CanvasItem, area: Rect2, wave: PackedInt32Array, col: Color) -> void:
	var m := 6.0
	for v in wave:
		m = maxf(m, absf(v))
	var step := area.size.x / (wave.size() + 1)
	var pts := PackedVector2Array()
	for i in wave.size():
		pts.append(Vector2(area.position.x + step * (i + 1), area.get_center().y - wave[i] / m * area.size.y * 0.46))
	if pts.size() > 1:
		ci.draw_polyline(pts, col, 2.4, true)
	for p in pts:
		ci.draw_circle(p, 3.0, col)


static func draw_holes(ci: CanvasItem, area: Rect2, wave: PackedInt32Array, alpha := 1.0) -> void:
	var cols := maxi(wave.size(), 1)
	var cw := minf(area.size.x / cols, 16.0)
	var x0 := area.get_center().x - cw * cols * 0.5
	var hh := area.size.y / 9.0
	var mid := area.get_center().y
	ci.draw_line(Vector2(area.position.x, mid), Vector2(area.end.x, mid), Color(INK, 0.25 * alpha), 1.0)
	for i in wave.size():
		var v := clampi(wave[i], -4, 4)
		for k in absi(v):
			var y := mid - (k + 1) * hh * 1.0 - hh * 0.5 if v > 0 else mid + k * hh * 1.0 + hh * 0.5
			ci.draw_rect(Rect2(x0 + i * cw + cw * 0.25, y, cw * 0.5, hh * 0.7), Color(HOLE, alpha))
