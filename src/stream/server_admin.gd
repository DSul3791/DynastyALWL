extends RefCounted

# Who may use the admin RPCs (placing markers and NPCs): a list of player keys in data/admin.json (gitignored: the real keys are
# never committed; data/admin.example.json shows the shape). With no file there are no admins and every admin RPC is refused.

# The check is on when data/items/admin_setting.json "check_admin" is true or the server was started with --check-admin (a server for
# other players, server/client split A5); off (local play, the default) makes everybody an admin. With --check-admin, --open-admin is
# ignored, so a test switch can never open a server for other players.
var _keys: Dictionary = {}
var strict: bool = OS.get_cmdline_user_args().has("--check-admin")
var enforce: bool = check_enabled() or strict
var open_to_all: bool = false     # --open-admin on the server command line: every player is an admin (headless tests only; ignored under --check-admin)


static func check_enabled() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/admin_setting.json"))
	return typeof(parsed) == TYPE_DICTIONARY and bool(parsed.get("check_admin", false))


func load_keys(paths: Array = ["res://data/admin.json"]) -> void:
	_keys.clear()

	for path in paths:
		if not FileAccess.file_exists(str(path)):
			continue

		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(path)))

		if typeof(parsed) == TYPE_DICTIONARY:
			for key in parsed.get("keys", []):
				_keys[str(key)] = true


# `key` is the store key or an account id ("local:<key>"); admin.json lists raw keys and is never logged.
func is_admin(key: String) -> bool:
	key = key.trim_prefix("local:")
	return not enforce or (open_to_all and not strict) or (key != "" and _keys.has(key))


func count() -> int:
	return _keys.size()


# One line for the server log at start: whether the check is on and how many keys it holds (never the keys).
func describe() -> String:
	if not enforce:
		return "admin check off: everybody is an admin (local play)"

	return "admin check on: %d admin key%s%s" % [count(), "" if count() == 1 else "s", "" if count() > 0 else " (nobody is an admin: add <store>/admin.json)"]
