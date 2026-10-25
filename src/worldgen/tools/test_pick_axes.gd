extends SceneTree
# Headless check of the held pickaxe (Dave's reference picture, 2026-10-25). The pick mesh (basic_look.gd) has its haft along x (pommel at -x, eye at x = 0.27), its head
# along z (pick at +z, chisel at -z) and both ends bending toward the grip (-x), as in the reference. HELD_LOOK_TURN["pick"] holds it with the head vertical (points up and
# down, Dave: "held with the points up and down"; then "flip it 180 degrees so the pointy part is on the bottom"), the haft along +y. So, held, in third person and in first person (which only lean the model about the mount's X axis):
#   - the head runs up and down (z), the pick tip above and the chisel tip below the haft line;
#   - both ends bend toward the grip (-y) in the haft-and-head plane, none sideways (x), tips at the head centre's x within 1 cm;
#   - from the front (along the haft) the head is a straight bar: the head's centre line holds one x within 1 cm;
#   - the model has no roll about the haft (the head axis has no x part).
# On the ground (mesh frame) the same holds with the head along z and the bend toward -x.

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
		var vertices: PackedVector3Array = BasicLook.mesh_for(id).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var turn: Basis = HeldItem.HELD_LOOK_TURN["pick"]
		_check_frame(id + " held", vertices, turn)
		_check_frame(id + " third person", vertices, Basis(Vector3.RIGHT, deg_to_rad(HeldItem.THIRD_LEAN_DEG)) * turn)
		_check_frame(id + " first person", vertices, Basis(Vector3.RIGHT, deg_to_rad(HeldItem.TOOL_TILT_SLIGHT_DEG)) * Basis(Vector3.RIGHT, deg_to_rad(-90.0)) * turn)
		_check_frame(id + " ground", vertices, Basis.IDENTITY, true)

	print("pick axes: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# `basis` takes mesh space to the frame under test; `ground` means the mesh frame itself (haft along x, head along z, bend toward -x).
func _check_frame(label: String, vertices: PackedVector3Array, basis: Basis, ground: bool = false) -> void:
	var head_axis: Vector3 = basis * Vector3(0.0, 0.0, 1.0)         # mesh z: the head's length, pick end positive
	var bend: Vector3 = basis * Vector3(-1.0, 0.0, 0.0)             # mesh -x: toward the grip
	var haft: Vector3 = basis * Vector3(1.0, 0.0, 0.0)              # mesh x: handle to head
	var side: Vector3 = basis * Vector3(0.0, 1.0, 0.0)              # mesh y: the sideways direction (out of the haft-and-head plane)
	var pick: Vector3 = _mean_where(vertices, 2, _extreme(vertices, 2, true), basis)
	var chisel: Vector3 = _mean_where(vertices, 2, _extreme(vertices, 2, false), basis)
	var eye: Vector3 = basis * Vector3(0.27, 0.0, 0.0)
	var pick_bend: float = (pick - eye).dot(bend)
	var chisel_bend: float = (chisel - eye).dot(bend)
	var pick_side: float = (pick - eye).dot(side)
	var chisel_side: float = (chisel - eye).dot(side)
	print(label, " head axis ", head_axis, " bend ", bend, " haft ", haft, " | pick tip bend %.3f side %.3f, chisel tip bend %.3f side %.3f" % [pick_bend, pick_side, chisel_bend, chisel_side])
	_check(absf(head_axis.dot(haft)) < 0.001 and absf(head_axis.dot(side)) < 0.001, label + ": the head axis is square to the haft and in the haft-and-head plane (no roll)")
	_check(pick_bend > 0.015 and chisel_bend > 0.015 and pick_bend < 0.05 and chisel_bend < 0.05, label + ": both ends bend gently toward the grip, 1.5 to 5 cm (%.3f, %.3f)" % [pick_bend, chisel_bend])
	_check(absf(pick_side) < 0.01 and absf(chisel_side) < 0.01, label + ": neither end bends sideways (%.4f, %.4f, limit 0.01)" % [pick_side, chisel_side])
	_check(absf(pick_bend - chisel_bend) < 0.03, label + ": the two ends bend by a similar amount")

	if label.ends_with(" held"):
		_check(head_axis.z < -0.999, label + ": the head stands vertical, pick end down (axis z %.3f)" % head_axis.z)
		_check(pick.z < -0.2 and chisel.z > 0.2, label + ": the pointed pick tip is below and the chisel tip above the haft line (z %.2f, %.2f)" % [pick.z, chisel.z])
		_check(pick.z < chisel.z, label + ": pick tip below chisel tip")
		_check(absf(pick.z + chisel.z) < 0.05, label + ": the collar sits near the middle of the head (tips %.2f down, %.2f up)" % [-pick.z, chisel.z])

	var low: float = 1e9
	var high: float = -1e9

	for v in vertices:
		if v.x > 0.2 and absf(v.z) < 0.04:
			var w: float = (basis * v).dot(side)
			low = minf(low, w)
			high = maxf(high, w)

	_check(high - low < 0.1, label + ": the head block is a thin bar (sideways extent %.3f)" % (high - low))


func _extreme(points: PackedVector3Array, axis: int, high: bool) -> float:
	var best: float = -1e9 if high else 1e9

	for p in points:
		best = maxf(best, p[axis]) if high else minf(best, p[axis])

	return best


func _mean_where(points: PackedVector3Array, axis: int, value: float, basis: Basis) -> Vector3:
	var sum: Vector3 = Vector3.ZERO
	var count: int = 0

	for p in points:
		if absf(p[axis] - value) < 0.0006:
			sum += basis * p
			count += 1

	return sum / maxf(float(count), 1.0)
