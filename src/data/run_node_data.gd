class_name RunNodeData
extends RefCounted
## One step of a run, loaded from data/config/run.json "nodes".
##   {"type": "fight",  "encounter": "01_drone"}
##   {"type": "reward", "size": 3, "pool": ["pulse", ...]}   size/pool optional
##   {"type": "rest",   "effects": [RunEffects...]}          effects optional
##   {"type": "event",  "event": "<event id>"}               resolved by the event engine later

const FIGHT := "fight"
const REWARD := "reward"
const REST := "rest"
const EVENT := "event"
const KINDS := [FIGHT, REWARD, REST, EVENT]

var kind := ""
## Fight: encounter id.
var encounter := ""
## Event: event id (format owned by narrative; opaque to the run layer).
var event := ""
## Reward: offer size override (-1 = rules.reward_offer_size).
var size := -1
## Reward: explicit card pool (empty = every card with reward_weight > 0).
var pool := PackedStringArray()
## Rest: effects applied when the rest is completed (empty = no-op).
var effects: Array[Dictionary] = []


static func from_dict(d: Dictionary, errors: PackedStringArray) -> RunNodeData:
	var n := RunNodeData.new()
	n.kind = str(d.get("type", ""))
	if not n.kind in KINDS:
		errors.append("run node: unknown type '%s'" % n.kind)
	n.encounter = str(d.get("encounter", ""))
	n.event = str(d.get("event", ""))
	n.size = int(d.get("size", -1))
	for id in d.get("pool", []):
		n.pool.append(str(id))
	for e in d.get("effects", []):
		if e is Dictionary:
			n.effects.append(e)
		else:
			errors.append("run node: effect must be an object, got %s" % str(e))
	if n.kind == FIGHT and n.encounter == "":
		errors.append("run node: fight without encounter")
	if n.kind == EVENT and n.event == "":
		errors.append("run node: event without event id")
	if n.kind == REWARD and d.has("size") and n.size < 1:
		errors.append("run node: reward size must be >= 1")
	return n


static func fight(encounter_id: String) -> RunNodeData:
	var n := RunNodeData.new()
	n.kind = FIGHT
	n.encounter = encounter_id
	return n
