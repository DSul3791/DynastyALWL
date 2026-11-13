extends SceneTree

# Buildables plan B0 and B1a (10 Nov 2026): the new foundation, doorway and window looks and the forged hammer heads build, sit on the grid of the
# pieces they match, and leave their openings walkable. Bounds only (no pictures): every look's meshes in its box, the solids where they should be.
#   godot --headless --path . --script res://src/worldgen/tools/test_buildable_looks_b1a.gd

const LookTable := preload("res://src/client/look_table.gd")
const BasicLook := preload("res://src/client/basic_look.gd")

const FOUNDATIONS := ["log_foundation", "brick_foundation"]
const DOORWAYS := ["log_doorway", "stone_doorway", "brick_doorway"]
const WINDOWS := ["thatch_window", "log_window", "stone_window", "brick_window"]

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


# The box round every mesh under `node`, in the look's own space.
func _mesh_box(node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true

	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		var b: AABB = (node.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false

	return box


# Whether any solid box under `node` holds `point` (look space).
func _solid_at(node: Node3D, point: Vector3) -> bool:
	for child in node.find_children("*", "CollisionShape3D", true, false):
		var cs: CollisionShape3D = child
		var shape: BoxShape3D = cs.shape as BoxShape3D

		if shape == null:
			continue

		var local: Vector3 = (node.global_transform.affine_inverse() * cs.global_transform).affine_inverse() * point

		if absf(local.x) <= shape.size.x * 0.5 and absf(local.y) <= shape.size.y * 0.5 and absf(local.z) <= shape.size.z * 0.5:
			return true

	return false


func _near(a: float, b: float, tolerance: float) -> bool:
	return absf(a - b) <= tolerance


func _build(look: String) -> Node3D:
	check(LookTable.has_look(look), "%s is in the look table" % look)
	var node: Node3D = LookTable.build(look)
	get_root().add_child(node)
	return node


func _run() -> void:
	await process_frame

	for look in FOUNDATIONS:
		var node: Node3D = _build(look)
		var box: AABB = _mesh_box(node)
		check(_near(box.size.x, 4.0, 0.1) and _near(box.size.z, 4.0, 0.1) and _near(box.end.y, 0.3, 0.03) and _near(box.position.y, -1.7, 0.05),
			"%s: 4 m square, top 0.3 m up, 2 m deep like the stone foundation (%s)" % [look, box])
		check(_solid_at(node, Vector3(0.0, 0.25, 0.0)) and _solid_at(node, Vector3(1.9, -1.6, 1.9)) and not _solid_at(node, Vector3(0.0, 0.35, 0.0)), "%s: solid from the top down, nothing above it" % look)

	for look in DOORWAYS:
		for open in [false, true]:
			var look_name: String = look + ("_open" if open else "")
			var node: Node3D = _build(look_name)
			var box: AABB = _mesh_box(node)
			check(box.position.x >= -1.04 and box.end.x <= 1.04 and box.position.y >= -0.01 and box.end.y <= 2.56 and box.end.y >= 2.3, "%s: in the 2 m by 2.4 m wall piece (%s)" % [look_name, box])
			check(_solid_at(node, Vector3(0.75, 1.0, 0.0)) and _solid_at(node, Vector3(-0.75, 1.0, 0.0)) and _solid_at(node, Vector3(0.0, 2.25, 0.0)), "%s: the wall either side of and over the gap is solid" % look_name)

			if open:
				check(not _solid_at(node, Vector3(0.0, 1.0, 0.0)) and not _solid_at(node, Vector3(-0.2, 0.3, 0.0)), "%s: the doorway is walkable" % look_name)
				check(box.end.z <= 1.06, "%s: the open door stays within a metre of the wall" % look_name)
			else:
				check(_solid_at(node, Vector3(0.0, 1.0, 0.0)), "%s: the shut door blocks the gap" % look_name)
				check(box.position.z >= -0.2 and box.end.z <= 0.2, "%s: as thick as a wall (%.2f to %.2f)" % [look_name, box.position.z, box.end.z])

	# The Crude doorway (BUG-010): a framed passage with no door at all. The wall is solid either side of and over the gap and nothing stands in it, at any
	# height a person passes, over the whole clear width; no mesh stands in the gap either.
	var crude: Node3D = _build("thatch_doorway")
	var crude_box: AABB = _mesh_box(crude)
	check(crude_box.position.x >= -1.04 and crude_box.end.x <= 1.04 and crude_box.position.y >= -0.01 and crude_box.end.y <= 2.56 and crude_box.end.y >= 2.3 and crude_box.position.z >= -0.2 and crude_box.end.z <= 0.2,
		"thatch_doorway: in the 2 m by 2.4 m wall piece, as thick as a wall (%s)" % crude_box)
	check(_solid_at(crude, Vector3(0.75, 1.0, 0.0)) and _solid_at(crude, Vector3(-0.75, 1.0, 0.0)) and _solid_at(crude, Vector3(0.0, 2.25, 0.0)), "thatch_doorway: the wall either side of and over the gap is solid")
	var blocked_at: Array = []

	for x in [-0.45, -0.3, 0.0, 0.3, 0.45]:
		for y in [0.1, 0.5, 1.0, 1.5, 1.9]:
			for z in [-0.1, 0.0, 0.1]:
				if _solid_at(crude, Vector3(x, y, z)):
					blocked_at.append(Vector3(x, y, z))

	check(blocked_at.is_empty(), "thatch_doorway: nothing solid in the 0.9 m by 1.9 m opening (%s)" % str(blocked_at))
	var leaf_in_gap: bool = false

	for child in crude.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		var b: AABB = (crude.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		leaf_in_gap = leaf_in_gap or (b.position.x > -0.44 and b.end.x < 0.44 and b.position.y < 1.9 and b.end.y > 0.1)   # a mesh wholly inside the opening: a door leaf

	check(not leaf_in_gap, "thatch_doorway: no door leaf hangs in the opening")
	check(not LookTable.has_look("thatch_doorway_open"), "thatch_doorway: the open twin look is retired")

	for look in WINDOWS:
		var node: Node3D = _build(look)
		var box: AABB = _mesh_box(node)
		check(box.position.x >= -1.04 and box.end.x <= 1.04 and box.position.y >= -0.01 and box.end.y <= 2.56 and box.end.y >= 2.3 and box.position.z >= -0.2 and box.end.z <= 0.2, "%s: in the 2 m by 2.4 m wall piece (%s)" % [look, box])
		check(not _solid_at(node, Vector3(0.0, 1.3, 0.0)) and _solid_at(node, Vector3(0.0, 0.5, 0.0)) and _solid_at(node, Vector3(0.0, 2.1, 0.0)) and _solid_at(node, Vector3(0.75, 1.3, 0.0)), "%s: open at 1.3 m, solid under, over and beside the gap" % look)

	for item in ["bronze_hammer", "iron_hammer", "steel_hammer"]:
		var mesh: Mesh = BasicLook.mesh_for(item)
		check(mesh != null and mesh.get_surface_count() >= 2, "%s: a hammer with a metal surface" % item)

		if mesh != null:
			var box: AABB = mesh.get_aabb()
			var stone: AABB = BasicLook.mesh_for("stone_hammer").get_aabb()
			# The same haft as the stone hammer (its grip end and a hammer's length); the forged head across it is longer than the stone lump, so only its
			# own span is checked (a cross-peen head about 15 cm, not a block).
			check(_near(box.position.x, stone.position.x, 0.02) and box.size.x > 0.4 and box.size.x < 0.5 and box.size.z > 0.12 and box.size.z < 0.2,
				"%s: the stone hammer's haft, a forged head across it (%s)" % [item, box])

	print("test_buildable_looks_b1a: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
