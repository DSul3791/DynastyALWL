extends SceneTree

# Cave air by depth and season (docs/design/cave_climate_design.md; Jamie #709): the bands by which way a cave runs and the season, the blend
# from the outside air at the mouth to the year mean deep in, the day swing halved, a draught only in the first 10 m, drying only at a winter
# mouth; in the server's warmth a winter mouth is colder than deep in and a summer mouth warmer, and without the callable the flat #667 cave.
#   godot --headless --path . --script res://src/worldgen/tools/test_cave_climate.gd

const CaveClimate := preload("res://src/shared/cave_climate.gd")
const TileDataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

const DEEP := 5.5

var failures: int = 0
var weather: Dictionary = {"temp_c": -5.0, "wind": 0.7, "rain": 0.0, "snow": 0.0}
var depth: float = 3.0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/warmth.json"))["cave_climate"]

	# 1. Which way a cave runs, and its band.
	check(CaveClimate.kind_of(Vector3(0, 530, 0), Vector3(30, 534, 0)) == CaveClimate.RISES, "a passage climbing 4 m in 30 m rises")
	check(CaveClimate.kind_of(Vector3(0, 530, 0), Vector3(30, 524, 0)) == CaveClimate.DROPS, "one falling 6 m in 30 m drops")
	check(CaveClimate.kind_of(Vector3(0, 530, 0), Vector3(30, 530.5, 0)) == CaveClimate.LEVEL, "half a metre in 30 is level")
	check(CaveClimate.band(cfg, CaveClimate.RISES, true) == Vector2(10, 60) and CaveClimate.band(cfg, CaveClimate.RISES, false) == Vector2(5, 20), "a rising cave: summer 10 to 60 m, winter 5 to 20 m")
	check(CaveClimate.band(cfg, CaveClimate.DROPS, false) == Vector2(10, 60) and CaveClimate.band(cfg, CaveClimate.LEVEL, false) == Vector2(10, 40), "a pit the reverse; level 10 to 40 m")

	# 2. The blend.
	var winter_mouth: float = CaveClimate.air_c(cfg, -5.0, 0.0, DEEP, 3.0, CaveClimate.RISES)
	var winter_15: float = CaveClimate.air_c(cfg, -5.0, 0.0, DEEP, 15.0, CaveClimate.RISES)
	var winter_25: float = CaveClimate.air_c(cfg, -5.0, 0.0, DEEP, 25.0, CaveClimate.RISES)
	check(is_equal_approx(winter_mouth, -5.0) and winter_15 > -5.0 and winter_15 < DEEP and is_equal_approx(winter_25, DEEP), "a rising cave in winter: outside air at 3 m, between at 15 m, deep air by 25 m (%.1f, %.1f, %.1f)" % [winter_mouth, winter_15, winter_25])
	var summer_25: float = CaveClimate.air_c(cfg, 16.0, 0.0, DEEP, 25.0, CaveClimate.RISES)
	check(summer_25 > DEEP + 3.0 and is_equal_approx(CaveClimate.air_c(cfg, 16.0, 0.0, DEEP, 70.0, CaveClimate.RISES), DEEP), "in summer the warmth reaches 25 m (%.1f) and is gone by 70 m" % summer_25)
	check(CaveClimate.air_c(cfg, -5.0, 0.0, DEEP, 25.0, CaveClimate.DROPS) < DEEP - 2.0, "a pit keeps winter cold at 25 m (%.1f)" % CaveClimate.air_c(cfg, -5.0, 0.0, DEEP, 25.0, CaveClimate.DROPS))
	check(is_equal_approx(CaveClimate.air_c(cfg, -1.0, -4.0, DEEP, 2.0, CaveClimate.LEVEL), 1.0), "at the mouth the night's chill is halved (-1 C outside, 4 C of it the night: 1 C)")

	# 3. Draught and drying.
	check(is_equal_approx(CaveClimate.draught_ms(cfg, -1.5, DEEP, 5.0), 0.42) and is_equal_approx(CaveClimate.draught_ms(cfg, -20.0, DEEP, 5.0), 0.6) and CaveClimate.draught_ms(cfg, -5.0, DEEP, 12.0) == 0.0, "a draught of 0.06 m/s a degree, at most 0.6, none past 10 m")
	check(CaveClimate.wind_of_ms(0.45) < 0.1, "which is a game wind under 0.1 (%.3f)" % CaveClimate.wind_of_ms(0.45))
	check(CaveClimate.dry_share(cfg, -5.0, DEEP, 10.0) == 0.5 and CaveClimate.dry_share(cfg, 4.0, DEEP, 10.0) == 0.0 and CaveClimate.dry_share(cfg, 16.0, DEEP, 10.0) == 0.0 and CaveClimate.dry_share(cfg, -5.0, DEEP, 25.0) == 0.0, "drying: half at a winter mouth, none at a mild or summer mouth, none past 20 m")

	# 4. The nearest mouth on a tile.
	var t = TileDataScript.new()
	t.cave_mouths = [[Vector3(0, 530, 0), CaveClimate.RISES], [Vector3(100, 520, 0), CaveClimate.DROPS]]
	var near: Array = t.nearest_cave_mouth(Vector3(80, 520, 0))
	check(is_equal_approx(float(near[0]), 20.0) and int(near[1]) == CaveClimate.DROPS, "the nearest mouth and its kind (%s)" % str(near))
	check(float(TileDataScript.new().nearest_cave_mouth(Vector3.ZERO)[0]) == INF, "no mouths: INF")

	# 5. The server's warmth: a winter storm outside, the player in a rising cave.
	var dir: String = "user://test_cave_climate"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _text): pass
	items.send_warmth = func(_p, _pct): pass
	items.weather_now = func(): return weather
	items.setup(ItemTableScript.load_default(), dir)
	items._hints_loaded = true
	items._hints = []
	items.peer_connected_hello(1, "caveair-key-01")
	items.report_position(1, Vector3(10.0, 0.0, 10.0))   # sea level: the weather's air is the outside air
	items.cover_at = func(_p): return 2.0
	items.cave_mean_c = func(_p): return DEEP
	items.cave_air = func(_p): return {"deep_c": DEEP, "depth_m": depth, "kind": CaveClimate.RISES, "day_part_c": 0.0}
	depth = 3.0
	var mouth: float = items.warmth_target(1)
	depth = 40.0
	var deep: float = items.warmth_target(1)
	check(mouth < deep, "a winter mouth is colder than deep in (%.0f at 3 m, %.0f at 40 m)" % [mouth, deep])
	weather = {"temp_c": 30.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
	depth = 3.0
	var hot_mouth: float = items.warmth_target(1)
	depth = 40.0
	check(hot_mouth > items.warmth_target(1), "a hot summer mouth is warmer than deep in (%.0f, %.0f)" % [hot_mouth, items.warmth_target(1)])

	# Drying: a winter mouth dries at half the cover rate; deep in, or a summer mouth, not at all.
	weather = {"temp_c": -5.0, "wind": 0.7, "rain": 0.0, "snow": 0.0}
	var rate: float = float(items._warmth_cfg.get("dry_cover_per_h", 1.0))
	depth = 8.0
	items._soak[1] = 1.0
	items._update_soak(1, 3600.0 * 0.5)
	check(is_equal_approx(float(items._soak[1]), 1.0 - 0.5 * rate * 0.5), "a winter mouth dries at half the cover rate (%.2f after half an hour)" % float(items._soak[1]))
	depth = 30.0
	items._soak[1] = 1.0
	items._update_soak(1, 3600.0)
	check(float(items._soak[1]) == 1.0, "deep in, no drying")
	weather = {"temp_c": 18.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
	depth = 8.0
	items._update_soak(1, 3600.0)
	check(float(items._soak[1]) == 1.0, "a summer mouth, no drying")

	# Without the callable: the flat cave of #667.
	items.cave_air = Callable()
	weather = {"temp_c": -5.0, "wind": 0.7, "rain": 0.0, "snow": 0.0}
	var flat: float = items.warmth_target(1)
	weather = {"temp_c": 25.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
	check(is_equal_approx(flat, items.warmth_target(1)), "with no mouth data the cave stays flat at the year mean")

	print("test_cave_climate: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
