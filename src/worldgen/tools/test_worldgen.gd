extends SceneTree

# Checks for the new world generator. Run with:
#   godot --headless --path . --script res://src/worldgen/tools/test_worldgen.gd
# Exits with code 0 when every check passes.

const GroundMaterialScript := preload("res://src/client/ground_material.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const RandomizerScript := preload("res://src/worldgen/matrix/matrix_randomizer.gd")
const TileMatrixScript := preload("res://src/worldgen/matrix/tile_matrix.gd")
const TilePlanScript := preload("res://src/worldgen/plan/tile_plan.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TileSitesScript := preload("res://src/worldgen/tile/tile_sites.gd")
const TileGeologyScript := preload("res://src/worldgen/tile/tile_geology.gd")
const TileClimateScript := preload("res://src/worldgen/tile/tile_climate.gd")
const TileWaterScript := preload("res://src/worldgen/tile/tile_water.gd")
const TileErosionScript := preload("res://src/worldgen/tile/tile_erosion.gd")
const IslandShapeScript := preload("res://src/worldgen/matrix/island_shape.gd")
const SketchScript := preload("res://src/worldgen/sketch/world_sketch.gd")
const ElevationScript := preload("res://src/worldgen/sketch/world_elevation.gd")
const WrapNoiseScript := preload("res://src/worldgen/tile/wrap_noise.gd")
const RiverNetworkScript := preload("res://src/worldgen/sketch/river_network.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const CensusScript := preload("res://src/worldgen/sketch/island_census.gd")
const TerrainGeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const TerrainLayout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const ServerStoreScript := preload("res://src/stream/server_block_store.gd")
const ClientCacheScript := preload("res://src/stream/client_block_cache.gd")
const NetworkStreamScript := preload("res://src/stream/network_voxel_stream.gd")
const FloraPlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const ServerFloraScript := preload("res://src/stream/server_flora.gd")
const FloraLayoutScript := preload("res://src/worldgen/runtime/flora_layout.gd")

const WORLD_PATH := "res://worlds/base_world/world.json"
const RULES_PATH := "res://worlds/base_world/plan/matrix_rules.json"
const SKETCH_RULES_PATH := "res://worlds/base_world/plan/sketch_rules.json"

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_seeds()
	_test_settings()
	_test_climate()
	_test_danger()
	_test_tables()
	_test_matrix()
	_test_sketch()

	print("")
	print("%d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: %s" % label)


func _approx(a: float, b: float, tolerance: float = 0.001) -> bool:
	return absf(a - b) <= tolerance


func _load_settings():
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(WORLD_PATH, errors)

	if settings == null:
		print("Could not load settings: %s" % str(errors))

	return settings


# ==================================================
# SEEDS
# ==================================================

func _test_seeds() -> void:
	var master: int = SeedUtil.master_seed(
		"This1is2the3greatest4game5of6all7time"
	)
	_check(master == 574716103, "master seed from the phrase")
	_check(
		SeedUtil.tile_seed(master, 0, 0) == 450413589,
		"tile (0,0) seed matches the world-seed branch"
	)
	_check(
		SeedUtil.tile_seed(master, -3, 4) == 688683332,
		"tile (-3,4) seed matches the world-seed branch"
	)

	# The old WorldDefinition and the new seed code must agree.
	var definition: WorldDefinition = WorldDefinition.new()
	definition.configure_island_tile(1, 0)
	_check(
		definition.world_seed == SeedUtil.tile_seed(master, 1, 0),
		"WorldDefinition and WorldgenSeed agree on tile seeds"
	)

	# Different purposes give independent streams.
	var rng_a: RandomNumberGenerator = SeedUtil.rng_for(master, "a", 1, 1)
	var rng_b: RandomNumberGenerator = SeedUtil.rng_for(master, "b", 1, 1)
	var rng_c: RandomNumberGenerator = SeedUtil.rng_for(master, "a", 1, 1)
	var first_a: int = rng_a.randi()
	_check(first_a != rng_b.randi(), "purposes give different streams")
	_check(first_a == rng_c.randi(), "same purpose repeats exactly")


# ==================================================
# SETTINGS
# ==================================================

func _test_settings() -> void:
	var settings = _load_settings()
	_check(settings != null, "world.json loads and validates")

	if settings == null:
		return

	_check(settings.master_seed == 574716103, "settings master seed")
	_check(settings.tiles_x == 21 and settings.tiles_z == 21, "21 by 21 world")
	_check(settings.get_max_tile_x() == 10, "last tile column is 10")
	_check(settings.get_all_tiles().size() == 441, "441 tiles")
	_check(settings.wrap_tile(11, 0) == Vector2i(-10, 0), "east edge wraps")
	_check(settings.wrap_tile(0, -11) == Vector2i(0, 10), "north edge wraps")
	_check(
		_approx(settings.tile_distance(Vector2(-10, 0), Vector2(10, 0)), 1.0),
		"tile distance wraps around the world"
	)
	_check(
		settings.tile_chebyshev(Vector2i(-10, -10), Vector2i(10, 10)) == 1,
		"Chebyshev distance wraps in both directions"
	)
	_check(settings.get_starter_set_of(Vector2i(3, 4)) == "inner", "inner starter")
	_check(settings.get_starter_set_of(Vector2i(-6, -6)) == "outer", "outer starter")
	_check(settings.get_starter_set_of(Vector2i(0, 0)) == "", "origin is no starter")
	_check(settings.get_all_starters().size() == 8, "eight starter tiles")

	# A broken file must be rejected.
	var broken = WorldSettingsScript.new()
	broken._apply({"name": "x", "seed_text": "y", "geometry": {"tiles_z": 20}})
	_check(not broken.validate().is_empty(), "even tile count is rejected")


# ==================================================
# CLIMATE
# ==================================================

func _test_climate() -> void:
	var settings = _load_settings()

	if settings == null:
		return

	var tile: float = float(settings.tile_size_m)
	var equator: float = tile * 0.5
	var half_world: float = tile * 10.5

	# Equator line is the middle of row 0.
	_check(_approx(settings.get_equator_z_m(), equator), "equator line z")
	_check(
		_approx(settings.latitude_for_z(equator), 0.0),
		"latitude is zero at the equator"
	)
	_check(
		_approx(settings.latitude_for_z(equator - half_world + 1.0), 1.0, 0.001),
		"north pole is latitude +1"
	)
	_check(
		_approx(settings.latitude_for_z(equator + half_world - 1.0), -1.0, 0.001),
		"south pole is latitude -1"
	)

	# Mirror symmetry about the equator.
	for row in range(1, 11):
		var north: float = settings.temperature_for_row_c(-row)
		var south: float = settings.temperature_for_row_c(row)
		_check(
			_approx(north, south, 0.2),
			"row %d and row -%d have the same temperature" % [row, row]
		)

	# The two poles meet across the wrap seam with the same climate.
	_check(
		_approx(
			settings.temperature_c(-10.0 * tile + 1.0),
			settings.temperature_c(11.0 * tile - 1.0),
			0.05
		),
		"the wrap seam joins matching temperatures"
	)

	# Temperature falls steadily from the equator to the pole.
	var previous: float = 1000.0

	for row in range(0, 11):
		var value: float = settings.temperature_for_row_c(row)

		if row > 0:
			_check(value < previous, "temperature falls at row %d" % row)

		previous = value

	_check(
		settings.temperature_for_row_c(0) > 25.0,
		"the equator row is hot"
	)
	_check(
		settings.temperature_for_row_c(4) > 8.0
		and settings.temperature_for_row_c(4) < 18.0,
		"starter rows are temperate"
	)
	_check(
		settings.temperature_for_row_c(9) < -5.0,
		"row 9 is arctic"
	)
	_check(
		_approx(
			settings.temperature_c(equator, 1000.0),
			settings.temperature_c(equator, 0.0) - 6.5,
			0.001
		),
		"altitude cools by the lapse rate"
	)

	# Zones follow the design: desert, transition, temperate, transition, arctic.
	var expected: Dictionary = {
		0: "desert", 1: "desert", 2: "transition_desert",
		3: "temperate", 4: "temperate", 5: "temperate", 6: "temperate",
		7: "transition_arctic", 8: "arctic", 9: "arctic", 10: "arctic",
	}

	for row in expected.keys():
		_check(
			settings.get_zone_id_for_row(row) == expected[row],
			"zone of row %d" % row
		)
		_check(
			settings.get_zone_id_for_row(-row) == expected[row],
			"zone of row -%d" % row
		)


# ==================================================
# DANGER
# ==================================================

func _test_danger() -> void:
	var settings = _load_settings()

	if settings == null:
		return

	for tile in settings.starter_tiles["inner"]:
		var value: float = settings.danger_at_tile(tile.x, tile.y)
		_check(value < 0.2, "inner starter %s is easy (%.2f)" % [str(tile), value])

	for tile in settings.starter_tiles["outer"]:
		var value: float = settings.danger_at_tile(tile.x, tile.y)
		_check(
			value >= 0.35 and value < 0.6,
			"outer starter %s is medium (%.2f)" % [str(tile), value]
		)

	_check(settings.danger_at_tile(0, 0) >= 0.99, "tile (0,0) is the deadliest")

	# The central trench covers rows -1 to 1 and columns -2 to 2.
	var trench: Dictionary = settings.world_features[0]
	var inside: int = 0

	for row in range(-1, 2):
		for column in range(-2, 3):
			if settings.is_tile_in_feature(trench, column, row):
				inside += 1

			_check(
				settings.danger_at_tile(column, row) >= 0.93,
				"trench tile (%d,%d) is deadly" % [column, row]
			)

	_check(inside == 15, "all fifteen trench tiles are inside the oblong (%d)" % inside)
	_check(not settings.is_tile_in_feature(trench, 3, 0), "column 3 is outside the trench")
	_check(not settings.is_tile_in_feature(trench, 0, 2), "row 2 is outside the trench")
	_check(
		settings.danger_at_tile(0, 0) > settings.danger_at_tile(2, 1),
		"the trench is deadliest at its center"
	)
	_check(settings.danger_at_tile(10, 4) >= 0.9, "the east edge is deadly")
	_check(settings.danger_at_tile(-10, -4) >= 0.9, "the west edge is deadly")
	_check(settings.danger_at_tile(0, 10) >= 0.9, "the south pole is deadly")
	_check(settings.danger_at_tile(0, -10) >= 0.9, "the north pole is deadly")
	_check(
		settings.danger_at_tile(3, 0) > settings.danger_at_tile(3, 4) + 0.3,
		"the equator row is more dangerous than the starter rows"
	)
	_check(
		_approx(settings.danger_at_tile(5, 3), settings.danger_at_tile(-5, -3), 0.001),
		"danger is symmetric"
	)

	# Rising steadily from an inner starter to the east edge.
	var previous: float = -1.0
	var rising: bool = true

	for column in range(3, 11):
		var value: float = settings.danger_at_tile(column, 4)

		if value < previous - 0.0001:
			rising = false

		previous = value

	_check(rising, "danger rises from the inner starters to the edge")

	# No jump across the east-west wrap seam.
	var tile: float = float(settings.tile_size_m)
	var east: float = settings.danger_at(11.0 * tile - 1.0, 4.5 * tile)
	var west: float = settings.danger_at(-10.0 * tile + 1.0, 4.5 * tile)
	_check(_approx(east, west, 0.01), "danger is continuous across the wrap seam")
	_check(settings.danger_tier(0.1) == "easy", "danger tier names")
	_check(settings.danger_tier(0.99) == "deadly", "deadly tier")


# ==================================================
# TABLES
# ==================================================

func _test_tables() -> void:
	var tables = TableSetScript.new()
	var problems: Array = tables.load_directory()
	_check(problems.is_empty(), "tables load without problems")

	if not problems.is_empty():
		print(str(problems))

	for table_name in [
		"biomes", "soils", "rocks", "surficial_deposits", "resources",
		"water_classes", "site_types", "feature_types", "province_kinds",
	]:
		_check(tables.has_table(table_name), "table %s exists" % table_name)

	# IDs must match the ones the existing generator already uses.
	_check(tables.id_of("rocks", "granite") == GeologyIds.GRANITE, "granite ID")
	_check(tables.id_of("rocks", "coal") == GeologyIds.COAL, "coal rock ID")
	_check(tables.id_of("rocks", "tuff") == 11, "tuff rock ID is 11")
	var rules_errors: Array = []
	var geology_rules: Dictionary = TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", rules_errors)
	var volcanic_layers: Array = geology_rules["geology"]["stacks"]["volcanic"]["layers"] if geology_rules.has("geology") else []
	var has_tuff_layer: bool = false
	for layer in volcanic_layers:
		if str(layer[0]) == "tuff":
			has_tuff_layer = true
	_check(has_tuff_layer, "volcanic rock stack has a tuff layer")
	_check(tables.id_of("resources", "tin") == ResourceIds.TIN, "tin ID")
	_check(tables.id_of("resources", "gemstone") == ResourceIds.GEMSTONE, "gem ID")
	_check(tables.id_of("resources", "peat") == ResourceIds.PEAT, "peat ID")
	_check(tables.id_of("resources", "bog_iron") > 0 and tables.id_of("resources", "saltpeter") > 0, "bog iron and saltpeter exist")
	_check(tables.entry_of("resources", "nickel").get("retired", false), "nickel is retired")
	_check(
		tables.id_of("surficial_deposits", "lake_sediment")
		== SurficialDepositIds.LAKE_SEDIMENT,
		"lake sediment ID"
	)
	_check(tables.name_of("biomes", 0) == "ocean", "name lookup")
	_check(tables.id_of("biomes", "nonsense") == -1, "unknown name gives -1")

	# A broken table must be caught.
	var broken = TableSetScript.new()
	var errors: Array = broken._add_table(
		{
			"table": "t", "next_id": 1,
			"entries": [
				{"id": 0, "name": "a"}, {"id": 0, "name": "b"},
			],
		},
		"test"
	)
	_check(not errors.is_empty(), "a repeated ID is rejected")


# ==================================================
# TILE MATRIX
# ==================================================

func _make_randomizer(settings, errors: Array):
	var rules: Dictionary = RandomizerScript.load_rules(RULES_PATH, errors)
	var randomizer = RandomizerScript.new()
	randomizer.setup(settings, rules)
	return randomizer


func _test_matrix() -> void:
	var settings = _load_settings()

	if settings == null:
		return

	var errors: Array = []
	var rules: Dictionary = RandomizerScript.load_rules(RULES_PATH, errors)
	_check(errors.is_empty() and not rules.is_empty(), "matrix rules load")

	var start_ms: int = Time.get_ticks_msec()
	var randomizer = _make_randomizer(settings, errors)
	var matrix = randomizer.generate()
	var elapsed_ms: int = Time.get_ticks_msec() - start_ms
	print("matrix generated in %d ms" % elapsed_ms)

	_check(matrix.cells.size() == 441, "matrix has 441 cells")

	# Same world and rules give the same matrix.
	var again = _make_randomizer(settings, errors).generate()
	_check(
		matrix.to_json_text() == again.to_json_text(),
		"the matrix is reproducible"
	)

	# Saving and loading changes nothing.
	var temp_path: String = "user://test_tile_matrix.json"
	matrix.save(temp_path)
	var loaded = TileMatrixScript.load_file(temp_path, errors)
	_check(loaded != null, "the matrix loads back")

	if loaded != null:
		_check(
			loaded.to_json_text() == matrix.to_json_text(),
			"save and load keep the matrix identical"
		)

	_test_matrix_invariants(settings, rules, matrix)
	_test_matrix_distribution(settings, rules, matrix)
	_test_matrix_locking(settings, matrix, errors)


func _test_matrix_invariants(settings, rules: Dictionary, matrix) -> void:
	var limit: float = float(settings.tile_size_m) * 0.5 - float(
		rules["island_edge_margin_m"]
	)
	var min_gap: float = float(rules["cluster_gap_m"][0]) - 5.0
	var bad_fit: int = 0
	var bad_gap: int = 0
	var bad_class: int = 0
	var bad_count: int = 0
	var bad_kind: int = 0
	var bad_hint: int = 0
	var bad_cap: int = 0
	var great_count: int = 0

	for cell in matrix.get_sorted_cells():
		var islands: Array = cell["islands"]
		var total: float = 0.0
		var big: int = 0

		if (cell["kind"] == "ocean") != islands.is_empty():
			bad_kind += 1

		if islands.size() > 6:
			bad_count += 1

		for island in islands:
			total += float(island["area_km2"])

			if island["size_class"] in ["large", "great"]:
				big += 1

			if island["size_class"] == "great":
				great_count += 1

			var points: PackedVector2Array = IslandShapeScript.boundary(
				float(island["center_x"]), float(island["center_z"]),
				float(island["semi_axis_a_m"]), float(island["semi_axis_b_m"]),
				float(island["rotation_deg"])
			)

			if (
				str(island["role"]) != "landmark"
				and not IslandShapeScript.fits_inside(points, limit + 0.5)
			):
				bad_fit += 1

			for hint in island["geology"]:
				if hint not in ["granite", "basin", "fold_belt", "volcanic"]:
					bad_hint += 1

			if island["geology"].is_empty():
				bad_hint += 1

		for first_index in range(islands.size()):
			for second_index in range(first_index + 1, islands.size()):
				var a: Dictionary = _island_geometry(islands[first_index])
				var b: Dictionary = _island_geometry(islands[second_index])

				if IslandShapeScript.gap_between(a, b) < min_gap:
					bad_gap += 1

		if big > 1:
			bad_class += 1

		if (
			total > float(rules["total_land_cap_km2"]) + 5.0
			and not str(cell["pattern"]).begins_with("feature:")
		):
			bad_cap += 1

	_check(bad_fit == 0, "every island fits inside its tile margin (%d bad)" % bad_fit)
	_check(bad_gap == 0, "islands keep their minimum gap (%d bad)" % bad_gap)
	_check(bad_class == 0, "at most one large or great island per tile (%d bad)" % bad_class)
	_check(bad_count == 0, "no tile has too many islands (%d bad)" % bad_count)
	_check(bad_kind == 0, "ocean tiles are empty and island tiles are not (%d bad)" % bad_kind)
	_check(bad_hint == 0, "every island has valid geology (%d bad)" % bad_hint)
	_check(bad_cap == 0, "total land per tile stays under the cap (%d bad)" % bad_cap)
	_check(great_count > 5, "great islands exist (%d)" % great_count)

	# Starter tiles
	var starters: Array = settings.get_all_starters()
	_check(starters.size() == 8, "eight starters")

	for tile in starters:
		var cell: Dictionary = matrix.get_cell(tile.x, tile.y)
		_check(cell.get("kind", "") == "starter", "starter %s kind" % str(tile))
		_check(bool(cell.get("locked", false)), "starter %s is locked" % str(tile))
		_check(
			cell["islands"].size() >= 1 and cell["islands"][0]["role"] == "main",
			"starter %s has a main island" % str(tile)
		)

		if not cell["islands"].is_empty():
			var area: float = float(cell["islands"][0]["area_km2"])
			_check(area >= 15.0, "starter %s island is large (%.1f km2)" % [str(tile), area])

		_check(
			cell["required"].has("harbor") and cell["required"].has("river"),
			"starter %s lists what it needs" % str(tile)
		)

		# Starter neighborhood: medium islands and varied geology.
		var medium_tiles: int = 0
		var hints: Dictionary = {}

		for dz in range(-2, 3):
			for dx in range(-2, 3):
				if dx == 0 and dz == 0:
					continue

				var near: Vector2i = settings.wrap_tile(tile.x + dx, tile.y + dz)
				var near_cell: Dictionary = matrix.get_cell(near.x, near.y)
				var has_medium: bool = false

				for island in near_cell["islands"]:
					if float(island["area_km2"]) >= 5.0:
						has_medium = true

					for hint in island["geology"]:
						hints[hint] = true

				if has_medium:
					medium_tiles += 1

		_check(medium_tiles >= 3, "starter %s has medium islands nearby" % str(tile))
		_check(
			hints.has("granite") and hints.has("basin") and hints.has("fold_belt"),
			"starter %s has granite, basin and fold belt nearby" % str(tile)
		)

	# Every climate zone has every kind of geology.
	for zone in settings.zones:
		var counts: Dictionary = {}

		for cell in matrix.get_sorted_cells():
			if cell["zone"] != zone["id"]:
				continue

			for island in cell["islands"]:
				for hint in island["geology"]:
					counts[hint] = int(counts.get(hint, 0)) + 1

		for hint in ["granite", "basin", "fold_belt", "volcanic"]:
			_check(
				int(counts.get(hint, 0)) >= 3,
				"zone %s has %s (%d)" % [zone["id"], hint, int(counts.get(hint, 0))]
			)


func _island_geometry(island: Dictionary) -> Dictionary:
	var geometry: Dictionary = {
		"cx": float(island["center_x"]),
		"cz": float(island["center_z"]),
		"a": float(island["semi_axis_a_m"]),
		"b": float(island["semi_axis_b_m"]),
		"rot": float(island["rotation_deg"]),
	}
	geometry["pts"] = IslandShapeScript.boundary(
		geometry["cx"], geometry["cz"], geometry["a"], geometry["b"], geometry["rot"]
	)
	return geometry


func _test_matrix_distribution(settings, rules: Dictionary, matrix) -> void:
	var ocean: int = 0
	var arctic_ocean: int = 0
	var arctic_total: int = 0
	var temperate_ocean: int = 0
	var temperate_total: int = 0
	var seas: Dictionary = {}
	var chains: Dictionary = {}

	for cell in matrix.get_sorted_cells():
		var is_ocean: bool = cell["kind"] == "ocean"

		if is_ocean:
			ocean += 1

		if cell["zone"] == "arctic":
			arctic_total += 1
			arctic_ocean += 1 if is_ocean else 0

		if cell["zone"] == "temperate":
			temperate_total += 1
			temperate_ocean += 1 if is_ocean else 0

		var pattern: String = str(cell["pattern"])

		if pattern.begins_with("open_sea"):
			seas[pattern] = true

		if pattern.begins_with("chain"):
			chains[pattern.get_slice(":", 1)] = true

	var fraction: float = float(ocean) / 441.0
	print("ocean tiles: %d of 441 (%.0f%%)" % [ocean, fraction * 100.0])
	_check(fraction > 0.2 and fraction < 0.5, "ocean share is plausible")
	_check(
		float(arctic_ocean) / float(arctic_total)
		> float(temperate_ocean) / float(temperate_total),
		"the arctic has more open ocean than the temperate zone"
	)
	_check(seas.size() >= 3, "open seas were placed (%d)" % seas.size())

	var trench_islands: int = 0
	var trench_tiles: int = 0
	var trench: Dictionary = settings.world_features[0]

	for cell in matrix.get_sorted_cells():
		if settings.is_tile_in_feature(trench, int(cell["x"]), int(cell["z"])):
			trench_tiles += 1

			for island in cell["islands"]:
				if str(island["role"]) != "landmark":
					trench_islands += 1

	_check(trench_tiles == 15, "the trench covers fifteen tiles (%d)" % trench_tiles)
	_check(trench_islands == 0, "the trench holds no ordinary islands")

	# The center island: the biggest island in the world, locked, volcanic.
	var center: Dictionary = matrix.get_cell(0, 0)
	_check(center["islands"].size() == 1, "tile (0,0) holds one island")

	if center["islands"].size() == 1:
		var island: Dictionary = center["islands"][0]
		_check(island["role"] == "landmark", "the center island is the landmark")
		_check(bool(center["locked"]), "the center island tile is locked")
		_check(island["character"] == "volcanic", "the center island is volcanic")
		_check(int(island["peak_height_m"]) >= 1800, "the volcano is very tall")
		_check(bool(island["crosses_tiles"]), "the center island crosses tile borders")

		# It is fixed by the world settings, never by chance: exactly the
		# same size, shape, height and seed on every run.
		var feature: Dictionary = settings.world_features[1]
		var tile_size: float = float(settings.tile_size_m)
		_check(
			int(island["semi_axis_a_m"]) == int(round(float(feature["half_length_tiles"]) * tile_size))
			and int(island["semi_axis_b_m"]) == int(round(float(feature["half_width_tiles"]) * tile_size))
			and int(island["center_x"]) == 0 and int(island["center_z"]) == 0
			and int(island["peak_height_m"]) == int(feature["peak_m"]),
			"the center island matches its fixed description in world.json"
		)
		_check(
			int(island["seed"]) == SeedUtil.purpose_seed(settings.master_seed, "island", 0, 0, 1),
			"the center island's seed comes from the world seed"
		)

		# A fresh run with different rules still gives the identical island.
		var changed_rules: Dictionary = rules.duplicate(true)
		changed_rules["tile_kind_odds"]["desert"] = {"ocean": 0.1, "peers": 0.1, "main": 0.8}
		changed_rules["open_seas"]["count"] = 2
		var changed_randomizer = RandomizerScript.new()
		changed_randomizer.setup(settings, changed_rules)
		var other_matrix = changed_randomizer.generate()
		_check(
			JSON.stringify(other_matrix.get_cell(0, 0)) == JSON.stringify(center),
			"the center island is identical even when the random rules change"
		)
		var biggest_other: float = 0.0

		for cell in matrix.get_sorted_cells():
			for other in cell["islands"]:
				if str(other["role"]) != "landmark":
					biggest_other = maxf(biggest_other, float(other["area_km2"]))

		_check(
			float(island["area_km2"]) > biggest_other * 2.0,
			"the center island is far bigger than any other (%.0f vs %.0f km2)"
			% [float(island["area_km2"]), biggest_other]
		)
	_check(chains.size() >= 3, "island chains were placed (%d)" % chains.size())


func _test_matrix_locking(settings, matrix, errors: Array) -> void:
	# Lock one ordinary tile with hand edits, mark another as baked, and
	# change the rules a little. Locked and baked tiles must not change.
	var edited = TileMatrixScript.new()
	edited.meta = matrix.meta.duplicate(true)

	for key in matrix.cells.keys():
		edited.cells[key] = matrix.cells[key].duplicate(true)

	var locked_tile: Vector2i = Vector2i(5, 5)
	var baked_tile: Vector2i = Vector2i(-6, 2)
	var locked_cell: Dictionary = edited.get_cell(locked_tile.x, locked_tile.y)
	locked_cell["locked"] = true
	locked_cell["notes"] = "hand edited"
	var baked_cell: Dictionary = edited.get_cell(baked_tile.x, baked_tile.y)
	baked_cell["status"] = "baked"
	baked_cell["notes"] = "already baked"

	var rules: Dictionary = RandomizerScript.load_rules(RULES_PATH, errors)
	var changed = RandomizerScript.new()
	changed.setup(settings, rules)
	var regenerated = changed.generate(edited)

	_check(
		JSON.stringify(regenerated.get_cell(locked_tile.x, locked_tile.y))
		== JSON.stringify(edited.get_cell(locked_tile.x, locked_tile.y)),
		"a locked tile is kept"
	)
	_check(
		JSON.stringify(regenerated.get_cell(baked_tile.x, baked_tile.y))
		== JSON.stringify(edited.get_cell(baked_tile.x, baked_tile.y)),
		"a baked tile is kept"
	)

	# Tiles far from any pattern change only when their own inputs change.
	var same: int = 0

	for key in matrix.cells.keys():
		if JSON.stringify(regenerated.cells[key]) == JSON.stringify(matrix.cells[key]):
			same += 1

	print("tiles identical after locking two tiles: %d of 441" % same)
	_check(same > 380, "locking two tiles leaves almost every other tile unchanged")


# ==================================================
# WORLD SKETCH AND ELEVATION
# ==================================================

func _test_sketch() -> void:
	var settings = _load_settings()

	if settings == null:
		return

	var errors: Array = []
	var rules: Dictionary = SketchScript.load_rules(SKETCH_RULES_PATH, errors)
	_check(not rules.is_empty(), "sketch rules load")

	var maker = SketchScript.new()
	maker.setup(settings, rules)
	var sketch: Dictionary = maker.generate()
	var again = SketchScript.new()
	again.setup(settings, rules)
	_check(
		JSON.stringify(sketch) == JSON.stringify(again.generate()),
		"the sketch is reproducible"
	)

	# A locked feature survives regeneration unchanged, even if edited.
	var edited: Dictionary = sketch.duplicate(true)

	for feature in edited["features"]:
		if feature["id"] == "arc_1":
			feature["locked"] = true
			feature["mounts"][0]["peak"] = 1234

	var regenerated: Dictionary = again.generate(edited)
	var kept: bool = false

	for feature in regenerated["features"]:
		if feature["id"] == "arc_1":
			kept = int(feature["mounts"][0]["peak"]) == 1234

	_check(kept, "a locked sketch feature is kept")

	# Build a coarse elevation map (320 m cells) for the checks.
	var started: int = Time.get_ticks_msec()
	var elevation = ElevationScript.new()
	elevation.build(settings, rules, sketch, 320.0)
	print("coarse elevation built in %d ms" % (Time.get_ticks_msec() - started))

	var second = ElevationScript.new()
	second.build(settings, rules, sketch, 320.0)
	_check(elevation.heights == second.heights, "the elevation map is reproducible")

	# The map joins up across the wrap seam in both directions.
	var seam_x: float = 0.0
	var inner_x: float = 0.0
	var seam_z: float = 0.0
	var inner_z: float = 0.0
	var last: int = elevation.size_x - 1

	for row in range(elevation.size_z):
		seam_x += absf(elevation.heights[elevation.index_of(0, row)] - elevation.heights[elevation.index_of(last, row)])
		# Compare with the steps just either side of the seam, where the
		# terrain is of the same kind (the ridge runs along this seam).
		inner_x += 0.5 * (
			absf(elevation.heights[elevation.index_of(1, row)] - elevation.heights[elevation.index_of(0, row)])
			+ absf(elevation.heights[elevation.index_of(last, row)] - elevation.heights[elevation.index_of(last - 1, row)])
		)

	for column in range(elevation.size_x):
		seam_z += absf(elevation.heights[elevation.index_of(column, 0)] - elevation.heights[elevation.index_of(column, last)])
		inner_z += 0.5 * (
			absf(elevation.heights[elevation.index_of(column, 1)] - elevation.heights[elevation.index_of(column, 0)])
			+ absf(elevation.heights[elevation.index_of(column, last)] - elevation.heights[elevation.index_of(column, last - 1)])
		)

	print("seam step east-west %.1f m vs beside it %.1f m; north-south %.1f m vs beside it %.1f m" % [
		seam_x / float(elevation.size_z), inner_x / float(elevation.size_z),
		seam_z / float(elevation.size_x), inner_z / float(elevation.size_x)
	])
	_check(seam_x < inner_x * 2.0 + 1.0, "no step at the east-west wrap seam")
	_check(seam_z < inner_z * 2.0 + 1.0, "no step at the north-south wrap seam")

	# Fixed features.
	var tile: float = float(settings.tile_size_m)
	var crater_floor: float = elevation.height_at_m(tile * 0.5, tile * 0.5)
	_check(
		crater_floor > 1400.0 and crater_floor < 1900.0,
		"the crater floor sits below the rim (%.0f m)" % crater_floor
	)

	var highest: float = -INF
	var lava: int = 0

	for index in range(elevation.heights.size()):
		highest = maxf(highest, elevation.heights[index])
		lava += 1 if elevation.special[index] == ElevationScript.SPECIAL_LAVA else 0

	_check(highest <= float(settings.world_top_m), "nothing rises above the world top")
	_check(lava > 0, "the crater holds lava")

	var counts: Dictionary = {}

	for index in range(elevation.special.size()):
		var kind: int = elevation.special[index]
		counts[kind] = int(counts.get(kind, 0)) + 1

	var cell_area: float = pow(elevation.cell_m / 1000.0, 2.0)
	_check(int(counts.get(ElevationScript.SPECIAL_SCORCHED, 0)) > 0, "scorched earth surrounds the volcano")
	_check(int(counts.get(ElevationScript.SPECIAL_SALT, 0)) > 0, "the center island has salt flats")
	_check(int(counts.get(ElevationScript.SPECIAL_ROAD, 0)) > 0, "old roads lead from the ruined city")
	_check(
		float(counts.get(ElevationScript.SPECIAL_RUINS, 0)) * cell_area > 5.0,
		"ground is prepared for the ruined city (%.1f km2)" % (float(counts.get(ElevationScript.SPECIAL_RUINS, 0)) * cell_area)
	)
	_check(int(counts.get(ElevationScript.SPECIAL_SWAMP, 0)) == 0, "no swamps on the desert island")
	_check(
		elevation.height_at_m(tile * 2.5, tile * 0.5) < -2300.0,
		"the trench is deep beside the center island"
	)

	var census: Dictionary = CensusScript.count(elevation)
	var center_label: int = census["label"][elevation.index_of(
		int((tile * 0.5 - elevation.origin_x) / elevation.cell_m) + 12,
		int((tile * 0.5 - elevation.origin_z) / elevation.cell_m)
	)]
	_check(center_label >= 0, "the center island is land")

	if center_label >= 0:
		var area: float = float(census["islands"][center_label]["area_km2"])
		_check(area > 120.0, "the center island is huge (%.0f km2)" % area)

		var tallest_other: float = 0.0

		for number in range(census["islands"].size()):
			if number != center_label:
				tallest_other = maxf(tallest_other, float(census["islands"][number]["peak_m"]))

		_check(
			tallest_other < float(census["islands"][center_label]["peak_m"]),
			"the center volcano is the tallest peak (%.0f m elsewhere)" % tallest_other
		)

	# Every starter tile has a decent island near its middle.
	for tile_position in settings.get_all_starters():
		var best: float = 0.0

		for dz in range(-6, 7, 2):
			for dx in range(-6, 7, 2):
				var column: int = int(((float(tile_position.x) + 0.5) * tile - elevation.origin_x) / elevation.cell_m) + dx
				var row: int = int(((float(tile_position.y) + 0.5) * tile - elevation.origin_z) / elevation.cell_m) + dz
				var number: int = census["label"][elevation.index_of(column, row)]

				if number >= 0:
					best = maxf(best, float(census["islands"][number]["area_km2"]))

		_check(best >= 15.0, "starter %s has an island (%.0f km2)" % [str(tile_position), best])

	# Every starter tile has flat, low town ground (the coastal plain and
	# harbor ground behind its beaches).
	var cell_km2: float = pow(elevation.cell_m / 1000.0, 2.0)

	for tile_position in settings.get_all_starters():
		var flat_km2: float = 0.0
		var first_column: int = int((float(tile_position.x) * tile - elevation.origin_x) / elevation.cell_m)
		var first_row: int = int((float(tile_position.y) * tile - elevation.origin_z) / elevation.cell_m)
		var tile_cells: int = int(tile / elevation.cell_m)

		for row in range(first_row, first_row + tile_cells):
			for column in range(first_column, first_column + tile_cells):
				var h: float = elevation.heights[elevation.index_of(column, row)]

				if h <= 0.0 or h > 40.0:
					continue

				var dx: float = (elevation.heights[elevation.index_of(column + 1, row)] - elevation.heights[elevation.index_of(column - 1, row)]) / (2.0 * elevation.cell_m)
				var dz: float = (elevation.heights[elevation.index_of(column, row + 1)] - elevation.heights[elevation.index_of(column, row - 1)]) / (2.0 * elevation.cell_m)

				if sqrt(dx * dx + dz * dz) < 0.08:
					flat_km2 += cell_km2

		_check(flat_km2 >= 2.0, "starter %s has flat town ground (%.1f km2)" % [str(tile_position), flat_km2])

	var land: float = 0.0

	for island in census["islands"]:
		land += float(island["area_km2"])

	var share: float = land / (float(settings.tiles_x * settings.tiles_z) * pow(tile / 1000.0, 2.0))
	print("land share %.1f%% in %d islands" % [share * 100.0, census["islands"].size()])
	_check(share > 0.02 and share < 0.12, "the land share is plausible")

	_test_tile_plan(settings, sketch, elevation, census)
	_test_tile_height(settings, elevation)
	_test_tile_erosion(settings, elevation)
	_test_tile_water(settings, elevation, sketch)


func _test_tile_plan(settings, sketch: Dictionary, elevation, census: Dictionary) -> void:
	var plan = TilePlanScript.new()
	plan.setup(settings, sketch, elevation)
	var matrix = plan.build()
	_check(matrix.cells.size() == 441, "the tile plan has 441 tiles")
	_check(plan.islands.size() == census["islands"].size(), "the plan lists every island")

	var again = TilePlanScript.new()
	again.setup(settings, sketch, elevation)
	_check(
		again.build().to_json_text() == matrix.to_json_text()
		and again.islands_json() == plan.islands_json(),
		"the tile plan is reproducible"
	)

	var temp_path: String = "user://test_tile_plan.json"
	matrix.save(temp_path)
	var errors: Array = []
	var loaded = TileMatrixScript.load_file(temp_path, errors)
	_check(
		loaded != null and loaded.to_json_text() == matrix.to_json_text(),
		"the tile plan saves and loads identically"
	)

	# Land in the plan adds up to the land in the map.
	var plan_land: float = 0.0
	var map_land: float = 0.0

	for cell in matrix.get_sorted_cells():
		plan_land += float(cell["land_km2"])

	for island in plan.islands:
		map_land += float(island["area_km2"])

	_check(absf(plan_land - map_land) < 0.01 * maxf(map_land, 1.0) + 1.0, "tile land adds up to island land")

	# Starters and the landmark are locked and hold land.
	for tile in settings.get_all_starters():
		var cell: Dictionary = matrix.get_cell(tile.x, tile.y)
		_check(
			str(cell["kind"]) == "starter" and float(cell["land_km2"]) > 25.0,
			"starter tile (%d,%d) is a starter with land" % [tile.x, tile.y]
		)

	# Each starter sits on a landmass in its size range.
	var errors_rules: Array = []
	var targets: Dictionary = SketchScript.load_rules(SKETCH_RULES_PATH, errors_rules)["starter_islands"]["landmass_km2"]
	var label: PackedInt32Array = census["label"]

	for feature in sketch["features"]:
		for mount in feature.get("mounts", []):
			if str(mount["type"]) != "starter":
				continue

			var tile: Vector2i = Vector2i(int(mount["starter"][0]), int(mount["starter"][1]))
			var range_km2: Array = targets[settings.get_starter_set_of(tile)]
			var column: int = int(floor((float(mount["x"]) - elevation.origin_x) / elevation.cell_m))
			var row: int = int(floor((float(mount["z"]) - elevation.origin_z) / elevation.cell_m))
			var number: int = label[elevation.index_of(column, row)]
			var area: float = float(census["islands"][number]["area_km2"]) if number >= 0 else 0.0
			print("starter %s landmass %.1f km2" % [str(tile), area])
			_check(
				area >= float(range_km2[0]) and area <= float(range_km2[1]),
				"starter %s landmass %.1f km2 is in range %s" % [str(tile), area, str(range_km2)]
			)

	var center: Dictionary = matrix.get_cell(0, 0)
	_check(
		str(center["kind"]) == "landmark" and center["features"].has("center_island")
		and center["geology_hints"].has("volcanic") and center["special"].has("lava"),
		"the center tile is the landmark island"
	)

	# Trench tiles away from the island hold no land; planned tiles hold land or a starter.
	for cell in matrix.get_sorted_cells():
		if str(cell["kind"]) == "trench":
			_check(float(cell["land_km2"]) == 0.0, "trench tile (%d,%d) has no land" % [cell["x"], cell["z"]])

		_check(
			(str(cell["status"]) == "planned") == (float(cell["land_km2"]) > 0.0 or str(cell["starter_set"]) != ""),
			"tile (%d,%d) status matches its land" % [cell["x"], cell["z"]]
		)

	# Every island lists tiles that point back at it.
	var consistent: bool = true

	for island in plan.islands:
		for tile in island["tiles"]:
			if not matrix.get_cell(int(tile[0]), int(tile[1]))["island_ids"].has(int(island["id"])):
				consistent = false

	_check(consistent, "island tile lists match the tiles")

	# A locked tile survives a rebuild unchanged even if edited.
	var edited = TileMatrixScript.new()
	edited.meta = matrix.meta.duplicate(true)

	for key in matrix.cells.keys():
		edited.cells[key] = matrix.cells[key].duplicate(true)

	edited.cells[Vector2i(0, 0)]["notes"] = "hand edited"
	edited.cells[Vector2i(0, 0)]["locked"] = true
	var rebuilt = plan.build(edited)
	_check(str(rebuilt.get_cell(0, 0)["notes"]) == "hand edited", "a locked plan tile is kept on rebuild")


func _test_tile_height(settings, elevation) -> void:
	var errors: Array = []
	var tile_rules: Dictionary = TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", errors)
	_check(not tile_rules.is_empty(), "tile rules load")

	var west = TileHeightScript.new()
	west.setup(settings, elevation, tile_rules)
	var started: int = Time.get_ticks_msec()
	west.build(Vector2i(3, 4))
	print("tile height map built in %d ms" % (Time.get_ticks_msec() - started))
	_check(west.samples == 1921 and west.heights.size() == 1921 * 1921, "the tile height map is 1,921 by 1,921")

	var east = TileHeightScript.new()
	east.setup(settings, elevation, tile_rules)
	east.build(Vector2i(4, 4))
	var south = TileHeightScript.new()
	south.setup(settings, elevation, tile_rules)
	south.build(Vector2i(3, 5))

	# Neighboring tiles agree exactly on their shared edge.
	var worst_x: float = 0.0
	var worst_z: float = 0.0

	for k in range(west.samples):
		worst_x = maxf(worst_x, absf(west.height_at(west.samples - 1, k) - east.height_at(0, k)))
		worst_z = maxf(worst_z, absf(west.height_at(k, west.samples - 1) - south.height_at(k, 0)))

	print("tile edge mismatch east %.4f m, south %.4f m" % [worst_x, worst_z])
	_check(worst_x < 0.001 and worst_z < 0.001, "tile edges match their neighbors")

	var again = TileHeightScript.new()
	again.setup(settings, elevation, tile_rules)
	again.build(Vector2i(3, 4))
	_check(again.heights == west.heights, "the tile height map is reproducible")

	# Land area agrees with the coarse world map.
	var tile_land: float = 0.0

	for value in west.heights:
		if value > 0.0:
			tile_land += 1.0

	tile_land *= pow(west.spacing_m / 1000.0, 2.0)
	var map_land: float = 0.0
	var tile_cells: int = int(round(float(settings.tile_size_m) / elevation.cell_m))

	for row in range(tile_cells):
		for column in range(tile_cells):
			var h: float = elevation.heights[elevation.index_of(
				(3 - settings.min_tile) * tile_cells + column, (4 - settings.min_tile) * tile_cells + row
			)]

			if h > 0.0:
				map_land += 1.0

	map_land *= pow(elevation.cell_m / 1000.0, 2.0)
	print("tile land %.1f km2 vs world map %.1f km2" % [tile_land, map_land])
	_check(absf(tile_land - map_land) < 0.06 * map_land, "tile land matches the world map")


func _test_tile_water(settings, elevation, sketch: Dictionary) -> void:
	var errors: Array = []
	var tile_rules: Dictionary = TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", errors)
	var tile: Vector2i = Vector2i(3, 4)
	var starter: Dictionary = {}

	for feature in sketch["features"]:
		for mount in feature.get("mounts", []):
			if str(mount["type"]) == "starter" and int(mount["starter"][0]) == tile.x and int(mount["starter"][1]) == tile.y:
				starter = {
					"bay_center": Vector2(float(mount["bay_center"][0]), float(mount["bay_center"][1])),
					"beach_dir": Vector2(float(mount["beach_dir"][0]), float(mount["beach_dir"][1])),
					"bay_radius_m": float(mount["bay_radius_m"]),
				}

	_check(not starter.is_empty(), "the starter tile has bay details")

	var height = TileHeightScript.new()
	height.setup(settings, elevation, tile_rules)
	height.build(tile)
	var water = TileWaterScript.new()
	water.setup(settings, tile_rules)
	var started: int = Time.get_ticks_msec()
	water.build(height, starter)
	print("tile water built in %d ms: %d river cells, %d lakes" % [
		Time.get_ticks_msec() - started, water.river_cells, water.lakes.size()
	])
	_check(water.river_cells > 500, "the tile has rivers")
	_check(water.max_bed_rise_m <= 0.0, "river beds only run downhill toward the sea (largest climb %.2f m)" % water.max_bed_rise_m)

	var low_lake: bool = false

	for lake in water.lakes:
		if float(lake["surface_m"]) < float(tile_rules["water"]["lake_min_surface_m"]):
			low_lake = true

	_check(not low_lake, "lakes only form above the minimum height")

	# River water is never below its bed (waterfalls on steep cliffs may sit well above the carved ground); ocean water is at sea level.
	var bad_surface: int = 0

	for index in range(water.samples * water.samples):
		var kind: int = water.water_class[index]

		if kind == TileWaterScript.OCEAN and water.water_surface[index] != 0.0:
			bad_surface += 1
		elif kind == TileWaterScript.RIVER and (
			water.water_surface[index] > water.heights[index] + 130.0
			or water.water_surface[index] < water.heights[index] - 0.01
		):
			bad_surface += 1

	var over_max: float = 0.0
	var under_max: float = 0.0

	for index in range(water.samples * water.samples):
		if water.water_class[index] == TileWaterScript.RIVER:
			over_max = maxf(over_max, water.water_surface[index] - water.heights[index])
			under_max = maxf(under_max, water.heights[index] - water.water_surface[index])

	print("river surface over ground at most %.1f m, under at most %.2f m, bad cells %d" % [over_max, under_max, bad_surface])
	_check(bad_surface == 0, "water surfaces are consistent with the ground")

	# The starter river reaches the bay head (when it is turned on; owner 2026-10-19: off).
	var path: PackedVector2Array = water.starter_path

	if bool(tile_rules["water"].get("starter_river", {}).get("enabled", false)):
		_check(path.size() > 50, "a starter river route was found (%d points)" % path.size())
	else:
		_check(path.is_empty(), "no designed starter river while it is turned off")

	if path.size() > 50:
		var mouth: Vector2 = path[path.size() - 1]
		var near_river: bool = false

		for dz in range(-40, 41):
			for dx in range(-40, 41):
				var column: int = int(mouth.x) + dx
				var row: int = int(mouth.y) + dz

				if column >= 0 and row >= 0 and column < water.samples and row < water.samples \
						and water.water_class[row * water.samples + column] == TileWaterScript.RIVER:
					near_river = true

		_check(near_river, "a river runs into the bay head")

	var again = TileWaterScript.new()
	again.setup(settings, tile_rules)
	again.build(height, starter)
	_check(again.heights == water.heights and again.water_class == water.water_class, "the tile water is reproducible")

	_test_tile_climate(settings, tile_rules, tile, water, elevation, sketch, starter)


func _test_tile_climate(settings, tile_rules: Dictionary, tile: Vector2i, water, elevation, sketch: Dictionary, starter: Dictionary) -> void:
	var tables = TableSetScript.new()
	_check(tables.load_directory().is_empty(), "tables load for the climate step")
	var climate = TileClimateScript.new()
	climate.setup(settings, tile_rules, tables)
	var started: int = Time.get_ticks_msec()
	climate.build(water.heights, water.water_class, tile.x * 1920, tile.y * 1920)
	print("tile climate built in %d ms, fertile land %.1f km2" % [Time.get_ticks_msec() - started, climate.fertile_km2])
	var total: int = water.samples * water.samples
	_check(climate.biome.size() == total and climate.soil.size() == total and climate.fertility.size() == total
		and climate.moisture.size() == total, "climate maps cover the tile")

	var biome_count: int = tables.get_entries("biomes").size()
	var soil_count: int = tables.get_entries("soils").size()
	var ocean: int = tables.id_of("biomes", "ocean")
	var bad: int = 0
	var water_fertile: int = 0
	var beach_near_sea: int = 0
	var wet_west: float = 0.0
	var dry_east: float = 0.0
	var west_cells: int = 0
	var east_cells: int = 0

	for j in range(0, water.samples, 4):
		for i in range(0, water.samples, 4):
			var index: int = j * water.samples + i

			if climate.biome[index] >= biome_count or climate.soil[index] >= soil_count:
				bad += 1

			if water.water_class[index] != 0:
				if climate.biome[index] != ocean or climate.fertility[index] != 0:
					water_fertile += 1
			elif water.heights[index] > 5.0:
				if i < water.samples / 3:
					wet_west += float(climate.moisture[index])
					west_cells += 1
				elif i > water.samples * 2 / 3:
					dry_east += float(climate.moisture[index])
					east_cells += 1

	_check(bad == 0, "every biome and soil id is in its table")
	_check(water_fertile == 0, "water cells are ocean biome with no fertility")
	_check(climate.biome_cells.has("beach"), "the tile has beaches")
	_check(climate.biome_cells.has("temperate_forest") and climate.biome_cells.has("temperate_grassland"),
		"the temperate tile has forest and grassland")
	_check(not climate.biome_cells.has("hot_desert") and not climate.biome_cells.has("glacier"),
		"a temperate tile has no desert or glacier")
	_check(climate.fertile_km2 > 1.0, "the starter tile has farmable fertile land (%.1f km2)" % climate.fertile_km2)

	var again = TileClimateScript.new()
	again.setup(settings, tile_rules, tables)
	again.build(water.heights, water.water_class, tile.x * 1920, tile.y * 1920)
	_check(again.biome == climate.biome and again.soil == climate.soil and again.fertility == climate.fertility
		and again.moisture == climate.moisture, "the climate maps are reproducible")

	var geology = _test_tile_geology(settings, tile_rules, tile, water, climate, elevation, sketch, tables)
	var built_sites = _test_tile_sites(settings, tile_rules, tile, water, climate, geology, tables, starter)
	_test_tile_file(settings, tile, water, climate, geology, built_sites)
	_test_runtime_terrain(settings, tile_rules, tables, tile, water, geology)
	_test_river_network()
	_test_wrap_noise()


func _test_tile_geology(settings, tile_rules: Dictionary, tile: Vector2i, water, climate, elevation, sketch: Dictionary, tables):
	var geology = TileGeologyScript.new()
	geology.setup(settings, tile_rules, tables, elevation, sketch)
	var started: int = Time.get_ticks_msec()
	geology.build(tile, water.heights, water.water_class, water.flow, climate.soil)
	print("tile geology built in %d ms: %d provinces, %d features, %d ore bodies" % [
		Time.get_ticks_msec() - started, geology.provinces.size(), geology.features.size(), geology.ore_bodies.size()
	])
	var samples: int = water.samples
	var total: int = samples * samples
	_check(geology.province.size() == total and geology.cover.size() == total and geology.layer_offset.size() == total
		and geology.surface_rock.size() == total, "geology maps cover the tile")

	var bad_province: int = 0

	for index in range(0, total, 7):
		if geology.province[index] >= geology.provinces.size():
			bad_province += 1

	_check(bad_province == 0, "every sample points at a listed province")

	# Names used in the lists exist in the tables.
	var unknown: Array = []

	for entry in geology.provinces:
		if tables.id_of("province_kinds", entry["kind"]) < 0:
			unknown.append(entry["kind"])

		for layer in entry["layers"]:
			if tables.id_of("rocks", layer["rock"]) < 0:
				unknown.append(layer["rock"])

		if tables.id_of("rocks", entry["base_rock"]) < 0:
			unknown.append(entry["base_rock"])

	for feature in geology.features:
		if tables.id_of("feature_types", str(feature["type"])) < 0:
			unknown.append(feature["type"])

	var ids: Dictionary = {}
	var duplicate_ids: int = 0
	var metals: Dictionary = {}

	for ore in geology.ore_bodies:
		if tables.id_of("resources", ore["resource"]) < 0:
			unknown.append(ore["resource"])

		if ids.has(ore["id"]):
			duplicate_ids += 1

		ids[ore["id"]] = true

		if tables.entry_of("resources", ore["resource"]).get("category", "") in ["metal", "precious"]:
			metals[ore["resource"]] = true

	for feature in geology.features:
		if ids.has(feature["id"]):
			duplicate_ids += 1

		ids[feature["id"]] = true

	_check(unknown.is_empty(), "geology names are all in the tables %s" % str(unknown))
	_check(duplicate_ids == 0, "feature and ore ids are unique in the tile")
	_check(geology.ore_bodies.size() >= 10, "the starter tile has ore bodies (%d)" % geology.ore_bodies.size())
	_check(metals.size() >= 3, "the starter tile has at least three metals %s" % str(metals.keys()))

	# Cover: bare rock has none, sea floor has some.
	var bare: int = tables.id_of("soils", "bare_rock")
	var bad_cover: int = 0

	for index in range(0, total, 5):
		if water.water_class[index] == 0 and climate.soil[index] == bare and geology.cover[index] != 0:
			bad_cover += 1
		elif water.water_class[index] == 1 and geology.cover[index] == 0:
			bad_cover += 1

	_check(bad_cover == 0, "cover depth is zero on bare rock and present on the sea floor")

	# Reproducible.
	var again = TileGeologyScript.new()
	again.setup(settings, tile_rules, tables, elevation, sketch)
	again.build(tile, water.heights, water.water_class, water.flow, climate.soil)
	_check(again.province == geology.province and again.layer_offset == geology.layer_offset
		and again.cover == geology.cover and again.surface_rock == geology.surface_rock
		and str(again.ore_bodies) == str(geology.ore_bodies), "geology is reproducible")

	# The east neighbor agrees on the shared edge: same province, same layer
	# offset, and the same feature and ore records where both list them.
	var east = TileGeologyScript.new()
	east.setup(settings, tile_rules, tables, elevation, sketch)
	var blank_heights: PackedFloat32Array = PackedFloat32Array()
	blank_heights.resize(total)
	var blank_bytes: PackedByteArray = PackedByteArray()
	blank_bytes.resize(total)
	east.build(tile + Vector2i(1, 0), blank_heights, blank_bytes, blank_heights, blank_bytes)
	var edge_mismatch: int = 0

	for j in range(samples):
		var mine: int = j * samples + samples - 1
		var theirs: int = j * samples

		if geology.provinces[geology.province[mine]]["id"] != east.provinces[east.province[theirs]]["id"] \
				or geology.layer_offset[mine] != east.layer_offset[theirs]:
			edge_mismatch += 1

	_check(edge_mismatch == 0, "geology matches the east neighbor along the edge (%d mismatches)" % edge_mismatch)

	var by_id: Dictionary = {}

	for feature in east.features:
		by_id[feature["id"]] = feature

	for ore in east.ore_bodies:
		if str(ore["shape"]) != "placer":
			by_id[ore["id"]] = ore

	var shared: int = 0
	var differing: int = 0

	for item in geology.features + geology.ore_bodies:
		if by_id.has(item["id"]):
			shared += 1

			if str(by_id[item["id"]]) != str(item):
				differing += 1

	_check(shared > 0 and differing == 0, "shared features and ore bodies are identical in both tiles (%d shared)" % shared)
	return geology


func _test_tile_sites(settings, tile_rules: Dictionary, tile: Vector2i, water, climate, geology, tables, starter: Dictionary):
	var mouth: Vector2 = Vector2(NAN, NAN)

	if water.starter_path.size() > 0:
		mouth = Vector2(float(tile.x), float(tile.y)) * float(settings.tile_size_m) \
			+ water.starter_path[water.starter_path.size() - 1] * float(settings.map_spacing_m)

	var sites = TileSitesScript.new()
	sites.setup(settings, tile_rules, tables)
	var started: int = Time.get_ticks_msec()
	sites.build(tile, water.heights, water.water_class, climate.soil, geology, starter, mouth)
	print("tile sites built in %d ms: %d caves, %d lairs" % [Time.get_ticks_msec() - started, sites.caves.size(), sites.lairs.size()])
	var rules: Dictionary = tile_rules["sites"]
	var samples: int = water.samples
	var spacing: float = float(settings.map_spacing_m)
	var origin: Vector2 = Vector2(float(tile.x), float(tile.y)) * float(settings.tile_size_m)
	var margin: float = float(rules["edge_margin_m"]) - 1.0
	var tile_m: float = float(settings.tile_size_m)
	var karst: int = 0
	var outside: int = 0
	var thin_roof: int = 0
	var bad_links: int = 0
	var bad_tiers: int = 0
	var exposed: int = 0
	var unknown_ore: int = 0
	var near_town: int = 0
	var segment_types: Array = ["passage", "squeeze", "shaft", "water", "ledge"]
	var ore_ids: Dictionary = {}
	var ids: Dictionary = {}
	var duplicate_ids: int = 0

	for ore in geology.ore_bodies:
		ore_ids[ore["id"]] = true
		ids[ore["id"]] = true

	for feature in geology.features:
		ids[feature["id"]] = true

	var keep_clear: Array = []

	for key in ["spawn_point", "town_block"]:
		if sites.starter.has(key):
			keep_clear.append(Vector2(float(sites.starter[key][0]), float(sites.starter[key][2])))

	for cave in sites.caves:
		if ids.has(cave["id"]):
			duplicate_ids += 1

		ids[cave["id"]] = true

		if str(cave["cave_kind"]) == "karst":
			karst += 1

		var nodes: Array = cave["nodes"]

		for n in range(nodes.size()):
			var node: Array = nodes[n]
			var p: Vector2 = Vector2(float(node[0]), float(node[2]))

			if p.x < origin.x + margin or p.y < origin.y + margin or p.x > origin.x + tile_m - margin or p.y > origin.y + tile_m - margin:
				outside += 1
				continue

			if cave["entrances"].has(n):
				for spot in keep_clear:
					if p.distance_to(spot) < float(rules["town_clear_m"]):
						near_town += 1

				continue

			var index: int = int(round((p.y - origin.y) / spacing)) * samples + int(round((p.x - origin.x) / spacing))

			if float(node[1]) + 0.5 * float(node[4]) > water.heights[index] - 1.0:
				thin_roof += 1

		for segment in cave["segments"]:
			if int(segment[0]) >= nodes.size() or int(segment[1]) >= nodes.size() or not segment_types.has(str(segment[2])):
				bad_links += 1

		for den in cave["dens"]:
			if int(den["tier"]) < 1 or int(den["tier"]) > 2:
				bad_tiers += 1

		if not cave["exposes"].is_empty():
			exposed += 1

		for ore_id in cave["exposes"]:
			if not ore_ids.has(ore_id):
				unknown_ore += 1

	_check(sites.caves.size() >= 8 and karst >= 5, "the starter tile has caves (%d, %d limestone)" % [sites.caves.size(), karst])
	_check(outside == 0, "cave nodes stay inside the tile margin")
	_check(thin_roof == 0, "cave passages stay under the ground away from entrances (%d too shallow)" % thin_roof)
	_check(bad_links == 0, "cave segments join real nodes with known types")
	_check(bad_tiers == 0, "starter tile dens are low tier (1 or 2)")
	_check(exposed > 0 and unknown_ore == 0, "some caves expose ore bodies (%d)" % exposed)
	_check(near_town == 0, "no cave opens near the starter spawn or town block")
	_check(duplicate_ids == 0, "site ids do not clash with geology ids")
	_check(sites.starter.has("spawn_point") and sites.starter.has("town_block") and not sites.harbor.is_empty(),
		"the starter tile has a spawn point, town block and harbor")

	var lair_ok: bool = true
	var cave_ids: Dictionary = {}

	for cave in sites.caves:
		cave_ids[cave["id"]] = true

	for lair in sites.lairs:
		lair_ok = lair_ok and cave_ids.has(lair["cave"])

	_check(not sites.lairs.is_empty() and lair_ok, "dormant lair sites point at caves")

	var again = TileSitesScript.new()
	again.setup(settings, tile_rules, tables)
	again.build(tile, water.heights, water.water_class, climate.soil, geology, starter, mouth)
	_check(str(again.caves) == str(sites.caves) and str(again.lairs) == str(sites.lairs) and str(again.starter) == str(sites.starter),
		"sites are reproducible")
	return sites


func _test_tile_erosion(settings, elevation) -> void:
	var errors: Array = []
	var tile_rules: Dictionary = TileHeightScript.load_rules("res://worlds/base_world/plan/tile_rules.json", errors)
	var height = TileHeightScript.new()
	height.setup(settings, elevation, tile_rules)
	height.build(Vector2i(3, 4))
	var erosion = TileErosionScript.new()
	erosion.setup(settings, tile_rules)
	var started: int = Time.get_ticks_msec()
	erosion.build(height)
	print("tile erosion in %d ms: deepest cut %.1f m" % [Time.get_ticks_msec() - started, erosion.deepest_cut_m])
	_check(erosion.deepest_cut_m > 10.0, "erosion cuts valleys")

	var n: int = height.samples
	var edges_same: bool = true
	var sea_same: bool = true
	var land_kept: bool = true

	for k in range(n):
		for index in [k, (n - 1) * n + k, k * n, k * n + n - 1]:
			if erosion.heights[index] != height.heights[index]:
				edges_same = false

	for index in range(n * n):
		var before: float = height.heights[index]

		if before <= 0.0 and erosion.heights[index] != before:
			sea_same = false

		if before > 0.0 and erosion.heights[index] <= 0.0:
			land_kept = false

	_check(edges_same, "erosion leaves tile edges unchanged so neighbors match")
	_check(sea_same, "erosion leaves the sea floor alone")
	_check(land_kept, "erosion never turns land into sea")

	var again = TileErosionScript.new()
	again.setup(settings, tile_rules)
	again.build(height)
	_check(again.heights == erosion.heights, "erosion is reproducible")


# A tiny sloped world: sea in the west column, land rising eastwards. The
# river network must find a river that reaches the sea.
class FakeElevation:
	extends RefCounted
	var size_x: int = 24
	var size_z: int = 24
	var cell_m: float = 160.0
	var origin_x: float = 0.0
	var origin_z: float = 0.0
	var heights: PackedFloat32Array = PackedFloat32Array()


func _test_wrap_noise() -> void:
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 2
	noise.frequency = 8.0 / 260.0
	var period: int = 21 * 1280
	var start: int = -10 * 1280
	var east: PackedByteArray = WrapNoiseScript.bytes(noise, start + period - 40, start + period - 30, 80, 60, start, start, period, period, 130)
	var west: PackedByteArray = WrapNoiseScript.bytes(noise, start - 40, start - 30, 80, 60, start, start, period, period, 130)
	var worst: int = 0

	for k in range(east.size()):
		worst = maxi(worst, absi(int(east[k]) - int(west[k])))

	_check(worst <= 1, "wrap noise repeats across the world seam, east and west corners (worst %d)" % worst)
	var plain: PackedByteArray = WrapNoiseScript.bytes(noise, 100, 100, 40, 40, start, start, period, period, 130)
	noise.offset = Vector3(100, 100, 0)
	var image: Image = noise.get_image(40, 40, false, false, false)

	if image.get_format() != Image.FORMAT_L8:
		image.convert(Image.FORMAT_L8)

	_check(plain == image.get_data(), "wrap noise is the plain noise image away from the seam")


func _test_river_network() -> void:
	var fake := FakeElevation.new()
	fake.heights.resize(fake.size_x * fake.size_z)

	for z in range(fake.size_z):
		for x in range(fake.size_x):
			fake.heights[z * fake.size_x + x] = -5.0 if x < 2 else 10.0 + 5.0 * float(x) + 0.3 * absf(float(z) - 12.0)

	var network = RiverNetworkScript.new()
	network.build(fake, 0.5)
	_check(network.river_cells > 0 and network.chains.size() > 0, "the river network finds rivers on a sloped world")
	var guides: Array = network.guides_in(Rect2(0, 0, 24.0 * 160.0, 24.0 * 160.0), 4.0)
	_check(guides.size() > 0, "a tile frame over the whole world gets river guides")
	var biggest: float = 0.0

	for guide in guides:
		for area in guide["areas"]:
			biggest = maxf(biggest, area)

	_check(biggest > 0.5, "river guides carry a drainage area")
	var again = RiverNetworkScript.new()
	again.build(fake, 0.5)
	_check(again.chains.size() == network.chains.size() and again.river_cells == network.river_cells, "the river network is reproducible")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	network.set_meander([{"wavelength_m": 900, "amplitude_m": 40}], rng)
	var world_w: float = 24.0 * 160.0
	var seam_gap: float = 0.0
	var biggest_push: float = 0.0

	for k in range(50):
		var x: float = 37.0 * float(k)
		var z: float = 61.0 * float(k)
		var push: Vector2 = network.meander_offset(x, z)
		biggest_push = maxf(biggest_push, push.length())
		seam_gap = maxf(seam_gap, push.distance_to(network.meander_offset(x + world_w, z - world_w)))

	_check(seam_gap < 0.01, "the river meander repeats exactly across the world wrap (gap %.4f m)" % seam_gap)
	_check(biggest_push > 5.0 and biggest_push < 200.0, "the river meander pushes curves sideways (%.0f m)" % biggest_push)


# The runtime terrain generator (plan step 14) on the tile file written by
# _test_tile_file.
func _test_runtime_terrain(settings, tile_rules: Dictionary, tables, tile: Vector2i, water, geology) -> void:
	var dir: String = "user://test_tiles"
	var target: String = "%s/tile_%d_%d.tile" % [dir, tile.x, tile.y]
	_check(FileAccess.file_exists(target), "the test tile file is there for the terrain generator")
	var generator = TerrainGeneratorScript.new()
	var plain_rules: Dictionary = tile_rules.duplicate(true)      # without the simulated-water channel cutting
	plain_rules["runtime_terrain"].erase("sim_water")
	generator.setup(settings, plain_rules, tables, dir)
	var data = generator.get_tile(tile)
	_check(not data.placeholder, "the terrain generator loads the tile file")
	_check(data.prov_datum.size() == geology.provinces.size(), "the terrain generator reads every province")
	var samples: int = water.samples
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 14

	# On grid points the interpolated height is the stored height.
	var worst: float = 0.0

	for n in range(300):
		var i: int = rng.randi_range(2, samples - 3)
		var j: int = rng.randi_range(2, samples - 3)
		var x: float = data.x0 + float(i) * data.spacing_m
		var z: float = data.z0 + float(j) * data.spacing_m
		worst = maxf(worst, absf(data.height_at(x, z) - water.heights[j * samples + i]))

	_check(worst < 0.06, "the generator's height matches the height map on grid points (worst %.3f m)" % worst)

	# Detail noise made as images matches the column-by-column noise.
	var x_mid: float = data.x0 + 7000.0
	var z_mid: float = data.z0 + 7000.0
	var grid: PackedFloat32Array = generator._detail_grid(x_mid, z_mid, 8, 1, 1.0)
	var grid_gap: float = 0.0

	for n in range(8):
		var dry: float = 1.0 - data.wet_at(x_mid + float(n), z_mid)

		if dry > 0.99:
			grid_gap = maxf(grid_gap, absf(grid[n] - generator._detail_at(data, x_mid + float(n), z_mid, 1.0)))

	_check(grid_gap < 0.02, "detail noise images match the per-column noise (gap %.3f m)" % grid_gap)

	# The world wraps.
	var period: float = generator.period_m
	_check(_approx(generator.surface_height(x_mid, z_mid), generator.surface_height(x_mid + period, z_mid - period), 0.01),
		"terrain height repeats one world width away")
	_check(_approx(generator.surface_height(-153590.0, 5.0), float(tile_rules["runtime_terrain"]["placeholder_depth_m"]), 0.001),
		"a tile with no file is open sea at the placeholder depth")

	# Rock under the ground agrees with the baked bedrock-surface map.
	var agree: int = 0
	var tested: int = 0

	for n in range(120):
		var i: int = rng.randi_range(4, samples - 5)
		var j: int = rng.randi_range(4, samples - 5)
		var index: int = j * samples + i

		if water.heights[index] <= 2.0:
			continue

		var x: int = int(data.x0) + i * 8
		var z: int = int(data.z0) + j * 8
		var bed: float = generator.surface_height(float(x), float(z)) - data.cover_at(float(x), float(z))
		var y: int = int(floor(bed - 2.0))
		var buffer: VoxelBuffer = TerrainLayout.make_buffer(16)
		var origin: Vector3i = Vector3i(x - 8, y - 8, z - 8)
		generator.generate(buffer, origin, 0)
		tested += 1

		if buffer.get_voxel(8, 8, 8, TerrainLayout.CHANNEL_ROCK) == geology.surface_rock[index]:
			agree += 1

	_check(tested > 30 and float(agree) >= 0.9 * float(tested), "runtime rock just under the bedrock surface matches the baked map (%d of %d)" % [agree, tested])

	# Air high up, solid rock deep down, and the same block twice.
	var air: VoxelBuffer = TerrainLayout.make_buffer()
	generator.generate(air, Vector3i(int(x_mid), 1500, int(z_mid)), 0)
	_check(air.get_voxel_f(5, 5, 5, TerrainLayout.CHANNEL_SDF) > 0.0 and air.get_voxel(5, 5, 5, TerrainLayout.CHANNEL_ROCK) == 0, "blocks high above the ground are air")
	var deep: VoxelBuffer = TerrainLayout.make_buffer()
	generator.generate(deep, Vector3i(int(x_mid), -2000, int(z_mid)), 0)
	var solid: bool = true

	for k in range(0, 32, 5):
		for i in range(0, 32, 5):
			for j in range(0, 32, 5):
				if deep.get_voxel_f(i, j, k, TerrainLayout.CHANNEL_SDF) >= 0.0 or deep.get_voxel(i, j, k, TerrainLayout.CHANNEL_ROCK) == 0:
					solid = false

	_check(solid, "blocks 2 km down are solid rock")
	var h_mid: float = generator.surface_height(x_mid, z_mid)
	var first: VoxelBuffer = TerrainLayout.make_buffer()
	var second: VoxelBuffer = TerrainLayout.make_buffer()
	var surface_origin: Vector3i = Vector3i(int(x_mid), int(floor(h_mid)) - 16, int(z_mid))
	generator.generate(first, surface_origin, 0)
	generator.generate(second, surface_origin, 0)
	var same: bool = true
	var crossings: int = 0

	for k in range(32):
		for i in range(32):
			for j in range(32):
				var a: float = first.get_voxel_f(i, j, k, TerrainLayout.CHANNEL_SDF)

				if a != second.get_voxel_f(i, j, k, TerrainLayout.CHANNEL_SDF) or first.get_voxel(i, j, k, TerrainLayout.CHANNEL_ROCK) != second.get_voxel(i, j, k, TerrainLayout.CHANNEL_ROCK):
					same = false

				if j > 0 and (a < 0.0) != (first.get_voxel_f(i, j - 1, k, TerrainLayout.CHANNEL_SDF) < 0.0):
					crossings += 1

	_check(same, "a block generates the same twice")
	_check(crossings >= 1024, "every column of a surface block crosses the ground (%d)" % crossings)

	# A cave chamber is hollow; an ore lens holds its resource.
	var hollow: int = 0
	var chambers: int = 0

	for cave in data.caves:
		for chamber in cave["chambers"]:
			var c: Vector3 = chamber["center"]

			if c.y > generator.surface_height(c.x, c.z) - 4.0:
				continue

			chambers += 1
			var buffer: VoxelBuffer = TerrainLayout.make_buffer(8)
			generator.generate(buffer, Vector3i(int(floor(c.x)) - 4, int(floor(c.y)) - 4, int(floor(c.z)) - 4), 0)

			if buffer.get_voxel_f(4, 4, 4, TerrainLayout.CHANNEL_SDF) > 0.0 and buffer.get_voxel(4, 4, 4, TerrainLayout.CHANNEL_ROCK) == 0:
				hollow += 1

	_check(chambers > 0 and hollow == chambers, "cave chambers are carved out (%d of %d)" % [hollow, chambers])
	var lenses: int = 0
	var found: int = 0

	for ore in data.ores:
		if str(ore["shape"]) != "lens":
			continue

		var c: Vector3 = Vector3(float(ore["center"][0]), float(ore["center"][1]), float(ore["center"][2]))
		var inside_tile: bool = c.x > data.x0 + 8.0 and c.z > data.z0 + 8.0 and c.x < data.x0 + 15350.0 and c.z < data.z0 + 15350.0

		if not inside_tile or c.y > generator.surface_height(c.x, c.z) - 10.0:
			continue

		lenses += 1
		var buffer: VoxelBuffer = TerrainLayout.make_buffer(8)
		generator.generate(buffer, Vector3i(int(floor(c.x)) - 4, int(floor(c.y)) - 4, int(floor(c.z)) - 4), 0)

		# Caves steered to an ore body may have hollowed out its middle.
		if buffer.get_voxel(4, 4, 4, TerrainLayout.CHANNEL_RESOURCE) == int(ore["resource_id"]) or buffer.get_voxel_f(4, 4, 4, TerrainLayout.CHANNEL_SDF) > 0.0:
			found += 1

	_check(lenses == 0 or found == lenses, "ore lenses hold their resource at the center unless a cave reached it (%d of %d)" % [found, lenses])
	_test_ground_material(generator, data, tables)
	_test_streaming(generator, data)
	_test_flora(generator, data, tables, tile_rules)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(target))


static func _remove_tree(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)

	if not DirAccess.dir_exists_absolute(absolute):
		return

	for file in DirAccess.get_files_at(absolute):
		DirAccess.remove_absolute(absolute + "/" + file)

	for sub in DirAccess.get_directories_at(absolute):
		_remove_tree(absolute + "/" + sub)

	DirAccess.remove_absolute(absolute)


# The ground material drawn by clients: the soil of each column's top, or
# its rock where no soil covers it, all the way down the column.
func _test_ground_material(generator, data, tables) -> void:
	var columns: int = 0
	var right: int = 0
	var bare: int = 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 77

	for n in range(40):
		var x: float = data.x0 + rng.randf_range(200.0, 15000.0)
		var z: float = data.z0 + rng.randf_range(200.0, 15000.0)
		var h: float = generator.surface_height(x, z)
		var buffer: VoxelBuffer = TerrainLayout.make_buffer(8)
		var origin: Vector3i = Vector3i(int(floor(x)) - 4, int(floor(h)) - 4, int(floor(z)) - 4)
		generator.generate(buffer, origin, 0)
		var soil: int = data.soil[data.nearest(float(origin.x + 4), float(origin.z + 4))]
		var material: int = buffer.get_voxel(4, 7, 4, TerrainLayout.CHANNEL_MATERIAL)
		var column_same: bool = material == buffer.get_voxel(4, 6, 4, TerrainLayout.CHANNEL_MATERIAL)
		columns += 1

		# Bank bands beside water repaint the soil (mud, clay, alluvium): tested with the water.
		if data.near_water()[data.nearest(float(origin.x + 4), float(origin.z + 4))] > 0:
			right += 1
			continue

		if soil > 0:
			if material == soil and column_same:
				right += 1
		else:
			bare += 1

			if material > TerrainLayout.MATERIAL_ROCK and column_same:
				right += 1

	_check(right == columns, "each column is drawn in its soil, or its rock where bare (%d of %d, %d bare)" % [right, columns, bare])
	# Deep down, every solid voxel is drawn as its own rock.
	var deep: VoxelBuffer = TerrainLayout.make_buffer(16)
	var x_deep: float = data.x0 + 7000.0
	var z_deep: float = data.z0 + 7000.0
	generator.generate(deep, Vector3i(int(x_deep), int(generator.surface_height(x_deep, z_deep)) - 120, int(z_deep)), 0)
	var solid: int = 0
	var as_rock: int = 0

	for kk in range(16):
		for jj in range(16):
			for ii in range(16):
				var rock: int = deep.get_voxel(ii, jj, kk, TerrainLayout.CHANNEL_ROCK)

				if rock == 0:
					continue

				solid += 1

				if deep.get_voxel(ii, jj, kk, TerrainLayout.CHANNEL_MATERIAL) == TerrainLayout.MATERIAL_ROCK + rock:
					as_rock += 1

	_check(solid > 0 and as_rock == solid, "deep rock is drawn as its own rock, so caves and holes show stone (%d of %d)" % [as_rock, solid])
	var palette: PackedVector3Array = GroundMaterialScript.palette(tables)
	var colored: bool = palette.size() == GroundMaterialScript.PALETTE_SIZE

	for entry in tables.get_entries("soils"):
		colored = colored and entry.has("color") and palette[int(entry["id"])].is_equal_approx(Vector3(entry["color"][0], entry["color"][1], entry["color"][2]))

	for entry in tables.get_entries("rocks"):
		colored = colored and entry.has("color") and int(entry["id"]) + TerrainLayout.MATERIAL_ROCK < palette.size()

	_check(colored, "every soil and rock has a color in the ground palette")


# Plan step 16: the server store, the client cache and the client stream,
# without a network.
func _test_streaming(generator, data) -> void:
	var root: String = "user://test_stream"
	_remove_tree(root)

	# A block survives the trip through the serializer.
	var x_mid: float = data.x0 + 7000.0
	var z_mid: float = data.z0 + 7000.0
	var h_mid: float = generator.surface_height(x_mid, z_mid)
	var block: Vector3i = Vector3i(int(floor(x_mid / 16.0)), int(floor(h_mid / 16.0)), int(floor(z_mid / 16.0)))
	var original: VoxelBuffer = TerrainLayout.make_buffer(16)
	generator.generate(original, block * 16, 0)
	var bytes: PackedByteArray = VoxelBlockSerializer.serialize_to_byte_array(original, VoxelBlockSerializer.COMPRESSION_ZSTD)
	var copy: VoxelBuffer = TerrainLayout.make_buffer(16)
	VoxelBlockSerializer.deserialize_from_byte_array(bytes, copy, true)
	var same: bool = true

	for k in range(16):
		for j in range(16):
			for i in range(16):
				for channel in [TerrainLayout.CHANNEL_ROCK, TerrainLayout.CHANNEL_SOIL, TerrainLayout.CHANNEL_RESOURCE, TerrainLayout.CHANNEL_MATERIAL]:
					if original.get_voxel(i, j, k, channel) != copy.get_voxel(i, j, k, channel):
						same = false

				if absf(original.get_voxel_f(i, j, k, TerrainLayout.CHANNEL_SDF) - copy.get_voxel_f(i, j, k, TerrainLayout.CHANNEL_SDF)) > 0.001:
					same = false

	_check(same, "a block comes through the serializer unchanged (%d bytes)" % bytes.size())

	# Ore deeper than the limit is hidden; ore near a surface stays.
	var ore: VoxelBuffer = TerrainLayout.make_buffer(16)
	ore.fill_f(-3.0, TerrainLayout.CHANNEL_SDF)
	ore.set_voxel(7, 1, 1, 1, TerrainLayout.CHANNEL_RESOURCE)
	ore.set_voxel_f(-1.0, 2, 2, 2, TerrainLayout.CHANNEL_SDF)
	ore.set_voxel(7, 2, 2, 2, TerrainLayout.CHANNEL_RESOURCE)
	ServerStoreScript.hide_buried_ore(ore, 2.0)
	_check(ore.get_voxel(1, 1, 1, TerrainLayout.CHANNEL_RESOURCE) == 0 and ore.get_voxel(2, 2, 2, TerrainLayout.CHANNEL_RESOURCE) == 7,
		"buried ore is hidden from clients and ore near a surface is not")

	# The server store makes a block once, then serves its cache, then edits.
	var store = ServerStoreScript.new()
	_check(store.setup(generator, root + "/server") == "", "the server store opens")
	var first: PackedByteArray = store.block_bytes(block, 0)
	var second: PackedByteArray = store.block_bytes(block, 0)
	_check(store.blocks_generated == 1 and store.cache_hits == 1 and first == second, "the server makes a block once and then serves it from its cache")
	var center: Vector3 = Vector3(x_mid, h_mid - 3.0, z_mid)
	var tile: Vector2i = generator.tile_of(x_mid, z_mid)
	var tiles: Array = store.dig_sphere(center, 4.0)
	_check(tiles == [tile] and store.revision_of(tile) == 2, "a dig raises its tile's revision")
	var dug: VoxelBuffer = TerrainLayout.make_buffer(16)
	var dug_block: Vector3i = Vector3i((center / 16.0).floor())
	store.load_block(dug, dug_block, 0)
	var inside: Vector3i = Vector3i(center.floor()) - dug_block * 16
	_check(dug.get_voxel_f(inside.x, inside.y, inside.z, TerrainLayout.CHANNEL_SDF) > 0.0,
		"the dug block is open at the dig")
	store.flush()
	var reopened = ServerStoreScript.new()
	reopened.setup(generator, root + "/server")
	_check(reopened.revision_of(tile) == 2, "tile revisions survive a server restart")
	# A re-bake throws the generated ground away; the saved dig replays over the new ground.
	reopened.clear_generated()
	var replayed: VoxelBuffer = TerrainLayout.make_buffer(16)
	reopened.load_block(replayed, dug_block, 0)
	_check(reopened.ops.count == 1 and replayed.get_voxel_f(inside.x, inside.y, inside.z, TerrainLayout.CHANNEL_SDF) > 0.0,
		"a saved dig survives a restart and a re-bake")

	# The client cache: hits, stale revisions and the size limit.
	var world: Dictionary = {"tile_size_m": generator.tile_size_m, "min_tile": generator.min_tile, "tiles_per_side": int(round(generator.period_m / generator.tile_size_m))}
	var cache = ClientCacheScript.new()
	cache.setup(root + "/client", world, {}, 2048)
	_check(cache.tile_of_block(block, 0) == tile and cache.tile_of_block(block + Vector3i(int(generator.period_m / 16.0), 0, 0), 0) == tile,
		"the client cache files a block under its tile, across the wrap")
	cache.save_block(original, block, 0)
	cache.flush()
	var cached: VoxelBuffer = TerrainLayout.make_buffer(16)
	_check(cache.load_block(cached, block, 0) and cached.get_voxel(3, 3, 3, TerrainLayout.CHANNEL_ROCK) == original.get_voxel(3, 3, 3, TerrainLayout.CHANNEL_ROCK),
		"the client cache returns a saved block")
	cache.set_revision(tile, 2)
	_check(not cache.load_block(cached, block, 0), "a newer tile revision empties that tile from the client cache")
	var tile_blocks: int = int(generator.tile_size_m / 16.0)

	for step in [0, 1, 5, 8]:
		cache.save_block(original, block + Vector3i(step * tile_blocks, 0, 0), 0)

	cache.flush()
	cache.budget_bytes = 0
	var removed: int = cache.enforce_budget(tile)
	cache.budget_bytes = 2048 * 1024 * 1024
	_check(removed == 2 and cache.load_block(cached, block, 0) and cache.load_block(cached, block + Vector3i(tile_blocks, 0, 0), 0)
		and not cache.load_block(cached, block + Vector3i(8 * tile_blocks, 0, 0), 0),
		"over its size limit the client cache drops far tiles and keeps the near ones (%d dropped)" % removed)

	# The client stream: a prefetched block is used without asking again.
	var stream = NetworkStreamScript.new()
	stream.cache = cache
	var far: Vector3i = block + Vector3i(0, 0, 3 * tile_blocks)
	var sent: PackedByteArray = bytes.duplicate()          # as the server sends it: the block plus its checksum
	var check: PackedByteArray = PackedByteArray()
	check.resize(4)
	check.encode_u32(0, hash(bytes) & 0xffffffff)
	sent.append_array(check)
	stream.deliver(PackedInt32Array([far.x, far.y, far.z, 0]), [sent])
	var streamed: VoxelBuffer = TerrainLayout.make_buffer(16)
	var result: int = stream._load_voxel_block(streamed, far, 0)
	var keys: Array = stream.take_requests()
	_check(result == VoxelStream.RESULT_BLOCK_FOUND and stream.prefetch_used == 1 and keys[0].is_empty()
		and streamed.get_voxel(3, 3, 3, TerrainLayout.CHANNEL_ROCK) == original.get_voxel(3, 3, 3, TerrainLayout.CHANNEL_ROCK),
		"the client stream uses a prefetched block without asking the server")
	_check(cache.load_block(cached, far, 0), "a streamed block goes into the client cache")
	cache.flush()
	_remove_tree(root)


# Plan step 15: runtime flora placement and the server's removals.
func _test_flora(generator, data, tables, tile_rules: Dictionary) -> void:
	var biome_names: Dictionary = {}
	var water_names: Dictionary = {}

	for entry in tables.get_entries("biomes"):
		biome_names[str(entry["name"])] = int(entry["id"])

	for entry in tables.get_entries("water_classes"):
		water_names[str(entry["name"])] = true

	var bad_names: Array = []

	for entry in tables.get_entries("flora"):
		for name in entry["per_hectare"]:
			if not biome_names.has(name):
				bad_names.append(name)

		for name in entry.get("water", []):
			if not water_names.has(name):
				bad_names.append(name)

	_check(tables.get_entries("flora").size() > 20 and bad_names.is_empty(), "the flora table names only real biomes and water classes %s" % str(bad_names))
	var placer = FloraPlacerScript.new()
	placer.setup(generator, tables, tile_rules)

	# Grove species (everember) grow only in groves, which are stable and sized as the table says.
	var ever: Dictionary = placer.species_by_id(122)
	var grove_count: int = 0
	var grove_ok: bool = ever.has("grove")

	if grove_ok:
		# Every chunk of a 12 km square (nine grove squares).
		for gz in range(47):
			for gx in range(47):
				var at: Vector2 = Vector2(float(gx) * 256.0, float(gz) * 256.0)
				var groves: Array = placer._groves_near(ever, ever["grove"], placer._grove_seed, 122, at)
				grove_ok = grove_ok and str(groves) == str(placer._groves_near(ever, ever["grove"], placer._grove_seed, 122, at))

				for g in groves:
					grove_count += 1
					grove_ok = grove_ok and g[1] >= 90.0 and g[1] <= 150.0 and placer._in_grove([g], g[0].x, g[0].y) and not placer._in_grove([g], g[0].x + 200.0, g[0].y)

	_check(grove_ok and grove_count > 0, "everember groves are stable, 90 to 150 m across in radius, and found (%d)" % grove_count)

	# The most wooded of a few chunks in the middle of the tile.
	var best: Vector2i = Vector2i.ZERO
	var items: Dictionary = {}
	var best_trees: int = -1

	for n in range(6):
		var chunk: Vector2i = placer.chunk_of(data.x0 + 4000.0 + 1100.0 * n, data.z0 + 4000.0 + 900.0 * n)
		var found: Dictionary = placer.chunk_items(chunk)
		var found_trees: int = 0

		for id in found["ids"]:
			if placer.species_of(id)["kind"] == FloraPlacerScript.KIND_TREE:
				found_trees += 1

		if found_trees > best_trees:
			best = chunk
			items = found
			best_trees = found_trees

	var ids: PackedInt32Array = items["ids"]
	var trees: int = 0
	var ok_place: bool = true
	var unique: Dictionary = {}
	var origin: Vector2 = placer.chunk_origin(best)

	for n in range(ids.size()):
		var item: Dictionary = placer.species_of(ids[n])
		var p: Vector3 = items["positions"][n]
		var k: int = data.nearest(p.x, p.z)
		unique[ids[n]] = true

		if item["kind"] == FloraPlacerScript.KIND_TREE:
			trees += 1

		if p.x < origin.x or p.z < origin.y or p.x >= origin.x + placer.chunk_m or p.z >= origin.y + placer.chunk_m:
			ok_place = false

		if absf(p.y - generator.surface_height(p.x, p.z)) > 0.01 or item["per_biome"][data.biome[k]] <= 0.0:
			ok_place = false

		if data.water_class[k] != 0 and (item["water_mask"] & (1 << data.water_class[k])) == 0:
			ok_place = false

	_check(ids.size() > 500 and trees > 20, "a land chunk holds trees and plants (%d items, %d trees)" % [ids.size(), trees])
	_check(ok_place, "flora sits on the ground inside its chunk, in a biome and water class it allows")
	_check(unique.size() == ids.size(), "flora item ids are unique in their chunk")
	var crowded: int = 0

	for a in range(ids.size()):
		var sa: Dictionary = placer.species_of(ids[a])

		if sa["kind"] == FloraPlacerScript.KIND_PLANT:
			continue

		for b in range(a + 1, ids.size()):
			var sb: Dictionary = placer.species_of(ids[b])

			if sb["kind"] == FloraPlacerScript.KIND_PLANT:
				continue

			var stand_a: float = float(sa["stand"]["spacing_m"]) if (ids[a] & 0xffff) >= FloraPlacerScript.STAND_BASE and sa.has("stand") else 0.0
			var stand_b: float = float(sb["stand"]["spacing_m"]) if (ids[b] & 0xffff) >= FloraPlacerScript.STAND_BASE and sb.has("stand") else 0.0
			var gap: float = FloraPlacerScript.min_gap(sa["kind"], FloraPlacerScript.spacing_radius(sa, items["heights"][a]), stand_a, ids[a] >> 16, sb["kind"], FloraPlacerScript.spacing_radius(sb, items["heights"][b]), stand_b, ids[b] >> 16)
			var pa: Vector3 = items["positions"][a]
			var pb: Vector3 = items["positions"][b]

			if Vector2(pa.x - pb.x, pa.z - pb.z).length() < gap - 0.01:
				crowded += 1

	_check(crowded == 0, "tree and shrub crowns keep apart (%d too close)" % crowded)

	# Softwood belt (Dave 2026-10-24): trees per ground slope band (rise over run across 4 m), conifers against broadleaves.
	var bands: Array = [0.1, 0.2, 0.35, 99.0]
	var belt: Array = [[0, 0], [0, 0], [0, 0], [0, 0]]

	for n in range(ids.size()):
		var tree: Dictionary = placer.species_of(ids[n])

		if tree["kind"] != FloraPlacerScript.KIND_TREE or not (tree["shape"] in ["conifer", "broadleaf"]):
			continue

		var tp: Vector3 = items["positions"][n]
		var rise: float = Vector2(generator.surface_height(tp.x + 2.0, tp.z) - generator.surface_height(tp.x - 2.0, tp.z), generator.surface_height(tp.x, tp.z + 2.0) - generator.surface_height(tp.x, tp.z - 2.0)).length() / 4.0
		var band: int = 0

		while rise >= float(bands[band]):
			band += 1

		belt[band][0 if tree["shape"] == "conifer" else 1] += 1

	print("Tree belt (conifer/broadleaf by slope band <0.10, 0.10-0.20, 0.20-0.35, >0.35): %s" % str(belt))
	_check(belt[0][0] + belt[0][1] + belt[1][0] + belt[1][1] + belt[2][0] + belt[2][1] + belt[3][0] + belt[3][1] > 0, "the tree belt table counts trees in every slope band it reaches")
	var again: Dictionary = placer.chunk_items(best)
	_check(again["ids"] == ids and again["positions"] == items["positions"], "a chunk's flora is the same every time")
	var period_chunks: int = int(round(generator.period_m / placer.chunk_m))
	_check(placer.normalize(best + Vector2i(period_chunks, -period_chunks)) == best, "flora chunks wrap with the world")
	var decoded: Dictionary = FloraPlacerScript.decode(FloraPlacerScript.encode(items, origin), origin)
	var worst: float = 0.0

	for n in range(ids.size()):
		worst = maxf(worst, (decoded["positions"][n] - items["positions"][n]).length())

	_check(decoded["ids"] == ids and worst < 0.005, "flora survives packing for the network (worst %.4f m)" % worst)

	# Removals: stored, applied and kept over a restart.
	var root: String = "user://test_flora"
	_remove_tree(root)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var server = ServerFloraScript.new()
	server.setup(placer, root)
	var before: int = FloraPlacerScript.decode(server.chunk_bytes(best), origin)["ids"].size()
	_check(server.cut(best, ids[0]) and not server.cut(best, ids[0]) and not server.cut(best, 12345678), "the server cuts a real item once and refuses unknown ones")
	var after: Dictionary = FloraPlacerScript.decode(server.chunk_bytes(best), origin)
	_check(after["ids"].size() == before - 1 and after["ids"].find(ids[0]) < 0, "a cut item is gone from the chunk sent to clients")
	server.save_removed(true)       # since build 597 the server writes removals on its tick (at most once a second) and at exit, not per cut
	var restarted = ServerFloraScript.new()
	restarted.setup(placer, root)
	_check(restarted.removed_in(best) == [ids[0]] and not restarted.layout_cleared, "flora removals survive a server restart")
	# A save made under another flora layout is dropped (patches move plants); a save without a stamp counts as the first layout.
	var stale: Dictionary = {"layout": FloraLayoutScript.VERSION + 1, "%d,%d" % [best.x, best.y]: [ids[0]]}
	var stale_file: FileAccess = FileAccess.open(root + "/flora_removed.json", FileAccess.WRITE)
	stale_file.store_string(JSON.stringify(stale))
	stale_file.close()
	var moved = ServerFloraScript.new()
	moved.setup(placer, root)
	_check(moved.layout_cleared and moved.removed_in(best).is_empty(), "removals made under another flora layout are cleared")
	var bare_file: FileAccess = FileAccess.open(root + "/flora_removed.json", FileAccess.WRITE)
	bare_file.store_string(JSON.stringify({"%d,%d" % [best.x, best.y]: [ids[0]]}))
	bare_file.close()
	var unstamped = ServerFloraScript.new()
	unstamped.setup(placer, root)
	_check(FloraLayoutScript.VERSION != 1 or (not unstamped.layout_cleared and unstamped.removed_in(best) == [ids[0]]), "an unstamped save counts as layout 1")
	_remove_tree(root)


# Writes the starter tile through the tile file writer, reads it back and
# checks every section.
func _test_tile_file(settings, tile: Vector2i, water, climate, geology, sites) -> void:
	var plan_cell: Dictionary = {"x": tile.x, "z": tile.y, "kind": "starter", "status": "planned"}
	var packed: Dictionary = TileFileScript.pack_tile(settings, tile, plan_cell, water, climate, geology, sites)
	var path: String = "user://test_tile_%d_%d.tile" % [tile.x, tile.y]
	var started: int = Time.get_ticks_msec()
	var written: Dictionary = TileFileScript.write(path, packed)
	print("tile file written in %d ms: %d bytes" % [Time.get_ticks_msec() - started, int(written["bytes"])])
	_check(written["ok"], "the tile file is written (%s)" % str(written["error"]))

	if not written["ok"]:
		return

	_check(not FileAccess.file_exists(path + ".partial"), "no .partial file is left behind")
	var again: Dictionary = TileFileScript.write(path, TileFileScript.pack_tile(settings, tile, plan_cell, water, climate, geology, sites))
	_check(int(again["bytes"]) == int(written["bytes"]) and FileAccess.get_sha256(path) != "", "writing twice gives a file of the same size")
	# A copy for the runtime terrain test, before the damage test below.
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://test_tiles"))
	DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path("user://test_tiles/tile_%d_%d.tile" % [tile.x, tile.y]))

	var head: Dictionary = TileFileScript.read_header(path)
	_check(head["ok"], "the tile header reads back")
	var header: Dictionary = head["header"]
	var table: Array = head["table"]
	_check(int(header["tile_x"]) == tile.x and int(header["tile_z"]) == tile.y, "header tile coordinate")
	_check(int(header["master_seed"]) == settings.master_seed and int(header["tile_seed"]) == settings.tile_seed(tile.x, tile.y), "header seeds")
	_check(int(header["samples"]) == water.samples and int(header["map_spacing_m"]) == 8, "header map size")
	_check(int(header["revision"]) == 1 and str(header["status"]) == "final", "header revision and status")

	var all_ok: bool = true

	for entry in table:
		var section: Dictionary = TileFileScript.read_section(path, table, str(entry["name"]))

		if not section["ok"]:
			all_ok = false
			print("  section %s: %s" % [entry["name"], section["error"]])

	_check(all_ok, "every section decompresses and passes its checksum")

	var height_raw: PackedByteArray = TileFileScript.read_section(path, table, "height")["raw"]
	var heights: PackedFloat32Array = TileFileScript.decode_height(height_raw)
	var worst: float = 0.0

	for i in range(heights.size()):
		worst = maxf(worst, absf(heights[i] - clampf(water.heights[i], -4000.0, 2553.5)))

	_check(heights.size() == water.samples * water.samples and worst <= 0.0501, "heights read back within 0.05 m (worst %.3f)" % worst)

	var surface: PackedFloat32Array = TileFileScript.decode_water_surface(TileFileScript.read_section(path, table, "water_surface")["raw"])
	var surface_ok: bool = true

	for i in range(surface.size()):
		if water.water_class[i] == 0:
			if not is_nan(surface[i]):
				surface_ok = false
				break
		elif absf(surface[i] - water.water_surface[i]) > 0.0501:
			surface_ok = false
			break

	_check(surface_ok, "water surface reads back, and dry cells have no surface")

	for name in ["water_class", "biome", "soil", "fertility", "moisture", "province", "cover"]:
		var source: PackedByteArray = {
			"water_class": water.water_class, "biome": climate.biome, "soil": climate.soil, "fertility": climate.fertility,
			"moisture": climate.moisture, "province": geology.province, "cover": geology.cover,
		}[name]
		_check(TileFileScript.read_section(path, table, name)["raw"] == source, "%s map reads back exactly" % name)

	var offsets: PackedInt32Array = TileFileScript.decode_layer_offset(TileFileScript.read_section(path, table, "layer_offset")["raw"])
	var offsets_ok: bool = offsets.size() == geology.layer_offset.size()

	for i in range(offsets.size()):
		if offsets[i] != clampi(geology.layer_offset[i], -32768, 32767):
			offsets_ok = false
			break

	_check(offsets_ok, "layer offsets read back exactly")

	var flow: PackedFloat32Array = TileFileScript.decode_flow(TileFileScript.read_section(path, table, "flow")["raw"])
	var flow_ok: bool = true

	for i in range(flow.size()):
		var source_flow: float = maxf(water.flow[i], 1.0)

		# Flow is stored for water only (spec Section 4b).
		if water.water_class[i] == 0:
			if flow[i] > 1.0:
				flow_ok = false
				break

			continue

		if flow[i] < source_flow / 1.0445 or flow[i] > source_flow * 1.0445:
			if source_flow < 2.0 ** 23.0:
				flow_ok = false
				break

	_check(flow_ok, "flow reads back within the logarithmic step (about 4 percent)")

	var low: int = int(header["low_res_samples"])
	var low_heights: PackedFloat32Array = TileFileScript.decode_height(TileFileScript.read_section(path, table, "low_height")["raw"])
	_check(low == 481 and low_heights.size() == 481 * 481, "low-resolution maps are 481 by 481")
	_check(absf(low_heights[100 * 481 + 200] - heights[400 * water.samples + 800]) < 0.001, "low-resolution height is every fourth sample")

	for name in ["provinces", "features", "ore_bodies", "sites"]:
		var listed: Dictionary = TileFileScript.read_list(path, table, name)
		_check(listed["ok"], "list %s reads back" % name)

	var ores: Array = TileFileScript.read_list(path, table, "ore_bodies")["value"]
	_check(ores.size() == geology.ore_bodies.size() and str(ores[0]["id"]) == str(geology.ore_bodies[0]["id"]), "ore bodies keep their count and IDs")
	var cave_list: Dictionary = TileFileScript.read_list(path, table, "sites")["value"]
	_check(cave_list["caves"].size() == sites.caves.size() and cave_list["lairs"].size() == sites.lairs.size(), "sites keep their caves and lairs")

	if not sites.starter.is_empty():
		_check(TileFileScript.read_list(path, table, "starter")["ok"], "starter data is stored on a starter tile")

	# A flipped byte in any section must be caught.
	var damaged: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	var target: Dictionary = {}

	# The biggest section: a tiny one (all one biome) can hide a flipped byte in padding.
	for entry in table:
		if str(entry["name"]) != "height" and (target.is_empty() or int(entry["size"]) > int(target["size"])):
			target = entry

	damaged.seek(int(target["offset"]) + int(target["size"]) / 2)
	var byte: int = damaged.get_8()
	damaged.seek(int(target["offset"]) + int(target["size"]) / 2)
	damaged.store_8(byte ^ 0x55)
	damaged.close()
	_check(not TileFileScript.read_section(path, table, str(target["name"]))["ok"], "a damaged section is caught")
	_check(TileFileScript.read_section(path, table, "height")["ok"], "other sections still read after one is damaged")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
