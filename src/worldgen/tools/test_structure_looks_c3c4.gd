extends SceneTree

# Item system C3 and C4 (item_system.md draft 7, Jamie's #936 and #938, 10 Nov 2026): the Storage jar, Hide - Sack, Wicker - Basket, Weapon rack,
# Armour stand, Sign, Tusk - Mount, Clay bloomery and Stonecutter's bench looks build inside their structures.json footprints (w x d, centred, standing
# on y = 0, under the height given here), are solid where they stand (not the Tusk mount: it hangs on a wall like the Antler mount, so it is given
# 0.3 m of depth out from the wall), and stay under the look table's triangle cap. Bounds only (no pictures). The Fish trap and Bird trap (#941) are
# checked here too; they are not solid.
#   godot --headless --path . --script res://src/worldgen/tools/test_structure_looks_c3c4.gd

const LookTable := preload("res://src/client/look_table.gd")

# look: footprint_x, height, footprint_z
const SIZES := {
	"storage_jar": Vector3(0.5, 0.8, 0.5), "hide_sack": Vector3(0.5, 0.65, 0.4), "wicker_basket": Vector3(0.6, 0.55, 0.6),
	"weapon_rack": Vector3(1.2, 1.6, 0.3), "armour_stand": Vector3(0.6, 1.8, 0.6), "sign": Vector3(0.6, 1.35, 0.1),
	"tusk_mount": Vector3(0.44, 2.15, 0.3), "clay_bloomery": Vector3(1.2, 1.45, 1.2), "stonecutters_bench": Vector3(2.0, 1.15, 1.0),
	"fish_trap": Vector3(0.8, 0.45, 0.5), "bird_trap": Vector3(0.6, 0.4, 0.6),
}
const NOT_SOLID := ["tusk_mount", "fish_trap", "bird_trap"]   # hung on a wall, or a trap you can walk over (no blocks_walk)

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
			and box.position.y >= -0.01 and box.end.y <= size.y and box.end.y >= 0.4, "%s: in its %s footprint (%s)" % [look, size, box])

		if look not in NOT_SOLID:
			check(_solid_at(node, Vector3(0.0, 0.2, 0.0)), "%s: solid where it stands" % look)

		var tris: int = _triangles(node)
		check(tris <= 300, "%s: under the 300 triangle cap (%d)" % [look, tris])

	print("test_structure_looks_c3c4: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
