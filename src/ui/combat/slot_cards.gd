class_name SlotCards
extends Control
## Punch cards standing in the transmitter's slots (screen space, drawn over
## the foot). An inserted card is shrunk to fit inside its slit and only its
## top part shows — name, cost, waveform and values. Several cards in one slot
## step up a little; the hovered card rises, grows (to be read) and comes to
## the front.

## Slotted card tag: sparkline height, value font (design size) and line height.
const SPARK_H := 16.0
const VALUE_FS := 11
const VALUE_LINE := 15.0
const TROUGH_INK := Color("9a3a26")
## Card width as a share of a cell (= the slit's width).
const WIDTH_CELLS := 0.84
const HOVER_SCALE := 2.6

## [{card: CardInstance, offset: int, flipped: bool, ghost: bool}]
var stubs: Array = []
var hover_uid := -1
## Screen-local bottom-left corner of each slot's slit (index = cell).
var bases := PackedVector2Array()
## On-screen width of one cell.
var cell_px := 40.0
## Computed in _draw, back to front: [{rect: Rect2, card: CardInstance}]
var _hits: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func card_scale() -> float:
	return cell_px * WIDTH_CELLS / CardView.CARD_SIZE.x


## Card whose visible part covers local point `p` (front-most), or null.
func card_at(p: Vector2) -> CardInstance:
	for i in range(_hits.size() - 1, -1, -1):
		if _hits[i]["rect"].has_point(p):
			return _hits[i]["card"]
	return null


## Visible rect of the card standing in slot `offset` (local).
func slot_rect(offset: int) -> Rect2:
	var s := card_scale()
	var b := bases[clampi(offset, 0, bases.size() - 1)]
	return Rect2(b - Vector2(0, PunchCard.TOP_H * s), Vector2(CardView.CARD_SIZE.x, PunchCard.TOP_H) * s)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	_hits.clear()
	if bases.is_empty():
		return
	var font := get_theme_default_font()
	var order := stubs.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["offset"] < b["offset"])
	# The hovered card is drawn last (in front).
	var hovered: Dictionary = {}
	var per_slot := {}
	var placed: Array = []
	for st in order:
		var k: int = per_slot.get(st["offset"], 0)
		per_slot[st["offset"]] = k + 1
		var entry := {"st": st, "stack": k, "lit": false}
		if st["card"].uid == hover_uid and not st.get("ghost", false):
			entry["lit"] = true
			hovered = entry
		else:
			placed.append(entry)
	if not hovered.is_empty():
		placed.append(hovered)
	var s := card_scale()
	for e in placed:
		var st: Dictionary = e["st"]
		var lit: bool = e["lit"]
		var sc := s * (HOVER_SCALE if lit else 1.0)
		var off: int = st["offset"]
		if off < 0 or off >= bases.size():
			continue
		# Stacked cards in one slot: each one a bit higher.
		var base := bases[off] + Vector2(0, -e["stack"] * 20.0)
		if lit:
			# Grow around the slot's centre, lifted out of the slit a little.
			base += Vector2(-CardView.CARD_SIZE.x * (sc - s) * 0.5, -10)
		var alpha := 0.55 if st.get("ghost", false) else 1.0
		var w := CardView.CARD_SIZE.x * sc
		var top_left: Vector2
		if lit:
			# Hovered: the real card face, enlarged enough to read everything.
			top_left = base - Vector2(0, PunchCard.TOP_H * sc)
			draw_set_transform(top_left, 0.0, Vector2(sc, sc))
			PunchCard.draw_top(self, font, Rect2(Vector2.ZERO, CardView.CARD_SIZE), st["card"].data, st.get("flipped", false), alpha, true)
			draw_set_transform(Vector2.ZERO)
			_hits.append({"rect": Rect2(top_left, Vector2(w, PunchCard.TOP_H * sc)), "card": st["card"]})
		else:
			var data: CardData = st["card"].data
			var th := tag_height(font, data.wave, w)
			var r := Rect2(base - Vector2(0, th), Vector2(w, th))
			_draw_tag(font, r, st["card"].data, st.get("flipped", false), alpha)
			# The slit's near lip in front of the card's lower edge.
			draw_line(base + Vector2(-1, 1), base + Vector2(w + 1, 1), Color(0, 0, 0, 0.55 * alpha), 3.0)
			_hits.append({"rect": r, "card": st["card"]})


## A slotted card at slot size, redesigned to stay legible there: a bold
## sparkline of the wave over its values, wrapped into as many rows as the
## slot's width needs (the name and the rest show when hovered).
func _draw_tag(font: Font, r: Rect2, data: CardData, flipped: bool, alpha: float) -> void:
	var pts := PunchCard.outline(r, 6.0)
	draw_colored_polygon(PackedVector2Array(Array(pts).map(func(p: Vector2) -> Vector2: return p + Vector2(2, 3))), Color(0, 0, 0, 0.25 * alpha))
	draw_colored_polygon(pts, Color(PunchCard.PAPER, alpha))
	var closed := pts.duplicate()
	closed.append(pts[0])
	draw_polyline(closed, Color(PunchCard.INK, 0.6 * alpha), 1.0, true)
	var wave := WaveMath.invert(data.wave) if flipped else data.wave
	if wave.is_empty():
		return
	var area := Rect2(r.position.x + 5, r.position.y + 6, r.size.x - 10, SPARK_H)
	draw_line(Vector2(area.position.x, area.get_center().y), Vector2(area.end.x, area.get_center().y), Color(PunchCard.GRID, 0.8 * alpha), 1.0)
	var m := 4.0
	for v in wave:
		m = maxf(m, absf(v))
	var line := PackedVector2Array()
	for i in wave.size():
		var x := area.get_center().x if wave.size() == 1 else area.position.x + area.size.x * i / (wave.size() - 1)
		line.append(Vector2(x, area.get_center().y - wave[i] / m * area.size.y * 0.5))
	if line.size() > 1:
		draw_polyline(line, Color(PunchCard.WAVE_INK, alpha), 2.0, true)
	for p in line:
		draw_circle(p, 2.2, Color(PunchCard.WAVE_INK, alpha))
	# Values in reading order, wrapped to fit the slot's width. Troughs are
	# printed in red-brown ink without the minus sign (it would not fit).
	var fs := Assets.fs(VALUE_FS)
	var inner := r.size.x - 6.0
	var cell := 0.0
	for v in wave:
		cell = maxf(cell, font.get_string_size(str(absi(v)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 1.0)
	var per := clampi(floori(inner / cell), 1, wave.size())
	var rows := ceili(float(wave.size()) / per)
	for i in wave.size():
		var row := i / per
		var in_row := mini(per, wave.size() - row * per)
		var x0 := r.position.x + 3.0 + (inner - in_row * cell) * 0.5
		var y := area.end.y + 6.0 + (row + 1) * VALUE_LINE
		var ink := TROUGH_INK if wave[i] < 0 else PunchCard.INK
		draw_string(font, Vector2(x0 + (i % per) * cell, y), str(absi(wave[i])), HORIZONTAL_ALIGNMENT_CENTER, cell, fs, Color(ink, alpha))


## Tag height for a wave of `n` values at slot width `w`.
func tag_height(font: Font, wave: PackedInt32Array, w: float) -> float:
	var fs := Assets.fs(VALUE_FS)
	var cell := 0.0
	for v in wave:
		cell = maxf(cell, font.get_string_size(str(absi(v)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 1.0)
	var per := clampi(floori((w - 6.0) / maxf(cell, 1.0)), 1, maxi(wave.size(), 1))
	return 6.0 + SPARK_H + 6.0 + ceili(float(maxi(wave.size(), 1)) / per) * VALUE_LINE + 6.0
