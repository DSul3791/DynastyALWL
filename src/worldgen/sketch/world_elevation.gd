class_name WorldElevation
extends RefCounted

# Builds one coarse elevation map for the whole wrapping world from the
# world sketch: the sea floor, the central trench, continental shelves,
# the mid-ocean ridge, every volcano, seamount and atoll, and the center
# island with its crater. Islands are wherever the map rises above sea
# level. Each tile later adds fine detail on top of this map.
#
# Noise fields are made seamless, so the map joins up across the wrap
# seam in both directions. Heights are meters relative to sea level.

const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")
const SketchScript := preload("res://src/worldgen/sketch/world_sketch.gd")

const OWNER_NONE := -1
const SPECIAL_NONE := 0
const SPECIAL_LAVA := 1
const SPECIAL_SWAMP := 2
const SPECIAL_SALT := 3
const SPECIAL_SCORCHED := 4
const SPECIAL_RUINS := 5
const SPECIAL_ROAD := 6

var settings
var rules: Dictionary = {}
var cell_m: float = 160.0
var size_x: int = 0
var size_z: int = 0
var origin_x: float = 0.0
var origin_z: float = 0.0

var heights: PackedFloat32Array = PackedFloat32Array()
var owners: PackedInt32Array = PackedInt32Array()     # feature index per cell
var special: PackedByteArray = PackedByteArray()      # lava and the like
var feature_ids: Array = []

var _province: PackedByteArray
var _detail: PackedByteArray
var _hills: PackedByteArray
var _ridged: PackedByteArray
var _warp_x: PackedByteArray
var _warp_z: PackedByteArray
var _fine_x: PackedByteArray
var _fine_z: PackedByteArray
var _master: int = 0
var _starters: Array = []   # starter mounts (ellipses), so shelf hills away from them can be given more relief


# cell_override lets tests build a coarser map quickly.
func build(world_settings, sketch_rules: Dictionary, sketch: Dictionary, cell_override: float = 0.0) -> void:
	settings = world_settings
	rules = sketch_rules
	_master = settings.master_seed
	cell_m = cell_override if cell_override > 0.0 else float(rules.get("cell_m", 160))
	var tile: float = float(settings.tile_size_m)
	size_x = int(round(float(settings.tiles_x) * tile / cell_m))
	size_z = int(round(float(settings.tiles_z) * tile / cell_m))
	origin_x = float(settings.min_tile) * tile
	origin_z = float(settings.min_tile) * tile

	_starters.clear()

	for feature in sketch.get("features", []):
		for mount in feature.get("mounts", []):
			if str(mount["type"]) == "starter":
				_starters.append(mount)

	_make_noise_fields()
	_build_sea_floor()
	_carve_trenches()

	feature_ids.clear()

	for feature in sketch.get("features", []):
		feature_ids.append(str(feature["id"]))

	var index: int = 0

	for feature in sketch.get("features", []):
		if str(feature["kind"]) == "continental_shelf":
			_raise_shelf(feature["shelf"], feature["shelf"], index)

			for lobe in feature.get("lobes", []):
				_raise_shelf(lobe, feature["shelf"], index)

		if str(feature["kind"]) == "mid_ocean_ridge":
			_raise_ridge(feature, index)

		index += 1

	index = 0

	for feature in sketch.get("features", []):
		for mount in feature.get("mounts", []):
			_raise_mount(mount, index)

		index += 1

	for feature in sketch.get("features", []):
		for mount in feature.get("mounts", []):
			if str(mount["type"]) == "starter" and mount.has("beach_dir"):
				_carve_bay(mount)

	for feature in sketch.get("features", []):
		for mount in feature.get("mounts", []):
			if str(mount["type"]) == "starter" and mount.has("beach_cap_m"):
				_shape_coast_profile(mount)
				_raise_foothills(mount)

	_shape_shelf_coasts(sketch)
	_raise_landmark_islands()

	# Craters last: the shelf and coast caps above would otherwise level the rim again.
	for feature in sketch.get("features", []):
		for mount in feature.get("mounts", []):
			var crater: Dictionary = _island_config(mount).get("crater", {})

			if str(mount["type"]) == "starter" and mount.has("beach_cap_m") and not crater.is_empty():
				_crater_at_summit(mount, crater, int(ceil(maxf(float(mount["a"]), float(mount["b"])) * 1.6 / cell_m)))
	_clamp_heights()


# ==================================================
# INDEXING AND NOISE
# ==================================================

func index_of(column: int, row: int) -> int:
	return posmod(row, size_z) * size_x + posmod(column, size_x)


func height_at_m(x_m: float, z_m: float) -> float:
	var column: int = int(floor((x_m - origin_x) / cell_m))
	var row: int = int(floor((z_m - origin_z) / cell_m))
	return heights[index_of(column, row)]


func cell_center_m(column: int, row: int) -> Vector2:
	return Vector2(
		origin_x + (float(column) + 0.5) * cell_m,
		origin_z + (float(row) + 0.5) * cell_m
	)


static func _value(field: PackedByteArray, index: int) -> float:
	return float(field[index]) / 127.5 - 1.0


# A seamless noise field covering the whole world, one byte per cell.
func _field(purpose: String, wavelength_m: float, octaves: int, noise_type: int, fractal: int) -> PackedByteArray:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = SeedUtil.purpose_seed(_master, purpose)
	noise.noise_type = noise_type
	noise.frequency = cell_m / wavelength_m
	noise.fractal_type = fractal
	noise.fractal_octaves = octaves
	var image: Image = noise.get_seamless_image(size_x, size_z, false, false, 0.12, true)

	if image.get_format() != Image.FORMAT_L8:
		image.convert(Image.FORMAT_L8)

	return image.get_data()


func _make_noise_fields() -> void:
	var simplex: int = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var fbm: int = FastNoiseLite.FRACTAL_FBM
	_province = _field("elev_province", 60000.0, 3, simplex, fbm)
	_detail = _field("elev_detail", 6000.0, 4, simplex, fbm)
	_hills = _field("elev_hills", 14000.0, 4, simplex, fbm)
	_ridged = _field("elev_ridged", 4000.0, 3, simplex, FastNoiseLite.FRACTAL_RIDGED)
	_warp_x = _field("elev_warp_x", 16000.0, 2, simplex, fbm)
	_warp_z = _field("elev_warp_z", 16000.0, 2, simplex, fbm)
	_fine_x = _field("elev_fine_x", 3500.0, 2, simplex, fbm)
	_fine_z = _field("elev_fine_z", 3500.0, 2, simplex, fbm)


# ==================================================
# SEA FLOOR AND TRENCH
# ==================================================

func _build_sea_floor() -> void:
	var floor_rules: Dictionary = rules["sea_floor"]
	var base: float = float(floor_rules["base_depth_m"])
	var variation: float = float(floor_rules["variation_m"])
	var detail: float = float(floor_rules["detail_m"])
	var count: int = size_x * size_z
	heights.resize(count)
	owners.resize(count)
	special.resize(count)
	owners.fill(OWNER_NONE)
	special.fill(SPECIAL_NONE)

	for index in range(count):
		heights[index] = (
			base
			+ variation * _value(_province, index)
			+ detail * _value(_detail, index)
		)


func _carve_trenches() -> void:
	for feature in settings.world_features:
		if str(feature.get("kind", "")) != "abyssal_trench":
			continue

		var floor_m: float = float(feature["floor_m"])
		var half_width: float = float(feature["half_width_tiles"])
		var falloff: float = float(feature["edge_falloff_tiles"])
		var reach_tiles: float = float(feature["half_length_tiles"]) + falloff + 0.5
		var center: Vector2 = _feature_center_m(feature)
		var radius_cells: int = int(ceil(reach_tiles * float(settings.tile_size_m) / cell_m))
		var center_column: int = int(floor((center.x - origin_x) / cell_m))
		var center_row: int = int(floor((center.y - origin_z) / cell_m))

		for row_offset in range(-radius_cells, radius_cells + 1):
			for column_offset in range(-radius_cells, radius_cells + 1):
				var column: int = center_column + column_offset
				var row: int = center_row + row_offset
				var position: Vector2 = cell_center_m(column, row)
				var tiles: Vector2 = settings.tiles_from_center(position.x, position.y)
				var reach: float = settings.feature_reach(feature, tiles)
				var index: int = index_of(column, row)
				var detail: float = _value(_detail, index)

				if reach <= 1.0:
					heights[index] = minf(heights[index], floor_m + 120.0 * detail + 200.0 * reach * reach)
					continue

				var outside: float = (reach - 1.0) * half_width / falloff

				if outside >= 1.0:
					continue

				var t: float = _smooth(outside)
				var carved: float = lerpf(floor_m + 200.0, heights[index], t)
				heights[index] = minf(heights[index], carved)


# ==================================================
# SHELVES AND RIDGES
# ==================================================

# outline: center, size and rotation of the shelf or one of its lobes.
# shelf: the shelf's depth and hill settings, shared by its lobes.
func _raise_shelf(outline: Dictionary, shelf: Dictionary, owner_index: int) -> void:
	var center: Vector2 = Vector2(float(outline["center_m"][0]), float(outline["center_m"][1]))
	var half_length: float = float(outline["half_length_m"])
	var half_width: float = float(outline["half_width_m"])
	var rotation: float = deg_to_rad(float(outline["rotation_deg"]))
	var depth: float = float(shelf["depth_m"])
	var edge: float = float(shelf["edge_width"])
	var amplitude: float = float(shelf["hill_amplitude_m"])
	var threshold: float = float(shelf["hill_threshold"])
	var warp: float = half_width * 0.5
	var reach: float = half_length * (1.0 + edge) + warp
	var radius_cells: int = int(ceil(reach / cell_m))
	var center_column: int = int(floor((center.x - origin_x) / cell_m))
	var center_row: int = int(floor((center.y - origin_z) / cell_m))
	var cos_r: float = cos(rotation)
	var sin_r: float = sin(rotation)

	for row_offset in range(-radius_cells, radius_cells + 1):
		for column_offset in range(-radius_cells, radius_cells + 1):
			var index: int = index_of(center_column + column_offset, center_row + row_offset)
			var dx: float = float(column_offset) * cell_m + warp * _value(_warp_x, index)
			var dz: float = float(row_offset) * cell_m + warp * _value(_warp_z, index)
			var along: float = (dx * cos_r + dz * sin_r) / half_length
			var across: float = (-dx * sin_r + dz * cos_r) / half_width
			var distance: float = sqrt(along * along + across * across)

			if distance >= 1.0 + edge:
				continue

			var mask: float = 1.0 - _smooth((distance - (1.0 - edge)) / (2.0 * edge))
			var hills: float = _value(_hills, index)
			var relief: float = amplitude * (hills - threshold)

			# Shelf hills away from the starter islands rise higher (`shelf_hill_gain`), so those islands are mountain
			# or moor islands too and not 400 m lumps.
			if relief > 0.0:
				relief *= lerpf(1.0, float(rules.get("shelves", {}).get("shelf_hill_gain", 1.0)), _away_from_starters(index_of(center_column + column_offset, center_row + row_offset), center_column + column_offset, center_row + row_offset))

			var shelf_height: float = depth + relief

			# Hills fade toward the shelf edge so islands stay on the shelf.
			shelf_height = lerpf(depth, shelf_height, _smooth(clampf((1.0 - distance) / 0.35, 0.0, 1.0)))
			shelf_height += 30.0 * _value(_detail, index)
			var blended: float = lerpf(heights[index], shelf_height, mask)

			if blended > 0.0 and mask > 0.5:
				owners[index] = owner_index

			heights[index] = blended


# Shelf islands (the hills on a continental shelf, away from the starter islands) get the same concave coast profile as the
# starters: gentle at the shore, the flat share of the land near the sea, steeper inland, so they have beaches and farmland
# before the mountains (`shelf_hill_gain` raised their relief).
func _shape_shelf_coasts(sketch: Dictionary) -> void:
	var exponent: float = float(rules.get("shelves", {}).get("shelf_coast_exponent", 1.55))
	var scale_m: float = float(rules.get("shelves", {}).get("shelf_coast_scale_m", 340.0))

	if scale_m <= 0.0:
		return

	for feature in sketch.get("features", []):
		if str(feature["kind"]) != "continental_shelf":
			continue

		var outline: Dictionary = feature["shelf"]
		var reach_m: float = float(outline["half_length_m"]) * (1.0 + float(outline["edge_width"])) + float(outline["half_width_m"]) * 0.5
		var radius: int = int(ceil(reach_m / cell_m))
		var size: int = radius * 2 + 1
		var center_column: int = int(floor((float(outline["center_m"][0]) - origin_x) / cell_m))
		var center_row: int = int(floor((float(outline["center_m"][1]) - origin_z) / cell_m))
		var sea: PackedFloat32Array = _sea_distance(center_column, center_row, radius)

		for row in range(size):
			for column in range(size):
				var d_m: float = sea[row * size + column] * cell_m

				if d_m <= 0.0:
					continue

				var cc: int = center_column - radius + column
				var cr: int = center_row - radius + row
				var weight: float = _away_from_starters(0, cc, cr)

				if weight <= 0.0:
					continue

				var index: int = index_of(cc, cr)
				var cap: float = 6.0 + scale_m * pow(d_m / 3500.0, exponent) * (1.0 + 0.2 * _value(_ridged, index))
				var row_abs: float = absf(cell_center_m(cc, cr).y) / float(settings.tile_size_m)
				var shore: Dictionary = rules.get("shelves", {}).get("climate_shores", {})

				if not shore.is_empty():
					# Hot latitudes: a long gentle sand apron. Polar latitudes: a steep rocky shore that climbs straight from the sea.
					var sand: float = 1.0 - _smooth(clampf((row_abs - float(shore.get("hot_row", 2.0))) / 1.0, 0.0, 1.0))
					var rock: float = _smooth(clampf((row_abs - float(shore.get("polar_row", 7.0))) / 1.0, 0.0, 1.0))
					var apron: float = _smooth(clampf(d_m / float(shore.get("sand_width_m", 1500.0)), 0.0, 1.0))
					cap *= lerpf(1.0, lerpf(float(shore.get("sand_cap_scale", 0.35)), 1.0, apron), sand)
					var cliff: float = rock * float(shore.get("cliff_m", 70.0)) * _smooth(clampf(d_m / float(shore.get("cliff_run_m", 150.0)), 0.0, 1.0))
					cap += cliff
					heights[index] = lerpf(heights[index], maxf(heights[index], cliff) if rock > 0.0 else heights[index], weight * rock)

				heights[index] = lerpf(heights[index], minf(heights[index], cap), weight)


# 0 inside a starter island's reach (its own shape rules apply there), 1 well away from all of them.
func _away_from_starters(_index: int, column: int, row: int) -> float:
	var away: float = 1.0
	var x: float = origin_x + (float(column) + 0.5) * cell_m
	var z: float = origin_z + (float(row) + 0.5) * cell_m

	for mount in _starters:
		var rotation: float = deg_to_rad(float(mount["rot"]))
		var dx: float = x - float(mount["x"])
		var dz: float = z - float(mount["z"])
		var along: float = (dx * cos(rotation) + dz * sin(rotation)) / float(mount["a"])
		var across: float = (-dx * sin(rotation) + dz * cos(rotation)) / float(mount["b"])
		away = minf(away, _smooth(clampf((sqrt(along * along + across * across) - 2.2) / 0.8, 0.0, 1.0)))

	return away


# The ridge crest follows a path x(z), so each row only needs the cells
# near the crest.
func _raise_ridge(feature: Dictionary, owner_index: int) -> void:
	var path: Dictionary = feature["path"]
	var crest: float = float(feature["crest_m"])
	var width: float = float(feature["width_m"])
	var reach_cells: int = int(ceil(width * 2.0 / cell_m))
	var tile: float = float(settings.tile_size_m)

	for row in range(size_z):
		var row_center: Vector2 = cell_center_m(0, row)
		var z_tiles: float = settings.tiles_from_center(row_center.x, row_center.y).y
		var x_tiles: float = SketchScript.ridge_x_tiles(path, z_tiles)
		var x_m: float = (x_tiles + 0.5) * tile
		var center_column: int = int(floor((x_m - origin_x) / cell_m))
		var center_offset: float = x_m - (origin_x + (float(center_column) + 0.5) * cell_m)

		for column_offset in range(-reach_cells, reach_cells + 1):
			var distance: float = absf(float(column_offset) * cell_m - center_offset)
			var index: int = index_of(center_column + column_offset, row)
			var noise_height: float = 380.0 * _value(_ridged, index) + 160.0 * _value(_detail, index)
			var raised: float = -4000.0 + (crest + noise_height + 4000.0) * exp(-pow(distance / width, 2.0))

			if raised > heights[index]:
				heights[index] = _smooth_max(heights[index], raised, 120.0)


# ==================================================
# VOLCANOES, SEAMOUNTS, ATOLLS AND ISLANDS
# ==================================================

func _raise_mount(mount: Dictionary, owner_index: int) -> void:
	var mount_type: String = str(mount["type"])
	var a: float = float(mount["a"])
	var b: float = float(mount["b"])
	var shore: float = float(mount.get("shore", 600))
	var slope: float = 5000.0

	if mount_type == "seamount":
		shore = 0.0
		slope = 0.0
	elif mount_type == "atoll":
		shore = 0.0
		slope = 2600.0

	var warp: float = minf(b * 0.45, 2200.0)
	var fine: float = minf(b * 0.12, 450.0)

	# Starter islands get rougher coasts so they do not read as ovals.
	if mount_type == "starter":
		warp = b * 0.7
		fine = b * 0.25
	var reach: float = a + shore + slope + warp + fine

	if mount_type == "seamount":
		reach = a + warp

	var radius_cells: int = int(ceil(reach / cell_m)) + 1
	var center_column: int = int(floor((float(mount["x"]) - origin_x) / cell_m))
	var center_row: int = int(floor((float(mount["z"]) - origin_z) / cell_m))
	var offset_x: float = float(mount["x"]) - (origin_x + (float(center_column) + 0.5) * cell_m)
	var offset_z: float = float(mount["z"]) - (origin_z + (float(center_row) + 0.5) * cell_m)
	var rotation: float = deg_to_rad(float(mount["rot"]))
	var cos_r: float = cos(rotation)
	var sin_r: float = sin(rotation)
	var beach_direction: Vector2 = Vector2.ZERO

	if mount.has("beach_dir"):
		beach_direction = Vector2(float(mount["beach_dir"][0]), float(mount["beach_dir"][1]))

	for row_offset in range(-radius_cells, radius_cells + 1):
		for column_offset in range(-radius_cells, radius_cells + 1):
			var index: int = index_of(center_column + column_offset, center_row + row_offset)
			var facing: float = 0.0

			if beach_direction != Vector2.ZERO:
				var plain_offset: Vector2 = Vector2(
					float(column_offset) * cell_m - offset_x, float(row_offset) * cell_m - offset_z
				)

				if plain_offset.length() > 1.0:
					facing = plain_offset.normalized().dot(beach_direction)

			var dx: float = (
				float(column_offset) * cell_m - offset_x
				+ warp * _value(_warp_x, index) + fine * _value(_fine_x, index)
			)
			var dz: float = (
				float(row_offset) * cell_m - offset_z
				+ warp * _value(_warp_z, index) + fine * _value(_fine_z, index)
			)
			var along: float = (dx * cos_r + dz * sin_r) / a
			var across: float = (-dx * sin_r + dz * cos_r) / b
			var distance: float = sqrt(along * along + across * across)
			var raised: float = -INF

			match mount_type:
				"seamount":
					raised = _seamount_height(mount, distance)
				"atoll":
					raised = _atoll_height(mount, distance, b, index)
				_:
					raised = _island_height(mount, distance, b, shore, slope, index, facing)

			# A strait around a starter island keeps nearby shelf hills
			# from joining it; they stay as satellite islands across the water.
			if mount_type == "starter" and distance > 1.0:
				var strait: float = float(mount.get("strait_m", 0))

				if strait > 0.0:
					var outside: float = (distance - 1.0) * b
					var hold: float = 1.0 - _smooth(clampf((outside - strait) / strait, 0.0, 1.0))
					var capped: float = minf(heights[index], float(mount.get("strait_depth_m", -30)))
					heights[index] = lerpf(heights[index], capped, hold)

			if raised <= heights[index] - 150.0:
				continue

			var combined: float = _smooth_max(heights[index], raised, 120.0)

			if raised > heights[index] and raised > 0.0:
				owners[index] = owner_index

			heights[index] = combined


# Land near a starter island may not climb faster than a concave profile of its
# distance from the sea: gentle at the shore, steeper inland, as on real
# volcanic islands. Without it the shelf hills stand behind a flat plain as a wall.
func _shape_coast_profile(mount: Dictionary) -> void:
	var reach_m: float = maxf(float(mount["a"]), float(mount["b"])) * 1.6
	var radius: int = int(ceil(reach_m / cell_m))
	var size: int = radius * 2 + 1
	var center_column: int = int(floor((float(mount["x"]) - origin_x) / cell_m))
	var center_row: int = int(floor((float(mount["z"]) - origin_z) / cell_m))
	var distance_cells: PackedFloat32Array = PackedFloat32Array()
	distance_cells.resize(size * size)

	for row in range(size):
		for column in range(size):
			var h: float = heights[index_of(center_column - radius + column, center_row - radius + row)]
			distance_cells[row * size + column] = 0.0 if h <= 0.0 else 1.0e9

	# Two-pass chamfer distance (cells) from the nearest sea cell.
	var diagonal: float = 1.4142
	for row in range(size):
		for column in range(size):
			var at: int = row * size + column
			var best: float = distance_cells[at]

			if column > 0:
				best = minf(best, distance_cells[at - 1] + 1.0)
			if row > 0:
				best = minf(best, distance_cells[at - size] + 1.0)
				if column > 0:
					best = minf(best, distance_cells[at - size - 1] + diagonal)
				if column < size - 1:
					best = minf(best, distance_cells[at - size + 1] + diagonal)

			distance_cells[at] = best

	for row in range(size - 1, -1, -1):
		for column in range(size - 1, -1, -1):
			var at: int = row * size + column
			var best: float = distance_cells[at]

			if column < size - 1:
				best = minf(best, distance_cells[at + 1] + 1.0)
			if row < size - 1:
				best = minf(best, distance_cells[at + size] + 1.0)
				if column < size - 1:
					best = minf(best, distance_cells[at + size + 1] + diagonal)
				if column > 0:
					best = minf(best, distance_cells[at + size - 1] + diagonal)

			distance_cells[at] = best

	var rotation: float = deg_to_rad(float(mount["rot"]))
	var cos_r: float = cos(rotation)
	var sin_r: float = sin(rotation)
	var cap_scale: float = float(mount["beach_cap_m"]) / 1100.0
	var exponent: float = float(mount.get("beach_exp", 1.7))
	var spawn: Dictionary = rules.get("spawn_keep", {})

	for row in range(size):
		for column in range(size):
			var dx: float = float(column - radius) * cell_m
			var dz: float = float(row - radius) * cell_m
			var along: float = (dx * cos_r + dz * sin_r) / float(mount["a"])
			var across: float = (-dx * sin_r + dz * cos_r) / float(mount["b"])
			var weight: float = 1.0 - _smooth(clampf((sqrt(along * along + across * across) - 1.1) / 0.5, 0.0, 1.0))

			# The spawn point and the showroom beside it keep the land they always had.
			if not spawn.is_empty():
				var cx: float = origin_x + (float(center_column - radius + column) + 0.5) * cell_m
				var cz: float = origin_z + (float(center_row - radius + row) + 0.5) * cell_m
				var spawn_distance: float = Vector2(cx - float(spawn["x"]), cz - float(spawn["z"])).length()
				weight *= _smooth(clampf((spawn_distance - float(spawn["keep_radius_m"])) / float(spawn["blend_radius_m"]), 0.0, 1.0))
			var d_m: float = distance_cells[row * size + column] * cell_m

			if weight <= 0.0 or d_m <= 0.0:
				continue

			# 6 m by the shore, about 55 m at 1 km, 150 m at 2 km, 350 m at 3.5 km.
			var cap: float = 6.0 + 340.0 * cap_scale * pow(d_m / 3500.0, exponent * 0.91)
			var index: int = index_of(center_column - radius + column, center_row - radius + row)
			# Ridge noise under the cap, so where it binds the ground is not a smooth cone.
			cap *= 1.0 + 0.2 * _value(_ridged, index)
			heights[index] = lerpf(heights[index], minf(heights[index], cap), weight)



# Height bands (Dave 24 Oct): the island's land is ranked by distance from the sea and the height follows the share of land
# area, not metres: beach and flatland about 20%, then farmland, rolling hills, foothills, mountains and epic peaks. The
# table is data (`height_bands` in sketch_rules.json, share of land -> fraction of the island's summit height); the summit
# height runs from `summit_m` [low, high] by the island's own peak number, so islands differ.
# Island type (stage 2, Kathleen's list in tech/ISLAND_TYPES_Kathleen.md): `island_types` in sketch_rules.json holds rows that
# override the starter-island defaults (summit_m, height_bands, spire_share, layout of peaks). A starter island's type is
# `starter_types["x,z"]` if set, else rolled from the type weights by a hash of the island's place, so it never changes.
func _island_config(mount: Dictionary) -> Dictionary:
	var starter_rules: Dictionary = rules.get("starter_islands", {})
	var types: Dictionary = rules.get("island_types", {})
	var config: Dictionary = starter_rules.duplicate()

	if types.is_empty():
		return config

	var key: String = "%d,%d" % [int(mount["starter"][0]), int(mount["starter"][1])] if mount.has("starter") else ""
	var chosen: String = str(rules.get("starter_types", {}).get(key, ""))

	if chosen == "" or not types.has(chosen):
		var total: float = 0.0

		for name in types:
			total += float(types[name].get("weight", 1.0))

		var hash_value: int = (int(mount["x"]) * 73856093) ^ (int(mount["z"]) * 19349663)
		var roll: float = float(absi(hash_value) % 10007) / 10007.0 * total

		for name in types:
			roll -= float(types[name].get("weight", 1.0))

			if roll <= 0.0:
				chosen = str(name)
				break

		if chosen == "":
			chosen = str(types.keys()[0])

	for field in types[chosen]:
		config[field] = types[chosen][field]

	config["type"] = chosen
	return config


func _band_table(mount: Dictionary, sea: PackedFloat32Array, size: int, radius: int) -> Dictionary:
	var starter_rules: Dictionary = _island_config(mount)
	var bands: Array = starter_rules.get("height_bands", [])

	if bands.is_empty():
		return {}

	var summit_range: Array = starter_rules.get("summit_m", [1000, 1450])
	var peak_range: Array = starter_rules.get("peak_m", [300, 560])
	var t: float = clampf((float(mount["peak"]) - float(peak_range[0])) / maxf(float(peak_range[1]) - float(peak_range[0]), 1.0), 0.0, 1.0)
	var summit: float = lerpf(float(summit_range[0]), float(summit_range[1]), t)
	# The spire sits on top of the bands (so the summit is a peak, not the end of a smooth curve): the bands end at
	# (1 - spire_share) of the summit height and the spire adds the rest over the last (1 - spire_start) of the distance to the sea.
	var spire: float = float(starter_rules.get("spire_share", 0.0)) * summit
	var distances: PackedFloat32Array = PackedFloat32Array()
	var rotation: float = deg_to_rad(float(mount["rot"]))
	var cos_r: float = cos(rotation)
	var sin_r: float = sin(rotation)

	for row in range(size):
		for column in range(size):
			var d_m: float = sea[row * size + column] * cell_m

			if d_m <= 0.0:
				continue

			var dx: float = float(column - radius) * cell_m
			var dz: float = float(row - radius) * cell_m
			var along: float = (dx * cos_r + dz * sin_r) / float(mount["a"])
			var across: float = (-dx * sin_r + dz * cos_r) / float(mount["b"])

			if along * along + across * across <= 1.6:
				distances.append(d_m)

	distances.sort()
	var farthest: float = distances[distances.size() - 1] if not distances.is_empty() else 1.0
	var peaks: Array = _pick_peaks(starter_rules, sea, size, radius, farthest)
	return {
		"bands": bands, "summit": summit, "distances": distances, "spire": spire, "farthest": farthest,
		"spire_start": float(starter_rules.get("spire_start", 0.88)), "spire_power": float(starter_rules.get("spire_power", 2.2)),
		"layout": peaks, "layout_base": float(starter_rules.get("layout_base", 0.4)),
		"peak_width_m": float(starter_rules.get("peak_width_m", 1500.0)),
		"type": str(starter_rules.get("type", "")),
	}


# Peak layout (type rows with `peaks`: N, `peak_heights`: factors, `peak_separation_m`): the peaks are put on the island's
# interior ridge, the cells farthest from the sea, at least the separation apart, highest first. Returns [x_m, z_m, factor] rows
# relative to the island centre (the same frame as dx, dz in the shaping passes).
func _pick_peaks(config: Dictionary, sea: PackedFloat32Array, size: int, radius: int, farthest: float) -> Array:
	var count: int = int(config.get("peaks", 0))
	var factors: Array = config.get("peak_heights", [])
	var peaks: Array = []

	if count <= 0:
		return peaks

	var separation: float = float(config.get("peak_separation_m", 1800.0))
	var order: Array = []

	for row in range(size):
		for column in range(size):
			var d_m: float = sea[row * size + column] * cell_m

			if d_m >= 0.3 * farthest:
				order.append([d_m, column, row])

	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])

	for candidate in order:
		var x: float = float(int(candidate[1]) - radius) * cell_m
		var z: float = float(int(candidate[2]) - radius) * cell_m
		var clear: bool = true

		for peak in peaks:
			if Vector2(x - float(peak[0]), z - float(peak[1])).length() < separation:
				clear = false
				break

		if clear:
			var factor: float = float(factors[peaks.size()]) if peaks.size() < factors.size() else 1.0
			peaks.append([x, z, factor])

			if peaks.size() >= count:
				break

	return peaks


# Height of the band curve at distance d_m from the sea.
func _band_height(table: Dictionary, d_m: float, x_m: float = 0.0, z_m: float = 0.0) -> float:
	var distances: PackedFloat32Array = table["distances"]
	var bands: Array = table["bands"]

	if distances.is_empty():
		return 0.0

	var share: float = float(distances.bsearch(d_m)) / float(distances.size())
	var spire: float = 0.0

	if float(table["spire"]) > 0.0:
		var u_top: float = clampf((d_m / float(table["farthest"]) - float(table["spire_start"])) / (1.0 - float(table["spire_start"])), 0.0, 1.0)
		spire = float(table["spire"]) * pow(u_top, float(table["spire_power"]))

	for i in range(1, bands.size()):
		if share <= float(bands[i][0]):
			var from: float = float(bands[i - 1][0])
			var span: float = maxf(float(bands[i][0]) - from, 0.0001)
			var u: float = (share - from) / span
			# Linear on the last segment: an eased end flattens the top into a plateau.
			var eased: float = u if i == bands.size() - 1 else _smooth(u)
			return minf(_layout(table, d_m, share, x_m, z_m, float(table["summit"]) * lerpf(float(bands[i - 1][1]), float(bands[i][1]), eased)) + spire, float(table["summit"]))

	return minf(_layout(table, d_m, share, x_m, z_m, float(table["summit"]) * float(bands[bands.size() - 1][1])) + spire, float(table["summit"]))


# Peak layout: rows [along, across, width, height factor] in island-ellipse units. High ground (share above 0.4) is shaped
# toward the nearest peaks, with passes in between at `layout_base` of the band height; low ground is left alone.
func _layout(table: Dictionary, d_m: float, share: float, x_m: float, z_m: float, band_height: float) -> float:
	var peaks: Array = table["layout"]

	if peaks.is_empty():
		return band_height

	var width: float = float(table["peak_width_m"])
	var field: float = 0.0
	var cone: float = 0.0

	for row in peaks:
		var distance_sq: float = Vector2(x_m - float(row[0]), z_m - float(row[1])).length_squared()
		var gauss: float = exp(-distance_sq / maxf(width * width, 1.0))
		field = maxf(field, float(row[2]) * gauss)
		# Each peak is its own cone, so it stands even where the sea-distance rank is low; it fades out at the coast.
		cone = maxf(cone, float(table["summit"]) * float(row[2]) * gauss * _smooth(clampf(d_m / 700.0, 0.0, 1.0)))

	var factor: float = float(table["layout_base"]) + (1.0 - float(table["layout_base"])) * clampf(field, 0.0, 1.0)
	return maxf(band_height * lerpf(1.0, factor, _smooth(clampf((share - 0.4) / 0.4, 0.0, 1.0))), cone)


# Foothill belt (ISLAND_SHAPE_PLAN step 2): the cap above only lowers land, so the sectors beside the peak axis stayed low and
# flat for kilometres. Inland ground now rises to at least a share of the same concave curve, modulated by radial ridges
# (spokes around the island centre, wandering with distance), so every sector has ridges and gullies running to the coast
# for the valleys to fall between. Spawn area, shore and the island's own peak are left alone.
func _raise_foothills(mount: Dictionary) -> void:
	var reach_m: float = maxf(float(mount["a"]), float(mount["b"])) * 1.6
	var radius: int = int(ceil(reach_m / cell_m))
	var size: int = radius * 2 + 1
	var center_column: int = int(floor((float(mount["x"]) - origin_x) / cell_m))
	var center_row: int = int(floor((float(mount["z"]) - origin_z) / cell_m))
	var sea: PackedFloat32Array = _sea_distance(center_column, center_row, radius)
	var rotation: float = deg_to_rad(float(mount["rot"]))
	var cos_r: float = cos(rotation)
	var sin_r: float = sin(rotation)
	var cap_scale: float = float(mount["beach_cap_m"]) / 1100.0
	var exponent: float = float(mount.get("beach_exp", 1.7))
	var floor_share: float = float(mount.get("foothill_floor", 0.88))
	var spokes: float = float(mount.get("foothill_spokes", 9.0))
	var wander: float = float(mount.get("foothill_wander", 0.5))
	var table: Dictionary = _band_table(mount, sea, size, radius)
	var ceiling: float = INF
	var spawn: Dictionary = rules.get("spawn_keep", {})
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = SeedUtil.purpose_seed(_master, "foothill_spokes_" + str(mount.get("id", "")))
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 1.0
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2

	for row in range(size):
		for column in range(size):
			var d_m: float = sea[row * size + column] * cell_m

			if d_m <= 150.0:
				continue

			var dx: float = float(column - radius) * cell_m
			var dz: float = float(row - radius) * cell_m
			var along: float = (dx * cos_r + dz * sin_r) / float(mount["a"])
			var across: float = (-dx * sin_r + dz * cos_r) / float(mount["b"])
			var weight: float = 1.0 - _smooth(clampf((sqrt(along * along + across * across) - 1.1) / 0.5, 0.0, 1.0))
			weight *= _smooth(clampf((d_m - 150.0) / 350.0, 0.0, 1.0))

			if not spawn.is_empty():
				var cx: float = origin_x + (float(center_column - radius + column) + 0.5) * cell_m
				var cz: float = origin_z + (float(center_row - radius + row) + 0.5) * cell_m
				var spawn_distance: float = Vector2(cx - float(spawn["x"]), cz - float(spawn["z"])).length()
				weight *= _smooth(clampf((spawn_distance - float(spawn["keep_radius_m"])) / float(spawn["blend_radius_m"]), 0.0, 1.0))

			if weight <= 0.0:
				continue

			var index: int = index_of(center_column - radius + column, center_row - radius + row)
			var angle: float = atan2(dz, dx) + wander * _value(_warp_x, index) * minf(d_m / 2000.0, 1.0)
			# Spokes: a closed circle in noise space, so the pattern is seamless around the island.
			var spoke: float = 0.5 + 0.5 * noise.get_noise_2d(cos(angle) * spokes * 0.35, sin(angle) * spokes * 0.35)
			spoke = clampf(spoke * 1.4 - 0.2, 0.0, 1.0)
			var curve: float = 6.0 + 340.0 * cap_scale * pow(d_m / 3500.0, exponent * 0.91)

			if not table.is_empty():
				curve = _band_height(table, d_m, dx, dz)

			var target: float = minf(curve * (floor_share + (1.0 - floor_share) * spoke), ceiling)

			if target > heights[index]:
				heights[index] = lerpf(heights[index], target, weight)



# Volcano type: a crater (no lava) cut into the island's highest point, a bowl floor `depth_m` under the summit. The breach
# is a gap in the rim toward `breach_bearing_deg` so the crater lake can drain to a river instead of being a closed pit.
func _crater_at_summit(mount: Dictionary, crater: Dictionary, radius: int) -> void:
	var center_column: int = int(floor((float(mount["x"]) - origin_x) / cell_m))
	var center_row: int = int(floor((float(mount["z"]) - origin_z) / cell_m))
	var best: float = -INF
	var best_at: Vector2 = Vector2.ZERO

	for row_offset in range(-radius, radius + 1):
		for column_offset in range(-radius, radius + 1):
			var column: int = center_column + column_offset
			var row: int = center_row + row_offset
			var h: float = heights[index_of(column, row)]

			if h > best:
				best = h
				best_at = cell_center_m(column, row)

	mount["crater_at"] = [best_at.x, best_at.y]   # metadata for the island checks; no terrain effect
	var crater_rules: Dictionary = crater.duplicate()
	# The rim is the ring round the summit at the crater radius, lifted a little, so it stands as a wall even when the summit
	# is a narrow spire (sampling the single highest cell as the rim left only a pit in the spire's side).
	var crater_radius: float = float(crater.get("radius_m", 320.0))
	var ring_sum: float = 0.0
	var ring_count: int = 16

	for step in range(ring_count):
		var angle: float = TAU * float(step) / float(ring_count)
		var at: Vector2 = best_at + Vector2(cos(angle), sin(angle)) * crater_radius
		ring_sum += heights[index_of(int(floor((at.x - origin_x) / cell_m)), int(floor((at.y - origin_z) / cell_m)))]

	var rim: float = ring_sum / float(ring_count) + float(crater.get("rim_lift_m", 60.0))
	_carve_crater(best_at, crater_radius, float(crater.get("depth_m", 180.0)), rim, crater_rules, bool(crater.get("lava", false)), true)


# Chamfer distance (in cells) from the nearest sea cell, over the square of `radius` cells round a centre cell.
func _sea_distance(center_column: int, center_row: int, radius: int) -> PackedFloat32Array:
	var size: int = radius * 2 + 1
	var distance_cells: PackedFloat32Array = PackedFloat32Array()
	distance_cells.resize(size * size)

	for row in range(size):
		for column in range(size):
			var h: float = heights[index_of(center_column - radius + column, center_row - radius + row)]
			distance_cells[row * size + column] = 0.0 if h <= 0.0 else 1.0e9

	var diagonal: float = 1.4142

	for row in range(size):
		for column in range(size):
			var at: int = row * size + column
			var best: float = distance_cells[at]

			if column > 0:
				best = minf(best, distance_cells[at - 1] + 1.0)
			if row > 0:
				best = minf(best, distance_cells[at - size] + 1.0)
				if column > 0:
					best = minf(best, distance_cells[at - size - 1] + diagonal)
				if column < size - 1:
					best = minf(best, distance_cells[at - size + 1] + diagonal)

			distance_cells[at] = best

	for row in range(size - 1, -1, -1):
		for column in range(size - 1, -1, -1):
			var at: int = row * size + column
			var best: float = distance_cells[at]

			if column < size - 1:
				best = minf(best, distance_cells[at + 1] + 1.0)
			if row < size - 1:
				best = minf(best, distance_cells[at + size] + 1.0)
				if column < size - 1:
					best = minf(best, distance_cells[at + size + 1] + diagonal)
				if column > 0:
					best = minf(best, distance_cells[at + size - 1] + diagonal)

			distance_cells[at] = best

	return distance_cells


# facing: how much this point lies on the island's beach side (+1) or
# its rocky side (-1). Only starter islands use it.
func _island_height(
	mount: Dictionary, distance: float, b: float, shore: float, slope: float,
	index: int, facing: float = 0.0
) -> float:
	var peak: float = float(mount["peak"])
	var beach: float = 0.0
	var rocky: float = 0.0

	if mount.has("beach_dir"):
		beach = _smooth(clampf((facing - 0.05) / 0.55, 0.0, 1.0))
		rocky = _smooth(clampf((-facing - 0.05) / 0.55, 0.0, 1.0))

	if distance < 1.0:
		var inland: float = 1.0 - distance
		var exponent: float = float(mount.get("exp", 1.0))
		var height: float = peak * pow(inland, exponent)
		var cliff: float = float(mount.get("cliff", 0))
		height += cliff * _smooth(clampf(inland / 0.07, 0.0, 1.0))

		# Gullies and ridges on the slopes, strongest on high ground.
		height += 0.18 * peak * inland * _value(_ridged, index) * (1.0 - beach)
		height += 6.0 * _value(_detail, index) * (1.0 - 0.7 * beach)

		if beach > 0.0:
			# A long gentle coastal plain behind the beach, then the hills.
			var plain: float = float(mount.get("plain_m", 28))
			var width: float = float(mount.get("plain_width", 0.5))
			var beach_exponent: float = float(mount.get("beach_exp", 1.7))
			# Concave rise from the shore (gentle at the beach, steeper inland)
			# with only a thin terrace at the water, as on real volcanic islands.
			var terrace: float = 1.5 + plain * minf(inland / width, 1.0)
			var beach_height: float = maxf(terrace, peak * pow(inland, beach_exponent))

			height = lerpf(height, beach_height, beach)

		if rocky > 0.0:
			# Steep rocky shore with sea cliffs facing the pole.
			var rocky_cliff: float = float(mount.get("rocky_cliff_m", 120))
			height += rocky * rocky_cliff * _smooth(clampf(inland / 0.05, 0.0, 1.0))
			height += rocky * 0.15 * peak * inland * absf(_value(_ridged, index))

		return maxf(height, 1.0)

	var outside: float = (distance - 1.0) * b
	var shelf_depth: float = 40.0

	# Shallow fringes vary in width around the coast. Beaches get wide
	# sandy shallows, rocky shores drop away fast.
	shore *= 0.35 + 0.65 * (0.5 + 0.5 * _value(_hills, index))
	shore = lerpf(lerpf(shore, shore * 2.0, beach), 100.0, rocky)

	if outside < shore:
		return -shelf_depth * (outside / maxf(shore, 1.0)) - 1.0

	var t: float = clampf((outside - shore) / slope, 0.0, 1.0)
	return -shelf_depth - (4000.0 - shelf_depth) * pow(t, 0.8)


func _seamount_height(mount: Dictionary, distance: float) -> float:
	if distance >= 1.0:
		return -INF

	var peak: float = float(mount["peak"])
	return peak - (peak + 4000.0) * pow(distance, 1.3)


func _atoll_height(mount: Dictionary, distance: float, b: float, index: int) -> float:
	var ring: float = float(mount.get("ring_m", 300))
	var from_ring: float = (distance - 1.0) * b

	if absf(from_ring) <= ring * 0.5:
		# Reef islets with gaps where the sea breaks through.
		return 2.0 + 5.0 * _value(_detail, index) if _value(_fine_x, index) > -0.35 else -3.0

	if from_ring < 0.0:
		return -22.0 + 6.0 * _value(_detail, index)

	var t: float = clampf((from_ring - ring * 0.5) / 2600.0, 0.0, 1.0)
	return -8.0 - 3992.0 * pow(t, 0.7)


# A sheltered bay on the beach side of a starter island, for the port:
# a rounded harbor just inside the beach, opening to the sea through a
# narrower mouth, with flat ground around it for the harbor town.
func _carve_bay(mount: Dictionary) -> void:
	var b: float = float(mount["b"])
	var direction: Vector2 = Vector2(float(mount["beach_dir"][0]), float(mount["beach_dir"][1]))
	var radius: float = b * float(mount.get("bay_radius", 0.32))
	var depth: float = float(mount.get("bay_depth_m", -14))
	var island_center: Vector2 = Vector2(float(mount["x"]), float(mount["z"]))

	# Walk out from the island's middle toward the beach to find the coast.
	var coast: Vector2 = island_center + direction * b
	var step: float = 0.0

	while step < b * 3.0:
		var probe: Vector2 = island_center + direction * step

		if height_at_m(probe.x, probe.y) <= 0.0:
			coast = probe
			break

		step += cell_m * 0.5

	var center: Vector2 = coast - direction * radius * 0.6
	mount["bay_center"] = [int(round(center.x)), int(round(center.y))]
	mount["bay_radius_m"] = int(round(radius))
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var reach: float = radius * 2.3
	var radius_cells: int = int(ceil(reach / cell_m)) + 1
	var center_column: int = int(floor((center.x - origin_x) / cell_m))
	var center_row: int = int(floor((center.y - origin_z) / cell_m))

	for row_offset in range(-radius_cells, radius_cells + 1):
		for column_offset in range(-radius_cells, radius_cells + 1):
			var column: int = center_column + column_offset
			var row: int = center_row + row_offset
			var index: int = index_of(column, row)
			var offset: Vector2 = cell_center_m(column, row) - center

			# A ragged shoreline, not a perfect circle.
			offset += Vector2(_value(_fine_x, index), _value(_fine_z, index)) * radius * 0.3
			var along: float = offset.dot(direction)
			var lateral: float = absf(offset.dot(side))
			var distance: float = Vector2(along / 1.15, lateral / 0.9).length() / radius
			var in_mouth: bool = along > 0.0 and along < radius * 2.0 and lateral < radius * 0.45

			if distance < 1.0:
				heights[index] = minf(heights[index], depth * (1.0 - 0.6 * distance * distance) - 1.0)
			elif in_mouth:
				heights[index] = minf(heights[index], depth * 0.6)
			elif distance < 2.1:
				# Flat harbor ground rising gently away from the water, up
				# to the height of the land behind so it meets the hills
				# without a cliff or a ditch.
				var t: float = (distance - 1.0) / 1.1
				var rim: float = 2.0 + 70.0 * pow(t, 1.6)
				heights[index] = minf(heights[index], rim)


# ==================================================
# THE CENTER ISLAND
# ==================================================

# A broad jungle shield with a steep volcano in the middle, a crater at
# the top and a breach in the rim where lava will spill out.
func _raise_landmark_islands() -> void:
	var owner_index: int = feature_ids.find("center_island")

	for feature in settings.world_features:
		if str(feature.get("kind", "")) != "landmark_island":
			continue

		var tile: float = float(settings.tile_size_m)
		var center: Vector2 = _feature_center_m(feature)
		var a: float = float(feature["half_length_tiles"]) * tile
		var b: float = float(feature["half_width_tiles"]) * tile
		var rim_height: float = float(feature.get("peak_m", 1900))
		var crater: Dictionary = feature.get("crater", {})
		var crater_radius: float = float(crater.get("radius_m", 700))
		var crater_depth: float = float(crater.get("depth_m", 250))

		var terrain: Dictionary = feature.get("terrain", {})
		var shield: Dictionary = {
			"type": "island", "x": center.x, "z": center.y, "a": a, "b": b,
			"rot": float(feature.get("rotation_deg", 0)), "peak": 480.0, "exp": 0.85,
			"cliff": float(terrain.get("cliff_m", 60)), "shore": 250.0,
		}
		_raise_mount(shield, owner_index)

		# The cone's rim sits at the requested peak height.
		var cone_radius: float = b * 0.48
		var cone_exponent: float = 1.25
		var apex: float = rim_height / pow(1.0 - crater_radius / cone_radius, cone_exponent)
		var cone: Dictionary = {
			"type": "island", "x": center.x, "z": center.y, "a": cone_radius, "b": cone_radius,
			"rot": 0.0, "peak": apex, "exp": cone_exponent, "cliff": 0.0, "shore": 0.0,
		}
		_raise_cone_exact(cone, owner_index)

		if not terrain.is_empty():
			_make_hostile(center, a, b, terrain, owner_index)

		var city: Dictionary = feature.get("ruined_city", {})

		if not city.is_empty():
			_prepare_ruined_city(center, city, owner_index)

		_carve_crater(center, crater_radius, crater_depth, rim_height, crater)
		_lava_river(center, crater_radius, rim_height - crater_depth, crater)

		if not terrain.is_empty():
			_scorch(center, a, b, crater_radius, terrain, owner_index)


# Roughens the island into hostile ground: jagged ridges, ravines running
# down from the volcano, and swampy basins in the lowlands.
func _make_hostile(center: Vector2, a: float, b: float, terrain: Dictionary, owner_index: int) -> void:
	var ravines: float = float(terrain.get("ravines", 9))
	var ravine_depth: float = float(terrain.get("ravine_depth_m", 140))
	var jagged: float = float(terrain.get("jaggedness_m", 150))
	var swamp_threshold: float = float(terrain.get("basin_threshold", terrain.get("swamp_threshold", 0.35)))
	var swamp_inland: Array = terrain.get("basin_inland", terrain.get("swamp_inland", [0.1, 0.45]))
	var basin_special: int = SPECIAL_SALT if str(terrain.get("basin_kind", "swamp")) == "salt_flat" else SPECIAL_SWAMP
	var mesa_threshold: float = float(terrain.get("mesa_threshold", 2.0))
	var mesa_step: float = float(terrain.get("mesa_step_m", 55))
	var radius_cells: int = int(ceil(a * 1.3 / cell_m)) + 1
	var center_column: int = int(floor((center.x - origin_x) / cell_m))
	var center_row: int = int(floor((center.y - origin_z) / cell_m))

	for row_offset in range(-radius_cells, radius_cells + 1):
		for column_offset in range(-radius_cells, radius_cells + 1):
			var column: int = center_column + column_offset
			var row: int = center_row + row_offset
			var index: int = index_of(column, row)

			if owners[index] != owner_index or heights[index] <= 0.0:
				continue

			var h: float = heights[index]
			var offset: Vector2 = cell_center_m(column, row) - center
			var angle: float = atan2(offset.y, offset.x) + 0.6 * _value(_warp_x, index)
			var reach: float = sqrt(pow(offset.x / a, 2.0) + pow(offset.y / b, 2.0))
			var inland: float = clampf(1.0 - reach, 0.0, 1.0)

			# Jagged ridges everywhere above the shore.
			h += jagged * _value(_ridged, index) * _smooth(clampf(h / 40.0, 0.0, 1.0))

			# Ravines radiating from the volcano, deepest mid-slope.
			var ravine: float = absf(sin(angle * ravines * 0.5))
			var cut: float = 1.0 - _smooth(clampf(ravine / 0.18, 0.0, 1.0))
			h -= ravine_depth * cut * _smooth(clampf(inland * 3.0, 0.0, 1.0)) * clampf(h / 200.0, 0.2, 1.0)

			# Swampy basins sunk into the lowlands, behind the sea cliffs,
			# fading in and out so their edges are not straight lines.
			var wet: float = 0.5 * _value(_hills, index) + 0.5 * _value(_detail, index)
			var low: float = float(swamp_inland[0])
			var high: float = float(swamp_inland[1])
			var window: float = (
				_smooth(clampf((inland - low) / 0.06, 0.0, 1.0))
				* (1.0 - _smooth(clampf((inland - high) / 0.12 + 0.5, 0.0, 1.0)))
			)
			var swampiness: float = _smooth(clampf((wet - swamp_threshold) / 0.15, 0.0, 1.0)) * window

			if swampiness > 0.0:
				var marsh: float = 3.0 + 6.0 * (0.5 + 0.5 * _value(_fine_x, index))

				if basin_special == SPECIAL_SALT:
					marsh = 4.0 + 1.5 * _value(_fine_x, index)

				h = lerpf(h, marsh, swampiness)

				if swampiness > 0.5:
					special[index] = basin_special

			# Stepped mesas: flat tops and steep risers, in patches.
			var mesa: float = _smooth(clampf((_value(_warp_z, index) - mesa_threshold) / 0.15, 0.0, 1.0))

			if mesa > 0.0 and h > 40.0 and h < 1000.0:
				var steps: float = h / mesa_step
				var riser: float = _smooth(clampf((steps - floor(steps) - 0.7) / 0.3, 0.0, 1.0))
				h = lerpf(h, (floor(steps) + riser) * mesa_step, mesa)

			heights[index] = maxf(h, 1.0)


# Flattens a broad, stepped plateau for the fallen city and marks the
# old roads leading from it. Ruins themselves come at the tile bake.
func _prepare_ruined_city(center: Vector2, city: Dictionary, owner_index: int) -> void:
	var offset: Array = city["offset_m"]
	var city_center: Vector2 = center + Vector2(float(offset[0]), float(offset[1]))
	var radius: float = float(city["radius_m"])
	var plateau: float = float(city["plateau_m"])
	var terraces: float = float(city.get("terraces", 3))
	var reach: float = radius * 1.6
	var radius_cells: int = int(ceil(reach / cell_m)) + 1
	var center_column: int = int(floor((city_center.x - origin_x) / cell_m))
	var center_row: int = int(floor((city_center.y - origin_z) / cell_m))

	for row_offset in range(-radius_cells, radius_cells + 1):
		for column_offset in range(-radius_cells, radius_cells + 1):
			var column: int = center_column + column_offset
			var row: int = center_row + row_offset
			var index: int = index_of(column, row)

			if heights[index] <= 0.0:
				continue

			var ragged: float = 1.0 + 0.12 * _value(_fine_x, index) + 0.22 * _value(_warp_x, index)
			var distance: float = (cell_center_m(column, row) - city_center).length() / (radius * ragged)

			if distance >= 1.6:
				continue

			# Low terraces stepping up toward the citadel in the middle.
			var level: float = floor((1.0 - clampf(distance, 0.0, 1.0)) * terraces)
			var flat: float = plateau + level * 12.0
			var blend: float = 1.0 - _smooth(clampf((distance - 1.0) / 0.6, 0.0, 1.0))
			heights[index] = lerpf(heights[index], flat, blend)

			if distance < 1.0:
				special[index] = SPECIAL_RUINS
				owners[index] = owner_index

	_ring_road(center, city_center, city, owner_index)


# The old road: a loop winding around the island at low to middle height,
# following the lie of the land and never climbing toward the volcano,
# with a short link to the city and spurs down to ruined shore villages.
func _ring_road(island_center: Vector2, city_center: Vector2, city: Dictionary, owner_index: int) -> void:
	var feature: Dictionary = {}

	for candidate in settings.world_features:
		if str(candidate.get("kind", "")) == "landmark_island":
			feature = candidate

	var tile: float = float(settings.tile_size_m)
	var a: float = float(feature["half_length_tiles"]) * tile
	var b: float = float(feature["half_width_tiles"]) * tile
	var road: Dictionary = city.get("ring_road", {})
	var reach_range: Array = road.get("reach", [0.6, 0.8])
	var reach: float = float(road.get("start_reach", 0.7))
	var angle_step: float = cell_m * 0.5 / (0.7 * b)
	var previous_height: float = -1.0
	var loop: Array = []
	var angle: float = 0.0

	# Walk once around, at each step choosing the nearby distance from the
	# middle that keeps the road most level.
	while angle < TAU:
		var best_reach: float = reach
		var best_cost: float = INF

		for candidate_index in range(7):
			var trial: float = clampf(
				reach + (float(candidate_index) - 3.0) * 0.01,
				float(reach_range[0]), float(reach_range[1])
			)
			var point: Vector2 = island_center + Vector2(cos(angle) * a, sin(angle) * b) * trial
			var height: float = height_at_m(point.x, point.y)
			var cost: float = 0.0 if previous_height < 0.0 else absf(height - previous_height)
			cost += 40.0 * absf(trial - reach)

			if height <= 0.0:
				cost += 10000.0

			if cost < best_cost:
				best_cost = cost
				best_reach = trial

		reach = best_reach
		var point: Vector2 = island_center + Vector2(cos(angle) * a, sin(angle) * b) * reach
		previous_height = height_at_m(point.x, point.y)

		if not loop.is_empty():
			_mark_road_line(loop[loop.size() - 1], point, 0.0)

		loop.append(point)
		angle += angle_step

	_mark_road_line(loop[loop.size() - 1], loop[0], 0.0)

	# Link from the city's edge to the nearest point of the loop.
	var nearest: Vector2 = loop[0]

	for point in loop:
		if point.distance_to(city_center) < nearest.distance_to(city_center):
			nearest = point

	_mark_road_line(city_center, nearest)

	# Ruined shore villages, spread around the coast, each reached by a
	# spur from the loop.
	var villages: int = int(city.get("shore_villages", 0))
	var village_radius: float = float(city.get("village_radius_m", 260))
	var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "center_island_villages")
	var city_angle: float = atan2((city_center.y - island_center.y) / b, (city_center.x - island_center.x) / a)

	for village_index in range(villages):
		var village_angle: float = city_angle + TAU * (float(village_index) + 0.5 + rng.randf_range(-0.2, 0.2)) / float(villages)
		var direction: Vector2 = Vector2(cos(village_angle) * a, sin(village_angle) * b).normalized()
		var on_loop: Vector2 = loop[0]

		for point in loop:
			var to_point: Vector2 = (point - island_center).normalized()

			if to_point.dot(direction) > (on_loop - island_center).normalized().dot(direction):
				on_loop = point

		# Walk out to the shore, then step back inland a little.
		var shore: Vector2 = on_loop
		var walked: float = 0.0

		while walked < 6000.0:
			var probe: Vector2 = on_loop + direction * walked

			if height_at_m(probe.x, probe.y) <= 0.0:
				break

			shore = probe
			walked += cell_m * 0.5

		var village: Vector2 = shore - direction * village_radius * 1.2

		if special[_index_at(village)] == SPECIAL_LAVA:
			continue

		_mark_road_line(on_loop, village)
		_flatten_ruin(village, village_radius, owner_index)


func _index_at(point: Vector2) -> int:
	return index_of(
		int(floor((point.x - origin_x) / cell_m)), int(floor((point.y - origin_z) / cell_m))
	)


func _mark_road(point: Vector2) -> void:
	var index: int = _index_at(point)

	if heights[index] > 0.0 and (special[index] == SPECIAL_NONE or special[index] == SPECIAL_SALT):
		special[index] = SPECIAL_ROAD


func _mark_road_line(from: Vector2, to: Vector2, wiggle: float = 120.0) -> void:
	var length: float = from.distance_to(to)
	var steps: int = int(ceil(length / (cell_m * 0.25)))

	for step in range(steps + 1):
		var t: float = float(step) / float(maxi(steps, 1))
		var side: Vector2 = (to - from).normalized().orthogonal()
		var wander: float = wiggle * sin(t * PI * 3.0) * sin(t * PI)
		_mark_road(from.lerp(to, t) + side * wander)


# A small flattened patch where a village once stood.
func _flatten_ruin(center: Vector2, radius: float, owner_index: int) -> void:
	var radius_cells: int = int(ceil(radius * 1.6 / cell_m)) + 1
	var center_column: int = int(floor((center.x - origin_x) / cell_m))
	var center_row: int = int(floor((center.y - origin_z) / cell_m))
	var level: float = maxf(height_at_m(center.x, center.y), 4.0)

	for row_offset in range(-radius_cells, radius_cells + 1):
		for column_offset in range(-radius_cells, radius_cells + 1):
			var column: int = center_column + column_offset
			var row: int = center_row + row_offset
			var index: int = index_of(column, row)

			if heights[index] <= 0.0:
				continue

			var distance: float = (cell_center_m(column, row) - center).length() / radius

			if distance >= 1.6:
				continue

			var blend: float = 1.0 - _smooth(clampf((distance - 1.0) / 0.6, 0.0, 1.0))
			heights[index] = lerpf(heights[index], level, blend)

			if distance < 1.0 and special[index] != SPECIAL_LAVA:
				special[index] = SPECIAL_RUINS


# Scorched earth: the volcano's upper slopes and the tongues of old lava
# flows running down from the crater, black and ashen.
func _scorch(center: Vector2, a: float, b: float, crater_radius: float, terrain: Dictionary, owner_index: int) -> void:
	var scorched_inland: float = float(terrain.get("scorched_inland", 0.62))
	var flows: int = int(terrain.get("old_flows", 5))
	var flow_length: float = float(terrain.get("old_flow_length_m", 8500))
	var radius_cells: int = int(ceil(a * 1.2 / cell_m)) + 1
	var center_column: int = int(floor((center.x - origin_x) / cell_m))
	var center_row: int = int(floor((center.y - origin_z) / cell_m))

	for row_offset in range(-radius_cells, radius_cells + 1):
		for column_offset in range(-radius_cells, radius_cells + 1):
			var column: int = center_column + column_offset
			var row: int = center_row + row_offset
			var index: int = index_of(column, row)

			if owners[index] != owner_index or heights[index] <= 0.0 or special[index] != SPECIAL_NONE:
				continue

			var offset: Vector2 = cell_center_m(column, row) - center
			var reach: float = sqrt(pow(offset.x / a, 2.0) + pow(offset.y / b, 2.0))
			var inland: float = 1.0 - reach + 0.08 * _value(_detail, index)

			if inland > scorched_inland:
				special[index] = SPECIAL_SCORCHED

	# Old flows spread around the volcano, steering clear of the city side.
	var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "center_island_flows")

	for flow_index in range(flows):
		var bearing: float = TAU * (float(flow_index) + rng.randf_range(0.15, 0.85)) / float(flows)
		var direction: Vector2 = Vector2(sin(bearing), -cos(bearing))

		# Northwest is the city's side; skip flows aimed at it.
		if direction.dot(Vector2(-0.9, -0.4).normalized()) > 0.75:
			continue

		var side: Vector2 = Vector2(-direction.y, direction.x)
		var distance_along: float = crater_radius
		var width: float = rng.randf_range(300.0, 650.0)
		var phase: float = rng.randf() * TAU

		while distance_along < flow_length:
			var wander: float = 700.0 * sin(distance_along / 2000.0 + phase)
			var point: Vector2 = center + direction * distance_along + side * wander
			var taper: float = width * (1.0 - 0.6 * distance_along / flow_length)
			var cells: int = int(ceil(taper / cell_m))
			var column: int = int(floor((point.x - origin_x) / cell_m))
			var row: int = int(floor((point.y - origin_z) / cell_m))

			for step_z in range(-cells, cells + 1):
				for step_x in range(-cells, cells + 1):
					if Vector2(step_x, step_z).length() * cell_m > taper:
						continue

					var index: int = index_of(column + step_x, row + step_z)

					# Old flows bury whatever they cross, the road included.
					if heights[index] > 0.0 and (
						special[index] == SPECIAL_NONE
						or special[index] == SPECIAL_SALT
						or special[index] == SPECIAL_ROAD
					):
						special[index] = SPECIAL_SCORCHED
						heights[index] += 4.0

			distance_along += cell_m * 0.5


# A lava river from the crater breach down to the sea.
func _lava_river(center: Vector2, crater_radius: float, start_height: float, crater: Dictionary) -> void:
	if not bool(crater.get("lava_flow_to_sea", false)):
		return

	var bearing: float = deg_to_rad(float(crater.get("breach_bearing_deg", 160)))
	var direction: Vector2 = Vector2(sin(bearing), -cos(bearing))
	var side: Vector2 = Vector2(-direction.y, direction.x)
	var distance: float = crater_radius * 0.8
	var height: float = start_height

	while distance < 30000.0:
		var wander: float = 600.0 * sin(distance / 1800.0) + 300.0 * sin(distance / 700.0 + 1.3)
		var point: Vector2 = center + direction * distance + side * wander
		var column: int = int(floor((point.x - origin_x) / cell_m))
		var row: int = int(floor((point.y - origin_z) / cell_m))
		var index: int = index_of(column, row)

		if heights[index] <= 0.0:
			break

		# The river sits a little below its banks and never climbs.
		height = minf(height, heights[index] - 6.0)
		heights[index] = maxf(height, 1.0)
		special[index] = SPECIAL_LAVA

		for spread in [-1, 1]:
			var bank: int = index_of(column + spread, row)

			if heights[bank] > 0.0 and special[bank] == SPECIAL_NONE:
				special[bank] = SPECIAL_LAVA

		distance += cell_m * 0.5


# The volcano cone without coastal warping, so the crater sits true.
func _raise_cone_exact(cone: Dictionary, owner_index: int) -> void:
	var radius: float = float(cone["a"])
	var radius_cells: int = int(ceil(radius / cell_m)) + 1
	var center_column: int = int(floor((float(cone["x"]) - origin_x) / cell_m))
	var center_row: int = int(floor((float(cone["z"]) - origin_z) / cell_m))
	var center: Vector2 = Vector2(float(cone["x"]), float(cone["z"]))

	for row_offset in range(-radius_cells, radius_cells + 1):
		for column_offset in range(-radius_cells, radius_cells + 1):
			var column: int = center_column + column_offset
			var row: int = center_row + row_offset
			var index: int = index_of(column, row)
			var position: Vector2 = cell_center_m(column, row)
			var distance: float = position.distance_to(center) / radius

			if distance >= 1.0:
				continue

			var height: float = float(cone["peak"]) * pow(1.0 - distance, float(cone["exp"]))
			height += 0.08 * height * _value(_ridged, index)

			if height > heights[index]:
				heights[index] = _smooth_max(heights[index], height, 60.0)
				owners[index] = owner_index


func _carve_crater(
	center: Vector2, radius: float, depth: float, rim_height: float, crater: Dictionary, lava: bool = true, raise_rim: bool = false
) -> void:
	var floor_height: float = rim_height - depth
	var bearing: float = deg_to_rad(float(crater.get("breach_bearing_deg", 160)))
	var breach_direction: Vector2 = Vector2(sin(bearing), -cos(bearing))
	var breach_half_width: float = maxf(float(crater.get("breach_width_m", 120)) * 0.5, cell_m * 0.75)
	var reach: float = radius * 1.8
	var radius_cells: int = int(ceil(reach / cell_m)) + 1
	var center_column: int = int(floor((center.x - origin_x) / cell_m))
	var center_row: int = int(floor((center.y - origin_z) / cell_m))

	for row_offset in range(-radius_cells, radius_cells + 1):
		for column_offset in range(-radius_cells, radius_cells + 1):
			var column: int = center_column + column_offset
			var row: int = center_row + row_offset
			var index: int = index_of(column, row)
			var offset: Vector2 = cell_center_m(column, row) - center
			var distance: float = offset.length()

			if raise_rim and distance >= radius * 0.8 and distance < radius * 1.2:
				var wall: float = rim_height * (1.0 - pow(absf(distance / radius - 1.0) / 0.2, 2.0) * 0.25)
				heights[index] = maxf(heights[index], wall)

			if distance < radius:
				var bowl: float = floor_height + depth * pow(distance / radius, 3.0)
				heights[index] = minf(heights[index], bowl)

				if lava:
					special[index] = SPECIAL_LAVA

			var along: float = offset.dot(breach_direction)
			var lateral: float = absf(offset.cross(breach_direction))

			if along > radius * 0.6 and along < radius * 1.8 and lateral < breach_half_width:
				var channel: float = floor_height + 15.0 - (along - radius * 0.6) * 0.3
				heights[index] = minf(heights[index], channel)


# ==================================================
# HELPERS
# ==================================================

func _clamp_heights() -> void:
	var bottom: float = float(settings.world_bottom_m) + 20.0
	var top: float = float(settings.world_top_m) - 40.0

	for index in range(heights.size()):
		heights[index] = clampf(heights[index], bottom, top)


func _feature_center_m(feature: Dictionary) -> Vector2:
	var tile: float = float(settings.tile_size_m)
	var center_tile: Array = feature["center_tile"]
	return Vector2(
		(float(center_tile[0]) + 0.5) * tile,
		(float(center_tile[1]) + 0.5) * tile
	)


static func _smooth(t: float) -> float:
	var clamped: float = clampf(t, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


# Like max(), but rounds the crease where two shapes meet.
static func _smooth_max(a: float, b: float, k: float) -> float:
	var h: float = maxf(k - absf(a - b), 0.0) / k
	return maxf(a, b) + h * h * k * 0.25
