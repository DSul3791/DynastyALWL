extends SceneTree

# Starter goals (data/items/starter_goals.json, Sal; code by Tyler 31 Oct 2026): the real first-hour goals, played on the server logic. Drink at the water, gather
# fibre, twist twine, make the axe, fell a tree, make and light a fire, build a lean-to and a workbench. Checks: each goal completes when its check is met, its reward
# is given (coins or items), a goal done early waits for its `after` and completes the moment it opens, the player is told "Goal done" and the next hint, the done goals
# are saved with the character and still done after a restart, and goals_state lists locked / open / done.
#   godot --headless --path . --script res://src/worldgen/tools/test_goals.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String, standing: Dictionary, near_water: Array):
	DirAccess.make_dir_recursive_absolute(dir)
	var it = ItemsScript.new()
	it.send_full = func(_p, _b): pass
	it.send_slots = func(_p, _b): pass
	it.send_world_items = func(_p, _a, _r): pass
	it.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	it.send_notice = func(_p, t): said.append(str(t))
	it.send_purse = func(_p, _c): pass
	it.ground_height = func(_x, _z): return 10.0
	it.tree_info = func(_chunk, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.1} if standing.has(id) else {}
	it.cut_tree = func(_chunk, id): standing.erase(id); return true
	it.water_near = func(_pos, _reach): return near_water[0]
	it.setup(ItemTableScript.load_default(), dir)
	it._vitals_cfg["thirst"]["drink_pace_ms"] = 0
	return it


func count(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func done(id: String) -> bool:
	return items._goal_state_of(1)["goals_done"].has(id)


func craft(recipe_id: String, n: int) -> void:
	var number: int = -1

	for k in items.recipes.numbers():
		if str(items.recipes.recipe(int(k)).get("id", "")) == recipe_id:
			number = int(k)

	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, number, 0, n, Vector3.ZERO)

	for s in range(150):
		items.tick(1.0)


func _init() -> void:
	var dir: String = "user://test_goals"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var standing: Dictionary = {7: true}
	var near_water: Array = [false]
	items = make(dir, standing, near_water)
	items.peer_connected_hello(1, "goals0000001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 2000.0
	items._admin_mode_off[1] = true
	items.admin_mode_on = func(_p): return false
	var rows: Array = items.goals_state(1)
	check(rows.size() >= 10 and rows[0][3] == 1 and rows.any(func(r): return r[0] == "axe" and r[3] == 0), "goals_state lists the goals: the first open, the axe locked (%d goals)" % rows.size())

	# Drink: needs the water and a drop in thirst room.
	items.vitals_of(1)["wet"] = 1000.0
	near_water[0] = true
	items.action(1, Net.ACT_DRINK, 0, 0, 0, Vector3.ZERO)
	check(done("drink") and items.coins_of(1) >= 2, "drinking at the water completes the first goal and pays 2 copper (%d)" % items.coins_of(1))
	check(said.any(func(t): return t.begins_with("Goal done: ")), "the player is told: %s" % str(said.filter(func(t): return t.begins_with("Goal done")).slice(0, 1)))

	# Twine made before fibre was held: twine waits for "fibre" (after), then completes as soon as it opens.
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("plant_fibre"), 0, 40, Vector3.ZERO)
	items._goals_tick()
	check(done("fibre") and not done("twine"), "12 plant fibre in the pack completes the fibre goal; twine is not done yet")
	var sticks_before: int = count("stick")
	craft("twine", 2)
	check(done("twine") and count("stick") >= sticks_before + 4, "two crafts of twine complete the twine goal and give 4 sticks (reward)")
	check(said.any(func(t): return t.begins_with("Next: ")), "and the next goal's hint is said")

	# Axe, then fell a tree.
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone"), 0, 6, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 20, Vector3.ZERO)
	craft("twine", 3)
	craft("stone_axe", 1)
	check(done("axe"), "making the stone axe completes the axe goal")
	items.action(1, Net.ACT_MOVE, items.inventory_of(1).numbers.find(items.table.number_of("stone_axe")), 0, 0, Vector3.ZERO)
	items.report_position(1, Vector3(8.0, 10.0, 0.0))

	for n in range(200):
		if standing.is_empty():
			break

		items._last_hit.clear()
		items.action(1, Net.ACT_HIT, 7, 0, 0, Vector3.ZERO)

	check(standing.is_empty() and done("fell") and count("kindling") >= 3, "felling a tree completes the fell goal and gives kindling")

	# Fire: kit, place, light.
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	craft("campfire", 1)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("campfire_kit")), 0, 0, Vector3(2.0, 10.0, 0.0))
	check(not done("fire"), "a fire that is only placed does not complete the fire goal")

	for k in items._items:
		if items._items[k].has("fire"):
			items.action(1, Net.ACT_LIGHT, k, 0, 0, Vector3.ZERO)

	check(done("fire"), "lighting the fire completes the fire goal")

	# Shelter: a lean-to placed. Workbench: kit placed.
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("leaves"), 0, 8, Vector3.ZERO)
	craft("lean_to_kit", 1)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("lean_to_kit")), 0, 0, Vector3(-3.0, 10.0, 0.0))
	check(done("shelter"), "placing a lean-to completes the shelter goal")
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 14, Vector3.ZERO)
	craft("workbench_kit", 1)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("workbench_kit")), 0, 0, Vector3(0.0, 10.0, 5.0))
	check(done("workbench"), "placing a workbench completes the workbench goal")

	items._save_characters()
	items._finish_writer()
	var again = make(dir, {}, [false])
	again.peer_connected_hello(1, "goals0000001")
	check(again._goal_state_of(1)["goals_done"].has("drink") and again._goal_state_of(1)["goals_done"].has("workbench") and not again._goal_state_of(1)["goals_done"].has("bed"), "the done goals are saved with the character and still done after a restart")
	var states: Array = again.goals_state(1)
	check(states.any(func(r): return r[0] == "workbench" and r[3] == 2) and states.any(func(r): return r[0] == "bed" and r[3] == 1), "goals_state shows workbench done and the bed goal open")
	print("goals: %d failures" % failures)
	quit(1 if failures > 0 else 0)
