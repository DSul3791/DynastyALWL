class_name TileClimate
extends RefCounted

# Climate, moisture, biome, soil and fertility for one tile, from the
# finished height map and water map.
#
#   temperature  latitude (from the world settings) minus a lapse by height
#   moisture     wet air swept along the prevailing wind: it refills over the
#                sea, thins over land and drops hard when it climbs (so land
#                behind mountains is dry), plus nearness to fresh water
#   biome, soil  chosen from temperature, moisture, slope, height, water
#   fertility    soil base value scaled by moisture, temperature and slope
#
# Maps are one byte per sample (same grid as the height map).

const WrapNoiseScript := preload("res://src/worldgen/tile/wrap_noise.gd")
const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")

const OCEAN := 1
const LAKE := 2
const RIVER := 3

var samples: int = 0
var biome: PackedByteArray = PackedByteArray()
var soil: PackedByteArray = PackedByteArray()
var fertility: PackedByteArray = PackedByteArray()
var moisture: PackedByteArray = PackedByteArray()
var temperature_c: PackedFloat32Array = PackedFloat32Array()   # kept for reports and previews

# Report after build().
var biome_cells: Dictionary = {}     # biome name -> cells
var soil_cells: Dictionary = {}      # soil name -> cells
var fertile_km2: float = 0.0         # land with fertility of 150 or more and gentle slope
var spacing_m: float = 8.0

var _settings
var _rules: Dictionary = {}
var _tables
var _air_field: Dictionary = {}     # world wet-air field (see build_world_air), empty = sweep per tile
var _fresh_points: PackedVector2Array = PackedVector2Array()
var _use_fresh_points: bool = false
var _origin_sx: int = 0             # world sample index of sample 0 / row 0
var _origin_sz: int = 0


func setup(settings, rules: Dictionary, tables) -> void:
	_settings = settings
	_rules = rules["climate"]
	_tables = tables
	spacing_m = float(settings.map_spacing_m)


# Gives the climate the world-wide wet-air field, so the air at a place does
# not depend on which tile is being built. Without it, each tile sweeps the
# wind across itself starting from a fixed value.
func use_world_air(field: Dictionary) -> void:
	_air_field = field


# The fresh water that wets the land (river bonus, clay banks) comes from the world's own river lines, not from the water
# this frame happened to build: the drainage in a frame depends on how much upstream it can see, so two tiles that share an
# edge disagreed about which streams exist near it (23 Oct bake: soil/moisture/cover differed up to 240 m from the edge).
# `points` are river line points in world meters (RiverNetwork.guides_in), the same for every frame that contains them.
func use_world_fresh_water(points: PackedVector2Array) -> void:
	_fresh_points = points
	_use_fresh_points = true


# Builds a frame of the world grid: `heights` and `water_class` hold
# n by n samples whose first sample is world sample (origin_sx, origin_sz).
# A frame wider than a tile (a margin) must start on a multiple of the
# coarse step, so neighboring frames share the same coarse grid.
func build(heights: PackedFloat32Array, water_class: PackedByteArray, origin_sx: int, origin_sz: int) -> void:
	var clock: int = Time.get_ticks_msec()
	_origin_sx = origin_sx
	_origin_sz = origin_sz
	samples = int(round(sqrt(float(heights.size()))))
	var total: int = samples * samples
	var step: int = maxi(int(round(float(_rules["coarse_cell_m"]) / spacing_m)), 1)
	var coarse: int = (samples - 1) / step + 1
	var tile_m: float = float(_settings.tile_size_m)
	var z0: float = float(origin_sz) * spacing_m

	# Sea-level temperature for each row.
	var sea_temperature: PackedFloat32Array = PackedFloat32Array()
	sea_temperature.resize(samples)

	for j in range(samples):
		sea_temperature[j] = _settings.temperature_c(z0 + float(j) * spacing_m, 0.0)

	var lapse: float = float(_settings.lapse_rate_c_per_km) / 1000.0

	# Coarse grid: heights, ocean and fresh-water masks, then distances.
	var coarse_height: PackedFloat32Array = PackedFloat32Array()
	coarse_height.resize(coarse * coarse)
	var ocean_mask: PackedByteArray = PackedByteArray()
	ocean_mask.resize(coarse * coarse)
	var fresh_mask: PackedByteArray = PackedByteArray()
	fresh_mask.resize(coarse * coarse)

	for row in range(coarse):
		for column in range(coarse):
			coarse_height[row * coarse + column] = heights[row * step * samples + column * step]

	for j in range(samples):
		var coarse_row: int = mini(j / step, coarse - 1) * coarse

		for i in range(samples):
			var kind: int = water_class[j * samples + i]

			if kind == 0:
				continue

			var cell: int = coarse_row + mini(i / step, coarse - 1)

			if kind == OCEAN:
				ocean_mask[cell] = 1
			elif not _use_fresh_points:
				fresh_mask[cell] = 1

	for point in _fresh_points:
		var column: int = roundi((point.x / spacing_m - float(origin_sx)) / float(step))
		var row: int = roundi((point.y / spacing_m - float(origin_sz)) / float(step))

		if column >= 0 and column < coarse and row >= 0 and row < coarse:
			fresh_mask[row * coarse + column] = 1

	var cell_m: float = float(step) * spacing_m
	var ocean_distance: PackedFloat32Array = _chamfer(ocean_mask, coarse, cell_m)
	var fresh_distance: PackedFloat32Array = _chamfer(fresh_mask, coarse, cell_m)
	var air: PackedFloat32Array = _world_air_grid(coarse, step) if not _air_field.is_empty() else _wet_air(coarse_height, coarse, cell_m, tile_row_of(z0))

	print("  climate timing: coarse grids + chamfer + air %d ms" % (Time.get_ticks_msec() - clock))
	clock = Time.get_ticks_msec()
	# Noise so boundaries are organic.
	var noise_rules: Dictionary = _rules["noise"]
	var moisture_noise: PackedByteArray = _noise("climate_moisture", float(noise_rules["moisture_wavelength_m"]))
	var temperature_noise: PackedByteArray = _noise("climate_temperature", float(noise_rules["temperature_wavelength_m"]))
	var moisture_amplitude: float = float(noise_rules["moisture_amplitude"])
	var temperature_amplitude: float = float(noise_rules["temperature_amplitude_c"])

	# Wetness follows the tile row each sample row lies in (the row shared by
	# two tile rows belongs to the southern one), so neighbors agree.
	var row_wetness: PackedFloat32Array = PackedFloat32Array()
	row_wetness.resize(samples)

	for j in range(samples):
		row_wetness[j] = float(_rules["zone_wetness"][_settings.get_zone_group_for_row(tile_row_of(z0 + float(j) * spacing_m))])
	var near_fresh: float = float(_rules["near_fresh_water_m"])
	var fresh_bonus: float = float(_rules["fresh_water_bonus"])

	var rules_biome: Dictionary = _rules["biome"]
	var rules_soil: Dictionary = _rules["soil"]
	var rules_fertility: Dictionary = _rules["fertility"]

	var ids: Dictionary = {}

	for name in ["ocean", "beach", "hot_desert", "dry_scrub", "savanna", "tropical_forest", "mangrove",
			"temperate_grassland", "temperate_forest", "mixed_forest", "marsh", "heath", "boreal_forest",
			"tundra", "alpine_meadow", "bare_rock", "snowfield", "glacier"]:
		ids[name] = _tables.id_of("biomes", name)

	var soil_ids: Dictionary = {}

	for name in ["bare_rock", "sand", "gravel", "silt", "clay", "loam", "peat", "alluvium", "forest_humus",
			"stony_soil", "permafrost", "snow", "glacial_ice", "beach_sand"]:
		soil_ids[name] = _tables.id_of("soils", name)

	var soil_base: Dictionary = {}

	for entry in _tables.get_entries("soils"):
		soil_base[int(entry["id"])] = float(entry["fertility_base"])

	# Slope thresholds as tangents (cheaper than angles per sample).
	var rock_tan: float = tan(deg_to_rad(float(rules_biome["rock_slope_deg"])))
	var scree_tan: float = tan(deg_to_rad(float(rules_biome["scree_slope_deg"])))
	var marsh_tan: float = tan(deg_to_rad(float(rules_biome["marsh_slope_deg"])))
	var flood_tan: float = tan(deg_to_rad(float(rules_soil["floodplain_slope_deg"])))
	var stony_tan: float = tan(deg_to_rad(float(rules_soil["stony_slope_deg"])))
	var zero_tan: float = tan(deg_to_rad(float(rules_fertility["slope_zero_deg"])))
	var hot_min: float = float(rules_biome["hot_min_c"])
	var warm_min: float = float(rules_biome["warm_min_c"])
	var cold_min: float = float(rules_biome["cold_min_c"])
	var snow_max: float = float(rules_biome["snow_max_c"])
	var glacier_max: float = float(rules_biome["glacier_max_c"])
	var peak: float = float(rules_fertility["moisture_peak"])
	var width: float = float(rules_fertility["moisture_width"])
	var best_low: float = float(rules_fertility["temperature_best_low_c"])
	var best_high: float = float(rules_fertility["temperature_best_high_c"])
	var zero_low: float = float(rules_fertility["temperature_zero_low_c"])
	var zero_high: float = float(rules_fertility["temperature_zero_high_c"])

	biome.resize(total)
	soil.resize(total)
	fertility.resize(total)
	moisture.resize(total)
	temperature_c.resize(total)
	biome_cells = {}
	soil_cells = {}
	var biome_counts: PackedInt32Array = PackedInt32Array()
	biome_counts.resize(256)
	var soil_counts: PackedInt32Array = PackedInt32Array()
	soil_counts.resize(256)
	var fertile_cells: int = 0
	var inv_two_spacing: float = 1.0 / (2.0 * spacing_m)
	print("  climate timing: noise + setup %d ms" % (Time.get_ticks_msec() - clock))
	clock = Time.get_ticks_msec()

	for j in range(samples):
		var v: float = float(j) / float(step)
		var r0: int = mini(int(v), coarse - 2)
		var tv: float = v - float(r0)

		for i in range(samples):
			var index: int = j * samples + i
			var h: float = heights[index]
			var kind: int = water_class[index]
			var u: float = float(i) / float(step)
			var c0: int = mini(int(u), coarse - 2)
			var tu: float = u - float(c0)
			var base_cell: int = r0 * coarse + c0

			# Temperature and moisture (bilinear from the coarse grid).
			var temperature: float = sea_temperature[j] - lapse * maxf(h, 0.0)
			temperature += temperature_amplitude * (float(temperature_noise[index]) / 127.5 - 1.0)
			temperature_c[index] = temperature
			var air_here: float = lerpf(
				lerpf(air[base_cell], air[base_cell + 1], tu),
				lerpf(air[base_cell + coarse], air[base_cell + coarse + 1], tu), tv
			)
			var fresh_here: float = fresh_distance[(r0 + (1 if tv > 0.5 else 0)) * coarse + c0 + (1 if tu > 0.5 else 0)]
			var wet: float = row_wetness[j] * (0.4 + 0.9 * air_here)
			wet += fresh_bonus * clampf(1.0 - fresh_here / near_fresh, 0.0, 1.0)
			wet += moisture_amplitude * (float(moisture_noise[index]) / 127.5 - 1.0)
			wet = clampf(wet, 0.0, 1.0)
			moisture[index] = int(round(wet * 255.0))

			if kind != 0:
				var water_soil: int = soil_ids["sand"] if kind == OCEAN else (soil_ids["silt"] if kind == LAKE else soil_ids["gravel"])
				biome[index] = ids["ocean"]
				soil[index] = water_soil
				fertility[index] = 0
				biome_counts[ids["ocean"]] += 1
				soil_counts[water_soil] += 1
				continue

			# Slope as a tangent.
			var gx: float = (heights[index + (1 if i < samples - 1 else 0)] - heights[index - (1 if i > 0 else 0)]) * inv_two_spacing
			var gz: float = (heights[index + (samples if j < samples - 1 else 0)] - heights[index - (samples if j > 0 else 0)]) * inv_two_spacing
			var slope: float = sqrt(gx * gx + gz * gz)
			var ocean_here: float = ocean_distance[(r0 + (1 if tv > 0.5 else 0)) * coarse + c0 + (1 if tu > 0.5 else 0)]

			var chosen: int = _pick_biome(
				ids, rules_biome, temperature, wet, h, slope, ocean_here, fresh_here,
				hot_min, warm_min, cold_min, snow_max, glacier_max, rock_tan, marsh_tan
			)
			var picked_soil: int = _pick_soil(
				soil_ids, rules_soil, ids, chosen, wet, h, slope, fresh_here, ocean_here,
				flood_tan, stony_tan, scree_tan, rock_tan, float(rules_biome["beach_distance_m"])
			)
			biome[index] = chosen
			soil[index] = picked_soil
			biome_counts[chosen] += 1
			soil_counts[picked_soil] += 1

			# Fertility.
			var moisture_factor: float = clampf(1.0 - absf(wet - peak) / width, 0.0, 1.0)
			var temperature_factor: float = 1.0

			if temperature < best_low:
				temperature_factor = clampf((temperature - zero_low) / (best_low - zero_low), 0.0, 1.0)
			elif temperature > best_high:
				temperature_factor = clampf((zero_high - temperature) / (zero_high - best_high), 0.0, 1.0)

			var slope_factor: float = clampf(1.0 - slope / zero_tan, 0.0, 1.0)
			var value: float = soil_base[picked_soil] * (0.35 + 0.65 * moisture_factor) * temperature_factor * slope_factor
			fertility[index] = clampi(int(round(value)), 0, 255)

			if value >= 150.0:
				fertile_cells += 1

	print("  climate timing: per-sample loop %d ms" % (Time.get_ticks_msec() - clock))

	for entry in _tables.get_entries("biomes"):
		var count: int = biome_counts[int(entry["id"])]

		if count > 0:
			biome_cells[str(entry["name"])] = count

	for entry in _tables.get_entries("soils"):
		var count: int = soil_counts[int(entry["id"])]

		if count > 0:
			soil_cells[str(entry["name"])] = count

	fertile_km2 = float(fertile_cells) * spacing_m * spacing_m / 1.0e6


func _pick_biome(
	ids: Dictionary, rules: Dictionary, temperature: float, wet: float, h: float, slope: float,
	ocean_distance: float, fresh_distance: float, hot_min: float, warm_min: float, cold_min: float,
	snow_max: float, glacier_max: float, rock_tan: float, marsh_tan: float
) -> int:
	# Shores and wet lowlands first.
	if h < float(rules["beach_height_m"]) and ocean_distance < float(rules["beach_distance_m"]):
		if temperature >= hot_min and wet >= 0.6 and slope < marsh_tan:
			return ids["mangrove"]

		return ids["beach"]

	if h < float(rules["marsh_height_m"]) and slope < marsh_tan and wet >= float(rules["marsh_moisture"]) \
			and temperature > cold_min:
		return ids["marsh"]

	# Cold and high.
	if temperature < glacier_max and h > 150.0:
		return ids["glacier"]

	if temperature < snow_max:
		return ids["snowfield"]

	if slope > rock_tan:
		return ids["bare_rock"]

	if temperature < cold_min:
		return ids["tundra"]

	if h > float(rules["alpine_min_height_m"]) and temperature < warm_min + 3.0:
		return ids["alpine_meadow"]

	if temperature < warm_min:
		return ids["boreal_forest"] if wet >= float(rules["boreal_moisture"]) else ids["tundra"]

	# Hot.
	if temperature >= hot_min:
		if wet < float(rules["desert_moisture"]):
			return ids["hot_desert"]

		if wet < float(rules["scrub_moisture"]):
			return ids["dry_scrub"]

		if wet < float(rules["savanna_moisture"]):
			return ids["savanna"]

		return ids["tropical_forest"]

	# Temperate.
	if wet < float(rules["desert_moisture"]):
		return ids["dry_scrub"]

	if wet < float(rules["grassland_moisture"]):
		return ids["temperate_grassland"]

	if wet < float(rules["mixed_moisture"]):
		return ids["mixed_forest"] if temperature < float(rules["cool_forest_below_c"]) else ids["temperate_forest"]

	if ocean_distance < 600.0 and slope > 0.0 and temperature < float(rules["cool_forest_below_c"]) + 2.0:
		return ids["heath"]

	return ids["temperate_forest"]


func _pick_soil(
	soil_ids: Dictionary, rules: Dictionary, ids: Dictionary, chosen: int, wet: float, h: float, slope: float,
	fresh_distance: float, ocean_distance: float, flood_tan: float, stony_tan: float, scree_tan: float,
	rock_tan: float, beach_distance: float
) -> int:
	if chosen == ids["bare_rock"] or slope > rock_tan:
		return soil_ids["bare_rock"]

	if chosen == ids["glacier"]:
		return soil_ids["glacial_ice"]

	if chosen == ids["snowfield"]:
		return soil_ids["snow"]

	if chosen == ids["beach"] or chosen == ids["mangrove"]:
		return soil_ids["beach_sand"] if chosen == ids["beach"] else soil_ids["silt"]

	if chosen == ids["marsh"]:
		return soil_ids["peat"]

	if chosen == ids["tundra"]:
		return soil_ids["stony_soil"] if slope > stony_tan else soil_ids["gravel"]

	if slope > scree_tan:
		return soil_ids["stony_soil"]

	if fresh_distance < float(rules["floodplain_distance_m"]) and slope < flood_tan:
		return soil_ids["alluvium"]

	if chosen == ids["hot_desert"] or (wet < float(rules["sand_moisture"]) and h < 40.0):
		return soil_ids["sand"]

	if slope > stony_tan:
		return soil_ids["stony_soil"]

	if wet >= float(rules["clay_moisture"]) and slope < flood_tan and fresh_distance < float(rules.get("clay_edge_m", 160.0)):
		return soil_ids["clay"]

	if chosen == ids["temperate_forest"] or chosen == ids["mixed_forest"] or chosen == ids["boreal_forest"] \
			or chosen == ids["tropical_forest"] or chosen == ids["heath"]:
		return soil_ids["forest_humus"]

	return soil_ids["loam"]


# Wet air per coarse cell, swept along the prevailing wind (an average of
# both directions where the wind is calm).
func _wet_air(coarse_height: PackedFloat32Array, coarse: int, cell_m: float, tile_row: int) -> PackedFloat32Array:
	var rules: Dictionary = _rules["air"]
	var direction: int = int(_rules["wind_toward_x"][_settings.get_zone_group_for_row(tile_row)])
	var forward: PackedFloat32Array = _sweep(coarse_height, coarse, cell_m, 1, rules) if direction >= 0 else PackedFloat32Array()
	var backward: PackedFloat32Array = _sweep(coarse_height, coarse, cell_m, -1, rules) if direction <= 0 else PackedFloat32Array()

	if direction > 0:
		return forward

	if direction < 0:
		return backward

	var mixed: PackedFloat32Array = forward.duplicate()

	for index in range(mixed.size()):
		mixed[index] = 0.5 * (forward[index] + backward[index])

	return mixed


func _sweep(coarse_height: PackedFloat32Array, coarse: int, cell_m: float, direction: int, rules: Dictionary) -> PackedFloat32Array:
	var air: PackedFloat32Array = PackedFloat32Array()
	air.resize(coarse * coarse)
	var km: float = cell_m / 1000.0
	var land_loss: float = float(rules["land_loss_per_km"]) * km
	var rise_loss: float = float(rules["rise_loss_per_100m"]) / 100.0
	var minimum: float = float(rules["minimum"])
	var recharge: float = float(rules["sea_recharge_per_km"]) * km

	for row in range(coarse):
		var current: float = 0.6
		var previous_height: float = coarse_height[row * coarse + (0 if direction > 0 else coarse - 1)]

		for k in range(coarse):
			var column: int = k if direction > 0 else coarse - 1 - k
			var index: int = row * coarse + column
			var h: float = coarse_height[index]

			if h <= 0.0:
				current = minf(1.0, current + recharge)
			else:
				current = maxf(current - land_loss - rise_loss * maxf(h - previous_height, 0.0), minimum)

			previous_height = h
			air[index] = current

	return air


# Two-pass chamfer distance (meters) from marked coarse cells.
func _chamfer(mask: PackedByteArray, size: int, cell_m: float) -> PackedFloat32Array:
	var distance: PackedFloat32Array = PackedFloat32Array()
	distance.resize(size * size)
	var diagonal: float = cell_m * 1.4142

	for index in range(size * size):
		distance[index] = 0.0 if mask[index] == 1 else 1.0e9

	for row in range(size):
		for column in range(size):
			var index: int = row * size + column
			var best: float = distance[index]

			if column > 0:
				best = minf(best, distance[index - 1] + cell_m)
			if row > 0:
				best = minf(best, distance[index - size] + cell_m)
				if column > 0:
					best = minf(best, distance[index - size - 1] + diagonal)
				if column < size - 1:
					best = minf(best, distance[index - size + 1] + diagonal)

			distance[index] = best

	for row in range(size - 1, -1, -1):
		for column in range(size - 1, -1, -1):
			var index: int = row * size + column
			var best: float = distance[index]

			if column < size - 1:
				best = minf(best, distance[index + 1] + cell_m)
			if row < size - 1:
				best = minf(best, distance[index + size] + cell_m)
				if column < size - 1:
					best = minf(best, distance[index + size + 1] + diagonal)
				if column > 0:
					best = minf(best, distance[index + size - 1] + diagonal)

			distance[index] = best

	return distance


# World-aligned noise (one byte per sample, 127.5 = zero).
func _noise(purpose: String, wavelength_m: float) -> PackedByteArray:
	var noise: FastNoiseLite = FastNoiseLite.new()
	noise.seed = SeedUtil.purpose_seed(_settings.master_seed, purpose)
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	noise.frequency = spacing_m / wavelength_m
	var tile_samples_w: int = int(_settings.tile_size_m / _settings.map_spacing_m)
	return WrapNoiseScript.bytes(
		noise, _origin_sx, _origin_sz, samples, samples, _settings.min_tile * tile_samples_w, _settings.min_tile * tile_samples_w,
		_settings.tiles_x * tile_samples_w, _settings.tiles_z * tile_samples_w, int(ceil(4.0 * wavelength_m / spacing_m))
	)


# The tile row a position lies in, wrapped into the world's rows.
func tile_row_of(z_m: float) -> int:
	var row: int = int(floor(z_m / float(_settings.tile_size_m)))
	return posmod(row - _settings.min_tile, _settings.tiles_z) + _settings.min_tile


# Wet air for this frame's coarse grid, read from the world field.
func _world_air_grid(coarse: int, step: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(coarse * coarse)
	var values: PackedFloat32Array = _air_field["values"]
	var size_x: int = int(_air_field["size_x"])
	var size_z: int = int(_air_field["size_z"])
	var cell: float = float(_air_field["cell_m"])
	var origin_x: float = float(_air_field["origin_x"])
	var origin_z: float = float(_air_field["origin_z"])

	for row in range(coarse):
		var v: float = (float(_origin_sz + row * step) * spacing_m - origin_z) / cell - 0.5
		var r0: int = int(floor(v))
		var tv: float = v - float(r0)
		var rb: int = posmod(r0, size_z) * size_x
		var rc: int = posmod(r0 + 1, size_z) * size_x

		for column in range(coarse):
			var u: float = (float(_origin_sx + column * step) * spacing_m - origin_x) / cell - 0.5
			var c0: int = int(floor(u))
			var tu: float = u - float(c0)
			var c_a: int = posmod(c0, size_x)
			var c_b: int = posmod(c0 + 1, size_x)
			out[row * coarse + column] = lerpf(lerpf(values[rb + c_a], values[rb + c_b], tu), lerpf(values[rc + c_a], values[rc + c_b], tu), tv)

	return out


# The wet-air field for the whole world, on the world elevation grid. Each
# row is swept along its wind (an average of both directions where the wind
# is calm), twice around the wrapped world so it settles.
static func build_world_air(settings, rules: Dictionary, elevation) -> Dictionary:
	var climate_rules: Dictionary = rules["climate"]
	var air_rules: Dictionary = climate_rules["air"]
	var size_x: int = elevation.size_x
	var size_z: int = elevation.size_z
	var values: PackedFloat32Array = PackedFloat32Array()
	values.resize(size_x * size_z)
	var km: float = elevation.cell_m / 1000.0
	var land_loss: float = float(air_rules["land_loss_per_km"]) * km
	var rise_loss: float = float(air_rules["rise_loss_per_100m"]) / 100.0
	var minimum: float = float(air_rules["minimum"])
	var recharge: float = float(air_rules["sea_recharge_per_km"]) * km

	for row in range(size_z):
		var z_m: float = elevation.origin_z + (float(row) + 0.5) * elevation.cell_m
		var tile_row: int = posmod(int(floor(z_m / float(settings.tile_size_m))) - settings.min_tile, settings.tiles_z) + settings.min_tile
		var direction: int = int(climate_rules["wind_toward_x"][settings.get_zone_group_for_row(tile_row)])
		var passes: Array = []

		if direction >= 0:
			passes.append(1)

		if direction <= 0:
			passes.append(-1)

		for sweep_direction in passes:
			var current: float = 0.6
			var previous_height: float = elevation.heights[row * size_x]

			for k in range(2 * size_x):
				var column: int = k % size_x if sweep_direction > 0 else size_x - 1 - (k % size_x)
				var index: int = row * size_x + column
				var h: float = elevation.heights[index]

				if h <= 0.0:
					current = minf(1.0, current + recharge)
				else:
					current = maxf(current - land_loss - rise_loss * maxf(h - previous_height, 0.0), minimum)

				previous_height = h

				if k >= size_x:
					values[index] += current / float(passes.size())

	return {
		"values": values, "size_x": size_x, "size_z": size_z, "cell_m": elevation.cell_m,
		"origin_x": elevation.origin_x, "origin_z": elevation.origin_z,
	}
