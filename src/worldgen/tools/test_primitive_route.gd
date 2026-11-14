extends SceneTree

# The primitive route and its goal credit (GOALS-REPAIR WP-PRIM, findings F1, F3, F4, F5 and the P2 gate gap; baseline/PRIMITIVE_ROUTE_d990abd.md).
# Everything is played through the server's player actions (pickup, craft queue, hits, process, place, put, light, drink, eat), and the goal counters
# (characters.json goal_counts, what the starter goals read) are checked for exactly the counts each action should leave:
#   1. the P2 route with ZERO admin gives: hand, tree, blocks, hammer, Chopping Block, firewood, medium fire, bonfire, charcoal, lean-to, a Crude piece;
#   2. F1: a lean-to placed short of sticks and finished by depositing the rest counts `placed:lean_to` once (the site path lost the kind);
#   3. F3: the axe on a ground log and the E split at the Chopping Block count like one craft each, the F queue still counts once, a pick and Admin mode count nothing;
#   4. F4: a fire newly reaching medium or large through a player action credits `fire_tier` once; a direct bonfire credits medium too; a re-feed at the same tier and Admin mode credit nothing;
#   5. F5: a fresh character drinks (and eats a berry) about 10 s after spawning and the goal event counts once.
# Fixtures that stand in for the world (scatter heaps on the ground, a tree record) are placed with drop_in_world and tree_info, never given to the pack.
#   godot --headless --path . --script res://src/worldgen/tools/test_primitive_route.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var said: Array = []
var standing: Dictionary = {}
var near_water: Array = [false]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


# A new server in its own folder with one new character (peer 1), a flat world and one standing oak (tree 7, 18 m).
func fresh(name: String) -> void:
	var dir: String = "user://test_primitive_route_" + name
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	said = []
	standing = {7: true}
	near_water = [false]
	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_reject = func(_p, _r): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.send_carry = func(_p, _id): pass
	items.send_chest = func(_p, _id, _b): pass
	items.send_chest_info = func(_p, _id, _k, _m): pass
	items.send_chest_lock = func(_p, _id, _l, _m, _o, _w, _a): pass
	items.send_craft_stock = func(_p, _n, _c): pass
	items.send_bulk_done = func(_p, _k, _s, _c, _i): pass
	items.send_purse = func(_p, _c): pass
	items.send_goal_done = func(_p, _id, _copper): pass
	items.send_goals = func(_p, _rows): pass
	items.ground_height = func(_x, _z): return 10.0
	items.tree_info = func(_chunk, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.1} if standing.has(id) else {}
	items.cut_tree = func(_chunk, id): standing.erase(id); return true
	items.water_near = func(_pos, _reach): return near_water[0]
	items.setup(ItemTableScript.load_default(), dir)
	items.admin_mode_on = func(_p): return false
	items.peer_connected_hello(1, "primroute0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))


func n(id: String) -> int:
	return items.table.number_of(id)


func have(id: String) -> int:
	return items.inventory_of(1).count_of(n(id))


func counts(key: String) -> int:
	return int(items._goal_state_of(1)["goal_counts"].get(key, 0))


func done(goal: String) -> bool:
	return items._goal_state_of(1)["goals_done"].has(goal)


func pass_time(seconds: int) -> void:
	for _s in range(seconds):
		items.tick(1.0)


func craft(recipe: int, times: int, seconds: int) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe, 0, times, Vector3.ZERO)
	pass_time(seconds)


# The ids of the loose (not scattered, not a piece, not a tree) world items of an item.
func loose(id: String) -> Array:
	var found: Array = []

	for k in items._items:
		var it: Dictionary = items._items[k]

		if not it.has("scatter") and not it.has("tree") and not it.has("fire") and not it.has("struct") and int(it["number"]) == n(id):
			found.append(k)

	return found


# Picks up every loose heap of these items, as many passes as a handful at a time needs (a log goes to the shoulder: never listed here).
func pick_up(ids: Array) -> void:
	for _pass in range(6):
		for id in ids:
			for k in loose(str(id)):
				items.action(1, Net.ACT_PICKUP, k, 0, 0, Vector3.ZERO)


func to_hotbar(id: String, slot: int) -> void:
	items.action(1, Net.ACT_MOVE, items.inventory_of(1).numbers.find(n(id)), slot, 0, Vector3.ZERO)


func piece_of(kind: String) -> int:
	for k in items._items:
		if items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == kind:
			return k

	return 0


func fire_ids() -> Array:
	var found: Array = []

	for k in items._items:
		if items._items[k].has("fire"):
			found.append(k)

	return found


func trunk_id() -> int:
	for k in items._items:
		if items._items[k].has("tree") and int(items._items[k]["tree"]["state"]) == 3:
			return k

	return 0


# Puts `count` of an item in the pack into a fire's store the way the window does: open, put, close (a burning fire counts its store when it closes).
func put_in_fire(fire: int, id: String, count: int) -> void:
	items.action(1, Net.ACT_CHEST_OPEN, fire, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, items.inventory_of(1).numbers.find(n(id)), fire, count, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)


func light(fire: int) -> void:
	items.action(1, Net.ACT_LIGHT, fire, 0, 0, Vector3.ZERO)


func state_of(fire: int) -> int:
	return int(items._items[fire]["fire"]["state"])


func _init() -> void:
	route()
	site_lean_to()
	manual_firewood()
	fire_tiers()
	drink_and_eat()
	print("primitive route tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# --- 1. The P2 route, zero admin gives ---
func route() -> void:
	fresh("route")
	items.vitals_of(1)["weight"] = 150.0   # a big frame: the route's stones, sticks, logs and blocks at their real weights fit
	check(have("stone") == 0 and have("stick") == 0 and counts("event:tree_felled") == 0, "a new character starts empty-handed with no goal counted")

	# Hand: stones, sticks, plant fibre and thatch lie about (what the ground scatter and the plants give); each heap is picked up with E.
	for k in range(6):
		var around: Vector3 = Vector3(cos(float(k) * TAU / 6.0), 0.0, sin(float(k) * TAU / 6.0))
		items.drop_in_world(n("stone"), 4, Vector3(0.0, 10.0, 0.0) + around * 1.5)
		items.drop_in_world(n("stick"), 5, Vector3(0.0, 10.0, 0.0) + around * 2.2)
		items.drop_in_world(n("plant_fibre"), 8, Vector3(0.0, 10.0, 0.0) + around * 2.9)
		items.drop_in_world(n("stick"), 1, Vector3(0.0, 10.0, 0.0) + around.rotated(Vector3.UP, 0.5) * 2.6)
		items.drop_in_world(n("thatch"), 5, Vector3(0.0, 10.0, 0.0) + around * 3.2)

	pick_up(["stone", "stick", "plant_fibre", "thatch"])
	check(have("stone") >= 8 and have("stick") >= 30 and have("plant_fibre") >= 42 and have("thatch") >= 20, "the heaps are gathered by hand (%d stones, %d sticks, %d fibre, %d thatch)" % [have("stone"), have("stick"), have("plant_fibre"), have("thatch")])

	# Tools: twine from fibre (recipe 1), then the Stone Axe (recipe 2); the axe goes on the hotbar.
	craft(1, 14, 60)
	craft(2, 1, 15)
	check(have("twine") >= 13 and have("stone_axe") == 1 and counts("made:stone_axe") == 1 and done("axe"), "twine and the Stone Axe are made by hand and the axe goal is done (%d twine)" % have("twine"))
	to_hotbar("stone_axe", 0)

	# Tree: fell the oak with the axe in hand.
	items.report_position(1, Vector3(8.0, 10.0, 0.0))

	for _hit in range(200):
		if standing.is_empty():
			break

		items._last_hit.clear()
		items.action(1, Net.ACT_HIT, 7, 0, 0, HeldTool.at_axe(items))

	check(standing.is_empty() and counts("event:tree_felled") == 1 and done("fell"), "felling the oak counts the tree once (%d)" % counts("event:tree_felled"))

	# The trunk: branch blows (sticks, leaves), then logs come off the far end onto the ground; cut four.
	var trunk: int = trunk_id()
	check(trunk != 0, "the felled oak lies as a trunk")
	var guard: int = 0

	while items._items.has(trunk) and loose("log_oak").size() < 4 and guard < 200:
		items.report_position(1, items.cut_line_point(trunk))
		items._last_process.clear()
		items.action(1, Net.ACT_PROCESS, trunk, 0, 0, HeldTool.at_axe(items))
		guard += 1

	check(loose("log_oak").size() >= 4 and have("leaves") >= 60, "four oak logs lie on the ground and the branch blows gave the lean-to's 60 leaves (%d logs, %d leaves, %d sticks)" % [loose("log_oak").size(), have("leaves"), have("stick")])

	# Blocks: the axe on a ground log gives three large wooden blocks (F3); one craft of Small wooden blocks (recipe 339) gives the small ones the hammer needs.
	var chopped: int = loose("log_oak")[0]
	items.report_position(1, items._items[chopped]["pos"] + Vector3(1.0, 0.0, 0.0))
	items._last_process.clear()
	items.action(1, Net.ACT_PROCESS, chopped, 0, 0, HeldTool.at_axe(items))
	pick_up(["wooden_block_large"])
	check(have("wooden_block_large") == 3 and counts("made:wooden_block_large") == 1, "the axe on a log gives 3 large blocks and counts one craft of them (%d blocks, %d counted)" % [have("wooden_block_large"), counts("made:wooden_block_large")])
	craft(339, 1, 10)
	check(have("wooden_block") == 4 and counts("made:wooden_block") == 1, "one large block is split into 4 small ones")

	# Hammer and Chopping Block.
	craft(161, 1, 10)
	to_hotbar("wooden_hammer", 1)
	check(have("wooden_hammer") == 1 and counts("made:wooden_hammer") == 1 and done("hammer"), "the Wooden Hammer is made and its goal is done")
	craft(15, 1, 12)
	items.report_position(1, Vector3(0.0, 10.0, 3.0))
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(n("chopping_block")), 0, 0, Vector3(2.0, 10.0, 3.0))
	var block: int = piece_of("chopping_block")
	check(block != 0 and counts("made:chopping_block") == 1 and counts("event:placed:chopping_block") == 1, "the Chopping Block is made and placed, each counted once")

	# Firewood: E at the block with the axe in hand, a large block then a small one. Each split counts like one craft (F3).
	var def: Dictionary = items._structures["chopping_block"]
	var per_large: int = int(def["firewood_per_large_block"])
	var per_small: int = int(def["firewood_per_block"])

	for _split in range(2):
		items._last_use.clear()
		items.action(1, Net.ACT_USE_STRUCT, block, 0, HeldTool.slot_of(items, "axe") + 1, Vector3.ZERO)

	pick_up(["firewood"])
	check(have("firewood") == per_large + per_small and counts("made:firewood") == 2, "two splits at the block give %d firewood and count two crafts (%d, %d counted)" % [per_large + per_small, have("firewood"), counts("made:firewood")])

	# Fire: the kit (recipe 4), placed laid with its start stick, lit small, three firewood make it medium, three logs a bonfire.
	craft(4, 1, 12)
	items.report_position(1, Vector3(-1.5, 10.0, 0.0))
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(n("campfire_kit")), 0, 0, Vector3(-3.0, 10.0, 0.0))
	var fire: int = fire_ids()[0] if not fire_ids().is_empty() else 0
	check(fire != 0 and counts("made:campfire_kit") == 1 and counts("event:placed:campfire") == 1, "the campfire is made and laid, each counted once")
	light(fire)
	check(items.fire_is_lit(state_of(fire)) and counts("event:fire_lit") == 1 and counts("event:fire_tier:medium") == 0 and done("fire"), "lit on its start stick it is a small fire: fire_lit once, no medium yet")
	put_in_fire(fire, "firewood", 3)
	check(state_of(fire) == 1 and counts("event:fire_tier:medium") == 1 and counts("event:fire_tier:large") == 0, "three firewood make it medium: credited once (state %d)" % state_of(fire))
	items.action(1, Net.ACT_CHEST_OPEN, fire, 0, 0, Vector3.ZERO)

	for _log in range(3):
		var log_id: int = loose("log_oak")[0]
		items.report_position(1, items._items[log_id]["pos"] + Vector3(1.0, 0.0, 0.0))
		items.action(1, Net.ACT_PICKUP, log_id, 0, 0, Vector3.ZERO)
		items.report_position(1, Vector3(-1.5, 10.0, 0.0))
		items.action(1, Net.ACT_CHEST_PUT, -1, fire, 1, Vector3.ZERO)

	items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
	check(state_of(fire) == ItemsScript.FIRE_STATE_BONFIRE and counts("event:fire_tier:medium") == 1 and counts("event:fire_tier:large") == 1, "three logs make it a bonfire: large credited once, medium still once (state %d)" % state_of(fire))

	# Charcoal at the lit fire from two firewood (recipe 341; the firewood left over from the medium fire).
	craft(341, 1, 40)
	check(have("charcoal") == 12 and counts("made:charcoal") == 1, "charcoal is made at the lit fire and counted once (%d)" % have("charcoal"))

	# Lean-to (blueprint 25: 20 sticks, 60 leaves, 6 twine) and a Crude piece (the thatch floor, blueprint 29), both with the hammer on the hotbar.
	items.report_position(1, Vector3(-6.0, 10.0, -5.0))
	items.action(1, Net.ACT_PLACE_BLUEPRINT, 25, 0, 0, Vector3(-6.0, 10.0, -8.0))
	check(piece_of("lean_to") != 0 and counts("event:placed:lean_to") == 1 and done("shelter"), "the lean-to is built with the hammer and counted once (%d)" % counts("event:placed:lean_to"))
	items.report_position(1, Vector3(6.0, 10.0, -5.0))
	items.action(1, Net.ACT_PLACE_BLUEPRINT, 29, 0, 0, Vector3(6.0, 10.0, -8.0))
	check(piece_of("thatch_floor") != 0 and counts("event:placed:thatch_floor") == 1, "a Crude thatch floor is built and counted once (%d)" % counts("event:placed:thatch_floor"))

	var admin_keys: int = 0

	for key in items._goal_state_of(1)["goal_counts"]:
		admin_keys += 1 if str(key).begins_with("admin:") else 0

	check(admin_keys == 0, "no admin give was used anywhere on the route")


# --- 2. F1: a site finished by deposit counts the piece's own kind ---
func site_lean_to() -> void:
	fresh("site")
	items.vitals_of(1)["weight"] = 150.0
	items.give(1, n("wooden_hammer"), 1)
	items.give(1, n("stick"), 10)   # the lean-to needs 20
	items.give(1, n("leaves"), 60)
	items.give(1, n("twine"), 6)
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.action(1, Net.ACT_PLACE_BLUEPRINT, 25, 0, 0, Vector3(0.0, 10.0, 3.0))
	var site: int = piece_of("lean_to")
	check(site != 0 and items._items[site]["struct"].has("site") and counts("event:placed:lean_to") == 0, "short of sticks the lean-to is a site, and a site counts nothing yet")
	items.give(1, n("stick"), 10)
	items.action(1, Net.ACT_USE_STRUCT, site, 0, 0, Vector3.ZERO)
	check(not items._items[site]["struct"].has("site") and counts("event:placed:lean_to") == 1 and counts("event:placed") == 1 and done("shelter"), "depositing the rest finishes it: placed:lean_to once, the shelter goal done (%d, any kind %d)" % [counts("event:placed:lean_to"), counts("event:placed")])


# --- 3. F3: manual firewood and blocks ---
func manual_firewood() -> void:
	fresh("chop")
	items.vitals_of(1)["weight"] = 150.0
	items.give(1, n("stone_axe"), 1)
	to_hotbar("stone_axe", 0)
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var block: int = items.dev_place("chopping_block@2,0,0")
	items.drop_in_world(n("log_oak"), 1, Vector3(0.0, 10.0, 2.0))
	items.drop_in_world(n("log"), 1, Vector3(0.0, 10.0, -2.0))

	# Axe on a ground log: one count per chop, the block of the log's class (a species log: large and hard; the plain Log: small and soft).
	items._last_process.clear()
	items.action(1, Net.ACT_PROCESS, loose("log_oak")[0], 0, 0, HeldTool.at_axe(items))
	check(counts("made:wooden_block_large") == 1 and counts("made:wooden_block_soft") == 0, "the axe on an oak log counts one large block craft")
	items._last_process.clear()
	items.action(1, Net.ACT_PROCESS, loose("log")[0], 0, 0, HeldTool.at_axe(items))
	check(counts("made:wooden_block_soft") == 1, "the axe on a plain Log counts one soft block craft")
	pick_up(["wooden_block_large", "wooden_block_soft"])

	# E at the block: one count per split, firewood of the block's class (large blocks first: the oak's three, then a soft one).
	for _split in range(3):
		items._last_use.clear()
		items.action(1, Net.ACT_USE_STRUCT, block, 0, HeldTool.slot_of(items, "axe") + 1, Vector3.ZERO)

	check(counts("made:firewood") == 3 and counts("made:firewood_soft") == 0, "three splits of large hard blocks count three hard firewood crafts (%d)" % counts("made:firewood"))
	items._last_use.clear()
	items.action(1, Net.ACT_USE_STRUCT, block, 0, HeldTool.slot_of(items, "axe") + 1, Vector3.ZERO)
	check(counts("made:firewood") == 3 and counts("made:firewood_soft") == 1, "a soft block then counts one soft firewood craft")

	# The F queue at the block counts once more, per craft, as before: no double count with the E split.
	items.give(1, n("log_oak"), 1)
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, 721, 0, 1, Vector3.ZERO)
	pass_time(20)
	check(counts("made:firewood") == 4 and counts("made:firewood_soft") == 1, "one Hard firewood craft at the block counts once (%d hard, %d soft in all)" % [counts("made:firewood"), counts("made:firewood_soft")])

	# A pick on a log tears kindling, not blocks: nothing is counted. Admin mode counts nothing either.
	items.give(1, n("stone_pickaxe"), 1)
	to_hotbar("stone_pickaxe", 2)
	var before: int = counts("made:wooden_block_large")
	var soft_before: int = counts("made:firewood_soft")
	items.drop_in_world(n("log_oak"), 1, Vector3(0.0, 10.0, 2.0))

	for _blow in range(40):
		if loose("log_oak").is_empty():
			break

		items._last_process.clear()
		items.action(1, Net.ACT_PROCESS, loose("log_oak")[0], 0, 0, Vector3(float(HeldTool.slot_of(items, "pick") + 1), 0.0, 0.0))

	check(loose("log_oak").is_empty() and counts("made:wooden_block_large") == before, "a log broken with the pick leaves kindling and counts no block")
	items.admin_ok = func(_p): return true
	items.admin_mode_on = func(_p): return true
	items.drop_in_world(n("log_oak"), 1, Vector3(0.0, 10.0, 2.0))
	items._last_process.clear()
	items.action(1, Net.ACT_PROCESS, loose("log_oak")[0], 0, 0, HeldTool.at_axe(items))
	items._last_use.clear()
	items.action(1, Net.ACT_USE_STRUCT, block, 0, HeldTool.slot_of(items, "axe") + 1, Vector3.ZERO)
	check(counts("made:wooden_block_large") == before and counts("made:firewood_soft") == soft_before and counts("made:firewood") == 4, "in Admin mode a chop and a split count nothing (GA-54)")


# --- 4. F4: fire tiers ---
func fire_tiers() -> void:
	fresh("tiers")
	items.vitals_of(1)["weight"] = 150.0
	items.give(1, n("campfire_kit"), 3)
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(n("campfire_kit")), 0, 0, Vector3(1.0, 10.0, 0.0))
	var a: int = fire_ids()[0]
	light(a)
	check(state_of(a) == ItemsScript.FIRE_STATE_SURVIVAL and counts("event:fire_lit") == 1 and counts("event:fire_tier") == 0, "lit on its start stick: a small fire credits no tier")

	# Medium once, through the store window; a re-feed at the same tier credits nothing.
	items.give(1, n("firewood"), 4)
	put_in_fire(a, "firewood", 3)
	check(state_of(a) == 1 and counts("event:fire_tier:medium") == 1 and counts("event:fire_tier:large") == 0 and counts("event:fire_tier") == 1, "three firewood in a burning fire: medium credited once")
	put_in_fire(a, "firewood", 1)
	check(state_of(a) == 1 and counts("event:fire_tier:medium") == 1 and counts("event:fire_tier") == 1, "a fourth firewood at the same tier credits nothing")

	# Large through ACT_FUEL (a log each): nothing until the third log lifts it; medium is not credited again.
	items.give(1, n("log"), 3)

	for k in range(3):
		items.action(1, Net.ACT_FUEL, a, 0, 0, Vector3.ZERO)

		if k < 2:
			check(counts("event:fire_tier:large") == 0, "log %d of 3 on the fire: no new tier" % (k + 1))

	check(state_of(a) == ItemsScript.FIRE_STATE_BONFIRE and counts("event:fire_tier:large") == 1 and counts("event:fire_tier:medium") == 1 and counts("event:fire_tier") == 2, "the third log makes the bonfire: large credited once, medium not again")

	# Burning down credits nothing.
	items._fire_burn(items._items[a]["fire"], 1.0e7)
	check(counts("event:fire_tier") == 2, "burning down is no progress (%d tier events)" % counts("event:fire_tier"))

	# A direct bonfire: three logs loaded in a laid fire, then lit, credits medium and large together.
	items.report_position(1, Vector3(9.0, 10.0, 0.0))
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(n("campfire_kit")), 0, 0, Vector3(10.0, 10.0, 0.0))
	var b: int = fire_ids().filter(func(k): return k != a)[0]
	items.give(1, n("log"), 3)
	put_in_fire(b, "log", 3)
	check(counts("event:fire_tier") == 2, "loading a laid fire credits nothing")
	light(b)
	check(state_of(b) == ItemsScript.FIRE_STATE_BONFIRE and counts("event:fire_tier:medium") == 2 and counts("event:fire_tier:large") == 2, "a fire lit straight to a bonfire credits medium and large (medium %d, large %d)" % [counts("event:fire_tier:medium"), counts("event:fire_tier:large")])

	# Admin mode: lighting counts nothing.
	items.report_position(1, Vector3(-9.0, 10.0, 0.0))
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(n("campfire_kit")), 0, 0, Vector3(-10.0, 10.0, 0.0))
	var c: int = fire_ids().filter(func(k): return k != a and k != b)[0]
	items.give(1, n("firewood"), 3)
	put_in_fire(c, "firewood", 3)
	items.admin_ok = func(_p): return true
	items.admin_mode_on = func(_p): return true
	light(c)
	check(items.fire_is_lit(state_of(c)) and counts("event:fire_tier:medium") == 2 and counts("event:fire_lit") == 2, "in Admin mode a lit medium fire counts nothing (GA-54)")


# --- 5. F5: drink and eat soon after spawning ---
func drink_and_eat() -> void:
	fresh("vitals")
	near_water[0] = true
	var thirst_cap: float = float((items._vitals_cfg.get("thirst", {}) as Dictionary).get("cap_ml", 2400))
	var fed_cap: float = float(items._vitals_cfg.get("stomach_cap_kcal", 2400))
	check(float(items.vitals_of(1)["wet"]) >= thirst_cap - 0.5 and float(items.vitals_of(1)["fed"]) >= fed_cap - 0.5, "a new character starts with a full thirst and a full stomach")
	pass_time(10)
	var wet_before: float = float(items.vitals_of(1)["wet"])
	var fed_before: float = float(items.vitals_of(1)["fed"])
	check(wet_before < thirst_cap - 1.0 and fed_before < fed_cap, "ten seconds later both have dropped (thirst %.1f of %.0f, stomach %.1f of %.0f)" % [wet_before, thirst_cap, fed_before, fed_cap])
	items.action(1, Net.ACT_DRINK, 0, 0, 0, Vector3.ZERO)
	check(float(items.vitals_of(1)["wet"]) > wet_before and counts("event:drink") == 1 and done("drink"), "drinking at the water now fills the thirst and counts once (%d)" % counts("event:drink"))
	items.give(1, n("blueberries"), 1)
	items.action(1, Net.ACT_EAT, items.inventory_of(1).numbers.find(n("blueberries")), 0, 0, Vector3.ZERO)
	check(float(items.vitals_of(1)["fed"]) > fed_before and counts("event:ate_food") == 1 and done("berries"), "eating a berry now raises the stomach and counts once (%d)" % counts("event:ate_food"))
