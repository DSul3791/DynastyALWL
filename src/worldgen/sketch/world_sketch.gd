class_name WorldSketch
extends RefCounted

# The world sketch: the large undersea features that islands grow from.
#
#   continental shelves  shallow platforms around each pair of starters,
#                        with big town-friendly islands and hilly isles
#   trench arc           a curved volcanic chain along the central trench
#   island arcs          curved volcanic chains in dangerous waters
#   hotspot tracks       a big young volcano, older smaller islands, then
#                        atolls in warm water or seamounts in cold water
#   mid-ocean ridge      an undersea range along the east-west edge
#   seamount field       scattered undersea peaks and the odd islet
#
# The fixed central trench and center island come from world.json.
# Each feature is a list of "mounts" (volcanoes, seamounts, atolls,
# islands) plus, for shelves and ridges, their outline or path. All
# positions are world meters. The elevation map is built from this.
#
# Every choice uses a random stream seeded by the world seed and the
# feature, so the same world and rules give the same sketch. Features
# marked "locked" in a saved sketch are kept as they are.

const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")

const FORMAT_VERSION := 1
const SKETCH_VERSION := 1

var _settings
var _rules: Dictionary = {}
var _master: int = 0
var _tile: float = 15360.0
var _shelves: Array = []        # shelf features, for keep-clear checks
var _occupied: Array = []       # [Vector2 tiles] points used by chains
var _density_noise: FastNoiseLite


static func load_rules(path: String, errors: Array) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("Sketch rules not found: %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("Sketch rules are not valid JSON: %s" % path)
		return {}

	return parsed


func setup(settings, rules: Dictionary) -> void:
	_settings = settings
	_rules = rules
	_master = settings.master_seed
	_tile = float(settings.tile_size_m)
	_density_noise = FastNoiseLite.new()
	_density_noise.seed = SeedUtil.purpose_seed(_master, "sketch_density")
	_density_noise.frequency = 0.18
	_density_noise.fractal_octaves = 2


func generate(existing: Dictionary = {}) -> Dictionary:
	_shelves.clear()
	_occupied.clear()
	var features: Array = []

	features.append_array(_make_shelves())
	features.append(_make_trench_arc())
	features.append_array(_make_island_arcs())
	features.append_array(_make_hotspots())
	features.append(_make_ridge())
	features.append(_make_seamount_field())

	for fixed in _settings.world_features:
		features.append({
			"id": str(fixed["id"]),
			"kind": str(fixed["kind"]),
			"fixed": true,
			"locked": true,
			"note": "Defined in world.json.",
			"mounts": [],
		})

	# Keep features the owner locked in the saved sketch.
	var locked: Dictionary = {}

	for feature in existing.get("features", []):
		if bool(feature.get("locked", false)) and not bool(feature.get("fixed", false)):
			locked[str(feature["id"])] = feature

	for index in range(features.size()):
		var feature_id: String = str(features[index]["id"])

		if locked.has(feature_id):
			features[index] = locked[feature_id]

	return {
		"format_version": FORMAT_VERSION,
		"meta": {
			"sketch_version": SKETCH_VERSION,
			"seed_text": _settings.seed_text,
			"master_seed": _master,
			"rules_sha256": JSON.stringify(_rules, "", true).sha256_text(),
		},
		"features": features,
	}


# ==================================================
# CONTINENTAL SHELVES AND STARTER ISLANDS
# ==================================================

func _make_shelves() -> Array:
	var rules: Dictionary = _rules["shelves"]
	var starter_rules: Dictionary = _rules["starter_islands"]
	var groups: Dictionary = {}

	# Pair each inner starter with the outer starter in the same quadrant.
	for tile in _settings.get_all_starters():
		var key: String = "%d_%d" % [signi(tile.x), signi(tile.y)]

		if not groups.has(key):
			groups[key] = []

		groups[key].append(tile)

	var keys: Array = groups.keys()
	keys.sort()
	var features: Array = []

	for key in keys:
		var tiles: Array = groups[key]
		var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "sketch_shelf:%s" % key)
		var first: Vector2 = _tile_center(tiles[0])
		var last: Vector2 = _tile_center(tiles[tiles.size() - 1])
		var center: Vector2 = (first + last) * 0.5
		var along: Vector2 = last - first
		var length: float = along.length()
		var angle: float = atan2(along.y, along.x) if length > 0.01 else rng.randf() * PI

		var jitter: float = float(rules["center_jitter_tiles"])
		center += Vector2(rng.randf_range(-jitter, jitter), rng.randf_range(-jitter, jitter))
		angle += deg_to_rad(rng.randf_range(
			-float(rules["rotation_jitter_deg"]), float(rules["rotation_jitter_deg"])
		))
		var half_length: float = length * 0.5 + rng.randf_range(
			float(rules["extra_length_tiles"][0]), float(rules["extra_length_tiles"][1])
		)
		var half_width: float = rng.randf_range(
			float(rules["half_width_tiles"][0]), float(rules["half_width_tiles"][1])
		)

		var shelf: Dictionary = {
			"id": "shelf_%s" % key.replace("-1", "n").replace("1", "p"),
			"kind": "continental_shelf",
			"locked": false,
			"geology": rules["geology"].duplicate(),
			"shelf": {
				"center_m": _round_pair(_to_meters(center)),
				"half_length_m": int(round(half_length * _tile)),
				"half_width_m": int(round(half_width * _tile)),
				"rotation_deg": int(round(rad_to_deg(angle))),
				"depth_m": int(rules["shelf_depth_m"]),
				"edge_width": float(rules["edge_width"]),
				"hill_amplitude_m": int(rules["hill_amplitude_m"]),
				"hill_threshold": float(rules["hill_threshold"]),
			},
			"lobes": [],
			"mounts": [],
		}
		shelf["_center_tiles"] = center
		shelf["_half_length"] = half_length
		shelf["_half_width"] = half_width
		shelf["_angle"] = angle
		_shelves.append(shelf)

		# Extra lobes break up the outline so no two shelves look alike.
		var lobe_count: int = rng.randi_range(int(rules["lobes"][0]), int(rules["lobes"][1]))

		for lobe_index in range(lobe_count):
			var along_offset: float = rng.randf_range(-1.0, 1.0) * half_length * 0.8
			var side_offset: float = rng.randf_range(-1.0, 1.0) * half_width * 0.9
			var lobe_center: Vector2 = center + Vector2(along_offset, side_offset).rotated(angle)
			var size: float = rng.randf_range(float(rules["lobe_size"][0]), float(rules["lobe_size"][1]))
			var lobe_angle: float = angle + rng.randf_range(-1.2, 1.2)
			var lobe_length: float = half_length * size
			var lobe_width: float = half_width * size * rng.randf_range(0.8, 1.3)
			shelf["lobes"].append({
				"center_m": _round_pair(_to_meters(lobe_center)),
				"half_length_m": int(round(lobe_length * _tile)),
				"half_width_m": int(round(lobe_width * _tile)),
				"rotation_deg": int(round(rad_to_deg(lobe_angle))),
			})
			_shelves.append({
				"_center_tiles": lobe_center, "_half_length": lobe_length,
				"_half_width": lobe_width, "_angle": lobe_angle,
			})

		for tile in tiles:
			shelf["mounts"].append(_starter_island(rng, tile, starter_rules, angle))

		features.append(shelf)

	# The underscore keys were only for placement checks.
	var cleaned: Array = []

	for feature in features:
		var copy: Dictionary = feature.duplicate(true)

		for helper_key in ["_center_tiles", "_half_length", "_half_width", "_angle"]:
			copy.erase(helper_key)

		cleaned.append(copy)

	return cleaned


func _starter_island(
	rng: RandomNumberGenerator, tile: Vector2i, rules: Dictionary, shelf_angle: float
) -> Dictionary:
	# Area range per starter set (inner, outer), or one range for all.
	var area_range: Variant = rules["area_km2"]

	if typeof(area_range) == TYPE_DICTIONARY:
		area_range = area_range.get(_settings.get_starter_set_of(tile), area_range.values()[0])

	var area_m2: float = rng.randf_range(
		float(area_range[0]), float(area_range[1])
	) * 1000000.0
	var aspect: float = rng.randf_range(float(rules["aspect"][0]), float(rules["aspect"][1]))
	var ab: float = area_m2 / PI
	var offset: float = float(rules["max_offset_m"])
	var position: Vector2 = _to_meters(_tile_center(tile)) + Vector2(
		rng.randf_range(-offset, offset), rng.randf_range(-offset, offset)
	)

	# Beaches face the equator: south in the northern hemisphere (north
	# is -z), north in the southern hemisphere.
	var row: int = tile.y - _settings.equator_tile_row
	var toward_equator: Vector2 = Vector2(0.0, 1.0 if row < 0 else -1.0)
	var jitter: float = deg_to_rad(float(rules["beach_angle_jitter_deg"]))
	var beach_direction: Vector2 = toward_equator.rotated(rng.randf_range(-jitter, jitter))

	return {
		"type": "starter",
		"x": int(round(position.x)),
		"z": int(round(position.y)),
		"a": int(round(sqrt(ab * aspect))),
		"b": int(round(sqrt(ab / aspect))),
		"rot": int(round(rad_to_deg(shelf_angle) + rng.randf_range(-30.0, 30.0))),
		"peak": int(round(rng.randf_range(float(rules["peak_m"][0]), float(rules["peak_m"][1])))),
		"exp": float(rules["profile_exponent"]),
		"cliff": 0,
		"shore": int(rules["shore_shelf_m"]),
		"starter": [tile.x, tile.y],
		"beach_dir": [snappedf(beach_direction.x, 0.001), snappedf(beach_direction.y, 0.001)],
		"plain_m": int(rules["plain_height_m"]),
		"plain_width": float(rules["plain_width"]),
		"beach_exp": float(rules.get("beach_profile_exponent", 1.7)),
		"beach_cap_m": int(rules.get("beach_cap_m", 1100)),
		"rocky_cliff_m": int(rules["rocky_cliff_m"]),
		"bay_radius": float(rules["bay_radius"]),
		"bay_depth_m": int(rules["bay_depth_m"]),
		"strait_m": int(rules.get("strait_m", 0)),
		"strait_depth_m": int(rules.get("strait_depth_m", -30)),
	}


# ==================================================
# VOLCANIC CHAINS
# ==================================================

func _make_trench_arc() -> Dictionary:
	var rules: Dictionary = _rules["trench_arc"]
	var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "sketch_trench_arc")
	var trench: Dictionary = _find_world_feature("abyssal_trench")
	var center: Vector2 = Vector2.ZERO

	if not trench.is_empty():
		center = Vector2(float(trench["center_tile"][0]), float(trench["center_tile"][1]))

	var side: float = -1.0 if rng.randf() < 0.5 else 1.0
	var half_span: float = float(rules["half_span_tiles"])
	var bow: float = float(rules["bow_tiles_per_tile2"])
	var offset: float = float(rules["offset_tiles"])
	var mounts: Array = []
	var x: float = -half_span

	while x <= half_span:
		# Arcs bow toward the trench: the middle sits closest to it.
		var z: float = side * (offset + bow * x * x)
		var slope: float = side * 2.0 * bow * x
		var tangent_deg: float = rad_to_deg(atan2(slope, 1.0))
		var point: Vector2 = center + Vector2(x, z)
		var normal: Vector2 = Vector2(-slope, 1.0).normalized()
		point += normal * rng.randf_range(-0.03, 0.03)
		var is_island: bool = rng.randf() < float(rules["island_chance"])
		mounts.append(_volcano(rng, point, is_island, 1.0, tangent_deg))
		_occupied.append(point)
		x += rng.randf_range(float(rules["spacing_m"][0]), float(rules["spacing_m"][1])) / _tile

	return {
		"id": "trench_arc",
		"kind": "island_arc",
		"locked": false,
		"geology": ["volcanic", "granite"],
		"side": "north" if side < 0.0 else "south",
		"mounts": mounts,
	}


func _make_island_arcs() -> Array:
	var rules: Dictionary = _rules["island_arcs"]
	var features: Array = []

	for arc_index in range(int(rules["count"])):
		var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "sketch_arc", arc_index)

		for attempt in range(300):
			var radius: float = rng.randf_range(
				float(rules["radius_tiles"][0]), float(rules["radius_tiles"][1])
			)
			var length: float = rng.randf_range(
				float(rules["length_tiles"][0]), float(rules["length_tiles"][1])
			)
			var middle: Vector2 = _random_position(rng)
			var facing: float = rng.randf() * TAU
			var circle_center: Vector2 = middle - Vector2(cos(facing), sin(facing)) * radius
			var span: float = length / radius
			var points: Array = []
			var angle: float = facing - span * 0.5

			while angle <= facing + span * 0.5:
				points.append(circle_center + Vector2(cos(angle), sin(angle)) * radius)
				angle += rng.randf_range(
					float(rules["spacing_m"][0]), float(rules["spacing_m"][1])
				) / _tile / radius

			if not _chain_fits(points, float(rules["min_danger"])):
				continue

			var mounts: Array = []

			for point in points:
				var to_center: Vector2 = point - circle_center
				var tangent_deg: float = rad_to_deg(atan2(to_center.x, -to_center.y))
				var danger: float = _danger(point)
				var chance: float = lerpf(
					float(rules["island_chance"][0]), float(rules["island_chance"][1]), danger
				)
				mounts.append(_volcano(rng, point, rng.randf() < chance, 1.0, tangent_deg))

			_occupied.append_array(points)
			features.append({
				"id": "arc_%d" % (arc_index + 1),
				"kind": "island_arc",
				"locked": false,
				"geology": ["volcanic", "granite"],
				"mounts": mounts,
			})
			break

	return features


func _make_hotspots() -> Array:
	var rules: Dictionary = _rules["hotspots"]
	var volcano_rules: Dictionary = _rules["volcanoes"]
	var features: Array = []

	for track_index in range(int(rules["count"])):
		var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "sketch_hotspot", track_index)

		for attempt in range(300):
			var start: Vector2 = _random_position(rng)
			var direction: float = rng.randf() * TAU
			var length: float = rng.randf_range(
				float(rules["length_tiles"][0]), float(rules["length_tiles"][1])
			)
			var heading: Vector2 = Vector2(cos(direction), sin(direction))
			var points: Array = []
			var distance: float = 0.0

			while distance <= length:
				var bend: Vector2 = Vector2(-heading.y, heading.x) * sin(distance * 0.35) * 0.25
				points.append(start + heading * distance + bend)
				distance += rng.randf_range(
					float(rules["spacing_m"][0]), float(rules["spacing_m"][1])
				) / _tile

			if not _chain_fits(points, float(rules["min_danger"])):
				continue

			var mounts: Array = []
			var direction_deg: float = rad_to_deg(direction)

			for index in range(points.size()):
				var point: Vector2 = points[index]
				var age: float = float(index) / float(maxi(points.size() - 1, 1))
				var temperature: float = _settings.temperature_c(_to_meters(point).y)

				if age >= float(rules["atoll_after_age"]):
					if temperature >= float(rules["atoll_min_temperature_c"]):
						mounts.append(_atoll(rng, point, age))
					else:
						mounts.append(_volcano(rng, point, false, 1.0, direction_deg))

					continue

				# Young end: one big volcano, shrinking and wearing down with age.
				var youth: float = 1.0 - age / float(rules["atoll_after_age"])
				var mount: Dictionary = _volcano(rng, point, true, 1.0, direction_deg)
				var radius: float = lerpf(
					float(volcano_rules["coast_radius_m"][0]),
					rng.randf_range(
						float(rules["young_coast_radius_m"][0]),
						float(rules["young_coast_radius_m"][1])
					),
					youth * youth
				)
				var aspect: float = float(mount["a"]) / maxf(float(mount["b"]), 1.0)
				mount["a"] = int(round(radius * sqrt(aspect)))
				mount["b"] = int(round(radius / sqrt(aspect)))
				mount["peak"] = int(round(minf(lerpf(
					180.0,
					rng.randf_range(float(rules["young_peak_m"][0]), float(rules["young_peak_m"][1])),
					youth
				) * _danger_lerp("peak_scale", _danger(point)), float(volcano_rules["max_peak_m"]))))
				mounts.append(mount)

			_occupied.append_array(points)
			features.append({
				"id": "hotspot_%d" % (track_index + 1),
				"kind": "hotspot_track",
				"locked": false,
				"geology": ["volcanic"],
				"mounts": mounts,
			})
			break

	return features


# A volcano that is either an island or a seamount, scaled by danger.
func _volcano(
	rng: RandomNumberGenerator, point: Vector2, is_island: bool,
	size_scale: float, direction_deg: float
) -> Dictionary:
	var rules: Dictionary = _rules["volcanoes"]
	var danger: float = _danger(point)
	var position: Vector2 = _to_meters(point)
	var rot: int = int(round(direction_deg + rng.randf_range(-20.0, 20.0)))

	if not is_island:
		var base: float = rng.randf_range(
			float(rules["seamount_radius_m"][0]), float(rules["seamount_radius_m"][1])
		)
		var stretch: float = rng.randf_range(1.0, 1.5)
		return {
			"type": "seamount",
			"x": int(round(position.x)),
			"z": int(round(position.y)),
			"a": int(round(base * sqrt(stretch))),
			"b": int(round(base / sqrt(stretch))),
			"rot": rot,
			"peak": int(round(rng.randf_range(
				float(rules["seamount_peak_m"][0]), float(rules["seamount_peak_m"][1])
			))),
		}

	# Skewed toward small: most volcanoes are small, a few are big.
	var low: float = float(rules["coast_radius_m"][0])
	var high: float = float(rules["coast_radius_m"][1])
	var size_t: float = pow(rng.randf(), float(rules["size_power"]))
	var radius: float = lerpf(low, high, size_t) * size_scale
	var aspect: float = rng.randf_range(1.0, 1.9)
	var peak: float = lerpf(
		float(rules["peak_m"][0]), float(rules["peak_m"][1]), size_t
	) * rng.randf_range(0.8, 1.2) * _danger_lerp("peak_scale", danger)

	# Only the center island's volcano may reach the greatest heights.
	peak = minf(peak, float(rules["max_peak_m"]))

	return {
		"type": "island",
		"x": int(round(position.x)),
		"z": int(round(position.y)),
		"a": int(round(radius * sqrt(aspect))),
		"b": int(round(radius / sqrt(aspect))),
		"rot": rot,
		"peak": int(round(peak)),
		"exp": snappedf(_danger_lerp("profile_exponent", danger), 0.01),
		"cliff": int(round(_danger_lerp("cliff_m", danger) if danger > 0.35 else 0.0)),
		"shore": int(round(_danger_lerp("shore_shelf_m", danger))),
	}


func _atoll(rng: RandomNumberGenerator, point: Vector2, age: float) -> Dictionary:
	var position: Vector2 = _to_meters(point)
	var radius: float = rng.randf_range(1200.0, 3200.0) * lerpf(1.0, 0.7, age)
	var stretch: float = rng.randf_range(1.0, 1.6)
	return {
		"type": "atoll",
		"x": int(round(position.x)),
		"z": int(round(position.y)),
		"a": int(round(radius * sqrt(stretch))),
		"b": int(round(radius / sqrt(stretch))),
		"rot": int(round(rng.randf_range(0.0, 180.0))),
		"peak": 4,
		"ring_m": int(round(rng.randf_range(220.0, 420.0))),
	}


# ==================================================
# RIDGE AND SEAMOUNTS
# ==================================================

func _make_ridge() -> Dictionary:
	var rules: Dictionary = _rules["ridge"]
	var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "sketch_ridge")
	var height: float = float(_settings.tiles_z)
	var path: Dictionary = {
		"center_x_tiles": float(_settings.tiles_x) * 0.5,
		"wiggle_tiles": float(rules["wiggle_tiles"]),
		"waves": int(rules["waves"]),
		"phase": snappedf(rng.randf() * TAU, 0.0001),
		"height_tiles": height,
	}
	var points: Array = []
	var z: float = -height * 0.5

	# The ridge runs the full height of the world along the east-west
	# edge, so it crosses both poles and closes on itself across the wrap.
	while z < height * 0.5:
		points.append(_round_pair(_to_meters(Vector2(ridge_x_tiles(path, z), z))))
		z += 0.25

	var mounts: Array = []

	for index in range(int(rules["islands"])):
		var pick: Array = points[rng.randi() % points.size()]
		var point: Vector2 = _from_meters(Vector2(float(pick[0]), float(pick[1])))
		var mount: Dictionary = _volcano(rng, point, true, 1.6, 90.0)
		mounts.append(mount)

	return {
		"id": "ridge_1",
		"kind": "mid_ocean_ridge",
		"locked": false,
		"geology": ["volcanic"],
		"crest_m": int(rules["crest_m"]),
		"width_m": int(rules["width_m"]),
		"path": path,
		"points": points,
		"mounts": mounts,
	}


func _make_seamount_field() -> Dictionary:
	var rules: Dictionary = _rules["seamount_field"]
	var volcano_rules: Dictionary = _rules["volcanoes"]
	var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "sketch_seamounts")
	var trench: Dictionary = _find_world_feature("abyssal_trench")
	var mounts: Array = []
	var attempts: int = 0

	# Most seamounts gather in groups, like real volcanic island groups,
	# leaving wide empty seas between them.
	var cluster_centers: Array = []

	for cluster_index in range(int(rules["clusters"])):
		cluster_centers.append(_random_position(rng))

	var spread: float = float(rules["cluster_spread_tiles"])

	while mounts.size() < int(rules["count"]) and attempts < int(rules["count"]) * 20:
		attempts += 1
		var point: Vector2

		if rng.randf() < float(rules["clustered_share"]):
			var cluster: Vector2 = cluster_centers[rng.randi() % cluster_centers.size()]
			var distance: float = spread * sqrt(-2.0 * log(maxf(rng.randf(), 0.0001)))
			var angle: float = rng.randf() * TAU
			point = cluster + Vector2(cos(angle), sin(angle)) * distance
		else:
			point = _random_position(rng)
			var density: float = clampf(0.5 + _density_noise.get_noise_2d(point.x, point.y), 0.1, 1.0)

			if rng.randf() > density:
				continue

		if _in_any_shelf(point, 0.2):
			continue

		if not trench.is_empty() and _settings.feature_reach(trench, point) < 1.0:
			continue

		var danger: float = _danger(point)
		var islet_chance: float = lerpf(
			float(rules["islet_chance_at_danger_0"]),
			float(rules["islet_chance_at_danger_1"]),
			danger
		)

		if rng.randf() < islet_chance:
			var mount: Dictionary = _volcano(rng, point, true, 1.0, rng.randf() * 180.0)
			var radius: float = rng.randf_range(
				float(rules["islet_coast_radius_m"][0]), float(rules["islet_coast_radius_m"][1])
			)
			var aspect: float = float(mount["a"]) / maxf(float(mount["b"]), 1.0)
			mount["a"] = int(round(radius * sqrt(aspect)))
			mount["b"] = int(round(radius / sqrt(aspect)))
			mount["peak"] = int(round(rng.randf_range(
				float(rules["islet_peak_m"][0]), float(rules["islet_peak_m"][1])
			)))
			mounts.append(mount)
		else:
			mounts.append(_volcano(rng, point, false, 1.0, rng.randf() * 180.0))

	return {
		"id": "seamount_field",
		"kind": "seamount_field",
		"locked": false,
		"geology": ["volcanic"],
		"mounts": mounts,
	}


# Where the ridge crest runs, in tiles from the middle of tile (0,0), for
# a row measured the same way. Waves are whole numbers so the path closes
# on itself across the north-south wrap.
static func ridge_x_tiles(path: Dictionary, z_tiles: float) -> float:
	var height: float = float(path["height_tiles"])
	var waves: float = float(path["waves"])
	var phase: float = float(path["phase"])
	var wiggle: float = float(path["wiggle_tiles"])
	var x: float = float(path["center_x_tiles"]) + wiggle * sin(TAU * waves * z_tiles / height + phase)
	x += 0.25 * wiggle * sin(TAU * (waves * 2.0 + 1.0) * z_tiles / height + phase * 1.7)
	return x


# ==================================================
# PLACEMENT CHECKS
# ==================================================

# A chain fits when every point is dangerous enough, clear of shelves,
# the trench and the center island, and away from other chains.
func _chain_fits(points: Array, min_danger: float) -> bool:
	var keep: Dictionary = _rules["keep_clear"]
	var trench: Dictionary = _find_world_feature("abyssal_trench")

	for point in points:
		if _danger(point) < min_danger:
			return false

		if _in_any_shelf(point, float(keep["shelf_margin_tiles"])):
			return false

		if not trench.is_empty() and _settings.feature_reach(trench, point) < float(keep["trench_margin"]):
			return false

		for other in _occupied:
			if _settings.tile_distance(point, other) < 1.5:
				return false

	return true


func _in_any_shelf(point: Vector2, margin_tiles: float) -> bool:
	for shelf in _shelves:
		var center: Vector2 = shelf["_center_tiles"]
		var offset: Vector2 = point - center
		offset.x = fposmod(offset.x + float(_settings.tiles_x) * 0.5, float(_settings.tiles_x)) - float(_settings.tiles_x) * 0.5
		offset.y = fposmod(offset.y + float(_settings.tiles_z) * 0.5, float(_settings.tiles_z)) - float(_settings.tiles_z) * 0.5
		offset = offset.rotated(-float(shelf["_angle"]))
		var along: float = offset.x / (float(shelf["_half_length"]) + margin_tiles)
		var across: float = offset.y / (float(shelf["_half_width"]) + margin_tiles)

		if along * along + across * across <= 1.0:
			return true

	return false


# ==================================================
# COORDINATES
# ==================================================

# Positions here are in tiles measured from the middle of tile (0,0),
# the same frame the danger map uses.
func _tile_center(tile: Vector2i) -> Vector2:
	return Vector2(float(tile.x), float(tile.y - _settings.equator_tile_row))


func _random_position(rng: RandomNumberGenerator) -> Vector2:
	return Vector2(
		rng.randf_range(-float(_settings.tiles_x) * 0.5, float(_settings.tiles_x) * 0.5),
		rng.randf_range(-float(_settings.tiles_z) * 0.5, float(_settings.tiles_z) * 0.5)
	)


# World meters, wrapped into the world.
func _to_meters(point: Vector2) -> Vector2:
	var min_x: float = float(_settings.min_tile) * _tile
	var min_z: float = float(_settings.min_tile) * _tile
	var width: float = float(_settings.tiles_x) * _tile
	var depth: float = float(_settings.tiles_z) * _tile
	var x: float = (point.x + 0.5) * _tile
	var z: float = (point.y + float(_settings.equator_tile_row) + 0.5) * _tile
	return Vector2(
		min_x + fposmod(x - min_x, width),
		min_z + fposmod(z - min_z, depth)
	)


func _from_meters(position: Vector2) -> Vector2:
	return _settings.tiles_from_center(position.x, position.y)


func _danger(point: Vector2) -> float:
	var position: Vector2 = _to_meters(point)
	return _settings.danger_at(position.x, position.y)


func _danger_lerp(key: String, danger: float) -> float:
	var pair: Array = _rules["danger_effects"][key]
	return lerpf(float(pair[0]), float(pair[1]), danger)


func _find_world_feature(kind: String) -> Dictionary:
	for feature in _settings.world_features:
		if str(feature.get("kind", "")) == kind:
			return feature

	return {}


func _round_pair(position: Vector2) -> Array:
	return [int(round(position.x)), int(round(position.y))]
