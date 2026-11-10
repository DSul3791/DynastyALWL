extends SceneTree

# The bronze path runs on the live data (Steve 10 Nov 2026, /mnt/project-files/steve/pickaxe_path.md): every step through the real server, the
# real recipes, blueprints and boulders.json, nothing stood in. A step that refuses prints what the server said.
#   1. a Stone - Pickaxe by hand (stick, stone, twine);
#   2. copper ore and tin ore picked out of a copper and a tin outcrop with it (boulders.json piece share as shipped);
#   3. a Stone - Forge from its blueprint with a wooden hammer;
#   4. charcoal at a lit campfire;
#   5. copper and tin ingots smelted at the Stone - Forge;
#   6. bronze ingots; 7. a Bronze - Pickaxe at the forge;
#   8. the bronze pick takes iron ore out of an iron outcrop, which the stone pick cannot.
#   godot --headless --path . --script res://src/worldgen/tools/test_bronze_path.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const HERE := Vector3(700.0, 10.0, 700.0)
const FORGE_AT := Vector3(700.0, 10.0, 702.5)
const FIRE_AT := Vector3(697.5, 10.0, 700.0)
const OUTCROP_AT := Vector3(702.0, 11.0, 699.0)
const OUTCROP_ID := 910001

var failures: int = 0
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", said.slice(maxi(said.size() - 3, 0)) if not said.is_empty() else "nothing")


func have(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func give(id: String, n: int) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, n, Vector3.ZERO)


func recipe_number(id: String) -> int:
	for n in items.recipes.numbers():
		if str(items.recipes.recipe(int(n)).get("id", "")) == id:
			return int(n)

	return 0


# Queues `times` of the recipe and runs the server clock until it is done (or `seconds` pass).
func craft(id: String, times: int, seconds: int) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe_number(id), 0, times, Vector3.ZERO)

	for s in range(seconds):
		items.tick(1.0)


# An outcrop boulder of `ore` (as _lay_out_boulders makes one), hit up to `blows` times or until `want` of `item` are in the pack.
func pick_out(ore: String, item: String, want: int, blows: int) -> void:
	items._items[OUTCROP_ID] = {"number": 0, "count": 5000, "pos": OUTCROP_AT, "left": 1.0e9, "scatter": items.BOULDER_KEY | 11, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 5000, "ore": ore}}

	for k in range(blows):
		if have(item) >= want:
			break

		items._last_hit.clear()
		items.action(1, Net.ACT_HIT, OUTCROP_ID, Net.HIT_BOULDER, 0, Vector3.ZERO)

	items._items.erase(OUTCROP_ID)


func _init() -> void:
	var dir: String = "user://test_bronze_path"
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
	items.peer_connected_hello(1, "bronzepath01")
	items.report_position(1, HERE)
	items.vitals_of(1)["weight"] = 5000.0   # the stones the picks break out are heavy; carrying is not under test
	var shipped_share: float = float(items._boulder_cfg.get("ore", {}).get("piece_share", 0.0))
	check(shipped_share > 0.0, "boulders.json ships an ore piece share (%.2f)" % shipped_share)

	# 1. Stone - Pickaxe by hand.
	give("stick", 2)
	give("stone", 3)
	give("twine", 2)
	craft("stone_pickaxe", 1, 60)
	check(have("stone_pickaxe") == 1, "1. a Stone - Pickaxe is made by hand")

	# 2. Copper and tin ore from outcrops with the stone pick: 2 ingots of each at 3 ore an ingot.
	pick_out("copper", "copper_ore", 6, 600)
	check(have("copper_ore") >= 6, "2a. the stone pick takes 6 copper ore out of a copper outcrop (%d)" % have("copper_ore"))
	pick_out("tin", "tin_ore", 6, 600)
	check(have("tin_ore") >= 6, "2b. and 6 tin ore out of a tin outcrop (%d)" % have("tin_ore"))
	pick_out("iron", "iron_ore", 1, 60)
	check(have("iron_ore") == 0, "2c. it takes no iron ore out of an iron outcrop")

	# 3. Stone - Forge from its blueprint, with the materials its row asks for.
	var forge_bp: Dictionary = {}

	for number in items._blueprints:
		if str(items._blueprints[number].get("structure", "")) == "stone_forge":
			forge_bp = items._blueprints[number]

	check(not forge_bp.is_empty(), "3a. the Stone - Forge has a blueprint")

	if forge_bp.is_empty():
		quit(1)
		return

	give("wooden_hammer", 1)

	for need in forge_bp["cost"]:
		give(str(need[0]), int(need[1]))

	items.action(1, Net.ACT_PLACE_BLUEPRINT, int(forge_bp["number"]), 0, 0, FORGE_AT)
	var forge_id: int = -1

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "stone_forge" and not items._items[id]["struct"].has("site"):
			forge_id = int(id)

	check(forge_id >= 0, "3b. the Stone - Forge stands (a wooden hammer, %s)" % str(forge_bp["cost"]))
	check(items.station_near(1, "forge", 1), "3c. it serves as a forge, level 1")

	# 4. Charcoal at a lit campfire (2 firewood each); 4 fuel for 4 smelts.
	items._items[items._next_id] = {"number": items.table.number_of("campfire_kit"), "count": 1, "pos": FIRE_AT, "left": 1.0e9, "fire": {"state": 1, "burn_left": 1.0e6, "covered": false, "recheck": 5.0}}
	items._next_id += 1
	give("firewood", 8)
	craft("charcoal", 4, 400)
	check(have("charcoal") == 4, "4. 8 firewood make 4 charcoal at the campfire (%d)" % have("charcoal"))

	# 5. Copper and tin ingots at the Stone - Forge, charcoal as the fuel.
	craft("smelt_copper", 2, 400)
	check(have("copper_ingot") == 2, "5a. 6 copper ore and 2 fuel make 2 copper ingots (%d)" % have("copper_ingot"))
	craft("smelt_tin", 2, 400)
	check(have("tin_ingot") == 2, "5b. 6 tin ore and 2 fuel make 2 tin ingots (%d)" % have("tin_ingot"))
	check(have("charcoal") == 0, "5c. the 4 smelts burnt the 4 charcoal (%d left)" % have("charcoal"))

	# 6. Bronze ingots: enough for the pick's 3, at whatever ratio the data has.
	var bronze: Dictionary = items.recipes.recipe(recipe_number("bronze_ingot"))
	var per_craft: int = int(bronze.get("gives", [0, 1])[1]) if not bronze.is_empty() else 1
	var crafts: int = maxi(ceili(3.0 / float(maxi(per_craft, 1))), 1)
	craft("bronze_ingot", crafts, 400)
	check(have("bronze_ingot") >= 3, "6. %d bronze crafts make %d bronze ingots (3 needed)" % [crafts, have("bronze_ingot")])

	# 7. The Bronze - Pickaxe at the forge.
	give("stick", 2)
	craft("bronze_pickaxe", 1, 200)
	check(have("bronze_pickaxe") == 1, "7. a Bronze - Pickaxe is made at the Stone - Forge")
	var inv = items.inventory_of(1)
	var bronze_slot: int = inv.numbers.find(items.table.number_of("bronze_pickaxe"))
	check(bronze_slot >= 0 and inv.on_hotbar(bronze_slot), "7b. it goes on a hotbar key by itself (a new tool)")

	if bronze_slot >= 0 and not inv.on_hotbar(bronze_slot):
		items.action(1, Net.ACT_HOTBAR_SET, 9, items.table.number_of("bronze_pickaxe"), 0, Vector3.ZERO)   # as a player would, so step 8 still runs

	# 8. Iron ore out of an iron outcrop with it.
	pick_out("iron", "iron_ore", 4, 400)
	check(have("iron_ore") >= 4, "8. the bronze pick takes iron ore out of an iron outcrop (%d)" % have("iron_ore"))

	print("test_bronze_path: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
