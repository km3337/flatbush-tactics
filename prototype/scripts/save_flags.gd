class_name FTSaveFlags
extends RefCounted

## One-off player flags that last between runs and sessions
## (user://flags.json), e.g. whether the tutorial has been played.

const PATH := "user://flags.json"
const TUTORIAL_DONE := &"tutorial_done"

static func has(flag: StringName) -> bool:
	return bool(_load().get(String(flag), false))

static func set_flag(flag: StringName, value := true) -> void:
	var data := _load()
	data[String(flag)] = value
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Couldn't save flags: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))

static func _load() -> Dictionary:
	if not FileAccess.file_exists(PATH):
		return {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return data if data is Dictionary else {}
