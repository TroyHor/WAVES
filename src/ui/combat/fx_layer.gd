class_name FxLayer
extends Control
## Transient effects drawn above everything: damage projectiles flying from
## the collision strip to their target, and floating damage numbers.

var _projectiles: Array = []  ## {from, to, color, start, dur, size}
var _floaters: Array = []     ## {pos, text, color, start, dur}
var _sparks: Array = []       ## {pos, vel, life, max_life, color}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


## Positions are global.
func shoot(from: Vector2, to: Vector2, color: Color, delay: float, dur: float, size_px: float) -> void:
	_projectiles.append({"from": from - global_position, "to": to - global_position, "color": color,
		"start": _now() + delay, "dur": dur, "size": size_px})


func float_text(pos: Vector2, text: String, color: Color) -> void:
	_floaters.append({"pos": pos - global_position, "text": text, "color": color, "start": _now(), "dur": 1.1})


## Overload spark: a short glowing streak thrown upward that falls back.
func spark(pos: Vector2, color: Color) -> void:
	var v := Vector2(randf_range(-220.0, 220.0), randf_range(-420.0, -160.0))
	var life := randf_range(0.35, 0.7)
	_sparks.append({"pos": pos - global_position, "vel": v, "life": life, "max_life": life, "color": color})


func _process(delta: float) -> void:
	for sp in _sparks:
		sp["vel"] += Vector2(0, 900.0) * delta
		sp["pos"] += sp["vel"] * delta
		sp["life"] -= delta
	_sparks = _sparks.filter(func(sp: Dictionary) -> bool: return sp["life"] > 0.0)
	var now := _now()
	_projectiles = _projectiles.filter(func(p: Dictionary) -> bool: return now < p["start"] + p["dur"])
	_floaters = _floaters.filter(func(f: Dictionary) -> bool: return now < f["start"] + f["dur"])
	queue_redraw()


func _draw() -> void:
	var now := _now()
	var font := get_theme_default_font()
	for p in _projectiles:
		var k: float = (now - p["start"]) / p["dur"]
		if k < 0.0:
			continue
		var col: Color = p["color"]
		# Trail of fading dots along an arcing path.
		for i in 7:
			var kk := clampf(k - i * 0.035, 0.0, 1.0)
			var e := kk * kk * (3.0 - 2.0 * kk)
			var pos: Vector2 = p["from"].lerp(p["to"], e)
			pos.x += sin(kk * PI) * 40.0 * signf(p["to"].x - p["from"].x + 0.01)
			draw_circle(pos, p["size"] * (1.0 - i * 0.12), Color(col, (1.0 - i * 0.14) * 0.9))
	for sp in _sparks:
		var k: float = sp["life"] / sp["max_life"]
		var p: Vector2 = sp["pos"]
		var tail: Vector2 = p - (sp["vel"] as Vector2) * 0.06
		var col: Color = sp["color"]
		draw_circle(p, 14.0 * k + 4.0, Color(col, k * 0.18))
		draw_line(tail, p, Color(col, k * 0.45), 10.0, true)
		draw_line(tail, p, Color(col, k * 0.9), 4.5, true)
		draw_line(tail, p, Color(col.lerp(Color.WHITE, 0.75), k), 2.0, true)
		draw_circle(p, 4.0 * k + 1.5, Color(col.lerp(Color.WHITE, 0.85), k))
	for f in _floaters:
		var k: float = (now - f["start"]) / f["dur"]
		var pos: Vector2 = f["pos"] + Vector2(0, -60.0 * k)
		# Pop: starts large and settles, Balatro-style.
		var fs := Assets.fs(44.0 * (1.0 + 0.6 * pow(1.0 - minf(k * 4.0, 1.0), 2)))
		draw_string(font, pos + Vector2(-100, 0), f["text"], HORIZONTAL_ALIGNMENT_CENTER, 200, fs, Color(f["color"], 1.0 - k * k))
