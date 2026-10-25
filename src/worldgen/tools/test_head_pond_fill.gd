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
const KNOWN_FAILURES := {1394078: "a real cell Sonny fixes on his lake branch with a re-bake"}
const MAX_POND_DEPTH_M := 8.5    # deeper than that is a lake or the sea, not a head pond

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A still pond, not a steep river cell: most of the cells within 4 samples hold baked water at the same level.
func _is_flat_water(data, k: int, surface: float) -> bool:
	var side: int = data.samples
	var same: int = 0

	for dj in range(-4, 5):
		for di in range(-4, 5):
			var n: int = k + dj * side + di
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
		var wet: float = sim.depth_at(k)
		# A pond is a 2 to 8 m bowl fed by 0.1 to 2 m3/s: it cannot fill faster than its spring brings the water. A bowl fills deepest first, so the volume share
		# the spring can deliver is a floor for the depth share.
		var volume: float = float(spot[3])
		var deliverable: float = float(spot[2]) * SIM_SECONDS / maxf(volume, 1.0)
		var share: float = minf(FILL_SHARE, deliverable)
		var need: float = share * float(spot[1])

		if volume > LAKE_VOLUME_M3:
			need = LAKE_NEED_M      # a lake: the spring cannot fill it, it only has to stand a metre deep

		var line: String = "spring at sample %d (%.2f m3/s, pond %.0f m3): pond %.1f m deep, filled to %.1f m after %d s, needs %.1f m" % [k, spot[2], volume, spot[1], wet, int(SIM_SECONDS), need]

		if KNOWN_FAILURES.has(k) and wet < need:
			print("known failure, not counted (%s): %s" % [KNOWN_FAILURES[k], line])
			continue

		_check(wet >= need, line)

	print("head pond fill: %d failures" % failures)
	quit(1 if failures > 0 else 0)
