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
