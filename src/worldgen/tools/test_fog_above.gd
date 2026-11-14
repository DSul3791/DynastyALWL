extends SceneTree

# Valley fog (#603) seen from above: the distance haze thins over the layer so a hill standing above it stays sharp (Dino's fog_above
# shot, 8 Nov 2026), while inside the layer and on a day without mist nothing changes. Run: godot --headless --script res://src/worldgen/tools/test_fog_above.gd

const WeatherLook := preload("res://src/client/weather_look.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1

	print("%s %s" % ["ok  " if ok else "FAIL", what])


func _init() -> void:
	_check(is_equal_approx(WeatherLook.above_clear(0.0, 0.0), 1.0), "no mist: the haze as before")
	_check(is_equal_approx(WeatherLook.above_clear(1.0, 0.0), WeatherLook.MIST_ABOVE_CLEAR) and WeatherLook.MIST_ABOVE_CLEAR < 0.5, "above a full layer the haze is thin, so hills above it stay sharp")
	_check(is_equal_approx(WeatherLook.above_clear(1.0, 1.0), 1.0), "inside the layer the distance fog carries the mist as before")
	_check(WeatherLook.above_clear(0.5, 0.0) > WeatherLook.above_clear(1.0, 0.0) and WeatherLook.above_clear(0.5, 0.0) < 1.0, "a thin mist thins it less")
	# The layer's height fog (Dave 14 Nov 2026: foggy under a clear sky): above the top it whitens the low ground; with the eye inside
	# it steps aside whatever the strength, so a thinning morning mist does not whiten everything near.
	_check(is_equal_approx(WeatherLook.layer_height_density(1.0, 0.0), WeatherLook.MIST_HEIGHT_DENSITY), "above a full layer: the low ground fills white")
	_check(is_equal_approx(WeatherLook.layer_height_density(0.5, 0.0), WeatherLook.MIST_HEIGHT_DENSITY * 0.5), "above a thin layer: less white")
	for strength in [1.0, 0.8, 0.5, 0.3, 0.1]:
		_check(is_zero_approx(WeatherLook.layer_height_density(strength, 1.0)), "inside a layer of strength %.1f: no height fog on the ground nearby" % strength)
	_check(WeatherLook.layer_height_density(0.5, 0.5) < WeatherLook.layer_height_density(0.5, 0.0), "at the top's edge: part way")
	print("test_fog_above: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
