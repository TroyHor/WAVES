class_name RelicRegistry
extends RefCounted
## id -> factory (Callable returning a Relic). Real relics register here once
## designed; tests register throwaway ones and unregister them afterwards.

static var _factories := {}


static func register(id: String, factory: Callable) -> void:
	_factories[id] = factory


static func unregister(id: String) -> void:
	_factories.erase(id)


static func has(id: String) -> bool:
	return _factories.has(id)


## Null (with an error) for unknown ids.
static func create(id: String) -> Relic:
	if not _factories.has(id):
		push_error("RelicRegistry: unknown relic '%s'" % id)
		return null
	var relic: Relic = _factories[id].call()
	relic.id = id
	return relic


static func create_all(ids: PackedStringArray) -> Array[Relic]:
	var out: Array[Relic] = []
	for id in ids:
		var r := create(id)
		if r != null:
			out.append(r)
	return out
