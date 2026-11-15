extends SceneTree

# Wood system phase 5, hauling (docs/design/TREE_WOOD_TOOLS_DESIGN.md s1.2, s6 W-14, W-15, W-16; Dave 15 Nov 2026): real server state, one player.
#   1. data: the Handcart's payload is 120 kg; the Small log sled and Small wagon are items (numbers below both next_number, a weight, a short description),
#      structures with a vehicle row on the Handcart's controller and hammer blueprints with the design's costs (the sled from logs, sticks and twine only, so it
#      comes before any saw); the Medium and Large sleds and wagons stay future-gated;
#   2. a player builds both from their blueprints with a Stone hammer;
#   3. cargo: the Handcart takes shoulder logs and plain Logs and stops at 120 kg; the sled takes logs, blocks and firewood only, up to its payload; the wagon takes anything;
#   4. crates: a sled has no bed for one, the wagon carries two, and each says its own name;
#   5. surface (W-16): the sled works on any ground, slower on bare rock and gravel, faster on snow, ice and (in rain) wet grass; it keeps pace on snow where the
#      Handcart cannot, and loses the handle on rock when walked at a pace it holds on snow.
#   godot --headless --path . --script res://src/worldgen/tools/test_wood_phase5.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Carts := preload("res://src/stream/server_carts.gd")
const DIR := "user://test_wood_phase5"

var failures: int = 0
var items
var clock: Array = [1.0e6]
var pulls: Dictionary = {}      # peer -> the last cart_pull [id, tenths of m/s]
var said: Dictionary = {}       # peer -> the last notice
var mat: Array = ["loam"]       # the surface material under every cart
var rain: Array = [0.0]         # the rain strength over the world


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func n(id: String) -> int:
	return items.table.number_of(id)


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
	s.send_storage_view = func(_p, _id, _numbers, _counts, _containers): pass
	s.send_craft_stock = func(_p, _n, _c): pass
	s.send_bulk_done = func(_p, _k, _s, _c, _i): pass
	s.send_craft_queue = func(_p, _e, _l): pass
	s.send_cart_pull = func(p, id, pace): pulls[p] = [id, pace]
	s.send_items_moved = func(_p, _ids, _at, _yaws): pass
	s.ground_height = func(_x, _z): return 10.0
	s.water_depth_at = func(_pos: Vector3) -> float: return 0.0
	s.ground_material = func(_x, _z): return str(mat[0])
	s.rain_now = func(): return float(rain[0])
	s.unix_now = func(): return clock[0]
	s.setup(ItemTableScript.load_default(), DIR)
	s.admin_mode_on = func(_p): return false
	return s


func join(at: Vector3) -> void:
	items.peer_connected_hello(1, "woodphase5key1")
	items.report_position(1, at)
	items.vitals_of(1)["weight"] = 75.0
	clear_pack()


func clear_pack() -> void:
	var inv = items.inventory_of(1)

	for s in inv.slot_count:
		inv.clear_slot(s)


func act(kind: int, a: int, b: int = 0, count: int = 0, at: Vector3 = Vector3.ZERO) -> void:
	items.action(1, kind, a, b, count, at)


func place(kind: String, x: float, z: float) -> int:
	return items.dev_place("%s@%f,%f,0" % [kind, x, z])


func box(id: int):
	return items._chests[int(items._items[id]["struct"]["uid"])]


func empty(id: int) -> void:
	for s in box(id).slot_count:
		box(id).clear_slot(s)


func of_kind(kind: String) -> Array:
	var out: Array = []

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind:
			out.append(id)

	return out


# Gives one item (a log goes on the shoulder) and puts it into the container from the pack: a log by the shoulder slot (-1), anything else by its slot.
func put(id: int, item: String, count: int) -> void:
	said.erase(1)

	if items.is_shoulder_item(n(item)):
		items.give(1, n(item), count)
		act(Net.ACT_CHEST_PUT, -1, id, count)
		return

	items.inventory_of(1).add(n(item), count)
	act(Net.ACT_CHEST_PUT, items.inventory_of(1).numbers.find(n(item)), id, count)


func in_box(id: int, item: String) -> int:
	return box(id).count_of(n(item))


func cost_of(row: Dictionary) -> Dictionary:
	var out: Dictionary = {}

	for need in row.get("cost", []):
		out[str(need[0])] = int(need[1])

	return out


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = make_server()
	data_checks()
	join(Vector3(3.0, 10.0, 5.0))
	build_checks()
	cargo_checks()
	crate_checks()
	surface_checks()
	print("test_wood_phase5: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


# --- 1. Data ---
func data_checks() -> void:
	var item_file: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json"))
	var gathered: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/gathered.json"))
	var weights: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/weights.json"))
	var bps: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json"))
	check(int(item_file["next_number"]) == int(gathered["next_number"]) and int(item_file["next_number"]) > 1482 and int(bps["next_number"]) > 357, "items.json and gathered.json next_number are in step and above the new rows, blueprints.json too")

	for id in ["small_log_sled", "small_wagon"]:
		var row: Dictionary = item_file["items"][id]
		var text: String = str(row["description"])
		check(int(row["number"]) in [1481, 1482] and str(row["kind"]) == "structure" and not bool(items.table.entry(id).get("future", false)), "%s is a live structure item (%d)" % [id, int(row["number"])])
		check(text.length() <= 110 and text.ends_with(".") and str(row["name"]).split(" ").size() <= 4, "%s: a name of at most four words and a description of at most 110 characters ending in a full stop" % id)
		check(weights["by_id"].has(id) and float(weights["by_id"][id]) > 0.0, "%s has a weight (%.1f kg)" % [id, float(weights["by_id"].get(id, 0.0))])

	# W-15: the Handcart's payload.
	var cart: Dictionary = items._structures["handcart"]
	check(float(cart["max_kg"]) == 120.0 and int(cart["slots"]) == 12 and not cart.has("takes") and not cart.has("takes_kinds"), "the Handcart carries 120 kg in 12 slots and takes any cargo, logs included")

	# W-14: blueprints, structures, one controller.
	var sled_bp: Dictionary = items._blueprints.get(356, {})
	var wagon_bp: Dictionary = items._blueprints.get(357, {})
	check(str(sled_bp.get("structure", "")) == "small_log_sled" and int(sled_bp.get("hammer", 0)) == 1 and str(sled_bp.get("tool", "hammer")) == "hammer" and str(sled_bp.get("station", "")) == "" and bool(sled_bp.get("known", false)), "blueprint 356 builds the Small log sled with a plain hammer, at no station")
	check(cost_of(sled_bp) == {"log": 2, "stick": 6, "twine": 4}, "the sled costs 2 Logs, 6 Sticks and 4 Twine: nothing sawn, so it comes before any saw (%s)" % str(cost_of(sled_bp)))
	check(str(wagon_bp.get("structure", "")) == "small_wagon" and int(wagon_bp.get("hammer", 0)) == 1 and bool(wagon_bp.get("known", false)) and cost_of(wagon_bp) == {"lumber": 8, "wooden_cart_wheel": 4, "axle": 2, "wooden_pin": 16}, "blueprint 357 builds the Small wagon for 8 Planks, 4 Wooden cart wheels, 2 Axles and 16 Wooden pins (%s)" % str(cost_of(wagon_bp)))
	check(cost_of(items._blueprints.get(250, {})) == {"lumber": 6, "wooden_cart_wheel": 2, "axle": 1, "wooden_pin": 12}, "the Handcart's own blueprint is unchanged")

	var sled: Dictionary = items._structures["small_log_sled"]
	var wagon: Dictionary = items._structures["small_wagon"]
	var states: Array = items._structures.values().map(func(d): return int(d.get("state", -1)))
	check(sled.has("vehicle") and wagon.has("vehicle") and states.count(446) == 1 and states.count(447) == 1 and int(sled["state"]) == 446 and int(wagon["state"]) == 447, "both are vehicle rows with their own new state (446, 447)")
	check((sled["takes"] as Array) == ["log", "wooden_block", "firewood"] and (sled["vehicle"]["crate_spots"] as Array).is_empty() and (wagon["vehicle"]["crate_spots"] as Array).size() == 2 and float(wagon["max_kg"]) > float(sled["max_kg"]) and float(sled["max_kg"]) > float(cart["max_kg"]), "the sled takes logs, blocks and firewood and has no bed for crates; the wagon has two crate spots and the largest payload")
	check(items._blueprint_of_kit.has("small_log_sled") and items._blueprint_of_kit.has("small_wagon"), "each comes apart into its blueprint's materials (kit to blueprint)")

	for id in ["cargo_sled", "light_cargo_cart", "farm_wagon", "timber_wagon", "passenger_sleigh"]:   # Medium and Large wait for animal keeping (W-14)
		check(bool(items.table.entry(id).get("future", false)) and not items._structures.has(id), "%s stays future-gated" % id)


# --- 2. A player builds them ---
func build_checks() -> void:
	var inv = items.inventory_of(1)
	items.give(1, n("stone_hammer"), 1)
	var at: int = inv.numbers.find(n("stone_hammer"))

	if not inv.on_hotbar(at):
		inv.move(at, 0)

	inv.add(n("log"), 2)
	inv.add(n("stick"), 6)
	inv.add(n("twine"), 4)
	act(Net.ACT_PLACE_BLUEPRINT, 356, 0, 0, Vector3(4.5, 10.0, 3.0))
	var sleds: Array = of_kind("small_log_sled")
	var sled: int = sleds[0] if sleds.size() == 1 else 0

	if sled != 0 and items._items[sled]["struct"].has("site"):
		act(Net.ACT_USE_STRUCT, sled)   # the materials go in from the pack

	check(sled != 0 and not items._items[sled]["struct"].has("site") and items._items[sled]["struct"].has("uid") and not items._carts.vehicle_of(items._items[sled]).is_empty(), "the Small log sled is built from its blueprint with a Stone hammer, and is a vehicle with its own store (%s)" % str(said.get(1, "")))
	check(inv.count_of(n("log")) == 0 and inv.count_of(n("stick")) == 0 and inv.count_of(n("twine")) == 0, "its logs, sticks and twine were used")
	inv.add(n("lumber"), 8)
	inv.add(n("wooden_cart_wheel"), 4)
	inv.add(n("axle"), 2)
	inv.add(n("wooden_pin"), 16)
	act(Net.ACT_PLACE_BLUEPRINT, 357, 0, 0, Vector3(4.5, 10.0, 7.5))
	var wagons: Array = of_kind("small_wagon")
	var wagon: int = wagons[0] if wagons.size() == 1 else 0

	if wagon != 0 and items._items[wagon]["struct"].has("site"):
		act(Net.ACT_USE_STRUCT, wagon)

	check(wagon != 0 and not items._items[wagon]["struct"].has("site") and not items._carts.vehicle_of(items._items[wagon]).is_empty(), "the Small wagon is built from its blueprint, and is a vehicle (%s)" % str(said.get(1, "")))
	check(inv.count_of(n("lumber")) == 0 and inv.count_of(n("wooden_cart_wheel")) == 0 and inv.count_of(n("axle")) == 0 and inv.count_of(n("wooden_pin")) == 0, "its planks, wheels, axles and pins were used")


# --- 3. Cargo and payload ---
func cargo_checks() -> void:
	clear_pack()
	items.report_position(1, Vector3(30.0, 10.0, 30.0))
	var cart: int = place("handcart", 31.5, 30.0)
	put(cart, "log_oak", 1)
	check(in_box(cart, "log_oak") == 1 and items.shoulder_of(1) == "", "a shoulder log goes into the Handcart")
	put(cart, "log", 2)
	check(in_box(cart, "log") == 2, "so do plain Logs")
	empty(cart)

	for i in 5:
		put(cart, "log_oak", 1)

	check(in_box(cart, "log_oak") == 5, "five hardwood logs (110 kg) fit the 120 kg Handcart")
	put(cart, "log_oak", 1)
	check(in_box(cart, "log_oak") == 5 and items.shoulder_of(1) == "log_oak", "a sixth would pass 120 kg: it stays on the shoulder (the old 300 kg took it)")
	items.lay_down_shoulder(1)
	put(cart, "firewood", 13)
	check(in_box(cart, "firewood") == 13 and items._carts.room_kg(cart) < 0.5 and items._carts.payload_kg(items._items[cart]) == 120.0, "firewood fills the last kilograms: %.2f kg of 120 left" % items._carts.room_kg(cart))
	clear_pack()

	var sled: int = place("small_log_sled", 40.0, 30.0)
	items.report_position(1, Vector3(38.5, 10.0, 30.0))
	put(sled, "log_oak", 1)
	put(sled, "log", 1)
	put(sled, "wooden_block", 2)
	put(sled, "firewood", 8)
	check(in_box(sled, "log_oak") == 1 and in_box(sled, "log") == 1 and in_box(sled, "wooden_block") == 2 and in_box(sled, "firewood") == 8, "the sled takes a shoulder log, a plain Log, Wooden blocks and Firewood")
	var refused: bool = true

	for item in ["stone", "lumber", "raw_meat"]:
		put(sled, item, 1)
		refused = refused and in_box(sled, item) == 0 and items.inventory_of(1).count_of(n(item)) == 1

		if items.inventory_of(1).count_of(n(item)) == 1:
			items.inventory_of(1).remove(n(item), 1)

	check(refused and str(said.get(1, "")) != "", "and nothing else: a stone, a Plank and meat stay in the pack")
	var every_log: bool = true

	for id in items.table.ids():
		if str(items.table.entry(id).get("carry", "")) == "shoulder":
			every_log = every_log and items._box_takes("small_log_sled", n(id)) and items._box_takes("handcart", n(id))

	check(every_log and not items._box_takes("small_log_sled", n("stone")), "every species log is a log for both (the plain Log group)")
	empty(sled)

	for i in 9:
		put(sled, "log_oak", 1)

	put(sled, "log_oak", 1)
	check(in_box(sled, "log_oak") == 9 and items.shoulder_of(1) == "log_oak" and items._carts.payload_kg(items._items[sled]) == 200.0, "nine hardwood logs (198 kg) load on the sled, a tenth passes its 200 kg and stays on the shoulder")
	clear_pack()

	var wagon: int = place("small_wagon", 50.0, 30.0)
	items.report_position(1, Vector3(48.5, 10.0, 30.0))
	put(wagon, "lumber", 2)
	put(wagon, "log_oak", 1)
	check(in_box(wagon, "lumber") == 2 and in_box(wagon, "log_oak") == 1, "the wagon takes anything: Planks and a log")
	empty(wagon)
	box(wagon).add(n("stone"), 300)
	put(wagon, "stone", 1)
	check(in_box(wagon, "stone") == 300 and items.inventory_of(1).count_of(n("stone")) == 1 and items._carts.room_kg(wagon) < 0.01, "300 kg of stone fill the wagon; one more stays in the pack")
	clear_pack()


# --- 4. Crates ---
func crate_checks() -> void:
	var sled: int = place("small_log_sled", 60.0, 30.0)
	var crate: int = place("warehouse_crate", 61.5, 30.0)
	items.report_position(1, Vector3(62.5, 10.0, 30.0))
	said.erase(1)
	act(Net.ACT_CART, crate, Carts.OP_LOAD)
	check(not items._items[crate]["struct"].has("on") and str(said.get(1, "")) == "There is no cart close enough.", "a crate beside only a sled stays down: the sled has no bed (%s)" % str(said.get(1, "")))
	check(items._carts.riders_of(sled).is_empty(), "nothing rides on the sled")

	var wagon: int = place("small_wagon", 80.0, 30.0)
	var crates: Array = [place("warehouse_crate", 81.6, 29.4), place("warehouse_crate", 81.6, 30.6), place("warehouse_crate", 78.4, 30.0)]
	items.report_position(1, Vector3(80.0, 10.0, 30.0))

	for c in crates:
		said.erase(1)
		act(Net.ACT_CART, c, Carts.OP_LOAD)

	var spots: Array = items._carts.riders_of(wagon).map(func(r): return int(items._items[r]["struct"].get("spot", -1)))
	spots.sort()
	check(spots == [0, 1] and not items._items[crates[2]]["struct"].has("on") and str(said.get(1, "")) == "The wagon has no room for another crate.", "the wagon carries two crates on its two spots and refuses a third by name (%s)" % str(said.get(1, "")))
	said.erase(1)
	act(Net.ACT_PICKUP, items._carts.riders_of(wagon)[0])
	check(str(said.get(1, "")) == "Set it down off the wagon first.", "a crate on the wagon must be set down before it is taken apart (%s)" % str(said.get(1, "")))


# --- 5. Surface (W-16) ---
# The pace sent to the puller (tenths of m/s) on this material in this much rain.
func pace_on(id: int, material: String, rain_v: float = 0.0) -> int:
	mat[0] = material
	rain[0] = rain_v
	items._carts.release(1, "")
	items.report_position(1, (items._items[id]["pos"] as Vector3) + Vector3(0.0, 0.0, -1.7))
	act(Net.ACT_CART, id, Carts.OP_GRAB)
	return int(pulls.get(1, [0, 0])[1])


func surface_checks() -> void:
	var sled: int = place("small_log_sled", 100.0, 30.0)
	var hand: int = place("handcart", 110.0, 30.0)
	var flat: int = pace_on(sled, "loam")
	check(flat > 0 and pace_on(sled, "bare_rock") < flat and pace_on(sled, "rock") < flat and pace_on(sled, "gravel") < flat, "the sled is slower on bare rock, rock and gravel than on loam (%.1f m/s)" % [float(flat) / 10.0])
	check(pace_on(sled, "bare_rock") > 0, "but it still goes on rock")
	check(pace_on(sled, "snow") > flat and pace_on(sled, "glacial_ice") > flat, "and faster on snow and ice")
	check(pace_on(sled, "mud") == flat and pace_on(sled, "sand") == flat and pace_on(sled, "peat") == flat, "it works on mud, sand and peat as on any ground")
	check(pace_on(hand, "mud") < pace_on(sled, "mud") and pace_on(hand, "snow") < pace_on(hand, "loam"), "where the Handcart drags in mud and snow")
	check(pace_on(sled, "loam", 0.5) > flat and pace_on(sled, "forest_humus", 0.5) > pace_on(sled, "forest_humus"), "wet grass (rain on a grass soil) is faster than dry")
	check(pace_on(sled, "loam", 0.1) == flat and pace_on(sled, "bare_rock", 0.5) == pace_on(sled, "bare_rock") and pace_on(sled, "snow", 0.5) == pace_on(sled, "snow"), "a drizzle does not count, and rain does not help rock or snow")
	check(pace_on(hand, "loam", 0.5) == pace_on(hand, "loam"), "rain changes nothing for the Handcart")

	# A pulled sled follows: on snow at 3.6 m/s it keeps hold; on rock at 3 m/s it slips and says so by name; on rock at 2 m/s it keeps hold.
	var here: Vector3 = items._items[sled]["pos"]
	pace_on(sled, "snow")
	walk(here + Vector3(0.0, 0.0, -16.7), 0.72)
	check(int(items._carts.puller_of.get(1, 0)) == sled and (items._items[sled]["pos"] as Vector3).z < here.z - 12.0, "on snow the sled keeps up with a walker at 3.6 m/s (at z %.1f)" % (items._items[sled]["pos"] as Vector3).z)
	items._carts.release(1, "")
	here = items._items[sled]["pos"]
	pace_on(sled, "bare_rock")
	walk(here + Vector3(0.0, 0.0, -16.7), 0.4)
	check(int(items._carts.puller_of.get(1, 0)) == sled and (items._items[sled]["pos"] as Vector3).z < here.z - 12.0, "on bare rock it keeps up at 2 m/s")
	items._carts.release(1, "")
	here = items._items[sled]["pos"]
	pace_on(sled, "bare_rock")
	walk(here + Vector3(0.0, 0.0, -16.7), 0.6)
	check(int(items._carts.puller_of.get(1, 0)) == 0 and str(said.get(1, "")) == "You lose hold of the sled.", "but at 3 m/s on bare rock the handle slips (%s)" % str(said.get(1, "")))


# The puller walks from where they are to `to` in 0.2 s reports of `step` metres; the clock moves with them.
func walk(to: Vector3, step: float) -> void:
	var here: Vector3 = items._peer_pos[1]

	while Vector2(to.x - here.x, to.z - here.z).length() > 0.01 and int(items._carts.puller_of.get(1, 0)) != 0:
		var d: Vector3 = Vector3(to.x - here.x, 0.0, to.z - here.z)
		here += d.normalized() * minf(step, d.length())
		clock[0] += 0.2
		items.report_position(1, here)
