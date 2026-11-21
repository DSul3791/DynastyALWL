extends SceneTree

# The slow tick's lists (audit 18 Nov 2026 finding 3): each part walks its own list of items instead of every world item. An item is on a list
# by what it is, never by a state that changes in place. This test runs two copies of the same world side by side, one on the lists and one on
# the old walk over every item (_tick_lists_off), through every state a fire, a light, a kiln, a smelter, a pot and an item's lifetime pass
# (a lit fire burns down to coals, warm ash, cold and is cleared; a torch is lit in place and burns out; a kept pile is given a lifetime in place
# and ages away; rain comes and goes), and compares every item after each slow tick. Then the small cases: a fire lit since the last full
# sort burns on the next tick, an item gone from the world is skipped.
#   godot --headless --path . --script res://src/worldgen/tools/test_tick_lists.gd      Prints "Test done: N pass, N fail".

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var passes: int = 0
var failures: int = 0
var raining: float = 0.0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func make(dir: String, off: bool):
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	items.rain_now = func(): return raining
	items.setup(ItemTableScript.load_default(), dir)
	items._dir = ""   # nothing is saved: the two copies must not share files
	items._tick_lists_off = off
	return items


# The world as a list of its items without their ids (ids made while ticking can come in another order), sorted.
func picture(items) -> Array:
	var out: Array = []

	for id in items._items:
		out.append(var_to_str(items._items[id]))

	out.sort()

	for uid in items._chests:   # the stores too (a fire's wood, a kiln's logs and charcoal); uids come in the same order in both
		out.append("%d %s" % [int(uid), str(items._chests[uid].to_bytes())])

	return out


# The same things in both copies: fires in each state, lights lit and unlit, kilns, smelters, a smithy, a pot over a fire, items with
# lifetimes, a kept pile.
func seed_world(items) -> Dictionary:
	var ids: Dictionary = {}
	ids["fire_log"] = items.dev_place("campfire@20,20,0,lit,log")
	ids["fire_weak"] = items.dev_place("campfire@40,20,0,lit")
	ids["fire_laid"] = items.dev_place("campfire@60,20,0")
	ids["coals"] = items.dev_place("campfire@80,20,0,coals")
	ids["ash"] = items.dev_place("campfire@100,20,0,ash")
	ids["pot"] = items.dev_place("campfire_pot@20,20,0")

	for kind in ["standing_torch", "wall_torch", "chandelier", "fireplace", "iron_hanging_lantern", "stone_brazier", "kiln", "smelter", "large_forge"]:   # a smithy is never lit (Dave 21 Nov 2026: it works on its fuel slot)
		ids[kind + "_lit"] = items.dev_place("%s@%d,60,0,lit" % [kind, 20 + 20 * ids.size()])
		ids[kind] = items.dev_place("%s@%d,80,0" % [kind, 20 + 20 * ids.size()])

	var stone: int = items.table.number_of("stone")
	items.drop_in_world(stone, 3, Vector3(10.0, 10.0, 140.0), 0, 900.0)       # ages away
	items.drop_in_world(stone, 2, Vector3(30.0, 10.0, 140.0), 0, 30000.0)
	items.drop_in_world(stone, 12, Vector3(50.0, 10.0, 140.0), 0, 1.0e9)      # a kept pile
	return ids


func _init() -> void:
	var lists = make("user://test_tick_lists_a", false)
	var walk = make("user://test_tick_lists_b", true)
	var ids_a: Dictionary = seed_world(lists)
	var ids_b: Dictionary = seed_world(walk)
	check(ids_a == ids_b, "both copies are seeded alike (%d things)" % ids_a.size())
	var states: Dictionary = {}
	var differ_at: int = -1
	var stone: int = lists.table.number_of("stone")
	var steps: int = 1600   # 60 s a slow tick: about 27 game hours, past coals (2 h) and warm ash (12 h)

	for step in steps:
		raining = 1.0 if step == 40 or (step >= 900 and step < 920) else 0.0   # a shower while lights and open fires burn (an open fire rained out is laid, 9, and
		                                                                       # never reaches coals: the dev coals fire shows those), and rain on warm ash later

		for w in [lists, walk]:
			if step == 5 and w._items.has(int(ids_a["standing_torch"])):
				var torch: Dictionary = w._items[int(ids_a["standing_torch"])]
				torch["struct"]["lit"] = true   # lit in place, between full sorts
				torch["struct"]["fuel_left"] = 600.0
				w._lit_valid = false

			if step == 7:
				w.drop_in_world(stone, 1, Vector3(50.0, 10.0, 140.0), 0, 1200.0)   # onto the kept pile: it is given a lifetime in place

			w.tick(60.0)

		for name in ["fire_log", "fire_weak", "coals"]:
			if lists._items.has(int(ids_a[name])):
				states[int(lists._items[int(ids_a[name])]["fire"]["state"])] = true

		if differ_at < 0 and picture(lists) != picture(walk):
			differ_at = step
			var pa: Array = picture(lists)
			var pb: Array = picture(walk)

			for k in mini(pa.size(), pb.size()):
				if pa[k] != pb[k]:
					print("tick lists: first difference at tick %d:\n  lists: %s\n  walk:  %s" % [step, str(pa[k]).left(400), str(pb[k]).left(400)])
					break

			if pa.size() != pb.size():
				print("tick lists: %d items on the lists, %d on the walk" % [pa.size(), pb.size()])

	check(differ_at < 0, "the lists and the old walk leave every item the same after every slow tick (first difference at tick %d)" % differ_at)
	check(states.has(ItemsScript.FIRE_STATE_COALS) and states.has(ItemsScript.FIRE_STATE_ASH), "the fires went through coals and warm ash (states seen %s)" % str(states.keys()))
	check(not lists._items.has(int(ids_a["coals"])) and not lists._items.has(int(ids_a["ash"])), "fires left as coals and warm ash are cleared away in time")
	check(not lists._items.has(int(ids_a["standing_torch"])) or not bool(lists._items[int(ids_a["standing_torch"])]["struct"].get("lit", false)), "the torch lit in place burned out")
	var pile_left: bool = false

	for id in lists._items:
		pile_left = pile_left or (int(lists._items[id]["number"]) == stone and lists._items[id]["pos"].distance_to(Vector3(50.0, 10.0, 140.0)) < 1.0)

	check(not pile_left, "the kept pile given a lifetime in place aged away")

	# A fire lit since the last full sort burns on the next tick; an item gone from the world is skipped; an item made by an earlier part of
	# a tick (a lit brazier's charcoal) ages in that same tick, as with the full walk.
	var items = make("user://test_tick_lists_a", false)

	for step in 4:
		items.tick(0.25)   # the lists are sorted

	items._tick_ids = items._tick_index()   # as the tick does at its start
	var made: int = items._next_id
	items.drop_in_world(stone, 1, Vector3(200.0, 10.0, 200.0), 0, 500.0)   # made mid-tick, after the lists were taken
	var left0: float = float(items._items[made]["left"])
	items._expire_items(10.0)
	items._tick_ids = {}
	check(items._items.has(made) and is_equal_approx(float(items._items[made]["left"]), left0 - 10.0), "an item made earlier in the tick ages in the same tick (%.1f -> %.1f)" % [left0, float(items._items[made]["left"]) if items._items.has(made) else -1.0])

	var fire: int = items.dev_place("campfire@20,20,0,lit")
	var burn0: float = float(items._items[fire]["fire"]["burn_left"])

	for step in 4:
		items.tick(0.25)

	check(float(items._items[fire]["fire"]["burn_left"]) < burn0, "a fire lit since the last full sort burns on the next ticks (%.2f -> %.2f)" % [burn0, float(items._items[fire]["fire"]["burn_left"])])
	items._items.erase(fire)
	items.tick(0.25)
	check(not items._items.has(fire), "an item gone from the world is skipped by its list")
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
