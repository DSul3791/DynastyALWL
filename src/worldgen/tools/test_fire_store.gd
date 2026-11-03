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

	var fed_before: int = int(fire.get("fed", 0))
	f.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(int(fire.get("fed", 0)) > fed_before, "closing the store sends the fire's row again, so the client's timer shows the new burn time")
	check(int(fire["state"]) == ItemsScript.FIRE_STATE_BONFIRE, "three beech logs in the store make the large fire (state %d, wood %s, pieces %s)" % [int(fire["state"]), str(fire["wood"]), str(fire.get("pieces", {}))])

	# Dave 2 Nov 2026: a third log put into a burning fire's store vanished. Wood put in while the store is open stays until the close counts it;
	# only wood that has burned leaves the store.
	var keep_box = f._chests[int(fire["uid"])]

	for keep_slot in range(keep_box.SLOTS):
		if keep_box.numbers[keep_slot] != 0:
			keep_box.take_from_slot(keep_slot, keep_box.counts[keep_slot])

	fire.erase("burnt")
	keep_box.add(f.table.number_of("log_beech"), 2)
	f._fire_apply_store(fire, keep_box)
	fire["state"] = f._fire_best_state(fire)
	f._items[id]["left"] = 1.0e9
	var two_logs: float = float(fire["burn_left"])
	f.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("log_beech"), 0, 1, Vector3.ZERO)
	f.action(1, Net.ACT_CHEST_PUT, f.inventory_of(1).numbers.find(f.table.number_of("log_beech")), id, 1, Vector3.ZERO)

	for n in range(3):
		f.tick(10.0)

	check(keep_box.count_of(f.table.number_of("log_beech")) == 3, "a third log put into a burning fire stays in the store while it is open (%d logs)" % keep_box.count_of(f.table.number_of("log_beech")))
	f.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	var log_s: float = float(f._cooking["fuel"]["log_beech"]) / ItemsScript.GAME_RATE
	check(float(fire["burn_left"]) > two_logs + log_s - 60.0 and float(fire["burn_left"]) < two_logs + log_s, "closing counts the third log, less what has burned (%.0f s, two logs %.0f s)" % [float(fire["burn_left"]), two_logs])
	check(int(fire["state"]) == ItemsScript.FIRE_STATE_BONFIRE, "three logs: the large fire (state %d)" % int(fire["state"]))

	# Dave 2 Nov 2026 (QA): three logs lift the fire a tier and it stays there until those logs are gone. One log burned out of three: the
	# store holds two, and closing it must not drop the bonfire. With the logs gone and three firewood it falls back to the medium fire.
	var stay_box = f._chests[int(fire["uid"])]

	for stay_slot in range(stay_box.SLOTS):
		if stay_box.numbers[stay_slot] != 0:
			stay_box.take_from_slot(stay_slot, stay_box.counts[stay_slot])

	fire.erase("burnt")
	stay_box.add(f.table.number_of("log_beech"), 2)
	fire["state"] = ItemsScript.FIRE_STATE_BONFIRE
	f.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	f.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(int(fire["state"]) == ItemsScript.FIRE_STATE_BONFIRE, "two logs left of three: still the large fire after the store is closed (state %d)" % int(fire["state"]))
	stay_box.take_from_slot(stay_box.numbers.find(f.table.number_of("log_beech")), 2)
	stay_box.add(f.table.number_of("firewood"), 3)
	f.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	f.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(int(fire["state"]) == 1, "the logs gone, three firewood: back to the medium fire (state %d)" % int(fire["state"]))

	# Dave 2 Nov 2026, again on the newer build: the third log still vanished. A fire whose burn time had run ahead of its store (an older fire, or one
	# fed outside the store) had burned log time with no counted log left to take, and that debt took the next log put in. It must stay.
	for debt_slot in range(keep_box.SLOTS):
		if keep_box.numbers[debt_slot] != 0:
			keep_box.take_from_slot(debt_slot, keep_box.counts[debt_slot])

	fire.erase("counted")
	fire["burnt"] = {"log": 3.0 * log_s}
	fire["wood"] = {"log": 2.0 * log_s, "firewood": 0.0, "weak": 0.0}
	fire["state"] = 1
	f.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("log_beech"), 0, 1, Vector3.ZERO)
	f.action(1, Net.ACT_CHEST_PUT, f.inventory_of(1).numbers.find(f.table.number_of("log_beech")), id, 1, Vector3.ZERO)

	for n in range(3):
		f.tick(10.0)

	check(keep_box.count_of(f.table.number_of("log_beech")) == 1, "a log put into a fire whose burn ran ahead of its store stays (%d)" % keep_box.count_of(f.table.number_of("log_beech")))
	f.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(float(fire["burn_left"]) > log_s - 60.0, "and closing counts it (%.0f s)" % float(fire["burn_left"]))

	# A fire that burns out leaves no wood in its store: the last piece is ash, not fresh burn time for the next close.
	var burn_box = f._chests[int(fire["uid"])]

	for burn_slot in range(burn_box.SLOTS):
		if burn_box.numbers[burn_slot] != 0:
			burn_box.take_from_slot(burn_slot, burn_box.counts[burn_slot])

	burn_box.add(f.table.number_of("stick"), 1)
	f._fire_apply_store(fire, burn_box)
	fire["state"] = 40
	f._items[id]["left"] = 1.0e9

	for n in range(60):
		if not ItemsScript.fire_is_lit(int(fire["state"])):
			break

		f.tick(10.0)

	check(int(fire["state"]) == 8 and burn_box.count_of(f.table.number_of("stick")) == 0, "a burnt-out fire's store holds no wood (state %d, sticks %d)" % [int(fire["state"]), burn_box.count_of(f.table.number_of("stick"))])
	f.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	f.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(float(fire["burn_left"]) <= 0.0, "closing a burnt-out fire's store gives no burn time back")

	# Take everything out: no burn time, the burning fire goes out.
	f.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	var box = f._chests[int(fire["uid"])]

	for take_slot in range(box.SLOTS):   # logs come out one at a time onto the shoulder, so empty the store directly
		if box.numbers[take_slot] != 0:
			box.take_from_slot(take_slot, box.counts[take_slot])

	f.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(float(fire["burn_left"]) <= 0.0 and int(fire["state"]) == 8, "an empty store: no burn time, the fire is out (burn %s, state %d)" % [str(fire["burn_left"]), int(fire["state"])])

	# Hold E on an unlit fire with an empty store picks it up.
	var kits_before: int = f.inventory_of(1).count_of(f.table.number_of("campfire_kit"))
	f.action(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
	check(not f._items.has(id) and f.inventory_of(1).count_of(f.table.number_of("campfire_kit")) == kits_before + 1, "an unlit fire with an empty store is picked up as a kit")

	print("fire store: %d failures" % failures)
	f._finish_writer()
	quit(1 if failures > 0 else 0)
