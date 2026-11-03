extends SceneTree

# Two players at one fire (Moderator 1 Nov 2026): each is charged only for what goes in, the wood adds up, one lights and the other adds wood to the lit fire,
# the second light is refused politely, a far player is refused, and a fuel or light order for a fire that is gone (burnt away, picked up) does nothing and does not crash.
#   godot --headless --path . --script res://src/worldgen/tools/test_fire_two_players.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var said: Dictionary = {}


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _fire_id(f) -> int:
	var id: int = 0

	for k in f._items:
		if f._items[k].has("fire"):
			id = k

	return id


func _init() -> void:
	var dir: String = "user://test_fire_two_players"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var f = ItemsScript.new()
	f.send_full = func(_p, _b): pass
	f.send_slots = func(_p, _b): pass
	f.send_world_items = func(_p, _a, _r): pass
	f.send_notice = func(p, t): said[p] = str(said.get(p, "")) + "|" + t
	f.setup(ItemTableScript.load_default(), dir)
	f.ground_height = func(x, z): return 10.0
	var stick: int = f.table.number_of("stick")
	var fibre: int = f.table.number_of("plant_fibre")

	for p in [1, 2, 3]:
		f.peer_connected_hello(p, "firekey00000%d" % p)
		f._characters[f._peer_key[p]]["grace_s"] = 0.0

	f.report_position(1, Vector3(0.0, 10.0, 0.0))
	f.report_position(2, Vector3(1.0, 10.0, 1.0))
	f.report_position(3, Vector3(60.0, 10.0, 60.0))   # far away
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("campfire_kit"), 0, 1, Vector3.ZERO)
	f.action(1, Net.ACT_PLACE, 0, 0, 0, Vector3(2.0, 10.0, 0.0))
	var id: int = _fire_id(f)
	check(id != 0, "player 1 lays a fire")

	for p in [1, 2, 3]:
		f.action(p, Net.ACT_ADMIN_GIVE, stick, 0, 6, Vector3.ZERO)

	f.action(1, Net.ACT_ADMIN_GIVE, fibre, 0, 3, Vector3.ZERO)
	f.action(2, Net.ACT_ADMIN_GIVE, fibre, 0, 2, Vector3.ZERO)

	for n in range(3):
		f.action(1, Net.ACT_FUEL, id, 0, 0, Vector3.ZERO)
		f.action(2, Net.ACT_FUEL, id, 0, 0, Vector3.ZERO)

	check(f.inventory_of(1).count_of(stick) == 3 and f.inventory_of(2).count_of(stick) == 3, "each player paid three sticks (%d, %d)" % [f.inventory_of(1).count_of(stick), f.inventory_of(2).count_of(stick)])
	var seconds: float = float(f._fire_wood(f._items[id]["fire"])["weak"])
	check(seconds > 0.0 and absf(seconds / 6.0 - float(f._cooking["fuel"]["stick"]) / ItemsScript.GAME_RATE) < 100.0, "six sticks in the fire add up (%.0f s, wood %s)" % [seconds, str(f._fire_wood(f._items[id]["fire"]))])

	f.action(3, Net.ACT_FUEL, id, 0, 0, Vector3.ZERO)
	check(f.inventory_of(3).count_of(stick) == 6, "a player 60 m away cannot feed it")

	f.action(1, Net.ACT_LIGHT, id, 0, 0, Vector3.ZERO)
	check(ItemsScript.fire_is_lit(int(f._items[id]["fire"]["state"])), "player 1 lights it")
	var state_after_light: int = int(f._items[id]["fire"]["state"])
	f.action(2, Net.ACT_LIGHT, id, 0, 0, Vector3.ZERO)
	check(int(f._items[id]["fire"]["state"]) == state_after_light, "player 2 lighting a lit fire changes nothing")
	var fibre_left: int = f.inventory_of(2).count_of(fibre)
	check(fibre_left == 2, "and costs player 2 nothing (%d fibre left)" % fibre_left)
	f.action(2, Net.ACT_FUEL, id, 0, 0, Vector3.ZERO)
	check(f.inventory_of(2).count_of(stick) == 2, "player 2 adds a stick to the lit fire")

	# The fire goes away while orders for it are in flight.
	f._items.erase(id)
	f.action(1, Net.ACT_FUEL, id, 0, 0, Vector3.ZERO)
	f.action(2, Net.ACT_LIGHT, id, 0, 0, Vector3.ZERO)
	check(f.inventory_of(1).count_of(stick) == 3 and f.inventory_of(2).count_of(stick) == 2, "orders for a fire that is gone take nothing")

	# A player who leaves with the fire still burning does not stop it burning.
	f.action(1, Net.ACT_ADMIN_GIVE, f.table.number_of("campfire_kit"), 0, 1, Vector3.ZERO)
	f.action(1, Net.ACT_PLACE, f.inventory_of(1).numbers.find(f.table.number_of("campfire_kit")), 0, 0, Vector3(-2.0, 10.0, 0.0))
	var id2: int = _fire_id(f)
	check(id2 != 0, "a second fire can be laid (said %s)" % str(said.get(1, "")))

	if id2 == 0:
		print("test_fire_two_players: FAIL")
		f._finish_writer()
		quit(1)
		return

	f.action(1, Net.ACT_FUEL, id2, 0, 0, Vector3.ZERO)
	f.action(1, Net.ACT_LIGHT, id2, 0, 0, Vector3.ZERO)
	f.peer_left(1)
	var burn_before: float = float(f._items[id2]["fire"]["burn_left"])
	f.tick(30.0)
	check(f._items.has(id2) and float(f._items[id2]["fire"]["burn_left"]) < burn_before, "the fire keeps burning after its lighter leaves")

	f._finish_writer()   # the background save thread must be done before quit, or the script is freed under it (Opcode 20 _write_file error)
	print("test_fire_two_players: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
