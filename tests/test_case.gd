class_name TestCase
extends RefCounted
## Minimal assertion base class. Every method named `test_*` in a subclass
## under tests/unit/ is run by tests/run_tests.gd.

var failures: Array[String] = []


func assert_true(cond: bool, msg := "") -> void:
	if not cond:
		_fail("expected true" + _suffix(msg))


func assert_false(cond: bool, msg := "") -> void:
	if cond:
		_fail("expected false" + _suffix(msg))


func assert_eq(actual: Variant, expected: Variant, msg := "") -> void:
	if not _equal(actual, expected):
		_fail("expected %s, got %s%s" % [str(expected), str(actual), _suffix(msg)])


func assert_ne(actual: Variant, unexpected: Variant, msg := "") -> void:
	if _equal(actual, unexpected):
		_fail("did not expect %s%s" % [str(unexpected), _suffix(msg)])


func _equal(a: Variant, b: Variant) -> bool:
	# Compare typed/untyped arrays by content so tests can use literals.
	if (a is Array or a is PackedInt32Array) and (b is Array or b is PackedInt32Array):
		if a.size() != b.size():
			return false
		for i in a.size():
			if not _equal(a[i], b[i]):
				return false
		return true
	return typeof(a) == typeof(b) and a == b


func _fail(text: String) -> void:
	failures.append(text)


func _suffix(msg: String) -> String:
	return "" if msg == "" else " — " + msg
