extends SceneTree

# Prevailing wind checks (docs/design/prevailing_wind.md): the switch-off heading is unchanged, the starter island's rose follows
# Jamie's #714, the wind veers ahead of a front and backs after it (57 S), the heading never jumps, and the local wind (coast,
# lee, canopy, slope and sea breezes) does what the design note says.
#   godot --headless --path . --script res://src/worldgen/tools/test_wind_dir.gd

const Weather := preload("res://src/shared/weather.gd")

const WORLD_SEED := 574716103             # worlds/base_world (the pictures' world)

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	_switch_off()
	Weather.wind_dir_on = true
	_bearings()
	_rose(WORLD_SEED)
	_rose(777)
	_smooth()
	_fronts()
	_front_days()
	_local()
	_slope_hours()
	_sea_breeze()
	Weather.wind_dir_on = false
	print("test_wind_dir: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


# Off: wind_dir is exactly the old heading, and local_wind hands the state back untouched.
func _switch_off() -> void:
	Weather.wind_dir_on = false
	var worst: float = 0.0

	for h in range(0, 24 * 30):
		var t: float = float(h) * 3600.0 + 1234.0
		var w: Dictionary = Weather.state(WORLD_SEED, t, "temperate")
		var old: float = TAU * Weather._noise(WORLD_SEED, 4, t / (20.0 * 3600.0)) + 0.8 * float(w["storm"]) * (Weather._noise(WORLD_SEED, 5, t / (2.0 * 3600.0)) - 0.5)
		worst = maxf(worst, absf(float(w["wind_dir"]) - old))

	check(worst < 1e-6, "switch off: wind_dir unchanged (worst %.2e rad)" % worst)
	var w0: Dictionary = Weather.state(WORLD_SEED, 5000.0, "temperate")
	check(Weather.local_wind(w0, {"grade": 0.3, "downhill": Vector2(1, 0), "sea_upwind": 1.0, "lee": 1.0}, 5000.0) == w0, "switch off: local_wind returns the state as it is")


# Bearings: from W the wind blows toward east, +x (heading 0); Jamie's #714 form atan2(cos B, -sin B) agrees for every bearing.
func _bearings() -> void:
	check(absf(angle_difference(Weather.heading_of_bearing(270.0 + 180.0), 0.0)) < 1e-5, "from west: heading 0 (toward +x)")
	check(Vector2.from_angle(Weather.heading_of_bearing(0.0 + 180.0)).distance_to(Vector2(0, 1)) < 1e-5, "from north: toward +z (south)")
	var worst: float = 0.0

	for b in range(0, 360, 5):
		var bearing: float = float(b)
		var jamie: float = atan2(cos(deg_to_rad(bearing)), -sin(deg_to_rad(bearing)))
		worst = maxf(worst, absf(angle_difference(Weather.heading_of_bearing(bearing + 180.0), jamie)))
		worst = maxf(worst, absf(angle_difference(deg_to_rad(Weather.bearing_of_heading(Weather.heading_of_bearing(bearing))), deg_to_rad(bearing))))

	check(worst < 1e-4, "bearing and heading agree with Jamie's form and each other (worst %.2e rad)" % worst)


# The year's rose on the starter island, hourly (Jamie #714: W and NW 52 %, mean 300 to 320, constancy 0.5 to 0.7, 55 to 65 %
# within 45 degrees of WNW). The model gives about 55 %, mean 293, constancy 0.55; the bands leave room either side.
func _rose(seed_value: int) -> void:
	var sectors: Array = [0, 0, 0, 0, 0, 0, 0, 0]
	var sum: Vector2 = Vector2.ZERO
	var near_wnw: int = 0
	var n: int = 365 * 24

	for h in range(n):
		var bearing: float = Weather.prevailing_from_deg(seed_value, float(h) * 3600.0, "temperate")
		sectors[int(fposmod(bearing + 22.5, 360.0) / 45.0) % 8] += 1
		sum += Vector2(sin(deg_to_rad(bearing)), cos(deg_to_rad(bearing)))
		near_wnw += 1 if absf(angle_difference(deg_to_rad(bearing), deg_to_rad(300.0))) <= deg_to_rad(45.0) else 0

	var share: Callable = func(i: int) -> float: return float(sectors[i]) / float(n)
	var mean: float = fposmod(rad_to_deg(atan2(sum.x, sum.y)), 360.0)
	var steady: float = sum.length() / float(n)
	var within: float = float(near_wnw) / float(n)
	print("rose seed %d: N %.0f NE %.0f E %.0f SE %.0f S %.0f SW %.0f W %.0f NW %.0f %%, mean from %.0f, constancy %.2f, %.0f %% within 45 of WNW" % [seed_value, 100.0 * share.call(0), 100.0 * share.call(1), 100.0 * share.call(2), 100.0 * share.call(3), 100.0 * share.call(4), 100.0 * share.call(5), 100.0 * share.call(6), 100.0 * share.call(7), mean, steady, 100.0 * within])
	check(share.call(6) + share.call(7) > 0.45, "seed %d: W and NW over 45 %% of the year" % seed_value)
	check(share.call(1) + share.call(2) + share.call(3) < 0.15, "seed %d: the east side (NE, E, SE) under 15 %%" % seed_value)
	check(share.call(2) + share.call(3) > 0.02, "seed %d: some easterly or south-easterly spells (blocked)" % seed_value)
	check(mean > 280.0 and mean < 320.0, "seed %d: mean from %.0f, between 280 and 320" % [seed_value, mean])
	check(steady > 0.45 and steady < 0.7, "seed %d: constancy %.2f, 0.45 to 0.7" % [seed_value, steady])
	check(within > 0.5 and within < 0.7, "seed %d: %.2f of the time within 45 degrees of WNW" % [seed_value, within])


# The heading never jumps: no wrap from 2 pi to 0, under 60 degrees in 10 game minutes even through a front's sharp back (about 40).
func _smooth() -> void:
	var worst: float = 0.0
	var previous: float = float(Weather.state(WORLD_SEED, 0.0, "temperate")["wind_dir"])

	for m in range(1, 24 * 6 * 60):
		var heading: float = float(Weather.state(WORLD_SEED, float(m) * 600.0, "temperate")["wind_dir"])
		check(is_finite(heading), "wind_dir finite")
		worst = maxf(worst, absf(heading - previous))
		previous = heading

	check(worst < deg_to_rad(60.0), "the heading turns at most %.0f degrees per 10 game minutes, no jump" % rad_to_deg(worst))


# Fronts, the southern rule: while rain is coming on, the wind has veered (turn above 0); once it eases, it has backed (below 0).
func _fronts() -> void:
	var coming: Array = [0.0, 0]
	var going: Array = [0.0, 0]

	for h in range(3, 365 * 24):
		var t: float = float(h) * 3600.0
		var wet_now: float = float(Weather.state(WORLD_SEED, t, "temperate")["rain"])
		var wet_before: float = float(Weather.state(WORLD_SEED, t - 3.0 * 3600.0, "temperate")["rain"])
		var turn: float = Weather.front_turn_deg(WORLD_SEED, t, "temperate")

		if wet_now > wet_before + 0.05:
			coming[0] += turn
			coming[1] += 1
		elif wet_now < wet_before - 0.05:
			going[0] += turn
			going[1] += 1

	var veer: float = coming[0] / maxf(float(coming[1]), 1.0)
	var back: float = going[0] / maxf(float(going[1]), 1.0)
	print("fronts: as rain comes on the wind has turned %+.0f degrees on average (%d hours); as it eases %+.0f (%d hours)" % [veer, coming[1], back, going[1]])
	check(coming[1] > 50 and going[1] > 50, "fronts: enough wet spells in a year")
	check(veer > 10.0, "fronts: veered (clockwise) as the rain comes on, 57 S")
	check(back < -20.0, "fronts: backed (anticlockwise) as it eases")


# The front of the pictures (prevailing_wind.md section 6), base world, days 107 and 108: rain from about 21:00 on a veered WNW
# wind; the back to SSW with the wind's peak about 05:00 to 07:00. A Python copy of the noise gave these numbers.
func _front_days() -> void:
	var day: float = 86400.0
	var before: Dictionary = Weather.state(WORLD_SEED, 107.0 * day + 22.0 * 3600.0, "temperate")
	var before_from: float = Weather.prevailing_from_deg(WORLD_SEED, 107.0 * day + 22.0 * 3600.0, "temperate")
	var after: Dictionary = Weather.state(WORLD_SEED, 108.0 * day + 7.0 * 3600.0, "temperate")
	var after_from: float = Weather.prevailing_from_deg(WORLD_SEED, 108.0 * day + 7.0 * 3600.0, "temperate")
	var noon_109: float = Weather.prevailing_from_deg(WORLD_SEED, 109.0 * day + 12.0 * 3600.0, "temperate")
	print("day 107 22:00 from %.0f rain %.2f; day 108 07:00 from %.0f rain %.2f wind %.2f; day 109 12:00 from %.0f" % [before_from, float(before["rain"]), after_from, float(after["rain"]), float(after["wind"]), noon_109])
	check(float(before["rain"]) > 0.2 and before_from > 285.0 and before_from < 312.0, "day 107 22:00: raining on a veered WNW wind (from %.0f, about 298)" % before_from)
	check(Weather.front_turn_deg(WORLD_SEED, 107.0 * day + 22.0 * 3600.0, "temperate") > 20.0, "day 107 22:00: veered")
	check(after_from > 180.0 and after_from < 215.0, "day 108 07:00: backed to SSW (from %.0f, about 194)" % after_from)
	check(float(after["rain"]) > 0.2 and float(after["wind"]) > 0.5, "day 108 07:00: still raining, and windier")
	check(noon_109 > 270.0 and noon_109 < 295.0, "day 109 12:00: from the west-north-west (%.0f, about 283)" % noon_109)


# Coast, lee and canopy, on a breezy noon (no slope or sea breeze: the world's wind is over 6 m/s).
func _local() -> void:
	var t: float = 109.0 * 86400.0 + 12.0 * 3600.0
	var w: Dictionary = {"wind": 0.6, "wind_dir": 0.3, "cloud": 0.2, "sun": 0.8}
	var base: float = Weather.wind_mps(0.6)
	var inland: Dictionary = Weather.local_wind(w, {}, t)
	var coast: Dictionary = Weather.local_wind(w, {"sea_upwind": 1.0}, t)
	var lee: Dictionary = Weather.local_wind(w, {"lee": 1.0}, t)
	var trees: Dictionary = Weather.local_wind(w, {"canopy": 1.0}, t)
	check(absf(float(coast["wind_mps"]) - base) < 0.01 and absf(float(inland["wind_mps"]) - 0.85 * base) < 0.01, "coast keeps the wind, inland 0.85 of it")
	check(float(coast["wind_gust"]) < float(inland["wind_gust"]), "the coast is steadier (gust x%.2f against x%.2f)" % [float(coast["wind_gust"]), float(inland["wind_gust"])])
	check(absf(float(lee["wind_mps"]) - 0.35 * 0.85 * base) < 0.01, "a crest's lee keeps 0.35")
	check(absf(float(trees["wind_mps"]) - 0.2 * 0.85 * base) < 0.01, "under the canopy 0.2")
	check(absf(float(inland["wind_dir"]) - 0.3) < 1e-4 and float(inland["wind_base_dir"]) == 0.3, "no breeze: the heading is the world's")
	check(absf(Weather.wind_of_mps(Weather.wind_mps(0.42)) - 0.42) < 1e-4, "wind to m/s and back")
	var steep: Dictionary = {"grade": 0.3, "downhill": Vector2(1, 0)}
	var windy_night: Dictionary = Weather.local_wind(w, steep, 109.0 * 86400.0 + 2.0 * 3600.0)
	check(float(windy_night["wind_slope_mps"]) == 0.0, "no slope breeze in a 10 m/s wind")
	# The heading stays near the world's when a breeze adds on (no jump of 2 pi).
	var calm: Dictionary = {"wind": 0.15, "wind_dir": TAU * 3.0 - 0.1, "cloud": 0.1, "sun": 0.0}
	var night: Dictionary = Weather.local_wind(calm, {"grade": 0.3, "downhill": Vector2(0, 1)}, 109.0 * 86400.0 + 2.0 * 3600.0)
	check(absf(float(night["wind_dir"]) - float(calm["wind_dir"])) < PI, "the bent heading stays next to the world's")


# Slope breezes on a clear light-wind day and night (1.7 m/s from the south): down the slope at night, full after dusk and before
# dawn, up the slope in the afternoon sun, little either way two hours after sunrise (the turn-round).
func _slope_hours() -> void:
	var day: float = 109.0
	var rise: float = Weather.sunrise_hour(day)
	var set_h: float = 24.0 - rise
	var steep: Dictionary = {"grade": 0.3, "downhill": Vector2(1, 0)}
	var gentle: Dictionary = {"grade": 0.08, "downhill": Vector2(1, 0)}
	var night_sky: Dictionary = {"wind": 0.15, "wind_dir": PI * 0.5 + PI, "cloud": 0.1, "sun": 0.0}
	var day_sky: Dictionary = {"wind": 0.15, "wind_dir": PI * 0.5 + PI, "cloud": 0.1, "sun": 1.0}
	var at: Callable = func(hour: float) -> float: return day * 86400.0 + fposmod(hour, 24.0) * 3600.0
	var deep_night: Dictionary = Weather.local_wind(night_sky, steep, at.call(rise - 1.0))
	print("slope: sunrise %.2f; night down-slope %+.1f m/s; after dusk %+.1f; an hour before sunset %+.1f; afternoon %+.1f; two hours after sunrise %+.1f" % [rise, float(deep_night["wind_slope_mps"]), float(Weather.local_wind(night_sky, steep, at.call(set_h + 1.6))["wind_slope_mps"]), float(Weather.local_wind(day_sky, steep, at.call(set_h - 1.0))["wind_slope_mps"]), float(Weather.local_wind(day_sky, steep, at.call(14.0))["wind_slope_mps"]), float(Weather.local_wind(day_sky, steep, at.call(rise + 2.0))["wind_slope_mps"])])
	check(float(deep_night["wind_slope_mps"]) > 2.5, "before dawn: about 3 m/s down a steep slope")
	var drawn: Vector2 = Vector2.from_angle(float(deep_night["wind_dir"]))
	check(drawn.dot(Vector2(1, 0)) > 0.8, "before dawn the wind runs downhill (dot %.2f)" % drawn.dot(Vector2(1, 0)))
	check(float(Weather.local_wind(night_sky, gentle, at.call(rise - 1.0))["wind_slope_mps"]) < 1.5, "a gentle slope drains more weakly")
	check(float(Weather.local_wind(night_sky, steep, at.call(set_h + 1.6))["wind_slope_mps"]) > 2.5, "full by 1.5 h after sunset")
	check(absf(float(Weather.local_wind(day_sky, steep, at.call(rise + 2.0))["wind_slope_mps"])) < 1.0, "little either way two hours after sunrise")
	var afternoon: Dictionary = Weather.local_wind(day_sky, steep, at.call(14.0))
	check(float(afternoon["wind_slope_mps"]) < -1.2, "sunny afternoon: up the slope (%+.1f m/s)" % float(afternoon["wind_slope_mps"]))
	check(float(Weather.local_wind({"wind": 0.15, "wind_dir": 0.0, "cloud": 0.95, "sun": 0.0}, steep, at.call(rise - 1.0))["wind_slope_mps"]) < 0.3, "no katabatic under a full cloud cover")
	check(float(Weather.local_wind(night_sky, {"grade": 0.02, "downhill": Vector2(1, 0)}, at.call(rise - 1.0))["wind_slope_mps"]) == 0.0, "none on the flat")
	# Smooth through the day: under 0.4 m/s per 6 game minutes (the sky's sun switches at sunrise and sunset, where the up-slope share is 0).
	var worst: float = 0.0
	var previous: float = float(Weather.local_wind(night_sky, steep, at.call(0.0))["wind_slope_mps"])

	for k in range(1, 240):
		var now: float = float(Weather.local_wind(day_sky if fposmod(k * 0.1, 24.0) > rise and fposmod(k * 0.1, 24.0) < set_h else night_sky, steep, at.call(k * 0.1))["wind_slope_mps"])
		worst = maxf(worst, absf(now - previous))
		previous = now

	check(worst < 0.4, "the slope breeze changes smoothly through the day (worst %.2f m/s per 6 min)" % worst)


# Sea breeze: onshore 2 to 4 m/s on a calm sunny afternoon by the sea, none in a fresh wind, offshore (land breeze) on a clear night.
func _sea_breeze() -> void:
	var t_day: float = 109.0 * 86400.0 + 14.5 * 3600.0
	var t_night: float = 109.0 * 86400.0 + 2.0 * 3600.0
	var by_sea: Dictionary = {"sea_way": Vector2(1, 0), "sea_upwind": 0.0}
	var calm_sun: Dictionary = {"wind": 0.15, "wind_dir": PI * 0.5, "cloud": 0.1, "sun": 1.0}
	var afternoon: Dictionary = Weather.local_wind(calm_sun, by_sea, t_day)
	var onshore: float = float(afternoon["wind_sea_mps"])
	check(onshore > 2.0 and onshore <= 4.0, "sea breeze %.1f m/s on a calm sunny afternoon" % onshore)
	check(Vector2.from_angle(float(afternoon["wind_dir"])).dot(Vector2(-1, 0)) > 0.6, "it blows in from the sea")
	check(float(Weather.local_wind({"wind": 0.4, "wind_dir": PI * 0.5, "cloud": 0.1, "sun": 1.0}, by_sea, t_day)["wind_sea_mps"]) == 0.0, "none when the world's wind is over 4 m/s")
	check(float(Weather.local_wind(calm_sun, by_sea, 109.0 * 86400.0 + 8.0 * 3600.0)["wind_sea_mps"]) < 0.5, "not yet at 08:00")
	var land: float = float(Weather.local_wind({"wind": 0.15, "wind_dir": PI * 0.5, "cloud": 0.1, "sun": 0.0}, by_sea, t_night)["wind_sea_mps"])
	check(land < -1.0 and land >= -2.0, "land breeze offshore at night (%.1f m/s)" % land)
