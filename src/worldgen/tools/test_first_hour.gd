extends SceneTree

# The first hour of a new character, start to finish on the server (job 78): gather by hand, hand-craft a stone axe,
# fell a tree and work the trunk, make and place a campfire, drink at the water, build a lean-to and a chest.
# Each step is asserted, and the vitals curve (hunger, thirst, exertion) is printed as "first hour:" lines.
#   godot --headless --path . --script res://src/worldgen/tools/test_first_hour.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var minute: float = 0.0
var curve: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


# Real seconds pass at a given exertion; the server ticks at 1 s and the craft queue runs inside the ticks.
func pass_time(seconds: float, exertion: float) -> void:
	for s in range(int(seconds)):
		items._exertion[1] = exertion
		items.tick(1.0)

	minute += seconds / 60.0


func note(label: String) -> void:
	var v: Dictionary = items.vitals_of(1)
	var points: Array = items._vitals_points(v)
	curve.append([minute, points[0], points[3]])
	print("first hour: minute %5.1f  hunger %3d%%  thirst %3d%%  weight %.1f kg  after %s" % [minute, points[0], points[3], float(v["weight"]), label])


func count(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func queue(recipe: int, crafts: int) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe, 0, crafts, Vector3.ZERO)


func pick_up_everything_near() -> int:
	var taken: int = 0

	for id in items._items.keys():
		var it: Dictionary = items._items[id]

		if it.has("scatter") or it.has("tree") or it.has("fire") or it.has("struct"):
			continue

		items.action(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
		taken += 1

	return taken


func _init() -> void:
	var dir: String = "user://test_first_hour"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	var standing: Dictionary = {7: true}
	items.tree_info = func(_chunk, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.1} if standing.has(id) else {}
	items.cut_tree = func(_chunk, id): standing.erase(id); return true
	var near_water: Array = [false]
	items.water_near = func(_pos, _reach): return near_water[0]
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "firsthour0001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items._vitals_cfg["eat_pace_ms"] = 0
	items._vitals_cfg["thirst"]["drink_pace_ms"] = 0
	items.vitals_of(1)["weight"] = 120.0   # real item weights: the whole first hour (36 sticks, 24 stones, then a log) needs a big frame
	var start: Array = items._vitals_points(items.vitals_of(1))
	check(start[0] == 100 and start[3] == 100 and count("stone") == 0, "a new character starts full and empty-handed")
	note("arriving")

	# 1. Gather by hand: stones, sticks and fibre lie around (what the ground scatter and the plants give).
	for n in range(6):
		var around: Vector3 = Vector3(cos(float(n) * TAU / 6.0), 0.0, sin(float(n) * TAU / 6.0))   # lying more than a metre apart, or they would merge into one heap
		items.drop_in_world(items.table.number_of("stone"), 4, Vector3(0.0, 10.0, 0.0) + around * 1.5)
		items.drop_in_world(items.table.number_of("stick"), 5, Vector3(0.0, 10.0, 0.0) + around * 2.2)
		items.drop_in_world(items.table.number_of("plant_fibre"), 8, Vector3(0.0, 10.0, 0.0) + around * 2.9)
		items.drop_in_world(items.table.number_of("stick"), 1, Vector3(0.0, 10.0, 0.0) + around.rotated(Vector3.UP, 0.5) * 2.6)

	pass_time(120.0, 0.3)
	var heaps: int = pick_up_everything_near()
	pick_up_everything_near()   # a heap gives a handful at a time: the fibre heaps (8 each) need a second pass
	check(heaps == 24 and count("stone") == 24 and count("stick") == 36 and count("plant_fibre") == 48, "gathering by hand fills the pack (%d stones, %d sticks, %d fibre)" % [count("stone"), count("stick"), count("plant_fibre")])
	note("gathering")

	# 2. Twist two twine from fibre by hand, then craft a stone axe (a stone, a stick and 2 twine).
	queue(1, 2)
	pass_time(20.0, 0.2)
	check(count("twine") == 2, "two twine are twisted by hand from fibre")
	queue(2, 1)
	pass_time(10.0, 0.2)
	check(count("stone_axe") == 1, "the stone axe is made by hand")
	items.action(1, Net.ACT_MOVE, items.inventory_of(1).numbers.find(items.table.number_of("stone_axe")), 0, 0, Vector3.ZERO)   # the player puts the axe on the hotbar
	note("crafting the axe")

	# 3. Fell a tree and work the trunk.
	items.report_position(1, Vector3(8.0, 10.0, 0.0))

	for n in range(30):
		items._last_hit.clear()
		items.action(1, Net.ACT_HIT, 7, 0, 0, Vector3.ZERO)

	check(standing.is_empty(), "the tree falls to the axe")
	pass_time(60.0, 0.8)
	var trunk_id: int = 0

	for k in items._items:
		if items._items[k].has("tree") and items._items[k]["tree"]["state"] == 3:
			trunk_id = k

	items.report_position(1, Vector3(14.0, 10.0, 0.0))
	var guard: int = 0

	while items._items.has(trunk_id) and guard < 200:
		if int(items._items[trunk_id]["tree"].get("blows", 0)) >= 2:
			items.report_position(1, items.cut_line_point(trunk_id))   # logs come off the far end: walk along to the cut line

		items._last_process.clear()
		items.action(1, Net.ACT_PROCESS, trunk_id, 0, 0, Vector3.ZERO)
		guard += 1

	pass_time(120.0, 0.8)
	var logs: int = count("log") + (1 if items.shoulder_of(1) != "" else 0)

	for k in items._items:   # the logs now fall to the ground beside the trunk (Dave): count the loose ones too
		if not items._items[k].has("tree") and not items._items[k].has("struct") and items.table.id_of(int(items._items[k]["number"])).begins_with("log"):
			logs += 1

	check(logs >= 1 and count("leaves") >= 1, "the trunk gives logs and leaves (%d logs, %d leaves, %d sticks)" % [logs, count("leaves"), count("stick")])
	print("first hour: after felling %d leaves, %d sticks, %d bark" % [count("leaves"), count("stick"), count("bark")])
	items.lay_down_shoulder(1)   # the big log is put down before the next job
	note("felling and working the tree")

	# 4. A campfire: craft the kit (6 sticks, 3 stones), place it (laid, not lit), light it with tinder from the pack.
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	queue(4, 1)
	pass_time(10.0, 0.2)
	check(count("campfire_kit") == 1, "the campfire kit is made (6 sticks, 3 stones)")
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("campfire_kit")), 0, 0, Vector3(2.0, 10.0, 0.0))
	var lit: int = 0

	for k in items._items:
		if items._items[k].has("fire"):
			items.action(1, Net.ACT_LIGHT, k, 0, 0, Vector3.ZERO)   # a placed fire is laid (fire tiers): light it with tinder from the pack

	for k in items._items:
		lit += 1 if items._items[k].has("fire") and items.fire_is_lit(int(items._items[k]["fire"]["state"])) else 0

	check(lit == 1, "the campfire is placed laid and then lit with tinder")
	note("making a campfire")

	# 5. Drink at the water's edge: no water, no drink; at the edge the thirst bar fills.
	pass_time(1200.0, 0.3)
	var before_drink: int = items._vitals_points(items.vitals_of(1))[3]
	check(before_drink < 100, "twenty minutes of work leave the character thirsty (%d%%)" % before_drink)
	items.action(1, Net.ACT_DRINK, 0, 0, 0, Vector3.ZERO)
	check(items._vitals_points(items.vitals_of(1))[3] == before_drink, "no drink away from water")
	near_water[0] = true

	for n in range(4):
		items.action(1, Net.ACT_DRINK, 0, 0, 0, Vector3.ZERO)

	check(items._vitals_points(items.vitals_of(1))[3] > before_drink, "a drink at the water's edge fills the thirst bar")
	near_water[0] = false
	note("drinking")

	# 6. A lean-to and a chest: twine from fibre, then the kits, then both placed.
	queue(1, 6)
	pass_time(30.0, 0.3)
	check(count("twine") == 6, "fibre is twisted into twine")
	items._vitals_cfg["eat_pace_ms"] = 0
	queue(13, 1)
	queue(14, 1)
	pass_time(70.0, 0.3)   # lean-to 25 s + chest 20 s since the craft pacing pass
	check(count("lean_to_kit") == 1 and count("chest_kit") == 1, "the lean-to and the woven chest are made")
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("lean_to_kit")), 0, 0, Vector3(-3.0, 10.0, 0.0))
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("chest_kit")), 0, 0, Vector3(0.0, 10.0, 4.0))
	var shelters: int = 0
	var chests: int = 0

	for k in items._items:
		if items._items[k].has("struct"):
			var kind: String = str(items._items[k]["struct"]["kind"])
			shelters += 1 if kind == "lean_to" else 0
			chests += 1 if items._items[k]["struct"].has("uid") else 0

	check(shelters == 1 and chests == 1, "a lean-to and a chest stand in camp (%d, %d)" % [shelters, chests])
	note("building the camp")

	# The hour as a whole: the curve only falls between drinks, and nothing is empty yet.
	pass_time(600.0, 0.2)
	note("resting")
	var last: Array = curve.back()
	check(last[1] > 0 and last[1] < 100, "hunger fell but is not empty after about 55 minutes (%d%%)" % last[1])
	check(last[2] > 0, "thirst is not empty after the drink (%d%%)" % last[2])

	for n in range(1, curve.size()):
		var drank: bool = curve[n][2] > curve[n - 1][2]
		check(curve[n][1] <= curve[n - 1][1] and (drank or curve[n][2] <= curve[n - 1][2]), "the vitals curve only falls, except a drink raises thirst (step %d)" % n)

	check(float(items.vitals_of(1)["health"]) >= 99.0, "nothing hurt the character in the first hour")
	print("first hour: %d failures" % failures)
	quit(1 if failures > 0 else 0)
