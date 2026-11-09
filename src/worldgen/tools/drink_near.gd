extends SceneTree

# In-world drink check (drinking water step 2b, docs/design/drinking_water_step2b_design.md 3): on the baked tiles, finds one spot of each
# kind from the record's own data (never from the spawn) and asks the game's own drink rule what a player there gets in five weathers.
# The spots: the biggest ground spring head; the widest intermittent brook with no spring above it; the widest ephemeral gully; a perennial
# brook about 100 m below its spring (inside its open length on a frosty night with a breeze); and a perennial brook more than three
# times its calm open length below its spring. Rows come from DrinkRules.tile_rows, as the
# terrain server's water_source builds them, and the pick from DrinkRules.pick with vitals.json thirst.sources. It prints the spot (to walk
# to), the rows, the pick in each weather, what the design expects, and a last line "verdict: PASS" or "verdict: FAIL". It reads only.
#   godot --headless --path . --script res://src/worldgen/tools/drink_near.gd -- [--tiles=2,3;3,3;...] [--world=res://worlds/base_world]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const DrinkRules := preload("res://src/shared/drink_rules.gd")
const WeatherScript := preload("res://src/shared/weather.gd")

const REACH_M := 3.0   # vitals.json thirst.reach_m
const FROST_C := -7.5  # the starter island's worst night (drink_rules.gd open_length_m)

# [name, ctx, iced]: the weathers. iced: the ice rule at the spot says a sheet (frost nights only).
const WEATHERS := [
	["august dry", {"season": "summer", "rain_h_ago": 72.0, "raining": false, "air_c": 22.0, "wind": 0.1}, false],
	["august 3 h after rain", {"season": "summer", "rain_h_ago": 3.0, "raining": false, "air_c": 20.0, "wind": 0.1}, false],
	["spring day, no rain 3 days", {"season": "spring", "rain_h_ago": 72.0, "raining": false, "air_c": 10.0, "wind": 0.1}, false],
	["frost night, calm", {"season": "winter", "rain_h_ago": 72.0, "raining": false, "air_c": FROST_C, "wind": 0.0}, true],
	["frost night, breeze", {"season": "winter", "rain_h_ago": 72.0, "raining": false, "air_c": FROST_C, "wind": 0.4}, true],
]

# What the design expects in each weather, by spot (section 3): "drink", "dry" (refused, the bed is dry) or "hole" (frozen: an ice hole).
const EXPECT := {
	"spring head": ["drink", "drink", "drink", "drink", "drink"],
	"intermittent brook, no spring": ["dry", "drink", "drink", "hole", "hole"],
	"ephemeral gully": ["dry", "drink", "dry", "dry", "dry"],
	"perennial, ~100 m below a spring": ["drink", "drink", "drink", "drink", "drink"],
	"perennial, past its open length": ["drink", "drink", "drink", "hole", "hole"],
}

var failures: int = 0


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var tiles: Array = []

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			world = argument.trim_prefix("--world=")
		elif argument.begins_with("--tiles="):
			for pair in argument.trim_prefix("--tiles=").split(";"):
				var p: PackedStringArray = pair.split(",")
				tiles.append(Vector2i(int(p[0]), int(p[1])))

	if tiles.is_empty():
		for tz in [3, 4, 5]:
			for tx in [2, 3, 4]:
				tiles.append(Vector2i(tx, tz))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var vitals: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/vitals.json"))
	var cfg: Dictionary = vitals["thirst"]["sources"] if typeof(vitals) == TYPE_DICTIONARY else {}

	if not errors.is_empty() or cfg.is_empty():
		print("drink_near: cannot start: %s" % str(errors if not errors.is_empty() else "no vitals.json thirst.sources"))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var spots: Dictionary = _find_spots(generator, settings, tiles, cfg)

	for name in EXPECT.keys():
		if not spots.has(name):
			print("SPOT %s: none on these tiles | FAIL" % name)
			failures += 1
			continue

		_check_spot(generator, settings, cfg, name, spots[name])

	print("verdict: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


func _mean_c(settings, z: float) -> Callable:
	var group: String = settings.get_zone_group_for_row(int(floor(z / float(settings.tile_size_m))))
	return func(height: float) -> float: return WeatherScript.year_mean_c(group, height)


# Spot name -> Vector3, the first best of each kind over the tiles (in the order given; ties keep the first).
func _find_spots(generator, settings, tiles: Array, cfg: Dictionary) -> Dictionary:
	var spots: Dictionary = {}
	var score: Dictionary = {}

	for tile in tiles:
		var data = generator.get_tile(tile)

		if data.placeholder:
			continue

		for spring in data.ground_springs:
			if float(spring[1]) > float(score.get("spring head", -1.0)):
				score["spring head"] = float(spring[1])
				spots["spring head"] = spring[0]

		if not data.has_drink():
			print("tile %d,%d: no channel samples (a tile with no streams, such as open sea, or one baked before step 2b)" % [tile.x, tile.y])
			continue

		var mean_c: Callable = _mean_c(settings, data.z0)

		for k in data.drink_samples():
			var row: Dictionary = data.drink_row(k, mean_c)

			if int(data.water_class[k]) == 2:
				continue   # a lake: tile_rows gives a lake row there, never a brook

			var at: Vector3 = Vector3(data.x0 + float(k % data.samples) * data.spacing_m, data.heights[k], data.z0 + float(floori(float(k) / float(data.samples))) * data.spacing_m)
			var below: float = float(row["below_spring_m"])
			var regime: int = int(row["regime"])
			var open_m: float = DrinkRules.open_length_m(cfg, row, FROST_C, 0.0) if is_finite(below) else INF
			var pick: Array = []

			if regime == 2 and not is_finite(below):
				pick = ["intermittent brook, no spring", float(row["width_m"])]
			elif regime == 3 and not is_finite(below):
				pick = ["ephemeral gully", float(row["width_m"])]
			elif regime == 1 and is_finite(below) and below >= 60.0 and below <= 140.0 and DrinkRules.open_length_m(cfg, row, FROST_C, 0.4) > below:
				pick = ["perennial, ~100 m below a spring", float(row["q_m3_s"])]
			elif regime == 1 and is_finite(below) and below > 3.0 * open_m:
				pick = ["perennial, past its open length", float(row["q_m3_s"])]

			if not pick.is_empty() and float(pick[1]) > float(score.get(pick[0], -1.0)):
				score[pick[0]] = float(pick[1])
				spots[pick[0]] = at

	return spots


func _check_spot(generator, settings, cfg: Dictionary, name: String, at: Vector3) -> void:
	var data = generator.get_tile(generator.tile_of(at.x, at.z))
	var rows: Array = DrinkRules.tile_rows(data, at, REACH_M, _mean_c(settings, at.z))
	var kinds: Array = []

	for row in rows:
		var text: String = str(row["kind"])

		if str(row["kind"]) == "brook":
			text += " r%d w%.1f m below %s q %.1f L/s" % [int(row["regime"]), float(row["width_m"]), "none" if is_inf(float(row["below_spring_m"])) else "%.0f m" % float(row["below_spring_m"]), float(row["q_m3_s"]) * 1000.0]

		if not kinds.has(text):
			kinds.append(text)

	var tile: Vector2i = generator.tile_of(at.x, at.z)
	print("SPOT %s: tile %d,%d  x %.0f z %.0f y %.1f  rows: %s" % [name, tile.x, tile.y, at.x, at.z, at.y, ", ".join(kinds)])

	for w in WEATHERS.size():
		var weather: Array = WEATHERS[w]
		var marked: Array = []

		for row in rows:
			marked.append((row as Dictionary).merged({"iced": bool(weather[2])}))

		var found: Dictionary = DrinkRules.pick(cfg, marked, weather[1])
		var got: String = "none"

		if found.has("refused"):
			got = str(found["refused"])
		elif not found.is_empty():
			got = "hole" if bool(found.get("frozen", false)) else "drink"

		var want: String = EXPECT[name][w]
		var ok: bool = got == want
		var detail: String = "" if found.has("refused") or found.is_empty() else " (%s, %.1f C)" % [str(found["kind"]), float(found["temp_c"])]
		print("  %-26s %-6s%s  expected %s | %s" % [weather[0], got, detail, want, "ok" if ok else "FAIL"])

		if not ok:
			failures += 1
