extends SceneTree
# Headless check of real thunder (docs/design/thunder_delay_design.md, Jamie #683 never-hear 5): 3 s a km, the shared strikes
# (src/shared/thunder.gd) out to 15 km, far rolls quiet and lost in a wind.

const WeatherSounds := preload("res://src/client/weather_sounds.gd")
const ThunderScript := preload("res://src/shared/thunder.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var sounds = WeatherSounds.new()
	var d1: float = sounds.thunder_delay(1000.0)
	var d5: float = sounds.thunder_delay(5000.0)
	_check(absf(d1 - 2.9) < 0.1, "1 km: heard after 2.9 s (%.2f)" % d1)
	_check(absf(d5 - 14.6) < 0.1, "5 km: heard after 14.6 s, about 3 s a km (%.2f)" % d5)

	# Which strikes play: the shared schedule (src/shared/thunder.gd), all of them within 3 km, a fixed thin share past it.
	_check(WeatherSounds.heard(2999.0, Vector3(1.0, 0.0, 2.0), 10.0), "a shared strike within 3 km is always heard")
	_check(not WeatherSounds.heard(15001.0, Vector3(1.0, 0.0, 2.0), 10.0), "nothing past 15 km is heard")
	var kept: int = 0
	var again: bool = true

	for i in range(4000):
		var point: Vector3 = Vector3(float(i * 37 % 9000), 0.0, float(i * 53 % 7000))
		var keep: bool = WeatherSounds.heard(8000.0, point, float(i) * 7.3)
		kept += 1 if keep else 0
		again = again and keep == WeatherSounds.heard(8000.0, point, float(i) * 7.3)

	_check(again, "a far strike is kept or not the same way every time (every client hears the same ones)")
	_check(kept > 20 and kept < 110, "past 3 km about %.1f%% are kept (%d of 4000)" % [WeatherSounds.THUNDER_FAR_KEEP * 100.0, kept])

	# The rate the schedule gives at the full storm, read the way the client reads it: about one strike in 25 real s within 3 km,
	# and far rolls about one a minute (4 game hours, 600 real s, around a spot).
	var storm: Dictionary = {"storm": 1.0, "rain": 1.0}
	var near_n: int = 0
	var far_n: int = 0

	for found in ThunderScript.strikes(12345, 0.0, 14400.0, storm, Vector3(50000.0, 0.0, 70000.0), WeatherSounds.THUNDER_REAL_MAX_M):
		var p: Vector3 = found[0]
		var d: float = Vector2(p.x - 50000.0, p.z - 70000.0).length()

		if d <= WeatherSounds.THUNDER_HEARD_ALL_M:
			near_n += 1
		elif WeatherSounds.heard(d, p, float(found[1])):
			far_n += 1

	_check(near_n >= 8 and near_n <= 50, "600 real s of a full storm: %d strikes within 3 km (about 24)" % near_n)
	_check(far_n >= 3 and far_n <= 25, "and %d far rolls (about 10)" % far_n)
	_check(ThunderScript.strikes(12345, 0.0, 14400.0, {"storm": 0.0, "rain": 1.0}, Vector3.ZERO, 15000.0).is_empty(), "no storm: no strikes")

	# The weather the schedule is read with: the world's, unless the sounds are forced.
	var world_state: Dictionary = {"storm": 0.0, "rain": 0.2}
	_check(sounds.thunder_state(world_state, false) == world_state, "not forced: the world's weather")
	sounds.kind = "storm"
	sounds.intensity = 1.0
	_check(float(sounds.thunder_state(world_state, true)["storm"]) > 0.0 and float(sounds.thunder_state(world_state, true)["rain"]) >= 0.5, "a forced storm thunders")

	# The schedule drives the claps: the first read only starts the clock, the next plays what fell between, in their direction.
	var clock: Array = [1000.0]
	var asked: Array = []
	sounds.game_seconds = func() -> float: return clock[0]
	sounds.thunder_between = func(t0: float, t1: float, centre: Vector3, reach: float) -> Array:
		asked.append([t0, t1, reach])
		return [[centre + Vector3(0.0, 0.0, 800.0), t1], [centre + Vector3(9000.0, 0.0, 0.0), t1]]
	var at: Vector3 = Vector3(10.0, 0.0, 20.0)
	var due: Array = sounds.due_strikes(at)
	_check(asked.is_empty() and due.is_empty(), "the first read starts the schedule, nothing played")
	clock[0] = 1060.0
	due = sounds.due_strikes(at)
	_check(asked.size() == 1 and is_equal_approx(float(asked[0][0]), 1000.0) and is_equal_approx(float(asked[0][1]), 1060.0), "the next read asks for the game seconds between")
	var far_heard: bool = WeatherSounds.heard(9000.0, at + Vector3(9000.0, 0.0, 0.0), 1060.0)
	_check(due.size() == (2 if far_heard else 1), "the near strike claps (%d due)" % due.size())
	_check(not due.is_empty() and absf(float(due[0][0]) - 800.0) < 0.01 and absf(float(due[0][1]) - PI / 2.0) < 0.001, "800 m off along +z: heard 800 m away, from +z (%s)" % str(due[0] if not due.is_empty() else []))
	clock[0] = 1055.0
	due = sounds.due_strikes(at)
	clock[0] = 1058.0
	due.append_array(sounds.due_strikes(at))
	_check(asked.size() == 1 and due.is_empty(), "a resync a few seconds back plays nothing twice: it waits for the clock to pass the last read")
	clock[0] = 1070.0
	due = sounds.due_strikes(at)
	_check(asked.size() == 2 and is_equal_approx(float(asked[1][0]), 1060.0), "then reads on from where it was (%s)" % str(asked[1] if asked.size() > 1 else []))
	clock[0] = 9000.0
	due = sounds.due_strikes(at)
	_check(asked.size() == 2 and due.is_empty(), "a long gap (a clock jump) starts fresh, no backlog of claps")

	# Level: falls with distance, near crack as today, a far roll quieter in wind.
	var today_near: float = WeatherSounds.THUNDER_DB - 300.0 / 400.0 + 3.0
	_check(is_equal_approx(WeatherSounds.thunder_real_db(300.0, 0.0), today_near), "a 300 m crack is as loud as today")
	_check(WeatherSounds.thunder_real_db(1000.0, 0.0) > WeatherSounds.thunder_real_db(5000.0, 0.0) and WeatherSounds.thunder_real_db(5000.0, 0.0) > WeatherSounds.thunder_real_db(15000.0, 0.0), "quieter with distance")
	var still: float = WeatherSounds.thunder_real_db(15000.0, 0.0)
	_check(still < -28.0 and still > -40.0, "15 km on a still evening: a faint grumble (%.1f dB)" % still)
	_check(WeatherSounds.thunder_real_db(12000.0, 1.0) < WeatherSounds.thunder_real_db(12000.0, 0.0) - 10.0, "12 km in a gale: lost in the wind")
	_check(is_equal_approx(WeatherSounds.thunder_real_db(8000.0, 1.0), WeatherSounds.thunder_real_db(8000.0, 0.0)), "under 10 km the wind takes nothing")
	sounds.free()

	print("thunder real: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
