extends SceneTree

# R1 dam test (design/WATER_LAND_TYPES.md 10.1): does a wall-to-wall dam in a gully back water up?
# A synthetic gully 41 cells long (8 m cells, steep walls 15 m, floor falling 1 m per 8 m cell... see _gully) with a stream
# spring at the top. Settles the stream, then raises the dam cells with set_ground (the sim-side set-ground-height step) and
# measures the level upstream before and after. Also: a 2-cell dam across a FLAT wide valley does not back up (water goes round).
#   godot --headless --path . --script res://src/worldgen/tools/test_dam_backup.gd

const WaterSim := preload("res://src/water/water_sim.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print("%s: %s" % ["pass" if ok else "FAIL", what])
	failures += 0 if ok else 1


# side x side cells; the gully runs north to south (j), floor falls fall_per_cell, walls rise wall_m beyond half_width cells of the centre.
func _gully(side: int, half_width: int, fall_per_cell: float, wall_m: float) -> PackedFloat32Array:
	var g: PackedFloat32Array = PackedFloat32Array()
	g.resize(side * side)
	@warning_ignore("integer_division")
	var centre: int = side / 2

	for j in range(side):
		for i in range(side):
			var floor_y: float = 30.0 - fall_per_cell * float(j)
			g[j * side + i] = floor_y + (wall_m if absi(i - centre) > half_width else 0.0)

	return g


func _run(sim, seconds: float) -> void:
	var limit: float = sim.seconds + seconds

	while sim.seconds < limit:
		sim.step()


func _level_at(sim, i: int, j: int) -> float:
	return sim.level(j * sim.side + i)


func _init() -> void:
	var side: int = 41
	@warning_ignore("integer_division")
	var centre: int = side / 2
	var ground: PackedFloat32Array = _gully(side, 1, 0.5, 15.0)    # gully 3 cells (24 m) wide, 0.5 m fall per 8 m, walls 15 m
	var sim = WaterSim.new()
	sim.setup(side, 8.0, ground)
	sim.add_spring(centre, 4, 3.0)
	_run(sim, 3600.0)
	var probe_j: int = 15
	var before: float = _level_at(sim, centre, probe_j)
	var before_depth: float = sim.depth_at(probe_j * side + centre)
	check(before_depth > 0.0, "the stream runs past the dam site before the dam (depth %.2f m at the probe)" % before_depth)

	# Dam: wall to wall across the gully at j = 20, 6 m above the floor (taller than the water).
	for i in range(centre - 2, centre + 3):
		sim.set_ground(i, 20, ground[20 * side + i] + 6.0)

	_run(sim, 3600.0)
	var after: float = _level_at(sim, centre, probe_j)
	print("  level upstream of the dam: %.2f m before, %.2f m after" % [before, after])
	check(after > before + 0.5, "a wall-to-wall dam raises the water upstream (by %.2f m)" % (after - before))
	check(sim.depth_at(30 * side + centre) < before_depth, "and the stream below the dam falls (depth %.2f m)" % sim.depth_at(30 * side + centre))

	# A flat wide valley: a 2-cell dam does not close it; water goes round.
	var flat: PackedFloat32Array = _gully(side, 12, 0.05, 15.0)
	var sim2 = WaterSim.new()
	sim2.setup(side, 8.0, flat)
	sim2.add_spring(centre, 4, 3.0)
	_run(sim2, 3600.0)
	var flat_before: float = _level_at(sim2, centre, probe_j)

	for i in range(centre - 1, centre + 1):
		sim2.set_ground(i, 20, flat[20 * side + i] + 6.0)

	_run(sim2, 3600.0)
	var flat_after: float = _level_at(sim2, centre, probe_j)
	print("  flat valley: %.2f m before, %.2f m after" % [flat_before, flat_after])
	check(flat_after - flat_before < 0.5, "a 2-cell dam in a wide flat valley does not back water up (%.2f m)" % (flat_after - flat_before))

	# Mass stays: a settled pond holds what the spring poured in minus what left.
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
