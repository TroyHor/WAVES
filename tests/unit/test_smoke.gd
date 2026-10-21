extends TestCase
## Sanity checks for the project skeleton itself.


func test_rules_config_parses() -> void:
	var text := FileAccess.get_file_as_string("res://data/config/rules.json")
	var data = JSON.parse_string(text)
	assert_true(data is Dictionary, "rules.json must be a JSON object")
	assert_eq(int(data["track_length"]), 16)


func test_harness_compares_arrays() -> void:
	assert_eq(PackedInt32Array([1, -2, 0]), [1, -2, 0])
