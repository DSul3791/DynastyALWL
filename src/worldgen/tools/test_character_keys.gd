extends SceneTree

# One server key per character (protocol 82): the client key map (adopt the machine key once, fresh key after, forget list) and the server's forget_key.
#   godot --headless --path . --script res://src/worldgen/tools/test_character_keys.gd

const Keys := preload("res://src/client/character/character_keys.gd")
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


func _init() -> void:
	Keys.path = "user://test_character_keys.json"

	if FileAccess.file_exists(Keys.path):
		DirAccess.remove_absolute(Keys.path)

	var machine: String = "machinekey000000000001"
	check(Keys.key_for("", machine) == machine, "no character: the machine key, as before")
	check(not FileAccess.file_exists(Keys.path), "no character writes nothing")
	var first: String = Keys.key_for("c1", machine)
	check(first == machine, "the first character to play adopts the old machine key")
	var second: String = Keys.key_for("c2", machine)
	check(second != machine and second.length() >= 8, "a later character gets its own key")
	check(Keys.key_for("c2", machine) == second and Keys.key_for("c1", machine) == machine, "keys are stable")
	Keys.forget("c2")
	check(Keys.key_for("c2", machine) != second, "a deleted character's key is not reused")
	Keys.forget("nobody")
	var forgotten: Array = Keys.take_forgotten()
	check(forgotten == [second], "the forget list holds the deleted key once: %s" % str(forgotten))
	check(Keys.take_forgotten().is_empty(), "and it is cleared after it is taken")
	FileAccess.open(Keys.path, FileAccess.WRITE).store_string("not json")
	check(Keys.key_for("c9", machine).length() >= 8, "a corrupt key file does not stop the game")
	DirAccess.remove_absolute(Keys.path)

	var dir: String = "user://test_character_keys"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	items.peer_connected_hello(1, "key-aaaaaaaa-0001")
	items.peer_connected_hello(2, "key-bbbbbbbb-0002")
	items.peer_connected_hello(3, "key-cccccccc-0003")
	items._characters["key-bbbbbbbb-0002"]["learned"] = {"5": true}
	items.peer_left(2)
	check(not items.forget_key(1, "key-aaaaaaaa-0001"), "a player cannot forget the key they are playing")
	check(not items.forget_key(1, "key-cccccccc-0003"), "nor a key someone else is playing")
	check(not items.forget_key(1, "key-unknown-9999"), "nor a key the server never saw")
	check(not items.forget_key(7, "key-bbbbbbbb-0002"), "a peer that has not said hello cannot forget anything")
	check(items._characters.has("key-bbbbbbbb-0002"), "all refusals left the record alone")
	check(items.forget_key(1, "key-bbbbbbbb-0002"), "an offline character is forgotten")
	check(not items._characters.has("key-bbbbbbbb-0002") and not items._inventories.has("key-bbbbbbbb-0002") and not items._vitals.has("key-bbbbbbbb-0002"), "record, pack and vitals are gone")
	check(items._characters.has("key-aaaaaaaa-0001") and items._inventories.has("key-cccccccc-0003"), "the others are untouched")
	items._save_characters()
	var again = make(dir)
	again._load_characters()
	check(not again._characters.has("key-bbbbbbbb-0002") and again._characters.has("key-aaaaaaaa-0001"), "the deletion survives a restart")

	if failures == 0:
		print("Test done: all pass")
	else:
		print("Test done: ", failures, " fail")

	quit(1 if failures > 0 else 0)
