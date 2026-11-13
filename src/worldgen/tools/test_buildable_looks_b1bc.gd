extends SceneTree

# Buildables plan B1b and B1c (10 Nov 2026): stairs, railings, the double doorway, pillars and roof corners build, sit in the boxes of
# the pieces they match, and are solid where a player stands or is stopped. Bounds only (no pictures).
#   godot --headless --path . --script res://src/worldgen/tools/test_buildable_looks_b1bc.gd

const LookTable := preload("res://src/client/look_table.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _mesh_box(node: Node3D) -> AABB:
	var box: AABB = AABB()
	var first: bool = true

	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		var b: AABB = (node.global_transform.affine_inverse() * mi.global_transform) * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false

	return box


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


func _inside(box: AABB, low: Vector3, high: Vector3) -> bool:
	return box.position.x >= low.x and box.position.y >= low.y and box.position.z >= low.z and box.end.x <= high.x and box.end.y <= high.y and box.end.z <= high.z


func _build(look: String) -> Node3D:
	check(LookTable.has_look(look), "%s is in the look table" % look)
	var node: Node3D = LookTable.build(look)
	get_root().add_child(node)
	return node


func _run() -> void:
	await process_frame

	for look in ["log_stairs", "stone_stairs", "brick_stairs"]:
		var node: Node3D = _build(look)
		var box: AABB = _mesh_box(node)
		check(_inside(box, Vector3(-0.55, -0.15, -1.3), Vector3(0.55, 2.45, 1.3)) and box.end.y > 2.35, "%s: 1 m wide, 2.4 m long and 2.4 m up like the wooden stairs (%s)" % [look, box])
		check(_solid_at(node, Vector3(0.0, 0.2, 1.08)) and _solid_at(node, Vector3(0.0, 2.35, -1.08)) and not _solid_at(node, Vector3(0.0, 0.5, 1.08)), "%s: a step at the foot, one at the top, open over the first step" % look)

	for look in ["wooden_railing", "iron_railing"]:
		var node: Node3D = _build(look)
		var box: AABB = _mesh_box(node)
		check(_inside(box, Vector3(-1.01, -0.01, -0.08), Vector3(1.01, 1.07, 0.08)), "%s: 2 m long, 1 m high, thin (%s)" % [look, box])
		check(_solid_at(node, Vector3(0.0, 0.9, 0.0)) and not _solid_at(node, Vector3(0.0, 0.5, 0.2)), "%s: stops a fall, nothing beside it" % look)

	for look in ["double_doorway"]:   # Iron and Steel doorways retired 13 Nov 2026
		var half: float = 2.0
		var gap: float = 1.0
		var node: Node3D = _build(look)
		var box: AABB = _mesh_box(node)
		check(_inside(box, Vector3(-half - 0.03, -0.01, -0.2), Vector3(half + 0.03, 2.45, 0.2)) and box.end.y >= 2.3, "%s: in its %d m wall piece (%s)" % [look, int(half * 2.0), box])
		check(_solid_at(node, Vector3(gap + 0.2, 1.0, 0.0)) and _solid_at(node, Vector3(-gap - 0.2, 1.0, 0.0)) and _solid_at(node, Vector3(0.0, 2.25, 0.0)), "%s: solid beside and over the gap" % look)
		check(not _solid_at(node, Vector3(0.0, 1.0, 0.0)) and not _solid_at(node, Vector3(gap - 0.1, 0.3, 0.0)), "%s: an empty frame, the gap is walkable (BUGLIST-002)" % look)
		check(not LookTable.has_look(look + "_open"), "%s: no open twin look" % look)

	for kind in ["thatch", "wooden", "log", "stone", "brick"]:
		var look: String = kind + "_pillar"
		var node: Node3D = _build(look)
		var box: AABB = _mesh_box(node)
		var half: float = 0.26 if kind in ["stone", "brick"] else 0.21
		check(_inside(box, Vector3(-half, -0.01, -half), Vector3(half, 2.62, half)) and box.end.y > 2.55, "%s: in its footprint, 2.6 m high (%s)" % [look, box])
		check(_solid_at(node, Vector3(0.0, 0.1, 0.0)) and _solid_at(node, Vector3(0.0, 2.5, 0.0)), "%s: solid top to bottom" % look)

	for kind in ["thatch", "wooden", "log", "stone", "brick"]:
		var look: String = kind + "_roof_corner"
		var node: Node3D = _build(look)
		var box: AABB = _mesh_box(node)
		check(_inside(box, Vector3(-1.36, -0.01, -1.36), Vector3(1.36, 3.0, 1.36)) and box.end.y > 2.5, "%s: the straight roof's 2.4 m square (%s)" % [look, box])
		check(_solid_at(node, Vector3(0.0, 2.55, 0.0)) and _solid_at(node, Vector3(1.0, 2.55, 1.0)), "%s: a roof to stand on" % look)

	print("test_buildable_looks_b1bc: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
