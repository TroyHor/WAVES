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


func _draw() -> void:
	var font := get_theme_default_font()
	var col := Assets.color("text_dim") if discard else Assets.color("player_wave")
	var card := Vector2(size.x * 0.56, size.y * 0.72)
	var base := Vector2(size.x * 0.5, size.y * 0.5)
	# Three stacked cards; the discard pile is fanned.
	for i in 3:
		var off := Vector2(i * 4.0, -i * 4.0) if not discard else Vector2(0, -i * 2.0)
		var rot := 0.0 if not discard else (i - 1) * 0.22
		draw_set_transform(base + off, rot, Vector2.ONE)
		var r := Rect2(-card * 0.5, card)
		draw_rect(r, Assets.color("panel"))
		draw_rect(r, Color(col, 0.5 + i * 0.25), false, 2.0)
	draw_set_transform(base + (Vector2(8, -8) if not discard else Vector2(0, -4)), 0.0, Vector2.ONE)
	# Mini wave on the top card.
	var pts := PackedVector2Array()
	for i in 13:
		var x := -card.x * 0.35 + i * card.x * 0.7 / 12.0
		pts.append(Vector2(x, -card.y * 0.18 + sin(i * 0.9) * card.y * 0.12))
	draw_polyline(pts, Color(col, 0.8), 2.0, true)
	var fs := int(34 * (1.0 + 0.25 * _bump))
	draw_string(font, Vector2(-card.x, card.y * 0.34), str(count), HORIZONTAL_ALIGNMENT_CENTER, card.x * 2, fs, Assets.color("net_wave"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
