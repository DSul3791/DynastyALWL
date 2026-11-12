extends SceneTree

# The Handcart and loaded crates (catalog Phase 10, M001-T17; master s3.11 [D11], s3.13 [D13]; STORAGE_WAREHOUSING_DESIGN.md s4 to s6): real server
# state with three players. The wheels and the axle are made at a Carpenter's bench and the Handcart is built from its hammer blueprint. A locked,
# loaded Warehouse crate at warehouse A: a stranger cannot lift it, a player who entered the code can; only one player holds the handle; a cart with
# a locked crate on it does not move for a stranger. The owner lifts it on (desk A stops listing it), wheels it toward warehouse B, the world is
# saved and the server restarted mid-trip (cart, crate, lock and contents come back), the trip goes on and the crate is set down at B (desk B lists
# it, desk A does not), contents identical and the food aged on the way at the cart's rate. Steep ground, deep water and a puller running ahead make
# the handle slip and the cart park; a disconnect parks it; a crate too heavy for the payload stays down; taking down a loaded cart sets the crate
# down whole and gives back its cargo and every part, or does nothing when the load cannot be carried. The cost of a pulled cart per report is printed.
#   godot --headless --path . --script res://src/worldgen/tools/test_handcart.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Carts := preload("res://src/stream/server_carts.gd")
const DIR := "user://test_handcart"
const RAMP_X := 40.0      # east of this the ground climbs 0.8 m per metre (too steep for a cart)
const WATER_Z := 120.0    # north of this the water is 1 m deep

var failures: int = 0
var items
var clock: Array = [1.0e6]
var pulls: Dictionary = {}     # peer -> the last cart_pull [id, tenths of m/s]
var moved: Dictionary = {}     # peer -> items_moved messages received
var views: Dictionary = {}     # peer -> the last storage_view [id, {number: total}, containers]
var said: Dictionary = {}      # peer -> the last notice
var keys: Dictionary = {1: "cartowner01", 2: "cartguest02", 3: "cartthird03"}
var stone: int = 0
var food: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func ground(x: float, _z: float) -> float:
	return 10.0 + maxf(x - RAMP_X, 0.0) * 0.8


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
	s.send_storage_view = func(p, id, numbers, counts, containers):
		var totals: Dictionary = {}
		for i in numbers.size():
			totals[int(numbers[i])] = int(counts[i])
		views[p] = [id, totals, containers]
	s.send_craft_stock = func(_p, _n, _c): pass
	s.send_bulk_done = func(_p, _k, _s, _c, _i): pass
	s.send_craft_queue = func(_p, _e, _l): pass
	s.send_cart_pull = func(p, id, pace): pulls[p] = [id, pace]
	s.send_items_moved = func(p, _ids, _at, _yaws): moved[p] = int(moved.get(p, 0)) + 1
	s.ground_height = func(x, z): return ground(x, z)
	s.water_depth_at = func(pos: Vector3) -> float: return 1.0 if pos.z > WATER_Z else 0.0
	s.unix_now = func(): return clock[0]
	s.setup(ItemTableScript.load_default(), DIR)
	s.admin_mode_on = func(_p): return false
	return s


func join(peer: int, at: Vector3) -> void:
	items.peer_connected_hello(peer, keys[peer])
	items.report_position(peer, at)
	items.vitals_of(peer)["weight"] = 75.0
	var inv = items.inventory_of(peer)

	for s in inv.SLOTS:   # an empty pack: what the test gives is all there is
		inv.clear_slot(s)


func act(peer: int, kind: int, a: int, b: int = 0, count: int = 0, at: Vector3 = Vector3.ZERO) -> void:
	items.action(peer, kind, a, b, count, at)


func cart_act(peer: int, op: int, a: int) -> void:
	act(peer, Net.ACT_CART, a, op)


func give(peer: int, id: String, count: int) -> void:
	items.inventory_of(peer).add(items.table.number_of(id), count)


func have(peer: int, id: String) -> int:
	return items.inventory_of(peer).count_of(items.table.number_of(id))


func box(id: int):
	return items._chests[int(items._items[id]["struct"]["uid"])]


func id_of_uid(uid: int) -> int:
	for id in items._items:
		if items._items[id].has("struct") and int(items._items[id]["struct"].get("uid", 0)) == uid:
			return id

	return 0


func of_kind(kind: String) -> Array:
	var out: Array = []

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			out.append(id)

	return out


# The placed piece of this kind standing at (x, z), 0 none.
func at_spot(kind: String, x: float, z: float) -> int:
	for id in of_kind(kind):
		if Vector2(items._items[id]["pos"].x - x, items._items[id]["pos"].z - z).length() < 0.1:
			return id

	return 0


func recipe_number(id: String) -> int:
	for n in items.recipes.numbers():
		if str(items.recipes.recipe(int(n)).get("id", "")) == id:
			return int(n)

	return 0


func craft(id: String, times: int, seconds: int) -> void:
	items._last_queue_act.clear()
	act(1, Net.ACT_CRAFT_QUEUE, recipe_number(id), 0, times)

	for s in range(seconds):
		items.tick(1.0)


# The puller walks from where they are to `to` in 0.2 s reports of `step` metres (3 m/s at 0.6); the clock moves with them.
func walk(peer: int, to: Vector3, step: float = 0.6) -> void:
	var here: Vector3 = items._peer_pos[peer]

	while Vector2(to.x - here.x, to.z - here.z).length() > 0.01:
		var d: Vector3 = Vector3(to.x - here.x, 0.0, to.z - here.z)
		here += d.normalized() * minf(step, d.length())
		here.y = ground(here.x, here.z)
		clock[0] += 0.2
		items.report_position(peer, here)


func view_totals(peer: int, desk: int) -> Array:
	views.erase(peer)
	act(peer, Net.ACT_VIEW_OPEN, desk)
	return views.get(peer, [0, {}, 0])


func pulling(peer: int) -> int:
	return int(items._carts.puller_of.get(peer, 0))


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make_server()
	stone = items.table.number_of("stone")
	food = items.table.number_of("raw_meat")
	check(items.table.shelf_units(food) > 0, "raw meat spoils (the ageing check needs it)")

	# --- 1. Data: three rows live, the rest of the vehicles still gated ---
	for id in ["handcart", "wooden_cart_wheel", "axle"]:
		check(not bool(items.table.entry(id).get("future", false)), "%s is live" % id)

	for id in ["reinforced_wagon_wheel", "light_cargo_cart", "farm_wagon", "passenger_sleigh"]:
		check(bool(items.table.entry(id).get("future", false)) and not items._structures.has(id), "%s stays FUTURE-GATED (phase 11)" % id)

	var bp: Dictionary = items._blueprints.get(250, {})
	check(str(bp.get("structure", "")) == "handcart" and int(bp.get("hammer", 0)) == 1, "blueprint 250 builds the Handcart with a hammer")
	var bp_cost: Dictionary = {}

	for row in bp.get("cost", []):
		bp_cost[str(row[0])] = int(row[1])

	check(int(bp_cost.get("wooden_cart_wheel", 0)) == 2 and int(bp_cost.get("axle", 0)) == 1 and int(bp_cost.get("lumber", 0)) > 0 and not bp_cost.has("hardwood_board"), "it takes two Wooden cart wheels, an Axle and Planks (no Hardwood boards: hardwood-free biomes can build it)")

	for id in ["wooden_cart_wheel", "axle"]:
		var r: Dictionary = items.recipes.recipe(recipe_number(id))
		check(str(r.get("station", "")) == "workbench" and int(r.get("station_level", 0)) == 2 and int(r.get("number", 0)) >= 700 and int(r.get("number", 0)) <= 719, "%s is made at the Carpenter's bench (recipe %d)" % [id, int(r.get("number", 0))])

	var def: Dictionary = items._structures["handcart"]
	check(int(def.get("slots", 0)) > 10 and float(def.get("max_kg", 0.0)) > 50.0 and def.has("vehicle"), "the Handcart has its own cargo store, more than a backpack (%d slots, %d kg)" % [int(def.get("slots", 0)), int(def.get("max_kg", 0))])
	check(bool(items._structures["wooden_crate"].get("cargo", false)) and bool(items._structures["warehouse_crate"].get("cargo", false)), "the Crate and the Warehouse crate ride as cargo")
	check(Net.PROTOCOL_VERSION >= 111 and Net.ACT_CART == 78 and ItemsScript.VERSION == 3, "protocol 111, ACT_CART 78, world_items version 3")

	# --- 2. Make the parts at a Carpenter's bench and build the cart from its blueprint ---
	join(1, Vector3(2.0, 10.0, 2.0))
	join(2, Vector3(16.0, 10.0, 6.0))
	join(3, Vector3(16.0, 10.0, 8.0))
	items.dev_place("log_workbench@0,5")
	give(1, "lumber", 8)
	give(1, "wooden_pin", 16)
	give(1, "iron_band", 3)
	craft("wooden_cart_wheel", 2, 80)
	craft("axle", 1, 60)
	check(have(1, "wooden_cart_wheel") == 2 and have(1, "axle") == 1 and have(1, "lumber") == 0 and have(1, "iron_band") == 0, "two wheels and an axle made at the bench, their Planks and iron bands used (%d wheels, %d axles)" % [have(1, "wooden_cart_wheel"), have(1, "axle")])
	items.report_position(1, Vector3(15.0, 10.0, 4.0))
	give(1, "wooden_hammer", 1)
	act(1, Net.ACT_HOTBAR_SET, 0, items.table.number_of("wooden_hammer"))   # the hammer on hotbar key 1 (the hand bar)
	give(1, "lumber", 6)
	give(1, "wooden_pin", 12)
	act(1, Net.ACT_PLACE_BLUEPRINT, 250, 0, 0, Vector3(17.0, 10.0, 4.0))
	var cart: int = of_kind("handcart")[0] if of_kind("handcart").size() == 1 else 0

	if cart != 0 and items._items[cart]["struct"].has("site"):
		act(1, Net.ACT_USE_STRUCT, cart)   # the materials go in from the pack

	check(cart != 0 and not items._items[cart]["struct"].has("site") and items._items[cart]["struct"].has("uid") and str(items._items[cart]["struct"]["owner"]) == keys[1], "the Handcart stands, built from its blueprint, owned by its builder")
	check(have(1, "wooden_cart_wheel") == 0 and have(1, "axle") == 0 and have(1, "lumber") == 0 and have(1, "wooden_pin") == 0, "its wheels, axle, Planks and pins were used")
	if cart == 0 or items._items[cart]["struct"].has("site"):
		print("FAIL no Handcart to go on with (last notice: %s)" % str(said.get(1, "")))
		quit(1)
		return

	var cart_uid: int = int(items._items[cart]["struct"]["uid"])

	# --- 3. Warehouse A: a desk and a loaded, locked crate; warehouse B: a desk; a control crate stays at A ---
	var desk_a: int = items.dev_place("warehouse_desk@22,0")
	var desk_b: int = items.dev_place("warehouse_desk@17,95")
	var crate: int = items.dev_place("warehouse_crate@19.5,4")
	var control: int = items.dev_place("warehouse_crate@24,-4")
	items._items[crate]["struct"]["owner"] = keys[1]
	items._items[control]["struct"]["owner"] = keys[1]
	var crate_uid: int = int(items._items[crate]["struct"]["uid"])
	box(crate).add(stone, 5)
	box(crate).add(food, 4)
	box(control).add(food, 4)
	box(cart).add(food, 4)   # food in the cart's own store, to compare with the food in the crate riding on it
	items.report_position(1, Vector3(19.0, 10.0, 2.0))
	var seen: Array = view_totals(1, desk_a)
	check(int(seen[1].get(stone, 0)) == 5, "desk A lists the crate at A (5 stones)")
	act(1, Net.ACT_CHEST_LOCK, crate, items.LOCK_SET, 42)
	check(not items._lock_of(items._items[crate]).is_empty(), "the owner locks the crate with 0042")

	# --- 4. The locked-crate rule: a stranger cannot lift it; with the code they can (and set it down again) ---
	items.report_position(2, Vector3(19.5, 10.0, 6.0))
	cart_act(2, Carts.OP_LOAD, crate)
	check(not items._items[crate]["struct"].has("on"), "a stranger cannot lift the locked crate onto the cart")
	act(2, Net.ACT_CHEST_LOCK, crate, items.LOCK_TRY, 42)
	cart_act(2, Carts.OP_LOAD, crate)
	check(int(items._items[crate]["struct"].get("on", 0)) == cart_uid, "after entering the code, that player may lift it on")
	cart_act(2, Carts.OP_UNLOAD, crate)
	check(not items._items[crate]["struct"].has("on") and absf(float(items._items[crate]["pos"].y) - 10.0) < 0.01, "and set it down again, on the ground")

	# --- 5. Lifting on: desk A drops it; one handle; a stranger cannot pull a cart with a locked crate on it ---
	var food_wear_0: int = box(crate).wear[1]
	cart_act(1, Carts.OP_LOAD, crate)
	check(int(items._items[crate]["struct"].get("on", 0)) == cart_uid, "the owner lifts the loaded crate onto the cart")
	check(int(view_totals(1, desk_a)[1].get(stone, 0)) == 0, "desk A no longer lists the crate once it is on the cart")
	items.report_position(3, Vector3(16.0, 10.0, 5.0))
	cart_act(3, Carts.OP_GRAB, cart)
	check(pulling(3) == 0, "a stranger cannot take the handle of a cart carrying a locked crate")
	items._sync_world_items()   # the players near learn of the cart (items_moved goes to those who know it)
	cart_act(1, Carts.OP_GRAB, cart)
	check(pulling(1) == cart and int(pulls.get(1, [0, 0])[0]) == cart and int(pulls[1][1]) > 0 and int(pulls[1][1]) <= 32, "the owner takes the handle; the pace is sent (%.1f m/s)" % (float(pulls.get(1, [0, 0])[1]) / 10.0))
	cart_act(2, Carts.OP_GRAB, cart)
	check(pulling(2) == 0 and pulling(1) == cart, "a second player cannot take the handle while it is held")
	items.report_position(2, Vector3(19.0, 10.0, 6.0))
	cart_act(2, Carts.OP_UNLOAD, crate)
	check(int(items._items[crate]["struct"].get("on", 0)) == cart_uid, "nobody sets a crate down while the cart is pulled")

	# --- 6. Wheel it north toward B; the crate rides; save and restart mid-trip ---
	var moved_3: int = int(moved.get(3, 0))
	walk(1, Vector3(15.0, 10.0, 50.0))
	var at: Vector3 = items._items[cart]["pos"]
	check(at.z > 46.0 and at.z < 49.0 and pulling(1) == cart, "the cart follows behind the puller (at z %.1f, puller at 50)" % at.z)
	check((items._items[crate]["pos"] as Vector3).distance_to(items._carts.spot_pos(items._items[cart], 0)) < 0.01 and items._items[crate]["pos"].y > at.y + 0.3, "the crate rides on the cart's bed")
	check(int(moved.get(3, 0)) > moved_3, "players who see the cart hear each move (items_moved, %d)" % (int(moved.get(3, 0)) - moved_3))
	items._spoil_tick(float(items.table.spoilage().get("tick_s", 15)) * 40.0)
	var crate_wear: int = box(crate).wear[1]
	check(crate_wear > food_wear_0 and crate_wear == box(cart).wear[0] and box(control).wear[0] < crate_wear, "food in the crate keeps ageing in transit, at the cart's rate (%d, cart store %d, crate left at A %d)" % [crate_wear, box(cart).wear[0], box(control).wear[0]])
	var lock_before: String = JSON.stringify(items._items[crate]["struct"]["lock"])
	items.save()
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/world_items.json"))
	var row_on: int = 0

	for row in saved["items"]:
		if row.size() > 19 and int(row[10]) == crate_uid:
			row_on = int(row[18])

	check(int(saved["version"]) == 3 and row_on == cart_uid, "world_items.json version 3 keeps the crate on its cart (row index 18)")
	items = make_server()
	cart = id_of_uid(cart_uid)
	crate = id_of_uid(crate_uid)
	desk_a = at_spot("warehouse_desk", 22.0, 0.0)
	desk_b = at_spot("warehouse_desk", 17.0, 95.0)
	check(cart != 0 and (items._items[cart]["pos"] as Vector3).distance_to(at) < 0.01, "after a restart the cart stands where it was saved, mid-trip")
	check(crate != 0 and int(items._items[crate]["struct"].get("on", 0)) == cart_uid and (items._items[crate]["pos"] as Vector3).distance_to(items._carts.spot_pos(items._items[cart], 0)) < 0.01, "the crate is still on the cart")
	check(box(crate).count_of(stone) == 5 and box(crate).count_of(food) == 4 and box(crate).wear[1] == crate_wear and JSON.stringify(items._items[crate]["struct"]["lock"]) == lock_before and str(items._items[crate]["struct"]["owner"]) == keys[1], "with its contents, age, owner and lock")
	check(items._carts.pulls.is_empty(), "nobody holds the handle after a restart: the cart is parked")
	join(1, Vector3(15.0, 10.0, 50.0))
	join(3, Vector3(16.0, 10.0, 52.0))
	cart_act(1, Carts.OP_GRAB, cart)
	check(pulling(1) == cart, "the owner takes the handle again")
	walk(1, Vector3(15.0, 10.0, 93.0))
	items._spoil_tick(float(items.table.spoilage().get("tick_s", 15)) * 40.0)
	check(box(crate).wear[1] > crate_wear, "the food ages on after the restart too")
	cart_act(1, Carts.OP_RELEASE, 0)
	check(pulling(1) == 0 and int(pulls.get(1, [-1, 0])[0]) == 0, "the owner lets go: cart_pull 0")

	# --- 7. Set it down at B: desk B lists it, desk A does not; contents identical ---
	items.report_position(1, Vector3(16.5, 10.0, 92.0))
	cart_act(1, Carts.OP_UNLOAD, crate)
	var down: Vector3 = items._items[crate]["pos"]
	check(not items._items[crate]["struct"].has("on") and absf(down.y - 10.0) < 0.01 and down.distance_to(items._items[cart]["pos"]) < 2.6, "the crate is set down beside the cart at B")
	check(int(view_totals(1, desk_b)[1].get(stone, 0)) == 5 and int(views[1][1].get(food, 0)) == 4, "desk B lists it (5 stones, 4 raw meat)")
	items.report_position(1, Vector3(20.0, 10.0, 1.0))
	check(int(view_totals(1, desk_a)[1].get(stone, 0)) == 0, "desk A does not")
	check(box(crate).count_of(stone) == 5 and box(crate).count_of(food) == 4 and int(items._items[crate]["struct"]["uid"]) == crate_uid and JSON.stringify(items._items[crate]["struct"]["lock"]) == lock_before, "the same crate, uid, lock and contents (nothing lost or doubled)")
	join(2, down + Vector3(1.0, 0.0, 0.0))
	check(items._may_access(2, items._items[crate]) and not items._may_access(3, items._items[crate]), "the lock moved with the crate: the player who entered the code still may open it, a stranger still may not")

	# --- 8. Terrain and pace: steep ground, deep water, a puller running ahead ---
	var c_pos: Vector3 = items._items[cart]["pos"]
	items.report_position(1, c_pos + Vector3(1.5, 0.0, 0.0))
	cart_act(1, Carts.OP_GRAB, cart)
	var pace_loaded_free: int = int(pulls[1][1])
	walk(1, Vector3(RAMP_X + 8.0, 10.0, c_pos.z), 0.6)
	check(pulling(1) == 0 and (items._items[cart]["pos"] as Vector3).x < RAMP_X + 0.6 and str(said.get(1, "")) == "Too steep for the handcart.", "the cart stops at the foot of a steep slope and the handle slips (cart at x %.1f)" % (items._items[cart]["pos"] as Vector3).x)
	c_pos = items._items[cart]["pos"]
	items.report_position(1, c_pos + Vector3(-1.5, 0.0, 0.0))
	cart_act(1, Carts.OP_GRAB, cart)
	walk(1, Vector3(c_pos.x - 1.5, 10.0, WATER_Z + 8.0), 0.6)
	check(pulling(1) == 0 and (items._items[cart]["pos"] as Vector3).z <= WATER_Z + 0.6 and str(said.get(1, "")) == "The water is too deep for the handcart.", "deep water refuses the cart (cart at z %.1f)" % (items._items[cart]["pos"] as Vector3).z)
	c_pos = items._items[cart]["pos"]
	items.report_position(1, c_pos + Vector3(0.0, 0.0, -1.7))
	cart_act(1, Carts.OP_GRAB, cart)
	walk(1, c_pos + Vector3(0.0, 0.0, -12.0), 2.0)   # 10 m/s: faster than the cart's pace
	check(pulling(1) == 0 and str(said.get(1, "")) == "You lose hold of the handcart.", "a puller running ahead of the cart's pace loses the handle")
	box(cart).add(stone, 120)
	items.report_position(1, items._items[cart]["pos"] + Vector3(0.0, 0.0, -1.7))
	cart_act(1, Carts.OP_GRAB, cart)
	check(pulling(1) == cart and int(pulls[1][1]) < pace_loaded_free, "a heavier load slows the cart (%.1f against %.1f m/s)" % [float(pulls[1][1]) / 10.0, float(pace_loaded_free) / 10.0])

	# --- 9. Disconnect while pulling: the cart parks where it is ---
	walk(1, items._items[cart]["pos"] + Vector3(0.0, 0.0, -8.0), 0.4)
	check(pulling(1) == cart, "still pulling")
	var parked: Vector3 = items._items[cart]["pos"]
	items.peer_left(1)
	check(items._carts.pulls.is_empty() and items._carts.puller_of.is_empty(), "a disconnect lets go of the handle")
	join(1, parked + Vector3(0.0, 0.0, -6.0))
	walk(1, parked + Vector3(0.0, 0.0, -12.0))
	check((items._items[cart]["pos"] as Vector3).distance_to(parked) < 0.01, "the cart stays parked where it was")

	# --- 10. Payload: a crate too heavy for the cart stays down ---
	var heavy: int = items.dev_place("warehouse_crate@%f,%f" % [parked.x + 2.0, parked.z])
	box(heavy).add(stone, 200)
	items.report_position(1, parked + Vector3(1.0, 0.0, 0.0))
	cart_act(1, Carts.OP_LOAD, heavy)
	check(not items._items[heavy]["struct"].has("on"), "a crate that would take the cart past its payload stays on the ground")
	for s in box(heavy).SLOTS:
		box(heavy).clear_slot(s)

	cart_act(1, Carts.OP_LOAD, heavy)
	check(items._items[heavy]["struct"].has("on"), "empty, it goes on")
	check(items._carts.room_kg(heavy) < float(def["max_kg"]) - 120.0, "the payload counts the cart's store and the crate's own wood (%.0f kg left)" % items._carts.room_kg(heavy))

	# --- 11. Taking a loaded cart down: nothing lost ---
	var cargo_stone: int = box(cart).count_of(stone)
	items._items[heavy]["struct"]["owner"] = keys[2]
	items._items[heavy]["struct"]["lock"] = {"salt": "", "hash": "", "ok": [], "allow": [], "tries": {}}   # locked by player 2 (owner only)
	act(1, Net.ACT_PICKUP, cart)
	check(items._items.has(cart) and items._items[heavy]["struct"].has("on"), "a cart carrying someone else's locked crate does not come apart")
	items._items[heavy]["struct"].erase("lock")
	act(1, Net.ACT_PICKUP, cart)
	check(items._items.has(cart) and box(cart).count_of(stone) == cargo_stone and items._items[heavy]["struct"].has("on"), "with more cargo than the player can carry, taking it down does nothing (all is kept)")
	box(cart).clear_slot(1)
	box(cart).clear_slot(2)
	box(cart).clear_slot(3)
	box(cart).clear_slot(4)
	box(cart).clear_slot(5)
	box(cart).clear_slot(6)
	check(box(cart).count_of(stone) == 0 and box(cart).count_of(food) == 4, "(the stones are taken out; 4 raw meat stay in its store)")
	var inv = items.inventory_of(1)

	for s in inv.SLOTS:
		inv.clear_slot(s)

	act(1, Net.ACT_PICKUP, cart)
	check(not items._items.has(cart), "the loaded cart comes apart")
	check(have(1, "raw_meat") == 4 and have(1, "wooden_cart_wheel") == 2 and have(1, "axle") == 1 and have(1, "lumber") == 6 and have(1, "wooden_pin") == 12, "its cargo and every part are in the pack (4 raw meat, 2 wheels, 1 axle, 6 Planks, 12 pins)")
	check(items._items.has(heavy) and not items._items[heavy]["struct"].has("on") and absf(float(items._items[heavy]["pos"].y) - 10.0) < 0.01 and items._chests.has(int(items._items[heavy]["struct"]["uid"])), "the crate on it is set down whole")

	# --- 12. The cost of a pulled cart ---
	print("cart follow: %d reports, %.1f us each (only a pulled cart costs anything: one dictionary look-up per report otherwise)" % [items._carts.follows, float(items._carts.follow_usec) / maxf(float(items._carts.follows), 1.0)])
	print("test_handcart: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
