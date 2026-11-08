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
	print("test_fog_above: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
