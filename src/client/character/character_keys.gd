extends RefCounted

# One server key per character (Steve, 1 Nov 2026; protocol 82). Until now the client sent ONE key per computer, so every character on it shared one server record
# (pack, vitals, learned recipes, goals, Rested, spawn bed). Now each character has its own key, kept in user://character_keys.json:
#   {"map": {character id: key}, "adopted": bool, "forget": [keys of deleted characters, to tell the server at the next join]}
# The first character to play after the update ADOPTS the old machine key, so nobody's existing progress is lost; every later character gets a fresh key.
# shortcut: a forget that never reaches the server (quit before the join) is dropped once sent or lost; the record then stays on the server (harmless, revisit with accounts).

const PATH := "user://character_keys.json"

static var path: String = PATH   # tests point this at a scratch file


static func _read() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"map": {}, "adopted": false, "forget": []}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY:
		return {"map": {}, "adopted": false, "forget": []}

	return {"map": parsed.get("map", {}) if typeof(parsed.get("map", {})) == TYPE_DICTIONARY else {},
		"adopted": bool(parsed.get("adopted", false)),
		"forget": parsed.get("forget", []) if typeof(parsed.get("forget", [])) == TYPE_ARRAY else []}


static func _write(data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify(data))


# The key to send for this character. No character (headless runs, rigs) = the machine key, as before.
static func key_for(character_id: String, machine_key: String) -> String:
	if character_id == "":
		return machine_key

	var data: Dictionary = _read()

	if data["map"].has(character_id) and str(data["map"][character_id]).length() >= 8:
		return str(data["map"][character_id])

	var key: String = machine_key

	if bool(data["adopted"]):
		key = Crypto.new().generate_random_bytes(12).hex_encode()

	data["adopted"] = true
	data["map"][character_id] = key
	_write(data)
	return key


# A character was deleted: remember its key so the server can drop the record at the next join.
static func forget(character_id: String) -> void:
	var data: Dictionary = _read()

	if not data["map"].has(character_id):
		return

	data["forget"].append(str(data["map"][character_id]))
	data["map"].erase(character_id)
	_write(data)


# The keys to tell the server about, once; the list is cleared.
static func take_forgotten() -> Array:
	var data: Dictionary = _read()
	var out: Array = data["forget"]

	if not out.is_empty():
		data["forget"] = []
		_write(data)

	return out
