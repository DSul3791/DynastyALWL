extends SceneTree

# Cave darkness by day (Dave 4 Nov 2026: "its day time and its light in the tunnels even at the very back. it should be dark"). The engine scales only the ambient
# colour by ambient_light_energy: the sky's share of the ambient and the sky reflections keep the full sky. weather_look.gd dimmed the energy under rock, so by
# day (sky share 0.75) three quarters of the open-air ambient still reached the back of a tunnel. Checks, with the game's own numbers: in the open the sky share
# and reflections are as before; deep in a tunnel the light left (colour part plus sky part) is within 10% of the cave setting, by day and by night; the
# reflections are off in a tunnel and back on outside; part way in the sky share fades with the light.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_cave_dark_day.gd
const WeatherLook := preload("res://src/client/weather_look.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


# The share of the open-air ambient that is left: the colour part (scaled by the energy, as under_rock scales it) mixed with the sky part (not scaled by it).
func _left(env: Environment, under_rock: float) -> float:
	var sky: float = env.ambient_light_sky_contribution
	return (1.0 - sky) * under_rock + sky * 1.0


func _init() -> void:
	var env: Environment = Environment.new()
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

	WeatherLook.sky_under_rock(env, WeatherLook.DAY_SKY_SHARE, 1.0)
	_check(is_equal_approx(env.ambient_light_sky_contribution, WeatherLook.DAY_SKY_SHARE), "in the open the sky share is the day's (%.2f)" % env.ambient_light_sky_contribution)
	_check(env.reflected_light_source == Environment.REFLECTION_SOURCE_SKY, "in the open the sky is reflected")

	for setting in [WeatherLook.CAVE_LIGHT_DARK, WeatherLook.CAVE_LIGHT_NORMAL]:
		var deep: float = WeatherLook.cave_light(1.0, setting)

		for share in [WeatherLook.DAY_SKY_SHARE, 0.3]:
			WeatherLook.sky_under_rock(env, share, deep)
			var left: float = _left(env, deep)
			_check(left <= setting * 1.1, "deep in a tunnel (setting %.2f, sky share %.2f) %.3f of the light is left" % [setting, share, left])

		_check(env.reflected_light_source == Environment.REFLECTION_SOURCE_DISABLED, "no sky reflections deep in a tunnel (setting %.2f)" % setting)

	var half: float = WeatherLook.cave_light(0.35)
	WeatherLook.sky_under_rock(env, WeatherLook.DAY_SKY_SHARE, half)
	_check(env.ambient_light_sky_contribution < WeatherLook.DAY_SKY_SHARE and env.ambient_light_sky_contribution > 0.0, "part way in the sky share fades (%.2f at light %.2f)" % [env.ambient_light_sky_contribution, half])

	WeatherLook.sky_under_rock(env, WeatherLook.DAY_SKY_SHARE, 1.0)
	_check(env.reflected_light_source == Environment.REFLECTION_SOURCE_SKY, "the sky reflections come back outside")
	print("cave dark day: %d failures" % _fails)
	quit(1 if _fails > 0 else 0)
