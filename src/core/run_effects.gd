class_name RunEffects
extends RefCounted
## Small, data-driven changes to a run (used by rest nodes and, later, events).
##   {"type": "hp", "amount": n}          heal (+) or hurt (-), clamped to 0..max
##   {"type": "max_hp", "amount": n}      change max HP (>= 1); HP is clamped to it
##   {"type": "add_card", "card": id}
##   {"type": "remove_card", "card": id}  removes one copy if present
##   {"type": "add_relic", "relic": id}
## New effect types: add a case here + in validate() + a test.

const TYPES := ["hp", "max_hp", "add_card", "remove_card", "add_relic"]


static func validate(effects: Array[Dictionary], db: GameDatabase) -> PackedStringArray:
	var errors := PackedStringArray()
	for e in effects:
		var type := str(e.get("type", ""))
		match type:
			"hp", "max_hp":
				if not e.has("amount"):
					errors.append("effect %s: missing amount" % type)
			"add_card", "remove_card":
				if not db.cards.has(str(e.get("card", ""))):
					errors.append("effect %s: unknown card '%s'" % [type, str(e.get("card", ""))])
			"add_relic":
				if str(e.get("relic", "")) == "":
					errors.append("effect add_relic: missing relic id")
			_:
				errors.append("unknown run effect type '%s'" % type)
	return errors


static func apply(run: RunState, effects: Array[Dictionary]) -> void:
	for e in effects:
		match str(e.get("type", "")):
			"hp":
				run.player_hp = clampi(run.player_hp + int(e.get("amount", 0)), 0, run.player_max_hp)
				if run.player_hp <= 0:
					run.lost = true
			"max_hp":
				run.player_max_hp = maxi(1, run.player_max_hp + int(e.get("amount", 0)))
				run.player_hp = mini(run.player_hp, run.player_max_hp)
			"add_card":
				run.deck_ids.append(str(e["card"]))
			"remove_card":
				var i := run.deck_ids.find(str(e["card"]))
				if i >= 0:
					run.deck_ids.remove_at(i)
			"add_relic":
				run.relic_ids.append(str(e["relic"]))
			_:
				push_error("RunEffects: unknown effect %s" % str(e))
