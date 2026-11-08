extends SceneTree

# A cave as shelter (Jamie's caves page, #664): a spot inside a carved passage or chamber with rock over it counts as in a cave, the open mouth
# and the rock round it do not; in a cave the air sits at the year's mean for its height (no wind chill, no day and night swing, no rain
# cooling), the rain does not soak you, and only a fire dries you (the air is near saturated).
#   godot --headless --path . --script res://src/worldgen/tools/test_cave_shelter.gd

const TileDataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const WeatherScript := preload("res://src/shared/weather.gd")

var failures: int = 0
var weather: Dictionary = {"temp_c": -6.0, "wind": 0.7, "rain": 0.8, "snow": 0.0, "cloud": 1.0, "season": "winter"}
var cave_spot: Vector3 = Vector3(10.0, 533.0, 10.0)


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	# 1. The geometry: a passage 3 m wide and 2 m high from (0, 530, 0) to (40, 530, 0) and a chamber of radius 6 at (60, 531, 0), all under
	# ground 20 m higher (a placeholder tile reads one height everywhere).
	var t = TileDataScript.new()
	t.placeholder = true
	t.placeholder_depth_m = 550.0
	var pa: Vector3 = Vector3(0.0, 530.0, 0.0)
	var pb: Vector3 = Vector3(40.0, 530.0, 0.0)
	var cc: Vector3 = Vector3(60.0, 531.0, 0.0)
	t.caves = [{"id": "t#1", "aabb": AABB(Vector3(-4.0, 526.0, -8.0), Vector3(72.0, 12.0, 16.0)),
			"capsules": [{"a": pa, "b": pb, "rw": 3.0, "rh": 2.0, "aabb": AABB(Vector3(-3.0, 528.0, -3.0), Vector3(46.0, 4.0, 6.0))}],
			"chambers": [{"center": cc, "r": 6.0, "rh": 4.0, "aabb": AABB(Vector3(54.0, 527.0, -6.0), Vector3(12.0, 8.0, 12.0))}]}]
	check(t.in_cave(Vector3(20.0, 528.5, 0.0)), "feet on a passage floor are in the cave")
	check(t.in_cave(Vector3(60.0, 528.0, 2.0)), "and in a chamber")
	check(not t.in_cave(Vector3(20.0, 528.5, 9.0)), "9 m to the side, in the rock, is not")
	check(not t.in_cave(Vector3(20.0, 545.0, 0.0)), "nor a spot over the passage, high in the rock")
	t.placeholder_depth_m = 529.5
	check(not t.in_cave(Vector3(20.0, 528.5, 0.0)), "with the ground only 1 m over your feet (the open mouth) it is not")
	t.placeholder_depth_m = 550.0
	check(not TileDataScript.new().in_cave(Vector3(20.0, 528.5, 0.0)), "a tile with no caves has none")

	# 2. Warmth: a winter storm outside (-6 C, wind 0.7, rain 0.8). In the cave the air is the year's mean for its height and no wind reaches in.
	var dir: String = "user://test_cave_shelter"
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
	items.game_seconds = func(): return 40.0 * 86400.0 + 4.0 * 3600.0   # 4 in the morning: the coldest of the night outside
	items.setup(ItemTableScript.load_default(), dir)
	items._hints_loaded = true
	items._hints = []
	items.peer_connected_hello(1, "cave-key-00001")
	items.report_position(1, cave_spot)
	var outside: float = items.warmth_target(1)
	items.cover_at = func(_p): return 2.0
	items.cave_mean_c = func(p): return WeatherScript.year_mean_c("temperate", p.y)
	var inside: float = items.warmth_target(1)
	var mean_here: float = WeatherScript.year_mean_c("temperate", cave_spot.y)
	check(absf(mean_here - 10.7) < 0.1, "the starter island's cave air at 533 m is about 10.7 C, the year mean from the grid row (%.1f; #717 row 21)" % mean_here)
	check(inside > outside + 10.0, "in the cave it is far warmer than out in the storm (%.0f inside, %.0f outside)" % [inside, outside])
	items._soak[1] = 0.0
	weather["temp_c"] = 25.0   # a hot afternoon outside changes nothing in the cave
	check(is_equal_approx(items.warmth_target(1), inside), "and the same on a hot day: cave air does not follow the weather")
	weather["temp_c"] = -6.0

	# 2b. A cave pool's water is at the cave air's year mean (Jamie #664, CONTRADICTIONS.md), warmer than the old fixed 2 C fallback.
	# Both pools are cold enough to pin a bare swimmer's target at 0, so the swimmer wears warm clothes here (insulation 0.6) to see the difference.
	var keep_insulation: Callable = items.insulation_of
	items.insulation_of = func(_peer): return 0.6
	items._swimming[1] = true
	items.set_cave_pool(1, true)
	var pool: float = items.warmth_target(1)
	var keep_cave: Callable = items.cave_mean_c
	items.cave_mean_c = Callable()
	var old_pool: float = items.warmth_target(1)
	items.cave_mean_c = keep_cave
	items.insulation_of = keep_insulation
	check(pool > old_pool, "a cave pool at the year mean (about 10.7 C) is less cold than the old 2 C (%.0f against %.0f)" % [pool, old_pool])
	items._swimming[1] = false
	items.set_cave_pool(1, false)

	# 3. Rain: in the cave it does not soak you; out of it you are wet, and in the cave only a fire dries you.
	items._update_soak(1, 1800.0)
	check(float(items._soak.get(1, 0.0)) < 0.01, "the rain does not soak you in a cave")
	items._soak[1] = 1.0
	items._update_soak(1, 3600.0)
	check(float(items._soak[1]) > 0.99, "wet in a cave you stay wet with no fire (%.2f)" % float(items._soak[1]))
	items._items[779] = {"number": 1, "count": 1, "pos": cave_spot + Vector3(1.0, 0.0, 0.0), "left": 1.0e9, "fire": {"state": 1, "burn_left": 1000.0, "covered": true, "recheck": 0.0}}
	items._lit_valid = false
	items._update_soak(1, 1800.0)
	check(float(items._soak[1]) < 0.9, "a fire dries you there (%.2f)" % float(items._soak[1]))
	items._items.erase(779)

	# 4. Under a roof outside a cave, drying still works as before.
	items.cave_mean_c = Callable()
	items._soak[1] = 1.0
	weather["rain"] = 0.0
	items._update_soak(1, 1800.0)
	check(float(items._soak[1]) < 1.0, "under a built roof you still dry slowly (%.2f)" % float(items._soak[1]))

	print("test_cave_shelter: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
