class_name EnemyData
extends RefCounted
## Static definition of an enemy, loaded from data/enemies/*.json.

var id := ""
var name := ""
var max_hp := 30
## Assets color id used to draw this enemy's channel on the scope.
var color_id := "enemy_ch1"
## Placeholder figure drawn in code until real art exists (see FigureView).
var figure_shape := "orb"
## Assets texture id for the final portrait; falls back to figure_shape.
var texture_id := ""
var moves: Array[EnemyMove] = []


static func from_dict(d: Dictionary, errors: PackedStringArray) -> EnemyData:
	var e := EnemyData.new()
	e.id = str(d.get("id", ""))
	e.name = str(d.get("name", e.id))
	e.max_hp = int(d.get("hp", 30))
	e.color_id = str(d.get("color", e.color_id))
	var fig: Dictionary = d.get("figure", {})
	e.figure_shape = str(fig.get("shape", e.figure_shape))
	e.texture_id = str(fig.get("texture", ""))
	for m in d.get("moves", []):
		e.moves.append(EnemyMove.from_dict(m, e.id, errors))
	if e.id == "":
		errors.append("enemy without id")
	if e.max_hp <= 0:
		errors.append("enemy %s: hp must be positive" % e.id)
	var has_pickable := false
	for m in e.moves:
		if m.weight > 0:
			has_pickable = true
		if m.next != "" and e.find_move(m.next) == null:
			errors.append("enemy %s move %s: next '%s' not found" % [e.id, m.id, m.next])
	if not has_pickable:
		errors.append("enemy %s: needs at least one move with weight > 0" % e.id)
	return e


func find_move(move_id: String) -> EnemyMove:
	for m in moves:
		if m.id == move_id:
			return m
	return null
