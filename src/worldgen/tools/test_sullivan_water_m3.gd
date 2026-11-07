extends SceneTree

# Sullivan water M3 gate, first half: the terrain adapter and the edit coordinator on made-up ground (guide sections 17, 21, 24.3 and 25).
# G01 berm raises a face crest, G02 a cut lowers it, G03 bridge (must report BLOCKED until layered water exists), F06 a dug canal makes no
# water and then fills by flow, F07 raised ground keeps its water, F14 an edit beside unloaded ground is refused with nothing changed, and an
# edit that roofs over standing water is undone. The real-ground half (server ground and VoxelTool) needs the game and comes next.
#   godot --headless --path . --script res://src/worldgen/tools/test_sullivan_water_m3.gd

const Grid := preload("res://src/sullivan_water/freshwater/water_grid_2d.gd")
const Adapter := preload("res://src/sullivan_water/freshwater/terrain_adapter.gd")
const Coordinator := preload("res://src/sullivan_water/freshwater/terrain_water_edit_coordinator.gd")

const CELL := 2.0
const SURFACE_TOL := 0.05   # guide 24.2: crossings found to within 0.05 m

var failures: int = 0


# Made-up ground with the game's conventions: SDF in metres, negative is solid. A flat floor at y 0, raised boxes (berms), floating boxes
# (bridges), and sphere digs and fills applied in order like the server's edit log. Only the `loaded` rectangle (x, z) is loaded.
class MadeUpGround:
	extends RefCounted
	var berms: Array = []     # [Rect2 (x, z), top y]
	var bridges: Array = []   # [AABB]
	var caves: Array = []     # [AABB] of air under the ground
	var ops: Array = []       # [add: bool, centre: Vector3, radius: float]
	var loaded: Rect2 = Rect2(-1000.0, -1000.0, 2000.0, 2000.0)

	func sdf(p: Vector3) -> float:
		var top: float = 0.0

		for b in berms:
			if (b[0] as Rect2).has_point(Vector2(p.x, p.z)):
				top = maxf(top, float(b[1]))

		var d: float = p.y - top

		for box in bridges:
			var a: AABB = box
			var inside: Vector3 = (p - a.get_center()).abs() - a.size * 0.5
			d = minf(d, maxf(inside.x, maxf(inside.y, inside.z)))

		for box in caves:
			var c: AABB = box
			var inside_c: Vector3 = (p - c.get_center()).abs() - c.size * 0.5
			d = maxf(d, -maxf(inside_c.x, maxf(inside_c.y, inside_c.z)))

		for op in ops:
			var r: float = (p - Vector3(op[1])).length() - float(op[2])
			d = minf(d, r) if bool(op[0]) else maxf(d, -r)

		return d

	func is_loaded(box: AABB) -> bool:
		return loaded.encloses(Rect2(box.position.x, box.position.z, box.size.x, box.size.z))

	func edit_sphere(center: Vector3, radius: float, add: bool) -> bool:
		ops.append([add, center, radius])
		return true

	func undo_last() -> bool:
		if ops.is_empty():
			return false

		ops.pop_back()
		return true


func _init() -> void:
	var begun: int = Time.get_ticks_msec()
	print("engine %s" % Engine.get_version_info().get("string", "?"))
	_g01_g02_f06_berm_and_cut()
	_g03_bridge()
	_deep_cave()
	_f07_raise_under_water()
	_f14_unloaded()
	_roof_over_water()
	print("%d failures, %d ms" % [failures, Time.get_ticks_msec() - begun])
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _setup(ground, w: int, h: int) -> Array:
	var grid = Grid.new(w, h, CELL)
	var adapter = Adapter.new(ground, Vector2.ZERO, CELL)
	adapter.y_min = -6.0
	adapter.y_max = 10.0
	var coordinator = Coordinator.new(grid, adapter)
	return [grid, adapter, coordinator]


func _volume_cols(grid, i_from: int, i_to: int) -> float:
	var sum: float = 0.0

	for j in range(grid.h):
		for i in range(i_from, i_to):
			sum += grid.volume[grid.index(i, j)]
	return sum


# G01: a 1 m wide, 1.5 m high berm along x = 10, the face between columns 4 and 5. G02 and F06: a cut through it, through the coordinator.
func _g01_g02_f06_berm_and_cut() -> void:
	var ground = MadeUpGround.new()
	ground.berms.append([Rect2(9.5, -100.0, 1.0, 200.0), 1.5])
	var parts: Array = _setup(ground, 10, 6)
	var grid = parts[0]
	var coordinator = parts[2]
	var built: Dictionary = coordinator.build()
	_check(bool(built["ok"]), "build: the adapter read all %d cells" % int(built["cells"]))
	_check(absf(grid.bed[grid.index(4, 2)]) < SURFACE_TOL and absf(grid.bed[grid.index(5, 2)]) < SURFACE_TOL, "G01: the cell beds either side of the berm stay low (%.3f, %.3f m)" % [grid.bed[grid.index(4, 2)], grid.bed[grid.index(5, 2)]])
	_check(absf(grid.crest_e[grid.index(4, 2)] - 1.5) < SURFACE_TOL, "G01: the face crest on the berm reads its 1.5 m height (%.3f m)" % grid.crest_e[grid.index(4, 2)])
	_check(grid.crest_e[grid.index(2, 2)] < 0.1, "G01: a face on flat ground stays open (%.3f)" % grid.crest_e[grid.index(2, 2)])

	for j in range(6):
		for i in range(5):
			grid.add_water(i, j, 1.0 * grid.area_m2, "pond")

	for _t in range(300):
		grid.step()

	_check(_volume_cols(grid, 5, 10) == 0.0, "G01: the berm holds 1 m of water back")

	var heard: Array = []
	coordinator.listeners.append(func(cells: Rect2i, revision: int): heard.append([cells, revision]))
	var before: float = grid.total_volume()
	var east_before: float = _volume_cols(grid, 5, 10)
	var cut: Dictionary = coordinator.edit_sphere(Vector3(10.0, 0.5, 5.0), 2.5, false)
	_check(cut["result"] == Coordinator.COMMITTED, "G02: the cut commits (%s %s)" % [cut["result"], cut["reason"]])
	_check(grid.crest_e[grid.index(4, 2)] < 1.0, "G02: the face crest where the cut crosses the berm drops (%.3f m)" % grid.crest_e[grid.index(4, 2)])
	_check(grid.crest_e[grid.index(4, 0)] > 1.4, "G02: the berm away from the cut keeps its crest (%.3f m)" % grid.crest_e[grid.index(4, 0)])
	_check(grid.total_volume() == before and _volume_cols(grid, 5, 10) == east_before, "F06: the dig made no water (%.6f m3 before and after; east side still %.3f)" % [before, _volume_cols(grid, 5, 10)])
	_check(heard.size() == 1 and int(heard[0][1]) == cut["revision"], "17: one affected_region_changed, with the new revision %d" % int(cut["revision"]))

	for _t in range(600):
		grid.step()

	_check(_volume_cols(grid, 5, 10) > 1.0, "F06: water then flows east through the cut (%.2f m3)" % _volume_cols(grid, 5, 10))
	_check(absf(grid.ledger_residual()) < 1.0e-9 * before, "F06: ledger balances (%s)" % String.num_scientific(grid.ledger_residual()))


# G03: a bridge deck over open ground. Its columns hold two surfaces. Detecting that passes; simulating water under it is BLOCKED.
func _g03_bridge() -> void:
	var ground = MadeUpGround.new()
	ground.bridges.append(AABB(Vector3(8.0, 3.0, -100.0), Vector3(4.0, 0.5, 200.0)))
	var parts: Array = _setup(ground, 10, 4)
	var grid = parts[0]
	var adapter = parts[1]
	var built: Dictionary = parts[2].build()
	_check(int(built["stacked"]) == 8 and adapter.classification[grid.index(4, 1)] == Adapter.STACKED, "G03: the 2 columns x 4 rows under the bridge are found STACKED (%d)" % int(built["stacked"]))
	_check(grid.crest_e[grid.index(3, 1)] == Grid.WALL and grid.crest_e[grid.index(5, 1)] == Grid.WALL, "G03: their faces are closed, so no water is put on the bridge deck")
	print("BLOCKED G03: flow under a bridge needs the layered water graph (guide 3.10, 24.3), not built yet")


# A cave 10 m under the ground does not make the surface STACKED: only air within stack_depth_m under the top does.
func _deep_cave() -> void:
	var ground = MadeUpGround.new()
	ground.caves.append(AABB(Vector3(-100.0, -12.0, -100.0), Vector3(200.0, 3.0, 200.0)))
	var parts: Array = _setup(ground, 4, 4)
	parts[1].y_min = -20.0
	var built: Dictionary = parts[2].build()
	_check(bool(built["ok"]) and int(built["stacked"]) == 0 and absf(parts[0].bed[0]) < SURFACE_TOL, "4.1: a cave 9 m down leaves the surface open, bed %.3f m" % parts[0].bed[0])


# F07: a fill raises ground under 1 m of standing water; the cell keeps its water, the surface rises, and the flow spreads it.
func _f07_raise_under_water() -> void:
	var ground = MadeUpGround.new()
	var parts: Array = _setup(ground, 6, 6)
	var grid = parts[0]
	var coordinator = parts[2]
	coordinator.build()
	grid.fill_to_level(1.0)
	var start: float = grid.total_volume()
	var cell_before: float = grid.volume[grid.index(2, 2)]
	var fill: Dictionary = coordinator.edit_sphere(Vector3(5.0, 0.0, 5.0), 0.8, true)
	_check(fill["result"] == Coordinator.COMMITTED, "F07: the fill under water commits (%s %s)" % [fill["result"], fill["reason"]])
	_check(grid.volume[grid.index(2, 2)] == cell_before and grid.surface(2, 2) > 1.5, "F07: the raised cell keeps its %.3f m3, surface now %.3f m" % [cell_before, grid.surface(2, 2)])

	for _t in range(1000):
		grid.step()

	_check(absf(grid.total_volume() - start) < 1.0e-9 * start and grid.surface(0, 0) > 1.0, "F07: no water lost; the pond rose to %.4f m" % grid.surface(0, 0))


# F14: ground is loaded only for x below 14 m. An edit whose halo reaches past it is refused, and nothing changes.
func _f14_unloaded() -> void:
	var ground = MadeUpGround.new()
	ground.loaded = Rect2(-1.0, -1.0, 15.0, 100.0)
	var parts: Array = _setup(ground, 10, 4)
	var grid = parts[0]
	var adapter = parts[1]
	var coordinator = parts[2]
	grid.bed.fill(99.0)
	var built: Dictionary = adapter.extract(grid, 0, 0, 9, 3)
	_check(not bool(built["ok"]) and grid.bed[0] == 99.0, "24.2: a read that meets unloaded ground writes nothing (%s)" % built["reason"])

	adapter.extract(grid, 0, 0, 4, 3)
	var revision: int = coordinator.terrain_revision
	var edit: Dictionary = coordinator.edit_sphere(Vector3(12.5, 0.0, 4.0), 1.0, false)
	_check(edit["result"] == Coordinator.REJECTED_UNLOADED, "F14: a dig beside unloaded ground is refused (%s: %s)" % [edit["result"], edit["reason"]])
	_check(ground.ops.is_empty() and coordinator.terrain_revision == revision, "F14: the ground and the revision did not change")


# An edit that roofs over standing water: the one-surface grid cannot hold it, so the coordinator undoes the edit and says why.
func _roof_over_water() -> void:
	var ground = MadeUpGround.new()
	var parts: Array = _setup(ground, 6, 6)
	var grid = parts[0]
	var coordinator = parts[2]
	coordinator.build()
	grid.fill_to_level(1.0)
	var start: float = grid.total_volume()
	var bed_before: float = grid.bed[grid.index(2, 2)]
	var roof: Dictionary = coordinator.edit_sphere(Vector3(5.0, 3.0, 5.0), 0.8, true)
	_check(roof["result"] == Coordinator.REJECTED_UNSUPPORTED_GEOMETRY, "25.1: a fill that roofs over water is refused (%s: %s)" % [roof["result"], roof["reason"]])
	_check(ground.ops.is_empty() and grid.bed[grid.index(2, 2)] == bed_before and grid.total_volume() == start, "25.1: it was undone: ground, bed and water as before")
	_check(not coordinator.frozen, "25.1: nothing frozen, since the undo worked")
