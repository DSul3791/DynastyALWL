extends SceneTree
# Headless check of firelight in fog, rain and snow (--firelight-weather, docs/design/firelight_weather_design.md, Jamie #645 never-see checks).

const FireWeather := preload("res://src/client/fire_weather.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	_check(is_equal_approx(FireWeather.reach(0.0, 0.0, 0.0), 1.0), "clear air, or rain: the reach is unchanged")
	_check(is_equal_approx(FireWeather.reach(1.0, 0.0, 0.0), 0.5), "dense fog halves the reach (never-see 1)")
	_check(absf(FireWeather.reach(0.6, 0.0, 0.0) - 0.7) < 0.001 and absf(FireWeather.reach(0.3, 0.0, 0.0) - 0.85) < 0.001, "thick fog -30 %, fog -15 %")
	_check(absf(FireWeather.reach(0.0, 1.0, 0.0) - 0.8) < 0.001, "heavy falling snow -20 %")
	_check(absf(FireWeather.reach(0.0, 0.0, 1.0) - 1.6) < 0.001, "fresh lying snow: 1.6 times the reach (never-see 4)")
	_check(FireWeather.reach(0.0, 0.0, 5.0) <= FireWeather.REACH_MAX and FireWeather.reach(5.0, 5.0, 0.0) >= FireWeather.REACH_MIN, "the reach stays within 0.4 to 1.8 (never-see 5)")
	_check(FireWeather.heavy_snow(0.3) == 0.0 and is_equal_approx(FireWeather.heavy_snow(1.0), 1.0), "light snow is not heavy")

	var thick: float = FireWeather.halo_strength(0.6, 0.0)
	_check(FireWeather.halo_alpha(thick, 0.0) > 0.3, "a halo through thick fog at night (never-see 2): alpha %.2f" % FireWeather.halo_alpha(thick, 0.0))
	_check(FireWeather.halo_alpha(FireWeather.halo_strength(0.0, 0.0), 0.0) == 0.0, "no halo in clear air")
	_check(FireWeather.halo_alpha(thick, 1.0) < 0.1, "faint by day")
	_check(absf(FireWeather.halo_diameter(0.2) - 1.5) < 0.001 and absf(FireWeather.halo_diameter(1.0) - 5.0) < 0.001, "the halo is 1.5 m in a light fog, 5 m in a dense one")
	_check(FireWeather.halo_strength(0.0, 1.0) > 0.5, "heavy snow lights a glowing sphere too")

	# Register and update: the base range is kept and scaled; switch off touches nothing.
	FireWeather.on = false
	var plain: OmniLight3D = OmniLight3D.new()
	plain.omni_range = 9.0
	FireWeather.register(plain)
	_check(not plain.has_meta("base_range") and plain.get_child_count() == 0, "switch off: nothing registered, no halo")
	plain.free()
	FireWeather.on = true
	var torch: OmniLight3D = OmniLight3D.new()
	torch.omni_range = 9.0
	root.add_child(torch)
	FireWeather.register(torch)
	_check(torch.has_meta("base_range") and torch.get_node_or_null("Halo") != null, "switch on: the torch keeps its base range and gets a halo")
	FireWeather.update(self, 1.0, 0.0, 0.0, 0.0)
	_check(absf(torch.omni_range - 4.5) < 0.01, "dense fog: a 9 m torch reaches 4.5 m (%.2f)" % torch.omni_range)
	FireWeather.update(self, 0.0, 0.0, 0.0, 0.0)
	_check(absf(torch.omni_range - 9.0) < 0.01, "clear again: back to 9 m, never drifting")
	FireWeather.on = false
	torch.queue_free()

	print("firelight weather: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
