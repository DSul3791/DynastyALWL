extends SceneTree

# Option B stages 2-3: runoff gathers into rivers (mass balance, agreement with today's rivers), then channels get a natural shape.
#   godot --headless --path . --script res://src/worldgen/tools/test_drainage_flow.gd [-- --tile=3,4]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const DrainageFillScript := preload("res://src/worldgen/tile/drainage_fill.gd")
const DrainageChannelsScript := preload("res://src/worldgen/tile/drainage_channels.gd")
const DrainageFlowScript := preload("res://src/worldgen/tile/drainage_flow.gd")

const STEP := 1                # 8 m cells (channels are 24 m wide and up)
const RIVER_CELLS_KM2 := 0.5   # river_start_km2 of today's world network
const NEAR_CELLS := 8          # 64 m
const KNOWN_DRY_RISES := 30    # known: dry-channel rises (class 0 to 0, a small real bed gap), owner Sonny river pass; about 25 measured, 30 leaves room. The test fails on growth.
const NOTCH_CELLS := 6         # the outlet notch behind a kept pit's rim
const LAKE_NEAR_CELLS := 3     # a rise within 3 cells of a baked lake cell (water_class 2) is the lake outlet, not a river

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# True when the cell or its receiver has a baked lake cell (water_class 2) within LAKE_NEAR_CELLS, or a carved bowl cell among its 8 neighbours.
func _lake_or_bowl_side(data, channels, index: int, next: int, side: int) -> bool:
	for cell in [index, next]:
		@warning_ignore("integer_division")
		var cell_row: int = cell / side
		var cell_column: int = cell % side

		for dz in range(-LAKE_NEAR_CELLS, LAKE_NEAR_CELLS + 1):
			for dx in range(-LAKE_NEAR_CELLS, LAKE_NEAR_CELLS + 1):
				var lake_column: int = cell_column + dx
				var lake_row: int = cell_row + dz

				if lake_column >= 0 and lake_column < side and lake_row >= 0 and lake_row < side and data.water_class[lake_row * STEP * data.samples + lake_column * STEP] == 2:
					return true

		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var column: int = cell_column + dx
				var row: int = cell_row + dz

				if column >= 0 and column < side and row >= 0 and row < side and channels.basin_mask[row * side + column] != 0:
					return true

	return false


# A kept pit: the bed climbs to its rim and the outlet notch falls away behind it. A rise is no fault when within the next NOTCH_CELLS cells downstream the bed
# falls by at least the rise (Sonny, 25 Oct); a rise with no drop after it still fails.
func _crest_with_notch(channels, fill, index: int, next: int) -> bool:
	var rise: float = channels.bed[next] - channels.bed[index]
	var at: int = next

	for step in NOTCH_CELLS:
		at = fill.receiver[at]

		if at < 0:
			return false

		if channels.bed[next] - channels.bed[at] >= rise:
			return true

	return false


# True when a baked lake cell (water_class 2) lies within `cells` cells of the cell.
func _lake_within(data, index: int, side: int, cells: int) -> bool:
	@warning_ignore("integer_division")
	var cell_row: int = index / side
	var cell_column: int = index % side

	for dz in range(-cells, cells + 1):
		for dx in range(-cells, cells + 1):
			var column: int = cell_column + dx
			var row: int = cell_row + dz

			if column >= 0 and column < side and row >= 0 and row < side and data.water_class[row * STEP * data.samples + column * STEP] == 2:
				return true

	return false


func _channels(h: PackedFloat32Array, fill, flow, side: int, cell_m: float, data) -> void:
	var rules: Dictionary = {"width_m_per_sqrt_q": 6.0, "min_width_m": 24.0, "depth_m_per_sqrt_q": 1.0, "min_depth_m": 1.5, "max_depth_m": 8.0}
	var begun: int = Time.get_ticks_msec()
	var channels = DrainageChannelsScript.new()
	channels.build(h, fill, flow, side, cell_m, RIVER_CELLS_KM2, rules, 17)
	var took: float = float(Time.get_ticks_msec() - begun) / 1000.0
	var rising: int = 0
	var rises: Array = []
	var centres: int = 0
	var outer_sum: float = 0.0
	var inner_sum: float = 0.0
	var apexes: int = 0

	for index in range(side * side):
		if flow.discharge[index] < RIVER_CELLS_KM2:
			continue

		centres += 1
		var next: int = fill.receiver[index]

		# A carved pond or lake bowl dips below its outlet on purpose (the lip is the outlet), so its cells are not rises.
		# Build 810 tiles: lake cells (baked water_class 2) and the cells beside a carved bowl rise or dip on purpose too.
		if next >= 0 and flow.discharge[next] >= RIVER_CELLS_KM2 and channels.bed[next] > channels.bed[index] + 0.001 and channels.basin_mask[index] == 0 and channels.basin_mask[next] == 0 \
				and not _lake_or_bowl_side(data, channels, index, next, side) and not _crest_with_notch(channels, fill, index, next):
			rising += 1

			if rises.size() < 80:
				@warning_ignore("integer_division")
				var at_row: int = index / side
				@warning_ignore("integer_division")
				var next_row: int = next / side
				rises.append("x %.0f z %.0f rise %.2f m, class %d -> %d, discharge %.1f km2, basin %d -> %d, lake within 8 cells %s" % [data.x0 + float(index % side) * cell_m, data.z0 + float(at_row) * cell_m,
					channels.bed[next] - channels.bed[index], data.water_class[at_row * STEP * data.samples + (index % side) * STEP], data.water_class[next_row * STEP * data.samples + (next % side) * STEP],
					flow.discharge[index], channels.basin_mask[index], channels.basin_mask[next], str(_lake_within(data, index, side, 8))])

		var turn: float = channels.curvature[index]

		if absf(turn) > 0.3 and flow.discharge[index] > 2.0 and next >= 0:
			var hx: int = next % side - index % side
			@warning_ignore("integer_division")
			var hz: int = next / side - index / side
			var right: int = index + (-hz) + hx * side
			var left: int = index + hz - hx * side
			var outer: int = left if turn > 0.0 else right
			var inner: int = right if turn > 0.0 else left

			if outer >= 0 and outer < side * side and inner >= 0 and inner < side * side:
				outer_sum += h[outer] - channels.bed[outer]
				inner_sum += h[inner] - channels.bed[inner]
				apexes += 1

	print("channel cells %d, bends %d, outer/inner depth ratio %.2f, %.1f s" % [centres, apexes, outer_sum / maxf(inner_sum, 0.001), took])
	if rising > 0:
		print("rises (first %d): " % rises.size())

		for line in rises:
			print("  ", line)

	print("known: dry-channel rises ~25, owner Sonny river pass (allowed up to %d); found %d" % [KNOWN_DRY_RISES, rising])
	_check(rising <= KNOWN_DRY_RISES, "bed rises downstream no more than the known dry-channel gaps (%d rises of %d cells, known up to %d)" % [rising, centres, KNOWN_DRY_RISES])
	_check(apexes >= 20, "at least 20 bends (%d)" % apexes)
	_check(outer_sum >= 1.3 * inner_sum, "outer bank at least 1.3x the inner bank depth")


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
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var data = generator.get_tile(tile)

	if data.placeholder:
		print("no baked tile, skipping")
		quit(0)
		return

	@warning_ignore("integer_division")
	var side: int = (data.samples - 1) / STEP + 1
	var cell_m: float = data.spacing_m * float(STEP)
	var h: PackedFloat32Array = PackedFloat32Array()
	h.resize(side * side)
	var sea: PackedByteArray = PackedByteArray()
	sea.resize(side * side)
	var runoff: PackedFloat32Array = PackedFloat32Array()
	runoff.resize(side * side)

	for row in range(side):
		for column in range(side):
			var k: int = row * STEP * data.samples + column * STEP
			var index: int = row * side + column
			h[index] = data.heights[k]
			sea[index] = 1 if data.heights[k] < 0.0 else 0
			runoff[index] = cell_m * cell_m * 1.0e-6   # one unit per km2 of land: discharge reads as catchment km2

	var begun: int = Time.get_ticks_msec()
	var fill = DrainageFillScript.new()
	fill.build(h, sea, side, 2.0)
	var flow = DrainageFlowScript.new()
	flow.build(fill, runoff)
	var took: float = float(Time.get_ticks_msec() - begun) / 1000.0
	var land_total: float = 0.0
	var leaving: float = 0.0

	for index in range(side * side):
		if sea[index] == 0:
			land_total += runoff[index]

			# Water leaves the tile at the sea or at the tile edge.
			var next: int = fill.receiver[index]

			if next < 0 or sea[next] == 1:
				leaving += flow.discharge[index]

	_check(absf(leaving - land_total) < 0.001 * land_total, "mass balance: %.2f km2 of land, %.2f leaves" % [land_total, leaving])
	var mask: PackedByteArray = flow.channel_cells(RIVER_CELLS_KM2)
	var rivers: int = 0
	var agree: int = 0

	for index in range(side * side):
		@warning_ignore("integer_division")
		var today_row: int = index / side

		if data.water_class[today_row * STEP * data.samples + (index % side) * STEP] != 3:
			continue

		rivers += 1
		var row: int = today_row
		var column: int = index % side
		var hit: bool = false

		for dz in range(-NEAR_CELLS, NEAR_CELLS + 1):
			for dc in range(-NEAR_CELLS, NEAR_CELLS + 1):
				var nr: int = row + dz
				var nc: int = column + dc

				if nr >= 0 and nr < side and nc >= 0 and nc < side and mask[nr * side + nc] == 1:
					hit = true

		if hit:
			agree += 1

	print("today's river cells %d, within 64 m of a drainage channel: %d (%.0f%%), %.1f s" % [rivers, agree, 100.0 * float(agree) / maxf(float(rivers), 1.0), took])
	_check(took < 30.0, "fill and flow under 30 s per tile (%.1f s)" % took)
	_channels(h, fill, flow, side, cell_m, data)
	print("drainage flow: %d failures" % failures)
	quit(1 if failures > 0 else 0)
