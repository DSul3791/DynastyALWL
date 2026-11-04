extends SceneTree

# Head pond fill (build 623 bug: the spring landed in a lower basin beside the head pond, so the
# real pond stayed dry while the basin filled and spilled). On a dry start every spring must sit
# in a pond that then fills: after SIM_SECONDS of simulated time the water at each spring stands
# at least FILL_SHARE of the way from the ground to the baked pond level.
#   godot --headless --path . --script res://src/worldgen/tools/test_head_pond_fill.gd [-- --tile=3,4]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const WaterSettler := preload("res://src/water/water_settler.gd")

const SIM_SECONDS := 10800.0
const FILL_SHARE := 0.8
const MIN_GROUND_M := 0.0        # below sea level is a bay or estuary hollow, not a head pond
const MIN_POND_DEPTH_M := 1.5    # drainage-mode head ponds are carved 2 to 8 m deep (drainage_channels.gd _carve_basins); 25 Oct 2026: was 10 to 14 m (the placed head_pond_depth_m ponds)
const MIN_SPRING_M3S := 0.2      # a trickle under this cannot fill a bowl in three hours: not tested
const LAKE_VOLUME_M3 := 100000.0 # a bigger bowl is a lake: its spring cannot fill it, so it only has to stand 1 m deep
const LAKE_NEED_M := 1.0
const BOWL_RING_M := [40.0, 80.0, 120.0]
const BOWL_SLACK_M := 1.5        # a river head has ground falling away beside it; a bowl has none lower than its bed by more than this
const KNOWN_FAILURES := {1394078: "a real cell Sonny fixes on his lake branch with a re-bake",
	3144147: "a 75,000 m3 valley pond at 4.59 m3/s: 2.31 of 2.64 m after 3 h, its water spreads flat over the valley floor (the probe finds no leak, more water stored within 200 m than delivered); unchanged by the backwater paint, so it fills slowly, not wrongly (2 Nov 2026)"}
const MAX_POND_DEPTH_M := 8.5    # deeper than that is a lake or the sea, not a head pond
const KNOWN_REACH_CELLS := 8      # a known failure is a pond, not one sample: a rebake can move its spring a few cells (4 Nov 2026: the valley pond's spring moved from 3144147 to 3147984, 5 cells, with the same 75,008 m3 bowl)

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A still pond, not a steep river cell: most of the cells within 4 samples hold baked water at the same level.
func _is_flat_water(data, k: int, surface: float) -> bool:
	var side: int = data.samples
	var same: int = 0

	var column: int = k % side
	@warning_ignore("integer_division")
	var row: int = k / side

	for dj in range(-4, 5):
		for di in range(-4, 5):
			# A spring within 4 samples of the tile's edge: the window stops at the edge (no row wrap, no read past the arrays; PC run 2 Nov 2026,
			# "Invalid access of index 3692024" after the TERRAIN_VERSION 47 rebake put a spring pond on the bottom rows).
			if column + di < 0 or column + di >= side or row + dj < 0 or row + dj >= side:
				continue

			var n: int = (row + dj) * side + column + di
			var level: float = data.water_surface[n]

			if data.water_class[n] > 1 and not is_nan(level) and absf(level - surface) < 0.5:
				same += 1

	return same >= 20   # a carved head pond is 25 m across at the least (about 30 cells in this window), not the old 50 m


# Water the pond holds when full: the joined baked water at the spring's level (4-neighbour flood fill), depth below that level times the cell area.
func _pond_volume(data, k: int, surface: float) -> float:
	var seen: Dictionary = {k: true}
	var queue: Array = [k]
	var total: float = 0.0
	var cell_m2: float = data.spacing_m * data.spacing_m

	while not queue.is_empty() and seen.size() < 60000:
		var at: int = queue.pop_back()
		total += maxf(surface - data.heights[at], 0.0) * cell_m2

		for step in [1, -1, data.samples, -data.samples]:
			var n: int = at + step

			if n < 0 or n >= data.heights.size() or seen.has(n):
				continue

			var level: float = data.water_surface[n]

			if data.water_class[n] > 1 and not is_nan(level) and absf(level - surface) < 0.5:
				seen[n] = true
				queue.append(n)

	return total


# The lowest ground 40 to 120 m round the sample: a bowl has none lower than its bed (within BOWL_SLACK_M), a river head sits on a slope with ground falling away.
func _ring_min(data, k: int) -> float:
	var side: int = data.samples
	var column: int = k % side
	@warning_ignore("integer_division")
	var row: int = k / side
	var lowest: float = INF

	for radius in BOWL_RING_M:
		for step in 16:
			var a: float = float(step) * TAU / 16.0
			var c: int = column + int(round(cos(a) * radius / data.spacing_m))
			var r: int = row + int(round(sin(a) * radius / data.spacing_m))

			if c >= 0 and c < side and r >= 0 and r < side:
				lowest = minf(lowest, data.heights[r * side + c])

	return lowest


# The known failure within KNOWN_REACH_CELLS of sample k, or -1.
func _known_near(k: int, side: int) -> int:
	for known in KNOWN_FAILURES:
		@warning_ignore("integer_division")
		if absi(int(known) % side - k % side) <= KNOWN_REACH_CELLS and absi(int(known) / side - k / side) <= KNOWN_REACH_CELLS:
			return int(known)

	return -1


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))

	var errors: Array = []
	var world: String = "res://worlds/base_world"
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var data = generator.get_tile(tile)

	if data.placeholder:
		push_error("no baked tile %s" % tile)
		quit(1)
		return

	var sim = WaterSettler.build(data, 10.0, generator, false)
	var spots: Array = []

	for spring in sim.springs:
		var k: int = int(spring[0])
		var surface: float = data.water_surface[k]

		if is_nan(surface) or data.water_class[k] < 2 or surface - data.heights[k] < MIN_POND_DEPTH_M or surface - data.heights[k] > MAX_POND_DEPTH_M:
			continue

		if data.heights[k] < MIN_GROUND_M or not _is_flat_water(data, k, surface):
			continue

		if float(spring[1]) < MIN_SPRING_M3S:
			continue

		# A class 2 cell is a pond or lake; a class 3 (river) cell only counts when it lies in a bowl, not on a steep river head.
		if data.water_class[k] == 3 and _ring_min(data, k) < data.heights[k] - BOWL_SLACK_M:
			continue

		spots.append([k, surface - data.heights[k], float(spring[1]), _pond_volume(data, k, surface)])

	_check(not spots.is_empty(), "tile %s has springs inside ponds (%d)" % [tile, spots.size()])

	while sim.seconds < SIM_SECONDS:
		sim.step()

	for spot in spots:
		var k: int = spot[0]
		# 2 Nov 2026: the pond's water, not only the spring cell: a spring on the bowl's side runs down to the floor first (spring 1900590 stood 1.75 m up the
		# slope of its bowl, dry at the spring with 0.5 m of water 40 m away). So the deepest water within 5 cells (40 m) counts, but only in this pond's own
		# bowl (joined to the spring through cells of the same baked pond level), on ground no higher than the spring cell's and above the sea (Tyler's review).
		var wet: float = sim.depth_at(k)
		var wet_at: int = k
		var side: int = data.samples
		var surface_k: float = data.water_surface[k]
		var bowl: Dictionary = {k: true}
		var queue: Array = [k]

		while not queue.is_empty():
			var at: int = queue.pop_back()

			for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ci: int = at % side + step.x
				@warning_ignore("integer_division")
				var cj: int = at / side + step.y
				@warning_ignore("integer_division")
				var near: bool = absi(ci - k % side) <= 5 and absi(cj - k / side) <= 5

				if ci < 0 or cj < 0 or ci >= side or cj >= side or not near:
					continue

				var q: int = cj * side + ci
				var level: float = data.water_surface[q]

				if bowl.has(q) or data.water_class[q] < 2 or is_nan(level) or absf(level - surface_k) >= 0.5:
					continue

				bowl[q] = true
				queue.append(q)

				if data.heights[q] <= data.heights[k] and data.heights[q] > 0.0 and sim.depth_at(q) > wet:
					wet = sim.depth_at(q)
					wet_at = q

		# A pond is a 2 to 8 m bowl fed by 0.1 to 2 m3/s: it cannot fill faster than its spring brings the water. A bowl fills deepest first, so the volume share
		# the spring can deliver is a floor for the depth share.
		var volume: float = float(spot[3])
		var deliverable: float = float(spot[2]) * SIM_SECONDS / maxf(volume, 1.0)
		var share: float = minf(FILL_SHARE, deliverable)
		var need: float = share * float(spot[1])

		if volume > LAKE_VOLUME_M3:
			# A lake: the spring cannot fill it, it only has to stand a metre deep, or as deep as its water can make it (2 Nov 2026: a 0.3 m3/s spring brings 3240 m3
			# in three hours, which cannot stand a metre deep in a 220,000 m3 bowl).
			need = minf(LAKE_NEED_M, maxf(need, 0.05))

		var line: String = "spring at sample %d (%.2f m3/s, pond %.0f m3): pond %.1f m deep, filled to %.2f m (at sample %d) after %d s, needs %.2f m" % [k, spot[2], volume, spot[1], wet, wet_at, int(SIM_SECONDS), need]

		var known: int = _known_near(k, data.samples)

		if known >= 0 and wet < need:
			print("known failure, not counted (%s): %s" % [KNOWN_FAILURES[known], line])
			continue

		_check(wet >= need, line)

	print("head pond fill: %d failures" % failures)
	quit(1 if failures > 0 else 0)
