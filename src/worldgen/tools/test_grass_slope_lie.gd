extends SceneTree

# BUGLIST-001 BUG-006 (distant grass looks flat, then drops onto the slope as the player comes near). A cell gets one ground ray per sample point
# (4 x 4 near, 3 x 3, 2 x 2, and 1 in the very far band of a 6 m cell) and scatters its cards up to half a sample spacing round each hit. The cards
# were laid at the hit's height, so on a slope a far cell was a horizontal sheet over the hill. GrassView.lie_y lays each card on the plane of its hit.
# This checks, on a tilted plane of ground, that at every sample density the card heights match the ground found by a ray at the card's own x and z,
# that the old flat height did not, and that a built cell is looked at again when the player first comes within FINE_GROUND_M of it.
#   godot --headless --path . --script res://src/worldgen/tools/test_grass_slope_lie.gd

const GrassView := preload("res://src/client/grass_view.gd")
const TOLERANCE_M := 0.05      # the ground here is an exact plane; the lie must reproduce it to a few cm
const SLOPE_Y := 0.8           # normal y of the tilted ground (about 37 degrees; steeper than MIN_SLOPE_Y 0.58 is bare rock and gets no grass)

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A slab whose top face is the plane through (0, 10, 0), tilted about z by `tilt`: the slab centre sits 10 m under that point along the tilted normal.
func _slope(tilt: float) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(400.0, 20.0, 400.0)
	shape.shape = box
	body.add_child(shape)
	body.rotation.z = tilt
	body.position = Vector3(10.0 * sin(tilt), 10.0 - 10.0 * cos(tilt), 0.0)
	return body


func _hit(space: PhysicsDirectSpaceState3D, x: float, z: float) -> Dictionary:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 80.0, z), Vector3(x, -80.0, z)))


func _initialize() -> void:
	_run()


func _run() -> void:
	var world: Node3D = Node3D.new()
	get_root().add_child(world)
	var tilt: float = acos(SLOPE_Y)
	var ground: StaticBody3D = _slope(tilt)
	world.add_child(ground)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var probe: Dictionary = _hit(space, 0.0, 0.0)
	check(not probe.is_empty() and absf((probe["normal"] as Vector3).y - SLOPE_Y) < 0.01, "the test ground is a plane tilted to normal y %.2f" % SLOPE_Y)

	# Cells of 6 m, at the sample densities of the four distance bands. Each sample point is hit by a ray at its centre; the cards are then
	# scattered over the whole sample square (grass_view.gd uses 0.95 of it) and laid by lie_y; the ground is found again by a ray at each card.
	var cell_m: float = GrassView.CELL_M
	var worst_lie: float = 0.0
	var worst_flat: float = 0.0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 6

	for pps in [4, 3, 2, 1]:
		var spacing: float = cell_m / float(pps)
		var lie_err: float = 0.0
		var flat_err: float = 0.0

		for cell_x in range(-3, 3):
			for j in range(pps):
				for i in range(pps):
					var x: float = float(cell_x) * cell_m + (float(i) + rng.randf()) * spacing
					var z: float = 12.0 + (float(j) + rng.randf()) * spacing
					var found: Dictionary = _hit(space, x, z)

					if found.is_empty():
						continue

					var point: Vector3 = found["position"]
					var normal: Vector3 = found["normal"]

					for k in range(12):
						var ox: float = point.x + rng.randf_range(-0.5, 0.5) * spacing * 0.95
						var oz: float = point.z + rng.randf_range(-0.5, 0.5) * spacing * 0.95
						var truth: Dictionary = _hit(space, ox, oz)

						if truth.is_empty():
							continue

						var truth_y: float = (truth["position"] as Vector3).y
						lie_err = maxf(lie_err, absf(GrassView.lie_y(point, normal, ox, oz) - truth_y))
						flat_err = maxf(flat_err, absf(point.y - truth_y))

		print("     %d x %d samples: card height error %.3f m with lie_y, %.3f m laid flat" % [pps, pps, lie_err, flat_err])
		check(lie_err <= TOLERANCE_M, "%d x %d samples per cell: cards lie on the slope (%.3f m off)" % [pps, pps, lie_err])
		worst_lie = maxf(worst_lie, lie_err)
		worst_flat = maxf(worst_flat, flat_err)

		if pps == 1:
			check(flat_err > 0.5, "the very far band laid flat hung or sank more than half a metre on this slope (%.2f m): the symptom" % flat_err)

	# Far and near agree: the same point of the slope gets the same card height whichever cell density drew it.
	var anchor: Vector3 = (_hit(space, 1.0, 20.0)["position"] as Vector3)
	var anchor_n: Vector3 = (_hit(space, 1.0, 20.0)["normal"] as Vector3)
	var far_sample: Vector3 = (_hit(space, 3.4, 22.6)["position"] as Vector3)
	var far_n: Vector3 = (_hit(space, 3.4, 22.6)["normal"] as Vector3)
	check(absf(GrassView.lie_y(far_sample, far_n, 1.0, 20.0) - anchor.y) <= TOLERANCE_M, "a far sample 3 m away lays a card at the same height as a near sample on top of it")
	check(absf(GrassView.lie_y(anchor, anchor_n, 3.4, 22.6) - far_sample.y) <= TOLERANCE_M, "and the other way round")
	# Level ground: no change at all.
	check(is_equal_approx(GrassView.lie_y(Vector3(1.0, 5.0, 1.0), Vector3.UP, 4.0, -2.0), 5.0), "level ground: the card stays at the hit's height")

	# A built cell is looked at again, on its own short ladder, when the player first comes within FINE_GROUND_M (the ground collision refines there).
	var grass = GrassView.new()
	grass.radius_m = 120.0
	grass._center = Vector3.ZERO
	var near_cell: Vector2i = Vector2i(int(floor(40.0 / cell_m)), 0)
	var far_cell: Vector2i = Vector2i(int(floor(100.0 / cell_m)), 0)

	for c in [near_cell, far_cell]:
		grass._cells[c] = {"cell": c, "bufs": {}, "count": 0, "retry": 0, "busy": false, "built": true, "fine": false, "lod": grass._lod_of(c, -1)}

	grass._rescan_begin(Vector3.ZERO, 1000)
	var steps: int = 0

	while grass._scan_active and steps < 200:
		grass._rescan_step()
		steps += 1

	check(not grass._scan_active, "the scan over the cells in reach finished")
	check(grass._cells.has(near_cell) and bool(grass._cells[near_cell]["fine"]), "a cell within FINE_GROUND_M is marked as looked at for the fine ground")
	check(grass._cells.has(far_cell) and not bool(grass._cells[far_cell]["fine"]), "a cell beyond it waits")
	var armed: bool = false
	var far_armed: bool = false

	for entry in grass._checks:
		armed = armed or (entry[0] == near_cell and entry[3] == GrassView.FINE_CHECK_TIMES)
		far_armed = far_armed or entry[0] == far_cell

	check(armed, "the near cell has a ground check on the fine ladder")
	check(not far_armed, "no ground check is armed for the far cell")
	check(GrassView.FINE_CHECK_TIMES[0] < GrassView.CHECK_TIMES[2], "the fine ladder starts soon (%d ms)" % int(GrassView.FINE_CHECK_TIMES[0]))
	grass.free()
	print("grass slope lie: %d failures" % failures)
	quit(1 if failures > 0 else 0)
