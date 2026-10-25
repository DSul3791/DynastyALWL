extends SceneTree

# Auto-make the missing part (Dave 25 Oct, Tyler's limits): pick the stone axe with fibre but no twine and the twine is queued first.
#   godot --headless --path . --script res://src/worldgen/tools/test_auto_craft.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const Planner := preload("res://src/shared/craft_planner.gd")

var failures: int = 0
var items
var table


class FakeRecipes extends RefCounted:
	var rows: Dictionary = {}

	func numbers() -> Array:
		var out: Array = rows.keys()
		out.sort()
		return out

	func recipe(number: int) -> Dictionary:
		return rows.get(number, {})


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var made = ItemsScript.new()
	made.send_full = func(_p, _b): pass
	made.send_slots = func(_p, _b): pass
	made.send_world_items = func(_p, _a, _r): pass
	made.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	made.ground_height = func(_x, _z): return 10.0
	made.setup(ItemTableScript.load_default(), dir)
	return made


func fresh(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var made = make(dir)
	made.peer_connected_hello(1, "autocraftkey1")
	made.report_position(1, Vector3(100.0, 10.0, 100.0))
	made.vitals_of(1)["weight"] = 120.0
	made._admin_mode_off[1] = true
	return made


func count(it, id: String) -> int:
	return it.inventory_of(1).count_of(it.table.number_of(id))


func give(it, id: String, n: int) -> void:
	it.inventory_of(1).add(it.table.number_of(id), n)


func queue(it, recipe: int, n: int) -> void:
	it._last_queue_act.clear()
	it.action(1, Net.ACT_CRAFT_QUEUE, recipe, 0, n, Vector3.ZERO)


func entries(it) -> Array:
	return it._craft_queues[it._peer_key[1]]["entries"]


func run(it, seconds: float) -> void:
	var t: float = 0.0

	while t < seconds:
		it._craft_tick(0.5)
		t += 0.5


func pack_totals(it) -> Dictionary:
	var out: Dictionary = {}

	for id in ["stone", "stick", "twine", "plant_fibre", "stone_axe"]:
		out[id] = count(it, id)

	return out


func _init() -> void:
	items = fresh("user://test_auto_craft")
	table = items.table
	give(items, "stone", 5)
	give(items, "stick", 5)
	give(items, "plant_fibre", 15)
	queue(items, 2, 1)
	var rows: Array = entries(items)
	check(rows.size() == 2 and int(rows[0][0]) == 1 and int(rows[0][1]) == 5 and int(rows[1][0]) == 2, "15 fibre, no twine: the queue is twine x5 then the stone axe (%s)" % str(rows.map(func(e): return [e[0], e[1]])))
	check(count(items, "plant_fibre") == 0 and count(items, "stone") == 4 and count(items, "stick") == 4, "the fibre, stone and stick are taken when it is queued")
	run(items, 40.0)
	check(count(items, "stone_axe") == 1 and count(items, "twine") == 0 and count(items, "plant_fibre") == 0 and entries(items).is_empty(), "the axe is made and no twine is left over (%s)" % str(pack_totals(items)))

	# 10 fibre is not enough for 5 twine
	items = fresh("user://test_auto_craft")
	give(items, "stone", 2)
	give(items, "stick", 2)
	give(items, "plant_fibre", 10)
	queue(items, 2, 1)
	check(entries(items).is_empty() and count(items, "plant_fibre") == 10, "10 fibre: nothing is queued and nothing is taken")

	# the parts you hold count: 2 twine held, 9 fibre makes the other 3
	items = fresh("user://test_auto_craft")
	give(items, "stone", 2)
	give(items, "stick", 2)
	give(items, "twine", 2)
	give(items, "plant_fibre", 9)
	queue(items, 2, 1)
	check(entries(items).size() == 2 and int(entries(items)[0][1]) == 3, "2 twine held: only 3 more are made")
	run(items, 30.0)
	check(count(items, "stone_axe") == 1 and count(items, "twine") == 0 and count(items, "plant_fibre") == 0, "the held twine and the new twine make the axe (%s)" % str(pack_totals(items)))

	# a plain craft with everything held is one entry, as before
	items = fresh("user://test_auto_craft")
	give(items, "stone", 2)
	give(items, "stick", 2)
	give(items, "twine", 5)
	queue(items, 2, 1)
	check(entries(items).size() == 1 and int(entries(items)[0][0]) == 2, "with the twine in hand it is a single craft")

	# cancel the twine: the axe goes with it and everything comes back exactly
	items = fresh("user://test_auto_craft")
	give(items, "stone", 5)
	give(items, "stick", 5)
	give(items, "plant_fibre", 15)
	var before: Dictionary = pack_totals(items)
	queue(items, 2, 1)
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(entries(items).is_empty() and pack_totals(items) == before, "cancelling the twine cancels the axe and refunds exactly (%s vs %s)" % [str(pack_totals(items)), str(before)])

	# cancel only the axe: the twine carries on
	queue(items, 2, 1)
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_CANCEL, 1, 0, 0, Vector3.ZERO)
	check(entries(items).size() == 1 and int(entries(items)[0][0]) == 1 and count(items, "stone") == 5 and count(items, "stick") == 5, "cancelling the axe leaves the twine queued and returns the stone and stick")
	run(items, 20.0)
	check(count(items, "twine") == 5 and count(items, "plant_fibre") == 0, "the twine is made and kept")

	# cancel after the twine is made and the axe has started: the twine used by the axe comes back too
	items = fresh("user://test_auto_craft")
	give(items, "stone", 5)
	give(items, "stick", 5)
	give(items, "plant_fibre", 15)
	before = pack_totals(items)
	queue(items, 2, 1)
	run(items, 11.0)   # five twine at 2 s each, then the axe has begun
	check(count(items, "twine") == 0 and entries(items).size() == 1 and (entries(items)[0][3] as Array).is_empty(), "the axe has started and taken its twine")
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(count(items, "twine") == 5 and count(items, "stone") == 5 and count(items, "stick") == 5, "cancelling a started axe returns the twine, stone and stick exactly")

	# the parts are gone when the step starts: dropped twine cancels the axe and refunds
	items = fresh("user://test_auto_craft")
	give(items, "stone", 5)
	give(items, "stick", 5)
	give(items, "plant_fibre", 15)
	queue(items, 2, 1)
	run(items, 9.0)
	items.inventory_of(1).remove(items.table.number_of("twine"), 3)
	run(items, 5.0)
	check(entries(items).is_empty() and count(items, "stone") == 5 and count(items, "stick") == 5 and count(items, "stone_axe") == 0, "twine taken away mid-queue: the axe is cancelled and its stone and stick come back")

	# too many at once: 20 axes would be 100 twine
	items = fresh("user://test_auto_craft")
	give(items, "stone", 30)
	give(items, "stick", 30)
	give(items, "plant_fibre", 400)
	queue(items, 2, 20)
	check(entries(items).is_empty() and count(items, "plant_fibre") == 400, "20 axes from fibre is over the 50 craft cap: nothing queued")
	queue(items, 2, 8)
	check(entries(items).size() == 2 and int(entries(items)[0][1]) == 40, "8 axes (40 twine + 8 axes = 48 crafts) are allowed")

	# carry limit: a light character cannot carry the made twine
	items = fresh("user://test_auto_craft")
	items.vitals_of(1)["weight"] = 0.5
	give(items, "stone", 1)
	give(items, "stick", 1)
	give(items, "plant_fibre", 15)
	queue(items, 2, 1)
	check(entries(items).is_empty() and count(items, "plant_fibre") == 15, "made parts that would not fit under the carry limit: nothing is queued (%d entries)" % entries(items).size())
	items.vitals_of(1)["weight"] = 120.0
	queue(items, 2, 1)
	check(entries(items).size() == 2, "the same craft queues for a character who can carry it")

	# save and reload in the middle of the queue: the queue comes back whole and finishes
	items = fresh("user://test_auto_craft")
	give(items, "stone", 5)
	give(items, "stick", 5)
	give(items, "plant_fibre", 15)
	queue(items, 2, 1)
	run(items, 5.0)
	items._dirty = true
	items.save()
	var shape: Array = entries(items).map(func(e): return [e[0], e[1], e[2], e[3], e[4]])
	var again = make("user://test_auto_craft")
	again.peer_connected_hello(1, "autocraftkey1")
	again.report_position(1, Vector3(100.0, 10.0, 100.0))
	again._admin_mode_off[1] = true
	var shape_after: Array = entries(again).map(func(e): return [e[0], e[1], e[2], e[3], e[4]])
	check(shape_after == shape, "the queue is the same after save and load (%s / %s)" % [str(shape), str(shape_after)])
	check(count(again, "plant_fibre") == 0 and count(again, "stone") == 4, "the taken ingredients are still taken after the load")
	run(again, 30.0)
	check(count(again, "stone_axe") == 1 and entries(again).is_empty(), "the reloaded queue finishes: the axe is made")

	# planner cases with made-up recipes: a loop, two ways to make a part, a part from a station you are away from, a long chain
	var a: int = table.number_of("stone")
	var b: int = table.number_of("stick")
	var c: int = table.number_of("twine")
	var d: int = table.number_of("plant_fibre")
	var fake = FakeRecipes.new()
	fake.rows[1] = {"number": 1, "name": "A", "needs": [[b, 1]], "keeps": [], "gives": [a, 1], "known": true, "station": ""}
	fake.rows[2] = {"number": 2, "name": "B", "needs": [[a, 1]], "keeps": [], "gives": [b, 1], "known": true, "station": ""}
	var ctx: Dictionary = {"have": func(_i): return 0, "station_ok": func(_r): return true, "free": false}
	var loop: Dictionary = Planner.plan(fake, table, 1, 1, ctx)
	check(not bool(loop["ok"]) and str(loop["msg"]).contains("circle"), "a recipe loop stops with a plain message (%s)" % str(loop["msg"]))

	fake.rows = {}
	fake.rows[1] = {"number": 1, "name": "Top", "needs": [[c, 1]], "keeps": [], "gives": [a, 1], "known": true, "station": ""}
	fake.rows[2] = {"number": 2, "name": "Twine one way", "needs": [[d, 1]], "keeps": [], "gives": [c, 1], "known": true, "station": ""}
	fake.rows[3] = {"number": 3, "name": "Twine another way", "needs": [[b, 1]], "keeps": [], "gives": [c, 1], "known": true, "station": ""}
	var amb: Dictionary = Planner.plan(fake, table, 1, 1, {"have": func(i): return 5 if i == d or i == b else 0, "station_ok": func(_r): return true, "free": false})
	check(not bool(amb["ok"]) and int(amb["ambiguous"]) == c and str(amb["msg"]).begins_with("Choose how to make"), "two ways to make a part: it asks, it does not guess (%s)" % str(amb["msg"]))

	fake.rows.erase(3)
	fake.rows[2]["station"] = "workbench"
	var away: Dictionary = Planner.plan(fake, table, 1, 1, {"have": func(i): return 5 if i == d else 0, "station_ok": func(_r): return false, "free": false})
	check(not bool(away["ok"]) and str(away["msg"]).contains("workbench"), "a part from a station you are away from is not planned (%s)" % str(away["msg"]))
	var near: Dictionary = Planner.plan(fake, table, 1, 1, {"have": func(i): return 5 if i == d else 0, "station_ok": func(_r): return true, "free": false})
	check(bool(near["ok"]) and (near["steps"] as Array).size() == 2, "the same part is planned when the station is near")

	fake.rows = {}
	fake.rows[1] = {"number": 1, "name": "L1", "needs": [[b, 1]], "keeps": [], "gives": [a, 1], "known": true, "station": ""}
	fake.rows[2] = {"number": 2, "name": "L2", "needs": [[c, 1]], "keeps": [], "gives": [b, 1], "known": true, "station": ""}
	fake.rows[3] = {"number": 3, "name": "L3", "needs": [[d, 1]], "keeps": [], "gives": [c, 1], "known": true, "station": ""}
	var chain3: Dictionary = Planner.plan(fake, table, 1, 1, {"have": func(i): return 5 if i == d else 0, "station_ok": func(_r): return true, "free": false})
	check(bool(chain3["ok"]) and (chain3["steps"] as Array).size() == 3, "a chain three deep is planned in order (%s)" % str((chain3["steps"] as Array).map(func(s): return s["recipe"])))

	fake.rows[4] = {"number": 4, "name": "kept", "needs": [[a, 1]], "keeps": [[d, 1]], "gives": [b, 1], "known": true, "station": ""}
	var tool_missing: Dictionary = Planner.plan(fake, table, 4, 1, {"have": func(i): return 5 if i == a else 0, "station_ok": func(_r): return true, "free": false})
	check(not bool(tool_missing["ok"]), "a missing kept tool is never made for you")

	print("auto craft tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
