extends SceneTree

# Animals in fog, the server half (docs/design/animals_in_fog_server.md section 7; Jamie docs/knowledge/fog-and-visibility.md; MikeW
# ANIMAL_FOG.md; Dave's fog instruction 14 Nov 2026): the fog at a point (Weather.fog_shape, the depth fog the client draws, over the cold-air
# floor; clear above the layer); sight full while the fog takes under 53 % and gone once it takes 78 %, so an unseen player is sensed by
# hearing and smell only; wolves shadow at half V in dense fog; perched birds sit out thick fog;
# deer keep their dawn hours later. Always on with the weather rules (the fog.on switch and the old flat mist cut are gone, 9 Nov 2026).
#   godot --headless --path . --script res://src/worldgen/tools/test_animals_fog.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const FogShape := preload("res://src/shared/fog_shape.gd")
const FogGroundScript := preload("res://src/shared/fog_ground.gd")
const WeatherRules := preload("res://src/shared/weather.gd")

var failures: int = 0
var hour: float = 12.0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func near(x: float, y: float, tol: float = 0.01) -> bool:
	return absf(x - y) <= tol * maxf(absf(y), 1.0)


func make():
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 0.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return []
	a.player_stances = func(): return []
	a.hour_now = func(): return hour
	a.weather_ahead = func(_h): return {}
	a.setup()
	a.traits = false
	a.rng.seed = 7
	return a


func _init() -> void:
	var a = make()
	var deer: Dictionary = a.species_def("deer")
	var fog: Dictionary = a._wx_rules()["fog"]

	check(not fog.has("on") and a.fog_on(), "the fog rules are always on (no switch, no old flat mist cut)")
	a.ground_height = Callable()

	# V (Weather.visibility_m: where the client's depth fog takes 95 %).
	var clear_v: float = FogShape.visibility(FogShape.depth(WeatherRules.VIS_HAZE_DENSITY, 0.0))
	var full_v: float = FogShape.visibility(FogShape.depth(WeatherRules.VIS_HAZE_DENSITY, 1.0))
	check(clear_v > 2500.0 and clear_v < 3100.0 and full_v > 45.0 and full_v < 60.0, "clear air about 2.8 km, full fog about 52 m (%.0f, %.0f)" % [clear_v, full_v])
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	check(near(a.fog_v(Vector3.ZERO), clear_v), "clear air through the server (%.0f)" % a.fog_v(Vector3.ZERO))
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_depth_m": 50.0}, 0.1)
	check(near(a.fog_v(Vector3.ZERO), full_v), "full valley fog inside the layer: the client's dense fog (%.0f)" % a.fog_v(Vector3.ZERO))
	check(near(a.fog_v(Vector3(0.0, 70.0, 0.0)), clear_v), "20 m above the top: clear (%.0f)" % a.fog_v(Vector3(0.0, 70.0, 0.0)))
	check(near(a.fog_v(), full_v), "the layer's own V for rules with no position")
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_depth_m": 50.0, "rain": 1.0}, 0.1)
	check(a.fog_v(Vector3.ZERO) <= full_v + 0.01 and near(a.fog_v(), full_v), "fog and heavy rain: no clearer at a point; the layer's own V is still the fog's")
	a._read_weather({"wind": 0.0, "mist": 0.0, "rain": 1.0}, 0.1)
	check(a.fog_v() >= clear_v - 0.01 and a.fog_v(Vector3.ZERO) > float(a._fog_cfg()["sit_below_m"]), "heavy rain alone does not set off the fog rules")
	a._read_weather({"wind": 0.0, "mist": 0.0, "storm": 1.0, "rain": 1.0, "snow": 1.0}, 0.1)
	check(a.fog_v(Vector3.ZERO) > float(a._fog_cfg()["sit_below_m"]), "the thickest storm alone does not ground the birds (%.0f)" % a.fog_v(Vector3.ZERO))
	# Sea fog over the land counts too, under its own top.
	a._read_weather({"wind": 0.0, "mist": 0.0, "sea_fog_land": 1.0, "sea_fog_top_m": 80.0}, 0.1)
	check(near(a.fog_v(Vector3.ZERO), full_v) and near(a.fog_v(Vector3(0.0, 100.0, 0.0)), clear_v) and near(a.fog_v(), full_v), "sea fog on the land: dense below its top, clear above")

	# The cold-air floor: a valley fog 50 m deep over a floor at 200 m fills the high basin; at sea level the old layer would be clear there.
	var basin: Dictionary = {"mist": 1.0, "mist_depth_m": 50.0}
	check(WeatherRules.visibility_m(basin, 220.0, 200.0) < 60.0 and WeatherRules.visibility_m(basin, 220.0, 0.0) > 2500.0, "a high basin's fog lies over its own floor")
	check(near(a.fog_floor(Vector3(10.0, 0.0, 10.0)), 0.0), "no tiles known: the floor is sea level (the old single layer)")
	# A real window (fog_ground.gd build_grid): a basin floored at 200 m. Inside it the fog lies over the basin; outside the window, sea level.
	var n: int = 64
	var heights := PackedFloat32Array()
	var fresh := PackedFloat32Array()
	heights.resize(n * n)
	fresh.resize(n * n)
	heights.fill(200.0)
	fresh.fill(INF)
	var ground = FogGroundScript.new()
	ground.grid = FogGroundScript.build_grid(heights, fresh, n, Vector2(5000.0, 5000.0))
	a._fog_grounds = [ground]
	var in_basin := Vector3(5000.0 + 32.0 * FogGroundScript.CELL_M, 220.0, 5000.0 + 32.0 * FogGroundScript.CELL_M)
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_depth_m": 50.0}, 0.1)
	check(absf(a.fog_floor(in_basin) - 200.0) < 1.0 and near(a.fog_v(in_basin), full_v), "through the server: the basin's floor (%.0f m) and its fog" % a.fog_floor(in_basin))
	check(near(a.fog_floor(Vector3(0.0, 220.0, 0.0)), 0.0) and near(a.fog_v(Vector3(0.0, 220.0, 0.0)), clear_v), "outside every window: sea level, so 220 m up is clear")
	a._fog_grounds = []
	# Sea cut off (the fen flats, Lane A 22 Nov 2026): a window with open sea bed west of column 16, flats at 0.3 m, a hollow at -0.4 m.
	var flats := PackedFloat32Array()
	flats.resize(n * n)

	for j in range(n):
		for i in range(n):
			flats[j * n + i] = -10.0 if i < 16 else (-0.4 if i >= 40 and i <= 44 and j >= 40 and j <= 44 else 0.3)

	var coast = FogGroundScript.new()
	coast.grid = FogGroundScript.build_grid(flats, fresh, n, Vector2(5000.0, 5000.0))
	var cell_at: Callable = func(i: int, j: int) -> Vector2: return Vector2(5000.0, 5000.0) + Vector2((float(i) + 0.5) * FogGroundScript.CELL_M, (float(j) + 0.5) * FogGroundScript.CELL_M)
	check(not a.sea_cut_off(cell_at.call(42, 42).x, cell_at.call(42, 42).y), "no window: the old rule, ground below 0 m is sea")
	a._fog_grounds = [coast]
	check(a.sea_cut_off(cell_at.call(42, 42).x, cell_at.call(42, 42).y), "a hollow below sea level cut off from the sea is not sea")
	check(not a.sea_cut_off(cell_at.call(8, 42).x, cell_at.call(8, 42).y), "the open sea is sea")
	a._fog_grounds = []
	# Along the line: both ends in the fog is the full fog; a player on the clear slope above sees and is seen through half of it.
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_depth_m": 50.0}, 0.1)
	var both_in: Vector3 = a.fog_shape_between(Vector3.ZERO, Vector3(40.0, 10.0, 0.0))
	var one_out: Vector3 = a.fog_shape_between(Vector3.ZERO, Vector3(40.0, 90.0, 0.0))
	var over: Vector3 = a.fog_shape_between(Vector3(0.0, 100.0, 0.0), Vector3(40.0, 100.0, 0.0))
	check(near(FogShape.visibility(both_in), full_v) and FogShape.visibility(one_out) > 3.0 * full_v and FogShape.visibility(one_out) < clear_v, "the line of sight: all fog %.0f m, partly out of it %.0f m" % [FogShape.visibility(both_in), FogShape.visibility(one_out)])
	check(near(FogShape.visibility(over), clear_v), "a line above the layer's top does not dip into it")
	# Clear air takes the short way and gives the same answer as the sums.
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	check(near(AnimalsScript.fog_sight_share(600.0, FogShape.depth(WeatherRules.VIS_HAZE_DENSITY, 0.0)), 1.0), "clear air: full sight inside CLEAR_SIGHT_M by the sums too")

	# Sight share in full fog: all of a player to about 31 m (the fog takes 53 %), none past about 42 m (78 %): Dave's silhouettes at 20 to 40 m.
	var dense: Vector3 = FogShape.depth(WeatherRules.VIS_HAZE_DENSITY, 1.0)
	check(near(AnimalsScript.fog_sight_share(25.0, dense), 1.0) and near(AnimalsScript.fog_sight_share(50.0, dense), 0.0), "full fog: sight 1 at 25 m, 0 at 50 m")
	var mid: float = AnimalsScript.fog_sight_share(36.5, dense)
	check(mid > 0.3 and mid < 0.7, "full fog: about half at 36 m (%.2f)" % mid)
	check(near(AnimalsScript.fog_sight_share(500.0, FogShape.depth(WeatherRules.VIS_HAZE_DENSITY, 0.0)), 1.0), "clear air: a player 500 m off is seen in full")
	var falls: bool = true
	var last: float = 2.0

	for metres in range(0, 80, 2):
		var share: float = AnimalsScript.fog_sight_share(float(metres), dense)
		falls = falls and share <= last + 1e-6
		last = share

	check(falls, "sight never grows with distance")

	# Sensing: in full valley fog a standing player 100 m off is out of sight, so only heard and smelt (senses.blind_factor: about 285 m
	# off at 0.35); in clear air 100 m.
	var deer_row: Dictionary = {"pos": Vector3.ZERO}
	var p: Vector3 = Vector3(100.0, 0.0, 0.0)
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_depth_m": 50.0}, 0.1)
	var foggy: float = 100.0 / a._sense_factor(deer_row, deer, p, 100.0, 0)
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	var clear: float = 100.0 / a._sense_factor(deer_row, deer, p, 100.0, 0)
	var blind: float = float(a.cfg["senses"]["blind_factor"])
	check(near(foggy, 100.0 / blind) and near(clear, 100.0), "100 m off: sensed at %.0f m in full valley fog (hearing and smell only), %.0f m in clear air" % [foggy, clear])
	check(near(a.weather_spook_x(deer), 1.0), "flag on: no flat mist cut on the spook range")

	# Wolves: the ring.
	check(near(AnimalsScript.fog_ring_m(25.0, clear_v, 10.0), 25.0) and near(AnimalsScript.fog_ring_m(25.0, full_v, 10.0), 25.0), "the pack shadows at 25 m in clear air and in full valley fog")
	check(near(AnimalsScript.fog_ring_m(25.0, 30.0, 10.0), 15.0) and near(AnimalsScript.fog_ring_m(25.0, 8.0, 10.0), 10.0), "15 m at V 30, never under 10 m")
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	check(near(a.fog_stalk_m(25.0, Vector3.ZERO), 25.0), "clear air through the server: 25 m")

	# Birds: a perched crow with its timer run out stays up in full valley fog and comes down in clear air.
	a.ground_height = func(_x, _z): return 0.0
	var crow: Dictionary = {"sp": "crow", "pos": Vector3(0.0, 8.0, 0.0), "perched": true, "timer": 0.0, "state": 0}
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_depth_m": 50.0}, 0.1)
	a.flight.step(crow, 0.1, 1.0e9, Vector3.INF)
	check(bool(crow.get("perched", false)) and not crow.has("fly"), "in full valley fog a perched crow sits it out")
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	a.flight.step(crow, 0.1, 1.0e9, Vector3.INF)
	check(crow.has("fly"), "in clear air it comes down")
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_depth_m": 50.0}, 0.1)
	check(near(a.weather_wander_x(a.species_def("songbirds"), "songbirds"), 0.15) and near(a.weather_wander_x(a.species_def("seabird"), "seabird"), 0.15), "in thick fog songbirds and seabirds hardly move")
	check(near(a.weather_wander_x(a.species_def("horse"), "horse"), 0.5) and near(a.fog_herd_x(deer), 0.5), "in fog stock wander half as far and herds keep half the distance")

	# Deer: 09:00 in fog counts as dusk; in clear air it is day.
	check(a.fog_period(deer, 9.0) == "dusk", "09:00 in fog: a deer keeps its dawn hours")
	check(a.fog_period(deer, 10.0) == "day", "10:00 in fog: day")
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	check(a.fog_period(deer, 9.0) == "day", "09:00 in clear air: day")

	# Wood edge: open ground with crowns 15 m off is the edge; under crowns or far from them is not.
	a.canopy = func(q: Vector3): return q.x >= 10.0
	check(a.fog_edge_ok(Vector3(0.0, 0.0, 0.0)) and not a.fog_edge_ok(Vector3(-30.0, 0.0, 0.0)) and not a.fog_edge_ok(Vector3(12.0, 0.0, 0.0)), "the wood edge test")

	print("animals in fog: %d failures" % failures)
	quit(1 if failures > 0 else 0)
