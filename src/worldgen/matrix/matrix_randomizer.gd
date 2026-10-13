class_name MatrixRandomizer
extends RefCounted

# Fills the tile matrix: for every tile, decides whether it is open ocean,
# holds several similar islands, or holds one large island with a chance
# of small islets off its coast. It also places the starter tiles, open
# seas, island chains and a fair spread of geology across the climate zones.
#
# Every random choice comes from a generator seeded by the world seed,
# the tile and the purpose, so the same world and rules always give the
# same matrix, and changing one tile never changes another.

const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")
const IslandShapeScript := preload("res://src/worldgen/matrix/island_shape.gd")
const TileMatrixScript := preload("res://src/worldgen/matrix/tile_matrix.gd")

const RANDOMIZER_VERSION := 1
const CLASS_ORDER := ["islet", "small", "medium", "large", "great"]
const GEOLOGY_HINTS := ["granite", "basin", "fold_belt", "volcanic"]

var _settings
var _rules: Dictionary = {}
var _master: int = 0
var _edge_limit: float = 4120.0
var _fill: float = 0.85
var _next_uid: int = 1


static func load_rules(path: String, errors: Array) -> Dictionary:
	if not FileAccess.file_exists(path):
		errors.append("Matrix rules not found: %s" % path)
		return {}

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("Matrix rules are not valid JSON: %s" % path)
		return {}

	return parsed


func setup(settings, rules: Dictionary) -> void:
	_settings = settings
	_rules = rules
	_master = settings.master_seed
	_fill = float(rules.get("island_fill_factor", 0.85))
	_edge_limit = (
		float(settings.tile_size_m) * 0.5
		- float(rules.get("island_edge_margin_m", 1000))
	)


# Builds the whole matrix. Cells that are locked, or already baked, are
# copied from the existing matrix and never changed.
func generate(existing = null):
	var matrix = TileMatrixScript.new()
	matrix.meta = {
		"randomizer_version": RANDOMIZER_VERSION,
		"seed_text": _settings.seed_text,
		"master_seed": _master,
		"rules_sha256": JSON.stringify(_rules, "", true).sha256_text(),
	}

	var frozen: Dictionary = {}

	if existing != null:
		for key in existing.cells.keys():
			if TileMatrixScript.is_frozen(existing.cells[key]):
				frozen[key] = existing.cells[key].duplicate(true)

	_pass_base(matrix, frozen)
	_pass_open_seas(matrix)
	_pass_chains(matrix)
	_pass_starter_neighborhoods(matrix)
	_pass_geology(matrix)
	_pass_neighborhood_geology(matrix)
	_pass_zone_coverage(matrix)
	_finish(matrix)

	return matrix


# ==================================================
# PASS 1: EVERY TILE
# ==================================================

func _pass_base(matrix, frozen: Dictionary) -> void:
	var starters: Array = _settings.get_all_starters()

	for tile in _settings.get_all_tiles():
		if frozen.has(tile):
			matrix.set_cell(frozen[tile])
			continue

		if tile in starters:
			matrix.set_cell(_make_starter_cell(tile))
			continue

		var rng: RandomNumberGenerator = SeedUtil.rng_for(
			_master, "matrix_base", tile.x, tile.y
		)
		var group: String = _settings.get_zone_group_for_row(tile.y)
		var layout: String = _pick(rng, _rules["tile_kind_odds"][group])
		var islands: Array = []

		match layout:
			"peers":
				islands = _generate_peers(rng, group, {})
			"main":
				islands = _generate_main(rng, group, {})

		if islands.is_empty():
			layout = "ocean"

		matrix.set_cell(_make_cell(tile, layout, islands))


func _make_starter_cell(tile: Vector2i) -> Dictionary:
	var rng: RandomNumberGenerator = SeedUtil.rng_for(
		_master, "matrix_starter", tile.x, tile.y
	)
	var group: String = _settings.get_zone_group_for_row(tile.y)
	var starter_rules: Dictionary = _rules["starter"]
	var islands: Array = _generate_main(rng, group, {
		"area_range": starter_rules["area_km2"],
		"character": "rolling",
		"shapes": {"ragged": 60, "round": 40},
		"satellite_weights": starter_rules["satellite_count_weights"],
	})
	var cell: Dictionary = _make_cell(tile, "starter", islands)
	cell["locked"] = true
	cell["starter_set"] = _settings.get_starter_set_of(tile)
	cell["required"] = starter_rules["required"].duplicate()
	cell["notes"] = (
		"Starter tile. Hand-tune: flat land for a town, a river, a natural harbor."
	)
	return cell


# ==================================================
# PASS 2: OPEN SEAS
# ==================================================

func _pass_open_seas(matrix) -> void:
	var sea_rules: Dictionary = _rules["open_seas"]
	var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "matrix_seas")
	var radius_range: Array = sea_rules["radius_tiles"]
	var clear_distance: float = float(sea_rules["keep_clear_of_starters_tiles"])
	var starters: Array = _settings.get_all_starters()
	var placed: Array = []   # [{center: Vector2, radius: float}]

	for sea_index in range(int(sea_rules["count"])):
		for attempt in range(60):
			var center: Vector2 = Vector2(
				rng.randf_range(
					float(_settings.min_tile), float(_settings.get_max_tile_x()) + 1.0
				),
				rng.randf_range(
					float(_settings.min_tile), float(_settings.get_max_tile_z()) + 1.0
				)
			)
			var radius: float = rng.randf_range(
				float(radius_range[0]), float(radius_range[1])
			)

			if not _sea_position_ok(center, radius, placed, starters, clear_distance):
				continue

			placed.append({"center": center, "radius": radius})

			for tile in _settings.get_all_tiles():
				var tile_center: Vector2 = Vector2(
					float(tile.x) + 0.5, float(tile.y) + 0.5
				)

				if _settings.tile_distance(center, tile_center) > radius:
					continue

				var cell: Dictionary = matrix.get_cell(tile.x, tile.y)

				if TileMatrixScript.is_frozen(cell):
					continue

				var sea: Dictionary = _make_cell(tile, "ocean", [])
				sea["pattern"] = "open_sea:%d" % (sea_index + 1)
				matrix.set_cell(sea)

			break


func _sea_position_ok(
	center: Vector2, radius: float, placed: Array,
	starters: Array, clear_distance: float
) -> bool:
	for starter in starters:
		var starter_center: Vector2 = Vector2(
			float(starter.x) + 0.5, float(starter.y) + 0.5
		)

		if _settings.tile_distance(center, starter_center) < radius + clear_distance:
			return false

	for other in placed:
		if _settings.tile_distance(center, other["center"]) < radius + float(other["radius"]):
			return false

	return true


# ==================================================
# PASS 3: ISLAND CHAINS AND VOLCANIC ARCS
# ==================================================

func _pass_chains(matrix) -> void:
	var chain_rules: Dictionary = _rules["chains"]
	var rng: RandomNumberGenerator = SeedUtil.rng_for(_master, "matrix_chains")
	var length_range: Array = chain_rules["length_tiles"]
	var curve: float = float(chain_rules["curve"])

	for chain_index in range(int(chain_rules["count"])):
		var is_arc: bool = chain_index < int(chain_rules["volcanic_arcs"])
		var length: int = rng.randi_range(int(length_range[0]), int(length_range[1]))
		var position: Vector2 = Vector2(
			rng.randf_range(
				float(_settings.min_tile), float(_settings.get_max_tile_x()) + 1.0
			),
			rng.randf_range(
				float(_settings.min_tile), float(_settings.get_max_tile_z()) + 1.0
			)
		)
		var angle: float = rng.randf() * TAU
		var path: Array = []        # wrapped tiles
		var directions: Array = []  # direction to the next step

		for step in range(length):
			var tile: Vector2i = _settings.wrap_tile(
				int(floor(position.x)), int(floor(position.y))
			)

			if path.is_empty() or path[path.size() - 1] != tile:
				path.append(tile)

			var turn: float = rng.randf_range(-curve, curve)
			angle += turn
			var step_direction: Vector2 = Vector2(cos(angle), sin(angle))
			position += step_direction

			if directions.size() < path.size():
				directions.append(step_direction)
			else:
				directions[path.size() - 1] = step_direction

		for index in range(path.size()):
			var tile: Vector2i = path[index]
			var cell: Dictionary = matrix.get_cell(tile.x, tile.y)

			if TileMatrixScript.is_frozen(cell):
				continue

			if str(cell.get("pattern", "")).begins_with("open_sea"):
				continue

			var tile_rng: RandomNumberGenerator = SeedUtil.rng_for(
				_master, "matrix_chain", tile.x, tile.y
			)
			var group: String = _settings.get_zone_group_for_row(tile.y)
			var options: Dictionary = {
				"count_weights": chain_rules["island_count_weights"],
				"allow_archipelago": false,
			}

			if is_arc:
				options["character"] = "volcanic"

			var islands: Array = _generate_peers(tile_rng, group, options)

			if islands.is_empty():
				continue

			_bias_islands(islands, directions[index])
			var chain_cell: Dictionary = _make_cell(tile, "peers", islands)
			chain_cell["pattern"] = "chain:%d:%s" % [
				chain_index + 1, "volcanic_arc" if is_arc else "island_chain"
			]
			matrix.set_cell(chain_cell)


# Slides every island in a tile toward a direction, as far as the tile
# edge margin allows, so islands in a chain meet near the tile borders.
# Works on finished islands (the entries stored in the matrix).
func _bias_islands(islands: Array, direction: Vector2) -> void:
	var low: Vector2 = Vector2(-INF, -INF)
	var high: Vector2 = Vector2(INF, INF)

	for island in islands:
		var extent: Vector2 = IslandShapeScript.extents(
			IslandShapeScript.boundary(
				0.0, 0.0,
				float(island["semi_axis_a_m"]), float(island["semi_axis_b_m"]),
				float(island["rotation_deg"])
			)
		)
		low.x = maxf(low.x, -_edge_limit + extent.x - float(island["center_x"]))
		high.x = minf(high.x, _edge_limit - extent.x - float(island["center_x"]))
		low.y = maxf(low.y, -_edge_limit + extent.y - float(island["center_z"]))
		high.y = minf(high.y, _edge_limit - extent.y - float(island["center_z"]))

	var shift: Vector2 = Vector2.ZERO

	if absf(direction.x) > 0.3:
		shift.x = (high.x if direction.x > 0.0 else low.x) * 0.8

	if absf(direction.y) > 0.3:
		shift.y = (high.y if direction.y > 0.0 else low.y) * 0.8

	for island in islands:
		island["center_x"] = int(island["center_x"]) + int(round(shift.x))
		island["center_z"] = int(island["center_z"]) + int(round(shift.y))


# ==================================================
# PASS 4: STARTER NEIGHBORHOODS
# ==================================================

func _pass_starter_neighborhoods(matrix) -> void:
	var rules: Dictionary = _rules["starter_neighborhood"]
	var radius: int = int(rules["radius_tiles"])
	var needed: int = int(rules["min_medium_island_tiles"])

	for starter in _settings.get_all_starters():
		var tiles: Array = _neighborhood_tiles(starter, radius)
		var medium_count: int = 0
		var candidates: Array = []

		for tile in tiles:
			var cell: Dictionary = matrix.get_cell(tile.x, tile.y)

			if _has_medium_island(cell):
				medium_count += 1
			elif not TileMatrixScript.is_frozen(cell):
				candidates.append(tile)

		if medium_count >= needed:
			continue

		var rng: RandomNumberGenerator = SeedUtil.rng_for(
			_master, "matrix_neighborhood", starter.x, starter.y
		)
		_shuffle(rng, candidates)

		for tile in candidates:
			if medium_count >= needed:
				break

			var tile_rng: RandomNumberGenerator = SeedUtil.rng_for(
				_master, "matrix_neighbor_tile", tile.x, tile.y
			)
			var group: String = _settings.get_zone_group_for_row(tile.y)
			var islands: Array = _generate_peers(tile_rng, group, {
				"force_class": "medium",
				"count_weights": {"1": 50, "2": 50},
				"allow_archipelago": false,
			})

			if islands.is_empty():
				continue

			var cell: Dictionary = _make_cell(tile, "peers", islands)
			cell["pattern"] = "starter_neighbor"
			matrix.set_cell(cell)
			medium_count += 1


func _neighborhood_tiles(center: Vector2i, radius: int) -> Array:
	var tiles: Array = []

	for dz in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx == 0 and dz == 0:
				continue

			tiles.append(_settings.wrap_tile(center.x + dx, center.y + dz))

	return tiles


func _has_medium_island(cell: Dictionary) -> bool:
	for island in cell.get("islands", []):
		if float(island["area_km2"]) >= 5.0:
			return true

	return false


# ==================================================
# PASS 5 AND 6: GEOLOGY HINTS
# ==================================================

func _pass_geology(matrix) -> void:
	var weights_by_character: Dictionary = _rules["geology_primary_weights"]
	var extra_chance: float = float(_rules["geology_extra_chance"])

	for cell in matrix.get_sorted_cells():
		for island in cell["islands"]:
			if not island["geology"].is_empty():
				continue

			var rng: RandomNumberGenerator = SeedUtil.rng_for(
				_master, "matrix_geology", int(cell["x"]), int(cell["z"]), int(island["id"])
			)
			var table: Dictionary = weights_by_character.get(
				str(island["character"]), weights_by_character["rolling"]
			)
			var primary: String = _pick(rng, table)
			island["geology"] = [primary]

			if float(island["area_km2"]) >= 5.0 and rng.randf() < extra_chance:
				var others: Dictionary = table.duplicate()
				others.erase(primary)

				if not others.is_empty():
					island["geology"].append(_pick(rng, others))


# Every starter neighborhood must offer granite (tin, copper), a basin
# (coal, clay) and a fold belt (iron) within reach of an early boat.
func _pass_neighborhood_geology(matrix) -> void:
	var rules: Dictionary = _rules["starter_neighborhood"]
	var radius: int = int(rules["radius_tiles"])

	for starter in _settings.get_all_starters():
		var found: Dictionary = {}
		var movable: Array = []

		for tile in _neighborhood_tiles(starter, radius):
			var cell: Dictionary = matrix.get_cell(tile.x, tile.y)

			for island in cell.get("islands", []):
				for hint in island["geology"]:
					found[hint] = true

				if (
					float(island["area_km2"]) >= 5.0
					and not TileMatrixScript.is_frozen(cell)
				):
					movable.append(island)

		var rng: RandomNumberGenerator = SeedUtil.rng_for(
			_master, "matrix_neighborhood_geology", starter.x, starter.y
		)

		for hint in rules["required_hints"]:
			if found.has(hint) or movable.is_empty():
				continue

			var island: Dictionary = movable[rng.randi() % movable.size()]

			if not island["geology"].has(hint):
				island["geology"].append(hint)

			found[hint] = true


# Every climate zone gets every kind of geology somewhere, so no zone is
# missing a key resource.
func _pass_zone_coverage(matrix) -> void:
	var minimum: int = int(_rules["zone_coverage"]["min_islands_per_hint"])

	for zone in _settings.zones:
		var zone_id: String = str(zone["id"])
		var islands_in_zone: Array = []   # [{cell, island}]

		for cell in matrix.get_sorted_cells():
			if str(cell["zone"]) != zone_id:
				continue

			for island in cell["islands"]:
				islands_in_zone.append({"cell": cell, "island": island})

		for hint in GEOLOGY_HINTS:
			var count: int = 0
			var candidates: Array = []

			for entry in islands_in_zone:
				if entry["island"]["geology"].has(hint):
					count += 1
				elif (
					float(entry["island"]["area_km2"]) >= 1.0
					and not TileMatrixScript.is_frozen(entry["cell"])
				):
					candidates.append(entry)

			var rng: RandomNumberGenerator = SeedUtil.rng_for(
				_master, "matrix_coverage:%s:%s" % [zone_id, hint]
			)

			while count < minimum and not candidates.is_empty():
				var index: int = rng.randi() % candidates.size()
				candidates[index]["island"]["geology"].append(hint)
				candidates.remove_at(index)
				count += 1


# ==================================================
# FINISHING
# ==================================================

func _finish(matrix) -> void:
	for cell in matrix.get_sorted_cells():
		var union: Array = []

		for island in cell["islands"]:
			for hint in island["geology"]:
				if not union.has(hint):
					union.append(hint)

		union.sort()
		cell["geology_hints"] = union


# ==================================================
# GENERATING ISLANDS FOR ONE TILE
# ==================================================

# Several islands of similar size, or an archipelago cluster.
# Options: force_class, character, count_weights, allow_archipelago.
func _generate_peers(
	rng: RandomNumberGenerator, group: String, options: Dictionary
) -> Array:
	var scale: float = float(_rules["area_scale"].get(group, 1.0))
	var allow_archipelago: bool = bool(options.get("allow_archipelago", true))
	var count_weights: Dictionary = options.get(
		"count_weights", _group_weights(_rules["peers_count_weights"], group)
	)
	var count: int = int(_pick(rng, count_weights))
	var archipelago: bool = (
		allow_archipelago
		and count >= 3
		and rng.randf() < float(_rules["archipelago_chance"])
	)

	if archipelago:
		count = int(_pick(rng, _rules["archipelago_count_weights"]))

	var character: String = str(options.get("character", ""))

	if character.is_empty():
		character = (
			"archipelago" if archipelago
			else _pick(rng, _rules["character_weights"][group])
		)

	var areas: Array = []
	var base_area: float = 0.0

	if not archipelago:
		var base_class: String = str(
			options.get("force_class", _pick(rng, _rules["peer_class_weights"]))
		)
		base_area = _area_for_class(rng, base_class)

	var variation: Array = _rules["peer_size_variation"]

	for index in range(count):
		var area: float = 0.0

		if archipelago:
			area = _area_for_class(
				rng, _pick(rng, _rules["archipelago_class_weights"])
			)
		else:
			area = base_area * rng.randf_range(
				float(variation[0]), float(variation[1])
			)

			# Peers stay small or medium; the large classes belong to
			# main islands.
			area = minf(area, float(_rules["size_classes"]["medium"][1]) - 0.01)

		areas.append(maxf(area * scale, 0.2))

	var total: float = 0.0

	for area in areas:
		total += float(area)

	var cap: float = float(_rules["total_land_cap_km2"])

	if total > cap:
		for index in range(areas.size()):
			areas[index] = float(areas[index]) * cap / total

	var islands: Array = []

	for area in areas:
		var shapes: Dictionary = (
			{"ragged": 50, "round": 50} if archipelago
			else _rules["shape_weights"]
		)
		islands.append(_new_island(
			rng, float(area), _pick(rng, shapes), "peer", character
		))

	# Place the largest first so small ones fill the gaps.
	islands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["area"]) > float(b["area"])
	)

	var placed: Array = []
	var min_gap: float = float(_rules["min_gap_between_islands_m"])
	var cluster_gap: Array = _rules["cluster_gap_m"]

	for island in islands:
		var success: bool = false

		if archipelago and not placed.is_empty():
			var base: Dictionary = placed[rng.randi() % placed.size()]
			success = _place_near(rng, island, base, placed, cluster_gap)
		else:
			var spread: float = 0.5 if archipelago else 1.0
			var gap: float = float(cluster_gap[0]) if archipelago else min_gap
			success = _place_free(rng, island, placed, gap, spread)

		if success:
			placed.append(island)

	return _finalize(rng, placed)


# One large or great island with a chance of islets and small islands
# just off its coast. Options: area_range, character, shapes,
# satellite_weights.
func _generate_main(
	rng: RandomNumberGenerator, group: String, options: Dictionary
) -> Array:
	var area: float = 0.0

	if options.has("area_range"):
		var range_km2: Array = options["area_range"]
		area = rng.randf_range(float(range_km2[0]), float(range_km2[1]))
	else:
		var weights: Dictionary = _group_weights(_rules["main_class_weights"], group)
		area = _area_for_class(rng, _pick(rng, weights))

	var character: String = str(options.get("character", ""))

	if character.is_empty():
		character = _pick(rng, _rules["character_weights"][group])

	var shapes: Dictionary = options.get("shapes", _rules["shape_weights"])
	var main: Dictionary = _new_island(rng, area, _pick(rng, shapes), "main", character)

	if not _place_free(rng, main, [], 0.0, 0.5):
		return []

	var placed: Array = [main]
	var scale: float = float(_rules["area_scale"].get(group, 1.0))
	var satellite_weights: Dictionary = options.get(
		"satellite_weights", _rules["satellite_count_weights"]
	)
	var satellite_count: int = int(_pick(rng, satellite_weights))
	var satellite_gap: Array = _rules["satellite_gap_m"]

	for index in range(satellite_count):
		var satellite_class: String = _pick(rng, _rules["satellite_class_weights"])
		var satellite_area: float = _area_for_class(rng, satellite_class) * scale
		var satellite: Dictionary = _new_island(
			rng, maxf(satellite_area, 0.15),
			_pick(rng, _rules["shape_weights"]), "satellite", character
		)

		if _place_near(rng, satellite, main, placed, satellite_gap):
			placed.append(satellite)

	return _finalize(rng, placed)


# ==================================================
# ISLAND WORKING DATA AND PLACEMENT
# ==================================================

func _new_island(
	rng: RandomNumberGenerator, area: float, shape: String,
	role: String, character: String
) -> Dictionary:
	var aspect_range: Array = _rules["shape_aspect"][shape]
	var island: Dictionary = {
		"uid": _next_uid,
		"area": area,
		"shape": shape,
		"aspect": rng.randf_range(float(aspect_range[0]), float(aspect_range[1])),
		"rot": float(int(round(rng.randf_range(0.0, 180.0)))),
		"role": role,
		"character": character,
		"cx": 0.0,
		"cz": 0.0,
		"a": 0.0,
		"b": 0.0,
		"pts": PackedVector2Array(),
	}
	_next_uid += 1
	_update_axes(island)
	return island


func _update_axes(island: Dictionary) -> void:
	var axes: Vector2 = IslandShapeScript.semi_axes(
		float(island["area"]), float(island["aspect"]), _fill
	)
	island["a"] = float(int(round(axes.x)))
	island["b"] = float(int(round(axes.y)))
	island["pts"] = IslandShapeScript.boundary(
		float(island["cx"]), float(island["cz"]),
		float(island["a"]), float(island["b"]), float(island["rot"])
	)


func _set_center(island: Dictionary, cx: float, cz: float) -> void:
	island["cx"] = float(int(round(cx)))
	island["cz"] = float(int(round(cz)))
	island["pts"] = IslandShapeScript.boundary(
		float(island["cx"]), float(island["cz"]),
		float(island["a"]), float(island["b"]), float(island["rot"])
	)


func _resize(island: Dictionary, factor: float) -> void:
	island["area"] = float(island["area"]) * factor
	_update_axes(island)


# Puts an island anywhere in the tile it fits, at least min_gap from the
# others. Shrinks it a little when it will not fit. Spread below 1 keeps
# it nearer the middle of the tile.
func _place_free(
	rng: RandomNumberGenerator, island: Dictionary, existing: Array,
	min_gap: float, spread: float
) -> bool:
	for shrink_step in range(8):
		var relative: PackedVector2Array = IslandShapeScript.boundary(
			0.0, 0.0, float(island["a"]), float(island["b"]), float(island["rot"])
		)
		var extent: Vector2 = IslandShapeScript.extents(relative)
		var slack_x: float = _edge_limit - extent.x
		var slack_z: float = _edge_limit - extent.y

		if slack_x >= 0.0 and slack_z >= 0.0:
			for attempt in range(40):
				_set_center(
					island,
					rng.randf_range(-slack_x, slack_x) * spread,
					rng.randf_range(-slack_z, slack_z) * spread
				)

				if _clear_of(island, existing, min_gap, -1):
					return true

		_resize(island, 0.88)

		if float(island["area"]) < 0.1:
			break

	return false


# Puts an island just off the coast of another one. The gap is the open
# water between their coasts.
func _place_near(
	rng: RandomNumberGenerator, island: Dictionary, base: Dictionary,
	existing: Array, gap_range: Array
) -> bool:
	var min_gap: float = float(gap_range[0])
	var max_gap: float = float(gap_range[1])

	for shrink_step in range(5):
		for attempt in range(40):
			var angle: float = rng.randf() * TAU
			var wanted_gap: float = rng.randf_range(min_gap, max_gap)
			var base_radius: float = IslandShapeScript.radius_at(
				float(base["a"]), float(base["b"]), float(base["rot"]), angle
			)
			var own_radius: float = sqrt(float(island["a"]) * float(island["b"]))
			var distance: float = base_radius + wanted_gap + own_radius

			_set_center(
				island,
				float(base["cx"]) + cos(angle) * distance,
				float(base["cz"]) + sin(angle) * distance
			)

			if not IslandShapeScript.fits_inside(island["pts"], _edge_limit):
				continue

			var true_gap: float = IslandShapeScript.gap_between(base, island)

			if true_gap < min_gap or true_gap > max_gap * 1.6:
				continue

			if _clear_of(island, existing, min_gap, int(base["uid"])):
				return true

		_resize(island, 0.8)

		if float(island["area"]) < 0.1:
			break

	return false


func _clear_of(
	island: Dictionary, existing: Array, min_gap: float, skip_uid: int
) -> bool:
	for other in existing:
		if int(other["uid"]) == skip_uid:
			continue

		if IslandShapeScript.gap_between(island, other) < min_gap:
			return false

	return true


# Turns working islands into the entries stored in the matrix.
func _finalize(rng: RandomNumberGenerator, islands: Array) -> Array:
	var ordered: Array = islands.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if str(a["role"]) == "main" and str(b["role"]) != "main":
			return true

		if str(b["role"]) == "main" and str(a["role"]) != "main":
			return false

		return float(a["area"]) > float(b["area"])
	)

	var result: Array = []

	for index in range(ordered.size()):
		var island: Dictionary = ordered[index]
		var area: float = snappedf(float(island["area"]), 0.01)
		var size_class: String = _class_of(area)
		var island_id: int = index + 1

		result.append({
			"id": island_id,
			"role": island["role"],
			"center_x": int(island["cx"]),
			"center_z": int(island["cz"]),
			"semi_axis_a_m": int(island["a"]),
			"semi_axis_b_m": int(island["b"]),
			"rotation_deg": int(island["rot"]),
			"shape": island["shape"],
			"aspect": snappedf(float(island["aspect"]), 0.01),
			"area_km2": area,
			"size_class": size_class,
			"character": island["character"],
			"peak_height_m": _peak_height(rng, str(island["character"]), size_class),
			"glaciated": false,
			"geology": [],
			"seed": 0,
		})

	return result


func _peak_height(
	rng: RandomNumberGenerator, character: String, size_class: String
) -> int:
	var ranges: Dictionary = _rules["peak_range_by_character_m"]
	var range_m: Array = ranges.get(character, ranges["rolling"])
	var scale: float = float(_rules["peak_scale_by_class"][size_class])
	var value: float = rng.randf_range(float(range_m[0]), float(range_m[1])) * scale
	value = clampf(value, 4.0, float(_settings.world_top_m) - 150.0)

	if value < 30.0:
		return int(round(value))

	return int(round(value / 10.0)) * 10


func _make_cell(tile: Vector2i, layout: String, islands: Array) -> Dictionary:
	var group: String = _settings.get_zone_group_for_row(tile.y)
	var kind: String = "islands"

	if layout == "ocean":
		kind = "ocean"
	elif layout == "starter":
		kind = "starter"

	var cell_islands: Array = []

	for island in islands:
		var final_island: Dictionary = island.duplicate(true)
		final_island["glaciated"] = group == "arctic"
		final_island["seed"] = SeedUtil.purpose_seed(
			_master, "island", tile.x, tile.y, int(final_island["id"])
		)
		cell_islands.append(final_island)

	return {
		"x": tile.x,
		"z": tile.y,
		"zone": _settings.get_zone_id_for_row(tile.y),
		"kind": kind,
		"layout": layout,
		"status": "placeholder" if kind == "ocean" else "planned",
		"locked": false,
		"revision": 0,
		"pattern": "",
		"starter_set": "",
		"required": [],
		"islands": cell_islands,
		"geology_hints": [],
		"notes": "",
	}


# ==================================================
# SMALL HELPERS
# ==================================================

func _area_for_class(rng: RandomNumberGenerator, size_class: String) -> float:
	var range_km2: Array = _rules["size_classes"][size_class]
	return rng.randf_range(float(range_km2[0]), float(range_km2[1]))


func _class_of(area_km2: float) -> String:
	for size_class in CLASS_ORDER:
		if area_km2 < float(_rules["size_classes"][size_class][1]):
			return size_class

	return "great"


func _group_weights(table: Dictionary, group: String) -> Dictionary:
	return table.get(group, table["default"])


# Picks a key at random in proportion to its weight. Keys are sorted
# first so the result never depends on dictionary order.
func _pick(rng: RandomNumberGenerator, weights: Dictionary) -> String:
	var keys: Array = weights.keys()
	keys.sort()
	var total: float = 0.0

	for key in keys:
		total += float(weights[key])

	var roll: float = rng.randf() * total

	for key in keys:
		roll -= float(weights[key])

		if roll < 0.0:
			return str(key)

	return str(keys[keys.size() - 1])


func _shuffle(rng: RandomNumberGenerator, items: Array) -> void:
	for index in range(items.size() - 1, 0, -1):
		var other: int = rng.randi() % (index + 1)
		var temp: Variant = items[index]
		items[index] = items[other]
		items[other] = temp
