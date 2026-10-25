extends SceneTree
# Headless check of the held pickaxe's axes (Dave 2026-10-25: it was bent sideways). The pick mesh (basic_look.gd) has its haft along x and its head along z,
# drooping toward -y. HELD_LOOK_TURN["pick"] must put the haft along +y (the held model's handle-to-head axis), the head tips left and right at the same
# height and the same distance from the haft, and the droop straight down (-z in the held model, the mount's +z is up) the same on both sides.

const BasicLook := preload("res://src/client/basic_look.gd")
const HeldItem := preload("res://src/client/held_item.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	for id in ["iron_pickaxe", "steel_pickaxe"]:
		var mesh: Mesh = BasicLook.mesh_for(id)
		var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var turn: Basis = HeldItem.HELD_LOOK_TURN["pick"]
		var box: AABB = AABB()
		var first: bool = true
		var turned: Array = []

		for v in vertices:
			var w: Vector3 = turn * v
			turned.append(w)
			box = AABB(w, Vector3.ZERO) if first else box.expand(w)
			first = false

		# The tip of each side is the average of the vertices at the extreme x (a box end has several corners at the same x).
		var right_tip: Vector3 = _mean_at(turned, box.end.x)
		var left_tip: Vector3 = _mean_at(turned, box.position.x)

		print(id, " held box ", box, " right tip ", right_tip, " left tip ", left_tip)
		_check(absf(right_tip.x + left_tip.x) < 0.005, id + ": the head is centred on the haft (tips equal distance left and right)")
		_check(absf(right_tip.y - left_tip.y) < 0.005 and absf(right_tip.z - left_tip.z) < 0.005, id + ": the two tips are at the same height and the same depth")
		_check(right_tip.z < -0.05 and left_tip.z < -0.05, id + ": the points droop downward (held z is up) on both sides")
		_check(absf(box.size.y) > 0.55 and box.size.x > 0.4 and box.size.x < 0.7, id + ": the haft runs along y (%.2f long) and the head along x (%.2f wide)" % [box.size.y, box.size.x])
		_check(absf(box.position.x + box.size.x * 0.5) < 0.005, id + ": the whole mesh is symmetrical about the haft in x")

	print("pick axes: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _mean_at(points: Array, x: float) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var count: int = 0

	for p in points:
		if absf(p.x - x) < 0.0005:
			sum += p
			count += 1

	return sum / maxf(float(count), 1.0)
