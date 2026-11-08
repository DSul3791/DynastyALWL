extends SceneTree

# Moon phases (Jamie's moonlight page #679): moonlight by the standard phase formula, and the moon placed by its phase on the ecliptic,
# at the starter island's latitude (34.3 S) on the calendar's spring equinox.
# Run: godot --headless --script res://src/worldgen/tools/test_moon_phase.gd

const DayCycle := preload("res://src/client/day_cycle.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1

	print("%s %s" % ["ok  " if ok else "FAIL", what])


func _moon_up_at(phase: float, hour: float) -> float:
	var phi: float = deg_to_rad(DayCycle.sky_latitude_deg())
	var h: float = deg_to_rad((hour - 12.0) * 15.0)
	return DayCycle.moon_on_ecliptic(phi, 0.0, h, phase).y          # an equinox day


func _init() -> void:
	_check(is_equal_approx(DayCycle.moon_light_phase(0.5), 1.0), "full moon: full light")
	var quarter: float = DayCycle.moon_light_phase(0.25)
	_check(quarter > 0.06 and quarter < 0.11, "a quarter moon gives about 8 to 9 %% of full, not 35 %% (%.3f)" % quarter)
	_check(DayCycle.moon_light_phase(0.0) < 0.001 and DayCycle.moon_light_phase(1.0) < 0.001, "new moon: none")
	var near: float = DayCycle.moon_light_phase(0.5 + 4.0 / 29.53)
	_check(near > 0.25 and near < 0.6, "4 days from full still about a third or more (%.2f)" % near)
	_check(DayCycle.moon_light_phase(0.4) > DayCycle.moon_light_phase(0.3), "it brightens toward full")

	_check(_moon_up_at(0.5, 0.0) > 0.5 and _moon_up_at(0.5, 21.0) > 0.0 and _moon_up_at(0.5, 3.0) > 0.0, "full moon: up all night, high at midnight")
	_check(_moon_up_at(0.25, 19.0) > 0.3 and _moon_up_at(0.25, 2.0) < 0.0, "first quarter: up in the evening, set by 2 in the morning")
	_check(_moon_up_at(0.75, 22.0) < 0.0 and _moon_up_at(0.75, 4.0) > 0.3, "last quarter: not up in the evening, up before dawn")
	_check(_moon_up_at(0.0, 0.0) < -0.5, "new moon: down at midnight, with the sun")

	var cycle = DayCycle.new()
	cycle.update(2.0, 0, 100.0 - 0.25 * 29.53)    # a first quarter, 2 in the morning on an equinox
	_check(cycle.moon_elevation < 0.0 and cycle.moon_light == 0.0 and cycle.light_factor == 0.0, "after a first quarter sets, no moonlight")
	cycle.update(0.0, 0, 100.0)                   # full moon, midnight
	_check(cycle.moon_light > 0.9 and cycle.light_factor > 0.15, "full moon at midnight lights the ground")
	print("test_moon_phase: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
