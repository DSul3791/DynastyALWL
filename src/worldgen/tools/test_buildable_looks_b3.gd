extends SceneTree

# Buildables plan B3 (10 Nov 2026): the furniture tiers, the stone work bench and the storage pieces build inside their footprints (the plan's w x d x h,
# centred, standing on y = 0) and are solid. Bounds only (no pictures).
#   godot --headless --path . --script res://src/worldgen/tools/test_buildable_looks_b3.gd

const LookTable := preload("res://src/client/look_table.gd")

const SIZES := {
	"log_bench": Vector3(2.0, 0.45, 0.4), "stone_bench": Vector3(2.0, 0.45, 0.4), "iron_bench": Vector3(2.0, 0.45, 0.4),
	"log_table": Vector3(1.4, 0.8, 0.7), "stone_table": Vector3(1.4, 0.85, 0.8), "iron_table": Vector3(1.4, 0.8, 0.7),
	"iron_chair": Vector3(0.6, 0.9, 0.6), "stone_workbench": Vector3(2.0, 1.1, 1.0),
	"wooden_shelf": Vector3(1.2, 1.2, 0.3), "wooden_cupboard": Vector3(1.0, 1.8, 0.5), "wooden_barrel": Vector3(0.7, 0.9, 0.7),
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


func _run() -> void:
	await process_frame

	for look in SIZES:
		check(LookTable.has_look(look), "%s is in the look table" % look)
		var node: Node3D = LookTable.build(look)
		get_root().add_child(node)
		var size: Vector3 = SIZES[look]
		var box: AABB = _mesh_box(node)
		var slack: float = 0.04
		check(box.position.x >= -size.x * 0.5 - slack and box.end.x <= size.x * 0.5 + slack and box.position.z >= -size.z * 0.5 - slack and box.end.z <= size.z * 0.5 + slack
			and box.position.y >= -0.01 and box.end.y <= size.y + slack and box.end.y >= size.y - 0.15, "%s: in its %s footprint (%s)" % [look, size, box])
		check(not node.find_children("*", "CollisionShape3D", true, false).is_empty(), "%s: solid" % look)

	print("test_buildable_looks_b3: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
