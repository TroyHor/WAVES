extends TestCase


func test_loads_project_rules_file() -> void:
	var r := RulesConfig.load_file()
	assert_eq(r.track_length, 16)
	assert_eq(r.offtrack_mode, WaveMath.OFFTRACK_TRUNCATE)
	assert_eq(r.overflow_ratio, 1.0)
	assert_true(r.simultaneous_death_is_loss)


func test_from_dict_coerces_json_number_types() -> void:
	var r := RulesConfig.from_dict({"track_length": 12.0, "overflow_ratio": 1, "hand_size": 6.0})
	assert_eq(r.track_length, 12)
	assert_eq(typeof(r.track_length), TYPE_INT)
	assert_eq(r.overflow_ratio, 1.0)
	assert_eq(typeof(r.overflow_ratio), TYPE_FLOAT)


func test_missing_keys_keep_defaults() -> void:
	var r := RulesConfig.from_dict({})
	assert_eq(r.energy_per_turn, 3)
