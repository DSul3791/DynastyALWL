extends SceneTree

# Carrying and moving loads with two players at once (coordinator 23 Nov 2026, survival loop walk): real server state. Player 1 pulls each
# vehicle (Handcart, Small log sled, Small wagon) while player 2 walks beside it and loads its own store: what goes in stays within the
# payload, the pace drops at the next step, the second player cannot take the handle or take the cart apart. The puller's connection drops
# mid-pull: the cart parks, the second player takes the handle and pulls on, the first rejoins and finds it held. A puller cannot pick a log
# up onto the shoulder (both hands are on the handle, as a log on the shoulder keeps the handle out of reach), and logs carried on the
# shoulder come back after a dropped connection and a server restart.
#   godot --headless --path . --script res://src/worldgen/tools/test_carts_two_players.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Carts := preload("res://src/stream/server_carts.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const DIR := "user://test_carts_two_players"

var failures: int = 0
var items
var clock: Array = [1.0e6]
var pulls: Dictionary = {}     # peer -> the last cart_pull [id, tenths of m/s]
var said: Dictionary = {}      # peer -> the last notice
var keys: Dictionary = {1: "loadpuller01", 2: "loadhelper02"}


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make_server():
	var s = ItemsScript.new()
	s.send_full = func(_p, _b): pass
	s.send_slots = func(_p, _b): pass
	s.send_world_items = func(_p, _a, _r): pass
	s.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	s.send_notice = func(p, t): said[p] = t
	s.send_carry = func(_p, _id): pass
	s.send_chest = func(_p, _id, _b): pass
	s.send_chest_info = func(_p, _id, _k, _m): pass
	s.send_chest_lock = func(_p, _id, _l, _mi, _mo, _w, _a): pass
	s.send_cart_pull = func(p, id, pace): pulls[p] = [id, pace]
	s.send_items_moved = func(_p, _ids, _at, _yaws): pass
	s.ground_height = func(_x, _z): return 10.0
	s.water_depth_at = func(_pos: Vector3) -> float: return 0.0
	s.unix_now = func(): return clock[0]
	s.setup(ItemTableScript.load_default(), DIR)
	s.admin_mode_on = func(_p): return false
	return s


func join(peer: int, at: Vector3) -> void:
	items.peer_connected_hello(peer, keys[peer])
	items.report_position(peer, at)
	items.vitals_of(peer)["weight"] = 75.0


func empty_pack(peer: int) -> void:
	var inv = items.inventory_of(peer)

	for s in inv.slot_count:
		inv.clear_slot(s)


func cart_act(peer: int, op: int, a: int) -> void:
	items.action(peer, Net.ACT_CART, a, op, 0, Vector3.ZERO)


func pulling(peer: int) -> int:
	return int(items._carts.puller_of.get(peer, 0))


func box(id: int):
	return items._chests[int(items._items[id]["struct"]["uid"])]


func pos(id: int) -> Vector3:
	return items._items[id]["pos"]


# The puller walks north from where they are, `metres` in 0.2 s reports of 0.4 m (2 m/s); the helper keeps beside the cart.
func walk_north(metres: float) -> void:
	var here: Vector3 = items._peer_pos[1]
	var to: float = here.z + metres

	while here.z < to - 0.01:
		here.z = minf(here.z + 0.4, to)
		clock[0] += 0.2
		items.report_position(1, here)

		if items._peer_pos.has(2) and pulling(1) != 0:
			items.report_position(2, pos(pulling(1)) + Vector3(1.2, 0.0, 0.0))


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make_server()
	var x: float = 0.0

	for kind in ["handcart", "small_log_sled", "small_wagon"]:
		_one_vehicle(kind, x)
		x += 40.0

	_shoulder_logs()
	items._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)


func _one_vehicle(kind: String, x: float) -> void:
	var cart: int = items.dev_place("%s@%.1f,0" % [kind, x])

	if cart == 0:
		check(false, "%s placed" % kind)
		return

	items._items[cart]["struct"]["owner"] = keys[1]
	var noun: String = items._carts.noun_for(cart)
	var max_kg: float = float(items._structures[kind]["max_kg"])
	join(1, Vector3(x, 10.0, 1.7))
	join(2, Vector3(x + 1.2, 10.0, 0.0))
	empty_pack(1)
	empty_pack(2)
	cart_act(1, Carts.OP_GRAB, cart)
	check(pulling(1) == cart, "%s: player 1 takes the handle" % kind)
	walk_north(4.0)
	var pace_empty: int = int(pulls[1][1])
	var at_0: Vector3 = pos(cart)
	check(at_0.z > 1.0, "%s: it follows (z %.1f)" % [kind, at_0.z])

	# Player 2 loads the store while it moves (stones; the sled takes only wood, so firewood).
	var takes: Array = items._structures[kind].get("takes", [])
	var load_id: String = "stone" if takes.is_empty() else "firewood"
	var cargo: int = items.table.number_of(load_id)
	var each: float = CarryRules.weight_of(load_id, items._carry_cfg)
	items.give(2, cargo, 40)
	items.action(2, Net.ACT_CHEST_PUT, items.inventory_of(2).numbers.find(cargo), cart, 40, Vector3.ZERO)
	check(box(cart).count_of(cargo) == 40, "%s: player 2 puts 40 %s (%.0f kg) in its store while player 1 pulls (%d in)" % [kind, load_id, 40.0 * each, box(cart).count_of(cargo)])
	walk_north(4.0)
	check(pulling(1) == cart and pos(cart).z > at_0.z + 2.0, "%s: player 1 pulls on with the cargo (z %.1f)" % [kind, pos(cart).z])
	box(cart).add(cargo, int(floor((max_kg - 10.0) / each)) - 40)   # about 10 kg short of the payload
	walk_north(2.0)
	check(int(pulls[1][1]) < pace_empty, "%s: near full, the pace drops at the next steps (%.1f against %.1f m/s)" % [kind, float(pulls[1][1]) / 10.0, float(pace_empty) / 10.0])
	empty_pack(2)
	var more: int = int(ceil(30.0 / each))
	items.give(2, cargo, more)
	var room: float = items._carts.room_kg(cart)
	var before: int = box(cart).count_of(cargo)
	items.action(2, Net.ACT_CHEST_PUT, items.inventory_of(2).numbers.find(cargo), cart, more, Vector3.ZERO)
	var went: int = box(cart).count_of(cargo) - before
	check(went == int(floor(room / each + 0.0001)) and went < more and items.inventory_of(2).count_of(cargo) == more - went, "%s: %d more, only the %.1f kg left of its %d kg payload go in (%d went, the rest stay in the pack)" % [kind, more, room, int(max_kg), went])
	check(items._carts.load_kg(cart) <= max_kg + 0.01, "%s: the cargo stays within the payload (%.1f kg)" % [kind, items._carts.load_kg(cart)])

	# Player 2 cannot take the handle or take the cart apart.
	cart_act(2, Carts.OP_GRAB, cart)
	check(pulling(2) == 0 and pulling(1) == cart and str(said.get(2, "")) == "Someone else has the handle.", "%s: player 2 cannot take the held handle" % kind)
	items.action(2, Net.ACT_PICKUP, cart, 0, 0, Vector3.ZERO)
	check(items._items.has(cart) and box(cart).count_of(cargo) == before + went, "%s: nor take player 1's %s apart (%s)" % [kind, noun, str(said.get(2, ""))])

	# The puller's connection drops mid-pull: the cart parks; player 2 pulls on; player 1 rejoins to find it held.
	walk_north(2.0)
	var parked: Vector3 = pos(cart)
	items.peer_left(1)
	check(items._carts.pulls.is_empty() and pulling(1) == 0, "%s: a dropped connection lets go of the handle" % kind)
	clock[0] += 5.0
	items.report_position(2, parked + Vector3(0.0, 0.0, 1.7))
	check(pos(cart).distance_to(parked) < 0.01, "%s: the cart stays parked where it was" % kind)
	cart_act(2, Carts.OP_GRAB, cart)
	check(pulling(2) == cart, "%s: player 2 takes the handle" % kind)
	var here: Vector3 = items._peer_pos[2]

	for i in 10:
		here.z += 0.4
		clock[0] += 0.2
		items.report_position(2, here)

	check(pos(cart).z > parked.z + 2.0 and box(cart).count_of(cargo) == before + went, "%s: and pulls it on, its cargo kept (z %.1f)" % [kind, pos(cart).z])
	join(1, pos(cart) + Vector3(-1.2, 0.0, 0.0))
	cart_act(1, Carts.OP_GRAB, cart)
	check(pulling(1) == 0 and pulling(2) == cart, "%s: player 1 rejoins and finds the handle held" % kind)
	cart_act(2, Carts.OP_RELEASE, 0)
	items.report_position(1, pos(cart) + Vector3(0.0, 0.0, 1.7))
	cart_act(1, Carts.OP_GRAB, cart)
	check(pulling(1) == cart, "%s: once player 2 lets go, player 1 takes it again" % kind)

	# Both hands on the handle: no log onto the shoulder.
	var log_id: int = 0
	items.drop_in_world(items.table.number_of("log_birch"), 1, items._peer_pos[1] + Vector3(0.5, 0.0, 0.0))

	for id in items._items:
		if int(items._items[id].get("number", 0)) == items.table.number_of("log_birch") and (items._items[id]["pos"] as Vector3).distance_to(items._peer_pos[1]) < 2.0:
			log_id = id

	items.action(1, Net.ACT_PICKUP, log_id, 0, 0, Vector3.ZERO)
	check(log_id != 0 and items.shoulder_count(1) == 0 and items._items.has(log_id) and pulling(1) == cart, "%s: the puller cannot lift a log onto the shoulder (%s)" % [kind, str(said.get(1, ""))])
	cart_act(1, Carts.OP_RELEASE, 0)
	items.action(1, Net.ACT_PICKUP, log_id, 0, 0, Vector3.ZERO)
	check(items.shoulder_count(1) == 1 and not items._items.has(log_id), "%s: once they let go, they can" % kind)
	items.peer_left(1)
	items.peer_left(2)


# Two logs on the shoulder come back after a dropped connection, still on the shoulder (they are pack items, saved with the character).
func _shoulder_logs() -> void:
	join(1, Vector3(200.0, 10.0, 0.0))
	empty_pack(1)
	items.give(1, items.table.number_of("log_birch"), 1)   # one log a pick-up
	items.give(1, items.table.number_of("log_birch"), 1)
	check(items.shoulder_count(1) == 2, "two logs on the shoulder")
	items.peer_left(1)
	join(1, Vector3(200.0, 10.0, 0.0))
	check(items.shoulder_count(1) == 2 and items.shoulder_of(1) == "log_birch", "after a dropped connection, both logs are still on the shoulder")
	items.peer_left(1)
	items.save()
	items._finish_writer()
	items = make_server()   # a server restart: the character is read back from disk
	join(1, Vector3(200.0, 10.0, 0.0))
	check(items.shoulder_count(1) == 2 and items.shoulder_of(1) == "log_birch", "and after a server restart too")
