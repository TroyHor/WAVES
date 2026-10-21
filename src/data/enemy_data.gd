class_name EnemyData
extends RefCounted
## Static definition of an enemy, loaded from data/enemies/*.json.
##
## JSON fields:
##   id, name, hp                  required
##   lanes: int                    number of lanes this enemy occupies (default 1)
##   moves: [                      intent pool; one move is drawn at random each turn
##     { id, name,
##       weight: number            relative chance; 0 = only reachable through `next`
##       max_repeat: int           max consecutive uses (0 = unlimited)
##       next: String              move forced on the following turn
##       waves: [ { shape: [int...], lane: int,
##                  offset: int | [min, max],   random start cell (inclusive)
##                  random_flip: bool } ] } ]

const KNOWN_KEYS := ["id", "name", "hp", "lanes", "moves", "description"]


class MoveWave:
	var shape: PackedInt32Array
	var lane := 0
	var offset_min := 0
	var offset_max := 0
	var random_flip := false


class Move:
	var id := ""
	var name := ""
	var weight := 1.0
	var max_repeat := 0
	var next := ""
	var waves: Array[MoveWave] = []


var id := ""
var name := ""
var hp := 1
var lanes := 1
var moves: Array[Move] = []
var description := ""


func move_by_id(move_id: String) -> Move:
	for m in moves:
		if m.id == move_id:
			return m
	return null


static func from_dict(d: Dictionary, errors: Array[String]) -> EnemyData:
	var e := EnemyData.new()
	var where := "enemy '%s'" % str(d.get("id", "?"))
	for key in d:
		if not key in KNOWN_KEYS:
			errors.append("%s: unknown key '%s'" % [where, key])
	e.id = str(d.get("id", ""))
	if e.id == "":
		errors.append("%s: missing id" % where)
	e.name = str(d.get("name", e.id))
	e.hp = int(d.get("hp", 0))
	if e.hp <= 0:
		errors.append("%s: hp must be > 0" % where)
	e.lanes = int(d.get("lanes", 1))
	e.description = str(d.get("description", ""))
	for md in d.get("moves", []):
		var m := Move.new()
		m.id = str(md.get("id", ""))
		m.name = str(md.get("name", m.id))
		m.weight = float(md.get("weight", 1.0))
		m.max_repeat = int(md.get("max_repeat", 0))
		m.next = str(md.get("next", ""))
		for wd in md.get("waves", []):
			var w := MoveWave.new()
			w.shape = CardData._int_array(wd.get("shape"))
			if w.shape.is_empty():
				errors.append("%s/%s: wave shape must be a non-empty integer array" % [where, m.id])
			w.lane = int(wd.get("lane", 0))
			if w.lane < 0 or w.lane >= e.lanes:
				errors.append("%s/%s: lane %d out of range" % [where, m.id, w.lane])
			var off = wd.get("offset", 0)
			if off is Array and off.size() == 2:
				w.offset_min = int(off[0])
				w.offset_max = int(off[1])
			else:
				w.offset_min = int(off)
				w.offset_max = w.offset_min
			if w.offset_max < w.offset_min:
				errors.append("%s/%s: offset range reversed" % [where, m.id])
			w.random_flip = bool(wd.get("random_flip", false))
			m.waves.append(w)
		e.moves.append(m)
	if e.moves.is_empty():
		errors.append("%s: needs at least one move" % where)
	for m in e.moves:
		if m.next != "" and e.move_by_id(m.next) == null:
			errors.append("%s/%s: next move '%s' does not exist" % [where, m.id, m.next])
	return e
