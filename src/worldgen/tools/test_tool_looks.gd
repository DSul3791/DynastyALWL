extends SceneTree
# Headless check of the tool looks brought to the pickaxe standard (Dave 2026-10-25), one group per round. Spades: a long straight haft along x with the blade at +x, wide in z
# and thin in y, metal tiers (iron, steel) on the metal surface, wood and stone tiers on one plain surface, the blade narrowing to a point.

const BasicLook := preload("res://src/client/basic_look.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	for tier in ["wooden", "stone", "iron", "steel"]:
		for size in ["", "_medium", "_large"]:
			var id: String = tier + "_spade" + size
			var mesh: Mesh = BasicLook.mesh_for(id)
			var metal: bool = tier in ["iron", "steel"]
			var box: AABB = mesh.get_aabb()
			var scale: float = float(BasicLook.entry(id).get("size", 1.0))
			var blade_width: float = _width_near(mesh, 0.46 * scale)
			var tip_width: float = _width_near(mesh, 0.6 * scale)
			_check(mesh.get_surface_count() == (2 if metal else 1), id + ": surfaces %d (metal tiers have the metal head surface)" % mesh.get_surface_count())
			_check(box.size.x > 0.9 * scale and box.size.x < 1.1 * scale, id + ": haft and blade run along x, %.2f m (size %.1f)" % [box.size.x, scale])
			_check(box.size.y < 0.05 * scale and box.size.z > 0.18 * scale, id + ": the blade is thin (y %.3f) and wide (z %.3f)" % [box.size.y, box.size.z])
			_check(tip_width < 0.5 * blade_width, id + ": the blade narrows to a point (width %.3f at the tip, %.3f at the middle)" % [tip_width, blade_width])

	# Axes and hammers: a straight haft along x with the head at its +x end, head wider in z than the haft is thick, all on one plain surface (no metal heads yet).
	for id in ["stone_axe", "stone_hammer", "wooden_hammer"]:
		var mesh: Mesh = BasicLook.mesh_for(id)
		var box: AABB = mesh.get_aabb()
		var scale: float = float(BasicLook.entry(id).get("size", 1.0))
		_check(mesh.get_surface_count() == 1, id + ": one plain surface")
		_check(box.size.x > 0.4 * scale and box.size.x < 0.9 * scale, id + ": haft along x, %.2f m long (size %.1f)" % [box.size.x, scale])
		_check(box.size.z > 0.1 * scale, id + ": the head is wide across the haft (z %.3f)" % box.size.z)
		_check(_width_near(mesh, 0.22 * scale, 0.1 * scale) > 0.1 * scale, id + ": the head sits at the haft's end (width %.3f near x 0.22)" % _width_near(mesh, 0.22 * scale, 0.1 * scale))
	_check(str(BasicLook.entry("wooden_hammer").get("shape", "")) == "hammer", "wooden_hammer is drawn as a mallet, not an axe")

	print("tool looks: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# The z extent of the vertices whose x is within `within` of `at`.
func _width_near(mesh: Mesh, at: float, within: float = 0.02) -> float:
	var low: float = 1e9
	var high: float = -1e9

	for surface in mesh.get_surface_count():
		for v in (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
			if absf(v.x - at) < within:
				low = minf(low, v.z)
				high = maxf(high, v.z)

	return high - low
