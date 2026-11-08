extends SceneTree

# Animals in fog, the server half (docs/design/animals_in_fog_server.md section 7; Jamie docs/knowledge/fog-and-visibility.md; MikeW
# ANIMAL_FOG.md): the visibility V at a point (from mist, or the weather's visibility_m, clear above the layer); sight full to V/4 and gone
# past V/2, so an unseen player is sensed by hearing and smell only; wolves shadow at half V in dense fog; perched birds sit out thick fog;
# deer keep their dawn hours later. With animals.json weather.fog.on false the old flat mist cut stands.
#   godot --headless --path . --script res://src/worldgen/tools/test_animals_fog.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")

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

	# Flag off: the old flat mist cut.
	check(not bool(fog.get("on", true)), "weather.fog ships off")
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0}, 0.1)
	a.ground_height = Callable()
	check(near(a._sight({"pos": Vector3.ZERO}, deer, Vector3(30.0, 0.0, 0.0), 30.0, false), 0.4), "flag off: thick mist cuts sight to 0.4 at any distance")
	fog["on"] = true

	# V.
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	check(near(a.fog_v(Vector3.ZERO), 20000.0), "no mist: V is 20 km")
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0}, 0.1)
	check(near(a.fog_v(Vector3.ZERO), 120.0), "mist 1 inside the layer: V is 120 m (%.0f)" % a.fog_v(Vector3.ZERO))
	check(near(a.fog_v(Vector3(0.0, 70.0, 0.0)), 20000.0), "20 m above the top: clear (%.0f)" % a.fog_v(Vector3(0.0, 70.0, 0.0)))
	check(near(a.fog_v(Vector3(0.0, 50.0, 0.0)), sqrt(20000.0 * 120.0)), "at the top: halfway in log (%.0f)" % a.fog_v(Vector3(0.0, 50.0, 0.0)))
	a._read_weather({"wind": 0.0, "mist": 0.6, "mist_top_m": 50.0}, 0.1)
	check(a.fog_v(Vector3.ZERO) > 800.0 and a.fog_v(Vector3.ZERO) < 1100.0, "mist 0.6: fog, about 930 m (%.0f)" % a.fog_v(Vector3.ZERO))
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0, "visibility_m": 60.0}, 0.1)
	check(near(a.fog_v(Vector3.ZERO), 60.0), "the weather's visibility_m wins inside the layer")

	# Sight share at V 120: full to 30 m, half at 45 m, none past 60 m.
	check(near(a.fog_sight_share(25.0, 120.0), 1.0) and near(a.fog_sight_share(45.0, 120.0), 0.5) and near(a.fog_sight_share(70.0, 120.0), 0.0), "sight share 1, 0.5, 0 at 25, 45, 70 m in V 120")

	# Spook: in V 40 a standing player 25 m off is past the deer's 30 m spook range; in clear air the same player is inside it.
	var deer_row: Dictionary = {"pos": Vector3.ZERO}
	var p: Vector3 = Vector3(25.0, 0.0, 0.0)
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0, "visibility_m": 40.0}, 0.1)
	var foggy: float = 25.0 / a._sense_factor(deer_row, deer, p, 25.0, 0)
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	var clear: float = 25.0 / a._sense_factor(deer_row, deer, p, 25.0, 0)
	var spook: float = float(deer.get("spook_m", 30.0))
	check(foggy > spook and clear <= spook, "in V 40 a deer senses a player 25 m off at %.0f m (spook %.0f), in clear air at %.0f m" % [foggy, spook, clear])
	check(near(a.weather_spook_x(deer), 1.0), "flag on: no flat mist cut on the spook range")

	# Wolves: 25 m in clear air and in V 120, 15 m in V 30, never under 10 m.
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	check(near(a.fog_stalk_m(25.0, Vector3.ZERO), 25.0), "clear air: the pack shadows at 25 m")
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0, "visibility_m": 120.0}, 0.1)
	check(near(a.fog_stalk_m(25.0, Vector3.ZERO), 25.0), "V 120: still 25 m")
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0, "visibility_m": 30.0}, 0.1)
	check(near(a.fog_stalk_m(25.0, Vector3.ZERO), 15.0), "V 30: 15 m")
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0, "visibility_m": 8.0}, 0.1)
	check(near(a.fog_stalk_m(25.0, Vector3.ZERO), 10.0), "V 8: never under 10 m")

	# Birds: a perched crow with its timer run out stays up in V 100 and comes down in clear air.
	a.ground_height = func(_x, _z): return 0.0
	var crow: Dictionary = {"sp": "crow", "pos": Vector3(0.0, 8.0, 0.0), "perched": true, "timer": 0.0, "state": 0}
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0, "visibility_m": 100.0}, 0.1)
	a.flight.step(crow, 0.1, 1.0e9, Vector3.INF)
	check(bool(crow.get("perched", false)) and not crow.has("fly"), "in V 100 a perched crow sits it out")
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	a.flight.step(crow, 0.1, 1.0e9, Vector3.INF)
	check(crow.has("fly"), "in clear air it comes down")
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0, "visibility_m": 100.0}, 0.1)
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
