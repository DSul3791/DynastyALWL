extends SceneTree

# Prevailing wind checks (docs/design/prevailing_wind.md): the starter island's months follow Jamie's 34 S rose (#773: a summer
# south-easter, winter westerlies, a mixed spring), the wind veers ahead of a front and backs after it, the heading never jumps,
# and the local wind (coast, lee, canopy, gusts, slope and sea breezes) does what the design note says.
#   godot --headless --path . --script res://src/worldgen/tools/test_wind_dir.gd

const Weather := preload("res://src/shared/weather.gd")

const WORLD_SEED := 574716103             # worlds/base_world (the pictures' world)

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	_bearings()
	_months(WORLD_SEED)
	_months(777)
	_smooth()
	_fronts()
	_front_days()
	_local()
	_slope_hours()
	_sea_breeze()
	print("test_wind_dir: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


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


# The starter island's months, hourly over three game years (34 S page section 1; the numbers a Python copy gave are in weather.gd):
# local summer blows from the south-east side, local winter from the west, and Spring 1 is mixed.
func _months(seed_value: int) -> void:
	var summer: Dictionary = _month_rose(seed_value, [3, 4])
	var winter: Dictionary = _month_rose(seed_value, [9, 10])
	var spring: Dictionary = _month_rose(seed_value, [0])
	var s: Array = summer["share"]
	var w: Array = winter["share"]
	print("seed %d: Summer 1-2 from %.0f (E %.0f SE %.0f S %.0f W %.0f NW %.0f %%), Winter 1-2 from %.0f (SW %.0f W %.0f NW %.0f E %.0f SE %.0f %%), Spring 1 constancy %.2f" % [seed_value, summer["mean"], 100.0 * s[2], 100.0 * s[3], 100.0 * s[4], 100.0 * s[6], 100.0 * s[7], winter["mean"], 100.0 * w[5], 100.0 * w[6], 100.0 * w[7], 100.0 * w[2], 100.0 * w[3], spring["steady"]])
	check(summer["mean"] > 125.0 and summer["mean"] < 170.0, "seed %d: local summer blows from the south-east (from %.0f; the page 141)" % [seed_value, summer["mean"]])
	check(s[2] + s[3] + s[4] >= 0.6 and s[6] + s[7] <= 0.25, "seed %d: a summer south-easter, not a westerly" % seed_value)
	check(winter["mean"] > 255.0 and winter["mean"] < 295.0, "seed %d: local winter blows from the west (from %.0f; the page 279)" % [seed_value, winter["mean"]])
	check(w[5] + w[6] + w[7] >= 0.55 and w[2] + w[3] <= 0.15, "seed %d: winter westerlies, not a south-easter" % seed_value)
	check(spring["steady"] < 0.4, "seed %d: Spring 1 is mixed (constancy %.2f; the page 0.28)" % [seed_value, spring["steady"]])


# The sector shares (N, NE .. NW), the vector mean bearing and the constancy over the given game months (0 = Spring 1) of three years.
func _month_rose(seed_value: int, months: Array) -> Dictionary:
	var sectors: Array = [0, 0, 0, 0, 0, 0, 0, 0]
	var sum: Vector2 = Vector2.ZERO
	var n: int = 0

	for year in range(3):
		for month in months:
			for h in range(int(float(month) * 365.0 / 12.0 * 24.0), int(float(month + 1) * 365.0 / 12.0 * 24.0)):
				var bearing: float = Weather.prevailing_from_deg(seed_value, float(year * 365 * 24 + h) * 3600.0, "temperate")
				sectors[int(fposmod(bearing + 22.5, 360.0) / 45.0) % 8] += 1
				sum += Vector2(sin(deg_to_rad(bearing)), cos(deg_to_rad(bearing)))
				n += 1

	var share: Array = []

	for count in sectors:
		share.append(float(count) / float(n))

	return {"share": share, "mean": fposmod(rad_to_deg(atan2(sum.x, sum.y)), 360.0), "steady": sum.length() / float(n)}


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
	check(veer > 10.0, "fronts: veered (clockwise) as the rain comes on, the southern rule")
	check(back < -20.0, "fronts: backed (anticlockwise) as it eases")


# A winter front on the base world (a Python copy of weather.gd gave these): day 281 21:00 in the westerlies the wind has veered
# right round to the north-north-east (from about 34); by day 282 04:00 the cold front has passed and it has backed to the
# west-south-west (about 248), the squall at its peak.
func _front_days() -> void:
	var day: float = 86400.0
	var ahead: float = 281.0 * day + 21.0 * 3600.0
	var behind: float = 282.0 * day + 4.0 * 3600.0
	var ahead_from: float = Weather.prevailing_from_deg(WORLD_SEED, ahead, "temperate")
	var behind_from: float = Weather.prevailing_from_deg(WORLD_SEED, behind, "temperate")
	print("day 281 21:00 from %.0f, turn %+.0f; day 282 04:00 from %.0f, turn %+.0f, squall %.2f" % [ahead_from, Weather.front_turn_deg(WORLD_SEED, ahead, "temperate"), behind_from, Weather.front_turn_deg(WORLD_SEED, behind, "temperate"), Weather.front_squall(WORLD_SEED, behind, "temperate")])
	check(Weather.westerly_spell(WORLD_SEED, ahead, "temperate") == 1.0 and Weather.westerly_spell(WORLD_SEED, behind, "temperate") == 1.0, "days 281 and 282: a westerly spell")
	check(Weather.front_turn_deg(WORLD_SEED, ahead, "temperate") > 50.0 and (ahead_from > 15.0 and ahead_from < 50.0), "day 281 21:00: veered to the north-north-east ahead of the front (from %.0f, about 34)" % ahead_from)
	check(Weather.front_turn_deg(WORLD_SEED, behind, "temperate") < -75.0 and behind_from > 230.0 and behind_from < 265.0, "day 282 04:00: backed to the west-south-west behind it (from %.0f, about 248)" % behind_from)
	check(Weather.front_squall(WORLD_SEED, behind, "temperate") > 0.85, "and the squall is at its peak")
	check(float(Weather.state(WORLD_SEED, behind, "temperate")["wind_squall"]) == Weather.front_squall(WORLD_SEED, behind, "temperate"), "the state carries the squall")


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
	check(is_equal_approx(float(coast["wind_gust"]), 1.4) and is_equal_approx(float(inland["wind_gust"]), 1.7) and is_equal_approx(float(trees["wind_gust"]), 2.5), "gust factors: open sea 1.4, inland 1.7, under trees 2.5 (34 S page section 4)")
	var squall: Dictionary = Weather.local_wind({"wind": 1.0, "wind_dir": 0.3, "cloud": 0.9, "sun": 0.1, "wind_squall": 1.0}, {"sea_upwind": 1.0}, t)
	check(is_equal_approx(float(squall["wind_gust"]), 2.0) and float(squall["wind_gust_mps"]) > 39.0 and float(squall["wind"]) <= 1.0, "a squall over a 20 m/s gale: gusts x2.0, 40 m/s in m/s, the mean still capped at 1")
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
