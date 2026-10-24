extends SceneTree

# Headless check that sun and sky light fade out under rock (weather_look.gd cave_light):
#   godot --headless --path . --script res://tools/check_cave_light.gd
# Fails (exit 1) when open air is not full light, a tunnel is not nearly dark, or the fade is not steady.

const WeatherLook := preload("res://src/client/weather_look.gd")


func _initialize() -> void:
	var failures: Array = []

	if not is_equal_approx(WeatherLook.cave_light(0.0), 1.0):
		failures.append("open air is not full light")

	if not is_equal_approx(WeatherLook.cave_light(0.05), 1.0):
		failures.append("a slight overhang dims the light")

	if WeatherLook.cave_light(1.0) > 0.06:
		failures.append("a tunnel is not dark: %.3f" % WeatherLook.cave_light(1.0))

	var last: float = 2.0

	for k in range(21):
		var light: float = WeatherLook.cave_light(float(k) / 20.0)

		if light > last + 0.0001:
			failures.append("light rises with enclosure at %d" % k)

		last = light

	if failures.is_empty():
		print("Cave light check: 4 pass, 0 fail")
		quit(0)
	else:
		for f in failures:
			printerr("FAIL: ", f)

		print("Cave light check: %d fail" % failures.size())
		quit(1)
