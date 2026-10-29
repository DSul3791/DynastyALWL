class_name WorldSettings
extends RefCounted

# The world's permanent settings, loaded from world.json.
#
# Everything here is decided once, before any tile is kept. The
# climate function turns a position into a temperature and a zone, so
# every part of the generator and the server agrees on the climate.

const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")

const FORMAT_VERSION := 1

# Identity
var world_name: String = ""
var seed_text: String = ""
var master_seed: int = 0

# Geometry
var tile_size_m: int = 10240
var region_size_m: int = 1024
var map_spacing_m: int = 8
var min_tile: int = -10
var tiles_x: int = 21
var tiles_z: int = 21
var voxel_size_m: float = 1.0
var world_bottom_m: int = -4000
var world_top_m: int = 4000
var sea_level_m: int = 0

# Climate
var equator_tile_row: int = 0
var lapse_rate_c_per_km: float = 6.5
var temperature_points: Array = []   # [[abs_latitude, celsius], ...]
var zones: Array = []                # [{id, group, max_abs_row}, ...]

# Starter tiles: {"inner": [Vector2i], "outer": [Vector2i]}
var starter_tiles: Dictionary = {}

# Fixed world features placed by hand, such as the central trench.
var world_features: Array = []

# Danger map (runtime-tunable; the world sketch reads it once for terrain)
var danger: Dictionary = {}

# Runtime-tunable values (not baked into tiles)
var tunable: Dictionary = {}


# Returns null and fills errors when the file cannot be used.
static func load_from_file(path: String, errors: Array) -> WorldSettings:
	if not FileAccess.file_exists(path):
		errors.append("World settings file not found: %s" % path)
		return null

	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("World settings file is not valid JSON: %s" % path)
		return null

	var settings: WorldSettings = WorldSettings.new()
	settings._apply(parsed)

	var problems: Array = settings.validate()

	if not problems.is_empty():
		errors.append_array(problems)
		return null

	return settings


func _apply(data: Dictionary) -> void:
	world_name = str(data.get("name", ""))
	seed_text = str(data.get("seed_text", ""))

	var geometry: Dictionary = data.get("geometry", {})
	tile_size_m = int(geometry.get("tile_size_m", tile_size_m))
	region_size_m = int(geometry.get("region_size_m", region_size_m))
	map_spacing_m = int(geometry.get("map_spacing_m", map_spacing_m))
	min_tile = int(geometry.get("min_tile", min_tile))
	tiles_x = int(geometry.get("tiles_x", tiles_x))
	tiles_z = int(geometry.get("tiles_z", tiles_z))
	voxel_size_m = float(geometry.get("voxel_size_m", voxel_size_m))
	world_bottom_m = int(geometry.get("world_bottom_m", world_bottom_m))
	world_top_m = int(geometry.get("world_top_m", world_top_m))
	sea_level_m = int(geometry.get("sea_level_m", sea_level_m))

	var climate: Dictionary = data.get("climate", {})
	equator_tile_row = int(climate.get("equator_tile_row", 0))
	lapse_rate_c_per_km = float(climate.get("lapse_rate_c_per_km", 6.5))
	temperature_points = climate.get("temperature_by_abs_latitude", [])
	zones = climate.get("zones", [])

	starter_tiles = {}
	var starters: Dictionary = data.get("starter_tiles", {})

	for set_name in starters.keys():
		var list: Array = []

		for pair in starters[set_name]:
			list.append(Vector2i(int(pair[0]), int(pair[1])))

		starter_tiles[str(set_name)] = list

	world_features = data.get("world_features", [])
	danger = data.get("danger", {})
	tunable = data.get("tunable", {})
	master_seed = SeedUtil.master_seed(seed_text)


# Returns a list of problems. Empty means the settings are usable.
func validate() -> Array:
	var problems: Array = []

	if world_name.is_empty():
		problems.append("name is empty")

	if seed_text.is_empty():
		problems.append("seed_text is empty")

	if tile_size_m <= 0 or tile_size_m % region_size_m != 0:
		problems.append("tile_size_m must be a multiple of region_size_m")

	if map_spacing_m <= 0 or tile_size_m % map_spacing_m != 0:
		problems.append("tile_size_m must be a multiple of map_spacing_m")

	if tiles_x <= 0 or tiles_z <= 0:
		problems.append("the world needs at least one tile")

	if tiles_z % 2 == 0:
		problems.append(
			"tiles_z should be odd so the equator row is in the middle"
		)

	if world_bottom_m >= world_top_m:
		problems.append("world_bottom_m must be below world_top_m")

	if equator_tile_row < min_tile or equator_tile_row > get_max_tile_z():
		problems.append("equator_tile_row is outside the world")

	if temperature_points.size() < 2:
		problems.append("the climate needs at least two temperature points")
	else:
		var previous: float = -1.0

		for point in temperature_points:
			if point.size() != 2:
				problems.append("a temperature point must be [latitude, celsius]")
				break

			var latitude: float = float(point[0])

			if latitude <= previous:
				problems.append(
					"temperature points must have increasing latitudes"
				)
				break

			previous = latitude

		if float(temperature_points[0][0]) != 0.0:
			problems.append("the first temperature point must be latitude 0")

		if float(temperature_points[temperature_points.size() - 1][0]) != 1.0:
			problems.append("the last temperature point must be latitude 1")

	if zones.is_empty():
		problems.append("the climate needs zones")
	else:
		var previous_row: int = -1

		for zone in zones:
			var max_row: int = int(zone.get("max_abs_row", -1))

			if max_row <= previous_row:
				problems.append("zone rows must increase")
				break

			previous_row = max_row

		if previous_row < get_max_abs_row():
			problems.append("zones do not reach the outermost tile row")

	for curve_name in ["east_west_by_abs_column", "north_south_by_abs_row"]:
		var curve: Array = danger.get(curve_name, [])

		if curve.size() < 2:
			problems.append("danger needs a %s curve" % curve_name)

	if danger.get("tiers", []).is_empty():
		problems.append("danger needs tiers")

	for set_name in starter_tiles.keys():
		for tile in starter_tiles[set_name]:
			if not is_tile_in_world(tile.x, tile.y):
				problems.append(
					"starter tile %s is outside the world" % str(tile)
				)

	return problems


# ==================================================
# TILE COORDINATES
# ==================================================

func get_max_tile_x() -> int:
	return min_tile + tiles_x - 1


func get_max_tile_z() -> int:
	return min_tile + tiles_z - 1


func get_max_abs_row() -> int:
	return maxi(
		absi(min_tile - equator_tile_row),
		absi(get_max_tile_z() - equator_tile_row)
	)


func is_tile_in_world(tile_x: int, tile_z: int) -> bool:
	return (
		tile_x >= min_tile
		and tile_x <= get_max_tile_x()
		and tile_z >= min_tile
		and tile_z <= get_max_tile_z()
	)


func wrap_tile(tile_x: int, tile_z: int) -> Vector2i:
	return Vector2i(
		min_tile + posmod(tile_x - min_tile, tiles_x),
		min_tile + posmod(tile_z - min_tile, tiles_z)
	)


# Distance between two tile positions on the wrapped world, in tiles.
func tile_distance(a: Vector2, b: Vector2) -> float:
	var dx: float = absf(a.x - b.x)
	var dz: float = absf(a.y - b.y)
	dx = minf(dx, float(tiles_x) - dx)
	dz = minf(dz, float(tiles_z) - dz)
	return sqrt(dx * dx + dz * dz)


# Largest tile-coordinate difference (Chebyshev) on the wrapped world.
func tile_chebyshev(a: Vector2i, b: Vector2i) -> int:
	var dx: int = absi(a.x - b.x)
	var dz: int = absi(a.y - b.y)
	dx = mini(dx, tiles_x - dx)
	dz = mini(dz, tiles_z - dz)
	return maxi(dx, dz)


func get_all_tiles() -> Array:
	var tiles: Array = []

	for tile_z in range(min_tile, get_max_tile_z() + 1):
		for tile_x in range(min_tile, get_max_tile_x() + 1):
			tiles.append(Vector2i(tile_x, tile_z))

	return tiles


func tile_seed(tile_x: int, tile_z: int) -> int:
	return SeedUtil.tile_seed(master_seed, tile_x, tile_z)


func get_starter_set_of(tile: Vector2i) -> String:
	for set_name in starter_tiles.keys():
		if tile in starter_tiles[set_name]:
			return set_name

	return ""


func get_all_starters() -> Array:
	var all: Array = []

	for set_name in starter_tiles.keys():
		all.append_array(starter_tiles[set_name])

	return all


# ==================================================
# CLIMATE
# ==================================================

# The equator line runs through the middle of the equator row.
func get_equator_z_m() -> float:
	return (
		float(equator_tile_row) * float(tile_size_m)
		+ float(tile_size_m) * 0.5
	)


# Half the world's north-south span: the equator-to-pole distance.
func get_half_world_z_m() -> float:
	return float(tiles_z) * float(tile_size_m) * 0.5


# +1 at the north pole, 0 at the equator, -1 at the south pole.
# North is -z in world coordinates. Both poles are the wrap seam.
func latitude_for_z(z_m: float) -> float:
	var offset: float = z_m - get_equator_z_m()
	var half: float = get_half_world_z_m()

	# Wrap the offset into one world period centered on the equator.
	var period: float = half * 2.0
	offset = fposmod(offset + half, period) - half

	return -offset / half


# Sea-level annual mean temperature for a latitude.
func sea_level_temperature_c(latitude: float) -> float:
	return sample_curve(temperature_points, clampf(absf(latitude), 0.0, 1.0))


# Reads a curve of [x, value] control points, easing smoothly between
# them so there are no kinks. Outside the points it holds the end values.
static func sample_curve(points: Array, x: float) -> float:
	if x <= float(points[0][0]):
		return float(points[0][1])

	for index in range(1, points.size()):
		var upper_x: float = float(points[index][0])

		if x <= upper_x:
			var lower_x: float = float(points[index - 1][0])
			var span: float = maxf(upper_x - lower_x, 0.000001)
			var t: float = clampf((x - lower_x) / span, 0.0, 1.0)
			t = t * t * (3.0 - 2.0 * t)
			return lerpf(float(points[index - 1][1]), float(points[index][1]), t)

	return float(points[points.size() - 1][1])


# Annual mean temperature at a position and altitude above sea level.
func temperature_c(z_m: float, altitude_m: float = 0.0) -> float:
	var base: float = sea_level_temperature_c(latitude_for_z(z_m))
	return base - lapse_rate_c_per_km * altitude_m / 1000.0


func temperature_for_row_c(tile_z: int, altitude_m: float = 0.0) -> float:
	var center_z: float = (
		float(tile_z) * float(tile_size_m) + float(tile_size_m) * 0.5
	)
	return temperature_c(center_z, altitude_m)


func get_zone_for_row(tile_z: int) -> Dictionary:
	var abs_row: int = absi(tile_z - equator_tile_row)

	for zone in zones:
		if abs_row <= int(zone["max_abs_row"]):
			return zone

	return zones[zones.size() - 1]


func get_zone_id_for_row(tile_z: int) -> String:
	return str(get_zone_for_row(tile_z)["id"])


func get_zone_group_for_row(tile_z: int) -> String:
	return str(get_zone_for_row(tile_z)["group"])


func get_zone_ids() -> Array:
	var ids: Array = []

	for zone in zones:
		ids.append(str(zone["id"]))

	return ids


# ==================================================
# DANGER
# ==================================================

# Position in tiles relative to the middle of tile (0,0), wrapped so the
# result runs from minus half the world to plus half the world.
func tiles_from_center(x_m: float, z_m: float) -> Vector2:
	var tile: float = float(tile_size_m)
	var column: float = x_m / tile - 0.5
	var row: float = z_m / tile - 0.5 - float(equator_tile_row)
	var half_x: float = float(tiles_x) * 0.5
	var half_z: float = float(tiles_z) * 0.5
	column = fposmod(column + half_x, float(tiles_x)) - half_x
	row = fposmod(row + half_z, float(tiles_z)) - half_z
	return Vector2(column, row)


# Danger from 0 (easy) to 1 (deadly). Lowest around the inner starter
# tiles, rising toward the east-west edge, the equator row and the
# poles, and peaking inside dangerous world features such as the central
# trench. The parts combine so that any one of them alone can make a
# place dangerous.
func danger_at(x_m: float, z_m: float) -> float:
	var position: Vector2 = tiles_from_center(x_m, z_m)
	var east_west: float = sample_curve(
		danger["east_west_by_abs_column"], absf(position.x)
	)
	var north_south: float = sample_curve(
		danger["north_south_by_abs_row"], absf(position.y)
	)
	var safety: float = (1.0 - east_west) * (1.0 - north_south)

	for feature in world_features:
		if feature.has("danger_peak"):
			safety *= 1.0 - _feature_danger(feature, position)

	return clampf(1.0 - safety, 0.0, 1.0)


# 1 inside the feature's oblong, deepest at its center, easing to 0 over
# the falloff distance beyond its edge.
func _feature_danger(feature: Dictionary, position: Vector2) -> float:
	var reach: float = feature_reach(feature, position)
	var peak: float = float(feature["danger_peak"])

	if reach <= 1.0:
		return peak * (0.94 + 0.06 * (1.0 - reach))

	var half_width: float = float(feature["half_width_tiles"])
	var outside_tiles: float = (reach - 1.0) * half_width
	var t: float = clampf(
		1.0 - outside_tiles / float(feature["edge_falloff_tiles"]), 0.0, 1.0
	)
	return peak * 0.94 * t * t * (3.0 - 2.0 * t)


# How far a position is from a feature's center, measured so that its
# oblong outline is 1. Positions are in tiles from the middle of (0,0).
func feature_reach(feature: Dictionary, position: Vector2) -> float:
	var center_tile: Array = feature["center_tile"]
	var center: Vector2 = Vector2(float(center_tile[0]), float(center_tile[1]))
	var offset: Vector2 = position - center
	offset.x = fposmod(offset.x + float(tiles_x) * 0.5, float(tiles_x)) - float(tiles_x) * 0.5
	offset.y = fposmod(offset.y + float(tiles_z) * 0.5, float(tiles_z)) - float(tiles_z) * 0.5
	offset = offset.rotated(-deg_to_rad(float(feature.get("rotation_deg", 0.0))))
	var along: float = offset.x / float(feature["half_length_tiles"])
	var across: float = offset.y / float(feature["half_width_tiles"])
	return sqrt(along * along + across * across)


# True when the middle of a tile lies inside a feature's oblong.
func is_tile_in_feature(feature: Dictionary, tile_x: int, tile_z: int) -> bool:
	var position: Vector2 = Vector2(float(tile_x), float(tile_z) - float(equator_tile_row))
	return feature_reach(feature, position) <= 1.0


func danger_at_tile(tile_x: int, tile_z: int) -> float:
	var tile: float = float(tile_size_m)
	return danger_at((float(tile_x) + 0.5) * tile, (float(tile_z) + 0.5) * tile)


func danger_tier(value: float) -> String:
	for tier in danger.get("tiers", []):
		if value < float(tier[0]):
			return str(tier[1])

	return "deadly"
