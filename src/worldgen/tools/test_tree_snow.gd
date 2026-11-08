extends SceneTree
# Headless check of snow that holds and sheds on the trees (--tree-snow, docs/design/trees_weather_design.md part C, never-see 3):
# conifers hold snow in frost and shed it in a thaw or a strong wind; bare twigs hold only a thin line.

const WeatherLook := preload("res://src/client/weather_look.gd")
const FloraView := preload("res://src/flora/flora_view.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


# Steps one crown kind hour by hour.
func _run(value: float, cap: float, ground: float, falling: float, temp_c: float, wind_ms: float, hours: int) -> float:
	for h in range(hours):
		value = WeatherLook.crown_snow_step(value, cap, ground, falling, temp_c, wind_ms, 1.0)

	return value


func _init() -> void:
	var conifer_cap: float = WeatherLook.CROWN_CONIFER_CAP
	var bare_cap: float = WeatherLook.CROWN_BARE_CAP

	# Loading: falling snow brings the crowns up to their share of the ground's cover.
	var loaded: float = _run(0.0, conifer_cap, 1.0, 0.6, -4.0, 1.0, 2)
	_check(is_equal_approx(loaded, 0.5), "a snowfall loads a conifer to half the ground's cover (%.2f)" % loaded)
	_check(is_equal_approx(_run(0.0, bare_cap, 1.0, 0.6, -4.0, 1.0, 2), 0.35), "bare twigs hold only a thin line (cap 0.35)")
	_check(_run(0.0, conifer_cap, 0.4, 0.6, -4.0, 1.0, 2) <= 0.2 + 0.001, "never more than its share of the ground's snow")

	# Frost: holds for days.
	var frost_day: float = _run(0.5, conifer_cap, 1.0, 0.0, -6.0, 3.0, 24)
	_check(frost_day > 0.35, "a day of still frost keeps most of it (%.2f)" % frost_day)

	# Thaw and wind: gone within about 3 game hours.
	var thaw: float = _run(0.5, conifer_cap, 1.0, 0.0, 5.0, 3.0, 3)
	_check(thaw < 0.1, "3 thaw hours at 5 °C: crown snow under 0.1 (%.3f) while the ground is still white" % thaw)
	var gale: float = _run(0.5, conifer_cap, 1.0, 0.0, -6.0, 12.0, 3)
	_check(gale < 0.1, "3 hours of a 12 m/s wind in frost: shed (%.3f)" % gale)
	_check(_run(0.0, conifer_cap, 1.0, 1.0, -6.0, 20.0, 2) == 0.0, "a blizzard wind over 8 m/s does not let the crowns load")
	_check(_run(0.5, conifer_cap, 0.0, 0.0, -6.0, 1.0, 1) == 0.0, "bare ground: bare crowns")

	# The view: conifer crowns take one value, broadleaf crowns and bark the other.
	var view = FloraView.new()
	view._make_tree_materials()
	view.set_snow_kinds(0.5, 0.2)
	var conifer: ShaderMaterial = view._tree_materials["conifer"]
	var oak: ShaderMaterial = view._tree_materials["oak"]
	var bark: ShaderMaterial = view._tree_materials["bark"]
	_check(is_equal_approx(float(conifer.get_shader_parameter("snow")), 0.5), "set_snow_kinds: conifer crowns 0.5")
	_check(is_equal_approx(float(oak.get_shader_parameter("snow")), 0.2) and is_equal_approx(float(bark.get_shader_parameter("snow")), 0.2), "set_snow_kinds: broadleaf crowns and bark 0.2")
	view.set_snow(0.7)
	_check(is_equal_approx(float(conifer.get_shader_parameter("snow")), 0.7) and is_equal_approx(float(oak.get_shader_parameter("snow")), 0.7), "switch off path: set_snow(ground) whitens every tree alike, as before")
	view.free()

	print("tree snow: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
