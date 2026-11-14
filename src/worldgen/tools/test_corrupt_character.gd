extends SceneTree

# A damaged character record does not lose the others (SCOPE_STEVE item 5): characters.json with one good record and several garbage ones (a string, a number, null,
# a list) loads the good one and skips the rest; a file whose players entry is not a table loads nothing and does not crash.
#   godot --headless --path . --script res://src/worldgen/tools/test_corrupt_character.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.setup(ItemTableScript.load_default(), dir)
	return items


func write(dir: String, content: String) -> void:
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var f: FileAccess = FileAccess.open(dir + "/characters.json", FileAccess.WRITE)
	f.store_string(content)
	f.close()


func _init() -> void:
	var dir: String = "user://test_corrupt_character"
	write(dir, JSON.stringify({"version": 1, "players": {"good_key_0000000001": {"luck": 3, "fitness": 2, "coins": 40}, "bad_string_00000000": "oops", "bad_number_00000000": 7, "bad_null_000000000000": null, "bad_list_0000000000": [1, 2], "good_key_0000000002": {"luck": -2}}}))
	var a = make(dir)
	check(a._characters.has("good_key_0000000001") and int(a._characters["good_key_0000000001"]["luck"]) == 3 and a._characters["good_key_0000000001"]["purse"] == {"coin_bronze": 4}, "the first good record survives (an older row's 40 copper purse reads as 4 bronze)")
	check(a._characters.has("good_key_0000000002") and int(a._characters["good_key_0000000002"]["luck"]) == -2, "the one after the damaged ones survives")
	check(not a._characters.has("bad_string_00000000") and not a._characters.has("bad_number_00000000") and not a._characters.has("bad_null_000000000000") and not a._characters.has("bad_list_0000000000"), "damaged records are skipped")

	write(dir, JSON.stringify({"version": 1, "players": "not a table"}))
	var b = make(dir)
	check(b._characters.is_empty(), "players that is not a table loads nothing and does not crash")
	write(dir, JSON.stringify([1, 2, 3]))
	var c = make(dir)
	check(c._characters.is_empty(), "a file that is not a table loads nothing and does not crash")
	write(dir, JSON.stringify({"version": 1, "players": {"only_key_00000000001": {"luck": 1}}}))
	var d = make(dir)
	d.peer_connected_hello(1, "only_key_00000000001")
	check(int(d._characters["only_key_00000000001"]["luck"]) == 1, "a clean file still loads and a player joins on it")

	print("test_corrupt_character: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
