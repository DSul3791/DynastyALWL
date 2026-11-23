extends SceneTree

# A stack dropped in a building lies on its floor, one dropped on a boulder on the rock (physical world audit, 23 Nov 2026): on a foundation it came down to the ground under it, 0.3 m
# inside the slab, and upstairs it fell through the floor to the ground floor. server_items _drop_height / _settled_loose / _floor_top_below.
#   godot --headless --path . --script res://src/worldgen/tools/test_drop_floor.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const PlacementRules := preload("res://src/shared/placement_rules.gd")

const GROUND := 10.0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func floor_below(from: Vector3) -> float:   # terrain_server._floor_below over flat ground with no digs (5 cm steps: up to 5 cm over it)
	var y: float = from.y + 0.05

	for step in range(480):
		if y < GROUND:
			return y + 0.05

		y -= 0.05

	return NAN


func add_struct(items, id: int, kind: String, pos: Vector3) -> void:
	items._items[id] = {"number": items.table.number_of(str(items._structures[kind]["item"])), "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0, "uid": id}}
	items._grid_add(id, items._items[id])


# Drops `count` stones for peer 1 standing at `feet`, aimed at `at`; the y the new stack lies at.
func drop(items, feet: Vector3, at: Vector3) -> float:
	items._peer_pos[1] = feet
	var stone: int = items.table.number_of("stone")
	var inv = items.inventory_of(1)
	inv.add(stone, 1)
	var before: Array = items._items.keys()
	items._drop(1, inv, inv.numbers.find(stone), 1, at)

	for id in items._items:
		if not before.has(id):
			return float(items._items[id]["pos"].y)

	return NAN


func _init() -> void:
	var dir: String = "user://test_drop_floor"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.setup(ItemTableScript.load_default(), dir)
	items.floor_below = floor_below
	items.ground_height = func(_x, _z): return GROUND
	items.peer_connected_hello(1, "test-drop-floor-01")

	# A foundation at (300, 300), another lifted 1.2 m on a slope at (320, 300), and over the first a floor piece (the storey above) 3 m up.
	add_struct(items, 900, "foundation_section", Vector3(300.0, GROUND, 300.0))
	add_struct(items, 901, "foundation_section", Vector3(320.0, GROUND + 1.2, 300.0))
	add_struct(items, 902, "floor_section", Vector3(300.0, GROUND + 3.0, 300.0))
	var top: float = GROUND + PlacementRules.anchor_top(items._structures["foundation_section"])
	var lifted: float = top + 1.2
	var upstairs: float = GROUND + 3.0 + PlacementRules.anchor_top(items._structures["floor_section"])

	check(absf(drop(items, Vector3(300.5, top, 300.5), Vector3(301.0, top, 301.0)) - top) < 0.01, "dropped on a foundation: on its top (%.2f), not inside it" % top)
	check(absf(drop(items, Vector3(320.5, lifted, 300.5), Vector3(321.0, lifted, 300.0)) - lifted) < 0.01, "on a foundation lifted on a slope: on its top (%.2f)" % lifted)
	check(absf(drop(items, Vector3(300.5, upstairs, 299.0), Vector3(299.0, upstairs, 299.0)) - upstairs) < 0.01, "upstairs: on the floor there (%.2f), not the ground floor" % upstairs)
	var below: float = drop(items, Vector3(298.6, top, 301.4), Vector3(298.6, top, 301.4))
	check(absf(below - top) < 0.01, "on the ground floor under the storey above: the foundation, not the floor overhead (%.2f)" % below)
	var beside: float = drop(items, Vector3(310.0, GROUND, 310.0), Vector3(310.5, GROUND, 310.0))
	check(absf(beside - GROUND) < 0.06, "on open ground beside them: the ground (%.2f)" % beside)

	# Ground dug or filled nearby settles loose items again: one on the foundation stays on it.
	var on_slab: Array = []

	for id in items._items:
		if not items._items[id].has("struct") and absf(float(items._items[id]["pos"].y) - top) < 0.01 and Vector2(items._items[id]["pos"].x - 300.0, items._items[id]["pos"].z - 300.0).length() < 2.5:
			on_slab.append(id)

	items.settle_loose_near(Vector3(301.0, GROUND, 301.0), 3.0)
	check(not on_slab.is_empty() and on_slab.all(func(id): return absf(float(items._items[id]["pos"].y) - top) < 0.01), "a dig nearby leaves a stack on the foundation on its top")

	# Over a floor piece taken down the next drop comes down to the ground floor (nothing is kept of it).
	items._items.erase(902)
	check(absf(drop(items, Vector3(299.0, upstairs, 299.0), Vector3(299.0, upstairs, 299.0)) - top) < 0.01, "with the storey's floor gone a drop up there comes down to the foundation")
	# Standing on a boulder (radius 1 m, whole): the stack lies on the rock's drawn top, not inside it; off its edge, on the ground.
	items._items[950] = {"number": 0, "count": 800, "pos": Vector3(340.0, GROUND, 300.0), "left": 1.0e9, "scatter": 1, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 800}}
	var rock_top: float = GROUND + ItemsScript.BOULDER_TOP_SHARE
	var on_rock: float = drop(items, Vector3(340.0, rock_top, 300.0), Vector3(340.0, rock_top, 300.0))
	check(absf(on_rock - rock_top) < 0.01, "on a boulder: on its top (%.2f), not inside the rock" % on_rock)
	var by_rock: float = drop(items, Vector3(342.0, GROUND, 302.0), Vector3(342.0, GROUND, 302.0))
	check(absf(by_rock - GROUND) < 0.06, "beside it: the ground (%.2f)" % by_rock)
	print("drop floor test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
