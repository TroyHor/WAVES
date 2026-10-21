class_name EnemyMove
extends RefCounted
## One entry of an enemy's move pool. A move is a list of wave segments; each
## segment may be placed several times at random offsets and randomly inverted.

const AUTO := -1

var id := ""
var name := ""
var weight := 1.0
## Move id that must follow this one (e.g. charge -> release). Empty = none.
var next := ""
## Max consecutive uses (0 = unlimited).
var max_repeat := 0
## Each: {shape: PackedInt32Array, offset_min, offset_max (AUTO = anywhere it fits),
##        count_min, count_max, flip_chance: float}
var segments: Array[Dictionary] = []


static func from_dict(d: Dictionary, owner_id: String, errors: PackedStringArray) -> EnemyMove:
	var m := EnemyMove.new()
	m.id = str(d.get("id", ""))
	m.name = str(d.get("name", m.id))
	m.weight = float(d.get("weight", 1.0))
	m.next = str(d.get("next", ""))
	m.max_repeat = int(d.get("max_repeat", 0))
	for s in d.get("waves", []):
		var shape := PackedInt32Array()
		for v in s.get("shape", []):
			shape.append(int(v))
		if shape.is_empty():
			errors.append("enemy %s move %s: empty shape" % [owner_id, m.id])
		var offset_range := _range(s.get("offset", null), AUTO)
		var count_range := _range(s.get("count", null), 1)
		m.segments.append({
			"shape": shape,
			"offset_min": offset_range.x, "offset_max": offset_range.y,
			"count_min": count_range.x, "count_max": count_range.y,
			"flip_chance": float(s.get("flip_chance", 0.0)),
		})
	if m.id == "":
		errors.append("enemy %s: move without id" % owner_id)
	if m.segments.is_empty():
		errors.append("enemy %s move %s: no waves" % [owner_id, m.id])
	return m


## Accepts null (default), a number, or [min, max].
static func _range(v: Variant, default: int) -> Vector2i:
	if v == null:
		return Vector2i(default, default)
	if v is Array:
		return Vector2i(int(v[0]), int(v[1]))
	return Vector2i(int(v), int(v))
