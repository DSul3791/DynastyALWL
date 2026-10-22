extends SceneTree

# Tunnel measurement (tech/EXCAVATION_BRACING_GROUND_DESIGN.md section 1): a wide tunnel under cover is a working excavation,
# a narrow one needs nothing, a pit open to the sky never counts.
#   godot --headless --path . --script res://src/worldgen/tools/test_tunnel_stability.gd

const GroundOps := preload("res://src/stream/ground_ops.gd")
const Stability := preload("res://src/stream/tunnel_stability.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _solid() -> VoxelBuffer:
	var buffer: VoxelBuffer = Layout.make_buffer(16)

	for z in range(16):
		for y in range(16):
			for x in range(16):
				buffer.set_voxel_f(-3.0, x, y, z, Layout.CHANNEL_SDF)
				buffer.set_voxel(1, x, y, z, Layout.CHANNEL_SOIL)

	return buffer


func _tunnel(radius: float) -> VoxelBuffer:
	var buffer: VoxelBuffer = _solid()

	for x in range(-2, 19, 1):
		GroundOps.apply_op(buffer, Vector3.ZERO, GroundOps.KIND_DIG, 0, Vector3(float(x), 8.0, 8.0), radius)

	return buffer


func _init() -> void:
	var deep: Callable = func(_x: float, _z: float) -> float: return 40.0
	var wide: Array = Stability.working(Stability.classify(_tunnel(2.2), Vector3.ZERO, deep))
	var near: Callable = func(_x: float, _z: float) -> float: return 14.0
	var narrow: Array = Stability.working(Stability.classify(_tunnel(0.9), Vector3.ZERO, near))
	_check(not wide.is_empty(), "a 4.4 m wide tunnel under 30 m of cover is working (%d cells)" % wide.size())
	_check(narrow.is_empty(), "a 1.8 m tunnel under 5 m of cover needs no bracing (%d cells)" % narrow.size())

	if not wide.is_empty():
		_check(float(wide[0]["need"]) > 0.0 and float(wide[0]["need"]) <= 1.0, "need is between 0 and 1 (%.2f)" % float(wide[0]["need"]))

	var shallow: Callable = func(_x: float, _z: float) -> float: return 9.0
	var open_pit: Array = Stability.working(Stability.classify(_tunnel(2.2), Vector3.ZERO, shallow))
	_check(open_pit.is_empty(), "a cut with no real cover above counts as open, not a roof (%d cells)" % open_pit.size())
	print("test_tunnel_stability: %d failures" % failures)
	quit(1 if failures > 0 else 0)
