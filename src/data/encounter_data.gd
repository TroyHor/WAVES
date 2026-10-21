class_name EncounterData
extends RefCounted
## A fight: which enemies (front first) and, for multi-enemy fights, how often
## they swap front/back. Loaded from data/encounters/*.json.

var id := ""
var name := ""
var enemy_ids := PackedStringArray()
## Turns between front/back swaps (0 = never).
var swap_interval := 0


static func from_dict(d: Dictionary, errors: PackedStringArray) -> EncounterData:
	var e := EncounterData.new()
	e.id = str(d.get("id", ""))
	e.name = str(d.get("name", e.id))
	e.swap_interval = int(d.get("swap_interval", 0))
	for id in d.get("enemies", []):
		e.enemy_ids.append(str(id))
	if e.id == "":
		errors.append("encounter without id")
	if e.enemy_ids.is_empty():
		errors.append("encounter %s: no enemies" % e.id)
	return e
