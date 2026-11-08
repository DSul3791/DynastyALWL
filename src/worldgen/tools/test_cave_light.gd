extends SceneTree

# --cave-light (docs/design/cave_light_design.md): daylight from the mouth and the bends, the eyes' lift and glare, drips in rows along cracks.
# Run: godot --headless --script res://src/worldgen/tools/test_cave_light.gd

const WeatherLook := preload("res://src/client/weather_look.gd")
const CaveSounds := preload("res://src/client/cave_sounds.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1

	print("%s %s" % ["ok  " if ok else "FAIL", what])


func _init() -> void:
	var deep: float = WeatherLook.CAVE_LIGHT_NORMAL_DEEP
	_check(is_equal_approx(WeatherLook.cave_light_view(0.0, 1.0, 0, 0.0), 1.0), "open air is full light")
	var mouth: float = WeatherLook.cave_light_view(0.7, 0.5, 0, 0.0)
	_check(mouth > 0.2 and mouth < 0.4, "at the mouth, half the view open: shade, colours still read (%.2f)" % mouth)
	var twilight: float = WeatherLook.cave_light_view(1.0, 1.0 / 24.0, 0, 0.0)
	_check(twilight > 0.005 and twilight < 0.03, "deeper with the mouth still in view: dusk (%.3f)" % twilight)
	_check(WeatherLook.cave_light_view(0.6, 0.5, 0, 0.0) > 0.0, "with Dark the mouth's twilight zone is not black")
	var bend: float = WeatherLook.cave_light_view(1.0, 0.0, 1, 0.0)
	_check(bend > 0.0 and bend < 0.001, "one bend: about moonlight (%.4f)" % bend)
	_check(WeatherLook.cave_light_view(1.0, 0.0, 2, 0.0) == 0.0, "two bends with Dark: pitch black")
	_check(is_equal_approx(WeatherLook.cave_light_view(1.0, 0.0, 2, deep), deep) and deep < 0.03, "Normal deep in is a faint dusk, not 12 %")

	_check(WeatherLook.adapted_light(0.0, 1.0) == 0.0, "the eyes never lift black")
	_check(WeatherLook.adapted_light(0.004, 1.0) > 0.015 and WeatherLook.adapted_light(0.004, 1.0) <= WeatherLook.CAVE_ADAPT_CAP, "dark-adapted eyes bring back some shapes, capped")
	_check(is_equal_approx(WeatherLook.adapted_light(0.004, 0.0), 0.004), "and not before they adapt")
	_check(is_equal_approx(WeatherLook.adapted_light(0.5, 1.0), 0.5), "bright light is not lifted")
	_check(WeatherLook.CAVE_COME_OUT_FAST_S <= 0.5 and WeatherLook.CAVE_ADAPT_OUT_S >= 1.0 and WeatherLook.CAVE_ADAPT_OUT_S <= 3.0, "coming out: the light is back at once, a glare of 1 to 3 s")
	_check(WeatherLook.CAVE_GO_DARK_S <= 1.0 and WeatherLook.CAVE_ADAPT_IN_S >= 60.0, "going in: dark within a second, the eyes adapt over minutes")

	# Drips in rows along cracks, from the same spots every visit.
	var here: Vector3 = Vector3(56520.0, 533.0, 72360.0)
	var spots: Array = CaveSounds.crack_spots(here)
	_check(spots.size() >= 4, "drip spots near a player (%d)" % spots.size())
	_check(spots == CaveSounds.crack_spots(here), "the same spots every visit")
	var within: bool = true

	for spot in spots:
		var off: float = Vector2(spot.x - here.x, spot.z - here.z).length()
		within = within and off >= 3.0 and off <= 12.0

	_check(within, "every spot 3 to 12 m off")
	var rows: int = 0

	for a in spots:
		for b in spots:
			var gap: float = Vector2(a.x - b.x, a.z - b.z).length()
			rows += 1 if absf(gap - CaveSounds.CRACK_SPOT_M) < 0.01 else 0

	_check(rows * 2 >= spots.size(), "spots sit in rows, %.1f m apart along a crack" % CaveSounds.CRACK_SPOT_M)

	var look: String = FileAccess.get_file_as_string("res://src/client/weather_look.gd")
	var cave: String = FileAccess.get_file_as_string("res://src/client/cave_sounds.gd")
	_check(look.contains("has(\"--cave-light\")") and cave.contains("has(\"--cave-light\")"), "behind --cave-light")
	print("test_cave_light: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
