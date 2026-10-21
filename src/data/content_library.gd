class_name ContentLibrary
extends RefCounted
## All data-driven content (cards, enemies, starter deck). Load once and share.

const CARDS_DIR := "res://data/cards/"
const ENEMIES_DIR := "res://data/enemies/"
const STARTER_DECK_PATH := "res://data/config/starter_deck.json"

var cards := {}    ## id -> CardData
var enemies := {}  ## id -> EnemyData
var starter_deck: Array[String] = []
var errors: Array[String] = []


static func load_default() -> ContentLibrary:
	var lib := ContentLibrary.new()
	for d in _read_dir(CARDS_DIR, lib.errors):
		var c := CardData.from_dict(d, lib.errors)
		if lib.cards.has(c.id):
			lib.errors.append("duplicate card id '%s'" % c.id)
		lib.cards[c.id] = c
	for d in _read_dir(ENEMIES_DIR, lib.errors):
		var e := EnemyData.from_dict(d, lib.errors)
		if lib.enemies.has(e.id):
			lib.errors.append("duplicate enemy id '%s'" % e.id)
		lib.enemies[e.id] = e
	var deck = JSON.parse_string(FileAccess.get_file_as_string(STARTER_DECK_PATH))
	if deck is Dictionary and deck.get("cards") is Array:
		for id in deck["cards"]:
			if not lib.cards.has(str(id)):
				lib.errors.append("starter deck: unknown card '%s'" % id)
			lib.starter_deck.append(str(id))
	else:
		lib.errors.append("cannot parse %s" % STARTER_DECK_PATH)
	for err in lib.errors:
		push_error("Content: " + err)
	return lib


func enemy_ids() -> Array[String]:
	var out: Array[String] = []
	for id in enemies:
		out.append(id)
	out.sort()
	return out


static func _read_dir(dir: String, errors: Array[String]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var files := DirAccess.get_files_at(dir)
	files.sort()
	for f in files:
		if not f.ends_with(".json"):
			continue
		var data = JSON.parse_string(FileAccess.get_file_as_string(dir + f))
		if data is Dictionary:
			out.append(data)
		else:
			errors.append("cannot parse %s%s" % [dir, f])
	return out
