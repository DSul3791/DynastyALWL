extends SceneTree

# Sullivan water M1 gate: the closed conservative freshwater grid (src/sullivan_water/freshwater/water_grid_2d.gd), against the guide's test
# matrix (docs/water/Sullivans_Guide_to_Better_Water_in_Godot_Edition_3.md section 21) and the M1 gate (section 13: a 10k step volume ledger,
# dry/wet, a stable pond). Made-up grids only, a few seconds, no tile, no rendering.
#   godot --headless --path . --script res://src/worldgen/tools/test_sullivan_water_grid.gd
#
# Tolerances are chosen before running (guide 21): F01 relative error < 1e-6 after 1000 ticks; every ledger residual < 1e-9 of the water
# involved; negative volume never below -1e-12 m^3 before the rounding guard.

const Grid := preload("res://src/sullivan_water/freshwater/water_grid_2d.gd")

const REL_TOL := 1.0e-6
const LEDGER_TOL := 1.0e-9
const NEG_TOL := -1.0e-12

var failures: int = 0


func _init() -> void:
	var begun: int = Time.get_ticks_msec()
	print("engine %s" % Engine.get_version_info().get("string", "?"))
	_f01_closed_basin()
	_f02_one_cell()
	_f03_raised_face()
	_f04_f05_dam()
	_law_compare()
	_f07_raise_under_water()
	_surface_not_ground()
	_f09_frame_rate()
	_mirror()
	_f13_withdrawal()
	_m1_ten_thousand()
	print("%d failures, %d ms" % [failures, Time.get_ticks_msec() - begun])
	quit(1 if failures > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# Godot's % has no %e: small numbers go through num_scientific.
func _e(x: float) -> String:
	return String.num_scientific(x)


# A bumpy basin bed: deterministic, a few decimetres of relief, no random state.
func _bumpy(grid, relief: float) -> void:
	for j in range(grid.h):
		for i in range(grid.w):
			grid.set_bed(i, j, relief * (0.5 + 0.5 * sin(i * 1.3 + j * 0.7) * cos(j * 1.1 - i * 0.4)))


func _report(name: String, grid) -> void:
	print("  %s: ticks %d, volume %.9f m3, expected %.9f, residual %s, min cell %s, worst negative %s, rounding %s, scaled cells last tick %d" % [
		name, grid.ticks, grid.total_volume(), grid.expected_volume(), _e(grid.ledger_residual()), _e(grid.min_volume()), _e(grid.max_negative_m3),
		_e(grid.rounding_m3), grid.last_scaled_cells])


# F01: 16 x 16 closed basin with 100 m^3; relative volume error < 1e-6 after 1000 ticks; no negative cells.
func _f01_closed_basin() -> void:
	var grid = Grid.new(16, 16)
	_bumpy(grid, 0.6)

	for k in range(16 * 16):
		var i: int = k % 16
		@warning_ignore("integer_division")
		var j: int = k / 16
		grid.add_water(i, j, 100.0 * float(i + 1) / 2176.0, "f01")   # 1 + 2 + ... + 16 = 136, times 16 rows = 2176: uneven, sums to 100

	var negative: bool = false

	for t in range(1000):
		grid.step()
		negative = negative or grid.min_volume() < 0.0

	_report("F01", grid)
	_check(absf(grid.total_volume() - 100.0) / 100.0 < REL_TOL, "F01: 100 m3 in a closed 16x16 basin stays 100 m3 after 1000 ticks (relative error %s)" % _e(absf(grid.total_volume() - 100.0) / 100.0))
	_check(not negative and grid.max_negative_m3 >= NEG_TOL, "F01: no cell goes negative (worst %s m3)" % _e(grid.max_negative_m3))


# F02: all the water in one cell; none created or lost, nonnegative every tick, a stable spread.
func _f02_one_cell() -> void:
	var grid = Grid.new(16, 16)
	grid.add_water(3, 4, 100.0, "f02")   # 25 m deep in one 2 m cell: a tower of water
	var negative: bool = false
	var worst: float = 0.0

	for t in range(4000):
		grid.step()
		negative = negative or grid.min_volume() < 0.0
		worst = maxf(worst, absf(grid.ledger_residual()))

	var wet: int = 0

	for k in range(16 * 16):
		wet += 1 if grid.volume[k] > 1.0e-9 else 0

	_report("F02", grid)
	_check(worst < LEDGER_TOL * 100.0, "F02: no water made or lost on any tick (worst residual %s m3)" % _e(worst))
	_check(not negative, "F02: every cell nonnegative on every tick")
	_check(wet == 256, "F02: the tower spread over the whole flat basin (%d of 256 cells wet)" % wet)
	_check(grid.max_wet_head() < 0.005, "F02: and settled level, no sloshing (largest step between wet cells %.4f m; flat at %.4f m deep)" % [grid.max_wet_head(), 100.0 / 1024.0])


# F03: two basins split by a raised face line: no flow before opening; flow after the crest is lowered, equal to the exchanged volume.
func _f03_raised_face() -> void:
	var grid = Grid.new(16, 8)

	for j in range(8):
		grid.set_crest_east(7, j, 2.0)   # a 2 m wall between columns 7 and 8

	for j in range(8):
		for i in range(8):
			grid.add_water(i, j, 1.0 * grid.area_m2, "f03")   # 1 m deep on the west side

	for t in range(300):
		grid.step()

	var east_before: float = _volume_in(grid, 8, 16)
	var west_before: float = _volume_in(grid, 0, 8)
	_check(east_before == 0.0, "F03: nothing crosses a 2 m crest from 1 m deep water (east side %s m3)" % _e(east_before))

	for j in range(8):
		grid.set_crest_east(7, j, Grid.OPEN)

	for t in range(600):
		grid.step()

	var east_after: float = _volume_in(grid, 8, 16)
	var west_after: float = _volume_in(grid, 0, 8)
	_report("F03", grid)
	_check(east_after > 0.0, "F03: water flows once the crest is lowered (east side %.3f m3)" % east_after)
	_check(absf((west_before - west_after) - east_after) < LEDGER_TOL * west_before, "F03: what the east gained (%.6f m3) is what the west lost (%.6f m3)" % [east_after, west_before - west_after])


func _volume_in(grid, i_from: int, i_to: int) -> float:
	var sum: float = 0.0

	for j in range(grid.h):
		for i in range(i_from, i_to):
			sum += grid.volume[grid.index(i, j)]
	return sum


# F04 and F05: a 3 m dam across a channel with a named spring upstream. Below the crest nothing passes and the reservoir rises; above it the
# water spills over, gradually (not a jump to level); removing the dam releases the stored water downstream with no water made or lost.
func _f04_f05_dam() -> void:
	var grid = Grid.new(16, 4)

	for j in range(4):
		grid.set_crest_east(7, j, 3.0)

	grid.add_spring(0, 1, 2.0, "f04 spring")   # 2 m3/s into a 32 cell (128 m2) reservoir: 3 m deep after 192 s
	grid.add_sink(15, 1, 5.0, "f04 outlet")    # the river leaving downstream (a declared outlet), so the far side does not fill up to the crest
	var spilled_at: int = -1
	var dry_while_below: bool = true
	var first_spill: float = 0.0

	for t in range(4000):
		grid.step()
		var up: float = grid.surface(3, 1)
		var down: float = _volume_in(grid, 8, 16)

		if up < 3.0 - 0.01 and down > 0.0:
			dry_while_below = false

		if spilled_at < 0 and down > 0.0:
			spilled_at = t
			first_spill = down

	var level_up: float = grid.surface(3, 1)
	_report("F04", grid)
	_check(dry_while_below, "F04: no water past the dam while the reservoir is below the 3 m crest")
	_check(spilled_at > 1800, "F04: the reservoir filled first and spilled only at tick %d (3 m needs about 1920 ticks of the spring)" % spilled_at)
	_check(first_spill < 1.0, "F04: the first spill is a trickle, not a jump to level (%.4f m3 in its first tick)" % first_spill)
	_check(level_up >= 3.0 and level_up < 3.5, "F04: the reservoir holds just over the crest while it spills (%.3f m)" % level_up)
	_check(absf(grid.ledger_residual()) < LEDGER_TOL * grid.total_volume(), "F04: ledger balances with the named spring (residual %s m3, spring %.3f m3)" % [_e(grid.ledger_residual()), float(grid.by_id.get("f04 spring", 0.0))])

	# F05: the dam goes at a recorded tick; the spring and the outlet stop so the stored water alone moves, with nothing leaving.
	grid.springs.clear()
	grid.sinks.clear()
	var removed_at: int = grid.ticks
	var up_before: float = _volume_in(grid, 0, 8)
	var down_before: float = _volume_in(grid, 8, 16)

	for j in range(4):
		grid.set_crest_east(7, j, Grid.OPEN)

	for t in range(3000):
		grid.step()

	var up_after: float = _volume_in(grid, 0, 8)
	var down_after: float = _volume_in(grid, 8, 16)
	_report("F05", grid)
	_check(down_after - down_before > 0.25 * up_before, "F05: removing the dam at tick %d sent the stored water downstream (%.1f m3 of %.1f)" % [removed_at, down_after - down_before, up_before])
	_check(absf((up_before + down_before) - (up_after + down_after)) < LEDGER_TOL * (up_before + down_before), "F05: same combined inventory before and after (%.6f / %.6f m3)" % [up_before + down_before, up_after + down_after])


# Not a check: the same F04 reservoir with the guide's orifice law, so the decision record (README decision 1) has its measurement each run.
func _law_compare() -> void:
	for law in [Grid.LAW_PIPE, Grid.LAW_ORIFICE]:
		var grid = Grid.new(16, 4)
		grid.law = law

		for j in range(4):
			grid.set_crest_east(7, j, 3.0)

		grid.add_spring(0, 1, 2.0, "spring")
		grid.add_sink(15, 1, 5.0, "outlet")

		for _t in range(4000):
			grid.step()

		print("  law %s: reservoir far end %.3f m, at the dam %.3f m (crest 3.0)" % ["pipe" if law == Grid.LAW_PIPE else "orifice", grid.surface(0, 1), grid.surface(7, 1)])


# F07 (the open-air part; the voxel edit part is M3): raising ground under standing water keeps the water; the surface rises with the bed.
func _f07_raise_under_water() -> void:
	var grid = Grid.new(8, 8)
	grid.fill_to_level(1.0)
	var before: float = grid.total_volume()
	var cell_before: float = grid.volume[grid.index(4, 4)]
	grid.set_bed(4, 4, 0.8)
	_check(grid.volume[grid.index(4, 4)] == cell_before, "F07: the raised cell keeps its %.3f m3" % cell_before)
	_check(absf(grid.surface(4, 4) - 1.8) < 1.0e-12, "F07: its surface rose with the bed to %.3f m" % grid.surface(4, 4))

	for t in range(2000):
		grid.step()

	_check(absf(grid.total_volume() - before) < LEDGER_TOL * before, "F07: no water lost after it spreads out (%.9f / %.9f m3)" % [grid.total_volume(), before])
	_check(grid.surface(0, 0) > 1.0, "F07: the displaced water raised the pond around it (%.4f m)" % grid.surface(0, 0))


# Guide 3.9: water follows the SURFACE, not the ground. A pond spills over a hump lower than its surface; a ridge above the surface holds.
func _surface_not_ground() -> void:
	var grid = Grid.new(12, 1)

	for i in range(12):
		grid.set_bed(i, 0, 0.5 if i == 5 else 0.0)

	for i in range(5):
		grid.add_water(i, 0, 1.0 * grid.area_m2, "pond")

	for t in range(500):
		grid.step()

	_check(_volume_in(grid, 6, 12) > 0.0, "3.9: a 1 m pond spills over a 0.5 m hump into the dry ground beyond (%.3f m3)" % _volume_in(grid, 6, 12))

	var ridge = Grid.new(12, 1)

	for i in range(12):
		ridge.set_bed(i, 0, 1.5 if i == 5 else -1.0 if i > 5 else 0.0)   # the far side is a lower ditch, behind a ridge

	for i in range(5):
		ridge.add_water(i, 0, 1.0 * ridge.area_m2, "pond")

	for t in range(500):
		ridge.step()

	_check(_volume_in(ridge, 6, 12) == 0.0, "3.9: a ditch lower than the pond stays dry behind a ridge above the pond's surface")


# F09: 10 and 60 frames a second give the same water once the same fixed ticks have run.
func _f09_frame_rate() -> void:
	var a = Grid.new(16, 16)
	var b = Grid.new(16, 16)

	for g in [a, b]:
		_bumpy(g, 0.6)
		g.add_water(2, 2, 40.0, "f09")
		g.add_spring(10, 12, 0.3, "f09 spring")

	while a.ticks < 300:
		a.advance(1.0 / 10.0 + 1.0e-9)

	while b.ticks < 300:
		b.advance(1.0 / 60.0)

	var most: float = 0.0

	for k in range(256):
		most = maxf(most, absf(a.volume[k] - b.volume[k]))

	_check(a.ticks == 300 and b.ticks == 300 and most == 0.0, "F09: 10 fps and 60 fps agree exactly after 300 ticks (largest cell difference %s m3)" % _e(most))


# No directional bias (guide 3.2): a setup and its east-west mirror give mirrored water.
func _mirror() -> void:
	var a = Grid.new(15, 9)
	var b = Grid.new(15, 9)

	for j in range(9):
		for i in range(15):
			var y: float = 0.3 * sin(i * 0.9) + 0.2 * cos(j * 1.7)
			a.set_bed(i, j, y)
			b.set_bed(14 - i, j, y)

	a.add_water(2, 3, 30.0, "m")
	b.add_water(12, 3, 30.0, "m")

	for t in range(800):
		a.step()
		b.step()

	var most: float = 0.0

	for j in range(9):
		for i in range(15):
			most = maxf(most, absf(a.volume[a.index(i, j)] - b.volume[b.index(14 - i, j)]))

	_check(most < 1.0e-9, "3.2: mirrored setups give mirrored water, so face order adds no bias (largest difference %s m3)" % _e(most))


# F13: a withdrawal asking for more than there is gets only what is there; inventory never negative.
func _f13_withdrawal() -> void:
	var grid = Grid.new(4, 4)
	grid.add_water(1, 1, 1.0, "f13")
	var got: float = grid.remove_water(1, 1, 5.0, "field")
	_check(got == 1.0 and grid.volume[grid.index(1, 1)] == 0.0, "F13: a 5 m3 request on a 1 m3 cell is granted 1 m3 (got %.3f)" % got)

	grid.add_water(2, 2, 0.5, "f13")
	grid.add_sink(2, 2, 10.0, "intake")   # 1 m3 a tick asked of 0.5 m3
	grid.step()
	_check(grid.min_volume() >= 0.0 and absf(float(grid.by_id["intake"]) + 0.5) < 1.0e-12, "F13: a sink asking 1 m3 a tick of a 0.5 m3 cell took 0.5 (booked %.3f)" % float(grid.by_id["intake"]))
	_check(absf(grid.ledger_residual()) < 1.0e-12, "F13: ledger balances (residual %s)" % _e(grid.ledger_residual()))


# M1 gate: a 10k tick ledger with a spring and a sink running, dry and wet cells, ending in a stable pond.
func _m1_ten_thousand() -> void:
	var grid = Grid.new(16, 16)
	_bumpy(grid, 1.2)
	grid.add_spring(1, 1, 0.4, "spring")
	grid.add_sink(14, 14, 0.3, "drain")
	var worst: float = 0.0
	var negative: bool = false

	for t in range(10000):
		grid.step()
		worst = maxf(worst, absf(grid.ledger_residual()) / maxf(grid.total_volume(), 1.0))
		negative = negative or grid.min_volume() < 0.0

	_report("M1", grid)
	print("  M1 ledger: spring %.3f m3, drain %.3f m3, rounding %s m3" % [float(grid.by_id.get("spring", 0.0)), -float(grid.by_id.get("drain", 0.0)), _e(grid.rounding_m3)])
	_check(worst < LEDGER_TOL, "M1: 10000 ticks with a spring and a drain, ledger residual never above %s of the water (worst %s)" % [_e(LEDGER_TOL), _e(worst)])
	_check(not negative, "M1: no negative cell in 10000 ticks")

	# Stop the inflow and outflow; the pond must come to rest.
	grid.springs.clear()
	grid.sinks.clear()

	for t in range(4000):
		grid.step()

	_check(grid.max_wet_head() < 0.005, "M1: with inflow stopped the pond settles (largest step between wet cells %.4f m)" % grid.max_wet_head())
