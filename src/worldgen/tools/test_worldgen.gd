extends SceneTree

# Checks for the new world generator. Run with:
#   godot --headless --path . --script res://src/worldgen/tools/test_worldgen.gd
# Exits with code 0 when every check passes.

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")

const WORLD_PATH := "res://worlds/base_world/world.json"

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_test_seeds()
	_test_settings()
	_test_climate()
	_test_tables()

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
	_check(settings.get_starter_set_of(Vector2i(-8, -5)) == "outer", "outer starter")
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

	# Equator line is the middle of row 0.
	_check(_approx(settings.get_equator_z_m(), 5120.0), "equator line z")
	_check(
		_approx(settings.latitude_for_z(5120.0), 0.0),
		"latitude is zero at the equator"
	)
	_check(
		_approx(settings.latitude_for_z(5120.0 - 107520.0 + 1.0), 1.0, 0.001),
		"north pole is latitude +1"
	)
	_check(
		_approx(settings.latitude_for_z(5120.0 + 107520.0 - 1.0), -1.0, 0.001),
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
			settings.temperature_c(5120.0, 1000.0),
			settings.temperature_c(5120.0, 0.0) - 6.5,
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
