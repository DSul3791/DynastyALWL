extends SceneTree

# Buildables plan B2 (10 Nov 2026): every fence section and gate builds in its 2 m section box, has its posts at the two ends (x = -1 and +1, where the next
# section shares them: placement_rules.gd fence_ends), is solid between them, and a gate opens to leave the gap walkable. Bounds only (no pictures).
#   godot --headless --path . --script res://src/worldgen/tools/test_buildable_looks_b2.gd

const LookTable := preload("res://src/client/look_table.gd")
const PieceLook := preload("res://src/client/piece_look.gd")

const KINDS := {"thatch": "thatch", "wood": "wood", "log": "log", "log_palisade": "palisade", "stone": "stone", "brick": "brick", "iron": "iron"}

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

	for name_part in KINDS:
		var kind: String = KINDS[name_part]
		var fence_look: String = name_part if name_part == "log_palisade" else name_part + "_fence"
		var gate_look: String = name_part + "_gate"

		for look in [fence_look, gate_look, gate_look + "_open"]:
			var is_gate: bool = look != fence_look
			var spec: Array = PieceLook.FENCE_SPEC.get(kind + "_gate", PieceLook.FENCE_SPEC[kind]) if is_gate else PieceLook.FENCE_SPEC[kind]
			var height: float = spec[0]
			var radius: float = spec[1]
			var half_depth: float = maxf(float(spec[2]) * 0.5, radius + 0.03) + 0.02
			var open: bool = look.ends_with("_open")
			var node: Node3D = _build(look)
			var box: AABB = _mesh_box(node)
			var reach_x: float = 1.0 + radius + 0.05
			check(box.position.x >= -reach_x and box.end.x <= reach_x and box.position.y >= -0.01 and box.end.y <= height + 0.06 and box.end.y >= height - 0.1
				and box.position.z >= -half_depth and box.end.z <= (2.0 if open else half_depth), "%s: in its 2 m section, %.1f m high (%s)" % [look, height, box])
			check(_solid_at(node, Vector3(-1.0, 0.3, 0.0)) and _solid_at(node, Vector3(1.0, 0.3, 0.0)), "%s: a post at each end, where the next section shares it" % look)

			if open:
				var w: float = 2.0 - 2.0 * radius - 0.04
				check(not _solid_at(node, Vector3(0.0, 0.5, 0.0)) and _solid_at(node, Vector3(-w * 0.5, 0.5, w * 0.5)), "%s: the gap is walkable, the leaf stands swung out" % look)
			else:
				check(_solid_at(node, Vector3(0.0, 0.5, 0.0)) and _solid_at(node, Vector3(0.5, minf(0.9, height - 0.1), 0.0)), "%s: solid between the posts" % look)

	print("test_buildable_looks_b2: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
