extends SceneTree

# Starter goals (data/items/starter_goals.json, Sal; code by Tyler 31 Oct 2026): the real first-hour goals, played on the server logic. Drink at the water, gather
# fibre, twist twine, make the axe, fell a tree, make and light a fire, build a lean-to and a workbench. Checks: each goal completes when its check is met, it pays its
# stage's copper (coins only), a goal completes out of its authored order (`after` is no lock, GA-40), the player is told "Goal done" and the next goal, goal_done
# goes to the client once per completion with the copper paid, the done goals are saved with the character and still done after a restart, a rejoin sends the
# list silently and pays nothing again, the next tick saves (GA-55), and Admin mode and admin gives earn nothing (GA-54). Protocol 119.
#   godot --headless --path . --script res://src/worldgen/tools/test_goals.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var items
var said: Array = []
var done_sent: Array = []   # [id, copper] per goal_done
var lists_sent: Array = []  # the rows of each goals message


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
	items.admin_mode_on = func(_p): return false
	check(lists_sent.size() == 1 and (lists_sent[0] as Array).size() == items._goals_data().size(), "the join sends the whole goal list once (%d lists)" % lists_sent.size())
	var rows: Array = items.goals_rows(1)
	check(rows.size() >= 10 and rows[0][0] == "drink" and rows[0][3] == 5 and rows[0][7] == false and rows.all(func(r): return r.size() == 8 and r[7] == false), "goals_rows lists every goal in the authored order, drink first paying 5 copper (start stage), none done (%d goals)" % rows.size())
	check(rows.all(func(r): return r[3] == 5 and r[4] == "" and r[5] == 0) and rows.any(func(r): return r[0] == "axe" and r[6].has("twine") and r[2] != ""), "every live goal pays 5 copper and no item (coins only, Dave 14 Nov; A-42 start stage); a row carries its how-to and the goals taught before it")
	var stages: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/goal_rewards.json")) as Dictionary).get("stages", {})
	check(not stages.is_empty() and items._goals_data().all(func(g): return stages.has(str(g.get("stage", ""))) and not g.has("reward")), "every goal names a stage from the one table in goal_rewards.json and carries no reward of its own")
	check(rows.any(func(r): return r[0] == "hoe") and rows.any(func(r): return r[0] == "path"), "the hoe and path goals are listed (Dave 4 Nov 2026)")

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
	items.give(1, items.table.number_of("plant_fibre"), 11)   # as a harvest gives them
	check(got.call("plant_fibre") == 11 and not done("fibre"), "11 gathered first-hand: not yet")
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

	check(str(live["fish"].get("event", "")) == "fish_caught" and int(live["fish"].get("count", 0)) == 1 and not live["fish"].has("have_item_any") and not live["fish"].has("or_event")
		and str(live["workbench"].get("what", "")) == "workbench" and not live["workbench"].has("what_any"), "the fish goal counts only a catch and the workbench goal only the workbench (corrected catalog, GA-47)")
	check(str(live["hammer"].get("made_item", "")) == "wooden_hammer" and str(live["hoe"].get("made_item", "")) == "wooden_hoe" and not JSON.stringify(live).contains("wooden_hammer_soft"), "the hammer and hoe goals count a made Wooden - Hammer and Wooden - Hoe; no wooden_hammer_soft item is named")

	# Axe, then fell a tree.
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone"), 0, 6, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 20, Vector3.ZERO)
	craft("twine", 3)
	craft("stone_axe", 1)
	check(done("axe"), "making the stone axe completes the axe goal")
	items.action(1, Net.ACT_MOVE, items.inventory_of(1).numbers.find(items.table.number_of("stone_axe")), 0, 0, Vector3.ZERO)
	items.report_position(1, Vector3(8.0, 10.0, 0.0))
	var kindling_fell: int = count("kindling")
	var fell_lines: int = said.size()

	for n in range(200):
		if standing.is_empty():
			break

		items._last_hit.clear()
		items.action(1, Net.ACT_HIT, 7, 0, 0, HeldTool.at_axe(items))

	check(standing.is_empty() and done("fell") and count("kindling") == kindling_fell and said.slice(fell_lines).any(func(t): return t.begins_with("Goal done: Fell a tree") and t.contains("You earn 5 copper.")), "felling a tree completes the fell goal and pays 5 copper, no kindling (coins only)")
	# The logs a felled tree breaks into by itself are its feller's gathering, once; the record clients get does not name the feller.
	var trunk_id: int = -1

	for k in items._items:
		if items._items[k].has("tree") and int(items._items[k]["tree"]["state"]) == 3:
			trunk_id = int(k)

	check(trunk_id >= 0 and str(items._fellers.get(trunk_id, "")) == "goals0000001" and not JSON.stringify(items._items[trunk_id]["tree"]).contains("goals0000001"), "the felled trunk remembers its feller on the server only")
	var log_n: int = items._log_number(str(items._items[trunk_id]["tree"].get("species", ""))) if trunk_id >= 0 else 0
	var ground_logs: Callable = func() -> int:
		var total: int = 0

		for k in items._items:
			if int(items._items[k].get("number", 0)) == log_n and not items._items[k].has("tree"):
				total += int(items._items[k]["count"])

		return total

	var logs_before: int = ground_logs.call()
	var logs_got: int = got.call(items.table.id_of(log_n))
	var split: bool = items.split_trunk(trunk_id)
	var laid: int = ground_logs.call() - logs_before
	check(split and laid > 0 and got.call(items.table.id_of(log_n)) == logs_got + laid, "the trunk splits into %d logs and the feller has gathered them (%d)" % [laid, got.call(items.table.id_of(log_n)) - logs_got])
	check(not items.split_trunk(trunk_id) and got.call(items.table.id_of(log_n)) == logs_got + laid and not items._fellers.has(trunk_id), "it splits once and is credited once")

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
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("wooden_hammer"), 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("leaves"), 0, 12, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 32, Vector3.ZERO)   # the lean-to costs 16 sticks, 4 leaves, 2 twine (lighter 3 Nov; was 32/8/4)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("twine"), 0, 4, Vector3.ZERO)
	items.place_piece(1, "lean_to_kit", Vector3(-3.0, 10.0, 0.0))
	check(done("shelter"), "placing a lean-to completes the shelter goal")
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stick"), 0, 24, Vector3.ZERO)   # the workbench now costs 20 sticks, 6 twine and 4 stones (pacing pass)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("twine"), 0, 6, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone"), 0, 4, Vector3.ZERO)
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
	admin.action(1, Net.ACT_CRAFT_QUEUE, hoe_recipe, 0, 1, Vector3.ZERO)

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
	# Hints: said once when their trigger holds, saved with the character, repeated only for a goal still open after 5 minutes.
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
	hinter.action(1, Net.ACT_ADMIN_GIVE, hinter.table.number_of("stick"), 0, 9, Vector3.ZERO)

	for n in range(4):
		hinter._goals_tick()

	check(said.has("Press E on nettles or tall grass to get plant fibre."), "nine sticks in the pack bring the fibre hint")
	var seen: Dictionary = hinter._goal_state_of(1)["hints_seen"]
	check(seen.has("move") and seen.has("bars") and seen.has("fibre"), "the said hints are saved with the character (%s)" % str(seen.keys()))
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
	# made_item_any (chop_log_blocks, GAP-GUIDE-ANY): crafts of any of the four wooden blocks add up; blocks only held, admin-given, count nothing.
	var blocks_check := {"made_item_any": ["wooden_block", "wooden_block_soft", "wooden_block_large", "wooden_block_soft_large"], "count": 2}
	check(not camp._goal_met(1, camp._goal_state_of(1), blocks_check, "chop_log_blocks"), "no block made: the blocks goal is open")
	camp.action(1, Net.ACT_ADMIN_GIVE, camp.table.number_of("wooden_block"), 0, 3, Vector3.ZERO)
	check(not camp._goal_met(1, camp._goal_state_of(1), blocks_check, "chop_log_blocks"), "three admin-given blocks in the pack do not complete it")
	camp._goal_made(1, camp.table.number_of("wooden_block"))
	check(not camp._goal_met(1, camp._goal_state_of(1), blocks_check, "chop_log_blocks"), "one block made: still open (count 2)")
	camp._goal_made(1, camp.table.number_of("wooden_block_soft_large"))
	check(camp._goal_met(1, camp._goal_state_of(1), blocks_check, "chop_log_blocks"), "two different blocks made: met")
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
	print("goals: %d failures" % failures)
	quit(1 if failures > 0 else 0)
