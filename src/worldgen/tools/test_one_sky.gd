extends SceneTree

# --one-sky (docs/design/one_sky_design.md, Sonny's A4 "One sky", Jamie's #706): the starter island's sun and moon at 57 S.
# Run: godot --headless --script res://src/worldgen/tools/test_one_sky.gd

const DayCycle := preload("res://src/client/day_cycle.gd")
const Weather := preload("res://src/shared/weather.gd")

const RISE_DEG := -0.833          # sun centre at rise and set with refraction (the upper limb on the horizon), as in Sonny's table

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1

	print("%s %s" % ["ok  " if ok else "FAIL", what])


func _sun(year_phase: float, hour: float) -> Vector3:
	var phi: float = deg_to_rad(DayCycle.sky_latitude_deg())
	return DayCycle.sky_direction(phi, DayCycle.sun_declination(year_phase), deg_to_rad((hour - 12.0) * 15.0))


func _moon(year_phase: float, hour: float, moon_phase: float) -> Vector3:
	var phi: float = deg_to_rad(DayCycle.sky_latitude_deg())
	return DayCycle.moon_on_ecliptic(phi, year_phase, deg_to_rad((hour - 12.0) * 15.0), moon_phase)


static func _altitude(v: Vector3) -> float:
	return rad_to_deg(asin(clampf(v.y, -1.0, 1.0)))


# Compass bearing in degrees, clockwise from north (-Z).
static func _bearing(v: Vector3) -> float:
	return fposmod(rad_to_deg(atan2(v.x, -v.z)), 360.0)


# The hour the sun crosses RISE_DEG between `from` (below) and `to` (above), or the reverse for a setting sun: by halving.
func _crossing(year_phase: float, from: float, to: float) -> float:
	var rising: bool = _altitude(_sun(year_phase, to)) > _altitude(_sun(year_phase, from))

	for _i in range(50):
		var mid: float = 0.5 * (from + to)
		var above: bool = _altitude(_sun(year_phase, mid)) > RISE_DEG

		if above == rising:
			to = mid
		else:
			from = mid

	return 0.5 * (from + to)


func _near_hour(got: float, want_h: int, want_m: int, minutes: float) -> bool:
	return absf(got - (float(want_h) + float(want_m) / 60.0)) * 60.0 <= minutes


static func _hm(hour: float) -> String:
	var m: int = int(roundf(hour * 60.0))
	return "%02d:%02d" % [floori(m / 60.0), m % 60]


func _init() -> void:
	DayCycle.one_sky_on = true
	_check(is_equal_approx(DayCycle.sky_latitude_deg(), -57.0), "the starter island's sky is at 57 S (%.1f)" % DayCycle.sky_latitude_deg())

	# Noon: 56.4, 33.0 and 9.6 degrees, due north, so shadows point south (+Z).
	for row in [[0.25, 56.4, "midsummer"], [0.0, 33.0, "equinox"], [0.75, 9.6, "midwinter"]]:
		var noon: Vector3 = _sun(row[0], 12.0)
		_check(absf(_altitude(noon) - float(row[1])) <= 0.2 and noon.z < 0.0 and absf(noon.x) < 0.001, "%s noon %.1f degrees due north (want %.1f)" % [row[2], _altitude(noon), row[1]])

	# Rise and set (Sonny's table, local solar time).
	for row in [[0.25, 3, 4, 139.0, 20, 56, 221.0, "midsummer"], [0.0, 5, 54, 90.0, 18, 6, 270.0, "equinox"], [0.75, 8, 39, 45.0, 15, 21, 315.0, "midwinter"]]:
		var rise: float = _crossing(row[0], 0.0, 12.0)
		var set_h: float = _crossing(row[0], 12.0, 24.0)
		var rise_b: float = _bearing(_sun(row[0], rise))
		var set_b: float = _bearing(_sun(row[0], set_h))
		_check(_near_hour(rise, row[1], row[2], 3.0) and absf(rise_b - float(row[3])) <= 1.5, "%s sunrise %s at %.0f degrees (want %02d:%02d at %.0f)" % [row[7], _hm(rise), rise_b, row[1], row[2], row[3]])
		_check(_near_hour(set_h, row[4], row[5], 3.0) and absf(set_b - float(row[6])) <= 1.5, "%s sunset %s at %.0f degrees (want %02d:%02d at %.0f)" % [row[7], _hm(set_h), set_b, row[4], row[5], row[6]])

	var midnight: float = _altitude(_sun(0.25, 0.0))
	_check(absf(midnight + 9.6) <= 0.2, "midsummer midnight: the sun only %.1f degrees down (nautical twilight all night)" % midnight)

	# The moon (Jamie #706): the midsummer full moon low in the north, the midwinter one high.
	var summer_top: float = -90.0
	var summer_top_v: Vector3 = Vector3.ZERO
	var winter_top: float = -90.0

	for step in range(240):
		var hour: float = float(step) * 0.1
		var s: Vector3 = _moon(0.25, hour, 0.5)

		if _altitude(s) > summer_top:
			summer_top = _altitude(s)
			summer_top_v = s

		winter_top = maxf(winter_top, _altitude(_moon(0.75, hour, 0.5)))

	_check(absf(summer_top - 9.6) <= 0.5 and summer_top_v.z < 0.0, "midsummer full moon at most %.1f degrees up, in the north (want about 10)" % summer_top)
	_check(winter_top > 50.0, "midwinter full moon rides high (%.1f degrees)" % winter_top)
	var full: Vector3 = _moon(0.25, 0.0, 0.5)
	var opposite: Vector3 = -_sun(0.25, 0.0)
	_check(full.dot(opposite) > 0.999, "a full moon stands opposite the sun")

	for spring in [0.0, 0.5]:
		var up_at_six: float = _altitude(_moon(spring, 18.0, 0.25))
		var later: float = _altitude(_moon(spring + 9.5 / 24.0 / 365.0, 27.5, 0.25 + 9.5 / 24.0 / 29.53))
		_check(up_at_six > 5.0 and later < 0.0, "first quarter at phase %.1f: up at 18:00 (%.1f), set by 03:30 (%.1f)" % [spring, up_at_six, later])

	# Phase 0.9 (late winter): noon 19.5 degrees, so a 30 degree slope facing south (+Z) gets no direct sun.
	var late: Vector3 = _sun(0.9, 12.0)
	var slope_normal: Vector3 = Vector3(0.0, cos(deg_to_rad(30.0)), sin(deg_to_rad(30.0)))
	_check(absf(_altitude(late) - 19.5) <= 0.5, "phase 0.9 noon %.1f degrees (want 19.5)" % _altitude(late))
	_check(slope_normal.dot(late) <= 0.0, "a 30 degree slope facing south gets no direct sun at noon (%.3f)" % slope_normal.dot(late))

	# The weather's sunrise (sun centre on the horizon, for the fog burn-off) agrees with the day cycle's.
	Weather.one_sky_on = true

	for day in [91.0, 0.0, 274.0]:
		var phase: float = day / 365.0
		var weather_rise: float = Weather.sunrise_hour(day, "temperate")
		var cycle_rise: float = weather_rise
		var lo: float = 0.0
		var hi: float = 12.0

		for _i in range(50):
			var mid: float = 0.5 * (lo + hi)

			if _sun(phase, mid).y > 0.0:
				hi = mid
			else:
				lo = mid

		cycle_rise = 0.5 * (lo + hi)
		_check(absf(weather_rise - cycle_rise) * 60.0 <= 2.0, "day %d: the weather's sunrise %s matches the sky's %s" % [int(day), _hm(weather_rise), _hm(cycle_rise)])

	# The day cycle itself: the light comes from the north at noon and the moonlight from the moon's place.
	DayCycle.moon_phase_on = true
	var cycle = DayCycle.new()
	cycle.update(12.0, 91, 91.0)
	var toward: Vector3 = cycle.light_basis * Vector3(0.0, 0.0, 1.0)      # the light shines along -Z of its basis, so +Z points at the sun
	_check(toward.z < 0.0 and absf(cycle.elevation - sin(deg_to_rad(56.4))) < 0.01, "midsummer noon: the sun light comes from the north (%.2f), shadows fall south" % toward.z)
	cycle.update(0.0, 100, 100.0)
	_check(cycle.moon_elevation > 0.1 and cycle.moon_elevation < 0.25, "day 100 midnight: the full moon low (sin %.2f)" % cycle.moon_elevation)

	# Switch off: today's 52 N sky.
	DayCycle.one_sky_on = false
	Weather.one_sky_on = false
	var old_noon: Vector3 = _sun(0.25, 12.0)
	_check(absf(_altitude(old_noon) - 61.4) <= 0.2 and old_noon.z > 0.0, "switch off: midsummer noon %.1f degrees due south, as before" % _altitude(old_noon))
	DayCycle.moon_phase_on = false

	print("test_one_sky: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)
