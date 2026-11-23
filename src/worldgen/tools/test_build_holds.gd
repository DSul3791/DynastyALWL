extends SceneTree

# What players build holds together (physical world audit round 5, 23 Nov 2026):
# - a ceiling aimed at a wall top sits on the walls (it fell to the foundation floor: snap knew only the foundation's anchors), and aimed at the floor stays there;
# - a wall under a roof corner or a ceiling that rests on it alone cannot be taken down ("Take down what stands on it first."); one with nothing on it can;
# - a closed room of every tier (foundation, eight walls, four ceilings or four roof corners) lets no daylight through: rays from inside hit a drawn face
#   (log walls showed light at every join, log ceilings a 4 cm gap, the log foundation's deck and sills slits).
#   godot --headless --path . --script res://src/worldgen/tools/test_build_holds.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Rules := preload("res://src/shared/placement_rules.gd")

var failures: int = 0
var items
var said: Array = []
var cfg: Dictionary


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func place(kit: String, at: Vector3, yaw: int = 0) -> int:
	said.clear()
	var next: int = items._next_id
	items.report_position(1, Vector3(at.x, 10.0, at.z + 0.5))
	items.place_piece(1, kit, at, yaw, 0)
	return next if items._items.has(next) else -1


func take_down(id: int) -> bool:
	said.clear()
	items.report_position(1, Vector3(items._items[id]["pos"].x, 10.0, items._items[id]["pos"].z))
	items._take_down(1, items.inventory_of(1), id)
	return not items._items.has(id)


# A 4 x 4 m room at (x, 500): the foundation and its eight walls. Returns [foundation id, the wall ids by their anchor].
func room(x: float, wall_kit: String, base_kit: String) -> Array:
	var base: int = place(base_kit, Vector3(x, 10.0, 500.0))
	var walls: Dictionary = {}

	for a in cfg["structures"][str(Rules.structure_of_kit(cfg, base_kit)["kind"])]["anchors"]["wall"]:
		walls[Vector2i(int(a[0]), int(a[1]))] = place(wall_kit, Vector3(x + float(a[0]) + 0.2 * signf(float(a[0])), 10.3, 500.0 + float(a[1]) + 0.2 * signf(float(a[1]))), int(a[2]))

	return [base, walls]


func tris(node: Node, xf: Transform3D, out: PackedVector3Array) -> void:
	var here: Transform3D = xf * ((node as Node3D).transform if node is Node3D else Transform3D.IDENTITY)

	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and (node as MeshInstance3D).visible:
		for p in (node as MeshInstance3D).mesh.get_faces():
			out.append(here * p)

	for child in node.get_children():
		tris(child, here, out)


# How many of `n` rays from `from`, spread evenly over the sphere, meet none of the drawn faces of pieces `ids`.
func escapes(view, ids: Array, from: Vector3, n: int) -> int:
	var faces: PackedVector3Array = PackedVector3Array()

	for id in ids:
		var it: Dictionary = items._items[id]
		var model: Node3D = view._model_for_state(int(cfg["structures"][str(it["struct"]["kind"])]["state"]), {})
		tris(model, Transform3D(Basis(Vector3.UP, deg_to_rad(float(it["struct"]["yaw"]))), it["pos"]), faces)
		model.free()

	var out: int = 0
	var turn: float = PI * (3.0 - sqrt(5.0))

	for i in n:
		var y: float = 1.0 - (float(i) + 0.5) / float(n) * 2.0
		var r: float = sqrt(1.0 - y * y)
		var d: Vector3 = Vector3(cos(turn * i) * r, y, sin(turn * i) * r)
		var k: int = 0
		var hit: bool = false

		while k < faces.size() and not hit:
			hit = Geometry3D.ray_intersects_triangle(from, d, faces[k], faces[k + 1], faces[k + 2]) != null
			k += 3

		if not hit:
			out += 1

	return out


func _init() -> void:
	cfg = Rules.load_config()
	var dir: String = "user://test_build_holds"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "buildholds001")
	items.free_build = true
	var top: float = 10.3 + Rules.WALL_HEIGHT_M

	# Ceilings: aimed at a wall top (by the wall, as the aim ray lands) they sit on it; aimed at the floor they lie on the foundation.
	var a: Array = room(1000.0, "wall_section_kit", "foundation_section_kit")
	var ceilings: Array = []

	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		ceilings.append(place("floor_section_kit", Vector3(1000.0 + c[0], top, 500.0 + c[1] * 1.9)))

	check(ceilings.all(func(id): return id > 0 and absf(float(items._items[id]["pos"].y) - top) < 0.01), "four ceilings aimed at the wall tops sit on them, %.1f m up (%s)" % [top, str(ceilings.map(func(id): return items._items[id]["pos"] if id > 0 else said))])
	var b: Array = room(1020.0, "wall_section_kit", "foundation_section_kit")
	var low: int = place("floor_section_kit", Vector3(1019.0, 10.3, 499.0))
	check(low > 0 and absf(float(items._items[low]["pos"].y) - 10.3) < 0.01, "a ceiling aimed at the foundation floor lies on it (%s)" % str(items._items[low]["pos"] if low > 0 else said))

	# Taking a wall down: one cell keeps its other wall, so the first wall comes down; then the cell's last wall holds it up and stays.
	var walls: Dictionary = a[1]
	check(take_down(int(walls[Vector2i(-1, -2)])), "a wall comes down while the ceiling on it rests on another wall too")
	check(not take_down(int(walls[Vector2i(-2, -1)])) and said.has("Take down what stands on it first."), "the ceiling's last wall stays, saying why (%s)" % str(said))
	check(take_down(int(ceilings[0])) and take_down(int(walls[Vector2i(-2, -1)])), "with the ceiling gone the wall comes down")

	# Roof corners on a room's wall tops: each corner rests on two walls; taking one of them down would leave the corner in the air.
	var c: Array = room(1040.0, "thatch_wall_kit", "thatch_floor_kit")
	var corners: Array = []

	for k in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		corners.append(place("thatch_roof_corner_kit", Vector3(1040.0 + k[0] * 1.2, top + 0.5, 500.0 + k[1] * 1.2)))

	check(corners.all(func(id): return id > 0), "four roof corners close the room (%s)" % str(corners))
	var under: int = int((c[1] as Dictionary)[Vector2i(1, 2)])
	check(not take_down(under) and items._items.has(under) and said.has("Take down what stands on it first."), "a wall under a roof corner stays, saying why (%s)" % str(said))
	var free_wall: int = int((b[1] as Dictionary)[Vector2i(2, 1)])
	check(take_down(free_wall), "a wall with nothing on it comes down")

	# No daylight through a closed room of any tier.
	var view = load("res://src/client/inventory_view.gd").new()
	var x: float = 1100.0

	for tier in [["thatch_wall_kit", "thatch_floor_kit", "floor_section_kit"], ["wall_section_kit", "wood_foundation_kit", "floor_section_kit"], ["log_wall_kit", "log_foundation_kit", "log_floor_kit"], ["stone_wall_kit", "brick_foundation_kit", "stone_floor_kit"], ["brick_wall_kit", "brick_foundation_kit", "brick_floor_kit"], ["engineered_wall_kit", "engineered_foundation_kit", "engineered_floor_kit"], ["fortified_wall_kit", "fortified_foundation_kit", "fortified_floor"]]:
		var before: Array = items._items.keys()
		room(x, tier[0], tier[1])

		for k in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
			place(tier[2], Vector3(x + k[0], top, 500.0 + k[1] * 1.9))

		var ids: Array = items._items.keys().filter(func(id): return not before.has(id))
		var light: int = 0

		for from in [Vector3(x, 11.9, 500.0), Vector3(x + 1.6, 10.5, 501.6), Vector3(x - 1.7, 12.4, 498.3)]:
			light += escapes(view, ids, from, 600)

		check(ids.size() == 13 and light == 0, "%s room: 13 pieces, no daylight through it (%d of 1800 rays got out)" % [tier[0], light])
		x += 20.0

	view.free()
	print("build holds test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
