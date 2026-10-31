extends SceneTree

# Headless: the lean-to model carries a sloped roof collider (not a solid box): ground at the back, 1.5 m at the ridge, crawl space under it.

const BuildingLook := preload("res://src/client/building_look.gd")

var failed: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failed += 1
		print("FAIL: ", what)


func _init() -> void:
	var root: Node3D = BuildingLook.leanto()
	var bodies: Array = []

	for child in root.get_children():
		if child is StaticBody3D:
			bodies.append(child)

	check(bodies.size() == 1, "the lean-to has one collision body")

	if bodies.size() == 1:
		var shape: CollisionShape3D = (bodies[0] as Node).get_child(0) as CollisionShape3D
		var box: BoxShape3D = shape.shape as BoxShape3D
		var xf: Transform3D = Transform3D(Basis.from_euler(shape.rotation), shape.position)
		var back: Vector3 = xf * Vector3(0.0, 0.0, -box.size.z * 0.5)
		var front: Vector3 = xf * Vector3(0.0, 0.0, box.size.z * 0.5)
		var low: Vector3 = back if back.y < front.y else front
		var high: Vector3 = front if back.y < front.y else back
		check(absf(low.y) < 0.02 and absf(low.z - (-0.9)) < 0.02, "the slab meets the ground at the back (z -0.9)")
		check(absf(high.y - 1.5) < 0.02 and absf(high.z - 0.1) < 0.02, "the slab reaches 1.5 m at the ridge (z 0.1)")
		check(absf(box.size.x - 2.6) < 0.01, "2.6 m wide")

	check(BuildingLook.leanto_roof_height(-0.9) == 0.0 and absf(BuildingLook.leanto_roof_height(0.1) - 1.5) < 0.001 and absf(BuildingLook.leanto_roof_height(-0.4) - 0.75) < 0.001, "roof height follows 1.5 * (z + 0.9)")
	check(BuildingLook.leanto_roof_height(0.5) == 0.0, "open front strip has no roof")
	print("test_leanto_collider: ", "PASS" if failed == 0 else "%d FAILED" % failed)
	quit(1 if failed > 0 else 0)
