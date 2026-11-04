extends SceneTree

# Headless: the lean-to model carries a sloped roof collider (not a solid box): ground at the back, 2.4 m at the ridge (Dave 3 Nov: big enough to walk in and lie down), crawl space under the back.

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
		check(absf(low.y) < 0.02 and absf(low.z - (-2.72)) < 0.02, "the slab meets the ground at the back (z -2.72)")
		check(absf(atan2(high.y - low.y, high.z - low.z) - deg_to_rad(35.5)) < 0.03, "the roof slopes about 35 degrees")
		check(absf(high.y - 2.4) < 0.02 and absf(high.z - 0.64) < 0.02, "the slab reaches 2.4 m at the ridge (z 0.64): a grown person stands up under the front")
		check(absf(box.size.x - 4.16) < 0.01, "4.16 m wide")

	check(BuildingLook.leanto_roof_height(-2.72) == 0.0 and absf(BuildingLook.leanto_roof_height(0.64) - 2.4) < 0.001 and absf(BuildingLook.leanto_roof_height(-1.04) - 1.2) < 0.001, "roof height follows 2.4 * (z + 2.72) / 3.36")
	check(BuildingLook.leanto_roof_height(0.64 - 1.9) > 0.5 and BuildingLook.leanto_roof_height(0.64 - 1.9 - 0.0) < 2.4, "room to lie down: 1.9 m of floor behind the ridge still has more than 0.5 m of roof over it")
	check(BuildingLook.leanto_roof_height(1.0) == 0.0, "open front strip has no roof")
	print("test_leanto_collider: ", "PASS" if failed == 0 else "%d FAILED" % failed)
	quit(1 if failed > 0 else 0)
