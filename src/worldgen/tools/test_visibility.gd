extends SceneTree

# One visibility number (weather_look.gd visibility_m, MikeW 8 Nov 2026): V = 3 / fog density, capped at 50 km.
#   godot --headless --path . --script res://src/worldgen/tools/test_visibility.gd

const WeatherLook := preload("res://src/client/weather_look.gd")
const LookSettings := preload("res://src/client/look_settings.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var clear: float = WeatherLook.visibility_of_density(LookSettings.FOG_DENSITY)
	var thick: float = WeatherLook.visibility_of_density(LookSettings.FOG_DENSITY * 20.0)
	var valley: float = WeatherLook.visibility_of_density(LookSettings.FOG_DENSITY * (1.0 + WeatherLook.MIST_INSIDE_THICK))
	print("visibility: clear air %.0f m, inside full valley fog %.0f m, the thickest weather fog %.0f m, under water %.0f m" % [clear, valley, thick, WeatherLook.visibility_of_density(WeatherLook.UNDER_FOG_DENSITY)])
	check(absf(clear - 3.0 / LookSettings.FOG_DENSITY) < 0.01, "clear air: 3 / density")
	check(valley > 180.0 and valley < 1000.0, "inside a full valley fog: fog by Jamie's #716 bands (180 to 1000 m), %.0f m" % valley)
	check(thick < clear and thick > 50.0, "the thickest weather fog is thinner than clear air and not dense fog")
	check(WeatherLook.visibility_of_density(0.0) == WeatherLook.VISIBILITY_MAX_M, "no fog drawn: the 50 km cap")
	check(WeatherLook.visibility_of_density(1e-9) == WeatherLook.VISIBILITY_MAX_M, "a trace of fog: still the cap, no huge number")
	var previous: float = INF
	var falls: bool = true

	for k in range(1, 200):
		var v: float = WeatherLook.visibility_of_density(0.0001 * float(k))
		falls = falls and v <= previous
		previous = v

	check(falls, "thicker fog never sees further")
	print("test_visibility: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
