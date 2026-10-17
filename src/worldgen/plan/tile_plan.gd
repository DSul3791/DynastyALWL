class_name TilePlan
extends RefCounted

# Builds the tile plan from the world sketch and its elevation map.
# Every tile gets a record of what the sketch put there: how much land,
# the highest and deepest points, which sketch features reach into it,
# geology hints, danger and the starter marking. Islands are listed
# once, world wide, and each tile points at the islands that touch it.
#
# The plan is derived data. Change the sketch and rebuild; tiles that
# are locked or already baked are kept as they were.

const TileMatrixScript := preload("res://src/worldgen/matrix/tile_matrix.gd")
const CensusScript := preload("res://src/worldgen/sketch/island_census.gd")
const ElevationScript := preload("res://src/worldgen/sketch/world_elevation.gd")

const PLAN_VERSION := 1
# A feature counts as present in a tile once it holds this much land.
const MIN_FEATURE_LAND_KM2 := 0.25
# Land below this share of a tile is just "a few islets" for the kind label.
const SHALLOW_M := -200.0

var _settings
var _sketch: Dictionary = {}
var _elevation

# After build(): the world wide island list (sorted largest first).
var islands: Array = []


func setup(settings, sketch: Dictionary, elevation) -> void:
	_settings = settings
	_sketch = sketch
	_elevation = elevation


func build(existing = null):
	var matrix = TileMatrixScript.new()
	matrix.meta = {
		"source": "sketch",
		"plan_version": PLAN_VERSION,
		"master_seed": _settings.master_seed,
		"world": _settings.world_name,
	}

	var census: Dictionary = CensusScript.count(_elevation)
	_number_islands(census)
	var stats: Dictionary = _tile_stats(census)

	for tile in _settings.get_all_tiles():
		var frozen: Dictionary = {}

		if existing != null:
			frozen = existing.get_cell(tile.x, tile.y)

		if TileMatrixScript.is_frozen(frozen):
			matrix.set_cell(frozen)
		else:
			matrix.set_cell(_make_cell(tile, stats.get(tile, {})))

	return matrix


# Island numbers follow size: 1 is the biggest. Ties keep scan order.
func _number_islands(census: Dictionary) -> void:
	var raw: Array = census["islands"]
	var order: Array = []

	for index in range(raw.size()):
		order.append(index)

	order.sort_custom(func(a: int, b: int) -> bool:
		var area_a: float = float(raw[a]["cells"])
		var area_b: float = float(raw[b]["cells"])

		if area_a != area_b:
			return area_a > area_b

		return a < b
	)

	_number_of_raw = PackedInt32Array()
	_number_of_raw.resize(raw.size())
	islands = []

	for rank in range(order.size()):
		var item: Dictionary = raw[order[rank]]
		_number_of_raw[order[rank]] = rank + 1
		var peak_position: Vector2 = _elevation.cell_center_m(
			int(item["peak_index"]) % _elevation.size_x,
			int(item["peak_index"]) / _elevation.size_x
		)
		var tile: Vector2i = _tile_of(peak_position)
		var owner: int = int(item["owner"])

		islands.append({
			"id": rank + 1,
			"area_km2": snappedf(float(item["area_km2"]), 0.01),
			"size_class": CensusScript.size_class(float(item["area_km2"])),
			"peak_m": int(round(float(item["peak_m"]))),
			"peak_x_m": int(round(peak_position.x)),
			"peak_z_m": int(round(peak_position.y)),
			"peak_tile": [tile.x, tile.y],
			"feature": _elevation.feature_ids[owner] if owner >= 0 else "",
			"tiles": [],
		})


var _number_of_raw: PackedInt32Array = PackedInt32Array()


func _tile_of(position_m: Vector2) -> Vector2i:
	var tile: float = float(_settings.tile_size_m)
	return Vector2i(int(floor(position_m.x / tile)), int(floor(position_m.y / tile)))


# One pass over the elevation map, adding up each tile's numbers.
func _tile_stats(census: Dictionary) -> Dictionary:
	var label: PackedInt32Array = census["label"]
	var tile_cells: int = int(round(float(_settings.tile_size_m) / _elevation.cell_m))
	var cell_km2: float = pow(_elevation.cell_m / 1000.0, 2.0)
	var stats: Dictionary = {}

	for row in range(_elevation.size_z):
		for column in range(_elevation.size_x):
			var tile: Vector2i = Vector2i(
				column / tile_cells + _settings.min_tile,
				row / tile_cells + _settings.min_tile
			)
			var index: int = row * _elevation.size_x + column

			if not stats.has(tile):
				stats[tile] = {
					"land_cells": 0, "peak": -INF, "deepest": INF,
					"shallow_cells": 0, "owners": {}, "islands": {}, "special": {},
				}

			var entry: Dictionary = stats[tile]
			var h: float = _elevation.heights[index]
			entry["peak"] = maxf(entry["peak"], h)
			entry["deepest"] = minf(entry["deepest"], h)

			if h > SHALLOW_M and h <= 0.0:
				entry["shallow_cells"] += 1

			if h <= 0.0:
				continue

			entry["land_cells"] += 1
			var owner: int = _elevation.owners[index]

			if owner >= 0:
				entry["owners"][owner] = int(entry["owners"].get(owner, 0)) + 1

			var number: int = _number_of_raw[label[index]]
			entry["islands"][number] = int(entry["islands"].get(number, 0)) + 1
			var special: int = _elevation.special[index]

			if special != ElevationScript.SPECIAL_NONE:
				entry["special"][special] = int(entry["special"].get(special, 0)) + 1

	# Remember which tiles each island touches.
	for tile in stats.keys():
		for number in stats[tile]["islands"].keys():
			islands[int(number) - 1]["tiles"].append([tile.x, tile.y])

	for island in islands:
		island["tiles"].sort_custom(func(a: Array, b: Array) -> bool:
			return a[1] < b[1] or (a[1] == b[1] and a[0] < b[0])
		)

	return stats


func _make_cell(tile: Vector2i, entry: Dictionary) -> Dictionary:
	var cell_km2: float = pow(_elevation.cell_m / 1000.0, 2.0)
	var land_km2: float = float(entry.get("land_cells", 0)) * cell_km2
	var tile_km2: float = pow(float(_settings.tile_size_m) / 1000.0, 2.0)
	var danger: float = _settings.danger_at_tile(tile.x, tile.y)
	var starter_set: String = _settings.get_starter_set_of(tile)
	var features: Array = []
	var geology: Array = []
	var island_ids: Array = []

	var owners: Dictionary = entry.get("owners", {})
	var owner_keys: Array = owners.keys()
	owner_keys.sort()

	for owner in owner_keys:
		if float(owners[owner]) * cell_km2 < MIN_FEATURE_LAND_KM2:
			continue

		var feature_id: String = str(_elevation.feature_ids[owner])
		features.append(feature_id)

		for hint in _geology_of(feature_id):
			if not geology.has(hint):
				geology.append(hint)

	var island_counts: Dictionary = entry.get("islands", {})
	var number_keys: Array = island_counts.keys()
	number_keys.sort()

	for number in number_keys:
		island_ids.append(int(number))

	var special_names: Array = []
	var special: Dictionary = entry.get("special", {})
	var special_keys: Array = special.keys()
	special_keys.sort()

	for code in special_keys:
		special_names.append(_special_name(int(code)))

	var in_trench: bool = false
	var landmark: bool = false

	for world_feature in _settings.world_features:
		if not _settings.is_tile_in_feature(world_feature, tile.x, tile.y):
			continue

		var kind: String = str(world_feature.get("kind", ""))
		in_trench = in_trench or kind == "abyssal_trench"
		landmark = landmark or kind == "landmark_island"

		if not features.has(str(world_feature["id"])):
			features.append(str(world_feature["id"]))

	var kind_name: String = "ocean"

	if starter_set != "":
		kind_name = "starter"
	elif landmark and land_km2 > 0.0:
		kind_name = "landmark"
	elif land_km2 > 0.0:
		kind_name = "islands"
	elif in_trench:
		kind_name = "trench"
	elif float(entry.get("shallow_cells", 0)) > 0.0:
		kind_name = "shallows"

	var needs_tile_file: bool = land_km2 > 0.0 or starter_set != ""

	return {
		"x": tile.x,
		"z": tile.y,
		"zone": _settings.get_zone_id_for_row(tile.y),
		"kind": kind_name,
		"status": "planned" if needs_tile_file else "placeholder",
		"locked": false,
		"revision": 0,
		"starter_set": starter_set,
		"danger": snappedf(danger, 0.001),
		"danger_tier": _settings.danger_tier(danger),
		"land_km2": snappedf(land_km2, 0.01),
		"land_share": snappedf(land_km2 / tile_km2, 0.0001),
		"peak_m": int(round(float(entry.get("peak", -2000.0)))),
		"deepest_m": int(round(float(entry.get("deepest", -2000.0)))),
		"features": features,
		"island_ids": island_ids,
		"geology_hints": geology,
		"special": special_names,
		"notes": "",
	}


func _geology_of(feature_id: String) -> Array:
	for feature in _sketch.get("features", []):
		if str(feature["id"]) != feature_id:
			continue

		if feature.has("geology"):
			return feature["geology"]

		if str(feature["kind"]) == "landmark_island":
			return ["volcanic"]

	return []


static func _special_name(code: int) -> String:
	match code:
		ElevationScript.SPECIAL_LAVA:
			return "lava"
		ElevationScript.SPECIAL_SWAMP:
			return "swamp"
		ElevationScript.SPECIAL_SALT:
			return "salt_flat"
		ElevationScript.SPECIAL_SCORCHED:
			return "scorched"
		ElevationScript.SPECIAL_RUINS:
			return "ruins"
		ElevationScript.SPECIAL_ROAD:
			return "road"

	return "unknown"


# The world wide island list as JSON text.
func islands_json() -> String:
	return JSON.stringify({
		"format_version": 1,
		"note": "Islands found in the sketch elevation map, largest first. Derived data; rebuilt by tools/build_tile_plan.gd.",
		"islands": islands,
	}, "  ", false) + "\n"
