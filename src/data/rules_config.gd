class_name RulesConfig
extends RefCounted
## Global rule numbers. Defaults here mirror data/config/rules.json; the JSON wins.

const DEFAULT_PATH := "res://data/config/rules.json"

var track_length := 16
var player_max_hp := 60
var energy_per_turn := 3
var hand_size := 5
var max_hand_size := 10
var offtrack_mode := WaveMath.OFFTRACK_TRUNCATE
var overflow_ratio := 1.0
var allow_reposition_before_resolve := true
var simultaneous_death_is_loss := true
## Card rewards (provisional defaults; designer tunes them).
var reward_offer_size := 3
var reward_allow_skip := true


static func load_file(path := DEFAULT_PATH) -> RulesConfig:
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("RulesConfig: cannot parse %s, using defaults" % path)
		return RulesConfig.new()
	return from_dict(data)


static func from_dict(data: Dictionary) -> RulesConfig:
	var cfg := RulesConfig.new()
	for key in data:
		if not key in cfg:
			push_warning("RulesConfig: unknown key '%s'" % key)
			continue
		var current = cfg.get(key)
		# JSON numbers are floats; coerce to the declared type of the default.
		match typeof(current):
			TYPE_INT: cfg.set(key, int(data[key]))
			TYPE_FLOAT: cfg.set(key, float(data[key]))
			TYPE_BOOL: cfg.set(key, bool(data[key]))
			_: cfg.set(key, str(data[key]))
	return cfg
