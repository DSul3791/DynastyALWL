extends SceneTree

# A save file missing while its .tmp or .prev is there (server_items.restore_missing, 22 Nov 2026): on Windows Godot's rename removes the old
# file before moving the .tmp over it, so a hard stop between the two left only .tmp and .prev and the loader started that part empty.
#   godot --headless --path . --script res://src/worldgen/tools/test_save_restore_missing.gd

const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _put(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _seconds(path: String) -> int:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return int(parsed.get("s", -1)) if typeof(parsed) == TYPE_DICTIONARY else -1


func _initialize() -> void:
	var dir: String = ProjectSettings.globalize_path("user://test_save_restore_missing")
	DirAccess.make_dir_recursive_absolute(dir)
	var path: String = dir + "/part.json"

	for suffix in ["", ".tmp", ".prev"]:
		DirAccess.remove_absolute(path + suffix)

	# Two saves: the second keeps the first as .prev.
	ItemsScript._write_file(path, JSON.stringify({"s": 1}))
	ItemsScript._write_file(path, JSON.stringify({"s": 2}))
	check(_seconds(path) == 2 and _seconds(path + ".prev") == 1, "two saves leave the newest and its .prev")
	check(ItemsScript.restore_missing(path) == "" and _seconds(path) == 2, "a file that is there is left alone")

	# 1. The Windows gap: the old file removed, the whole .tmp not moved yet. The .tmp is the newer save and is used.
	_put(path + ".tmp", JSON.stringify({"s": 3}))
	DirAccess.remove_absolute(path)
	check(ItemsScript.restore_missing(path) != "" and _seconds(path) == 3 and not FileAccess.file_exists(path + ".tmp"), "a missing file comes back from its whole .tmp")

	# 2. Missing, with a torn .tmp: the .prev is used.
	_put(path + ".tmp", "{\"s\": 4")
	DirAccess.remove_absolute(path)
	check(ItemsScript.restore_missing(path) != "" and _seconds(path) == 1, "a torn .tmp is passed over for the .prev")

	# 3. Missing with only a .prev.
	DirAccess.remove_absolute(path + ".tmp")
	DirAccess.remove_absolute(path)
	check(ItemsScript.restore_missing(path) != "" and _seconds(path) == 1, "a missing file comes back from its .prev")

	# 4. Nothing at all (a fresh store): nothing made.
	for suffix in ["", ".tmp", ".prev"]:
		DirAccess.remove_absolute(path + suffix)

	check(ItemsScript.restore_missing(path) == "" and not FileAccess.file_exists(path), "a fresh store stays empty")
	print("test_save_restore_missing: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(1 if failures > 0 else 0)
