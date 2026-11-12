extends SceneTree

# Mission 001 phase 2c data (M001-T09; master s2.1, s2.2, s3.1, s4 items 1, 4, 13): the tool ladders, through the real server, recipes
# and blueprints. Every amount is read from the live data, so tuning keeps the test valid.
#   1. the rows: each family's tiers rise with its material (Wooden 1 ... Steel 5); disposable gear has no repair; metal tools repair at
#      the station type that makes them; edge only on sharpening-eligible metal tools; the Stone - Spade and Stone - Sickle are retired;
#   2. the groups take the better tool: an Iron - Knife for the Wooden bowl (recipe 20), an Iron - Axe for small blocks (339), a
#      Steel - Saw for Planks by hand (159), with no stone knife, stone axe or Iron - Saw in the pack;
#   3. every new ladder tool is made at its station from live materials: bronze at the Stone - Forge, iron and steel at the lit Smithy;
#   4. any metal hammer builds a blueprint of the top hammer tier, and the wooden and stone hammers do not (decision 73);
#   5. the Grindstone is built before the first saw and is a station.
#   godot --headless --path . --script res://src/worldgen/tools/test_tool_ladder.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const HERE := Vector3(0.0, 10.0, 0.0)
const RANK := {"wood": 1, "stone": 2, "bronze": 3, "iron": 4, "steel": 5}
const FAMILIES := ["axe", "pick", "spade", "hammer", "hoe", "knife", "saw", "sickle", "scythe", "chisel"]
const EDGED := ["axe", "pick", "knife", "saw", "sickle", "scythe", "chisel"]
const NEW_TOOLS := ["iron_axe", "steel_axe", "iron_knife", "steel_knife", "steel_saw", "bronze_sickle", "iron_sickle", "steel_sickle",
		"bronze_scythe", "steel_scythe"]
const DISPOSABLE := ["stone_axe", "stone_knife", "stone_hoe", "stone_hammer", "stone_pickaxe", "wooden_spade", "wooden_hoe", "wooden_hammer",
		"hide_scraper", "spear", "stone_mace", "javelin", "sewing_needle"]
const STATION := {"bronze": "forge", "iron": "brick_forge", "steel": "brick_forge"}

var failures: int = 0
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


func n_of(id: String) -> int:
	return items.table.number_of(id)


func have(id: String) -> int:
	return items.inventory_of(1).count_of(n_of(id))


func row(id: String) -> Dictionary:
	return items.table.entry(id)


func recipe_number(id: String) -> int:
	for n in items.recipes.numbers():
		if str(items.recipes.recipe(int(n)).get("id", "")) == id:
			return int(n)

	return 0


func recipe(id: String) -> Dictionary:
	return items.recipes.recipe(recipe_number(id))


func empty_pack() -> void:
	var inv = items.inventory_of(1)

	for slot in range(inv.SLOTS):
		if inv.numbers[slot] != 0:
			inv.remove(inv.numbers[slot], inv.counts[slot])


# Puts one of the tool in the pack with a hotbar key on it (wears_tool and the hammer need it on the hotbar).
func hold(id: String) -> void:
	var inv = items.inventory_of(1)
	items.give(1, n_of(id), 1)

	if not inv.hotbar.has(n_of(id)):
		inv.hotbar[0] = n_of(id)


func give_needs(id: String) -> void:
	for need in recipe(id).get("needs", []):
		items.inventory_of(1).add(int(need[0]), int(need[1]))   # straight into the pack (a log would go on the shoulder through give)


func craft(id: String, seconds: int = 60) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number(id), 0, 1, Vector3.ZERO)

	for s in range(seconds):
		items.tick(1.0)


func blueprint_of(structure: String) -> Dictionary:
	for number in items._blueprints:
		if str(items._blueprints[number].get("structure", "")) == structure:
			return items._blueprints[number]

	return {}


func standing_at(structure: String, at: Vector3) -> int:
	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct") and str(it["struct"]["kind"]) == structure and not it["struct"].has("site") and Vector3(it["pos"]).distance_to(at) < 1.0:
			return int(id)

	return -1


# Places a blueprint with the cost in the pack; true when the piece stands there.
func place(structure: String, at: Vector3) -> bool:
	var bp: Dictionary = blueprint_of(structure)

	for need in bp.get("cost", []):
		items.give(1, n_of(str(need[0])), int(need[1]))

	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(bp.get("number", 0)), 0, 0, at)
	return standing_at(structure, at) >= 0


func _init() -> void:
	var dir: String = "user://test_tool_ladder"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_reject = func(_p, _r): pass
	items.send_notice = func(_p, text): said.append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.admin_mode_on = func(_p): return false
	items.peer_connected_hello(1, "ladder000001")
	items.report_position(1, HERE)
	items.vitals_of(1)["weight"] = 5000.0   # carrying is not under test

	# 1. The rows.
	for id in items.table.ids():
		var r: Dictionary = row(id)
		var cls: String = str(r.get("tool_class", ""))

		if str(r.get("kind", "")) != "tool" or not FAMILIES.has(cls) or bool(r.get("retired", false)) or bool(r.get("future", false)):
			continue

		var mat: String = str(r.get("material", "wood" if id.begins_with("wooden_") else ""))
		check(RANK.has(mat) and int(r.get("tier", 1)) == int(RANK.get(mat, 0)), "%s: tier %d is its material's rank (%s)" % [id, int(r.get("tier", 1)), mat])
		check(bool(r.get("edge", false)) == (STATION.has(mat) and EDGED.has(cls)), "%s: edge only on a sharpening-eligible metal tool" % id)

		if STATION.has(mat):
			check(not r.get("repair", []).is_empty() and str(r.get("repair_station", "")) == STATION[mat], "%s: repaired at the %s" % [id, STATION[mat]])

	for id in DISPOSABLE:
		check(not row(id).is_empty() and not row(id).has("repair"), "%s is disposable: no repair" % id)

	for id in NEW_TOOLS + ["steel_pickaxe", "steel_spade", "steel_hoe", "steel_hammer", "steel_chisel", "grindstone"]:
		check(not row(id).is_empty() and not bool(row(id).get("future", false)), "%s is live" % id)

	for id in ["steel_pickaxe", "steel_chisel"] + NEW_TOOLS:
		check(bool(recipe(id).get("known", false)) and not bool(recipe(id).get("locked", false)), "the %s recipe is known from the start" % id)

	for id in ["stone_spade", "sickle"]:
		check(bool(row(id).get("retired", false)) and recipe_number(id) == 0, "%s and its recipe are retired" % id)

	check(int(row("javelin").get("stack", 0)) == 1 and int(recipe("spear").get("needs", []).filter(func(c): return int(c[0]) == n_of("stone")).size()) == 1 and recipe("spear").get("keeps", []).is_empty(), "the Javelin stacks 1; the Stone - Spear uses up its stone")

	var extra: Dictionary = items._dig_cfg.get("tier_extra", {})
	check(int(extra.get(str(int(row("wooden_spade").get("tier", 1))), 0)) == 0 and int(extra.get(str(int(row("iron_spade")["tier"])), 0)) == 2 and int(extra.get(str(int(row("steel_spade")["tier"])), 0)) == 3, "dig extra by spade: wooden 0, iron 2, steel 3 (as before the renumbering)")

	# 2. The groups take the better tool.
	for pair in [["wooden_bowl", "iron_knife", "stone_knife"], ["small_blocks_from_large", "iron_axe", "stone_axe"], ["lumber_by_hand", "steel_saw", "hand_saw"]]:
		empty_pack()
		hold(str(pair[1]))
		give_needs(str(pair[0]))
		var gives: Array = recipe(str(pair[0])).get("gives", [0, 0])
		craft(str(pair[0]))
		check(have(str(pair[2])) == 0 and items.inventory_of(1).count_of(int(gives[0])) == int(gives[1]) and have(str(pair[1])) == 1, "%s is made keeping a %s (no %s): %d %s" % [pair[0], pair[1], pair[2], items.inventory_of(1).count_of(int(gives[0])), items.table.id_of(int(gives[0]))])

	# The craft above ran only because a saw-class tool was on the hotbar (server_items.gd: wears_tool needs one); the recipe keeps the group.
	check(str(recipe("lumber_by_hand").get("wears_tool", "")) == "saw" and recipe("lumber_by_hand").get("keeps", []).any(func(c): return int(c[0]) == n_of("saw")), "Planks by hand keep any saw and wear it")

	for gid in ["knife", "axe", "saw"]:
		check(items.table.has_group_label(n_of(gid)) and items.table.cost_name(n_of(gid)).begins_with("Any "), "a %s cost reads \"%s\"" % [gid, items.table.cost_name(n_of(gid))])

	# 3. Every new tool at its station, from live materials.
	empty_pack()
	hold("wooden_hammer")
	var forge_at: Vector3 = HERE + Vector3(4.0, 0.0, 0.0)
	var smithy_at: Vector3 = HERE + Vector3(0.0, 0.0, 30.0)
	check(place("stone_forge", forge_at), "a Stone - Forge stands")

	for id in NEW_TOOLS:
		var r: Dictionary = recipe(id)
		var live: bool = r.get("needs", []).all(func(c): return not bool(row(items.table.id_of(int(c[0]))).get("future", false)) and not bool(row(items.table.id_of(int(c[0]))).get("retired", false)))
		check(live and str(r.get("station", "")) == STATION[str(row(id).get("material", ""))], "%s: made at the %s from live materials" % [id, str(r.get("station", ""))])

	for id in NEW_TOOLS.filter(func(t): return str(row(t).get("material", "")) == "bronze"):
		give_needs(id)
		craft(id)
		check(have(id) == 1, "%s is made at the Stone - Forge" % id)

	items.report_position(1, smithy_at)
	empty_pack()
	hold("wooden_hammer")
	check(place("blacksmithy", smithy_at + Vector3(2.0, 0.0, 0.0)), "a Smithy stands")
	items.give(1, n_of("charcoal"), 20)   # fires the Smithy

	for id in NEW_TOOLS.filter(func(t): return str(row(t).get("material", "")) != "bronze"):
		give_needs(id)
		craft(id)
		check(have(id) == 1, "%s is made at the lit Smithy" % id)

	# 4. Any metal hammer builds the top hammer tier; the wooden and stone ones do not.
	var top: int = 0

	for number in items._blueprints:
		if not bool(items._blueprints[number].get("retired", false)):
			top = maxi(top, int(items._blueprints[number].get("hammer", 1)))

	var top_row: String = "iron_brazier"   # a free-standing piece of the top hammer tier
	check(int(blueprint_of(top_row).get("hammer", 0)) == top and top > int(row("stone_hammer").get("tier", 1)), "the %s needs the top hammer tier %d" % [top_row, top])

	var spot: int = 0

	for hammer in ["wooden_hammer", "stone_hammer", "bronze_hammer", "iron_hammer", "steel_hammer"]:
		empty_pack()
		hold(hammer)
		spot += 1
		var at: Vector3 = HERE + Vector3(-8.0 * float(spot), 0.0, -12.0)
		items.report_position(1, at + Vector3(0.0, 0.0, 2.0))
		var metal: bool = STATION.has(str(row(hammer).get("material", "")))
		check(place(top_row, at) == metal, "%s %s a %s (hammer tier %d)" % [hammer, "builds" if metal else "cannot build", top_row, top])

	# 5. The Grindstone: before the first saw, a station.
	empty_pack()
	hold("wooden_hammer")
	var grind_at: Vector3 = HERE + Vector3(-6.0, 0.0, 12.0)
	items.report_position(1, grind_at + Vector3(0.0, 0.0, 1.5))
	var cost_ids: Array = blueprint_of("grindstone").get("cost", []).map(func(c): return str(c[0]))
	check(not cost_ids.is_empty() and cost_ids.all(func(c): return c in ["stone", "log"]), "the Grindstone costs only stone and logs (%s)" % str(cost_ids))
	check(place("grindstone", grind_at) and items.station_near(1, "grindstone"), "the Grindstone stands and is a grindstone station")

	print("tool ladder: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
