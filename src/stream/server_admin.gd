extends RefCounted

# Who may use the admin RPCs (placing markers and NPCs): a list of player keys in data/admin.json (gitignored: the real keys are
# never committed; data/admin.example.json shows the shape). With no file there are no admins and every admin RPC is refused.

var _keys: Dictionary = {}
var open_to_all: bool = false     # --open-admin on the server command line: every player is an admin (headless tests only)


func load_keys(paths: Array = ["res://data/admin.json"]) -> void:
	_keys.clear()

	for path in paths:
		if not FileAccess.file_exists(str(path)):
			continue

		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(path)))

		if typeof(parsed) == TYPE_DICTIONARY:
			for key in parsed.get("keys", []):
				_keys[str(key)] = true


func is_admin(key: String) -> bool:
	return open_to_all or (key != "" and _keys.has(key))


func count() -> int:
	return _keys.size()
