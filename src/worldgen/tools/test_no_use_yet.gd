extends SceneTree

# Things a player can get that did nothing (coordinator 23 Nov 2026: "a tester who crafts fodder or builds a trough and finds it does nothing
# will file it as a bug"): make the small, obvious ones work, mark the rest where the player sees it.
#   1. Amadou ("takes a spark and holds an ember") is tinder: it lights warm ash like tinder fungus, and is used up.
#   2. The raw greens whose text says "eaten raw" or "eaten fresh" can be eaten (40 kcal, as fiddleheads).
#   3. The rapier moves (skills.json "placeholder") say "planned" in the skills screen; nothing practises them yet.
#   4. Every shield blocks (items.json block) and its text says how much.
#   5. Comfrey roots, "not for eating", cannot be eaten. (Materials with no use: tools/progression_check.py --unmarked, run by merge_check.)
#   godot --headless --path . --script res://src/worldgen/tools/test_no_use_yet.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const VitalsRules := preload("res://src/shared/vitals_rules.gd")

const DIR := "user://test_no_use_yet"
const GREENS := ["wild_garlic_leaves", "dandelion_leaves", "sorrel_leaves", "watercress", "samphire", "angelica_stems"]

var failures: int = 0
var items
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func n(id: String) -> int:
	return items.table.number_of(id)


func slot_of(id: String) -> int:
	var inv = items.inventory_of(1)

	for s in inv.slot_count:
		if inv.numbers[s] == n(id):
			return s

	return -1


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), DIR)
	items.peer_connected_hello(1, "nouseyet0000001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	var inv = items.inventory_of(1)
	items.vitals_of(1)["weight"] = 1.0e6   # the pack's carry limit is not what is tested

	# 1. Amadou is tinder.
	check(n("amadou") > 0 and (items._cooking.get("tinder_also", []) as Array).has("amadou"), "amadou is one of the tinders (cooking.json tinder_also)")
	items.give(1, n("amadou"), 2)
	var fire: Dictionary = {"uid": 0, "synced": false}
	check(items._use_tinder(fire, inv) and inv.count_of(n("amadou")) == 1, "lighting warm ash takes one amadou from the pack")

	# 2. Raw greens are food.
	for id in GREENS:
		check(n(id) > 0 and VitalsRules.food_value(id, items._vitals_cfg) > 0, "%s can be eaten (%d kcal)" % [id, VitalsRules.food_value(id, items._vitals_cfg)])

	items.give(1, n("watercress"), 3)
	said.clear()
	items._last_eat.clear()
	items.vitals_of(1)["fed"] = 0.0
	items._eat(1, inv, slot_of("watercress"))
	var fed: float = float(items.vitals_of(1)["fed"])
	check(inv.count_of(n("watercress")) == 2 and fed > 0.0 and not said.has("You cannot eat that."), "eating watercress takes one and feeds (%.0f kcal; %s)" % [fed, str(said)])

	# 3. Placeholder skills are marked planned in the skills screen.
	var skills: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/skills.json"))["skills"]
	var screen: String = FileAccess.get_file_as_string("res://src/client/character_screen.gd")
	var planned: Array = []

	for id in skills:
		if bool(skills[id].get("placeholder", false)):
			planned.append(id)

	check(planned.size() >= 4 and screen.contains("planned: nothing practises it yet"), "the skills screen source marks %s as planned (a source check: no UI here)" % ", ".join(planned))

	# 4. Every shield says what its raised block stops (test_shield_block.gd plays it).
	var shields: Array = []

	for id in JSON.parse_string(FileAccess.get_file_as_string("res://data/items/items.json"))["items"].keys():
		if str(items.table.entry(id).get("tool_class", "")) == "shield":
			shields.append(id)

	check(shields.size() >= 6, "%d shields found" % shields.size())

	for id in shields:
		var share: int = int(round(float(items.table.entry(id).get("block", 0.0)) * 100.0))
		check(share > 0 and str(items.table.entry(id).get("description", "")).contains("Raised, it stops %d%% of a frontal blow." % share), "%s blocks %d%% and says so" % [id, share])

	# 5. Comfrey roots ("not for eating") are not food, though their id ends with "roots".
	check(VitalsRules.food_value("comfrey_roots", items._vitals_cfg) == 0, "comfrey roots cannot be eaten")

	items._finish_writer()
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
