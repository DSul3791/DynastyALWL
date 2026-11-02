extends SceneTree

# Read-only report on the rivers, lakes and wetlands of one baked tile (nothing is written). Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/river_report.gd -- --tile=3,4
#
# Prints: totals; river depth by flow (does a bigger river get deeper and wider?); the starter river from source to
# mouth; river pieces that end on dry land (stranded); lakes; marsh share. See GENERATOR_NOTES.md.

const TileBakerScript := preload("res://src/worldgen/tile/tile_baker.gd")

const NONE := 0
const OCEAN := 1
const LAKE := 2
const RIVER := 3


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)
	var world_dir: String = "res://worlds/base_world"

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")

	quit(_run(world_dir, tile))


func _run(world_dir: String, tile: Vector2i) -> int:
	var baker = TileBakerScript.new()
	var problem: String = baker.setup(world_dir, 0.0)

	if problem != "":
		push_error(problem)
		return 1

	var result: Dictionary = baker.bake(tile)
	var water = result["water"]
	var climate = result["climate"]
	var side: int = int(water.samples)
	var spacing: float = float(water.spacing_m)
	var cls: PackedByteArray = water.water_class
	print("Tile %s: %d river cells, longest river %.0f m, %d lakes, %d pit cells filled, %d head ponds made (widest %.0f m)" % [
		str(tile), water.river_cells, water.longest_river_m, water.lakes.size(), water.filled_cells, water.ponds_made, water.largest_pond_m
	])

	_depth_by_flow(water, cls, side)
	_starter_river(water, side, spacing)
	_stranded(water, cls, side)
	_lakes(water)
	var land: float = 0.0

	for name in climate.biome_cells:
		if name != "ocean":
			land += float(climate.biome_cells[name])

	var marsh: float = float(climate.biome_cells.get("marsh", 0))
	print("Marsh: %.1f km2 of %.0f km2 land (%.1f%%); peat soil %.1f km2" % [
		marsh * 64.0 / 1.0e6, land * 64.0 / 1.0e6, 100.0 * marsh / maxf(land, 1.0), float(climate.soil_cells.get("peat", 0)) * 64.0 / 1.0e6
	])
	return 0


# River depth (water surface minus bed) in bins of flow, one bin per octave of flow.
func _depth_by_flow(water, cls: PackedByteArray, side: int) -> void:
	var bins: Dictionary = {}

	for k in range(cls.size()):
		if cls[k] != RIVER or is_nan(water.water_surface[k]):
			continue

		var flow: float = float(water.flow[k])

		if flow <= 0.0:
			continue

		var octave: int = int(floor(log(flow) / log(2.0)))

		if not bins.has(octave):
			bins[octave] = []

		bins[octave].append(float(water.water_surface[k]) - float(water.heights[k]))

	var keys: Array = bins.keys()
	keys.sort()
	print("River depth by flow (flow value doubles each row): cells, mean depth m, 90th percentile m, deepest m")

	for octave in keys:
		var depths: Array = bins[octave]
		depths.sort()
		var sum: float = 0.0

		for d in depths:
			sum += float(d)

		print("  flow %9.1f to %9.1f: %6d cells, mean %.2f, p90 %.2f, max %.2f" % [
			pow(2.0, float(octave)), pow(2.0, float(octave + 1)), depths.size(), sum / float(depths.size()),
			float(depths[int(float(depths.size() - 1) * 0.9)]), float(depths[depths.size() - 1])
		])


# The starter river from source to mouth, one line about every 160 m.
func _starter_river(water, side: int, spacing: float) -> void:
	var path: PackedVector2Array = water.starter_path
	print("Starter river path: %d points (%.0f m)" % [path.size(), float(path.size()) * spacing])

	if path.size() == 0:
		return

	print("  step  bed_m  surface_m  depth_m   flow   class")
	var every: int = maxi(path.size() / 14, 1)

	for n in range(0, path.size(), every):
		var p: Vector2 = path[n]
		var k: int = int(round(p.y)) * side + int(round(p.x))

		if k < 0 or k >= water.heights.size():
			continue

		var surface: float = float(water.water_surface[k]) if not is_nan(water.water_surface[k]) else NAN
		print("  %4d %6.1f %8.1f %7.2f %8.1f   %d" % [n, water.heights[k], surface, surface - water.heights[k], water.flow[k], water.water_class[k]])

	var last: Vector2 = path[path.size() - 1]
	var lk: int = int(round(last.y)) * side + int(round(last.x))

	if lk >= 0 and lk < water.heights.size():
		print("  the starter river ends at height %.1f m, class %d (1 ocean, 2 lake, 3 river, 0 dry)" % [water.heights[lk], water.water_class[lk]])


# River pieces (8-connected) that reach no ocean, lake or tile edge: rivers that end on dry land.
func _stranded(water, cls: PackedByteArray, side: int) -> void:
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(cls.size())
	var pieces: int = 0
	var stranded: int = 0
	var stranded_cells: int = 0
	var stranded_sizes: Array = []

	for start in range(cls.size()):
		if cls[start] != RIVER or seen[start] == 1:
			continue

		pieces += 1
		var stack: PackedInt32Array = PackedInt32Array([start])
		seen[start] = 1
		var size: int = 0
		var reaches: bool = false

		while not stack.is_empty():
			var k: int = stack[stack.size() - 1]
			stack.resize(stack.size() - 1)
			size += 1
			var col: int = k % side
			var row: int = k / side

			if col == 0 or row == 0 or col == side - 1 or row == side - 1:
				reaches = true

			for dr in [-1, 0, 1]:
				for dc in [-1, 0, 1]:
					if dr == 0 and dc == 0:
						continue

					var nc: int = col + dc
					var nr: int = row + dr

					if nc < 0 or nr < 0 or nc >= side or nr >= side:
						continue

					var n: int = nr * side + nc

					if cls[n] == OCEAN or cls[n] == LAKE:
						reaches = true
					elif cls[n] == RIVER and seen[n] == 0:
						seen[n] = 1
						stack.append(n)

		if not reaches:
			stranded += 1
			stranded_cells += size
			stranded_sizes.append(size)

	stranded_sizes.sort()
	print("River pieces: %d; %d end on dry land (%d cells; sizes %s)" % [pieces, stranded, stranded_cells, str(stranded_sizes.slice(maxi(stranded_sizes.size() - 8, 0)))])


func _lakes(water) -> void:
	var total: float = 0.0

	for lake in water.lakes:
		total += float(lake["area_m2"])

	var deep: int = 0

	for lake in water.lakes:
		if float(lake["depth_m"]) >= 1.0 and float(lake["area_m2"]) >= 5000.0:
			deep += 1

	print("Lakes: %d, %.1f ha in all; %d at least 0.5 ha and 1 m deep" % [water.lakes.size(), total / 10000.0, deep])
