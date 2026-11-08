extends SceneTree
# Headless check of real thunder (--thunder-real, docs/design/thunder_delay_design.md, Jamie #683 never-hear 5): 3 s a km, strikes
# out to 15 km, far rolls quiet and lost in a wind.

const WeatherSounds := preload("res://src/client/weather_sounds.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var sounds = WeatherSounds.new()
	WeatherSounds.thunder_real_on = false
	_check(sounds.thunder_delay(5000.0) <= 4.0, "switch off: today's shortened delay (%.1f s at 5 km)" % sounds.thunder_delay(5000.0))
	WeatherSounds.thunder_real_on = true
	var d1: float = sounds.thunder_delay(1000.0)
	var d5: float = sounds.thunder_delay(5000.0)
	_check(absf(d1 - 2.9) < 0.1, "1 km: heard after 2.9 s (%.2f)" % d1)
	_check(absf(d5 - 14.6) < 0.1, "5 km: heard after 14.6 s, about 3 s a km (%.2f)" % d5)

	# Where strikes land: near ones in the cell, far ones out to 15 km, never beyond.
	var far: int = 0
	var near: int = 0
	var most: float = 0.0
	var least: float = 1.0e9

	for i in range(400):
		var pick: float = float(i % 20) / 20.0 + 0.025
		var spread: float = floorf(float(i) / 20.0) / 20.0 + 0.025
		var d: float = WeatherSounds.real_strike_distance(pick, spread, 1.0)
		most = maxf(most, d)
		least = minf(least, d)
		far += 1 if d > 10000.0 else 0
		near += 1 if d < 3000.0 else 0

	_check(most <= WeatherSounds.THUNDER_REAL_MAX_M and least >= 250.0, "strikes from 250 m to 15 km (%.0f to %.0f m)" % [least, most])
	_check(far > 0 and near > 200, "a full storm: most strikes in the cell, some past 10 km (%d near, %d far of 400)" % [near, far])
	_check(WeatherSounds.real_strike_distance(0.5, 0.5, 0.2) > 3000.0, "a weak storm: the same pick lands farther off")

	# Level: falls with distance, near crack as today, a far roll quieter in wind.
	var today_near: float = WeatherSounds.THUNDER_DB - 300.0 / 400.0 + 3.0
	_check(is_equal_approx(WeatherSounds.thunder_real_db(300.0, 0.0), today_near), "a 300 m crack is as loud as today")
	_check(WeatherSounds.thunder_real_db(1000.0, 0.0) > WeatherSounds.thunder_real_db(5000.0, 0.0) and WeatherSounds.thunder_real_db(5000.0, 0.0) > WeatherSounds.thunder_real_db(15000.0, 0.0), "quieter with distance")
	var still: float = WeatherSounds.thunder_real_db(15000.0, 0.0)
	_check(still < -28.0 and still > -40.0, "15 km on a still evening: a faint grumble (%.1f dB)" % still)
	_check(WeatherSounds.thunder_real_db(12000.0, 1.0) < WeatherSounds.thunder_real_db(12000.0, 0.0) - 10.0, "12 km in a gale: lost in the wind")
	_check(is_equal_approx(WeatherSounds.thunder_real_db(8000.0, 1.0), WeatherSounds.thunder_real_db(8000.0, 0.0)), "under 10 km the wind takes nothing")
	WeatherSounds.thunder_real_on = false
	sounds.free()

	print("thunder real: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
