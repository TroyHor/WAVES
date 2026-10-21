class_name Progress
extends RefCounted
## Persistent meta progress (currently: which tutorial hints were seen).
## Stored through Platform.save_path so a cloud-save backend can mirror it.

const FILE := "progress.json"

var seen_hints := {}
var _path := ""


static func load_from(path: String) -> Progress:
	var p := Progress.new()
	p._path = path
	if FileAccess.file_exists(path):
		var data = JSON.parse_string(FileAccess.get_file_as_string(path))
		if data is Dictionary:
			for id in data.get("seen_hints", []):
				p.seen_hints[str(id)] = true
	return p


func mark_seen(hint_id: String) -> void:
	seen_hints[hint_id] = true
	save()


func reset_hints() -> void:
	seen_hints.clear()
	save()


func save() -> void:
	if _path == "":
		return
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f == null:
		push_warning("Progress: cannot write %s" % _path)
		return
	f.store_string(JSON.stringify({"seen_hints": seen_hints.keys()}, "\t"))
