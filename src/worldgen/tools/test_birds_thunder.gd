extends SceneTree

# Birds and thunder (docs/design/birds_and_thunder_server.md section 5): the shared strike schedule is the same for the same inputs, needs
# rain 0.5 and a storm, and comes at about the client's rate; a bird within 800 m flies up (state 15) when the clap's sound reaches it,
# one farther off does not; with animals.json thunder.on false nothing happens.
#   godot --headless --path . --script res://src/worldgen/tools/test_birds_thunder.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const Thunder := preload("res://src/shared/thunder.gd")

var failures: int = 0
var game_s: Array = [100000.0]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	# The schedule.
	var storm: Dictionary = {"storm": 1.0, "rain": 1.0}
	var a1: Array = Thunder.strikes(42, 0.0, 86400.0, storm, Vector3.ZERO, 3000.0)
	var a2: Array = Thunder.strikes(42, 0.0, 86400.0, storm, Vector3.ZERO, 3000.0)
	check(a1.size() > 0 and str(a1) == str(a2), "the same seed and time give the same strikes (%d in a game day within 3 km)" % a1.size())
	check(Thunder.strikes(42, 0.0, 86400.0, {"storm": 1.0, "rain": 0.3}, Vector3.ZERO, 3000.0).is_empty(), "no thunder without heavy rain")
	check(Thunder.strikes(42, 0.0, 86400.0, {"storm": 0.0, "rain": 1.0}, Vector3.ZERO, 3000.0).is_empty(), "no thunder without a storm")
	# Client rate: a strike within 2.8 km every 14 to 45 real s (about 30), i.e. about 120 a real hour (a game day) at storm 1.
	var near: int = Thunder.strikes(7, 0.0, 86400.0 * 10.0, storm, Vector3(50000.0, 0.0, 50000.0), 2800.0).size()
	check(near > 10 * 60 and near < 10 * 240, "about the client's rate: %d strikes within 2.8 km in 10 game days" % near)

	# The flush.
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 0.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return [Vector3.ZERO]
	a.player_stances = func(): return []
	a.hour_now = func(): return 12.0
	a.weather_ahead = func(_h): return {}
	a.setup()
	a.traits = false
	a.game_seconds = func(): return game_s[0]
	a.thunder_between = func(t0, t1, _c, _r): return [[Vector3(100.0, 0.0, 0.0), (t0 + t1) * 0.5]]
	var near_crow: Dictionary = {"id": 900001, "sp": "crow", "pos": Vector3(300.0, 8.0, 0.0), "perched": true, "timer": 60.0, "state": 0, "heading": 0.0}
	var far_crow: Dictionary = {"id": 900002, "sp": "crow", "pos": Vector3(1500.0, 8.0, 0.0), "perched": true, "timer": 60.0, "state": 0, "heading": 0.0}
	a.animals[900001] = near_crow
	a.animals[900002] = far_crow

	a._thunder_tick([Vector3.ZERO])
	game_s[0] += 60.0
	a._thunder_tick([Vector3.ZERO])
	check(a._claps.is_empty() and not near_crow.has("fly"), "flag off: no thunder")
	a._thunder_cfg()["on"] = true
	a._thunder_tick([Vector3.ZERO])   # the first tick with thunder on only starts its clock (no backlog of strikes from while it was off)
	game_s[0] += 60.0
	a._thunder_tick([Vector3.ZERO])
	check(a._claps.size() == 1 and not near_crow.has("fly"), "the flash: the sound has not reached the crow yet")

	if a._claps.is_empty():
		print("birds and thunder: no clap queued, stopping (%d failures)" % failures)
		quit(1)
		return

	a._claps[0][1] = int(a._claps[0][1]) - 2000   # two real seconds later: the sound is 686 m out
	a._thunder_tick([Vector3.ZERO])
	check(near_crow.has("fly") and int(near_crow["state"]) == 15, "the crow 200 m from the strike flies up (state %d)" % int(near_crow["state"]))
	check(not far_crow.has("fly"), "a crow 1.4 km from the strike stays")

	print("birds and thunder: %d failures" % failures)
	quit(1 if failures > 0 else 0)
