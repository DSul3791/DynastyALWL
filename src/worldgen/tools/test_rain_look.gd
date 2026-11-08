extends SceneTree

# The rain streaks with --rain-look (docs/design/rain_look_design.md 3.1): drops fall at real speeds (drizzle 2.5 m/s, a downpour 9 m/s, never
# faster), drift with the wind along its own heading (Jamie #637: m/s = 20 x wind^1.3, gusts up to 1.5 x), the slant held under 65 degrees,
# and the lit shader is the one built when the switch is on.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_rain_look.gd
const WeatherLook := preload("res://src/client/weather_look.gd")

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
	_check(WeatherLook.RAIN_SHADER_LIT.contains("void light()") and not WeatherLook.RAIN_SHADER_LIT.contains("unshaded"), "the switched-on streaks are lit by the scene, not self-lit")
	_check(WeatherLook.RAIN_SHADER.contains("unshaded"), "without the switch the streaks are as before")

	print("test_rain_look: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
