class_name TileLandTypes
extends RefCounted

# Land-type pass over the climate biome map (design: /mnt/project-files/tech/LAND_TYPE_PLAN_Sonny.md, Dave 25 Oct 2026: trees stood
# in the coastal lakes because the map did not know where the water is, and the evergreen belt did not exist). Runs on the
# build frame after TileClimate.build, so tile edges agree. Rules (tile_rules.json "land_types"):
#   1. shore: land within shore_cells of a painted lake or river (low lakes, surface under low_lake_m: wet_flat_cells) becomes marsh
#      (reeds and wet meadow, no trees), unless steeper than shore_max_slope_deg.
#   2. treeline: forest and grassland above treeline_m become alpine_meadow (bare rock stays); steeper than rock_slope_deg is rock.
#   3. evergreen belt: ground steeper than belt_slope (tangent) and between belt_min_m and treeline_m that is forest or grassland
#      becomes mixed_forest up to boreal_from_m, boreal_forest above. Valley and farmland keep what the climate gave.

static func apply(biome: PackedByteArray, heights: PackedFloat32Array, water_class: PackedByteArray, water_surface: PackedFloat32Array, side: int, spacing_m: float, rules: Dictionary, ids: Dictionary) -> Dictionary:
	var counts: Dictionary = {"marsh": 0, "alpine": 0, "belt": 0, "boreal": 0}

	if rules.is_empty() or not bool(rules.get("enabled", true)):
		return counts

	var marsh_id: int = ids["marsh"]
	var alpine_id: int = ids["alpine_meadow"]
	var rock_id: int = ids["bare_rock"]
	var mixed_id: int = ids["mixed_forest"]
	var boreal_id: int = ids["boreal_forest"]
	var open_ids: Dictionary = {}

	for name in ["temperate_grassland", "temperate_forest", "mixed_forest", "heath", "boreal_forest", "alpine_meadow"]:
		open_ids[int(ids[name])] = true

	var shore_cells: int = int(rules.get("shore_cells", 3))
	var wet_flat_cells: int = int(rules.get("wet_flat_cells", 12))
	var low_lake_m: float = float(rules.get("low_lake_m", 4.0))
	var shore_max_tan: float = tan(deg_to_rad(float(rules.get("shore_max_slope_deg", 15.0))))
	var treeline_m: float = float(rules.get("treeline_m", 620.0))
	var belt_min_m: float = float(rules.get("belt_min_m", 250.0))
	var boreal_from_m: float = float(rules.get("boreal_from_m", 400.0))
	var belt_tan: float = float(rules.get("belt_slope", 0.2))
	var rock_tan: float = tan(deg_to_rad(float(rules.get("rock_slope_deg", 38.0))))
	var inv_two: float = 1.0 / (2.0 * spacing_m)
	var shore: PackedByteArray = PackedByteArray()
	shore.resize(side * side)

	# 1. Mark the shore: from every painted lake or river cell, a square of shore_cells (wet_flat_cells round a low lake).
	for j in range(side):
		for i in range(side):
			var index: int = j * side + i
			var kind: int = water_class[index]

			if kind < 2:
				continue

			var reach: int = shore_cells

			if kind == 2 and not is_nan(water_surface[index]) and water_surface[index] < low_lake_m:
				reach = wet_flat_cells

			for dj in range(maxi(j - reach, 0), mini(j + reach + 1, side)):
				var row: int = dj * side

				for di in range(maxi(i - reach, 0), mini(i + reach + 1, side)):
					shore[row + di] = 1

	for j in range(side):
		for i in range(side):
			var index: int = j * side + i
			var current: int = biome[index]

			if water_class[index] != 0 or (not open_ids.has(current) and current != rock_id):
				continue

			var h: float = heights[index]
			var gx: float = (heights[index + (1 if i < side - 1 else 0)] - heights[index - (1 if i > 0 else 0)]) * inv_two
			var gz: float = (heights[index + (side if j < side - 1 else 0)] - heights[index - (side if j > 0 else 0)]) * inv_two
			var slope: float = sqrt(gx * gx + gz * gz)

			if shore[index] == 1 and slope <= shore_max_tan and current != rock_id:
				biome[index] = marsh_id
				counts["marsh"] += 1
				continue

			if current == rock_id:
				continue

			if slope > rock_tan:
				biome[index] = rock_id
				continue

			if h > treeline_m:
				if current != alpine_id:
					biome[index] = alpine_id
					counts["alpine"] += 1

				continue

			if slope >= belt_tan and h >= belt_min_m:
				var belt_id: int = boreal_id if h >= boreal_from_m else mixed_id

				if current != belt_id:
					biome[index] = belt_id
					counts["boreal" if belt_id == boreal_id else "belt"] += 1

	return counts


# Valley farmland (Dave 24 Oct: the valley up to where the evergreen belt ends, anywhere the player can walk): fertile, walkable,
# low forest ground becomes temperate_grassland in field-sized patches (value noise over WORLD position, so tiles agree), and a
# hedge strip, one coarse cell wide, of the old forest is left between fields. Hardwoods then stand in the woodlots and hedges.
# Rules: tile_rules.json "land_types": field_m (patch size), field_threshold, farm_fertility_min, farm_min_m, farm_slope.
static func farmland(biome: PackedByteArray, fertility: PackedByteArray, heights: PackedFloat32Array, water_class: PackedByteArray, side: int, spacing_m: float, origin_sx: int, origin_sz: int, rules: Dictionary, ids: Dictionary) -> int:
	if rules.is_empty() or not bool(rules.get("enabled", true)) or not bool(rules.get("farmland", true)):
		return 0

	var forest_id: int = ids["temperate_forest"]
	var grass_id: int = ids["temperate_grassland"]
	var field_m: float = float(rules.get("field_m", 240.0))
	var threshold: float = float(rules.get("field_threshold", 0.5))
	var fertility_min: int = int(rules.get("farm_fertility_min", 90))
	var farm_min_m: float = float(rules.get("farm_min_m", 10.0))
	var farm_tan: float = float(rules.get("farm_slope", 0.3))
	var field_seed: int = int(rules.get("field_seed", 7919))
	# The noise is read on a grid two WORLD samples (16 m) apart, aligned to the world not the frame, so two tiles agree; that
	# grid's cell is the hedge width.
	var base_x: int = origin_sx >> 1
	var base_z: int = origin_sz >> 1
	var coarse: int = (side >> 1) + 2
	var noise: PackedFloat32Array = PackedFloat32Array()
	noise.resize(coarse * coarse)

	for cj in range(coarse):
		var z: float = float((base_z + cj) * 2) * spacing_m / field_m

		for ci in range(coarse):
			noise[cj * coarse + ci] = _value_noise(float((base_x + ci) * 2) * spacing_m / field_m, z, field_seed)

	var inv_two: float = 1.0 / (2.0 * spacing_m)
	var changed: int = 0

	for j in range(side):
		var cj: int = ((origin_sz + j) >> 1) - base_z

		for i in range(side):
			var index: int = j * side + i

			if biome[index] != forest_id or water_class[index] != 0 or heights[index] < farm_min_m or fertility[index] < fertility_min:
				continue

			var ci: int = ((origin_sx + i) >> 1) - base_x
			var here: float = noise[cj * coarse + ci]

			if here < threshold:
				continue

			# Hedge: a coarse cell beside a non-field cell stays woodland.
			if noise[cj * coarse + ci + 1] < threshold or noise[cj * coarse + maxi(ci - 1, 0)] < threshold \
					or noise[(cj + 1) * coarse + ci] < threshold or noise[maxi(cj - 1, 0) * coarse + ci] < threshold:
				continue

			var gx: float = (heights[index + (1 if i < side - 1 else 0)] - heights[index - (1 if i > 0 else 0)]) * inv_two
			var gz: float = (heights[index + (side if j < side - 1 else 0)] - heights[index - (side if j > 0 else 0)]) * inv_two

			if sqrt(gx * gx + gz * gz) > farm_tan:
				continue

			biome[index] = grass_id
			changed += 1

	return changed


# Smooth value noise in 0..1 at lattice coordinates (x, z).
static func _value_noise(x: float, z: float, noise_seed: int) -> float:
	var ix: int = int(floor(x))
	var iz: int = int(floor(z))
	var fx: float = x - float(ix)
	var fz: float = z - float(iz)
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a: float = _lattice(ix, iz, noise_seed)
	var b: float = _lattice(ix + 1, iz, noise_seed)
	var c: float = _lattice(ix, iz + 1, noise_seed)
	var d: float = _lattice(ix + 1, iz + 1, noise_seed)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


static func _lattice(ix: int, iz: int, noise_seed: int) -> float:
	var h: int = (ix * 73856093) ^ (iz * 19349663) ^ (noise_seed * 83492791)
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0
