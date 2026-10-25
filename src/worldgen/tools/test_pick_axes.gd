extends SceneTree
# Headless check of the held pickaxe (Dave's reference rendering, 2026-10-25): a straight haft, one head across it, both ends curving down in the plane of head and droop
# (a long tapering pick one side, a shorter flat chisel the other), nothing bending sideways. HELD_LOOK_TURN["pick"] puts the haft along +y (handle to head), the head
# along x (across the hand) and the droop down (-z), so:
#   - the haft runs along y; the head is wide across x and thin along y (a thin slab from the side);
#   - both tips are lower than the head's middle, by a similar amount, and neither leans fore or aft (y) away from the head;
#   - the pick end is longer than the chisel end.

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
		var head: AABB = AABB()
		var first: bool = true
		var first_head: bool = true

		for v in vertices:
			var w: Vector3 = turn * v
			turned.append(w)
			box = AABB(w, Vector3.ZERO) if first else box.expand(w)
			first = false

			if w.y > 0.2 and absf(w.x) > 0.06:                                                  # the head region (the eye is at y 0.27)
				head = AABB(w, Vector3.ZERO) if first_head else head.expand(w)
				first_head = false

		var pick_tip: Vector3 = _mean_where(turned, 0, box.end.x)         # the +x end
		var chisel: Vector3 = _mean_where(turned, 0, box.position.x)      # the -x end
		print(id, " held box ", box, " head ", head, " tips ", pick_tip, " ", chisel)
		_check(box.size.y > 0.55, id + ": the haft runs along y (%.2f long)" % box.size.y)
		_check(head.size.x > 0.42 and head.size.x < 0.75, id + ": the head is wide across x (%.2f)" % head.size.x)
		_check(head.size.y < 0.1, id + ": from the side the head is a thin slab (y %.2f)" % head.size.y)
		_check(pick_tip.z < -0.02 and chisel.z < -0.02, id + ": both ends curve down (z %.3f and %.3f)" % [pick_tip.z, chisel.z])
		_check(absf(pick_tip.z - chisel.z) < 0.03, id + ": both ends end at a similar height (%.3f vs %.3f)" % [pick_tip.z, chisel.z])
		_check(absf(pick_tip.y - 0.27) < 0.02 and absf(chisel.y - 0.27) < 0.02, id + ": neither end leans fore or aft (y %.3f and %.3f)" % [pick_tip.y, chisel.y])
		_check(pick_tip.x > -chisel.x + 0.04, id + ": the pick end is longer than the chisel end (%.2f vs %.2f)" % [pick_tip.x, -chisel.x])

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
