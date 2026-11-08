extends SceneTree

# Drinking water by source (docs/design/drinking_water_design.md section 6; Sonny docs/water/springs_and_drinking_water.md): springs always run,
# brooks by regime and season, a brook below a spring freezes past Sonny's open length, frozen water needs an ice hole, salt water is refused,
# and with vitals.json thirst.sources off the drink is today's. Stub rows only: nothing reads a record yet (build step 1).
#   godot --headless --path . --script res://src/worldgen/tools/test_drinking_water.gd

const DrinkRules := preload("res://src/shared/drink_rules.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const CFG := {"rain_memory_h": 24.0, "flash_memory_h": 6.0, "night_h_w_m2k": 20.0}

var failures: int = 0
var rows_here: Array = []
var weather: Dictionary = {"temp_c": 10.0, "rain": 0.0}
var season: Array = ["summer"]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func ctx(season_name: String, rain_h: float, air: float, raining: bool = false) -> Dictionary:
	return {"season": season_name, "rain_h_ago": rain_h, "raining": raining, "air_c": air}


func _init() -> void:
	_rules()
	_server()
	print("drinking water: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _rules() -> void:
	# Spring: a drink in August and on a -10 C night, its water the year mean + 1 (6.5 C at cave 8002), never frozen.
	var spring: Dictionary = {"kind": "spring", "dry_m3_s": 0.002, "temp_c": 6.5}
	var aug: Dictionary = DrinkRules.pick(CFG, [spring], ctx("summer", INF, 18.0))
	var frost: Dictionary = DrinkRules.pick(CFG, [spring], ctx("winter", INF, -10.0))
	check(str(aug.get("kind", "")) == "spring", "a spring is a drink in a dry August")
	check(str(frost.get("kind", "")) == "spring" and not bool(frost.get("frozen", true)), "a spring is open on a -10 C night")
	check(is_equal_approx(float(frost.get("temp_c", 0.0)), 6.5), "a spring's water is its own (year mean + 1): %.1f C" % float(frost.get("temp_c", 0.0)))

	# Brook regime 2: dry in summer, wet in summer within a day of rain, wet in autumn.
	var brook2: Dictionary = {"kind": "brook", "regime": 2}
	check(str(DrinkRules.pick(CFG, [brook2], ctx("summer", 48.0, 18.0)).get("refused", "")) == "dry", "an intermittent brook is dry in summer after 2 days without rain")
	check(str(DrinkRules.pick(CFG, [brook2], ctx("summer", 12.0, 18.0)).get("kind", "")) == "brook", "an intermittent brook runs in summer within a day of rain")
	check(str(DrinkRules.pick(CFG, [brook2], ctx("autumn", 300.0, 8.0)).get("kind", "")) == "brook", "an intermittent brook runs in autumn")

	# Brook regime 3: only in rain or within 6 h of it.
	var gully: Dictionary = {"kind": "brook", "regime": 3}
	check(str(DrinkRules.pick(CFG, [gully], ctx("autumn", 3.0, 8.0)).get("kind", "")) == "brook", "an ephemeral gully holds water 3 h after rain")
	check(str(DrinkRules.pick(CFG, [gully], ctx("autumn", 10.0, 8.0)).get("refused", "")) == "dry", "an ephemeral gully is dry 10 h after rain")
	check(str(DrinkRules.pick(CFG, [gully], ctx("winter", INF, 2.0, true)).get("kind", "")) == "brook", "an ephemeral gully runs while it rains")

	# Brook below a spring in a dry summer: a drink where the row keeps baseflow, dry where q_base_dry is 0.
	var above: Dictionary = {"kind": "brook", "regime": 2, "dry_ok": true}
	var below: Dictionary = {"kind": "brook", "regime": 2, "dry_ok": false}
	check(str(DrinkRules.pick(CFG, [above], ctx("summer", INF, 18.0)).get("kind", "")) == "brook", "in August the spring's brook runs above its dry end")
	check(str(DrinkRules.pick(CFG, [below], ctx("summer", INF, 18.0)).get("refused", "")) == "dry", "in August the bed is dry below it")

	# Sonny's worked example: Q 0.002 m3/s, W 0.5 m, spring 6.5 C, -4 C night, h 20: lambda 838 m, x0 about 810 m.
	var near: Dictionary = {"kind": "brook", "regime": 1, "below_spring_m": 500.0, "q_m3_s": 0.002, "width_m": 0.5, "spring_c": 6.5}
	var far: Dictionary = near.duplicate()
	far["below_spring_m"] = 1000.0
	var x0: float = DrinkRules.open_length_m(near, -4.0, 20.0)
	check(absf(x0 - 810.0) < 15.0, "open length on a -4 C night is about 810 m (%.0f m)" % x0)
	check(not bool(DrinkRules.pick(CFG, [near], ctx("winter", INF, -4.0)).get("frozen", true)), "the brook is open 500 m below its spring")
	check(bool(DrinkRules.pick(CFG, [far], ctx("winter", INF, -4.0)).get("frozen", false)), "the brook is frozen 1000 m below its spring")
	check(not bool(DrinkRules.pick(CFG, [far], ctx("winter", INF, 2.0)).get("frozen", true)), "above 0 C nothing freezes")

	# Still water follows the ice rule at the spot.
	check(bool(DrinkRules.pick(CFG, [{"kind": "lake", "iced": true}], ctx("winter", INF, -6.0)).get("frozen", false)), "an iced lake is frozen")

	# Salt: refused alone, and a lake within reach still wins. Order: spring before lake before puddle.
	check(str(DrinkRules.pick(CFG, [{"kind": "salt"}], ctx("summer", 1.0, 15.0)).get("refused", "")) == "salt", "the sea alone is refused as salt")
	check(str(DrinkRules.pick(CFG, [{"kind": "salt"}, {"kind": "lake"}], ctx("summer", 1.0, 15.0)).get("kind", "")) == "lake", "a lake 2 m off wins over the sea")
	check(str(DrinkRules.pick(CFG, [{"kind": "puddle"}, {"kind": "lake"}, spring], ctx("autumn", 1.0, 8.0)).get("kind", "")) == "spring", "the cleanest source within reach wins")
	check(DrinkRules.pick(CFG, [], ctx("summer", 1.0, 15.0)).is_empty(), "no rows, no answer")


func _server() -> void:
	var dir: String = "user://test_drinking_water"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 0.0
	items.water_near = func(_pos, _reach): return true
	items.water_source = func(_pos, _reach): return rows_here
	items.weather_now = func(): return weather
	items.season_now = func(): return season[0]
	items.game_seconds = func(): return 1000.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "drinkwater0001")
	items.report_position(1, Vector3(0.0, 0.0, 0.0))
	var v: Dictionary = items.vitals_of(1)
	var sources: Dictionary = items._vitals_cfg["thirst"]["sources"]

	# Flag off: the sea row is ignored and today's drink goes on.
	check(not bool(sources.get("enabled", true)), "thirst.sources ships off")
	rows_here = [{"kind": "salt"}]
	check(_drinks(items, v), "flag off: today's drink, whatever the rows say")

	sources["enabled"] = true
	check(not _drinks(items, v), "flag on: the sea alone is refused")
	rows_here = [{"kind": "salt"}, {"kind": "lake"}]
	check(_drinks(items, v), "flag on: a lake beside the sea is a drink")

	# Frozen: no hole, no drink; with the fishing hole, a drink.
	season[0] = "winter"
	weather = {"temp_c": -6.0, "rain": 0.0}
	rows_here = [{"kind": "lake", "iced": true}]
	check(not _drinks(items, v), "frozen lake without a hole is refused")
	items._holes.append({"pos": Vector3(1.0, 0.0, 0.0), "until": 1.0e12})
	check(_drinks(items, v), "frozen lake with an ice hole within reach is a drink")

	# A dry bed is refused; no rows at all falls back to today's test.
	season[0] = "summer"
	weather = {"temp_c": 18.0, "rain": 0.0}
	rows_here = [{"kind": "brook", "regime": 3}]
	check(not _drinks(items, v), "a dry gully in summer is refused")
	rows_here = []
	check(_drinks(items, v), "no source rows: today's water test stands")


func _drinks(items, v: Dictionary) -> bool:
	v["wet"] = 500.0
	items._last_drink.clear()
	items.action(1, Net.ACT_DRINK, -1, 0, 0, Vector3.ZERO)
	return float(v["wet"]) > 500.0
