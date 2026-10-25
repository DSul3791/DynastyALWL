extends SceneTree
# Headless check of the held pickaxe's axes (Dave 2026-10-25: it was bent sideways; it is a grub hoe / pick mattock). The pick mesh (basic_look.gd) has its haft
# along x, its head along z (pick at +z, broad blade at -z) and the bends toward the grip (-x). HELD_LOOK_TURN["pick"] must put the haft along +y (the held
# model's handle-to-head axis) and the head along z (up and down in the hand), so that:
#   - from the front (looking along the haft) the head is one narrow straight bar: its x extent is small and centred on the haft;
#   - both ends bend the same way, toward the grip (-y), by a similar amount;
#   - the pick tip is above the head centre and the blade edge below it (or the reverse), the head's middle on the haft.

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
		var turned: Array = []
		var box: AABB = AABB()
		var first: bool = true

		for v in vertices:
			var w: Vector3 = turn * v
			turned.append(w)
			box = AABB(w, Vector3.ZERO) if first else box.expand(w)
			first = false

		var top: Vector3 = _mean_where(turned, 2, box.end.z)             # the highest points (the pick tip)
		var bottom: Vector3 = _mean_where(turned, 2, box.position.z)     # the lowest points (the blade edge)
		var middle: Vector3 = _mean_where(turned, 2, 0.5 * (box.position.z + box.end.z) * 0.0)
		print(id, " held box ", box, " pick tip ", top, " blade edge ", bottom)
		_check(box.size.y > 0.55, id + ": the haft runs along y (%.2f long)" % box.size.y)
		_check(box.size.x < 0.2 and absf(box.position.x + box.size.x * 0.5) < 0.01, id + ": from the front the head is one narrow bar centred on the haft (x %.2f wide)" % box.size.x)
		_check(box.size.z > 0.3, id + ": the head runs up and down in the hand (z %.2f)" % box.size.z)
		_check(top.z > 0.12 and bottom.z < -0.12, id + ": pick tip above and blade edge below the middle (%.2f, %.2f)" % [top.z, bottom.z])
		_check(top.y < 0.27 - 0.02 and bottom.y < 0.27 - 0.02, id + ": both ends bend toward the grip (y %.2f and %.2f, eye at 0.27)" % [top.y, bottom.y])
		_check(absf(top.x) < 0.01 and absf(bottom.x) < 0.01, id + ": neither end leans sideways (x %.3f and %.3f)" % [top.x, bottom.x])

	print("pick axes: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _mean_where(points: Array, axis: int, value: float) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var count: int = 0

	for p in points:
		if absf(p[axis] - value) < 0.0006:
			sum += p
			count += 1

	return sum / maxf(float(count), 1.0)
