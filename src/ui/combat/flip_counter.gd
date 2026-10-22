class_name FlipCounter
extends Control
## Mechanical flip/roll counter: each digit sits on its own dark tile with a
## split line; when the value changes the digits roll (old up, new from below).

var color := Color.WHITE
var digits := 2
var value := 0:
	set(v):
		if v != value:
			_prev = value
			_roll = 1.0
		value = v
var _prev := 0
var _roll := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _roll > 0.0:
		_roll = move_toward(_roll, 0.0, delta * 5.0)
	queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var n := maxi(digits, str(value).length())
	var gap := 6.0
	var tile_w := minf((size.x - gap * (n - 1)) / n, size.y * 0.72)
	var total := tile_w * n + gap * (n - 1)
	var x0 := (size.x - total) * 0.5
	var fs := int(size.y * 0.78)
	var cur := str(value).lpad(n, " ")
	var old := str(_prev).lpad(n, " ")
	var k := _roll * _roll
	for i in n:
		var r := Rect2(x0 + i * (tile_w + gap), 0, tile_w, size.y)
		var tile := StyleBoxFlat.new()
		tile.bg_color = Color("141414")
		tile.set_corner_radius_all(InstrumentStyle.PLATE_RADIUS)
		tile.border_color = Color(0, 0, 0)
		tile.set_border_width_all(2)
		draw_style_box(tile, r)
		var base := Vector2(r.position.x, r.position.y + size.y * 0.5 + fs * 0.36)
		var changed := cur[i] != old[i] and k > 0.0
		if changed:
			draw_string(font, base - Vector2(0, size.y * (1.0 - k)), old[i], HORIZONTAL_ALIGNMENT_CENTER, tile_w, fs, Color(color, k))
			draw_string(font, base + Vector2(0, size.y * k), cur[i], HORIZONTAL_ALIGNMENT_CENTER, tile_w, fs, Color(color, 1.0 - k))
		else:
			draw_string(font, base, cur[i], HORIZONTAL_ALIGNMENT_CENTER, tile_w, fs, color)
		# Split line and a soft sheen on the upper half.
		draw_line(Vector2(r.position.x + 2, r.get_center().y), Vector2(r.end.x - 2, r.get_center().y), Color(0, 0, 0, 0.9), 2.0)
		draw_rect(Rect2(r.position + Vector2(2, 2), Vector2(r.size.x - 4, r.size.y * 0.5 - 3)), Color(1, 1, 1, 0.04))
