extends SceneTree

# A stack dropped in a building lies on its floor, one dropped on a boulder on the rock (physical world audit, 23 Nov 2026): on a foundation it came
# down to the ground under it, 0.3 m inside the slab, upstairs it fell through the floor to the ground floor, on a boulder it lay inside the rock.
# What lay on a floor or rock comes down when that goes. server_items _drop_height / _settled_loose / _floor_top_below / _resettle_on.
# Run twice: before any sync (every record is looked at) and with the records filed in the sync grid, as on a running server.
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


# Files every record in the NEAR_M sync grid, as _sync_world_items does on a full sync.
func file_grid(items) -> void:
	var grid: Dictionary = {}

	for id in items._items:
		var cell: Vector2i = Vector2i(int(floor(items._items[id]["pos"].x / ItemsScript.NEAR_M)), int(floor(items._items[id]["pos"].z / ItemsScript.NEAR_M)))

		if not grid.has(cell):
			grid[cell] = []

		grid[cell].append(id)

	items._sync_grid = grid
	items._sync_grid_next = items._next_id


# Drops one of `item` for peer 1 standing at `feet`, aimed at `at`; the new stack's world id.
func drop_id(items, feet: Vector3, at: Vector3, item: String = "stone") -> int:
	items._peer_pos[1] = feet
	var number: int = items.table.number_of(item)
	var inv = items.inventory_of(1)
	inv.add(number, 1)
	var before: Array = items._items.keys()
	items._drop(1, inv, inv.numbers.find(number), 1, at)

	for id in items._items:
		if not before.has(id):
			return id

	return -1


func drop(items, feet: Vector3, at: Vector3) -> float:
	var id: int = drop_id(items, feet, at)
	return float(items._items[id]["pos"].y) if id >= 0 else NAN


func make(dir: String):
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
	return items


func run(filed: bool) -> void:
	var how: String = " (sync grid)" if filed else ""
	var items = make("user://test_drop_floor" + ("_grid" if filed else ""))

	# A foundation at (300, 300), another lifted 1.2 m on a slope at (320, 300), over the first a floor piece (the storey above) 3 m up, a blueprint
	# site for a foundation at (330, 330), and a boulder (radius 1 m, whole) at (340, 300).
	add_struct(items, 900, "foundation_section", Vector3(300.0, GROUND, 300.0))
	add_struct(items, 901, "foundation_section", Vector3(320.0, GROUND + 1.2, 300.0))
	add_struct(items, 902, "floor_section", Vector3(300.0, GROUND + 3.0, 300.0))
	add_struct(items, 903, "foundation_section", Vector3(330.0, GROUND, 330.0))
	items._items[903]["struct"]["site"] = {"have": {}}
	items._items[950] = {"number": 0, "count": 800, "pos": Vector3(340.0, GROUND, 300.0), "left": 1.0e9, "scatter": 1, "boulder": {"radius": 1.0, "yaw": 0.0, "total": 800}}

	if filed:
		file_grid(items)

	var top: float = GROUND + PlacementRules.anchor_top(items._structures["foundation_section"])
	var lifted: float = top + 1.2
	var upstairs: float = GROUND + 3.0 + PlacementRules.anchor_top(items._structures["floor_section"])
	var rock_top: float = GROUND + ItemsScript.BOULDER_TOP_SHARE

	check(absf(drop(items, Vector3(300.5, top, 300.5), Vector3(301.0, top, 301.0)) - top) < 0.01, "dropped on a foundation: on its top (%.2f), not inside it%s" % [top, how])
	check(absf(drop(items, Vector3(320.5, lifted, 300.5), Vector3(321.0, lifted, 300.0)) - lifted) < 0.01, "on a foundation lifted on a slope: on its top (%.2f)%s" % [lifted, how])
	var up_id: int = drop_id(items, Vector3(300.5, upstairs, 299.0), Vector3(299.0, upstairs, 299.0))
	check(up_id >= 0 and absf(float(items._items[up_id]["pos"].y) - upstairs) < 0.01, "upstairs: on the floor there (%.2f), not the ground floor%s" % [upstairs, how])
	var below: float = drop(items, Vector3(298.6, top, 301.4), Vector3(298.6, top, 301.4))
	check(absf(below - top) < 0.01, "on the ground floor under the storey above: the foundation, not the floor overhead (%.2f)%s" % [below, how])
	var beside: float = drop(items, Vector3(310.0, GROUND, 310.0), Vector3(310.5, GROUND, 310.0))
	check(absf(beside - GROUND) < 0.06, "on open ground beside them: the ground (%.2f)%s" % [beside, how])
	var site: float = drop(items, Vector3(330.0, top, 330.0), Vector3(330.0, top, 330.0))
	check(absf(site - GROUND) < 0.06, "on a foundation's blueprint site: the ground, a site holds nothing up (%.2f)%s" % [site, how])
	var rock_id: int = drop_id(items, Vector3(340.0, rock_top, 300.0), Vector3(340.0, rock_top, 300.0))
	check(rock_id >= 0 and absf(float(items._items[rock_id]["pos"].y) - rock_top) < 0.01, "on a boulder: on its top (%.2f), not inside the rock%s" % [rock_top, how])
	var by_rock: float = drop(items, Vector3(342.0, GROUND, 302.0), Vector3(342.0, GROUND, 302.0))
	check(absf(by_rock - GROUND) < 0.06, "beside the boulder: the ground (%.2f)%s" % [by_rock, how])

	# Ground dug or filled nearby settles loose items again: one on the foundation stays on it.
	var on_slab: Array = []

	for id in items._items:
		if not items._items[id].has("struct") and not items._items[id].has("boulder") and absf(float(items._items[id]["pos"].y) - top) < 0.01 and Vector2(items._items[id]["pos"].x - 300.0, items._items[id]["pos"].z - 300.0).length() < 2.5:
			on_slab.append(id)

	items.settle_loose_near(Vector3(301.0, GROUND, 301.0), 3.0)
	check(not on_slab.is_empty() and on_slab.all(func(id): return absf(float(items._items[id]["pos"].y) - top) < 0.01), "a dig nearby leaves a stack on the foundation on its top%s" % how)

	# The floor upstairs is taken down: the stack on it comes down to the foundation (_resettle_on, as _take_down calls it).
	items._items.erase(902)
	items._resettle_on(Vector3(300.0, GROUND + 3.0, 300.0), ItemsScript.FLOOR_ROWS_REACH_M)
	check(absf(float(items._items[up_id]["pos"].y) - top) < 0.01, "the storey's floor taken down: the stack on it comes down to the foundation (%.2f)%s" % [float(items._items[up_id]["pos"].y), how])
	check(absf(drop(items, Vector3(301.5, upstairs, 298.5), Vector3(301.5, upstairs, 298.5)) - top) < 0.01, "and a drop up there comes down to the foundation%s" % how)

	# The foundation goes too: the stacks on it come down to the ground.
	items._items.erase(900)
	items._resettle_on(Vector3(300.0, GROUND, 300.0), ItemsScript.FLOOR_ROWS_REACH_M)
	check(on_slab.all(func(id): return absf(float(items._items[id]["pos"].y) - GROUND) < 0.06), "the foundation taken down: what lay on it lies on the ground%s" % how)

	# The boulder is mined down to half its stones: the stack on top follows it down; mined out, it lies on the ground.
	items._items[950]["count"] = 400
	items._resettle_on(Vector3(340.0, GROUND, 300.0), 1.0)
	var half_top: float = GROUND + ItemsScript.BOULDER_TOP_SHARE * ItemsScript.BoulderWear.radius_now(1.0, 400, 800)
	check(absf(float(items._items[rock_id]["pos"].y) - half_top) < 0.01, "the boulder half mined: the stack on it comes down with it (%.2f)%s" % [float(items._items[rock_id]["pos"].y), how])
	items._items.erase(950)
	items._resettle_on(Vector3(340.0, GROUND, 300.0), 1.0)
	check(absf(float(items._items[rock_id]["pos"].y) - GROUND) < 0.06, "mined out: the stack lies on the ground%s" % how)

	# A log on a foundation is not put into the rolling world (it holds only the ground, so the log rolled down through the slab).
	add_struct(items, 960, "foundation_section", Vector3(360.0, GROUND, 360.0))

	if filed:
		file_grid(items)

	var log_item: String = "log" if items.table.number_of("log") > 0 else ""

	if log_item != "":
		var log_id: int = drop_id(items, Vector3(360.0, top, 360.0), Vector3(360.0, top, 360.0), log_item)
		check(log_id >= 0 and absf(float(items._items[log_id]["pos"].y) - top) < 0.01, "a log dropped on a foundation lies on its top%s" % how)
		check(log_id >= 0 and not items._log_supported(items._items[log_id]), "and is not handed to the rolling world, which would roll it through the slab%s" % how)


func _init() -> void:
	run(false)
	run(true)
	print("drop floor test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
