extends SceneTree

# Mission 001 phase 2b: leather and textiles (master s2.8, s3.4, s4 item 10) for a new character, through the real server, recipes and
# blueprints. Every amount is read from the live data, so tuning the numbers keeps the test valid.
#   1. gather stones, sticks and plant fibre by hand; a stone knife; hides and bone from two rabbit carcasses; a Bone - Needle;
#   2. Thread twisted by hand from plant fibre;
#   3. a Hide - Hood sewn by hand with the needle and Thread, no Twine and no building (2.8 item 3);
#   4. leather at a Tanning rack, then the Leatherworking table from logs, sticks, twine and stone, and a Leather strap there;
#   5. the Loom, and Fibre cloth woven on it (refused by hand);
#   6. the Tailor's table, and a Fibre - Gambeson made there (refused at the Loom alone).
# The scraper, hammer and the stations' logs, twine, clay and stones are given: they are gathered or made elsewhere and
# covered by other tests (test_first_hour, test_server_items).
#   godot --headless --path . --script res://src/worldgen/tools/test_textile_route.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const HERE := Vector3(0.0, 10.0, 0.0)
const NEEDLE_RECIPES := [23, 39, 40, 41, 42, 173, 194, 195, 196, 237, 238, 241, 388]   # master s3.4: Thread replaces Twine in these
const HAND_SEWN := [23, 30, 39, 40, 41, 42, 173, 194, 195, 196, 388]                   # stay by hand with the needle (2.8 item 3)
const PRE_SAW := ["log", "stick", "twine", "stone", "clay", "hide", "plant_fibre"]       # no Planks and no metal (s4 item 10)

var failures: int = 0
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(said.slice(maxi(said.size() - 3, 0))) if not said.is_empty() else "nothing")


func have(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func recipe_number(id: String) -> int:
	for n in items.recipes.numbers():
		if str(items.recipes.recipe(int(n)).get("id", "")) == id:
			return int(n)

	return 0


func need_of(recipe_id: String, id: String) -> int:
	for need in items.recipes.recipe(recipe_number(recipe_id)).get("needs", []):
		if int(need[0]) == items.table.number_of(id):
			return int(need[1])

	return 0


# Water by the player's route (GOALS-REPAIR GA-04): the real fill action at fresh water puts 500 mL a fill into a bucket in the pack; a recipe's water ingredient is drawn from it.
func fill_water(units: int) -> void:
	items.water_near = func(_pos, _reach): return true
	var bucket: int = items.table.number_of("bucket")

	if items.inventory_of(1).count_of(bucket) == 0:
		items.action(1, Net.ACT_ADMIN_GIVE, bucket, 0, 1, Vector3.ZERO)

	var slot: int = items.inventory_of(1).numbers.find(bucket)

	for k in range(units):
		items._last_drink.clear()
		items.action(1, Net.ACT_DRINK, slot, 0, 0, Vector3.ZERO)

	check(items.inventory_of(1).count_fill(items.table.number_of("water")) >= units and have("water") == 0, "4a1. %d fills of 500 mL make %d water ingredients; no stackable water exists" % [units, units])


# One felled oak (the fall: test_fell_autosplit) cut up with a Stone - Axe in hand, away from the stations: it gives its harvest_yield count of tannin bark, once.
func bark_from_oak() -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	var id: int = 960001
	var at: Vector3 = Vector3(300.0, 10.0, 300.0)
	var back: Vector3 = items.position_of(1)
	items._items[id] = {"number": 0, "count": 1, "pos": at, "left": 1.0e9, "tree": {"state": 3, "species": "oak", "yaw": 0.0, "pitch": 0.0, "length": 9.0, "radius": 0.3, "chunk": [4, 4]}}

	for blow in range(40):
		if not items._items.has(id):
			break

		var tree: Dictionary = items._items[id]["tree"]
		var logs_phase: bool = int(tree.get("blows", 0)) >= int(items._drops["trunk"]["branch_blows"]) and int(tree.get("logs_left", 0)) > 0
		var length_now: float = float(tree["length"])
		var piece: float = length_now if int(tree.get("logs_left", 0)) <= 1 else minf(float(items._drops["trunk"]["log_length_m"]), length_now)
		items.report_position(1, at + Vector3(0.3, 0.0, (length_now - piece * 0.5) if logs_phase else 0.5))
		items._last_process.erase(1)
		items.action(1, Net.ACT_PROCESS, id, 0, 0, HeldTool.at_axe(items))

	items.report_position(1, back)
	check(have("tannin_bark") == int(items._drops["harvest_yield"]["oak"]["count"]), "4a0. a felled oak cut up with the axe gives its tannin bark (%d)" % have("tannin_bark"))


func gives_of(recipe_id: String) -> int:
	return int(items.recipes.recipe(recipe_number(recipe_id)).get("gives", [0, 1])[1])


func crafts_for(recipe_id: String, wanted: int) -> int:
	return ceili(float(wanted) / float(gives_of(recipe_id)))


func craft(id: String, times: int, seconds: int) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number(id), 0, times, Vector3.ZERO)

	for s in range(seconds):
		items.tick(1.0)

	collect()


# Station products stay in the station (master s2.5, M001-T18): after a craft the player takes them out of their own station stores beside
# them through the real server path (open, Take all, close), as a player does.
func collect() -> void:
	for id in items._items.keys():
		var it: Dictionary = items._items.get(id, {})

		if it.has("struct") and items._is_station_store(it) and str(it["struct"].get("owner", "")) == items.key_of(1) and (it["pos"] as Vector3).distance_to(items.position_of(1)) <= 4.0:
			items.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
			items.action(1, Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0, 0, Vector3.ZERO)
			items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)


func blueprint_of(structure: String) -> Dictionary:
	for number in items._blueprints:
		if str(items._blueprints[number].get("structure", "")) == structure:
			return items._blueprints[number]

	return {}


func standing(structure: String) -> int:
	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == structure and not items._items[id]["struct"].has("site"):
			return int(id)

	return -1


# Builds a station from its blueprint: the materials are put in the pack, and the pack must give exactly the cost.
func build(structure: String, at: Vector3) -> int:
	var bp: Dictionary = blueprint_of(structure)

	for need in bp.get("cost", []):
		items.give(1, items.table.number_of(str(need[0])), int(need[1]))

	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(bp.get("number", 0)), 0, 0, at)
	var id: int = standing(structure)
	var spent: bool = bp.get("cost", []).all(func(c): return have(str(c[0])) == 0) if id >= 0 else false
	check(id >= 0 and spent, "the %s stands, built from %s" % [structure, str(bp.get("cost", []))])
	return id


func _init() -> void:
	var dir: String = "user://test_textile_route"
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
	items.peer_connected_hello(1, "textiles0001")
	items.report_position(1, HERE)
	items.vitals_of(1)["weight"] = 5000.0   # carrying is not under test
	check(have("stone") == 0 and have("plant_fibre") == 0, "a new character arrives empty-handed")

	# The data: Thread replaces Twine in the needle recipes, fur keeps Sinew, hide goods stay by hand, the stations cost no Planks or metal.
	for n in NEEDLE_RECIPES:
		var ids: Array = items.recipes.recipe(n).get("needs", []).map(func(c): return items.table.id_of(int(c[0])))
		check(ids.has("thread") and not ids.has("twine"), "recipe %d (%s) sews with Thread, not Twine" % [n, items.recipes.recipe(n).get("id", "")])

	for id in ["fur_cloak", "fur_hat", "fur_boots"]:
		check(need_of(id, "sinew") > 0 and need_of(id, "thread") == 0, "%s keeps Sinew" % id)

	for n in HAND_SEWN:
		check(str(items.recipes.recipe(n).get("station", "")) == "", "recipe %d (%s) is still sewn by hand" % [n, items.recipes.recipe(n).get("id", "")])

	for st in ["leatherworking_table", "loom", "tailors_table"]:
		var ids: Array = blueprint_of(st).get("cost", []).map(func(c): return str(c[0]))
		check(not ids.is_empty() and ids.all(func(c): return c in PRE_SAW), "the %s is built before the first saw, of %s" % [st, str(ids)])

	# 1. Gather by hand, a stone knife, two rabbits worked with it, a needle from the bone.
	var thread_n: int = need_of("hide_hood", "thread")
	var cloth_n: int = need_of("gambeson", "fibre_cloth")
	var fibre_n: int = crafts_for("thread", thread_n) * need_of("thread", "plant_fibre") + crafts_for("fibre_cloth", cloth_n) * need_of("fibre_cloth", "plant_fibre") + need_of("gambeson", "plant_fibre")

	for n in range(8):
		var around: Vector3 = Vector3(cos(float(n) * TAU / 8.0), 0.0, sin(float(n) * TAU / 8.0))   # more than a metre apart, or heaps merge
		items.drop_in_world(items.table.number_of("plant_fibre"), ceili(float(fibre_n) / 8.0), HERE + around * 2.5)

	items.drop_in_world(items.table.number_of("stone"), need_of("stone_knife", "stone"), HERE + Vector3(1.2, 0.0, 0.0))
	items.drop_in_world(items.table.number_of("stick"), need_of("stone_knife", "stick"), HERE + Vector3(-1.2, 0.0, 0.0))

	for _pass in range(20):   # a heap gives a handful at a time
		for id in items._items.keys():
			if items._items.has(id) and not items._items[id].has("scatter") and not items._items[id].has("struct"):
				items.action(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)

	check(have("plant_fibre") >= fibre_n and have("stone") > 0 and have("stick") > 0, "1a. gathering by hand gives %d plant fibre (%d needed), stones and sticks" % [have("plant_fibre"), fibre_n])
	craft("stone_knife", 1, 20)
	check(have("stone_knife") == 1, "1b. a stone knife by hand")

	for n in range(2):
		var carcass: int = items.make_carcass("rabbit", HERE + Vector3(1.5, 0.0, 1.5))

		for blow in range(6):
			items._last_process.erase(1)
			items.action(1, Net.ACT_PROCESS, carcass, 0, 0, Vector3(float(HeldTool.slot_of(items, "knife") + 1), 0.0, 0.0))

	check(have("hide") >= 2 and have("bone") >= 1, "1c. the knife takes %d hides and %d bones from two rabbits" % [have("hide"), have("bone")])
	craft("sewing_needle", 1, 20)
	check(have("sewing_needle") == 1, "1d. a Bone - Needle by hand")

	# 2. Thread by hand.
	var fibre_before: int = have("plant_fibre")
	craft("thread", crafts_for("thread", thread_n), 20)
	check(have("thread") >= thread_n and have("plant_fibre") == fibre_before - crafts_for("thread", thread_n) * need_of("thread", "plant_fibre"), "2. plant fibre twists into %d Thread by hand" % have("thread"))

	# 3. A hide hood sewn by hand: no building near, no Twine in the pack.
	var hides: int = have("hide")
	check(have("twine") == 0 and standing("workbench") < 0, "3a. no Twine and no bench")
	craft("hide_hood", 1, 30)
	check(have("hide_hood") == 1 and have("hide") == hides - need_of("hide_hood", "hide") and have("thread") == 0 and have("sewing_needle") == 1, "3b. the hood is sewn by hand from a hide and Thread; the needle is kept")

	# 4. Leather, then the Leatherworking table and a Leather strap there.
	items.give(1, items.table.number_of("hide_scraper"), 1)
	items.give(1, items.table.number_of("wooden_hammer"), 1)
	craft("processed_hide", 1, 30)
	check(have("processed_hide") == 0 and have("hide") >= 1, "4. no Drying rack: the hide is not scraped and dried (master s3.4: the rack adds the hide drying step)")
	var rack: int = build("drying_rack", HERE + Vector3(-2.6, 0.0, 0.5))
	craft("processed_hide", 1, 40)
	check(have("processed_hide") == 1, "4. at the Drying rack the hide is scraped and dried")
	items._items.erase(rack)   # cleared away so the Tailor's table can stand on that side later
	build("tanning_rack", HERE + Vector3(0.0, 0.0, -3.0))
	bark_from_oak()   # the bark: a felled oak cut up with the axe (GOALS-REPAIR GA-01)
	fill_water(need_of("leather", "water"))   # the water: a bucket filled at fresh water (GOALS-REPAIR GA-04)
	craft("leather", 1, 60)
	check(have("leather") == 1 and have("processed_hide") == 0, "4a. the dried hide is tanned at the Tanning rack")
	check(items.inventory_of(1).liquid_ml() == 0 and have("bucket") == 1, "4a2. tanning used up the bucket's water; the bucket stays (%d mL left)" % items.inventory_of(1).liquid_ml())
	check(str(items.recipes.recipe(recipe_number("leather_strap")).get("station", "")) == "leatherworking_table", "4b. the Leather strap is a Leatherworking table recipe")
	craft("leather_strap", 1, 30)
	check(have("leather_strap") == 0 and have("leather") == 1, "4c. no Leather strap at the Tanning rack; the leather is kept")
	var bench: int = build("leatherworking_table", HERE + Vector3(3.0, 0.0, 0.0))
	craft("leather_strap", 1, 30)
	check(have("leather_strap") == gives_of("leather_strap") and have("leather") == 0, "4d. the Leatherworking table cuts %d Leather straps" % have("leather_strap"))

	# 5. The Loom and Fibre cloth.
	fibre_before = have("plant_fibre")
	craft("fibre_cloth", 1, 60)
	check(have("fibre_cloth") == 0 and have("plant_fibre") == fibre_before, "5a. no Fibre cloth by hand")
	var loom: int = build("loom", HERE + Vector3(0.0, 0.0, 3.0))
	craft("fibre_cloth", crafts_for("fibre_cloth", cloth_n), 60 * crafts_for("fibre_cloth", cloth_n))
	check(have("fibre_cloth") >= cloth_n, "5b. the Loom weaves %d Fibre cloth" % have("fibre_cloth"))

	# 6. The Tailor's table and a gambeson.
	craft("gambeson", 1, 60)
	check(have("gambeson") == 0 and have("fibre_cloth") >= cloth_n, "6a. no gambeson at the Loom alone")
	var tailor: int = build("tailors_table", HERE + Vector3(-3.0, 0.0, 0.0))
	craft("gambeson", 1, 60)
	check(have("gambeson") == 1 and have("fibre_cloth") == crafts_for("fibre_cloth", cloth_n) * gives_of("fibre_cloth") - cloth_n, "6b. the Tailor's table makes a Fibre - Gambeson")
	check(standing("leatherworking_table") == bench and standing("loom") == loom and standing("tailors_table") == tailor, "6c. all three stations still stand in the world")

	print("textile route: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
