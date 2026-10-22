class_name SlotCards
extends Control
## Punch cards standing in the transmitter's slots (screen space, drawn over
## the foot). An inserted card is shrunk and only its top part shows — name,
## cost, waveform and values — so it can be read in place. Cards further right
## stand in front; several cards in one slot fan up a little; the hovered card
## rises, grows and comes to the front.

## Card width in cells (cards overlap their right neighbours).
const WIDTH_CELLS := 2.0
const HOVER_SCALE := 1.5

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
		# Stacked cards in one slot: each one a bit higher and to the right.
		var base := bases[off] + Vector2(e["stack"] * 8.0, -e["stack"] * 12.0)
		if lit:
			base += Vector2(0, -10)
		var top_left := base - Vector2(0, PunchCard.TOP_H * sc)
		var alpha := 0.55 if st.get("ghost", false) else 1.0
		draw_set_transform(top_left, 0.0, Vector2(sc, sc))
		PunchCard.draw_top(self, font, Rect2(Vector2.ZERO, CardView.CARD_SIZE), st["card"].data, st.get("flipped", false), alpha, lit)
		draw_set_transform(Vector2.ZERO)
		# The slit's near lip in front of the card's lower edge.
		var w := CardView.CARD_SIZE.x * sc
		draw_line(base + Vector2(-2, 1), base + Vector2(w + 2, 1), Color(0, 0, 0, 0.55 * alpha), 3.0)
		_hits.append({"rect": Rect2(top_left, Vector2(w, PunchCard.TOP_H * sc)), "card": st["card"]})
