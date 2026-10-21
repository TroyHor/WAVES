class_name GameDatabase
extends RefCounted
## Loads and cross-validates every data file. Adding a card/enemy/encounter is
## just dropping a JSON file into the matching folder.

const CARD_DIR := "res://data/cards/"
const ENEMY_DIR := "res://data/enemies/"
const ENCOUNTER_DIR := "res://data/encounters/"
const STARTER_DECK_PATH := "res://data/config/starter_deck.json"
const RUN_PATH := "res://data/config/run.json"
const HINTS_PATH := "res://data/tutorial/hints.json"

var cards := {}       ## id -> CardData
var enemies := {}     ## id -> EnemyData
var encounters := {}  ## id -> EncounterData
var starter_deck := PackedStringArray()
## Encounter ids of the linear run, in order.
var run_order := PackedStringArray()
## Tutorial hint definitions (see TutorialRules).
var hints: Array[Dictionary] = []
var errors := PackedStringArray()


static func load_default() -> GameDatabase:
	var db := GameDatabase.new()
	for d in _read_dir(CARD_DIR, db.errors):
		var c := CardData.from_dict(d, db.errors)
		db._add(db.cards, c.id, c, "card")
	for d in _read_dir(ENEMY_DIR, db.errors):
		var e := EnemyData.from_dict(d, db.errors)
		db._add(db.enemies, e.id, e, "enemy")
	for d in _read_dir(ENCOUNTER_DIR, db.errors):
		var enc := EncounterData.from_dict(d, db.errors)
		db._add(db.encounters, enc.id, enc, "encounter")
	var starter = _read_json(STARTER_DECK_PATH, db.errors)
	if starter is Dictionary:
		for id in starter.get("cards", []):
			db.starter_deck.append(str(id))
	var run = _read_json(RUN_PATH, db.errors)
	if run is Dictionary:
		for id in run.get("encounters", []):
			db.run_order.append(str(id))
	var hint_data = _read_json(HINTS_PATH, db.errors)
	if hint_data is Dictionary:
		for h in hint_data.get("hints", []):
			if h is Dictionary:
				db.hints.append(h)
	db._validate_refs()
	for e in db.errors:
		push_error("GameDatabase: " + e)
	return db


func card(id: String) -> CardData:
	return cards.get(id)


func enemy(id: String) -> EnemyData:
	return enemies.get(id)


func encounter(id: String) -> EncounterData:
	return encounters.get(id)


func starter_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for id in starter_deck:
		if cards.has(id):
			out.append(cards[id])
	return out


func encounter_enemies(enc: EncounterData) -> Array[EnemyData]:
	var out: Array[EnemyData] = []
	for id in enc.enemy_ids:
		if enemies.has(id):
			out.append(enemies[id])
	return out


## Sorted ids so menus and tests are deterministic.
func encounter_ids() -> PackedStringArray:
	var ids := PackedStringArray(encounters.keys())
	ids.sort()
	return ids


func _add(table: Dictionary, id: String, value: Variant, kind: String) -> void:
	if table.has(id):
		errors.append("duplicate %s id '%s'" % [kind, id])
	table[id] = value


func _validate_refs() -> void:
	if starter_deck.is_empty():
		errors.append("starter deck is empty")
	for id in starter_deck:
		if not cards.has(id):
			errors.append("starter deck: unknown card '%s'" % id)
	if run_order.is_empty():
		errors.append("run order is empty")
	for id in run_order:
		if not encounters.has(id):
			errors.append("run: unknown encounter '%s'" % id)
	errors.append_array(TutorialRules.validate(hints))
	for enc in encounters.values():
		for id in enc.enemy_ids:
			if not enemies.has(id):
				errors.append("encounter %s: unknown enemy '%s'" % [enc.id, id])


static func _read_dir(dir: String, errors: PackedStringArray) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files := DirAccess.get_files_at(dir)
	files.sort()
	for f in files:
		if f.ends_with(".json"):
			var d = _read_json(dir + f, errors)
			if d is Dictionary:
				out.append(d)
	return out


static func _read_json(path: String, errors: PackedStringArray) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		errors.append("%s: %s (line %d)" % [path, json.get_error_message(), json.get_error_line()])
		return null
	if not json.data is Dictionary:
		errors.append("%s: top level must be an object" % path)
		return null
	return json.data
