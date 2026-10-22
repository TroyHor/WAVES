class_name PileIcon
extends Control
## Draw / discard pile as an icon (a little card stack) with a big count.
## Hover shows the pile name as a tooltip instead of permanent text.

var discard := false
var count := 0:
	set(v):
		if v != count:
			_bump = 1.0
		count = v
		queue_redraw()
var _bump := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	tooltip_text = "弃牌堆" if discard else "抽牌堆"


func _process(delta: float) -> void:
	if _bump > 0.0:
		_bump = move_toward(_bump, 0.0, delta * 3.0)
		queue_redraw()


## Card-reader tray: a stack of punch cards (fanned for the discard tray)
## with a mechanical counter plate showing how many cards are in it.
func _draw() -> void:
	var font := get_theme_default_font()
	var card := Vector2(size.x * 0.62, size.y * 0.7)
	var base := Vector2(size.x * 0.5, size.y * 0.46)
	# Dark tray under the stack.
	var tray := Rect2(base.x - card.x * 0.62, base.y - card.y * 0.5 + 8, card.x * 1.24, card.y * 0.95)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1f1b16")
	sb.set_corner_radius_all(InstrumentStyle.WINDOW_RADIUS)
	draw_style_box(sb, tray)
	for i in 4:
		var off := Vector2(i * 2.0, -i * 3.0) if not discard else Vector2((i - 1.5) * 3.0, -i * 2.0)
		var rot := 0.0 if not discard else (i - 1.5) * 0.12
		draw_set_transform(base + off, rot, Vector2.ONE)
		var r := Rect2(-card * 0.5, card)
		var pts := PunchCard.outline(r, 8.0)
		draw_colored_polygon(pts, PunchCard.PAPER.darkened(0.12 * (3 - i)))
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, Color(PunchCard.INK, 0.35), 1.0, true)
		if i == 3:
			PunchCard.draw_holes(self, Rect2(r.position + Vector2(6, r.size.y * 0.5), Vector2(r.size.x - 12, r.size.y * 0.4)),
				PackedInt32Array([2, -1, 3, 1, -2, 2]))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Counter plate.
	var plate := Rect2(base.x - 34, size.y - 40, 68, 36)
	InstrumentStyle.draw_plate(self, plate)
	var fs := Assets.fs(26 * (1.0 + 0.25 * _bump))
	draw_string(font, Vector2(plate.position.x, plate.end.y - 8), str(count), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x, fs, Assets.color("energy"))
