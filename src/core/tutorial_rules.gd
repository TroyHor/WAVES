class_name TutorialRules
extends RefCounted
## Decides which tutorial hint (data/tutorial/hints.json) to show, given a
## snapshot of the game state. Pure: the UI builds the context and renders.
##
## Hint: {id, text, anchor, after?, complete?, trigger: {conditions...}}
## All trigger conditions present must hold; `after` must already be seen.

const ANCHORS := ["enemy_scope", "player_scope", "collision", "hand", "resolve", "player_figure", "enemy_figure", "energy", "none"]
const COMPLETE := ["button", "card_played", "resolve"]
const CONDITIONS := ["encounter", "turn", "run_index", "hand_keyword", "hand_effect", "preview_outcome", "multi_enemy", "forced_next", "played_at_least"]


## ctx keys: encounter: String, turn: int, run_index: int, hand_keywords: Array,
## hand_effects: Array, preview_outcomes: Array[String], multi_enemy: bool,
## forced_next: bool, played: int
static func matches(hint: Dictionary, ctx: Dictionary, seen: Dictionary) -> bool:
	var id: String = hint.get("id", "")
	if seen.has(id):
		return false
	var after: String = hint.get("after", "")
	if after != "" and not seen.has(after):
		return false
	var trig: Dictionary = hint.get("trigger", {})
	for key in trig:
		var want = trig[key]
		match key:
			"encounter":
				if ctx.get("encounter", "") != want:
					return false
			"turn":
				if ctx.get("turn", 0) != int(want):
					return false
			"run_index":
				if ctx.get("run_index", -1) != int(want):
					return false
			"hand_keyword":
				if not want in ctx.get("hand_keywords", []):
					return false
			"hand_effect":
				if not want in ctx.get("hand_effects", []):
					return false
			"preview_outcome":
				if not want in ctx.get("preview_outcomes", []):
					return false
			"multi_enemy":
				if ctx.get("multi_enemy", false) != bool(want):
					return false
			"forced_next":
				if ctx.get("forced_next", false) != bool(want):
					return false
			"played_at_least":
				if ctx.get("played", 0) < int(want):
					return false
	return true


## First matching hint in file order, or {} if none.
static func next_hint(hints: Array[Dictionary], ctx: Dictionary, seen: Dictionary) -> Dictionary:
	for h in hints:
		if matches(h, ctx, seen):
			return h
	return {}


static func outcome_names(result: TrackResult) -> Array[String]:
	var out: Array[String] = []
	for o in result.outcome:
		var n := ""
		match o:
			TrackResult.Outcome.OVERFLOW: n = "overflow"
			TrackResult.Outcome.CANCELLED: n = "cancelled"
			TrackResult.Outcome.PLAYER_HIT: n = "player_hit"
			TrackResult.Outcome.ENEMY_HIT: n = "enemy_hit"
		if n != "" and not n in out:
			out.append(n)
	return out


static func validate(hints: Array[Dictionary]) -> PackedStringArray:
	var errors := PackedStringArray()
	var ids := {}
	for h in hints:
		var id: String = h.get("id", "")
		if id == "" or ids.has(id):
			errors.append("hint: missing or duplicate id '%s'" % id)
		ids[id] = true
		if str(h.get("text", "")) == "":
			errors.append("hint %s: empty text" % id)
		if not h.get("anchor", "none") in ANCHORS:
			errors.append("hint %s: unknown anchor '%s'" % [id, h.get("anchor")])
		if not h.get("complete", "button") in COMPLETE:
			errors.append("hint %s: unknown complete '%s'" % [id, h.get("complete")])
		for key in h.get("trigger", {}):
			if not key in CONDITIONS:
				errors.append("hint %s: unknown trigger condition '%s'" % [id, key])
	for h in hints:
		var after: String = h.get("after", "")
		if after != "" and not ids.has(after):
			errors.append("hint %s: after '%s' not found" % [h.get("id", ""), after])
	return errors
