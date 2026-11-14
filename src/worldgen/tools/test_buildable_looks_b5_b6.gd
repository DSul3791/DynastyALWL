extends SceneTree

# Buildables plan B5 and B6 (10 Nov 2026): the garden and water pieces build inside their footprints (the plan's w x d x h, centred, standing on y = 0; a
# scarecrow's arms and a pump's handle reach a little past the footprint, which is their solid) and every conduit reaches its ports: a straight piece
# x = -1 and +1, a corner -X and +Z, a tee -X, +X and +Z (the rows' "water" ports). Bounds only (no pictures).
#   godot --headless --path . --script res://src/worldgen/tools/test_buildable_looks_b5_b6.gd

const LookTable := preload("res://src/client/look_table.gd")

const SIZES := {
	"thatch_garden_plot": Vector3(2.0, 0.3, 2.0), "wooden_garden_plot": Vector3(2.0, 0.4, 2.0), "stone_garden_plot": Vector3(2.0, 0.4, 2.0), "brick_garden_plot": Vector3(2.0, 0.4, 2.0),
	"wooden_planter_box": Vector3(0.8, 0.3, 0.3), "stone_planter": Vector3(0.8, 0.6, 0.8), "wooden_trellis": Vector3(1.6, 2.0, 0.1), "wooden_compost_bin": Vector3(1.0, 0.8, 1.0),
	"thatch_scarecrow": Vector3(1.1, 2.0, 0.6), "wooden_cold_frame": Vector3(1.0, 0.5, 1.0),
	"stone_well": Vector3(1.6, 1.1, 1.6), "wooden_hand_pump": Vector3(0.5, 1.1, 0.5), "iron_hand_pump": Vector3(0.5, 1.1, 0.5),
	"log_trough": Vector3(1.6, 0.5, 0.5), "wooden_trough": Vector3(2.0, 0.5, 0.6), "stone_trough": Vector3(2.0, 0.6, 0.7), "wooden_sluice": Vector3(2.0, 0.6, 0.4),
	"iron_tap": Vector3(0.3, 0.4, 0.3), "iron_deep_well_pump": Vector3(0.8, 1.6, 0.8), "stone_cistern": Vector3(2.0, 1.0, 2.0), "stone_raised_cistern": Vector3(2.0, 3.0, 2.0),
}

const CONDUITS := {
	"wooden_channel": ["straight", 0.4, 0.3], "wooden_channel_corner": ["corner", 0.4, 0.3], "wooden_channel_tee": ["tee", 0.4, 0.3],
	"stone_channel": ["straight", 0.5, 0.3], "stone_channel_corner": ["corner", 0.5, 0.3], "stone_channel_tee": ["tee", 0.5, 0.3],
	"iron_pipe": ["straight", 0.2, 0.2], "iron_pipe_elbow": ["corner", 0.2, 0.2],
}

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


func _build(look: String) -> Node3D:
	check(LookTable.has_look(look), "%s is in the look table" % look)
	var node: Node3D = LookTable.build(look)
	get_root().add_child(node)
	return node


func _run() -> void:
	await process_frame

	for look in SIZES:
		var node: Node3D = _build(look)
		var size: Vector3 = SIZES[look]
		var box: AABB = _mesh_box(node)
		check(box.position.x >= -size.x * 0.5 - 0.04 and box.end.x <= size.x * 0.5 + 0.04 and box.position.z >= -size.z * 0.5 - 0.04 and box.end.z <= size.z * 0.5 + 0.04
			and box.position.y >= -0.01 and box.end.y <= size.y + 0.06 and box.end.y >= size.y - 0.2, "%s: in its %s footprint (%s)" % [look, size, box])

	for look in CONDUITS:
		var row: Array = CONDUITS[look]
		var shape: String = row[0]
		var half_w: float = float(row[1]) * 0.5
		var node: Node3D = _build(look)
		var box: AABB = _mesh_box(node)
		var to_plus_x: bool = shape != "corner"
		var to_plus_z: bool = shape != "straight"
		check(box.position.x <= -0.97 and box.position.x >= -1.04 and (box.end.x >= 0.97 if to_plus_x else box.end.x <= half_w + 0.06) and box.end.x <= 1.04
			and box.position.z >= -half_w - 0.04 and (box.end.z >= 0.97 if to_plus_z else box.end.z <= half_w + 0.04) and box.end.z <= 1.04
			and box.position.y >= -0.01 and box.end.y <= float(row[2]) + 0.04, "%s: a %s piece reaching its ports (%s)" % [look, shape, box])
		var high: float = float(row[2]) * 0.5
		check(_solid_at(node, Vector3(-0.9, high, 0.0)) and _solid_at(node, Vector3(0.9, high, 0.0)) == to_plus_x and _solid_at(node, Vector3(0.0, high, 0.9)) == to_plus_z,
			"%s: solid along its runs and nowhere else" % look)

	print("test_buildable_looks_b5_b6: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
