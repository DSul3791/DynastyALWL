extends SceneTree

# Dave 19 Nov 2026 (play test): digging all the dirt from under a tree brought the tree down but left its stump hanging in the air, where no axe could
# reach it. His ruling: "the stump can just break into its components and fall". A stump whose ground is dug away breaks into what chopping it gives
# (drops.json stump) and the pieces come to rest on the ground below; a stump with its ground still under it stays; a stump left over a hole in a
# save breaks on the first rot pass after loading.
#   godot --headless --path . --script res://src/worldgen/tools/test_stump_undermined.gd

const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const FLOOR_Y := 7.5   # the bottom of the dug hole: where pieces let go come to rest

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String, share: Array, standing: Dictionary):
	var w = ItemsScript.new()
	w.send_full = func(_p, _b): pass
	w.send_slots = func(_p, _b): pass
	w.send_world_items = func(_p, _a, _r): pass
	w.setup(ItemTableScript.load_default(), dir)
	w.ground_height = func(_x, _z): return 10.0
	w.floor_below = func(_at): return FLOOR_Y
	w.game_seconds = func(): return 5000.0
	w.dig_ground = func(_c, _r): return true
	w.dig_support = func(_b, _r, _d): return share[0]
	w.trees_near = func(_p, _r): return [[Vector2i.ZERO, 7]] if standing.has(7) else []
	w.tree_info = func(_c, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.3} if standing.has(id) else {}
	w.cut_tree = func(_c, id): standing.erase(id); return true
	w.peer_connected_hello(1, "abcdef123456")
	w.report_position(1, Vector3(8.0, 10.0, 0.0))
	return w


func _init() -> void:
	var dir: String = "user://test_stump_undermined_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(dir)
	var share: Array = [1.0]
	var standing: Dictionary = {7: true}
	var w = make(dir, share, standing)
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_shovel"), 0, 1, Vector3.ZERO)
	w.action(1, Net.ACT_ADMIN_GIVE, w.table.number_of("stone_axe"), 0, 1, Vector3.ZERO)
	check(HeldTool.slot_of(w, "shovel") >= 0, "the test player holds a shovel")

	# 1. A tree dug out from under falls, and its stump breaks up when it lands: no stump is left, its pieces lie at the bottom of the hole.
	share[0] = 0.1
	_dig(w)
	check(not standing.has(7), "the tree with its ground dug away falls")
	var stump: int = _stump(w)
	check(stump != 0 and w._items[stump]["tree"].has("fresh"), "while it comes down its stump is there (the fall plays round it)")
	var before: Dictionary = _wood_counts(w)
	w._fall_tick(5.0)
	check(_stump(w) == 0, "once the tree lands its dug-out stump is gone")
	check(_grown_at_floor(w, before) > 0, "the stump broke into its pieces and they came down to the bottom of the hole, not left in the air")

	# 2. A stump of a tree chopped down normally stays while its ground holds, and breaks once the ground under it is dug away.
	_fell_on_solid(w, standing, share)
	stump = _stump(w)
	check(stump != 0, "an axe-felled tree on solid ground leaves its stump")
	w._sync_world_items()   # the stump is filed in the sync grid: the dig looks only at the grid's cells round the hole (_ids_near)
	check(not w._sync_grid.is_empty(), "the world sync filed its grid")
	share[0] = 0.6
	_dig(w)
	check(w._items.has(stump), "a dig beside it that leaves most of its ground keeps the stump")
	share[0] = 0.1
	before = _wood_counts(w)
	_dig(w)
	check(not w._items.has(stump), "digging the ground from under the stump breaks it")
	check(_grown_at_floor(w, before) > 0, "its pieces fall to the ground below")

	# 2b. A stump made since the last sync (not in the grid yet) is found too.
	_fell_on_solid(w, standing, share)
	stump = _stump(w)
	check(stump != 0 and stump >= w._sync_grid_next, "a new stump stands, made since the grid was filed")
	share[0] = 0.1
	_dig(w)
	check(not w._items.has(stump), "a stump made since the last sync breaks when its ground is dug away")

	# 3. A stump saved over a hole breaks on the first rot pass after loading; one on solid ground stays.
	_fell_on_solid(w, standing, share)
	check(_stump(w) != 0, "a third stump stands for the save")
	w.save()
	var solid: Array = [1.0]
	var r = make(dir, solid, {})
	check(_stump(r) != 0, "the stump loads from the save")
	r._rot(61.0)
	check(_stump(r) != 0, "a loaded stump on solid ground stays")
	var dug: Array = [0.1]
	var r2 = make(dir, dug, {})
	r2._rot(61.0)
	check(_stump(r2) == 0, "a loaded stump with its ground dug away breaks on the first rot pass")
	print("stump undermined tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# Tree 7 stands again and is felled with the axe on solid ground; it lands and leaves its stump.
func _fell_on_solid(w, standing: Dictionary, share: Array) -> void:
	standing[7] = true
	share[0] = 1.0

	for n in range(30):
		if not standing.has(7):
			break

		w._last_hit.clear()
		w.action(1, Net.ACT_HIT, 7, 0, 0, HeldTool.at_axe(w))

	w._fall_tick(5.0)


func _dig(w) -> void:
	w._last_dig.clear()
	w.action(1, Net.ACT_DIG, HeldTool.slot_of(w, "shovel"), 0, 0, Vector3(9.0, 10.0, 0.0))


func _stump(w) -> int:
	for k in w._items:
		if w._items[k].has("tree") and int(w._items[k]["tree"]["state"]) == 4:
			return int(k)

	return 0


func _wood_numbers(w) -> Array:
	var out: Array = []

	for row in w._stump_final_rows(w._drops.get("stump", {}), 0.3):
		out.append(w.table.number_of(str(row[0])))

	return out


# World id -> count of every loose piece of the kinds a stump breaks into.
func _wood_counts(w) -> Dictionary:
	var out: Dictionary = {}
	var numbers: Array = _wood_numbers(w)

	for k in w._items:
		var it: Dictionary = w._items[k]

		if not it.has("tree") and int(it.get("number", 0)) in numbers:
			out[k] = int(it["count"])

	return out


# How many of those piles are new or grew since `before`; -1 when any of them is not at the bottom of the hole.
func _grown_at_floor(w, before: Dictionary) -> int:
	var now: Dictionary = _wood_counts(w)
	var grown: int = 0

	for k in now:
		if int(now[k]) > int(before.get(k, 0)):
			if absf(w._items[k]["pos"].y - FLOOR_Y) > 0.01:
				print("  piece %d at y %.2f, not on the floor" % [k, w._items[k]["pos"].y])
				return -1

			grown += 1

	return grown
