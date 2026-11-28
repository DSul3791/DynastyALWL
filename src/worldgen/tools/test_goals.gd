extends SceneTree

# Starter goals (data/items/starter_goals.json, Sal; code by Tyler 31 Oct 2026): the real first-hour goals, played on the server logic. Drink at the water, gather
# fibre, twist twine, make the axe, fell a tree, make and light a fire, build a lean-to and a workbench. Checks: each goal completes when its check is met, it pays its
# stage's copper (coins only), a goal completes out of its authored order (`after` is no lock, GA-40), the player is told "Goal done" and the next goal, goal_done
# goes to the client once per completion with the copper paid, the done goals are saved with the character and still done after a restart, a rejoin sends the
# list silently and pays nothing again, the next tick saves (GA-55), and Admin mode and admin gives earn nothing (GA-54). Protocol 119. A goal row carries its
# amount and count, and goal_progress sends the counts of unfinished goals with an amount as they move (protocol 122, Dave 14 Nov 2026: "Gather plant fiber 0/50").
#   godot --headless --path . --script res://src/worldgen/tools/test_goals.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")   # the hand slot a craft holds its tool in (protocol 126)

var failures: int = 0
var items
var said: Array = []
var done_sent: Array = []   # [id, copper] per goal_done
var lists_sent: Array = []  # the rows of each goals message
var progress_sent: Array = []   # the changes of each goal_progress message


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
	it.send_goal_done = func(_p, id, copper): done_sent.append([id, copper])
	it.send_goals = func(_p, rows): lists_sent.append(rows)
	it.send_goal_progress = func(_p, changes): progress_sent.append(changes)
	it.ground_height = func(_x, _z): return 10.0
	it.tree_info = func(_chunk, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.3} if standing.has(id) else {}
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
	items.action(1, Net.ACT_CRAFT_QUEUE, number, 0, n, CraftHand.at(items, 1, number))

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
	items.admin_mode_on = func(_p): return false
	check(lists_sent.size() == 1 and (lists_sent[0] as Array).size() == items._goals_data().size(), "the join sends the whole goal list once (%d lists)" % lists_sent.size())
	var rows: Array = items.goals_rows(1)
	check(rows.size() >= 10 and rows[0][0] == "drink" and rows[0][3] == 5 and rows[0][7] == false and rows.all(func(r): return r.size() == 10 and r[7] == false), "goals_rows lists every goal in the authored order, drink first paying 5 copper (start stage), none done (%d goals)" % rows.size())
	var stages: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/goal_rewards.json")) as Dictionary).get("stages", {})
	var goal_list: Array = items._goals_data()
	var pays_stage: bool = rows.size() == goal_list.size()

	for i in rows.size():
		pays_stage = pays_stage and rows[i][0] == str(goal_list[i]["id"]) and rows[i][3] == int(stages.get(str(goal_list[i].get("stage", "")), -1))

	check(pays_stage and rows.all(func(r): return r[4] == "" and r[5] == 0) and rows.any(func(r): return r[0] == "axe" and r[6].has("twine") and r[2] != ""), "every live goal pays its stage's copper and no item (coins only, Dave 14 Nov; A-42; the metal path pays 10 to 20); a row carries its how-to and the goals taught before it")
	check(rows.any(func(r): return r[0] == "steel_tool" and r[3] == int(stages.get("steel", 0))), "the metal path's last goal pays the steel stage")
	check(not stages.is_empty() and items._goals_data().all(func(g): return stages.has(str(g.get("stage", ""))) and not g.has("reward")), "every goal names a stage from the one table in goal_rewards.json and carries no reward of its own")
	check(rows.any(func(r): return r[0] == "hoe") and rows.any(func(r): return r[0] == "path"), "the hoe and path goals are listed (Dave 4 Nov 2026)")
	var amounts: Dictionary = {}

	for r in rows:
		amounts[r[0]] = [r[8], r[9]]

	check(amounts.get("fibre") == [12, 0] and amounts.get("twine") == [2, 0] and amounts.get("path") == [15, 0] and amounts.get("axe") == [1, 0], "a row carries its amount and count so far: fibre 0 of 12, twine 0 of 2, path 0 of 15, the axe 0 of 1 (%s)" % str([amounts.get("fibre"), amounts.get("twine"), amounts.get("axe")]))
	check(amounts.get("night_walk") == [100, 0], "the night walk counts whole metres, 100 (%s)" % str(amounts.get("night_walk")))

	# Drink: needs the water and a drop in thirst room.
	items.vitals_of(1)["wet"] = 1000.0
	near_water[0] = true
	items.action(1, Net.ACT_DRINK, 0, 0, 0, Vector3.ZERO)
	check(done("drink") and items.coins_of(1) >= 5, "drinking at the water completes the first goal and pays 5 copper (%d)" % items.coins_of(1))
	check(said.any(func(t): return t.begins_with("Goal done: ")), "the player is told: %s" % str(said.filter(func(t): return t.begins_with("Goal done")).slice(0, 1)))
	check(said.any(func(t): return t.begins_with("Goal done: Drink") and t.contains("You earn 5 copper.")), "the goal's coins are named in its line, so they are not taken for a find (TEST-009): %s" % str(said.filter(func(t): return t.begins_with("Goal done")).slice(0, 1)))
	check(done_sent.size() == 1 and done_sent[0] == ["drink", 5], "goal_done goes to the client once, with the copper paid (%s)" % str(done_sent))
	check(items._save_in <= 0.0, "a completion saves on the next tick (GA-55)")
	var coins_drunk: int = items.coins_of(1)
	items.action(1, Net.ACT_DRINK, 0, 0, 0, Vector3.ZERO)
	items._goal_event(1, "drink")
	items._goals_check(1)
	check(items.coins_of(1) == coins_drunk and done_sent.size() == 1, "drinking again and a repeated check pay nothing and send nothing (%d copper, %d sent)" % [items.coins_of(1), done_sent.size()])
	# A sale and a filled order (server_trade.gd) are goal events too: their goals pay their own copper on top of the trade, once (the trade tests opt out of goals).
	items._goal_event(1, "sold")
	items._goal_event(1, "wanted_order")
	check(done("sell") and done("order") and items.coins_of(1) == coins_drunk + 10, "a sale and a filled order complete the sell and order goals out of order and pay 5 + 5 copper (%d)" % (items.coins_of(1) - coins_drunk))
	items._goal_event(1, "sold")
	check(items.coins_of(1) == coins_drunk + 10, "a second sale pays no goal again")

	# Admin-given fibre does not count (GA-54); twine made from it does, before the fibre goal it is taught after (out of order, GA-40).
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("plant_fibre"), 0, 40, Vector3.ZERO)
	items._goals_tick()
	check(not done("fibre"), "40 admin-given plant fibre do not complete the fibre goal")
	var sticks_before: int = count("stick")
	var coins_twine: int = items.coins_of(1)
	craft("twine", 2)
	check(done("twine") and not done("fibre") and count("stick") == sticks_before and items.coins_of(1) == coins_twine + 5, "two crafts of twine complete the twine goal before the fibre goal and pay 5 copper, no sticks (coins only)")
	check(said.any(func(t): return t.begins_with("Goal done: ") and t.contains(" Next: Gather plant fibre.")), "and the line names the first unfinished goal in the authored order")
	var got: Callable = func(id: String) -> int: return int(items._goal_state_of(1)["goal_counts"].get("got:" + id, 0))
	check(got.call("plant_fibre") == 0 and got.call("stick") == 0, "admin gives are not gathered (got: %d fibre, %d sticks)" % [got.call("plant_fibre"), got.call("stick")])
	items._gain_source = "trade"
	items.give(1, items.table.number_of("plant_fibre"), 5)   # as server_trade.gd gives a purchase
	items._gain_source = items.SRC_RETURN
	items.give(1, items.table.number_of("plant_fibre"), 5)   # as a refund or a taken-down site gives back
	items._gain_source = items.SRC_PICKUP
	items._goals_tick()
	check(got.call("plant_fibre") == 0 and not done("fibre"), "bought and handed-back fibre are not gathered either, though held (%d held)" % count("plant_fibre"))
	check(not progress_sent.any(func(c): return (c as Dictionary).has("fibre")), "admin-given, bought and handed-back fibre sent no fibre count (%s)" % str(progress_sent))
	progress_sent.clear()
	items.give(1, items.table.number_of("plant_fibre"), 11)   # as a harvest gives them
	check(got.call("plant_fibre") == 11 and not done("fibre"), "11 gathered first-hand: not yet")
	check(progress_sent.size() == 1 and progress_sent[0].get("fibre") == 11 and not progress_sent[0].has("axe"), "the gathering sends the fibre count that moved, 11, at once, and no single-item goal (%s)" % str(progress_sent))
	progress_sent.clear()
	items._goals_tick()
	check(progress_sent.is_empty(), "a check where nothing moved sends nothing (%s)" % str(progress_sent))
	items.give(1, items.table.number_of("plant_fibre"), 1)
	items._goals_tick()
	check(got.call("plant_fibre") == 12 and done("fibre"), "the 12th gathered plant fibre completes the fibre goal: history, not what is held (got_item)")
	# On the ground: natural scatter is found and counts; a stick someone dropped does not (it could be the player's own, picked up again).
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var stick_n: int = items.table.number_of("stick")

	for k in items._items.keys():   # no other sticks or scatter near the two test sticks (a batch pickup sweeps nearby heaps of the same item)
		if (items._items[k].has("scatter") or int(items._items[k].get("number", 0)) == stick_n) and (items._items[k]["pos"] as Vector3).distance_to(Vector3(0.0, 10.0, 0.0)) < 8.0:
			items._items.erase(k)

	var dropped_id: int = items._next_id
	items._items[dropped_id] = {"number": stick_n, "count": 1, "pos": Vector3(-1.5, 10.0, 0.0), "left": 1.0e9}
	items._next_id += 1
	var scatter_id: int = items._next_id
	items._items[scatter_id] = {"number": stick_n, "count": 1, "pos": Vector3(1.5, 10.0, 0.0), "left": 1.0e9, "scatter": 987654321}
	items._next_id += 1
	var sticks_got: int = got.call("stick")
	var sticks_held: int = count("stick")
	items.action(1, Net.ACT_PICKUP, dropped_id, 0, 0, Vector3.ZERO)
	check(count("stick") == sticks_held + 1 and got.call("stick") == sticks_got, "a dropped stick picked up is held but not counted as gathered")
	items.action(1, Net.ACT_PICKUP, scatter_id, 0, 0, Vector3.ZERO)
	check(count("stick") == sticks_held + 2 and got.call("stick") == sticks_got + 1, "a natural scatter stick picked up is counted as gathered (%d)" % (got.call("stick") - sticks_got))
	var live: Dictionary = {}

	for goal in items._goals_data():
		live[str(goal["id"])] = goal["check"]

	# Dave 14 Nov 2026: "the first goal should always be the first goal a play can do next. the second one will be what should be next". The Goals box and the
	# "Next:" line show the first goal not done and the one after it in the authored order; that first goal is always one the player can do because every
	# goal a goal follows (`after`) comes before it in the order, so it is done by then. This keeps that true for every goal added later.
	var earlier: Dictionary = {}
	var late: Array = []

	for goal in items._goals_data():
		for a in goal.get("after", []):
			if not earlier.has(str(a)):
				late.append("%s after %s" % [str(goal["id"]), str(a)])

		earlier[str(goal["id"])] = true

	check(late.is_empty(), "every goal comes after the goals it follows, so the first goal not done is one the player can do next (%s)" % str(late))

	check(str(live["fish"].get("event", "")) == "fish_caught" and int(live["fish"].get("count", 0)) == 1 and not live["fish"].has("have_item_any") and not live["fish"].has("or_event")
		and str(live["workbench"].get("what", "")) == "workbench" and not live["workbench"].has("what_any"), "the fish goal counts only a catch and the workbench goal only the workbench (corrected catalog, GA-47)")
	check((live["hammer"].get("made_item_any", []) as Array).has("stone_hammer") and not (live["hammer"].get("made_item_any", []) as Array).has("wooden_hammer") and (live["hoe"].get("made_item_all", []) as Array).has("wooden_hoe") and not JSON.stringify(live).contains("wooden_hammer_soft"), "the hammer goal counts a made Stone - Hammer (the Wooden one retired 18 Nov 2026) and the hoe goal a Wooden - Hoe; no wooden_hammer_soft item is named")

	# Axe, then fell a tree.
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone"), 0, 19, Vector3.ZERO)   # axe 1 and campfire 16 (Dave 20 Nov 2026: "campfire 16 stones"), 2 to spare as before
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 20, Vector3.ZERO)
	craft("twine", 3)
	craft("stone_axe", 1)
	check(done("axe"), "making the stone axe completes the axe goal")
	items.action(1, Net.ACT_MOVE, items.inventory_of(1).numbers.find(items.table.number_of("stone_axe")), 0, 0, Vector3.ZERO)
	items.report_position(1, Vector3(8.0, 10.0, 0.0))
	var log_n: int = items._log_number("oak")
	var ground_logs: Callable = func() -> int:
		var total: int = 0

		for k in items._items:
			if int(items._items[k].get("number", 0)) == log_n and not items._items[k].has("tree"):
				total += int(items._items[k]["count"])

		return total

	# What lies on the ground per item (not trees or natural scatter), and the feller's got: counts, to compare what a fall lays with what it credits.
	var ground: Callable = func() -> Dictionary:
		var totals: Dictionary = {}

		for k in items._items:
			var rec: Dictionary = items._items[k]

			if int(rec.get("number", 0)) > 0 and not rec.has("tree") and not rec.has("scatter"):
				totals[int(rec["number"])] = int(totals.get(int(rec["number"]), 0)) + int(rec["count"])

		return totals

	var got_all: Callable = func() -> Dictionary:
		var counts: Dictionary = {}

		for key in items._goal_state_of(1)["goal_counts"]:
			if str(key).begins_with("got:"):
				counts[items.table.number_of(str(key).substr(4))] = int(items._goal_state_of(1)["goal_counts"][key])

		return counts

	# Every item a fall lays on the ground is credited to the feller, item by item and once (Dave 14 Nov: "gathering counts when you ... cut it down").
	var laid_matches: Callable = func(ground_before: Dictionary, got_before: Dictionary) -> String:
		var ground_now: Dictionary = ground.call()
		var got_now: Dictionary = got_all.call()
		var bad: Array = []

		var numbers: Dictionary = ground_now.duplicate()
		numbers.merge(got_now)

		for number in numbers:
			var laid_n: int = int(ground_now.get(number, 0)) - int(ground_before.get(number, 0))
			var got_n: int = int(got_now.get(number, 0)) - int(got_before.get(number, 0))

			if laid_n != got_n:
				bad.append("%s laid %d got %d" % [items.table.id_of(int(number)), laid_n, got_n])

		return ", ".join(bad)

	var kindling_fell: int = count("kindling")
	var fell_lines: int = said.size()
	var logs_before: int = ground_logs.call()
	var logs_got: int = got.call(items.table.id_of(log_n))
	var ground_was: Dictionary = ground.call()
	var got_was: Dictionary = got_all.call()

	for n in range(200):
		if standing.is_empty():
			break

		items._last_hit.clear()
		items.action(1, Net.ACT_HIT, 7, 0, 0, HeldTool.at_axe(items))

	check(standing.is_empty() and done("fell") and count("kindling") == kindling_fell and said.slice(fell_lines).any(func(t): return t.begins_with("Goal done: Fell a tree") and t.contains("You earn 5 copper.")), "felling a tree completes the fell goal and pays 5 copper, no kindling (coins only)")
	# QA #9 (Dave 25 Nov 2026, a bear): the hunt goal's done line names the animal really worked, not a rabbit.
	var hunt_lines: int = said.size()
	var hunt_was_done: bool = done("hunt")
	items._goal_what[1] = "black bear"
	items._goal_event(1, "carcass_worked")
	check(hunt_was_done or (done("hunt") and said.slice(hunt_lines).any(func(t): return t.begins_with("Goal done: You worked a black bear with your knife."))), "working a bear completes the hunt goal and its line names the bear (%s)" % str(said.slice(hunt_lines).slice(0, 1)))
	# What a felled tree breaks into as it falls is its feller's gathering, once; the record clients get does not name the feller.
	var stump_id: int = -1

	for k in items._items:
		if items._items[k].has("tree") and int(items._items[k]["tree"]["state"]) == 4:
			stump_id = int(k)

	check(stump_id >= 0 and not JSON.stringify(items._items[stump_id]["tree"]).contains("goals0000001"), "the stump's record does not name the feller")
	var laid: int = ground_logs.call() - logs_before
	check(laid > 0 and got.call(items.table.id_of(log_n)) == logs_got + laid, "the tree comes down in %d logs and the feller has gathered them (%d)" % [laid, got.call(items.table.id_of(log_n)) - logs_got])
	var mismatch: String = laid_matches.call(ground_was, got_was)
	var others_got: int = 0

	for number in got_all.call():
		if int(number) != log_n:
			others_got += int(got_all.call()[number]) - int(got_was.get(number, 0))

	check(mismatch == "" and others_got > 0, "the crown's sticks and leaves and the trunk's bark, seeds and roots it lays are the feller's gathering too (%s)" % mismatch)
	var got_after: Dictionary = got_all.call()

	for n in range(8):
		items.tick(0.25)   # the fall lands

	check(got_all.call().hash() == got_after.hash(), "landing credits nothing more: it is credited once")
	# A small tree breaks up into firewood, kindling and sticks: those are the feller's gathering as well.
	ground_was = ground.call()
	got_was = got_all.call()
	items._fell_record(Vector2i(0, 0), {"name": "oak", "position": Vector3(40.0, 10.0, 0.0), "height": 4.0, "trunk": 0.1}, Vector2(1.0, 0.0), "goals0000001")
	mismatch = laid_matches.call(ground_was, got_was)
	check(mismatch == "" and got_all.call().hash() != got_was.hash() and int(got_all.call().get(items.table.number_of("firewood"), 0)) > int(got_was.get(items.table.number_of("firewood"), 0)), "a small tree's firewood, kindling and sticks are its feller's gathering (%s)" % mismatch)

	# Fire: kit, place, light.
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	craft("campfire", 1)
	items.place_item(1, items.table.number_of("campfire_kit"), Vector3(2.0, 10.0, 0.0), 0)
	check(not done("fire"), "a fire that is only placed does not complete the fire goal")

	for k in items._items:
		if items._items[k].has("fire"):
			items.action(1, Net.ACT_LIGHT, k, 0, 0, Vector3.ZERO)

	check(done("fire"), "lighting the fire completes the fire goal")

	# Shelter and workbench come after the hammer goal: a wooden hammer in the pack, then a lean-to and a bench placed.
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone_hammer"), 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("leaves"), 0, 12, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 32, Vector3.ZERO)   # the lean-to costs 16 sticks, 4 leaves, 2 twine (lighter 3 Nov; was 32/8/4)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("twine"), 0, 4, Vector3.ZERO)
	items.place_piece(1, "lean_to_kit", Vector3(-3.0, 10.0, 0.0))
	check(done("shelter"), "placing a lean-to completes the shelter goal")
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 24, Vector3.ZERO)   # the workbench now costs 20 sticks, 6 twine and 8 stones (0.5 kg each, Dave 19 Nov 2026)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("twine"), 0, 6, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone"), 0, 8, Vector3.ZERO)
	items.place_piece(1, "workbench_kit", Vector3(0.0, 10.0, 5.0))
	check(done("workbench"), "placing a workbench completes the workbench goal")

	items._save_characters()
	items._finish_writer()
	var again = make(dir, {}, [false])
	again.peer_connected_hello(1, "goals0000001")
	check(again._goal_state_of(1)["goals_done"].has("drink") and again._goal_state_of(1)["goals_done"].has("workbench") and not again._goal_state_of(1)["goals_done"].has("bed"), "the done goals are saved with the character and still done after a restart")
	var states: Array = again.goals_rows(1)
	check(states.any(func(r): return r[0] == "workbench" and r[7] == true) and states.any(func(r): return r[0] == "bed" and r[7] == false), "goals_rows shows workbench done and the bed goal not done")
	var sent_before: int = done_sent.size()
	var coins_saved: int = again.coins_of(1)
	again._goals_check(1)
	check(lists_sent.size() >= 2 and (lists_sent[-1] as Array).any(func(r): return r[0] == "workbench" and r[7] == true), "the rejoin sends the list with the done goals marked")
	check(done_sent.size() == sent_before and again.coins_of(1) == coins_saved, "the rejoin and a fresh check send no goal_done and pay nothing again (%d copper)" % coins_saved)
	var sent_ids: Dictionary = {}

	for row in done_sent:
		sent_ids[row[0]] = int(sent_ids.get(row[0], 0)) + 1

	check(sent_ids.size() == done_sent.size() and sent_ids.size() == items._goal_state_of(1)["goals_done"].size(), "each done goal was announced exactly once (%s)" % str(sent_ids))
	# Admin mode: nothing counts, nothing completes, and turning it off does not complete what was done in it (GA-54).
	var admin = make("user://test_goals_admin", {}, [true])
	admin.admin_ok = func(_p): return true
	var admin_on: Array = [true]
	admin.admin_mode_on = func(_p): return admin_on[0]
	admin.peer_connected_hello(1, "goalsadmin001")
	admin.report_position(1, Vector3(0.0, 10.0, 0.0))
	admin.vitals_of(1)["weight"] = 2000.0
	admin.vitals_of(1)["wet"] = 1000.0
	admin._goal_event(1, "drink")
	admin._goal_made(1, admin.table.number_of("twine"), 3)
	admin._goals_check(1)
	check(admin._goal_state_of(1)["goals_done"].is_empty() and int(admin._goal_state_of(1)["goal_counts"].get("event:drink", 0)) == 0, "in Admin mode a drink and a craft count nothing")
	admin_on[0] = false
	admin._goals_check(1)
	check(admin._goal_state_of(1)["goals_done"].is_empty(), "turning Admin mode off completes nothing done in it")
	admin._goal_made(1, admin.table.number_of("twine"), 2)
	check(admin._goal_state_of(1)["goals_done"].has("twine"), "a sealed batch of two crafts counts as two (the twine goal needs 2)")
	# A free craft's product in the pack, a talk and a night walk in Admin mode earn nothing after it is switched off (GA-54).
	var hoe: int = admin.table.number_of("wooden_hoe")
	var hoe_recipe: int = -1

	for k in admin.recipes.numbers():
		if int(admin.recipes.recipe(int(k)).get("gives", [0])[0]) == hoe:
			hoe_recipe = int(k)

	admin_on[0] = true
	admin._last_queue_act.clear()
	admin.action(1, Net.ACT_CRAFT_QUEUE, hoe_recipe, 0, 1, CraftHand.at(admin, 1, hoe_recipe))

	for s in range(60):
		admin.tick(1.0)

	admin.game_seconds = func(): return 21.0 * 3600.0
	admin.note_talked(1, "edda")
	admin.give(1, admin.table.number_of("torch"), 1)

	for n in range(12):
		admin.report_position(1, Vector3(float(n + 1) * 10.0, 10.0, 0.0))
		admin._night_walk_tick()

	admin_on[0] = false
	admin._goals_check(1)
	var gone: Dictionary = admin._goal_state_of(1)
	check(hoe_recipe >= 0 and admin.count_for(1, "wooden_hoe") == 1, "Admin mode crafted a Wooden - Hoe for free (recipe %d)" % hoe_recipe)
	check(not gone["goals_done"].has("hoe") and not gone["goals_done"].has("story") and float(gone["goal_counts"].get("moved_lit_night", 0.0)) == 0.0, "and neither the free hoe, a talk at 21:00 nor a night walk in Admin mode counts once it is off (%s)" % str(gone["goals_done"].keys()))
	# Hints: said once when their trigger holds, saved with the character, never repeated (the client's OK box, R-HUD-HINT-BOX).
	said.clear()
	var hinter = make("user://test_goals_hints", {}, [false])
	hinter.hint_every = 1   # every goals tick looks at the hints (the game looks every 4th slow tick)
	hinter.peer_connected_hello(1, "hintsplayer01")
	hinter.report_position(1, Vector3(0.0, 10.0, 0.0))
	hinter.vitals_of(1)["weight"] = 2000.0
	hinter._goals_tick()
	check(said.has("Walk with W A S D. Hold Shift to run."), "the first hint is said at once (%s)" % str(said))
	var count_before: int = said.size()
	hinter._goals_tick()
	check(said.size() == count_before or said[-1] != "Walk with W A S D. Hold Shift to run.", "and not said twice")
	hinter.report_position(1, Vector3(6.0, 10.0, 0.0))

	for n in range(3):
		hinter._goals_tick()

	check(said.has("Press Tab to see Health, Food, Water, Temperature and Energy."), "moving 5 m brings the next hint (%s)" % str(said.slice(-2)))
	check(not hinter._hint_trigger_true(1, hinter._goal_state_of(1), "walked_far"), "6 m from the start is not far enough for the map hint")
	hinter.report_position(1, Vector3(151.0, 10.0, 0.0))
	check(hinter._hint_trigger_true(1, hinter._goal_state_of(1), "walked_far"), "151 m from the start brings the map hint's trigger")
	hinter.report_position(1, Vector3(6.0, 10.0, 0.0))
	hinter.action(1, Net.ACT_ADMIN_GIVE, hinter.table.number_of("stick"), 0, 9, Vector3.ZERO)

	for n in range(4):
		hinter._goals_tick()

	check(said.has("Press E on nettles or tall grass to get plant fibre."), "nine sticks in the pack bring the fibre hint")
	var seen: Dictionary = hinter._goal_state_of(1)["hints_seen"]
	check(seen.has("move") and seen.has("bars") and seen.has("fibre"), "the said hints are saved with the character (%s)" % str(seen.keys()))
	seen["fibre"] = float(seen["fibre"]) - 600.0   # said 10 minutes ago, its goal still open
	var fibre_said: int = said.count("Press E on nettles or tall grass to get plant fibre.")

	for n in range(4):
		hinter._goals_tick()

	check(said.count("Press E on nettles or tall grass to get plant fibre.") == fibre_said, "a hint whose goal is still open is not said again later")
	# Camp goals: worn_warmth, talked (npc and hours), moved_lit_night (metres), through the same machinery.
	var camp = make("user://test_goals_camp", {}, [false])
	camp.game_seconds = func(): return 21.0 * 3600.0   # 21:00
	camp.peer_connected_hello(1, "campgoals0001")
	camp.report_position(1, Vector3(0.0, 10.0, 0.0))
	camp.vitals_of(1)["weight"] = 2000.0
	var camp_state: Dictionary = camp._goal_state_of(1)
	for id in ["fire", "knife", "torch_night"]:
		camp_state["goals_done"][id] = true

	check(not camp._goal_met(1, camp_state, {"event": "worn_warmth", "min": 0.7}, "fur_for_winter"), "bare: not warm enough")
	camp._characters[camp._peer_key[1]]["worn"] = [camp.table.number_of("hide_hood"), camp.table.number_of("hide_cloak"), camp.table.number_of("hide_boots"), 0, 0, 0]
	check(absf(camp._worn_warmth(1) - 0.55) < 0.01, "hood, cloak and boots add up to %.2f warmth" % camp._worn_warmth(1))
	camp.note_talked(1, "hob")
	check(not camp._goal_state_of(1)["goals_done"].has("story"), "talking to someone else does not count for the story goal")
	camp.note_talked(1, "edda")
	check(camp._goal_state_of(1)["goals_done"].has("story"), "talking to Edda at 21:00 completes the story goal")
	var other = make("user://test_goals_camp2", {}, [false])
	other.game_seconds = func(): return 12.0 * 3600.0
	other.peer_connected_hello(1, "campgoals0002")
	other.report_position(1, Vector3(0.0, 10.0, 0.0))
	other._goal_state_of(1)["goals_done"]["fire"] = true
	other.note_talked(1, "edda")
	check(not other._goal_state_of(1)["goals_done"].has("story"), "at noon the same talk does not count")

	# A night walk with a torch in the pack: 100 m.
	camp.give(1, camp.table.number_of("torch"), 1)   # a crafted or bought torch (an admin-given one lights no goal)
	camp._night_walk_tick()

	for n in range(12):
		camp.report_position(1, Vector3(float(n + 1) * 10.0, 10.0, 0.0))
		camp._night_walk_tick()

	check(float(camp._goal_state_of(1)["goal_counts"].get("moved_lit_night", 0.0)) >= 110.0, "walking 120 m with a torch at night adds up (%.0f m)" % float(camp._goal_state_of(1)["goal_counts"].get("moved_lit_night", 0.0)))
	camp._goals_check(1)
	check(camp._goal_state_of(1)["goals_done"].has("night_walk"), "and completes the night walk goal")
	# Sal's tutorial steps 23 and 24: the plant-food-at-the-fire hint and the placed-pot hint.
	var pot_state: Dictionary = camp._goal_state_of(1)
	camp.report_position(1, Vector3(0.0, 10.0, 0.0))
	check(not camp._hint_trigger_true(1, pot_state, "has_plant_food_at_fire"), "no plant food hint without a fire or ingredients")
	camp.action(1, Net.ACT_ADMIN_GIVE, camp.table.number_of("blueberries"), 0, 2, Vector3.ZERO)
	camp.action(1, Net.ACT_ADMIN_GIVE, camp.table.number_of("honeyspindle_nectar"), 0, 1, Vector3.ZERO)
	check(not camp._hint_trigger_true(1, pot_state, "has_plant_food_at_fire"), "ingredients but no lit fire: no hint")
	var pot_fire: int = camp._next_id
	camp._items[pot_fire] = {"number": 0, "count": 1, "pos": Vector3(2.0, 10.0, 0.0), "left": 1.0e9, "fire": {"state": 1, "burn_left": 1000.0}}
	camp._next_id += 1
	check(camp._hint_trigger_true(1, pot_state, "has_plant_food_at_fire"), "berries and nectar beside a lit fire: the hint triggers")
	check(not camp._hint_trigger_true(1, pot_state, "campfire_pot_placed"), "no pot placed yet")
	camp._goal_event(1, "placed", "campfire_pot")
	check(camp._hint_trigger_true(1, pot_state, "campfire_pot_placed"), "placing a campfire pot triggers its hint")
	var pot_id: int = camp._next_id
	camp._items[pot_id] = {"number": 0, "count": 1, "pos": Vector3(2.0, 10.0, 0.5), "left": 1.0e9, "struct": {"kind": "campfire_pot", "yaw": 0.0}}
	camp._next_id += 1
	check(not camp._hint_trigger_true(1, pot_state, "has_plant_food_at_fire"), "once a pot stands at the fire the plant food hint stops")
	# Hint triggers that used to match nothing (3 Nov 2026): the sea water ones (the fell hint is Sal's #245).
	check(not camp._hint_trigger_true(1, camp._goal_state_of(1), "wall_placed"), "no wall built: no roof panel hint")
	camp._goal_event(1, "placed", "thatch_wall")
	check(camp._hint_trigger_true(1, camp._goal_state_of(1), "wall_placed"), "a Crude - Wall standing brings the roof panel hint (GA-18)")
	check(not camp._hint_trigger_true(1, pot_state, "has_sea_water"), "no sea water in the pack: no hint")
	camp.action(1, Net.ACT_ADMIN_GIVE, camp.table.number_of("sea_water"), 0, 1, Vector3.ZERO)
	check(camp._hint_trigger_true(1, pot_state, "has_sea_water"), "sea water in the pack triggers its hint")
	var bench_check := {"event": "placed", "what_any": ["workbench", "log_workbench"], "count": 1}
	check(not camp._goal_met(1, pot_state, bench_check, "workbench"), "no bench placed: the workbench goal is open")
	camp._goal_event(1, "placed", "log_workbench")
	check(camp._goal_met(1, camp._goal_state_of(1), bench_check, "workbench"), "a log workbench also completes the workbench goal (Dino round 6)")
	check(camp._hint_trigger_true(1, camp._goal_state_of(1), "workbench_placed"), "a log workbench fires the workbench_placed hints")
	check(not camp._hint_trigger_true(1, pot_state, "has_campfire_kit"), "no fire kit in the pack: no place-fire reminder")
	var fish_check := {"have_item_any": ["trout", "perch"], "or_event": "fish_caught", "count": 1}
	check(not camp._goal_met(1, camp._goal_state_of(1), fish_check, "fish"), "no fish caught or held: the fish goal is open")
	camp._goal_event(1, "fish_caught")
	check(camp._goal_met(1, camp._goal_state_of(1), fish_check, "fish"), "a caught fish completes the fish goal even when it is gone from the pack")
	var axe_check := {"made_item": "stone_axe", "or_have": true, "count": 1}
	camp.trees_near = func(_p, _r): return []
	check(not camp._hint_trigger_true(1, camp._goal_state_of(1), "axe_held_near_tree"), "no tree near: no fell hint")
	var bought_before: bool = camp._goal_met(1, camp._goal_state_of(1), axe_check, "axe")
	camp.action(1, Net.ACT_ADMIN_GIVE, camp.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	check(not camp._goal_met(1, camp._goal_state_of(1), axe_check, "axe"), "an admin-given stone axe does not complete the axe goal")
	camp.give(1, camp.table.number_of("stone_axe"), 1)   # as Hob's sale gives it
	check(camp._goal_met(1, camp._goal_state_of(1), axe_check, "axe"), "a bought stone axe in the pack completes the axe goal (was %s before)" % str(bought_before))
	# made_item_any (chop_log_blocks, GAP-GUIDE-ANY): crafts of any of the listed items add up (the wooden block and the firewood it splits into); blocks only held, admin-given, count nothing.
	var blocks_check := {"made_item_any": ["wooden_block", "firewood"], "count": 2}
	check(not camp._goal_met(1, camp._goal_state_of(1), blocks_check, "chop_log_blocks"), "no block made: the blocks goal is open")
	camp.action(1, Net.ACT_ADMIN_GIVE, camp.table.number_of("wooden_block"), 0, 3, Vector3.ZERO)
	check(not camp._goal_met(1, camp._goal_state_of(1), blocks_check, "chop_log_blocks"), "three admin-given blocks in the pack do not complete it")
	camp._goal_made(1, camp.table.number_of("wooden_block"))
	check(not camp._goal_met(1, camp._goal_state_of(1), blocks_check, "chop_log_blocks"), "one block made: still open (count 2)")
	camp._goal_made(1, camp.table.number_of("firewood"))
	check(camp._goal_met(1, camp._goal_state_of(1), blocks_check, "chop_log_blocks"), "a block and a firewood made: met")
	# made_item_all (Dave 25 Nov 2026, a tier's tool set): one of each id, the same one twice is still one; admin-given ones count nothing.
	var set_check := {"made_item_all": ["stone_pickaxe", "stone_saw"], "or_have": true}
	var set_state: Dictionary = camp._goal_state_of(1)
	camp.action(1, Net.ACT_ADMIN_GIVE, camp.table.number_of("stone_saw"), 0, 1, Vector3.ZERO)
	check(camp._goal_progress(1, set_state, set_check) == Vector2i(0, 2), "an admin-given saw: the set is 0 of 2 (%s)" % str(camp._goal_progress(1, set_state, set_check)))
	camp._goal_made(1, camp.table.number_of("stone_pickaxe"))
	camp._goal_made(1, camp.table.number_of("stone_pickaxe"))
	check(camp._goal_progress(1, set_state, set_check) == Vector2i(1, 2) and not camp._goal_met(1, set_state, set_check, "stone_tools"), "two pickaxes made: the set is 1 of 2, still open")
	camp._goal_made(1, camp.table.number_of("stone_saw"))
	check(camp._goal_met(1, set_state, set_check, "stone_tools"), "a pickaxe and a saw made: the set is met")
	# The spread's once-a-second look (_goals_poll, coordinator 25 Nov 2026): a have goal completes through it, admin-given units do not count, and
	# a look with nothing moved since the last is skipped.
	var poll_state: Dictionary = camp._goal_state_of(1)
	poll_state["goals_done"].erase("charcoal")
	camp._goal_poll_sig.erase(1)
	camp.action(1, Net.ACT_ADMIN_GIVE, camp.table.number_of("charcoal"), 0, 4, Vector3.ZERO)
	camp._goals_poll(1)
	check(not poll_state["goals_done"].has("charcoal") or camp._goals_paused(1), "4 admin-given charcoal: the poll leaves the charcoal goal open")
	var sig_was: int = int(camp._goal_poll_sig.get(1, 0))
	camp._goals_poll(1)
	check(int(camp._goal_poll_sig.get(1, 0)) == sig_was, "nothing moved: the next look keeps the same signature (skipped)")
	camp.inventory_of(1).add(camp.table.number_of("charcoal"), 4)
	camp._goals_poll(1)
	check(poll_state["goals_done"].has("charcoal") or camp._goals_paused(1), "4 more charcoal of its own: the poll completes the charcoal goal")
	camp.trees_near = func(_p, _r): return [[Vector2i.ZERO, 1]]
	check(camp._tool_slot(camp.inventory_of(1), "axe") < 0 or camp._hint_trigger_true(1, camp._goal_state_of(1), "axe_held_near_tree"), "an axe on the hotbar beside a tree fires the fell hint")
	camp.action(1, Net.ACT_ADMIN_GIVE, camp.table.number_of("campfire_kit"), 0, 1, Vector3.ZERO)
	check(camp._hint_trigger_true(1, pot_state, "has_campfire_kit"), "a fire kit in the pack triggers the place-fire reminder")
	check(not camp._hint_trigger_true(1, pot_state, "near_nettle") or camp.count_for(1, "nettles") > 0, "near_nettle needs nettles in the pack")
	# The seasonal, fruit and dig hints (hints.json: fruit_spoil, fruit_pick, orchard, season_change, winter_store, cave_in) judge their triggers now.
	var hint_state: Dictionary = camp._goal_state_of(1)
	check(not camp._hint_trigger_true(1, hint_state, "fruit_in_pack"), "no fruit in the pack: no fruit hint")
	camp.action(1, Net.ACT_ADMIN_GIVE, camp.table.number_of("plums"), 0, 1, Vector3.ZERO)
	check(camp._hint_trigger_true(1, hint_state, "fruit_in_pack"), "a plum in the pack fires the fruit hint")
	var stamp: Array = [10]
	camp.season_stamp = func(): return stamp[0]
	check(not camp._hint_trigger_true(1, hint_state, "season_changes"), "the first look only records the season")
	check(not camp._hint_trigger_true(1, hint_state, "season_changes"), "the same season: no season hint")
	stamp[0] = 11
	check(camp._hint_trigger_true(1, hint_state, "season_changes"), "a new season fires the season hint")
	check(not camp._hint_trigger_true(1, hint_state, "digging_under_ceiling"), "no deep dig yet: no cave-in hint")
	camp._goal_event(1, "dug_under")
	check(camp._hint_trigger_true(1, hint_state, "digging_under_ceiling"), "a deep dig fires the cave-in hint")
	camp.trees_near = func(_p, _r): return []
	check(not camp._hint_trigger_true(1, hint_state, "near_orchard"), "no trees: no orchard hint")

	# The first hour on dev (way-in check, 23 Nov 2026): every hint's goal is a real goal, and the felled tree brings a hammer hint
	# after the trunk one (the lean-to and workbench hints say "hold your hammer").
	var goal_ids: Dictionary = {}

	for goal in camp._goals_data():
		goal_ids[str(goal.get("id", ""))] = true

	var hint_ids: Array = []

	for hint in camp._hints_data():
		hint_ids.append(str(hint["id"]))
		check(str(hint.get("goal", "")) == "" or goal_ids.has(str(hint["goal"])), "hint %s points at a real goal (%s)" % [hint["id"], hint.get("goal", "")])

	check(hint_ids.find("hammer") == hint_ids.find("trunk") + 1 and hint_ids.find("hammer") < hint_ids.find("leanto"), "the hammer hint follows the felled tree, before the lean-to")

	# The drink goal's hint names the way and distance to the nearest fresh water from where the player stands (coordinator for Dave,
	# 22 Nov 2026), worked out from the world's water map, again after a walk of WATER_HINT_MOVE_M, and no more once the player has drunk.
	var wdir: String = "user://test_goals_water"
	DirAccess.make_dir_recursive_absolute(wdir)

	for file in DirAccess.get_files_at(wdir):
		DirAccess.remove_absolute(wdir + "/" + file)

	var w = make(wdir, {}, [false])
	var lake: Array = [Vector3(1000.0, 10.0, -400.0)]
	w.nearest_fresh_water = func(pos, reach):
		var d: float = Vector2(lake[0].x - pos.x, lake[0].z - pos.z).length()
		return Vector3(lake[0].x, d if d <= reach else INF, lake[0].z)
	lists_sent.clear()
	w.peer_connected_hello(1, "water0000001")
	w.report_position(1, Vector3(1000.0, 10.0, 0.0))
	var drink_how: String = str((lists_sent.back() as Array)[0][2]) if not lists_sent.is_empty() else ""
	check(lists_sent.size() == 2 and drink_how.ends_with("The nearest fresh water is about 400 m north."), "the first position sends the drink hint with the way to water (%s)" % drink_how)
	w.report_position(1, Vector3(1010.0, 10.0, 0.0))
	check(lists_sent.size() == 2, "a few steps send nothing new")
	w.report_position(1, Vector3(1000.0 - 300.0, 10.0, -400.0 + 300.0))
	drink_how = str((lists_sent.back() as Array)[0][2])
	check(lists_sent.size() == 3 and drink_how.ends_with("about 420 m north-east."), "after a walk the hint is worked out again (%s)" % drink_how)
	lake[0] = Vector3(9000.0, 10.0, 9000.0)
	w.report_position(1, Vector3(0.0, 10.0, 0.0))
	check(str((lists_sent.back() as Array)[0][2]).contains("No fresh water within"), "no water in reach says so")
	w._goal_state_of(1)["goals_done"]["drink"] = true
	var lists_before: int = lists_sent.size()
	w.report_position(1, Vector3(600.0, 10.0, 600.0))
	check(lists_sent.size() == lists_before and not str(w.goals_rows(1)[0][2]).contains("fresh water"), "once drunk the hint is the plain one and is not sent again")

	# The search itself on a small made-up tile (8 m samples): a one-sample-wide river 100 m away is found; marsh, sea and a seasonal pond
	# nearer are not drinking water for the hint; nothing in reach is INF; a tile with no water map is INF.
	var tile = load("res://src/worldgen/runtime/tile_terrain_data.gd").new()
	tile.samples = 400
	tile.spacing_m = 8.0
	tile.x0 = 0.0
	tile.z0 = 0.0
	tile.water_class.resize(400 * 400)
	tile.water_surface.resize(400 * 400)
	tile.water_surface.fill(NAN)

	for j in 400:   # a river one sample wide, running north-south at x = 1608 (sample 201), 104 m east of the player
		tile.water_class[j * 400 + 201] = 3
		tile.water_surface[j * 400 + 201] = 5.0

	for cell in [[190, 200, 4], [195, 200, 1], [198, 200, 10]]:   # marsh, sea and a seasonal pond, all nearer
		tile.water_class[cell[1] * 400 + cell[0]] = cell[2]
		tile.water_surface[cell[1] * 400 + cell[0]] = 5.0

	var t0: int = Time.get_ticks_usec()
	var found: Vector3 = tile.fresh_water_spot(Vector3(1504.0, 10.0, 1600.0), 1500.0)
	var dry_t0: int = Time.get_ticks_usec()
	tile.fresh_water_spot(Vector3(400.0, 10.0, 400.0), 1500.0)   # far from the river: the near pass and the whole coarse pass
	print("drink hint search: %d us found near, %d us the whole reach" % [dry_t0 - t0, Time.get_ticks_usec() - dry_t0])
	check(absf(found.y - 104.0) < 17.0 and found.x == 1608.0, "a narrow river 104 m east is found past nearer marsh, sea and seasonal water (%s)" % str(found))
	check(tile.fresh_water_spot(Vector3(1504.0, 10.0, 1600.0), 50.0).y == INF, "no fresh water in reach: INF")
	tile.placeholder = true
	check(tile.fresh_water_spot(Vector3(1504.0, 10.0, 1600.0), 1500.0).y == INF, "an ocean tile with no map: INF")
	print("goals: %d failures" % failures)
	quit(1 if failures > 0 else 0)
