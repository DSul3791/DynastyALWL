extends SceneTree

# Item system C3 and C4 (item_system.md draft 7, Jamie's #936 and #938, 10 Nov 2026): the Storage jar, Hide - Sack, Wicker - Basket, Weapon rack,
# Armour stand, Sign, Tusk - Mount, Clay bloomery and Stonecutter's bench looks build inside their structures.json footprints (w x d, centred, standing
# on y = 0, under the height given here), are solid where they stand (not the Tusk mount: it hangs on a wall like the Antler mount, so it is given
# 0.3 m of depth out from the wall), and stay under the look table's triangle cap. Bounds only (no pictures). The set Fish trap and Bird trap (#941,
# fish_trap_set and bird_trap_set) are checked here too; they are not solid. The Iron - Anvil (#950)
# is checked too, and is solid, and so are the Preserving jar and Root cellar (#955) and the B3b Log - Shelf, Iron - Chest and Wooden - Crate.
# The seven-tier ladder's free-standing concrete pieces (10 Nov 2026) are checked too: the Engineered and Fortified pillars, the Fortified gate and wall
# top, and the Mixer.
# The C7 future placeholders (chicken coop, fodder trough, tub, sap tap, cheese press, spinning wheel, loom) have looks before their rows; their
# sizes here are first guesses. The Carpenter's bench (the level-2 workbench rename) is 2.0 x 1.0 like the bench it replaces. The sap tap hangs on a tree (its back at Z = 0, given 0.3 m out from the bark) and is not solid.
#   godot --headless --path . --script res://src/worldgen/tools/test_structure_looks_c3c4.gd

const LookTable := preload("res://src/client/look_table.gd")

# look: footprint_x, height, footprint_z
const SIZES := {
	"storage_jar": Vector3(0.5, 0.8, 0.5), "hide_sack": Vector3(0.5, 0.65, 0.4), "wicker_basket": Vector3(0.6, 0.55, 0.6),
	"weapon_rack": Vector3(1.2, 1.6, 0.3), "armour_stand": Vector3(0.6, 1.8, 0.6), "sign": Vector3(0.6, 1.35, 0.1),
	"tusk_mount": Vector3(0.44, 2.15, 0.3), "clay_bloomery": Vector3(1.2, 1.45, 1.2), "stonecutters_bench": Vector3(2.0, 1.15, 1.0),
	"fish_trap_set": Vector3(0.8, 0.45, 0.5), "bird_trap_set": Vector3(0.6, 0.4, 0.6),
	"iron_anvil": Vector3(0.6, 0.85, 0.4), "preserving_jar": Vector3(0.5, 0.6, 0.5), "root_cellar": Vector3(2.0, 0.7, 2.0),
	"log_shelf": Vector3(1.2, 1.25, 0.3), "iron_chest": Vector3(1.0, 0.65, 0.6), "wooden_crate": Vector3(0.8, 0.85, 0.8),
	"engineered_pillar": Vector3(0.5, 2.6, 0.5), "fortified_pillar": Vector3(0.6, 2.6, 0.6), "fortified_gate": Vector3(2.0, 2.5, 0.3),
	"fortified_wall_top": Vector3(2.0, 0.85, 0.4), "mixer": Vector3(1.2, 1.1, 0.8),
	"chicken_coop": Vector3(1.6, 1.5, 1.2), "fodder_trough": Vector3(1.6, 0.6, 0.5), "tub": Vector3(1.4, 0.6, 0.8), "sap_tap": Vector3(0.3, 1.2, 0.6),
	"cheese_press": Vector3(0.8, 1.4, 0.6), "spinning_wheel": Vector3(1.0, 1.1, 0.5), "loom": Vector3(1.6, 1.85, 0.8),
	"carpenters_bench": Vector3(2.0, 1.1, 1.0),
}
const NOT_SOLID := ["tusk_mount", "fish_trap_set", "bird_trap_set", "sap_tap"]   # hung on a wall, or a trap you can walk over (no blocks_walk)
const LOW := {"fish_trap_set": 0.3, "bird_trap_set": 0.3}   # pieces lower than the usual 0.4 m: the traps lie on the ground

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

	for child in node.find_children("*", "MeshInstance3D", true, false):   # the mesh's own corners, not its turned AABB, which grows on a tipped part
		var mi: MeshInstance3D = child

		if mi.mesh == null:
			continue

		var to_node: Transform3D = node.global_transform.affine_inverse() * mi.global_transform

		for v in mi.mesh.get_faces():
			var p: Vector3 = to_node * v

			if first:
				box = AABB(p, Vector3.ZERO)
				first = false
			else:
				box = box.expand(p)

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
			and box.position.y >= -0.01 and box.end.y <= size.y and box.end.y >= float(LOW.get(look, 0.4)), "%s: in its %s footprint (%s)" % [look, size, box])

		if look not in NOT_SOLID:
			check(_solid_at(node, Vector3(0.0, 0.2, 0.0)), "%s: solid where it stands" % look)

		var tris: int = _triangles(node)
		check(tris <= 300, "%s: under the 300 triangle cap (%d)" % [look, tris])

	print("test_structure_looks_c3c4: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
