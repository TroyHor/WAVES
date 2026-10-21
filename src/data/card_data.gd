class_name CardData
extends RefCounted
## Static definition of a card, loaded from data/cards/*.json.
##
## JSON fields:
##   id, name, cost            required
##   wave: [int...]            single-lane waveform, or
##   waves: [[int...], ...]    one waveform per lane (chord card); omit both for non-wave cards
##   flippable: bool           player may invert the wave while placing it
##   echo: int                 also place a copy `echo` cells after the start
##   on_play: [{type, ...}]    immediate effects; currently {"type": "draw", "amount": n}
##   description: String      extra rules text (keywords are rendered automatically)

const KNOWN_KEYS := ["id", "name", "cost", "wave", "waves", "flippable", "echo", "on_play", "description"]
const EFFECT_TYPES := ["draw"]

var id := ""
var name := ""
var cost := 0
var waves: Array[PackedInt32Array] = []
var flippable := false
var echo := 0
var on_play: Array[Dictionary] = []
var description := ""


func has_wave() -> bool:
	return not waves.is_empty()


## Cards with immediate effects can't be taken back once played.
func is_retractable() -> bool:
	return on_play.is_empty()


## Number of track cells the card spans on its lane, including its echo.
func span() -> int:
	var longest := 0
	for w in waves:
		longest = maxi(longest, w.size())
	return longest + maxi(echo, 0)


static func from_dict(d: Dictionary, errors: Array[String]) -> CardData:
	var c := CardData.new()
	var where := "card '%s'" % str(d.get("id", "?"))
	for key in d:
		if not key in KNOWN_KEYS:
			errors.append("%s: unknown key '%s'" % [where, key])
	if not d.get("id") is String or d["id"] == "":
		errors.append("%s: missing id" % where)
	c.id = str(d.get("id", ""))
	c.name = str(d.get("name", c.id))
	c.cost = int(d.get("cost", -1))
	if c.cost < 0:
		errors.append("%s: cost must be >= 0" % where)
	var raw_waves: Array = []
	if d.has("wave"):
		raw_waves = [d["wave"]]
	elif d.has("waves"):
		raw_waves = d["waves"]
	for rw in raw_waves:
		var w := _int_array(rw)
		if w.is_empty():
			errors.append("%s: waves must be non-empty integer arrays" % where)
		c.waves.append(w)
	c.flippable = bool(d.get("flippable", false))
	c.echo = int(d.get("echo", 0))
	for e in d.get("on_play", []):
		if not e is Dictionary or not e.get("type") in EFFECT_TYPES:
			errors.append("%s: unknown on_play effect %s" % [where, str(e)])
			continue
		c.on_play.append(e)
	c.description = str(d.get("description", ""))
	if not c.has_wave() and c.on_play.is_empty():
		errors.append("%s: card has neither a wave nor an effect" % where)
	return c


static func _int_array(raw: Variant) -> PackedInt32Array:
	var out := PackedInt32Array()
	if not raw is Array:
		return out
	for v in raw:
		if not (v is float or v is int) or float(v) != floorf(float(v)):
			return PackedInt32Array()
		out.append(int(v))
	return out
