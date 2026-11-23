extends SceneTree

# The fishing loop, over server restarts (the coordinator, 23 Nov 2026): a hook from bone, line from sinew, a rod from sticks, line and the
# hook, and a fish trap from sticks and line, all by hand from live recipes; a cast, a bite and a second click land a fish; the fish is one
# that lives in that water (brook, lake, river, sea) whether or not the line is in a school; a fish trap set in a river fishes each game
# hour, and after a restart it is still there with its catch and goes on fishing; Fishing practice is kept; a fish roasts on the campfire
# to a roast that keeps longer, and the smoker and the pot keep fish for days. The bite sound (#1720) is the sound thread's and not tested here.
#   godot --headless --path . --script res://src/worldgen/tools/test_fishing_loop.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")

const DIR := "user://test_fishing_loop"
const KEY := "fishloop-key-00001"
const SHORE := Vector3(5.0, 10.0, 5.0)
const DRY_X := 60.0   # land from here east: the campfire goes here

var failures: int = 0
var passes: int = 0
var clock: Array = [1.0e9]                                    # unix seconds (the fish stock clock)
var game: Array = [100.0 * 86400.0 + 12.0 * 3600.0]          # game seconds (the trap's hours)
var kind_here: Array = ["brook"]                              # the water kind every water point answers
var said: Array = []
var fish_ids: Array = []


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1

	print(("ok   " if ok else "FAIL ") + what)


func start(wipe: bool):
	DirAccess.make_dir_recursive_absolute(DIR)

	if wipe:
		for sub in ["", "/world_items"]:
			DirAccess.make_dir_recursive_absolute(DIR + sub)

			for file in DirAccess.get_files_at(DIR + sub):
				DirAccess.remove_absolute(DIR + sub + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.unix_now = func(): return clock[0]
	items.game_seconds = func(): return game[0]
	items.ground_height = func(_x, _z): return 10.0
	items.water_near = func(p, _r): return p.x < DRY_X
	items.water_depth_at = func(p): return 0.6 if p.x < DRY_X else 0.0
	items.water_kind_at = func(x, _z): return {"kind": kind_here[0] if x < DRY_X else "", "depth": 0.6 if x < DRY_X else 0.0}
	items.setup(ItemTableScript.load_default(), DIR)
	items.peer_connected_hello(1, KEY)
	items.set_fitness(1, 50)
	items.report_position(1, SHORE)
	items._moving[1] = 0.0
	return items


func save(items) -> void:
	items._dirty = true
	items.save()
	items._finish_writer()


func n(items, id: String) -> int:
	return items.table.number_of(id)


func have(items, id: String) -> int:
	return items.inventory_of(1).count_of(n(items, id))


func craft(items, recipe_id: String, count: int = 1) -> void:
	var all: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/recipes.json")) as Dictionary)["recipes"]
	var rec: Dictionary = all[recipe_id]
	var number: int = int(rec["number"])
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, number, 0, count, CraftHand.at(items, 1, number))

	for k in int(ceil(float(rec["craft_s"]) * count)) + 3:
		items.tick(1.0)


func fish_count(items) -> int:
	var got: int = 0

	for id in fish_ids:
		got += have(items, id)

	return got


# One cast, a forced bite and the second click: the species landed ("" when nothing came in).
func land_one(items) -> String:
	var rod_slot: int = items.inventory_of(1).numbers.find(n(items, "fishing_rod"))
	var cell: Vector2i = items._fish_cell(SHORE)
	items._fish_stock["%d,%d" % [cell.x, cell.y]] = [12, clock[0]]
	var before: Dictionary = {}

	for id in fish_ids:
		before[id] = have(items, id)

	items._last_fish.clear()
	items.action(1, Net.ACT_FISH, rod_slot, 0, 0, Vector3.ZERO)

	if not items._fishing.has(1):
		return ""

	items._fishing[1]["bites"] = true
	items._fishing[1]["at"] = Time.get_ticks_msec() - 1
	items._fish_tick()
	items.action(1, Net.ACT_FISH, rod_slot, 0, 0, Vector3.ZERO)

	for id in fish_ids:
		if have(items, id) > int(before[id]):
			items.inventory_of(1).remove(n(items, id), have(items, id))   # eaten, so a long run of casts never fills the pack
			return id

	return ""


func lives_in(items, species: String, kind: String) -> bool:
	for row in items._fish_schools().cfg.get("species_by_kind", {}).get(kind, []):
		if str(row[0]) == species:
			return true

	return false


func _init() -> void:
	var items = start(true)
	var fishing: Dictionary = items._fishing_data()

	for water in fishing.get("species", {}):
		for row in fishing["species"][water]:
			if not fish_ids.has(str(row[0])):
				fish_ids.append(str(row[0]))

	for water in items._fish_schools().cfg.get("species_by_kind", {}):
		for row in items._fish_schools().cfg["species_by_kind"][water]:
			if not fish_ids.has(str(row[0])):
				fish_ids.append(str(row[0]))

	for id in fish_ids:
		check(n(items, id) != 0, "fish %s is a real item" % id)

	# 1. Making, by hand from live recipes: hook from bone, line from sinew, the rod, the fish trap.
	items.give(1, n(items, "bone"), 1)
	craft(items, "hook")
	check(have(items, "hook") == 1 and have(items, "bone") == 0, "1. a bone grinds to a hook")
	items.give(1, n(items, "sinew"), 3)
	craft(items, "sinew_cord")
	check(have(items, "twine") == 2, "1. three sinew twist to two line (%d)" % have(items, "twine"))
	items.give(1, n(items, "stick"), 2)
	craft(items, "fishing_rod")
	check(have(items, "fishing_rod") == 1 and have(items, "hook") == 0 and have(items, "twine") == 0, "1. sticks, line and the hook make a fishing rod")
	items.give(1, n(items, "stick"), 10)
	items.give(1, n(items, "twine"), 4)
	craft(items, "fish_trap")
	check(have(items, "fish_trap") == 1, "1. ten sticks and four line make a fish trap by hand (the recipe is live, not locked)")
	check(not bool(items.table.entry("fish_trap").get("future", false)) and not bool(items.table.entry("bird_trap").get("future", false)), "1. the Fish trap and the Bird trap are live items")
	check(bool(items.recipes.recipe(391).get("known", false)) and not bool(items.recipes.recipe(391).get("locked", true)), "1. the Bird trap recipe is known and not locked")

	# 2. Cast, bite, land, and the fish lives in that water.
	var rod_slot: int = items.inventory_of(1).numbers.find(n(items, "fishing_rod"))
	items.report_position(1, Vector3(DRY_X + 40.0, 10.0, 5.0))
	items._last_fish.clear()
	said.clear()
	items.action(1, Net.ACT_FISH, rod_slot, 0, 0, Vector3.ZERO)
	check(not items._fishing.has(1) and said.has(str(fishing["say_no_water"])), "2. no water, no cast, and it says so")
	items.report_position(1, SHORE)
	items._last_fish.clear()
	said.clear()
	items.action(1, Net.ACT_FISH, rod_slot, 0, 0, Vector3.ZERO)
	check(items._fishing.has(1) and said.has(str(fishing["say_cast"])), "2. a cast goes out")
	items._fishing[1]["bites"] = true
	items._fishing[1]["at"] = Time.get_ticks_msec() - 1
	items._fish_tick()
	check(str(items._fishing[1]["phase"]) == "bite", "2. something bites")
	var before_fish: int = fish_count(items)
	items.action(1, Net.ACT_FISH, rod_slot, 0, 0, Vector3.ZERO)
	check(fish_count(items) == before_fish + 1, "2. the second click lands it")
	var fish_skill: float = float(items._skill_records(1).get("fishing", {}).get("p", 0.0))
	check(fish_skill > 0.0, "2. landing a fish trains Fishing (%.3f)" % fish_skill)

	for pass_ in ["brook", "lake", "river", "pond", "sea_shallow", "river no school", "sea_shallow no school", "brook no school"]:
		var kind: String = pass_.get_slice(" ", 0)
		kind_here[0] = kind
		items._schools = null   # its placements are cached by cell and day; a new water kind is a new map

		if pass_.ends_with("no school"):
			items._fish_schools().cfg["count_weights"] = [1.0, 0.0, 0.0, 0.0]   # no school anywhere: the line is out in open water
		var landed: Dictionary = {}
		var wrong: Array = []

		for k in 24:
			var got: String = land_one(items)

			if got != "":
				landed[got] = int(landed.get(got, 0)) + 1

				if not lives_in(items, got, kind) and not wrong.has(got):
					wrong.append(got)

		if landed.is_empty():
			print("  said: ", said.slice(-4))

		check(not landed.is_empty() and wrong.is_empty(), "2. every fish landed from %s water lives there (%s%s)" % [pass_, str(landed), (", wrong: " + str(wrong)) if not wrong.is_empty() else ""])

	# 3. A fish trap set in a river fishes each game hour, and keeps its catch over a restart.
	kind_here[0] = "river"
	items._schools = null
	var trap_at: Vector3 = SHORE + Vector3(2.0, 0.0, 0.0)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(n(items, "fish_trap")), 0, 0, trap_at)
	var trap_id: int = -1

	for id in items._items:
		if str(items._items[id].get("struct", {}).get("kind", "")) == "fish_trap_set":
			trap_id = id

	check(trap_id >= 0 and have(items, "fish_trap") == 0, "3. the fish trap is set in 0.6 m of water")

	if trap_id < 0:
		print("Test done: %d pass, %d fail" % [passes, failures + 1])
		quit(1)
		return

	var trap_cell: Vector2i = items._fish_cell(items._items[trap_id]["pos"])
	items._fish_stock["%d,%d" % [trap_cell.x, trap_cell.y]] = [12, clock[0]]
	fishing["trap"]["hour_chance"] = 1.0
	game[0] += 3600.0
	items._fish_traps_tick()   # the first look notes the trap (the traps are looked over every ten game minutes)
	game[0] += 3600.0
	items._fish_traps_tick()
	var box = items._chests[int(items._items[trap_id]["struct"]["uid"])]
	var in_trap: Array = []

	for slot in box.slot_count:
		for k in (box.counts[slot] if box.numbers[slot] != 0 else 0):
			in_trap.append(items.table.id_of(box.numbers[slot]))

	if in_trap.is_empty():
		print("  trap: ", items._items[trap_id], " stock ", items.fish_stock(trap_cell), " rolled ", items._trap_rolled)

	check(in_trap.size() == 1, "3. after a game hour the trap holds a fish (%s)" % str(in_trap))
	check(in_trap.size() == 1 and lives_in(items, str(in_trap[0]), "river"), "3. and it is a river fish (%s)" % str(in_trap))
	var held: String = str(in_trap[0]) if not in_trap.is_empty() else ""
	var trap_pos: Vector3 = items._items[trap_id]["pos"]
	save(items)

	items = start(false)
	fishing = items._fishing_data()
	var again: int = -1

	for id in items._items:
		if str(items._items[id].get("struct", {}).get("kind", "")) == "fish_trap_set" and (items._items[id]["pos"] as Vector3).distance_to(trap_pos) < 0.1:
			again = id

	check(again >= 0, "3. after a restart the fish trap is still in the river")

	if again >= 0:
		box = items._chests[int(items._items[again]["struct"]["uid"])]
		var kept: Array = []

		for slot in box.slot_count:
			for k in (box.counts[slot] if box.numbers[slot] != 0 else 0):
				kept.append(items.table.id_of(box.numbers[slot]))

		check(kept == [held], "3. with its fish still in it (%s, was %s)" % [str(kept), held])
		fishing["trap"]["hour_chance"] = 1.0
		items._fish_stock["%d,%d" % [trap_cell.x, trap_cell.y]] = [12, clock[0]]
		game[0] += 3600.0
		items._fish_traps_tick()
		game[0] += 3600.0
		items._fish_traps_tick()
		var now_in: int = 0

		for slot in box.slot_count:
			now_in += box.counts[slot] if box.numbers[slot] != 0 else 0   # two of one kind share a slot

		check(now_in == 2, "3. and it goes on fishing after the restart (%d in it)" % now_in)
		check(items._chest_of(1, again) == box, "3. E opens it to take the catch")

	check(float(items._skill_records(1).get("fishing", {}).get("p", 0.0)) >= fish_skill - 0.01, "3. Fishing practice is kept over the restart")
	check(have(items, "fishing_rod") == 1, "3. the rod is still in the pack")

	# 4. Cooking and keeping: a fish roasts on the campfire; the roast keeps longer; the smoker and the pot keep fish for days.
	var fire_spot: Vector3 = Vector3(DRY_X + 10.0, 10.0, 5.0)
	items.report_position(1, fire_spot + Vector3(1.5, 0.0, 0.0))
	items.give(1, n(items, "campfire_kit"), 1)
	items.give(1, n(items, "plant_fibre"), 4)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(n(items, "campfire_kit")), 0, 0, fire_spot)
	var fire: int = -1

	for id in items._items:
		if items._items[id].has("fire"):
			items.action(1, Net.ACT_LIGHT, id, 0, 0, Vector3.ZERO)
			fire = id

	if fire < 0:
		print("  said: ", said.slice(-4))

	check(fire >= 0 and ItemsScript.fire_is_lit(int(items._items[fire]["fire"]["state"])), "4. a campfire burns on the bank")
	var trout_before: int = have(items, "trout")
	items.give(1, n(items, "trout"), 1)
	var roast_before: int = have(items, "roast_fish")
	items._last_cook.clear()
	items.action(1, Net.ACT_COOK, fire, 0, 0, Vector3.ZERO)
	check(have(items, "roast_fish") == roast_before + 1 and have(items, "trout") == trout_before, "4. a trout roasts to roast fish on the campfire")
	var cooking: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/cooking.json"))
	var uncooked: Array = []

	for id in fish_ids:
		if str(cooking.get("cooks_into", {}).get(id, "")) != "roast_fish":
			uncooked.append(id)

	check(uncooked.is_empty(), "4. every fish roasts to roast fish (%s do not)" % str(uncooked))
	check(items.table.shelf_units(n(items, "roast_fish")) > items.table.shelf_units(n(items, "trout")), "4. roast fish keeps longer than raw")
	check(items.table.shelf_units(n(items, "smoked_fish")) > items.table.shelf_units(n(items, "roast_fish")) and items.table.shelf_units(n(items, "salted_fish")) > items.table.shelf_units(n(items, "roast_fish")), "4. smoked and salted fish keep longer still")
	var smoked: Dictionary = items.recipes.recipe(112)
	var fish_group: PackedInt32Array = items.table.group_members(n(items, "fish"))
	var all_in: bool = true

	for id in fish_ids:
		all_in = all_in and fish_group.has(n(items, id))

	check(str(smoked.get("station", "")) == "smoker" and all_in, "4. the smoker takes any fish with sea salt")
	check(n(items, "sea_salt") != 0 and n(items, "smoker") != 0, "4. sea salt and the smoker are real items")

	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
