class_name FTRecords
extends RefCounted

## Saved run records (user://records.json): one entry per won run, with the
## gear and arsenal that won it. A starting point for meta progression.

const PATH := "user://records.json"

static func load_wins() -> Array:
	if not FileAccess.file_exists(PATH):
		return []
	var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return data.get("wins", []) if data is Dictionary else []

static func add_win(entry: Dictionary) -> void:
	var wins := load_wins()
	wins.append(entry)
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Couldn't save run record: %s" % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify({"wins": wins}, "\t"))
