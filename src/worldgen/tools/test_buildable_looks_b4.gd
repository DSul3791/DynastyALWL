extends SceneTree

# Buildables plan B4 (10 Nov 2026): every placed light builds inside its footprint (the plan's w x d x h, standing on y = 0; the wall lantern reaching out from
# its wall at z = 0), its lit flames sit where it holds its fire (each flame spot inside the look's box, near the top of a post), and the carried lanterns,
# horn pane and lamp oil have art. Bounds only (no pictures).
#   godot --headless --path . --script res://src/worldgen/tools/test_buildable_looks_b4.gd

const LookTable := preload("res://src/client/look_table.gd")
const PieceLook := preload("res://src/client/piece_look.gd")
const BuildingLook := preload("res://src/client/building_look.gd")
const BasicLook := preload("res://src/client/basic_look.gd")

const SIZES := {
	"wooden_hanging_lantern": Vector3(0.3, 0.4, 0.3), "iron_hanging_lantern": Vector3(0.3, 0.4, 0.3), "iron_wall_lantern": Vector3(0.3, 0.5, 0.6),
	"wooden_torch_post": Vector3(0.3, 2.2, 0.3), "stone_torch_pillar": Vector3(0.5, 2.0, 0.5), "iron_torch_stand": Vector3(0.3, 1.8, 0.3),
	"wooden_lamp_post": Vector3(0.3, 3.0, 1.0), "iron_lamp_post": Vector3(0.3, 3.4, 1.0), "stone_lamp_post": Vector3(0.5, 3.0, 1.2),
	"stone_brazier": Vector3(0.8, 0.7, 0.8), "iron_brazier": Vector3(0.7, 0.8, 0.7),
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
			and box.position.y >= -0.01 and box.end.y <= size.y + slack, "%s: in its %s footprint (%s)" % [look, size, box])
		check(PieceLook.LIGHT_SPOTS.has(look), "%s: has flame spots for lit_fixture" % look)

		if PieceLook.LIGHT_SPOTS.has(look):
			var spots: Array = PieceLook.LIGHT_SPOTS[look]["spots"]
			var inside: bool = true

			for spot in spots:
				var at: Vector3 = spot[0]
				inside = inside and absf(at.x) <= size.x * 0.5 and absf(at.z) <= size.z * 0.5 + 0.01 and at.y > box.end.y - 0.6 - (0.3 if size.y < 0.6 else 0.0) and at.y < box.end.y + 0.4

			check(inside, "%s: its flames are where it holds its fire" % look)
			var fixture: Node3D = BuildingLook.lit_fixture(look)
			check(fixture.get_node_or_null("Light") != null and fixture.get_child_count() > spots.size(), "%s: lit, it draws its flames and a light" % look)
			fixture.free()

	for item in ["wooden_lantern", "iron_lantern", "horn_pane", "lamp_oil"]:
		var mesh: Mesh = BasicLook.mesh_for(item)
		check(mesh != null and mesh.get_aabb().size.length() > 0.05, "%s: has art" % item)

	print("test_buildable_looks_b4: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
