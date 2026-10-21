extends SceneTree

# Warmth (protocol 36, data/items/warmth.json): cold lowers it, a fire or cover helps, cold costs health down to 1 and never
# further, messages do not flicker, older saves read warm.
#   godot --headless --path . --script res://src/worldgen/tools/test_warmth.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0
var weather: Dictionary = {"temp_c": 15.0, "wind": 0.0, "rain": 0.0, "snow": 0.0}
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

	weather = {"temp_c": -8.0, "wind": 0.6, "rain": 0.0, "snow": 0.0}
	check(items.warmth_target(1) < 30.0, "a cold windy day aims low (%.0f)" % items.warmth_target(1))
	run(items, 400)
	var w: float = float(items.vitals_of(1)["warmth"])
	check(w < 70.0 and w > 40.0 and said.is_empty(), "warmth falls over game hours, not at once (%.0f)" % w)
	run(items, 400)
	check(said.has("You are getting cold"), "the cold message shows once")
	check(said.count("You are getting cold") == 1, "and only once")

	weather = {"temp_c": -18.0, "wind": 0.6, "rain": 0.0, "snow": 0.4}   # an arctic winter snowfall
	run(items, 1500)
	check(float(items.vitals_of(1)["health"]) < 100.0 and float(items.vitals_of(1)["health"]) >= 1.0, "deep cold costs health")
	check(said.has("You are freezing"), "the freezing message shows")

	run(items, 9000)
	check(float(items.vitals_of(1)["health"]) == 1.0, "cold stops at 1 health (like hunger)")

	# Cover and a fire, on an ordinary cold day.
	weather = {"temp_c": -8.0, "wind": 0.6, "rain": 0.0, "snow": 0.0}
	items.cover_at = func(_p): return 1.0
	check(items.warmth_target(1) > 25.0, "cover cuts the wind (%.0f)" % items.warmth_target(1))
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
