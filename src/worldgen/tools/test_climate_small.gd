extends SceneTree

# Small, fast check of the climate classification (tile_climate.gd) on a made-up ground (Tyler, 31 Oct 2026; the gap named in the relevance table: nothing tested
# climate-driven biomes on their own, only inside the 56 s test_worldgen). A 193 x 193 frame: sea along the south edge, land rising steadily to about 1,400 m in
# the north. Checks: every id is in its table, sea is the ocean biome and nothing else is, the temperature falls with height by the world's lapse rate, the
# same input gives the same maps, the lowlands are green (forest or grass) and the summit is cold ground (alpine, tundra, rock, snow or ice), and a beach lies
# between the sea and the lowlands.
#   godot --headless --path . --script res://src/worldgen/tools/test_climate_small.gd

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const TileClimateScript := preload("res://src/worldgen/tile/tile_climate.gd")

const SIDE := 193
const SEA_ROWS := 12
const TOP_M := 1400.0
const COLD := ["alpine_meadow", "tundra", "bare_rock", "snowfield", "glacier"]
const GREEN := ["temperate_forest", "mixed_forest", "temperate_grassland", "boreal_forest", "heath", "marsh", "dry_scrub", "savanna", "tropical_forest"]

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var begun: int = Time.get_ticks_msec()
	var errors: Array = []
	var world: String = "res://worlds/base_world"
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	_check(errors.is_empty(), "world, rules and tables load (%s)" % str(errors))
	var heights: PackedFloat32Array = PackedFloat32Array()
	heights.resize(SIDE * SIDE)
	var water: PackedByteArray = PackedByteArray()
	water.resize(SIDE * SIDE)

	for row in range(SIDE):
		for column in range(SIDE):
			# Row 0 is the north (high) edge, the last rows are the sea.
			var rise: float = clampf(float(SIDE - 1 - SEA_ROWS - row) / float(SIDE - 1 - SEA_ROWS), 0.0, 1.0)
			heights[row * SIDE + column] = -4.0 if row >= SIDE - SEA_ROWS else 2.0 + TOP_M * pow(rise, 1.3) + 3.0 * sin(float(column) * 0.4)
			water[row * SIDE + column] = 1 if row >= SIDE - SEA_ROWS else 0

	var climate = TileClimateScript.new()
	climate.setup(settings, rules, tables)
	climate.build(heights, water, 3 * 1920, 4 * 1920)
	var biome_names: Dictionary = {}

	for entry in tables.get_entries("biomes"):
		biome_names[int(entry["id"])] = str(entry["name"])

	var bad: int = 0
	var sea_wrong: int = 0

	for k in range(SIDE * SIDE):
		if not biome_names.has(int(climate.biome[k])):
			bad += 1

		if (water[k] == 1) != (biome_names.get(int(climate.biome[k]), "") == "ocean"):
			sea_wrong += 1

	_check(climate.biome.size() == SIDE * SIDE and bad == 0, "every cell has a biome from the table (%d bad)" % bad)
	_check(sea_wrong == 0, "sea is the ocean biome and no land is (%d wrong)" % sea_wrong)

	# Temperature falls with height at the world's lapse rate: compare a low land row and a high row in the same column.
	var low_row: int = SIDE - SEA_ROWS - 4
	var high_row: int = 6
	var column: int = SIDE / 2
	var dh: float = heights[low_row * SIDE + column] - heights[high_row * SIDE + column]
	var t_low: float = climate.temperature_c[low_row * SIDE + column]
	var t_high: float = climate.temperature_c[high_row * SIDE + column]
	var expect: float = dh / 1000.0 * float(settings.lapse_rate_c_per_km)
	_check(absf((t_high - t_low) - expect) < 2.0, "temperature falls %.1f C over %.0f m of climb (the lapse rate gives %.1f)" % [t_high - t_low, -dh, expect])

	# Lowlands green, summit cold.
	var low_green: int = 0
	var low_total: int = 0
	var top_cold: int = 0
	var top_total: int = 0
	var beach: int = 0

	for row in range(SIDE - SEA_ROWS - 40, SIDE - SEA_ROWS - 8):
		for c in range(SIDE):
			low_total += 1
			low_green += 1 if str(biome_names[int(climate.biome[row * SIDE + c])]) in GREEN else 0

	for row in range(0, 12):
		for c in range(SIDE):
			top_total += 1
			top_cold += 1 if str(biome_names[int(climate.biome[row * SIDE + c])]) in COLD else 0

	for row in range(SIDE - SEA_ROWS - 6, SIDE - SEA_ROWS):
		for c in range(SIDE):
			beach += 1 if str(biome_names[int(climate.biome[row * SIDE + c])]) == "beach" else 0

	_check(float(low_green) >= 0.8 * float(low_total), "the lowlands are green: %d of %d cells forest, grass, heath or marsh" % [low_green, low_total])
	_check(float(top_cold) >= 0.8 * float(top_total), "the summit band is cold ground: %d of %d cells alpine, tundra, rock, snow or ice" % [top_cold, top_total])
	_check(beach > 0, "a beach lies between the sea and the lowlands (%d cells)" % beach)
	var again = TileClimateScript.new()
	again.setup(settings, rules, tables)
	again.build(heights, water, 3 * 1920, 4 * 1920)
	_check(again.biome == climate.biome and again.soil == climate.soil and again.temperature_c == climate.temperature_c, "the same input gives the same maps")
	var took: float = float(Time.get_ticks_msec() - begun) / 1000.0
	print("climate small: %d failures, %.1f s, biomes %s" % [failures, took, str(climate.biome_cells)])
	quit(1 if failures > 0 else 0)
