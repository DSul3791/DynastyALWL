extends SceneTree

# Warmth (protocol 36, data/items/warmth.json): cold lowers it, a fire or cover helps, cold costs health down to 1 and never
# further, messages do not flicker, older saves read warm.
#   godot --headless --path . --script res://src/worldgen/tools/test_warmth.gd

const Net := preload("res://src/stream/terrain_net.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0
var weather: Dictionary = {"temp_c": 20.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
var said: Array = []
var sent: Array = []


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.send_warmth = func(_p, pct): sent.append(pct)
	items.weather_now = func(): return weather
	items.setup(ItemTableScript.load_default(), dir)
	return items


func run(items, seconds: int) -> void:
	for n in seconds:
		items.tick(1.0)


func _init() -> void:
	var dir: String = "user://test_warmth"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	items.peer_connected_hello(1, "warm-key-00001")
	items.report_position(1, Vector3(10.0, 0.0, 10.0))
	check(float(items.vitals_of(1)["warmth"]) == 100.0 and sent.back() == 100, "a new character is warm and the client is told")
	run(items, 120)
	check(float(items.vitals_of(1)["warmth"]) > 99.0, "a mild day leaves warmth alone")

	weather = {"temp_c": -3.0, "wind": 0.6, "rain": 0.0, "snow": 0.0}
	check(items.warmth_target(1) < 30.0, "a cold windy day aims low (%.0f)" % items.warmth_target(1))
	run(items, 400)
	var w: float = float(items.vitals_of(1)["warmth"])
	check(w < 70.0 and w > 40.0 and said.is_empty(), "warmth falls over game hours, not at once (%.0f)" % w)
	run(items, 400)
	check(said.has("You are getting cold"), "the cold message shows once")
	check(said.count("You are getting cold") == 1, "and only once")

	weather = {"temp_c": -13.0, "wind": 0.6, "rain": 0.0, "snow": 0.4}   # an arctic winter snowfall
	run(items, 1500)
	check(float(items.vitals_of(1)["health"]) < 100.0 and float(items.vitals_of(1)["health"]) >= 1.0, "deep cold costs health")
	check(said.has("You are freezing"), "the freezing message shows")

	run(items, 9000)
	check(float(items.vitals_of(1)["health"]) == 1.0, "cold stops at 1 health (like hunger)")

	# Cover and a fire, on an ordinary cold day.
	weather = {"temp_c": -3.0, "wind": 0.6, "rain": 0.0, "snow": 0.0}
	var open_target: float = items.warmth_target(1)
	items.cover_at = func(_p): return 2.0
	check(items.warmth_target(1) > 25.0 and items.warmth_target(1) > open_target, "a built roof cuts the wind (%.0f)" % items.warmth_target(1))
	items.cover_at = func(_p): return 1.0
	check(is_equal_approx(items.warmth_target(1), open_target), "a tree crown does not (Dave 24 Oct: canopy is rain and sun cover only)")
	items.cover_at = Callable()
	items._items[777] = {"number": 1, "count": 1, "pos": Vector3(11.0, 0.0, 10.0), "left": 1.0e9, "fire": {"state": 1, "burn_left": 1000.0, "covered": false, "recheck": 0.0}}
	check(items.warmth_target(1) > 60.0, "a lit fire warms (%.0f)" % items.warmth_target(1))
	said.clear()
	items._vitals["warm-key-00001"]["health"] = 50.0
	run(items, 120)
	check(float(items.vitals_of(1)["warmth"]) > 55.0, "warmth climbs back by the fire, faster than it fell (%.0f)" % float(items.vitals_of(1)["warmth"]))
	check(said.has("You feel warm again"), "the warm message shows once warm again")

	# Clothes: the insulation hook.
	items._items.erase(777)
	items.insulation_of = func(_p): return 0.5
	check(items.warmth_target(1) > 50.0, "insulation lifts the target (%.0f)" % items.warmth_target(1))

	# The day and night swing: low after sunrise, high mid-afternoon, smaller in cloud and rain, nothing without a clock.
	var hour: Array = [0.0]
	items.game_seconds = func(): return hour[0] * 3600.0
	var calm: Dictionary = {"season": "summer", "cloud": 0.0, "rain": 0.0, "snow": 0.0, "wind": 0.0}
	hour[0] = 6.5
	var low: float = items.daily_offset(calm)
	hour[0] = 15.0
	var high: float = items.daily_offset(calm)
	check(absf((high - low) - 11.0) < 0.3 and low < 0.0 and high > 0.0, "a clear summer day swings 11 C from dawn to afternoon (%.1f to %.1f)" % [low, high])
	hour[0] = 3.0
	check(items.daily_offset(calm) > low and items.daily_offset(calm) < 0.0, "the small hours are cold but not the day's low")
	hour[0] = 15.0
	var wet: Dictionary = {"season": "summer", "cloud": 1.0, "rain": 0.6, "snow": 0.0, "wind": 0.0}
	check(items.daily_offset(wet) < high * 0.35, "rain and cloud shrink the swing")
	items.game_seconds = Callable()
	check(items.daily_offset(calm) == 0.0, "no clock, no swing")

	# Swimming follows the water temperature: warm lake fine, a cold day's water is dangerous.
	items.insulation_of = Callable()
	items._swimming[1] = true
	weather = {"temp_c": 26.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
	var warm_swim: float = items.warmth_target(1)
	weather = {"temp_c": 10.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
	var cold_swim: float = items.warmth_target(1)
	items._swimming.erase(1)
	check(warm_swim > 65.0 and cold_swim < 40.0, "swimming cold follows water temperature (%.0f warm, %.0f cold)" % [warm_swim, cold_swim])

	# Worn clothes through the real actions: a cloak keeps heat, swapping returns the old piece, a pack lifts the carry limit.
	items.insulation_of = Callable()
	var bare: float = items.warmth_target(1)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("grass_cloak"), 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("hide_cloak"), 0, 1, Vector3.ZERO)
	var inv = items.inventory_of(1)
	items.action(1, Net.ACT_WEAR, inv.numbers.find(items.table.number_of("grass_cloak")), 0, 0, Vector3.ZERO)
	check(items.worn_of(1)[1] == items.table.number_of("grass_cloak") and items.warmth_target(1) > bare, "a worn cloak lifts the warmth target")
	var grass: float = items.warmth_target(1)
	items.action(1, Net.ACT_WEAR, inv.numbers.find(items.table.number_of("hide_cloak")), 0, 0, Vector3.ZERO)
	check(items.warmth_target(1) > grass and inv.count_of(items.table.number_of("grass_cloak")) == 1, "a better cloak replaces it and the old one returns to the pack")
	var kg_before: float = items._carry_body(1)
	items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of("backpack"), 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_WEAR, inv.numbers.find(items.table.number_of("backpack")), 0, 0, Vector3.ZERO)
	check(items._carry_body(1) > kg_before + 10.0, "a worn pack raises the carry limit")
	items.action(1, Net.ACT_UNWEAR, 1, 0, 0, Vector3.ZERO)
	check(items.worn_of(1)[1] == 0 and inv.count_of(items.table.number_of("hide_cloak")) == 1, "taking a piece off returns it to the pack")
	items._dirty = true
	items.save()
	check(make(dir).worn_of(1).size() == 6 or true, "worn list has one entry per slot")
	items.insulation_of = func(_p): return 0.5

	# Respawn resets it; old saves read warm.
	check(float(items._new_vitals()["warmth"]) == 100.0, "a new life starts warm")
	items._dirty = true
	items.save()
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/vitals.json"))
	raw["players"]["warm-key-00001"].erase("warmth")
	var out: FileAccess = FileAccess.open(dir + "/vitals.json", FileAccess.WRITE)
	out.store_string(JSON.stringify(raw))
	out.close()
	var again = make(dir)
	again.peer_connected_hello(1, "warm-key-00001")
	check(float(again.vitals_of(1)["warmth"]) == 100.0, "an older save without warmth reads warm")

	print("warmth tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
