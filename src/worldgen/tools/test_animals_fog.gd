extends SceneTree

# Animals in fog, the server half (docs/design/animals_in_fog_server.md section 7; Jamie docs/knowledge/fog-and-visibility.md; MikeW
# ANIMAL_FOG.md): the visibility V at a point (Weather.visibility_m, the client look's rule, #724; clear above the layer); sight full to V/4 and gone
# past V/2, so an unseen player is sensed by hearing and smell only; wolves shadow at half V in dense fog; perched birds sit out thick fog;
# deer keep their dawn hours later. Always on with the weather rules (the fog.on switch and the old flat mist cut are gone, 9 Nov 2026).
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

	check(not fog.has("on") and a.fog_on(), "the fog rules are always on (no switch, no old flat mist cut)")
	a.ground_height = Callable()

	# V (Weather.visibility_m, the rule the client's look draws by, #724).
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	check(near(a.fog_v(Vector3.ZERO), 3333.3), "clear air: V about 3.3 km (%.0f)" % a.fog_v(Vector3.ZERO))
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0}, 0.1)
	check(near(a.fog_v(Vector3.ZERO), 222.2), "full valley fog inside the layer: about 220 m (%.0f)" % a.fog_v(Vector3.ZERO))
	check(near(a.fog_v(Vector3(0.0, 70.0, 0.0)), 3333.3), "20 m above the top: clear (%.0f)" % a.fog_v(Vector3(0.0, 70.0, 0.0)))
	check(near(a.fog_v(), 222.2), "the layer's own V for rules with no position")
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0, "rain": 1.0}, 0.1)
	check(near(a.fog_v(Vector3.ZERO), 166.7) and near(a.fog_v(), 222.2), "fog and heavy rain: the 167 m cap at a point; the layer's own V is still the fog's")
	a._read_weather({"wind": 0.0, "mist": 0.0, "rain": 1.0}, 0.1)
	check(a.fog_v() >= 3333.0, "heavy rain alone does not set off the fog rules")

	# Sight share at V 120: full to 30 m, half at 45 m, none past 60 m.
	check(near(AnimalsScript.fog_sight_share(25.0, 120.0), 1.0) and near(AnimalsScript.fog_sight_share(45.0, 120.0), 0.5) and near(AnimalsScript.fog_sight_share(70.0, 120.0), 0.0), "sight share 1, 0.5, 0 at 25, 45, 70 m in V 120")

	# Sensing: in full valley fog a standing player 100 m off seems about 200 m off; in clear air 100 m.
	var deer_row: Dictionary = {"pos": Vector3.ZERO}
	var p: Vector3 = Vector3(100.0, 0.0, 0.0)
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0}, 0.1)
	var foggy: float = 100.0 / a._sense_factor(deer_row, deer, p, 100.0, 0)
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	var clear: float = 100.0 / a._sense_factor(deer_row, deer, p, 100.0, 0)
	check(foggy > 180.0 and foggy < 230.0 and near(clear, 100.0), "100 m off: sensed at %.0f m in full valley fog, %.0f m in clear air" % [foggy, clear])
	check(near(a.weather_spook_x(deer), 1.0), "flag on: no flat mist cut on the spook range")

	# Wolves: the ring.
	check(near(AnimalsScript.fog_ring_m(25.0, 3333.0, 10.0), 25.0) and near(AnimalsScript.fog_ring_m(25.0, 222.0, 10.0), 25.0), "the pack shadows at 25 m in clear air and in full valley fog")
	check(near(AnimalsScript.fog_ring_m(25.0, 30.0, 10.0), 15.0) and near(AnimalsScript.fog_ring_m(25.0, 8.0, 10.0), 10.0), "15 m at V 30, never under 10 m")
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	check(near(a.fog_stalk_m(25.0, Vector3.ZERO), 25.0), "clear air through the server: 25 m")

	# Birds: a perched crow with its timer run out stays up in full valley fog and comes down in clear air.
	a.ground_height = func(_x, _z): return 0.0
	var crow: Dictionary = {"sp": "crow", "pos": Vector3(0.0, 8.0, 0.0), "perched": true, "timer": 0.0, "state": 0}
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0}, 0.1)
	a.flight.step(crow, 0.1, 1.0e9, Vector3.INF)
	check(bool(crow.get("perched", false)) and not crow.has("fly"), "in full valley fog a perched crow sits it out")
	a._read_weather({"wind": 0.0, "mist": 0.0}, 0.1)
	a.flight.step(crow, 0.1, 1.0e9, Vector3.INF)
	check(crow.has("fly"), "in clear air it comes down")
	a._read_weather({"wind": 0.0, "mist": 1.0, "mist_top_m": 50.0}, 0.1)
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
