class_name HintSlip
extends Control
## Tutorial hint as a handwritten duty-log slip (a DeskNote) taped beside the
## instrument it is about, with a grease-pencil arrow drawn to the real object.
## Only the slip's tick box takes mouse input. The caller (CombatScreen) offers
## candidate spots that keep readings, counters, the fire key and the slots
## clear; the first spot the text fits in is used.

signal dismissed

const MAX_W := 520.0
const PENCIL_W := 4.0
const HEAD_LEN := 20.0

var text := ""
var show_tick := true
var note: DeskNote
## Arrow route in screen-local coordinates: slip edge -> via... -> tip.
var _path := PackedVector2Array()
## Share of the arrow drawn so far (it is drawn in after the slip lands).
var _draw_t := 0.0:
	set(v):
		_draw_t = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	note = DeskNote.new()
	note.wrap = true
	note.max_design = 22
	note.min_design = 18
	note.grow_down = true
	note.tick_box = show_tick
	note.lines = PackedStringArray(text.split("\n"))
	note.ticked.connect(_on_ticked)
	add_child(note)
	modulate.a = 0.0


## Places the slip in the first spot its text fits. Each candidate:
## {spot: Rect2, align: 0..1 (x inside the spot), prefer_y: float,
##  tip: Vector2, via: PackedVector2Array, start_dy: float}; without a tip
## no arrow is drawn. Returns the chosen index.
func place(cands: Array) -> int:
	var pick := cands.size() - 1
	for i in cands.size():
		var sp: Rect2 = cands[i]["spot"]
		note.max_h = sp.size.y
		if note.height_for(minf(sp.size.x, MAX_W)) <= sp.size.y:
			pick = i
			break
	var c: Dictionary = cands[pick]
	var spot: Rect2 = c["spot"]
	var w := minf(spot.size.x, MAX_W)
	note.max_h = spot.size.y
	var h := note.height_for(w)
	var top := clampf(float(c.get("prefer_y", spot.position.y)) - h * 0.4, spot.position.y, maxf(spot.position.y, spot.end.y - h))
	note.place(spot.position.x + (spot.size.x - w) * float(c.get("align", 0.0)), top, w)
	# A slight, stable tilt per hint (pinned by hand, not aligned).
	note.rotation = (float(hash(text) % 7) - 3.0) * 0.006
	_path = PackedVector2Array()
	queue_redraw()
	if not c.has("tip"):
		return pick
	var tip: Vector2 = c["tip"]
	var via: PackedVector2Array = c.get("via", PackedVector2Array())
	var toward := via[0] if not via.is_empty() else tip
	var r := note.get_rect()
	# `start_dy` drops the start down the slip's edge (a longer, slanted
	# stroke where the slip sits right beside its target).
	toward.y += float(c.get("start_dy", 0.0))
	var start := Vector2(clampf(toward.x, r.position.x + 6.0, r.end.x - 6.0), clampf(toward.y, r.position.y + 6.0, r.end.y - 6.0))
	_path = PackedVector2Array([start])
	_path.append_array(via)
	_path.append(tip)
	return pick


## Slip lands (fade in, settles), then the arrow is drawn in.
func appear() -> void:
	note.scale = Vector2(1.05, 1.05)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.18)
	tw.parallel().tween_property(note, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "_draw_t", 1.0, 0.35).set_ease(Tween.EASE_OUT)


## Slip is taken down: slides a little and fades, then frees itself.
func leave() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween()
	tw.tween_property(note, "position:y", note.position.y + 14.0, 0.25)
	tw.parallel().tween_property(self, "modulate:a", 0.0, 0.25)
	tw.tween_callback(queue_free)


func _on_ticked() -> void:
	await get_tree().create_timer(0.3).timeout
	dismissed.emit()


func _draw() -> void:
	if _path.size() < 2 or _draw_t <= 0.0:
		return
	var pts := _wobbly(_path)
	var total := 0.0
	for i in range(1, pts.size()):
		total += pts[i].distance_to(pts[i - 1])
	var shown := PackedVector2Array([pts[0]])
	var left := total * _draw_t
	for i in range(1, pts.size()):
		var d := pts[i].distance_to(pts[i - 1])
		if d >= left:
			shown.append(pts[i - 1].lerp(pts[i], left / maxf(d, 0.001)))
			break
		shown.append(pts[i])
		left -= d
	# Light pencil with a dark edge: readable on the cream cases and the
	# dark desk alike.
	var shadow := Color(0, 0, 0, 0.35)
	var edge := Color(Assets.color("paper_ink"), 0.9)
	var pencil := Assets.color("grease_pencil")
	var strokes: Array[PackedVector2Array] = [shown]
	if _draw_t >= 1.0:
		var tip := _path[_path.size() - 1]
		var dir := (tip - _path[_path.size() - 2]).normalized()
		for s in [-1.0, 1.0]:
			strokes.append(PackedVector2Array([tip - dir.rotated(s * 0.5) * HEAD_LEN, tip]))
	for st in strokes:
		draw_polyline(_offset(st, Vector2(2, 3)), shadow, PENCIL_W + 3.0, true)
	for st in strokes:
		draw_polyline(st, edge, PENCIL_W + 3.0, true)
	for st in strokes:
		draw_polyline(st, pencil, PENCIL_W, true)


## Hand-drawn look: each segment subdivided and nudged sideways a little.
func _wobbly(path: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([path[0]])
	var dist := 0.0
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var n := maxi(1, int(a.distance_to(b) / 14.0))
		var perp := (b - a).normalized().orthogonal()
		for k in range(1, n + 1):
			var f := float(k) / n
			dist += a.distance_to(b) / n
			var wob := sin(dist * 0.06 + float(i) * 1.7) * 1.6 if k < n else 0.0
			out.append(a.lerp(b, f) + perp * wob)
	return out


static func _offset(p: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q in p:
		out.append(q + d)
	return out
