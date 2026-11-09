extends SceneTree

# Drinking water by source (docs/design/drinking_water_design.md section 6; Sonny docs/water/springs_and_drinking_water.md): springs always run,
# brooks by regime and season, a brook below a spring freezes past Sonny's open length, frozen water needs an ice hole, salt water is refused,
# and with vitals.json thirst.sources off the drink is today's. Stub rows, and a stub tile's drink sections read back as brook rows (step 2b).
#   godot --headless --path . --script res://src/worldgen/tools/test_drinking_water.gd

const DrinkRules := preload("res://src/shared/drink_rules.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const WaterRecordScript := preload("res://src/worldgen/record/water_record.gd")
const TileTerrainDataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")

const CFG := {"rain_memory_h": 24.0, "flash_memory_h": 6.0, "open_m": 440.0, "cold_x": [[-2.0, 1.8], [-5.0, 1.0], [-10.0, 0.6], [-15.0, 0.4]], "breeze_wind": 0.3, "breeze_x": 0.5}

var failures: int = 0
var rows_here: Array = []
var weather: Dictionary = {"temp_c": 10.0, "rain": 0.0}
var season: Array = ["summer"]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func ctx(season_name: String, rain_h: float, air: float, raining: bool = false) -> Dictionary:
	return {"season": season_name, "rain_h_ago": rain_h, "raining": raining, "air_c": air, "wind": 0.15}


func _init() -> void:
	_rules()
	_tile_rows()
	_server()
	print("drinking water: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _rules() -> void:
	# Spring: a drink in August and on a -10 C night, its water the year mean (5.5 C at #8002, Jamie #739), never frozen.
	var spring: Dictionary = {"kind": "spring", "dry_m3_s": 0.002, "temp_c": 5.5}
	var aug: Dictionary = DrinkRules.pick(CFG, [spring], ctx("summer", INF, 18.0))
	var frost: Dictionary = DrinkRules.pick(CFG, [spring], ctx("winter", INF, -10.0))
	check(str(aug.get("kind", "")) == "spring", "a spring is a drink in a dry August")
	check(str(frost.get("kind", "")) == "spring" and not bool(frost.get("frozen", true)), "a spring is open on a -10 C night")
	check(is_equal_approx(float(frost.get("temp_c", 0.0)), 5.5), "a spring's water is its own (the year mean): %.1f C" % float(frost.get("temp_c", 0.0)))

	# Ground springs from the record (step 2a): a row for each head within reach (level distance), its water the year mean at its height, and a head
	# the record gave no flow fails in a dry summer.
	var heads: Array = [[Vector3(10.0, 50.0, 10.0), 0.002, "bushes"], [Vector3(30.0, 52.0, 10.0), 0.0, "bushes"]]
	var mean_at: Callable = func(head: Vector3) -> float: return 14.0 - 0.0065 * head.y
	var at_spring: Array = DrinkRules.ground_spring_rows(heads, Vector3(11.5, 51.8, 11.0), 3.0, mean_at)
	check(at_spring.size() == 1 and str(at_spring[0]["kind"]) == "spring", "one ground spring row within 3 m (got %d)" % at_spring.size())
	check(at_spring.size() == 1 and is_equal_approx(float(at_spring[0]["temp_c"]), 14.0 - 0.0065 * 50.0), "a ground spring's water is the year mean at its height")
	check(DrinkRules.ground_spring_rows(heads, Vector3(20.0, 50.0, 10.0), 3.0, mean_at).is_empty(), "no row 10 m from both heads")
	var winter_pick: Dictionary = DrinkRules.pick(CFG, at_spring, ctx("winter", INF, -10.0))
	check(str(winter_pick.get("kind", "")) == "spring" and not bool(winter_pick.get("frozen", true)), "a ground spring is open on a -10 C night")
	var dry_head: Array = DrinkRules.ground_spring_rows(heads, Vector3(30.0, 52.0, 11.0), 3.0, mean_at)
	check(str(DrinkRules.pick(CFG, dry_head, ctx("summer", INF, 18.0)).get("refused", "")) == "dry", "a ground spring with no flow is dry in August")

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

	# Jamie #739's open length: 440 m x sqrt(L/s) in calm air at -5 C, x1.8 at -2, x0.6 at -10, x0.4 at -15, halved in a breeze. Sonny's
	# worked spring (2 L/s, -4 C night) comes out at about 790 m (his heat-loss sum gave 810).
	var near: Dictionary = {"kind": "brook", "regime": 1, "below_spring_m": 500.0, "q_m3_s": 0.002, "width_m": 0.5, "spring_c": 5.5}
	near["iced"] = true
	var far: Dictionary = near.duplicate()
	far["below_spring_m"] = 1000.0
	var far_thin: Dictionary = far.duplicate()
	far_thin["iced"] = false
	var x0: float = DrinkRules.open_length_m(CFG, near, -4.0, 0.15)
	check(absf(x0 - 788.0) < 15.0, "open length on a calm -4 C night is about 790 m (%.0f m)" % x0)
	check(absf(DrinkRules.open_length_m(CFG, near, -5.0, 0.15) - 622.0) < 5.0, "2 L/s at -5 C calm: 440 x 1.41 = 622 m")
	check(absf(DrinkRules.open_length_m(CFG, near, -4.0, 0.5) - 394.0) < 10.0, "in a breeze it is halved")
	check(DrinkRules.open_length_m(CFG, near, -20.0, 0.15) < DrinkRules.open_length_m(CFG, near, -10.0, 0.15), "colder: shorter (held at x0.4 past -15)")
	check(not bool(DrinkRules.pick(CFG, [near], ctx("winter", INF, -4.0)).get("frozen", true)), "the brook is open 500 m below its spring")
	check(bool(DrinkRules.pick(CFG, [far], ctx("winter", INF, -4.0)).get("frozen", false)), "the brook is frozen 1000 m below its spring")
	check(not bool(DrinkRules.pick(CFG, [far_thin], ctx("winter", INF, -4.0)).get("frozen", true)), "past the open length but with no bearing ice there (_on_ice false): open, no hole asked")
	check(not bool(DrinkRules.pick(CFG, [far], ctx("winter", INF, 2.0)).get("frozen", true)), "above 0 C nothing freezes")

	# Still water follows the ice rule at the spot.
	check(bool(DrinkRules.pick(CFG, [{"kind": "lake", "iced": true}], ctx("winter", INF, -6.0)).get("frozen", false)), "an iced lake is frozen")

	# Salt: refused alone, and a lake within reach still wins. Order: spring before lake before puddle.
	check(str(DrinkRules.pick(CFG, [{"kind": "salt"}], ctx("summer", 1.0, 15.0)).get("refused", "")) == "salt", "the sea alone is refused as salt")
	check(str(DrinkRules.pick(CFG, [{"kind": "salt"}, {"kind": "lake"}], ctx("summer", 1.0, 15.0)).get("kind", "")) == "lake", "a lake 2 m off wins over the sea")
	check(str(DrinkRules.pick(CFG, [{"kind": "puddle"}, {"kind": "lake"}, spring], ctx("autumn", 1.0, 8.0)).get("kind", "")) == "spring", "the cleanest source within reach wins")
	check(DrinkRules.pick(CFG, [], ctx("summer", 1.0, 15.0)).is_empty(), "no rows, no answer")


# Step 2b on a 3 x 3 stub tile: the drink sections (water_record.gd encode_drink) read back as brook rows (TileTerrainData.drink_row), and
# the rows behave by regime: a perennial brook runs in a dry August, an intermittent one with no spring is a dry bed.
func _tile_rows() -> void:
	var drink: Dictionary = {
		"regime": PackedFloat32Array([0, 1, 2, 0, 3, 0, 0, 0, 0]),
		"width_m": PackedFloat32Array([0, 0.8, 2.5, 0, 0.3, 0, 0, 0, 0]),
		"below_spring_m": PackedFloat32Array([NAN, 120.0, NAN, NAN, NAN, NAN, NAN, NAN, NAN]),
		"spring_q": PackedFloat32Array([0, 0.002, 0, 0, 0, 0, 0, 0, 0]),
		"spring_y": PackedFloat32Array([0, 88.4, 0, 0, 0, 0, 0, 0, 0]),
	}
	var tile = TileTerrainDataScript.new()
	tile.samples = 3
	tile.load_drink_sections(WaterRecordScript.encode_drink(drink))
	var mean_c: Callable = func(height: float) -> float: return 12.0 - 0.01 * height
	var brook: Dictionary = tile.drink_row(1, mean_c)
	check(str(brook.get("kind", "")) == "brook" and int(brook.get("regime", 0)) == 1 and bool(brook.get("dry_ok", false)), "sample 1 is a perennial brook (%s)" % str(brook))
	check(absf(float(brook.get("below_spring_m", 0.0)) - 120.0) < 0.01 and absf(float(brook.get("q_m3_s", 0.0)) - 0.002) < 1.0e-6, "120 m below a 2 L/s spring (%s)" % str(brook))
	check(absf(float(brook.get("width_m", 0.0)) - 0.8) < 0.01 and absf(float(brook.get("spring_c", 0.0)) - mean_c.call(88.4)) < 0.001, "0.8 m wide, the spring's water the year mean at 88.4 m (%s)" % str(brook))
	var bed: Dictionary = tile.drink_row(2, mean_c)
	check(int(bed.get("regime", 0)) == 2 and is_inf(float(bed.get("below_spring_m", 0.0))) and not bed.has("spring_c"), "sample 2 is an intermittent brook with no spring (%s)" % str(bed))
	check(int(tile.drink_row(4, mean_c).get("regime", 0)) == 3 and tile.drink_row(0, mean_c).is_empty() and tile.drink_row(8, mean_c).is_empty(), "a gully at 4; no brook off the channels")
	var august: Dictionary = ctx("summer", 72.0, 24.0)
	check(DrinkRules.runs(CFG, brook, august) and not DrinkRules.runs(CFG, bed, august), "in a dry August the perennial brook runs and the intermittent bed is dry")
	# The client's drink points (DrinkRules.chunk_points, net drink_points): the brook cells on the world sample grid, a lake cell left out (the
	# server gives a lake row there), and the ground spring heads in the chunk.
	tile.spacing_m = 8.0
	tile.water_class = PackedByteArray([0, 0, 2, 0, 0, 0, 0, 0, 0])
	tile.ground_springs = [[Vector3(4.0, 1.0, 4.0), 0.002, "bushes", 0.002], [Vector3(40.0, 1.0, 4.0), 0.002, "bushes", 0.002]]
	var points: Array = DrinkRules.chunk_points(tile, Vector2.ZERO, 24.0)
	check(points[0] == PackedInt32Array([1, 0, 2, 1, 1, 4]), "drink points: the perennial cell and the gully, not the lake cell (%s)" % str(points[0]))
	check(points[1] == PackedFloat32Array([4.0, 4.0]), "drink points: the spring head in the chunk, not the one beyond it (%s)" % str(points[1]))
	var empty = TileTerrainDataScript.new()
	empty.samples = 3
	check(empty.drink_row(1, mean_c).is_empty() and not empty.has_drink(), "a tile with no drink sections gives no brook rows")


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
	check(bool(sources.get("enabled", false)), "thirst.sources ships on (Dave 8 Nov)")
	sources["enabled"] = false
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

	# The season is the place's own (Weather.season_at, half a year off across the equator): the calendar says winter, but at
	# the player it is summer, so an intermittent brook long without rain is dry there.
	season[0] = "winter"
	items._last_rain_s = -INF
	items.season_at = func(_pos): return "summer"
	rows_here = [{"kind": "brook", "regime": 2}]
	check(not _drinks(items, v), "the drink reads the season at the player, not the calendar's")
	items.season_at = Callable()
	check(_drinks(items, v), "without season_at the calendar's season stands (winter: the brook runs)")

	# The terrain server's rows carry no ice field: the server's own ice rule at the player (_on_ice, the fishing ice) decides.
	items._holes.clear()
	items.ice_cover_at = func(_pos): return 1.0
	rows_here = [{"kind": "lake"}]
	check(not _drinks(items, v), "a lake row without an ice field is frozen where the ice rule says ice")
	items.ice_cover_at = Callable()
	check(_drinks(items, v), "and a drink where it says none")

	# The sea: no drinking water in reach (the sim holds no sea), salt water is: the salt line, not the plain refusal.
	var said: Array = []
	items.send_notice = func(_p, text): said.append(str(text))
	items.water_near = func(_pos, _reach): return false
	rows_here = [{"kind": "salt"}]
	check(not _drinks(items, v) and said.has(str(sources.get("say_salt", ""))), "at the sea the player hears the salt line (%s)" % str(said))

	# Where the settled water shows nothing (docs/design/drink_prompt_design.md (a)): a ground spring head is a drink, a dry August bed of a
	# record brook is "The bed is dry", and with no record row it is the plain refusal as before.
	season[0] = "summer"
	items._last_rain_s = -INF
	rows_here = [{"kind": "spring", "dry_m3_s": 0.002, "temp_c": 12.0}]
	check(_drinks(items, v), "a ground spring head the settled water does not show is a drink")
	said.clear()
	rows_here = [{"kind": "brook", "regime": 2}]
	check(not _drinks(items, v) and said.has(str(sources.get("say_dry", ""))), "a record brook's dry August bed says the bed is dry (%s)" % str(said))
	rows_here = []
	check(not _drinks(items, v), "no water shown and no record row: no drink")
	items.water_near = func(_pos, _reach): return true


func _drinks(items, v: Dictionary) -> bool:
	v["wet"] = 500.0
	items._last_drink.clear()
	items.action(1, Net.ACT_DRINK, -1, 0, 0, Vector3.ZERO)
	return float(v["wet"]) > 500.0
