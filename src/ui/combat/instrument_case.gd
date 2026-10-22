class_name InstrumentCase
extends Control
## A cream instrument housing on the bench. The combat layout places screens,
## gauges and lamps (child Controls) over the windows declared here; this node
## only draws the hardware: case, display windows, round ports and print.

## Recessed display windows (local rects).
var windows: Array[Rect2] = []
## Round observation ports: [{center: Vector2, radius: float, glow: Color}]
var ports: Array = []
## Silkscreen labels: [{pos: Vector2, text: String, size: float, align?, width?}]
var labels: Array = []
## Indicator lamps: [{center: Vector2, on: bool, color: Color}]
var lamps: Array = []
## Assets texture id of this item's final art (art_direction §10).
var texture_id := ""
## False when the case is a device face (the DeskDevice casts the shadow).
var desk_shadow := true
var _flash := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Brief light-up of the case (e.g. the integrity box when you take damage).
func flash() -> void:
	_flash = 1.0


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = move_toward(_flash, 0.0, delta * 2.5)
		queue_redraw()


func _draw() -> void:
	var font := get_theme_default_font()
	var tex := Assets.texture(texture_id) if texture_id != "" else null
	InstrumentStyle.draw_case(self, Rect2(Vector2.ZERO, size), InstrumentStyle.CASE_RADIUS, _flash, tex, desk_shadow)
	for w in windows:
		InstrumentStyle.draw_window(self, w)
	for p in ports:
		InstrumentStyle.draw_round_window(self, p["center"], p["radius"], p.get("glow", Color.WHITE))
	for lp in lamps:
		var c: Vector2 = lp["center"]
		var col: Color = lp.get("color", Assets.color("damage_to_player"))
		draw_circle(c, 9, Assets.color("knob"))
		if lp.get("on", false):
			draw_circle(c, 16, Color(col, 0.18))
			draw_circle(c, 6, col.lerp(Color.WHITE, 0.2))
		else:
			draw_circle(c, 6, col.darkened(0.7))
		draw_circle(c + Vector2(-2, -2), 1.8, Color(1, 1, 1, 0.6))
	for l in labels:
		InstrumentStyle.draw_print(self, font, l["pos"], l["text"], l["size"], l.get("align", HORIZONTAL_ALIGNMENT_LEFT), l.get("width", -1.0))
