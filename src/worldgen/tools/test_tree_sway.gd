extends SceneTree
# Headless check of sway by wind (--tree-wind, docs/design/trees_weather_design.md part A, never-see 1): a calm and a gale
# must not sway the same, and every swaying flora shader takes the same wind so crowns stay on their trunks.

const FloraView := preload("res://src/flora/flora_view.gd")
const WeatherLook := preload("res://src/client/weather_look.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	# The amount: still in a calm, 1 at 12 m/s, a hard swing in a gale, capped.
	_check(FloraView.wind_k(1.0) == 0.0, "k(1 m/s) = 0: still in a calm")
	_check(is_equal_approx(FloraView.wind_k(12.0), 1.0), "k(12 m/s) = 1: today's sway (%.3f)" % FloraView.wind_k(12.0))
	_check(FloraView.wind_k(25.0) > 4.0, "k(25 m/s) > 4: crowns swing hard in a gale (%.2f)" % FloraView.wind_k(25.0))
	_check(FloraView.wind_k(60.0) <= FloraView.WIND_K_MAX, "k is capped at %.0f" % FloraView.WIND_K_MAX)
	_check(FloraView.wind_k(5.0) < FloraView.wind_k(8.0) and FloraView.wind_k(8.0) < FloraView.wind_k(17.0), "k rises with the wind")
	_check(FloraView.wind_flutter(0.0) < 0.15 and is_equal_approx(FloraView.wind_flutter(8.0), 1.0), "flutter near still in a calm, full from 8 m/s")

	# The weather presets (Jamie #637: m/s = 20 x wind^1.3): clear is still, a storm swings.
	var clear_ms: float = WeatherLook.tree_wind_ms(0.1)
	var storm_ms: float = WeatherLook.tree_wind_ms(0.8)
	_check(FloraView.wind_k(clear_ms) == 0.0, "clear (wind 0.1, %.1f m/s): still" % clear_ms)
	_check(FloraView.wind_k(storm_ms) > 1.0, "storm (wind 0.8, %.1f m/s): k %.2f" % [storm_ms, FloraView.wind_k(storm_ms)])

	# Every swaying shader has the wind uniforms, and the old two-sine path is still there for the switch off.
	for shader_name in ["FOLIAGE_SHADER", "BARK_SHADER", "PETAL_SHADER", "FRUIT_SHADER", "GREENS_SHADER", "BERRY_SHADER", "CHROME_SHADER"]:
		var code: String = str(FloraView.get_script_constant_map().get(shader_name, ""))
		_check(code.contains("uniform bool wind_on") and code.contains("wind_k") and code.contains("wind_to"), "%s has the wind uniforms" % shader_name)
		_check(code.contains("sin(TIME * 0.9"), "%s keeps the old sway for the switch off" % shader_name)

	# The setter: with the switch on, every swaying material gets the same numbers.
	var view = FloraView.new()
	view._make_tree_materials()
	FloraView.tree_wind_on = false
	view.set_wind(15.0, 0.0)
	var broad: ShaderMaterial = view._tree_materials["broad"]
	_check(broad.get_shader_parameter("wind_on") != true, "switch off: set_wind leaves the shaders on the old sway")
	FloraView.tree_wind_on = true
	view.set_wind(15.0, PI * 0.5)
	var k: float = FloraView.wind_k(15.0)
	var same: bool = true
	var count: int = 0

	for key in view._tree_materials:
		var material: ShaderMaterial = view._tree_materials[key] as ShaderMaterial

		if material == null or not material.shader.code.contains("uniform bool wind_on"):
			continue

		count += 1
		same = same and material.get_shader_parameter("wind_on") == true and is_equal_approx(float(material.get_shader_parameter("wind_k")), k)
		var to: Vector2 = material.get_shader_parameter("wind_to")
		same = same and to.distance_to(Vector2(0.0, 1.0)) < 0.001

	_check(count >= 10 and same, "switch on: all %d swaying materials get k %.2f and the heading (0, 1)" % [count, k])
	FloraView.tree_wind_on = false
	view.free()

	print("tree sway: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
