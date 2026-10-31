extends SceneTree

# Small, fast check of the climate classification (tile_climate.gd) on a made-up ground (Tyler, 31 Oct 2026; the gap named in the relevance table: nothing tested
# climate-driven biomes on their own, only inside the 56 s test_worldgen). A 193 x 193 frame: sea along the south edge, land rising steadily to about 2,600 m in
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
const TERRACES := 14
const TOP_M := 2600.0
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
			# Terraces: flat steps (slope does not turn everything to bare rock), so each step shows what its height and temperature alone make of the biome.
			var step: float = floorf(rise * float(TERRACES)) / float(TERRACES)
			heights[row * SIDE + column] = -4.0 if row >= SIDE - SEA_ROWS else 2.0 + TOP_M * pow(step, 1.3) + 0.3 * sin(float(column) * 0.4)
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

	for row in range(SIDE - SEA_ROWS - 30, SIDE - SEA_ROWS - 16):
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
	# Up the terraces the ground gets colder: the middle row of each step, ranked green 0, cool woods and heath 1, alpine or tundra 2, rock, snow or ice 3.
	var ranks: Array = []
	var seen: Dictionary = {}

	for t in range(TERRACES):
		var row: int = clampi(int((float(SIDE - 1 - SEA_ROWS) * (1.0 - (float(t) + 0.5) / float(TERRACES)))), 0, SIDE - 1 - SEA_ROWS)
		var name: String = str(biome_names[int(climate.biome[row * SIDE + SIDE / 2])])
		seen[name] = true
		ranks.append(3 if name in ["bare_rock", "snowfield", "glacier"] else (2 if name in ["alpine_meadow", "tundra"] else (1 if name in ["boreal_forest", "heath"] else 0)))

	var worst_drop: int = 0

	for t in range(1, TERRACES):   # t = 0 is the lowest step
		worst_drop = maxi(worst_drop, int(ranks[t - 1]) - int(ranks[t]))

	print("terraces from the lowest step up: ", ranks, " biomes ", seen.keys())
	_check(worst_drop == 0 and int(ranks[0]) == 0 and int(ranks[TERRACES - 1]) >= 2 and seen.size() >= 3, "going up the terraces the biome only gets colder, from green to cold, through at least 3 kinds")
	var again = TileClimateScript.new()
	again.setup(settings, rules, tables)
	again.build(heights, water, 3 * 1920, 4 * 1920)
	_check(again.biome == climate.biome and again.soil == climate.soil and again.temperature_c == climate.temperature_c, "the same input gives the same maps")

	# The bake classifies in native code (GenCore); the script version is the reference it must match. Same maps from the script path = both agree on this ground.
	TileClimateScript.force_script = true
	var by_script = TileClimateScript.new()
	by_script.setup(settings, rules, tables)
	by_script.build(heights, water, 3 * 1920, 4 * 1920)
	TileClimateScript.force_script = false
	_check(by_script.biome == climate.biome and by_script.soil == climate.soil and by_script.temperature_c == climate.temperature_c, "the script classification gives the same maps as the bake's")
	# The rule on its own (pick_biome, the reference the native code must match): one made-up spot, only the temperature or wetness changing.
	var rb: Dictionary = rules["climate"]["biome"]
	var c: Dictionary = {
		"hot_min": rb["hot_min_c"], "warm_min": rb["warm_min_c"], "cold_min": rb["cold_min_c"], "snow_max": rb["snow_max_c"], "glacier_max": rb["glacier_max_c"],
		"rock_tan": tan(deg_to_rad(float(rb["rock_slope_deg"]))), "marsh_tan": tan(deg_to_rad(float(rb["marsh_slope_deg"]))),
		"beach_height_m": rb["beach_height_m"], "beach_distance_m": rb["beach_distance_m"], "marsh_height_m": rb["marsh_height_m"], "marsh_moisture": rb["marsh_moisture"],
		"alpine_min_height_m": rb["alpine_min_height_m"], "boreal_moisture": rb["boreal_moisture"], "desert_moisture": rb["desert_moisture"],
		"scrub_moisture": rb["scrub_moisture"], "savanna_moisture": rb["savanna_moisture"], "grassland_moisture": rb["grassland_moisture"],
		"mixed_moisture": rb["mixed_moisture"], "cool_forest_below_c": rb["cool_forest_below_c"],
	}
	var ids: Dictionary = {}

	for name in ["beach", "hot_desert", "dry_scrub", "savanna", "tropical_forest", "mangrove", "temperate_grassland", "temperate_forest", "mixed_forest", "marsh", "heath",
			"boreal_forest", "tundra", "alpine_meadow", "bare_rock", "snowfield", "glacier"]:
		ids[name] = tables.id_of("biomes", name)

	var sweep: Array = [[30.0, 0.8, "tropical_forest"], [28.0, 0.1, "hot_desert"], [15.0, 0.8, "temperate_forest"], [15.0, 0.3, "temperate_grassland"], [3.0, 0.8, "boreal_forest"],
		[-5.0, 0.8, "tundra"], [-10.0, 0.8, "snowfield"], [-16.0, 0.8, "glacier"]]
	var wrong: Array = []

	for row in sweep:
		var got: int = TileClimateScript.pick_biome(ids, c, float(row[0]), float(row[1]), 300.0, 0.05, 5000.0)

		if got != int(ids[row[2]]):
			wrong.append("%s C wet %s -> %s, not %s" % [row[0], row[1], biome_names.get(got, "?"), row[2]])

	_check(wrong.is_empty(), "the biome rule: hot wet = tropical, hot dry = desert, mild = forest or grass, cool = boreal, cold = tundra, snow, glacier %s" % str(wrong))
	_check(TileClimateScript.pick_biome(ids, c, 12.0, 0.5, 300.0, 1.5, 5000.0) == int(ids["bare_rock"]), "a steep slope is bare rock at any mild temperature")
	_check(TileClimateScript.pick_biome(ids, c, 7.0, 0.5, 1200.0, 0.05, 5000.0) == int(ids["alpine_meadow"]), "high and cool ground is alpine meadow")
	var took: float = float(Time.get_ticks_msec() - begun) / 1000.0
	print("climate small: %d failures, %.1f s, biomes %s" % [failures, took, str(climate.biome_cells)])
	quit(1 if failures > 0 else 0)
