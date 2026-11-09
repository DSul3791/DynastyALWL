extends SceneTree

# The rain streaks (docs/design/rain_look_design.md 3.1): drops fall at real speeds (drizzle 2.5 m/s, a downpour 9 m/s, never
# faster), drift with the wind along its own heading (Jamie #637: m/s = 20 x wind^1.3, gusts up to 1.5 x), the slant held under 65 degrees,
# and the streaks are lit by the scene.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_rain_look.gd
const WeatherLook := preload("res://src/client/weather_look.gd")
const Puddles := preload("res://src/client/puddles.gd")
const GroundMaterial := preload("res://src/client/ground_material.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


func _init() -> void:
	_check(absf(WeatherLook.wind_ms(0.3) - 4.18) < 0.05 and absf(WeatherLook.wind_ms(1.0) - 20.0) < 0.01 and WeatherLook.wind_ms(0.0) == 0.0, "wind 0.3 is about 4.2 m/s, 1.0 is 20 m/s, calm is 0")
	_check(is_equal_approx(WeatherLook.rain_fall(0.0), 2.5) and is_equal_approx(WeatherLook.rain_fall(1.0), 9.0), "drizzle falls at 2.5 m/s, a downpour at 9 m/s")
	_check(WeatherLook.rain_fall(0.65) > WeatherLook.rain_fall(0.3) and WeatherLook.rain_fall(2.0) <= 9.0, "harder rain falls faster, and never past 9 m/s")

	# Drift along the heading the wind blows toward: (cos, sin) on (x, z).
	var east: Vector2 = WeatherLook.rain_drift(6.5, 0.3, 0.0, 0.0)
	_check(east.x > 4.0 and absf(east.y) < 0.001, "a wind blowing toward +x drifts the rain toward +x (%.2f, %.2f)" % [east.x, east.y])
	var south: Vector2 = WeatherLook.rain_drift(6.5, 0.3, PI * 0.5, 0.0)
	_check(south.y > 4.0 and absf(south.x) < 0.001, "and toward +z for a heading of 90 degrees")
	_check(WeatherLook.rain_drift(6.5, 0.3, 0.0, 1.0).x > east.x * 1.45, "a full gust drifts it 1.5 times as far")
	var gale: Vector2 = WeatherLook.rain_drift(2.5, 1.0, 0.0, 1.0)
	_check(rad_to_deg(atan2(gale.length(), 2.5)) <= WeatherLook.RAIN_LOOK_MAX_SLANT_DEG + 0.01, "drizzle in a gale slants at most 65 degrees")
	_check(rad_to_deg(atan2(WeatherLook.rain_drift(2.5, 0.3, 0.0, 0.0).length(), 2.5)) > rad_to_deg(atan2(WeatherLook.rain_drift(9.0, 0.3, 0.0, 0.0).length(), 9.0)), "light rain slants more than a downpour in the same wind")
	_check(WeatherLook.rain_drift(6.5, 0.0, 1.0, 1.0).length() < 0.001, "no wind, no slant")

	var lo: float = 1.0
	var hi: float = 0.0

	for i in range(400):
		var g: float = WeatherLook.gust_at(float(i) * 0.1)
		lo = minf(lo, g)
		hi = maxf(hi, g)

	_check(lo >= 0.0 and hi <= 1.0 and hi - lo > 0.6, "gusts swing within 0..1 (%.2f to %.2f over 40 s)" % [lo, hi])
	_check(WeatherLook.RAIN_SHADER_LIT.contains("void light()") and not WeatherLook.RAIN_SHADER_LIT.contains("unshaded"), "the streaks are lit by the scene, not self-lit")

	_check_wet()
	# Splashes (3.2): flecks in the ground shader by material, the sheet only from High quality and only in a downpour.
	_check(GroundMaterial.SHADER.contains("float rain_crowns(") and GroundMaterial.SHADER.contains("uniform float splash_rain"), "the ground shader draws splash crowns from splash_rain")
	_check(WeatherLook.SPLASH_FROM_QUALITY == 2 and WeatherLook.SPLASH_FROM >= 0.5 and WeatherLook.SPLASH_PER_HIT <= 5, "the splash sheet: High and Ultra only, a downpour only, a few droplets a hit")
	_check(preload("res://src/flora/flora_view.gd").BARK_SHADER.contains("uniform float wet") and preload("res://src/flora/flora_view.gd").BARK_SHADER.contains("wind_face"), "the bark darkens in the rain, more on the windward side")
	_check_puddle_drying()
	print("test_rain_look: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)


# Wet surfaces (rain_look_design.md 3.4): soaked in 3 game minutes of rain, held in light rain, rock dry first and litter last, mud keeping
# half for hours, faster in sun and wind; the run-off streaks outlast the rock face.
func _wet_after(hours: float, rain: float, wind: float, sun: float, start: float) -> Array:
	var w: Array = [start, start, start, start, start, start, start]
	var steps: int = maxi(int(hours / 0.01), 1)

	for i in range(steps):
		w = Puddles.wet_step(w.slice(0, 6), float(w[6]), hours / float(steps), rain, wind, sun)

	return w


func _check_wet() -> void:
	var soaked: Array = _wet_after(0.05, 0.6, 0.0, 0.0, 0.0)
	_check(float(soaked.min()) > 0.99, "3 game minutes of rain soak every layer")
	_check(float(_wet_after(0.025, 0.6, 0.0, 0.0, 0.0)[0]) < 0.6, "and the first minute and a half only part soaks them")
	var held: Array = _wet_after(2.0, 0.1, 0.0, 0.0, 1.0)
	_check(float(held[5]) > 0.99 and float(held[0]) > 0.99, "light rain holds the wetness")
	var hour: Array = _wet_after(1.0, 0.0, 0.0, 0.0, 1.0)
	_check(float(hour[5]) < 0.01 and float(hour[0]) > 0.5 and float(hour[1]) > float(hour[0]), "after an hour on a grey still day rock is dry, turf still wet, litter wetter")
	_check(float(hour[6]) > 0.3, "the run-off streaks on steep rock outlast the face (%.2f)" % float(hour[6]))
	_check(absf(float(_wet_after(3.0, 0.0, 0.0, 0.0, 1.0)[3]) - Puddles.WET_MUD_FLOOR) < 0.06, "mud keeps about half its wetness for hours")
	var sunny: Array = _wet_after(0.5, 0.0, 1.0, 1.0, 1.0)
	_check(float(sunny[2]) < 0.01 and float(_wet_after(0.5, 0.0, 0.0, 0.0, 1.0)[2]) > 0.6, "sun and wind dry gravel in half an hour that a grey still day leaves wet")
	_check(Puddles.WET_DRY_H[5] < Puddles.WET_DRY_H[2] and Puddles.WET_DRY_H[2] < Puddles.WET_DRY_H[0] and Puddles.WET_DRY_H[0] < Puddles.WET_DRY_H[1], "drying order: rock, gravel, turf, litter")


# Puddle drain times (Jamie's judged numbers, coordinator 8 Nov 2026): by kind of ground and season.
func _check_puddle_drying() -> void:
	var summer: float = Puddles.winter_share(137.0 * 86400.0)
	var winter: float = Puddles.winter_share(319.0 * 86400.0)
	_check(summer < 0.01 and winter > 0.99 and absf(Puddles.winter_share(46.0 * 86400.0) - 0.5) < 0.05, "the season: high summer about day 137, deep winter about day 319 (%.2f, %.2f)" % [summer, winter])
	_check(is_equal_approx(Puddles.drain_hours(0, 0.0), 3.0) and is_equal_approx(Puddles.drain_hours(1, 1.0), 2.0) and is_equal_approx(Puddles.drain_hours(2, 0.5), 1.0), "turf dries in about 3 h, litter 2 h, gravel 1 h, in any season")
	_check(is_equal_approx(Puddles.drain_hours(3, summer), 72.0) and absf(Puddles.drain_hours(3, winter) - 240.0) < 0.5, "clay holds its puddles 3 game days in summer, 10 in winter")
	_check(is_equal_approx(Puddles.drain_hours(Puddles.TRACK, 0.0), 72.0) and is_equal_approx(Puddles.drain_hours(Puddles.TRACK, 1.0), 240.0), "and so do worn tracks")
	_check(is_equal_approx(Puddles.drain_hours(5, 0.0), 48.0) and is_equal_approx(Puddles.drain_hours(5, 1.0), 144.0), "dips in rock hold 2 days in summer, 6 in winter")
	_check(is_inf(Puddles.drain_hours(Puddles.PEAT, 0.0)) and is_inf(Puddles.drain_hours(Puddles.PEAT, 1.0)), "shallow pools on peat never dry")
	_check(Puddles.SOAK_MM_H.size() == 8 and is_equal_approx(Puddles.SOAK_MM_H[2], 40.0) and is_equal_approx(Puddles.SOAK_MM_H[4], 20.0) and is_equal_approx(Puddles.SOAK_MM_H[0], 7.6) and is_equal_approx(Puddles.SOAK_MM_H[3], 1.5), "soak-in rates: gravel 40, sand 20, loam 7.6, clay 1.5 mm/h")
	_check(Puddles.fill_per_h(3, 0.3) > 0.0 and Puddles.fill_per_h(0, 0.3) == 0.0 and Puddles.fill_per_h(5, 0.15) > 0.0, "light rain fills clay and dips in rock, not turf")
	_check(Puddles.fill_per_h(0, 0.65) > 0.5 and Puddles.fill_per_h(2, 0.65) == 0.0 and Puddles.fill_per_h(2, 1.0) > 0.0, "steady rain fills turf within two hours; loose gravel only in a downpour")
	_check(Puddles.fill_per_h(3, 0.65) > Puddles.fill_per_h(0, 0.65), "clay fills faster than turf")
	_check(Puddles.PRONE.size() == 8 and float(Puddles.PRONE[4]) == 0.0, "sand never holds water")
	_check(GroundMaterial.SHADER.contains("uniform float puddle_level[8]") and GroundMaterial.SHADER.contains("peat_w"), "the ground shader reads the track and peat levels")
