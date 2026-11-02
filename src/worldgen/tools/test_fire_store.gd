extends SceneTree

# The fire's store is what burns (Dave 2 Nov 2026): wood put in it counts when it is closed (burn time and tier), wood taken out stops counting, an empty store means no
# burn time (a burning fire goes out), burned wood leaves the store, and hold E picks up an unlit fire with an empty store.
#   godot --headless --path . --script res://src/worldgen/tools/test_fire_store.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var said: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	DirAccess.make_dir_recursive_absolute("user://test_fire_store")

	for file in DirAccess.get_files_at("user://test_fire_store"):
		DirAccess.remove_absolute("user://test_fire_store/" + file)

	var f = ItemsScript.new()
	f.send_full = func(_p, _b): pass
	f.send_slots = func(_p, _b): pass
	f.send_world_items = func(_p, _a, _r): pass
	f.send_notice = func(_p, t): said.append(t)
	f.setup(ItemTableScript.load_default(), "user://test_fire_store")
	f.ground_height = func(_x, _z): return 10.0
	f.peer_connected_hello(1, "firestore0001")
	f._characters[f._peer_key[1]]["grace_s"] = 0.0
	f.report_position(1, Vector3(0.0, 10.0, 0.0))
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("campfire_kit"), 0, 2, Vector3.ZERO)
	f.action(1, Net.ACT_PLACE, 0, 0, 0, Vector3(2.0, 10.0, 0.0))
	var id: int = 0

	for k in f._items:
		if f._items[k].has("fire"):
			id = k

	check(id != 0, "a fire is placed")
	var fire: Dictionary = f._items[id]["fire"]
	check(bool(fire.get("synced", false)) and float(fire["burn_left"]) > 0.0, "a placed fire holds its first stick in its store and burns from it")
	var rate: float = 24.0 if not f.has_method("game_rate") else float(f.game_rate())

	# Open, put 3 firewood in, close: the burn time grows and the tier is medium once lit.
	fire["state"] = ItemsScript.FIRE_STATE_SURVIVAL   # lit small
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("firewood"), 0, 3, Vector3.ZERO)
	f.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	var before: float = float(fire["burn_left"])
	var slot: int = f.inventory_of(1).numbers.find(f.table.number_of("firewood"))
	f.action(1, Net.ACT_CHEST_PUT, slot, id, 3, Vector3.ZERO)
	f.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(float(fire["burn_left"]) > before, "three firewood in the store: more burn time after closing (%s then %s)" % [before, fire["burn_left"]])
	check(int(fire["state"]) == 1, "three firewood make the medium fire (state %d)" % int(fire["state"]))

	# Three logs: the large fire.
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("log_beech"), 0, 3, Vector3.ZERO)
	f.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)

	for round in range(3):
		var log_slot: int = f.inventory_of(1).numbers.find(f.table.number_of("log_beech"))

		if log_slot >= 0:
			f.action(1, Net.ACT_CHEST_PUT, log_slot, id, 1, Vector3.ZERO)

	f.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(int(fire["state"]) == ItemsScript.FIRE_STATE_BONFIRE, "three beech logs in the store make the large fire (state %d, wood %s, pieces %s)" % [int(fire["state"]), str(fire["wood"]), str(fire.get("pieces", {}))])

	# Take everything out: no burn time, the burning fire goes out.
	f.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	var box = f._chests[int(fire["uid"])]

	for take_slot in range(box.SLOTS):
		if box.numbers[take_slot] != 0:
			f.action(1, Net.ACT_CHEST_TAKE, take_slot, id, box.counts[take_slot], Vector3.ZERO)

	f.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(float(fire["burn_left"]) <= 0.0 and int(fire["state"]) == 8, "an empty store: no burn time, the fire is out (burn %s, state %d)" % [str(fire["burn_left"]), int(fire["state"])])

	# Hold E on an unlit fire with an empty store picks it up.
	var kits_before: int = f.inventory_of(1).count_of(f.table.number_of("campfire_kit"))
	f.action(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
	check(not f._items.has(id) and f.inventory_of(1).count_of(f.table.number_of("campfire_kit")) == kits_before + 1, "an unlit fire with an empty store is picked up as a kit")

	print("fire store: %d failures" % failures)
	f._finish_writer()
	quit(1 if failures > 0 else 0)
