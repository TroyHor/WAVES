class_name SlotBar
extends Control
## The foot of the L-shaped transmitter: a horizontal surface with a card slot
## running under the screen. Each inserted punch card shows only its bottom
## strip (its waveform) at the cells it occupies; cards whose cells overlap are
## stacked in rows. Stubs can be dragged along the slot (move), pulled out
## (take back) or right-clicked (flip) — handled by the combat screen via
## stub_at().

var track_length := 16
## Grid start / width in local coordinates (same columns as the screen above).
var grid_x0 := 0.0
var grid_w := 100.0
## [{card: CardInstance, offset: int, wave: PackedInt32Array, ghost: bool}]
var stubs: Array = []
var hover_uid := -1
## Computed in _draw: [{rect: Rect2, card: CardInstance}]
var _hits: Array = []


func cell_width() -> float:
	return grid_w / track_length


## Placed card whose stub covers local point `p` (null if none).
func stub_at(p: Vector2) -> CardInstance:
	for i in range(_hits.size() - 1, -1, -1):
		if _hits[i]["rect"].has_point(p):
			return _hits[i]["card"]
	return null


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var r := Rect2(Vector2.ZERO, size)
	# Top surface of the foot (lit from above) with a darker front lip.
	draw_rect(r, Assets.color("case").lightened(0.06))
	draw_rect(Rect2(0, size.y - 14, size.x, 14), Assets.color("case_dark"))
	draw_line(Vector2(0, size.y - 14), Vector2(size.x, size.y - 14), Color(1, 1, 1, 0.5), 1.0)
	draw_line(Vector2(0, 1), Vector2(size.x, 1), Color(0, 0, 0, 0.25), 2.0)
	# The slot itself.
	var slot := Rect2(grid_x0 - 10, 12, grid_w + 20, size.y - 34)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("16130f")
	sb.set_corner_radius_all(InstrumentStyle.PLATE_RADIUS)
	draw_style_box(sb, slot)
	var cw := cell_width()
	for t in range(1, track_length):
		var x := grid_x0 + t * cw
		draw_line(Vector2(x, slot.position.y + 3), Vector2(x, slot.end.y - 3), Color(1, 1, 1, 0.05), 1.0)
	# Row assignment: greedy, earliest offset first.
	var order := stubs.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["offset"] < b["offset"])
	var row_ends: Array[int] = []
	var rows_of := {}
	for st in order:
		var placed := false
		for ri in row_ends.size():
			if row_ends[ri] <= st["offset"]:
				row_ends[ri] = st["offset"] + st["wave"].size()
				rows_of[st] = ri
				placed = true
				break
		if not placed:
			rows_of[st] = row_ends.size()
			row_ends.append(st["offset"] + st["wave"].size())
	var n_rows := maxi(1, row_ends.size())
	var row_h := (slot.size.y - 6) / n_rows
	_hits.clear()
	for st in order:
		var ri: int = rows_of[st]
		var x0: float = grid_x0 + st["offset"] * cw
		var w: float = st["wave"].size() * cw
		var rect := Rect2(x0 + 2, slot.position.y + 3 + ri * row_h, w - 4, row_h - 3)
		var card: CardInstance = st["card"]
		var hovered := card.uid == hover_uid
		var a := 0.55 if st.get("ghost", false) else 1.0
		draw_rect(rect, Color(PunchCard.PAPER.lightened(0.05 if hovered else 0.0), a))
		draw_rect(rect, Color(Assets.color("energy") if hovered else PunchCard.INK, (0.9 if hovered else 0.4) * a), false, 2.0 if hovered else 1.0)
		# Samples sit at their cell centres so the strip lines up with the screen.
		var wave: PackedInt32Array = st["wave"]
		var m := 6.0
		for v in wave:
			m = maxf(m, absf(v))
		var pts := PackedVector2Array()
		for i in wave.size():
			pts.append(Vector2(x0 + (i + 0.5) * cw, rect.get_center().y - wave[i] / m * rect.size.y * 0.4))
		if pts.size() > 1:
			draw_polyline(pts, Color(PunchCard.WAVE_INK, a), 2.4, true)
		for p in pts:
			draw_circle(p, 2.6, Color(PunchCard.WAVE_INK, a))
		_hits.append({"rect": rect, "card": card})
