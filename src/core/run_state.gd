class_name RunState
extends RefCounted
## A linear run: fight the encounters in data/config/run.json in order.
## Player HP carries over between fights (it is never refilled).

var encounter_ids := PackedStringArray()
var index := 0
var player_hp := 0
var player_max_hp := 0
var seed_value := 0
var lost := false


static func new_run(db: GameDatabase, rules: RulesConfig, p_seed: int) -> RunState:
	var r := RunState.new()
	r.encounter_ids = db.run_order.duplicate()
	r.player_max_hp = rules.player_max_hp
	r.player_hp = r.player_max_hp
	r.seed_value = p_seed
	return r


func current_encounter_id() -> String:
	return encounter_ids[index] if index < encounter_ids.size() else ""


func is_won() -> bool:
	return not lost and index >= encounter_ids.size()


func is_over() -> bool:
	return lost or is_won()


## Each fight gets its own deterministic seed derived from the run seed.
func make_combat(db: GameDatabase, rules: RulesConfig) -> Combat:
	var enc := db.encounter(current_encounter_id())
	return Combat.new(rules, db.starter_cards(), db.encounter_enemies(enc), seed_value + index * 7919, enc.swap_interval, player_hp)


func complete_combat(combat: Combat) -> void:
	player_hp = combat.player_hp
	if combat.outcome == Combat.Outcome.WON:
		index += 1
	elif combat.outcome == Combat.Outcome.LOST:
		lost = true
