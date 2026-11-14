extends SceneTree

# The Copper tools (GOALS-REPAIR R2b; CATALOG_IMPLEMENTATION_PLAN R2 "meaningful Copper tools"; master s2: a Copper pick only with a verified
# mining role, Bronze mines Iron). Roster and stats PROVISIONAL (GOALS-REPAIR A-13, A-14): a Copper - Pickaxe and a Copper - Axe, between
# Stone and Bronze. Every amount is read from the live data, so tuning keeps the test valid:
#   1. the rows: copper material, durability between the Stone and Bronze tools of the same class, repaired with copper at the forge; made at
#      the Primitive smithy from Copper ingots (the making itself: test_tool_ladder section 3);
#   2. the Copper pick breaks more stone a blow than the Stone pick and less than the Bronze one (boulders.json tools);
#   3. no cycle: a Stone pick takes copper and tin ore; a Copper pick takes copper, tin and coal but no iron; a Bronze pick takes iron;
#   4. the Copper axe fells a tree in fewer blows than the Stone axe and more than the Bronze one (drops.json wood_tools).
#   godot --headless --path . --script res://src/worldgen/tools/test_copper_tools.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir_name: String, tool_ids: Array):
	var dir: String = "user://" + dir_name
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.send_reject = func(_p, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items._boulder_cfg["luck_extra"] = 0.0   # no luck doubles: the stones a blow are the rate alone
	items._boulder_cfg["flint"] = {}
	items.game_seconds = func(): return 5000.0
	items.peer_connected_hello(1, "coppertool01")
	items.report_position(1, Vector3(5.0, 11.5, 5.0))
	items.vitals_of(1)["weight"] = 5000.0

	for id in tool_ids:
		items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(str(id)), 0, 1, Vector3.ZERO)

	return items


func slot_of(items, id: String) -> int:
	return items.inventory_of(1).numbers.find(items.table.number_of(id))


func count(items, id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func boulder(items, ore: String) -> void:
	items._items[900001] = {"number": 0, "count": 5000, "pos": Vector3(5.0, 11.5, 6.0), "left": 1.0e9, "scatter": items.BOULDER_KEY | 7, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 5000}}

	if ore != "":
		items._items[900001]["boulder"]["ore"] = ore


# `n` blows on the boulder with the tool in pack slot `slot` in hand; the pieces that came out of it.
func blows(items, slot: int, n: int) -> int:
	var before: int = int(items._items[900001]["count"])

	for k in range(n):
		items._last_hit.clear()
		items.action(1, Net.ACT_HIT, 900001, Net.HIT_BOULDER, slot + 1, Vector3.ZERO)

	return before - int(items._items[900001]["count"])


func row(table, id: String) -> Dictionary:
	return table.entry(id)


func _init() -> void:
	var table = ItemTableScript.load_default()

	# --- 1. The rows ---
	for pair in [["copper_pickaxe", "stone_pickaxe", "bronze_pickaxe", "pick"], ["copper_axe", "stone_axe", "bronze_axe", "axe"]]:
		var r: Dictionary = row(table, str(pair[0]))
		var d: int = int(r.get("durability", 0))
		check(not r.is_empty() and str(r.get("material", "")) == "copper" and str(r.get("tool_class", "")) == str(pair[3]) and not bool(r.get("retired", false)), "%s is a live copper %s" % [pair[0], pair[3]])
		check(d > int(row(table, str(pair[1])).get("durability", 0)) and d < int(row(table, str(pair[2])).get("durability", 0)), "%s lasts longer than %s and less than %s (%d)" % [pair[0], pair[1], pair[2], d])
		check(r.get("repair", []).any(func(c): return str(c[0]) == "copper_ingot") and str(r.get("repair_station", "")) == "forge", "%s is repaired with copper at the forge" % pair[0])

	var probe = make("test_copper_tools_rows", [])
	var made: Array = []

	for n in probe.recipes.numbers():
		var rec: Dictionary = probe.recipes.recipe(int(n))

		if ["copper_pickaxe", "copper_axe"].has(table.id_of(int(rec.get("gives", [0, 0])[0]))):
			var copper: bool = rec.get("needs", []).any(func(c): return int(c[0]) == table.number_of("copper_ingot"))
			check(str(rec.get("station", "")) == "forge" and copper and bool(rec.get("known", false)), "%s is made at the Primitive smithy from Copper ingots" % table.id_of(int(rec["gives"][0])))
			made.append(table.id_of(int(rec["gives"][0])))

	check(made.has("copper_pickaxe") and made.has("copper_axe"), "both Copper tools have a recipe")
	probe._finish_writer()

	# --- 2. Stones a blow ---
	var got: Dictionary = {}

	for id in ["stone_pickaxe", "copper_pickaxe", "bronze_pickaxe"]:
		var w = make("test_copper_tools_" + id, [id])
		boulder(w, "")
		got[id] = blows(w, slot_of(w, id), 20)
		w._finish_writer()

	check(got["stone_pickaxe"] > 0 and got["copper_pickaxe"] > got["stone_pickaxe"] and got["bronze_pickaxe"] > got["copper_pickaxe"], "20 blows: a Stone pick breaks %d stones, a Copper pick %d, a Bronze pick %d" % [got["stone_pickaxe"], got["copper_pickaxe"], got["bronze_pickaxe"]])

	# --- 3. Ore: no cycle ---
	for case in [["stone_pickaxe", "copper", "copper_ore", true], ["stone_pickaxe", "tin", "tin_ore", true], ["copper_pickaxe", "copper", "copper_ore", true],
			["copper_pickaxe", "tin", "tin_ore", true], ["copper_pickaxe", "coal", "coal", true], ["copper_pickaxe", "iron", "iron_ore", false], ["bronze_pickaxe", "iron", "iron_ore", true]]:
		var o = make("test_copper_tools_ore_%s_%s" % [case[0], case[1]], [case[0]])
		o._boulder_cfg["ore"]["piece_share"] = 1.0
		boulder(o, str(case[1]))
		var pieces: int = blows(o, slot_of(o, str(case[0])), 20)
		var ore: int = count(o, str(case[2]))
		check(pieces > 0 and (ore > 0) == bool(case[3]), "a %s %s %s from a %s outcrop (%d ore of %d pieces)" % [case[0], "takes" if case[3] else "takes no", case[2], case[1], ore, pieces])
		o._finish_writer()

	# --- 4. Felling (each axe on its own server, so felling practice from one tree does not help the next) ---
	var took: Dictionary = {}

	for id in ["stone_axe", "copper_axe", "bronze_axe"]:
		var w = make("test_copper_tools_fell_" + id, [id])
		var standing: Dictionary = {11: true}
		w.tree_info = func(_c, tid): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.3} if standing.has(tid) else {}
		w.cut_tree = func(_c, tid): standing.erase(tid); return true
		w.report_position(1, Vector3(8.0, 10.0, 0.0))
		took[id] = fell(w, standing, 11, slot_of(w, id))
		w._finish_writer()

	check(took["stone_axe"] > 0 and took["copper_axe"] > 0 and took["bronze_axe"] > 0 and took["copper_axe"] < took["stone_axe"] and took["bronze_axe"] < took["copper_axe"], "an oak falls in %d blows of a Stone axe, %d of a Copper axe, %d of a Bronze axe" % [took["stone_axe"], took["copper_axe"], took["bronze_axe"]])

	print("copper tools: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# Blows until the tree falls with the tool in pack slot `slot` in hand (-1: it never fell in 200).
func fell(w, standing: Dictionary, id: int, slot: int) -> int:
	var n: int = 0

	while standing.has(id) and n < 200:
		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, id, 0, 0, Vector3(float(slot + 1), 0.0, 0.0))
		n += 1

	return n if not standing.has(id) else -1
