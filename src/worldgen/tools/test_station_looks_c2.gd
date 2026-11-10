extends SceneTree

# Item system C2 stations (item_system.md draft 7, Jamie's #934, 10 Nov 2026): the Kiln, Tanning rack, Drying rack, Smoker and Oil press looks build inside
# their structures.json footprints (w x d, centred, standing on y = 0, under the height given here), are solid over the footprint, and stay under the
# look table's triangle cap. Bounds only (no pictures).
#   godot --headless --path . --script res://src/worldgen/tools/test_station_looks_c2.gd

const LookTable := preload("res://src/client/look_table.gd")

# look: footprint_x, height, footprint_z
const SIZES := {
	"kiln": Vector3(1.6, 1.7, 1.6), "tanning_rack": Vector3(2.0, 1.8, 0.6), "drying_rack": Vector3(1.6, 1.4, 0.6), "smoker": Vector3(1.2, 1.7, 1.2),
	"oil_press": Vector3(1.2, 1.1, 1.2),
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


func _triangles(node: Node) -> int:
	var total: int = 0

	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		total += floori(float((node as MeshInstance3D).mesh.get_faces().size()) / 3.0)

	for child in node.get_children():
		total += _triangles(child)

	return total


func _run() -> void:
	await process_frame

	for look in SIZES:
		check(LookTable.has_look(look), "%s is in the look table" % look)
		var node: Node3D = LookTable.build(look)
		get_root().add_child(node)
		var size: Vector3 = SIZES[look]
		var box: AABB = _mesh_box(node)
		check(box.position.x >= -size.x * 0.5 - 0.04 and box.end.x <= size.x * 0.5 + 0.04 and box.position.z >= -size.z * 0.5 - 0.04 and box.end.z <= size.z * 0.5 + 0.04
			and box.position.y >= -0.01 and box.end.y <= size.y and box.end.y >= 0.6, "%s: in its %s footprint (%s)" % [look, size, box])
		check(_solid_at(node, Vector3(0.0, 0.3, 0.0)), "%s: solid where it stands" % look)
		var tris: int = _triangles(node)
		check(tris <= 300, "%s: under the 300 triangle cap (%d)" % [look, tris])

	print("test_station_looks_c2: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
