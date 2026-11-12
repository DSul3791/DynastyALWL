extends SceneTree

# Mission 001 phase 8 (M001-T16): the eight food boards and the Serving Platter (master s3.15 [D15]; companion FOOD_PREPARATION_PRESERVATION_SERVING.md s3,
# s5 scenarios 8 and 9) through the real server:
#   1. the data: eight boards live at the Food preparation table from cooked foods, the Ploughman's board still FUTURE, a board's portions are its stack
#      count, its food per portion and shelf life come from its ingredients (the shortest-lived), each board is one food of its group (tier 3);
#   2. a board made at a built table from real dishes (spent once), its age the stalest input's; boards of different ages never join;
#   3. a portion eaten from the pack is one food of the board's group: it refreshes, never stacks;
#   4. the platter goes only on a table top; the owner sets the board on it (the stack moves); two players eat half; a stranger cannot take it
#      or the platter; every portion is counted (pack + platter + eaten = made);
#   5. a placed platter with its board survives a save and load (portions, age, owner); picked up, the board and the platter come back whole.
#   godot --headless --path . --script res://src/worldgen/tools/test_serving_platter.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const FoodEffects := preload("res://src/shared/food_effects.gd")
const VitalsRules := preload("res://src/shared/vitals_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const HERE := Vector3(0.0, 10.0, 0.0)
const BOARDS := ["seafood_platter", "roast_platter", "mixed_grill_platter", "charcuterie_board", "harvest_platter", "tavern_supper_board", "breakfast_platter", "dessert_platter"]
const KEYS := ["platter-key-01", "platter-key-02"]

var failures: int = 0
var items
var said: Array = []
var asks: Array = []
var clock: Array = [(100.0 * 24.0 + 12.0) * 3600.0]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


func num(id: String) -> int:
	return items.table.number_of(id)


func have(peer: int, id: String) -> int:
	return items.inventory_of(peer).count_of(num(id))


func recipe_number(id: String) -> int:
	for n in items.recipes.numbers():
		if str(items.recipes.recipe(int(n)).get("id", "")) == id:
			return int(n)

	return 0


func recipe(id: String) -> Dictionary:
	return items.recipes.recipe(recipe_number(id))


func make_server(dir: String):
	var it = ItemsScript.new()
	it.send_full = func(_p, _b): pass
	it.send_slots = func(_p, _b): pass
	it.send_world_items = func(_p, _a, _r): pass
	it.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	it.send_reject = func(_p, _r): pass
	it.send_notice = func(_p, text): said.append(str(text))
	it.send_food_ask = func(p, slot, number, groups): asks.append([p, slot, number, groups])
	it.game_seconds = func(): return clock[0]
	it.ground_height = func(_x, _z): return 10.0
	it.setup(ItemTableScript.load_default(), dir)
	it.admin_mode_on = func(_p): return false
	it._vitals_cfg["eat_pace_ms"] = 0

	for n in KEYS.size():
		it.peer_connected_hello(n + 1, KEYS[n])
		it.report_position(n + 1, HERE + Vector3(float(n) * 0.8, 0.0, 1.0))
		it.vitals_of(n + 1)["weight"] = 5000.0

	return it


func structure_id(kind: String) -> int:
	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == kind and not items._items[id]["struct"].has("site"):
			return int(id)

	return -1


func plate(id: int):
	return items._chests.get(int(items._items[id]["struct"]["uid"]))


func on_plate(id: int) -> int:
	return int(plate(id).counts[0]) if plate(id) != null and plate(id).numbers[0] != 0 else 0


func use(peer: int, id: int, choice: int = 0) -> void:
	items._last_eat.clear()
	items.vitals_of(peer)["fed"] = 0.0
	items.action(peer, Net.ACT_USE_STRUCT, id, choice, 0, Vector3.ZERO)


func _init() -> void:
	var dir: String = "user://test_serving_platter"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = make_server(dir)
	var fx: Dictionary = items._food_cfg
	var vit: Dictionary = VitalsRules.load_config()

	# 1. The data.
	for b in BOARDS:
		var r: Dictionary = recipe(b)
		var portions: int = int(r.get("gives", ["", 0])[1])
		var kcal: int = 0
		var shortest: int = 1 << 30
		var cooked: bool = true

		for need in r.get("needs", []):
			var id: String = items.table.id_of(int(need[0]))
			kcal += VitalsRules.food_value(id, vit) * int(need[1])
			shortest = mini(shortest, items.table.shelf_units(int(need[0])))
			cooked = cooked and not FoodEffects.profile(id, fx).is_empty()   # a dish with an effect profile: cooked or prepared, never raw

		check(not bool(items.table.entry(b).get("future", false)) and str(r.get("station", "")) == "food_preparation_table" and cooked, "1a. %s is live, made at the Food preparation table from cooked foods" % b)
		check(portions == r["needs"].reduce(func(s, n): return s + int(n[1]), 0) and VitalsRules.food_value(b, vit) * portions <= kcal and items.table.shelf_units(num(b)) == shortest, "1b. %s: %d portions, %d kcal each from the %d of its dishes, the shortest shelf life of them" % [b, portions, VitalsRules.food_value(b, vit), kcal])
		var prof: Dictionary = FoodEffects.profile(b, fx)
		var want: String = {"dessert_platter": "dessert", "harvest_platter": "fruit_veg"}.get(b, "main")
		check(int(prof.get("tier", 0)) == 3 and str(prof.get("group", "")) == want, "1c. %s is one tier 3 %s food" % [b, want])

	check(bool(items.table.entry("ploughmans_board").get("future", false)) and recipe_number("ploughmans_board") == 0, "1d. the Ploughman's board waits for cheese and pickles (FUTURE, no recipe)")
	check(str(FoodEffects.profile("tavern_supper_board", fx).get("xp", "")) == "all", "1e. the Tavern supper board (three groups) is the balanced board: all-skill XP")

	# 2. A Roast platter made at a built table; ages.
	var prep: int = items._next_id   # built elsewhere (test_cooking_route builds it from its blueprint)
	items._items[prep] = {"number": num("food_preparation_table"), "count": 1, "pos": HERE + Vector3(1.5, 0.0, -0.5), "left": 1.0e9, "struct": {"kind": "food_preparation_table", "yaw": 0.0}}
	items._grid_add(prep, items._items[prep])
	items._next_id += 1
	var roast: Dictionary = recipe("roast_platter")
	var portions: int = int(roast["gives"][1])

	for need in roast["needs"]:
		items.give(1, int(need[0]), int(need[1]))

	var stale: int = int(roast["needs"][0][0])
	var inv = items.inventory_of(1)
	inv.wear[inv.numbers.find(stale)] = items.table.shelf_units(stale) / 2   # one ingredient half gone
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number("roast_platter"), 0, 1, Vector3.ZERO)

	for s in 10:
		items.tick(1.0)

	var board_n: int = num("roast_platter")
	var slot: int = inv.numbers.find(board_n)
	check(have(1, "roast_platter") == portions and roast["needs"].all(func(n): return items.inventory_of(1).count_of(int(n[0])) == 0), "2b. the board is made from the real dishes (each spent once): %d portions in one stack" % portions)
	check(slot >= 0 and absf(items.table.freshness(board_n, inv.wear[slot]) - 0.5) < 0.05, "2c. its age is the stalest ingredient's (%.2f fresh)" % (items.table.freshness(board_n, inv.wear[slot]) if slot >= 0 else -1.0))
	var fresh_left: int = inv.add(board_n, 2, 0)
	check(fresh_left == 0 and have(1, "roast_platter") == portions + 2 and inv.counts[slot] == portions, "2d. a fresh board never joins the half-gone one: two stacks")
	inv.take_from_slot(inv.numbers.find(board_n, slot + 1), 2)
	inv.add(board_n, 1, inv.wear[slot] + 1)   # one tenth of a game hour apart: an ordinary food would join (spoilage merge_gap)
	check(inv.counts[slot] == portions and have(1, "roast_platter") == portions + 1, "2e. boards join only at the very same age (spoilage.json exact_age)")
	inv.take_from_slot(inv.numbers.find(board_n, slot + 1), 1)
	inv.add(board_n, 1, inv.wear[slot])
	check(inv.counts[slot] == portions + 1, "2f. at the same age they join")
	inv.take_from_slot(slot, 1)

	# 3. A portion from the pack: one Main meal, tier 3; another refreshes, never stacks.
	items._last_eat.clear()
	items.vitals_of(1)["fed"] = 0.0
	items.action(1, Net.ACT_EAT, slot, 0, 0, Vector3.ZERO)
	var on: Dictionary = FoodEffects.live(items._food_of(1), clock[0])
	check(have(1, "roast_platter") == portions - 1 and on.has("main") and int(on["main"]["t"]) == 3 and absf(items.fitness_xp_mult(1) - 1.20) < 0.0001, "3a. one portion from the pack is one tier 3 Main meal (+20 %% Fitness XP)")
	clock[0] += 60.0
	items._last_eat.clear()
	items.vitals_of(1)["fed"] = 0.0
	items.action(1, Net.ACT_EAT, slot, 0, 0, Vector3.ZERO)
	on = FoodEffects.live(items._food_of(1), clock[0])
	check(have(1, "roast_platter") == portions - 2 and on.size() == 1 and absf(items.fitness_xp_mult(1) - 1.20) < 0.0001 and absf(float(on["main"]["until"]) - (clock[0] + 12.0 * 3600.0)) < 0.5, "3b. a second portion refreshes the 12 h timer and adds nothing (no stacking)")
	items.give(1, board_n, 2, {}, inv.wear[slot])   # back to a full board's count, at the same age (it joins)
	var made: int = have(1, "roast_platter")

	# 4. The platter on a table.
	items.action(1, Net.ACT_ADMIN_GIVE, num("serving_platter"), 0, 2, Vector3.ZERO)
	items.action(1, Net.ACT_PLACE, inv.numbers.find(num("serving_platter")), 0, 0, HERE + Vector3(-2.0, 0.0, 0.0))
	check(structure_id("serving_platter") < 0 and have(1, "serving_platter") == 2 and said.has("Set it on a table."), "4a. on bare ground the platter is refused: 'Set it on a table.'")
	var table_pos: Vector3 = items._items[prep]["pos"]
	items.action(1, Net.ACT_PLACE, inv.numbers.find(num("serving_platter")), 0, 0, table_pos + Vector3(0.9, 0.0, 0.2))
	var platter: int = structure_id("serving_platter")
	var top: float = float(items._structures["serving_platter"]["attach_kinds"]["food_preparation_table"])
	check(platter >= 0 and absf(items._items[platter]["pos"].y - (table_pos.y + top)) < 0.01 and absf(items._items[platter]["pos"].x - table_pos.x) <= 0.45 + 0.001, "4b. aimed at the table's edge it sits on the top, inside the edge (%s)" % (str(items._items[platter]["pos"]) if platter >= 0 else "none"))
	items.action(1, Net.ACT_PLACE, inv.numbers.find(num("serving_platter")), 0, 0, items._items[platter]["pos"])
	check(have(1, "serving_platter") == 1 and said.has("There is a platter there already."), "4c. one platter to a spot")
	items.give(1, num("stone"), 1)
	items.action(1, Net.ACT_CHEST_PUT, inv.numbers.find(num("stone")), platter, 1, Vector3.ZERO)
	check(on_plate(platter) == 0 and have(1, "stone") >= 1, "4d. a platter takes food boards only")
	items.action(1, Net.ACT_CHEST_PUT, inv.numbers.find(board_n), platter, made, Vector3.ZERO)
	check(on_plate(platter) == made and have(1, "roast_platter") == 0, "4e. the owner sets the board out: all %d portions move onto the platter" % made)
	var stranger_before: int = have(2, "roast_platter")
	items.action(2, Net.ACT_CHEST_OPEN, platter, 0, 0, Vector3.ZERO)
	items.action(2, Net.ACT_CHEST_TAKE, 0, platter, made, Vector3.ZERO)
	check(on_plate(platter) == made and have(2, "roast_platter") == stranger_before, "4f. another player cannot take the board")
	var eaten: int = 0
	var food_was: Array = [0.0, 0.0]

	for k in made / 2:
		var peer: int = 1 + k % 2
		var before: int = on_plate(platter)
		use(peer, platter)
		food_was[peer - 1] = float(items.vitals_of(peer)["fed"])
		eaten += before - on_plate(platter)

	check(eaten == made / 2 and on_plate(platter) == made - eaten and food_was[0] > 0.0 and food_was[1] > 0.0, "4g. two players eat half (%d portions), each portion fed someone" % eaten)
	check(FoodEffects.live(items._food_of(2), clock[0]).has("main"), "4h. a portion from the platter is a Main meal for the second player too")
	items._characters[KEYS[1]]["food"] = {"bread": {"id": "flatbread", "t": 1, "until": clock[0] + 9999.0}, "fruit_veg": {"id": "roast_roots", "t": 1, "until": clock[0] + 9999.0}, "dessert": {"id": "berry_compote", "t": 1, "until": clock[0] + 9999.0}}
	asks.clear()
	var before_ask: int = on_plate(platter)
	use(2, platter)
	check(on_plate(platter) == before_ask and asks.size() == 1 and int(asks[0][1]) == -platter, "4i. with three other groups active the player is asked first (the question names the platter) and nothing is eaten")
	use(2, platter, FoodEffects.group_index("dessert", fx))
	check(on_plate(platter) == before_ask - 1 and FoodEffects.live(items._food_of(2), clock[0]).has("main"), "4j. answered, one portion is eaten and replaces the Dessert")
	eaten += 1
	items.action(2, Net.ACT_PICKUP, platter, 0, 0, Vector3.ZERO)
	check(structure_id("serving_platter") == platter and on_plate(platter) == made - eaten, "4k. another player cannot pick the platter up")
	said.clear()
	items.action(1, Net.ACT_PICKUP, prep, 0, 0, Vector3.ZERO)
	check(items._items.has(prep) and said.has("Take the platter off it first."), "4m. the table cannot be taken down from under the platter")
	var beside: int = items._next_id   # a second table end to end with it, 1.5 m on: the platter (0.45 m from the first's middle) is 1.05 m from its middle
	items._items[beside] = {"number": num("food_preparation_table"), "count": 1, "pos": items._items[prep]["pos"] + Vector3(1.5, 0.0, 0.0), "left": 1.0e9, "struct": {"kind": "food_preparation_table", "yaw": 0.0}}
	items._grid_add(beside, items._items[beside])
	items._next_id += 1
	check(not items._platter_on(items._items[beside]) and items._platter_on(items._items[prep]), "4m2. the platter stands on its own table, not on the one beside it (the turned footprint, not a radius)")
	items._items[beside]["struct"]["yaw"] = 90.0
	check(not items._platter_on(items._items[beside]), "4m3. nor on the neighbour turned a quarter")
	items._items.erase(beside)
	items.action(2, Net.ACT_CHEST_OPEN, platter, 0, 0, Vector3.ZERO)
	items.action(2, Net.ACT_BULK, 0, 0, 0, Vector3.ZERO)
	check(on_plate(platter) == made - eaten, "4n. nor can another player open it and Take all")
	check(have(1, "roast_platter") + have(2, "roast_platter") + on_plate(platter) + eaten == made, "4l. every portion is counted: none made or lost")

	# 5. Save, load, pick up.
	var uid: int = int(items._items[platter]["struct"]["uid"])
	var left: int = on_plate(platter)
	var age: int = int(plate(platter).wear[0])
	items._dirty = true
	items.save()
	items = make_server(dir)
	platter = -1

	for id in items._items:
		if items._items[id].has("struct") and int(items._items[id]["struct"].get("uid", -1)) == uid:
			platter = int(id)

	check(platter >= 0 and str(items._items[platter]["struct"]["kind"]) == "serving_platter" and on_plate(platter) == left and int(plate(platter).wear[0]) == age and str(items._items[platter]["struct"].get("owner", "")) == KEYS[0], "5a. after a restart the platter keeps its board, %d portions, their age and its owner" % left)
	var rows: Array = []
	items.send_world_items = func(_p, a, _r): rows.append_array(a)
	items._known[1] = {}
	items._sync_world_items()
	var row: Array = []

	for r in rows:
		if int(r[0]) == platter:
			row = r

	check(not row.is_empty() and (int(row[5].get("board", 0)) == board_n and int(row[5].get("portions", 0)) == left), "5b. its world row tells clients the board and the portions left (%s)" % str(row.slice(4) if not row.is_empty() else "not sent here"))
	var platters_before: int = have(1, "serving_platter")
	items.action(1, Net.ACT_PICKUP, platter, 0, 0, Vector3.ZERO)
	var back: int = items.inventory_of(1).numbers.find(board_n)
	check(structure_id("serving_platter") < 0 and have(1, "roast_platter") == left and have(1, "serving_platter") == platters_before + 1, "5c. picked up: the %d portions and the platter come back, nothing on the table" % left)
	check(back >= 0 and int(items.inventory_of(1).wear[back]) == age, "5d. and the board keeps its age")
	print("serving platter: %d failures" % failures)
	quit(1 if failures > 0 else 0)
