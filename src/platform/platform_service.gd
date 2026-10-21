extends Node
## Platform abstraction (achievements, cloud saves, user identity).
## Gameplay code only talks to this autoload ("Platform"). Today it is a local
## no-op/offline implementation; a GodotSteam backend will be plugged in later
## without touching gameplay code.

signal achievement_unlocked(id: String)

var backend_name := "offline"
var _unlocked := {}


func is_online() -> bool:
	return false


func unlock_achievement(id: String) -> void:
	if _unlocked.has(id):
		return
	_unlocked[id] = true
	achievement_unlocked.emit(id)


func is_achievement_unlocked(id: String) -> bool:
	return _unlocked.has(id)


## Save files always go through here so a cloud-sync backend can mirror them.
func save_path(file_name: String) -> String:
	return "user://" + file_name
