extends SceneTree

# Headless checks for the water simulation: godot --headless --script this file.

const WaterSim := preload("res://src/water/water_sim.gd")

var _passed: int = 0
var _failed: int = 0


func _check(ok: bool, message: String) -> void:
	if ok:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: ", message)


func _flat(side: int, height: float) -> PackedFloat32Array:
	var g: PackedFloat32Array = PackedFloat32Array()
	g.resize(side * side)
	g.fill(height)
	return g


func _run(sim, ticks: int) -> void:
	for t in range(ticks):
		sim.step()


# Runs a stretch of simulated time (the water moves in real seconds).
func _run_s(sim, seconds: float) -> void:
	var until: float = sim.seconds + seconds

	while sim.seconds < until:
		sim.step()


func _initialize() -> void:
	# Both versions of the core: C++ (when the add-on loads) and the GDScript fallback.
	var probe = WaterSim.new()
	probe.setup(3, 8.0, _flat(3, 1.0))
	print("water sim: C++ core %s" % ("loaded" if probe.native() else "not loaded"))

	if probe.native():
		_suite()
		print("  (above: C++ core; below: GDScript fallback)")

	WaterSim.force_script = true
	_suite()
	WaterSim.force_script = false
	print("water sim: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _suite() -> void:
	# 1. A closed bowl fills level and keeps every drop of water.
	var g: PackedFloat32Array = _flat(21, 10.0)

	for j in range(5, 16):
		for i in range(5, 16):
			g[j * 21 + i] = 5.0

	var bowl = WaterSim.new()
	bowl.setup(21, 8.0, g)
	bowl.add_water(10, 10, 3.0)
	var before: float = bowl.total_volume()
	_run(bowl, 400)
	_check(absf(bowl.total_volume() + bowl.evaporated_m3 + bowl.sea_m3 - before) < before * 0.001, "a closed bowl keeps all its water (%f vs %f)" % [bowl.total_volume(), before])
	var lowest: float = INF
	var highest: float = -INF

	for j in range(5, 16):
		for i in range(5, 16):
			var k: int = j * 21 + i

			if bowl.depth_at(k) > 0.05:
				lowest = minf(lowest, bowl.level(k))
				highest = maxf(highest, bowl.level(k))

	_check(highest - lowest < 0.1, "water in a bowl settles to one level (spread %f)" % (highest - lowest))

	# 2. A spring over a rim spills and runs downhill to the sea.
	var side: int = 41
	var slope: PackedFloat32Array = _flat(side, 0.0)

	for j in range(side):
		for i in range(side):
			slope[j * side + i] = float(side - 1 - i) * 1.0 - 0.0   # high at left (40 m), sea at right

	var river = WaterSim.new()
	river.setup(side, 8.0, slope)
	river.add_spring(2, 20, 5.0)
	_run_s(river, 1200.0)
	_check(river.depth_at(20 * side + 20) > 0.01, "a spring's water reaches downhill (%f)" % river.depth_at(20 * side + 20))
	_check(river.sea_m3 > 0.0, "water reaches the sea")

	# 3. A dam: block the valley, the water backs up behind it.
	var valley: PackedFloat32Array = _flat(side, 0.0)

	for j in range(side):
		for i in range(side):
			var wall: float = absf(float(j) - 20.0) * 3.0
			valley[j * side + i] = float(side - 1 - i) * 0.5 + wall

	var open = WaterSim.new()
	open.setup(side, 8.0, valley.duplicate())
	open.add_spring(2, 20, 3.0)
	_run_s(open, 1500.0)
	var open_up: float = open.depth_at(20 * side + 8)

	var dammed = WaterSim.new()
	dammed.setup(side, 8.0, valley.duplicate())
	dammed.add_spring(2, 20, 3.0)

	for j in range(0, side):
		dammed.set_ground(20, j, 40.0)

	_run_s(dammed, 1500.0)
	_check(dammed.depth_at(20 * side + 10) > open_up + 0.3, "a dam backs water up behind it (%f vs %f)" % [dammed.depth_at(20 * side + 10), open_up])
	_check(dammed.depth_at(20 * side + 30) < 0.05, "nothing flows past a dam")

	# Break the dam: the stored water runs out.
	dammed.set_ground(20, 20, valley[20 * side + 20])
	_run_s(dammed, 1500.0)
	_check(dammed.depth_at(20 * side + 30) > 0.05, "a broken dam lets the water through")

	# 4. A stranded puddle dries.
	var dry = WaterSim.new()
	var pit: PackedFloat32Array = _flat(9, 5.0)
	pit[4 * 9 + 4] = 4.97
	dry.setup(9, 8.0, pit)
	dry.add_water(4, 4, 0.03)
	_run_s(dry, 600.0)
	_check(dry.depth_at(4 * 9 + 4) < 0.001, "a stranded puddle dries")

	# 5. The spring multiplier (rain later) swells the flow.
	var swell = WaterSim.new()
	swell.setup(side, 8.0, slope.duplicate())
	swell.add_spring(2, 20, 3.0)
	_run_s(swell, 900.0)
	var calm: float = swell.depth_at(20 * side + 10)
	swell.spring_multiplier = 3.0
	_run_s(swell, 900.0)
	_check(swell.depth_at(20 * side + 10) > calm, "a bigger spring rate makes the river swell")

	# 6. Real flow (owner, 2026-10-19): in a channel, less water runs shallower (a
	# trickle at 0.1) and more water rises and spreads wider (a flood at 5x).
	var channel: PackedFloat32Array = _flat(side, 0.0)

	for j in range(side):
		for i in range(side):
			channel[j * side + i] = float(side - 1 - i) * 0.08 + absf(float(j) - 20.0) * 0.4

	var flood = WaterSim.new()
	flood.setup(side, 8.0, channel)
	flood.add_spring(2, 20, 10.0)
	_run_s(flood, 3000.0)
	var normal_depth: float = flood.depth_at(20 * side + 20)
	var normal_wet: int = flood.wet_cells()
	flood.spring_multiplier = 0.1
	_run_s(flood, 3000.0)
	var low_depth: float = flood.depth_at(20 * side + 20)
	_check(low_depth < normal_depth * 0.5, "at 0.1 the river drops to a trickle (%.2f m from %.2f m)" % [low_depth, normal_depth])
	flood.spring_multiplier = 5.0
	_run_s(flood, 3000.0)
	print("  channel at 10 m3/s: %.2f m deep, %d wet squares; at 0.1: %.2f m; at 5x: %.2f m, %d wet squares" % [normal_depth, normal_wet, low_depth, flood.depth_at(20 * side + 20), flood.wet_cells()])
	_check(flood.depth_at(20 * side + 20) > normal_depth * 1.5 and flood.wet_cells() > normal_wet, "at 5x the river rises and spreads (%.2f m, %d wet squares from %d)" % [flood.depth_at(20 * side + 20), flood.wet_cells(), normal_wet])

	# 7. Digging (owner, 2026-10-19): a ditch dug from a walled pond down the slope drains it.
	var land: PackedFloat32Array = PackedFloat32Array()
	land.resize(side * side)

	for j in range(side):
		for i in range(side):
			land[j * side + i] = 30.0 - float(i) * 0.5          # slopes down to the east

	for j in range(15, 26):
		for i in range(5, 16):
			land[j * side + i] = 24.0                          # a hollow (the pond floor)

	for j in range(14, 27):
		for i in range(4, 17):
			if j == 14 or j == 26 or i == 4 or i == 16:
				land[j * side + i] = 32.0                      # its walls

	var pond = WaterSim.new()
	pond.setup(side, 8.0, land)

	for j in range(15, 26):
		for i in range(5, 16):
			pond.add_water(i, j, 3.0)

	_run_s(pond, 600.0)
	var kept: float = pond.depth_at(20 * side + 10)
	_check(kept > 2.5, "a walled pond keeps its water (%.2f m)" % kept)
	# Dig through the east wall and on down the slope (2 m holes, 4 m apart).
	var origin: Vector2 = Vector2.ZERO

	for step_m in range(0, 80, 4):
		var x: float = 16.0 * 8.0 - 8.0 + float(step_m)
		pond.dig(Vector3(x, land[20 * side + int(x / 8.0)] - 0.5, 20.0 * 8.0), 2.5, origin)

	_run_s(pond, 3000.0)
	_check(pond.depth_at(20 * side + 10) < kept - 0.5, "a ditch dug from the pond drains it (%.2f m from %.2f m)" % [pond.depth_at(20 * side + 10), kept])

	# 10. The drawing levels kept up to date from changed squares match a full recount.
	var inc = WaterSim.new()
	var hill: PackedFloat32Array = _flat(31, 20.0)

	for j in range(31):
		for i in range(31):
			hill[j * 31 + i] = 20.0 - float(j) * 0.5

	inc.setup(31, 8.0, hill)
	inc.add_spring(15, 2, 5.0)
	inc.level_map()
	_run(inc, 120)
	var fast: PackedFloat32Array = inc.level_map()
	inc.reset_levels()
	var full: PackedFloat32Array = inc.level_map()
	var same: bool = true

	for k in range(fast.size()):
		if is_nan(fast[k]) != is_nan(full[k]) or (not is_nan(fast[k]) and absf(fast[k] - full[k]) > 0.0001):
			same = false

	_check(same, "kept-up-to-date drawing levels match a full recount")

	# 11. Owner report (2026-10-19, a dry band across the river): a shallow riffle between
	# drawn water is drawn; thin water at the end of a river is not.
	var riffle = WaterSim.new()
	riffle.setup(9, 8.0, _flat(9, 5.0))
	var start: PackedFloat32Array = _flat(9, 0.0)

	for i in range(1, 6):
		start[4 * 9 + i] = 0.3

	start[4 * 9 + 3] = 0.05
	start[4 * 9 + 6] = 0.05
	riffle.set_depth(start)
	var drawn: PackedFloat32Array = riffle.level_map()
	_check(not is_nan(drawn[4 * 9 + 3]), "a shallow riffle between river water is drawn")
	_check(is_nan(drawn[4 * 9 + 6]), "thin water past the end of the river is not drawn")
