extends SceneTree

# Checks for the new world generator. Run with:
#   godot --headless --path . --script res://src/worldgen/tools/test_worldgen.gd
# Exits with code 0 when every check passes.

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const RandomizerScript := preload("res://src/worldgen/matrix/matrix_randomizer.gd")
const TileMatrixScript := preload("res://src/worldgen/matrix/tile_matrix.gd")
const IslandShapeScript := preload("res://src/worldgen/matrix/island_shape.gd")

const WORLD_PATH := "res://worlds/base_world/world.json"
const RULES_PATH := "res://worlds/base_world/plan/matrix_rules.json"

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_seeds()
	_test_settings()
	_test_climate()
	_test_danger()
	_test_tables()
	_test_matrix()

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
	_check(tables.id_of("resources", "tin") == ResourceIds.TIN, "tin ID")
	_check(tables.id_of("resources", "gemstone") == ResourceIds.GEMSTONE, "gem ID")
	_check(tables.id_of("resources", "peat") == ResourceIds.PEAT, "peat ID")
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
