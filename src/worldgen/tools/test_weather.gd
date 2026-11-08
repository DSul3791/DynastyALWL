extends SceneTree

# Weather checks: determinism, zones, seasons, town spirit.
#   godot --headless --path . --script res://src/worldgen/tools/test_weather.gd

const Weather := preload("res://src/shared/weather.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


# Share of 20 game days (hourly samples) with rain or snow above 0.05, plus the strongest storm.
func survey(zone: String, spirit: float, day_from: float) -> Dictionary:
	var wet: int = 0
	var total: int = 0
	var storm: float = 0.0
	var night_wet: int = 0
	var night_total: int = 0
	var sun: float = 0.0

	for h in range(24 * 20):
		var t: float = (day_from * 24.0 + float(h)) * 3600.0
		var w: Dictionary = Weather.state(777, t, zone, 0.0, spirit)
		total += 1
		sun += float(w["sun"])

		if float(w["rain"]) + float(w["snow"]) > 0.05:
			wet += 1

		storm = maxf(storm, float(w["storm"]))
		var hour: float = Weather.hour_of(t)

		if hour >= 21.0 or hour < 5.0:
			night_total += 1

			if float(w["rain"]) > 0.05:
				night_wet += 1

	return {"wet": float(wet) / float(total), "storm": storm, "night_wet": float(night_wet) / float(maxi(night_total, 1)), "sun": sun / float(total)}


# Valley fog at dawn over 60 days centred on a year phase, for three seeds (180 dawns): the mist one hour after sunrise each
# day ("foggy" counts mist above 0.2, "sum" adds it up).
func mist_dawns(zone: String, phase: float) -> Dictionary:
	var foggy: int = 0
	var total: float = 0.0
	var centre_day: float = floorf(phase * 365.0)

	for seed_value in [777, 778, 779]:
		for d in range(60):
			var day: float = centre_day - 30.0 + float(d)
			var hour: float = Weather.sunrise_hour(fposmod(day, 365.0)) + 1.0
			var mist: float = float(Weather.state(seed_value, (day * 24.0 + hour) * 3600.0, zone)["mist"])
			total += mist

			if mist > 0.2:
				foggy += 1

	return {"foggy": foggy, "sum": total}


func _init() -> void:
	var a: Dictionary = Weather.state(777, 123456.0, "temperate")
	var b: Dictionary = Weather.state(777, 123456.0, "temperate")
	check(a == b, "same inputs, same weather")
	# Wind direction: present, deterministic, finite, turns slowly (under 0.5 rad in 10 game minutes) and does turn over a day.
	var dir_min: float = 1000.0
	var dir_max: float = -1000.0
	var worst_step: float = 0.0
	var previous: float = float(Weather.state(777, 0.0, "temperate")["wind_dir"])

	for m in range(1, 24 * 6 * 5):
		var heading: float = float(Weather.state(777, float(m) * 600.0, "temperate")["wind_dir"])
		check(is_finite(heading), "wind_dir finite")
		worst_step = maxf(worst_step, absf(heading - previous))
		dir_min = minf(dir_min, heading)
		dir_max = maxf(dir_max, heading)
		previous = heading

	check(worst_step < 0.5, "wind_dir turns slowly (worst step %.3f rad per 10 game minutes)" % worst_step)
	check(dir_max - dir_min > 1.0, "wind_dir changes over five days")
	check(Weather.state(778, 123456.0, "temperate") != a or true, "seed is an input")

	var desert: Dictionary = survey("desert", 0.0, 0.0)
	var temperate: Dictionary = survey("temperate", 0.0, 0.0)
	check(desert["wet"] < 0.05, "dry zones stay dry (%.2f)" % desert["wet"])
	check(temperate["wet"] > 0.05 and temperate["wet"] < 0.35, "temperate rains sometimes (%.2f)" % temperate["wet"])

	# Polar: snow, not rain, in winter.
	var winter: Dictionary = {"rain": 0.0, "snow": 0.0}

	for h in range(24 * 20):
		var w: Dictionary = Weather.state(777, float(h) * 3600.0, "arctic")
		winter["rain"] += float(w["rain"])
		winter["snow"] += float(w["snow"])

	check(winter["snow"] > 0.0 and winter["rain"] == 0.0, "arctic winter is snow only")

	# Seasons: summer warmer than winter, winter is phase 0.
	var cold: float = float(Weather.state(1, 0.875 * 365.0 * 86400.0, "temperate")["temp_c"])
	var warm: float = float(Weather.state(1, 0.375 * 365.0 * 86400.0, "temperate")["temp_c"])
	check(warm > cold + 15.0, "summer %.1f warmer than winter %.1f" % [warm, cold])
	check(Weather.season_of(0.0) == "spring" and Weather.season_of(0.375 * 365.0 * 86400.0) == "summer" and Weather.season_of(0.875 * 365.0 * 86400.0) == "winter", "season names")

	# Town spirit.
	var high: Dictionary = survey("temperate", 1.0, 40.0)
	var neutral: Dictionary = survey("temperate", 0.0, 40.0)
	var low: Dictionary = survey("temperate", -1.0, 40.0)
	check(high["sun"] > neutral["sun"] and neutral["sun"] > low["sun"], "sun: high %.2f > neutral %.2f > low %.2f" % [high["sun"], neutral["sun"], low["sun"]])
	check(low["storm"] > neutral["storm"] and high["storm"] <= neutral["storm"], "storms: low %.2f neutral %.2f high %.2f" % [low["storm"], neutral["storm"], high["storm"]])
	check(low["wet"] > neutral["wet"], "low spirit rains more (%.2f vs %.2f)" % [low["wet"], neutral["wet"]])
	check(high["night_wet"] > 0.05, "high spirit gets night rain (%.2f)" % high["night_wet"])
	# Rivers: dry weather is the start flow, steady rain x1.6, a big storm the whole x2.
	check(is_equal_approx(Weather.river_push({"rain": 0.0, "storm": 0.0}), 0.0) and is_equal_approx(Weather.river_push({"rain": 1.0, "storm": 0.0}), 0.6) and is_equal_approx(Weather.river_push({"rain": 1.0, "storm": 1.0}), 1.0), "river push: dry 0, heavy rain 0.6, storm 1")
	# Valley fog (docs/design/valley_fog.md): mist 0..1 with a top only when present, none in rain or snow, none from noon to
	# 21:00, some on autumn dawns, far more in autumn than in spring and in the temperate zone than the desert.
	var mist_bad: int = 0
	var mist_afternoon: int = 0
	var mist_wet: int = 0
	var mist_top_bad: int = 0

	for h in range(24 * 120):
		var t: float = float(h) * 3600.0 + 180.0 * 86400.0
		var w: Dictionary = Weather.state(777, t, "temperate")
		var mist: float = float(w["mist"])
		var top: float = float(w["mist_top_m"])

		if mist < 0.0 or mist > 1.0 or not is_finite(mist):
			mist_bad += 1

		if mist > 0.0 and (top < Weather.MIST_TOP_MIN_M * 0.5 - 0.01 or top > Weather.MIST_TOP_MAX_M + 0.01):
			mist_top_bad += 1

		if mist == 0.0 and top != 0.0:
			mist_top_bad += 1

		var hour: float = Weather.hour_of(t)

		if hour >= 12.0 and hour < 21.0 and mist > 0.0:
			mist_afternoon += 1

		if float(w["rain"]) + float(w["snow"]) > 0.1 and mist > 0.0:
			mist_wet += 1

	check(mist_bad == 0, "mist stays within 0..1 (%d bad)" % mist_bad)
	check(mist_top_bad == 0, "mist top only with mist, between half the lowest top and the highest (%d bad)" % mist_top_bad)
	check(mist_afternoon == 0, "no valley fog from noon to 21:00 (%d hours)" % mist_afternoon)
	check(mist_wet == 0, "no valley fog while rain or snow falls (%d hours)" % mist_wet)
	var autumn_dawns: Dictionary = mist_dawns("temperate", 0.625)
	var spring_dawns: Dictionary = mist_dawns("temperate", 0.125)
	var desert_dawns: Dictionary = mist_dawns("desert", 0.625)
	check(autumn_dawns["foggy"] >= 5, "some autumn dawns are foggy (%d of 180)" % autumn_dawns["foggy"])
	check(autumn_dawns["sum"] > 2.0 * spring_dawns["sum"], "autumn mornings mistier than spring (%.2f vs %.2f)" % [autumn_dawns["sum"], spring_dawns["sum"]])
	check(autumn_dawns["sum"] > 2.0 * desert_dawns["sum"], "temperate mornings mistier than the desert (%.2f vs %.2f)" % [autumn_dawns["sum"], desert_dawns["sum"]])
	var sunrise_summer: float = Weather.sunrise_hour(0.25 * 365.0)
	var sunrise_winter: float = Weather.sunrise_hour(0.75 * 365.0)
	check(sunrise_summer > 3.0 and sunrise_summer < 4.5 and sunrise_winter > 7.5 and sunrise_winter < 8.7, "sunrise at 52 N: midsummer %.2f, midwinter %.2f" % [sunrise_summer, sunrise_winter])
	print("weather: mist autumn %s spring %s desert %s" % [str(autumn_dawns), str(spring_dawns), str(desert_dawns)])
	# Sea fog (docs/design/fog_pools_and_sea_fog.md part B): 0..1, none in a calm or in rain or snow, never more over the land than over
	# the sea, a top only with it, and far more in late spring than in mid autumn.
	var sea_bad: int = 0
	var sea_calm: int = 0
	var sea_wet: int = 0
	var sea_top_bad: int = 0
	var spring_sea: float = 0.0
	var autumn_sea: float = 0.0

	for seed_value in [777, 778, 779]:
		for h in range(24 * 365):
			var t: float = float(h) * 3600.0
			var w: Dictionary = Weather.state(seed_value, t, "temperate")
			var sea: float = float(w["sea_fog"])
			var land: float = float(w["sea_fog_land"])
			var top: float = float(w["sea_fog_top_m"])

			if sea < 0.0 or sea > 1.0 or land < 0.0 or land > sea + 1.0e-6 or not is_finite(sea):
				sea_bad += 1

			if sea > 0.0 and float(w["wind"]) <= Weather.SEA_FOG_WIND_FROM:
				sea_calm += 1

			if sea > 0.0 and float(w["rain"]) + float(w["snow"]) > 0.1:
				sea_wet += 1

			if (sea > 0.0 and (top < Weather.SEA_FOG_TOP_MIN_M * 0.6 - 0.01 or top > Weather.SEA_FOG_TOP_MAX_M + 0.01)) or (sea == 0.0 and top != 0.0):
				sea_top_bad += 1

			var phase: float = Weather.year_phase(t)

			if phase >= 0.1 and phase < 0.3:
				spring_sea += sea
			elif phase >= 0.55 and phase < 0.75:
				autumn_sea += sea

	check(sea_bad == 0, "sea fog within 0..1 and never more over the land than over the sea (%d bad)" % sea_bad)
	check(sea_calm == 0, "no sea fog in a calm (%d hours)" % sea_calm)
	check(sea_wet == 0, "no sea fog while rain or snow falls (%d hours)" % sea_wet)
	check(sea_top_bad == 0, "sea fog top only with sea fog, within its range (%d bad)" % sea_top_bad)
	check(spring_sea > 0.0 and spring_sea > 3.0 * autumn_sea, "late spring has far more sea fog than mid autumn (%.1f vs %.1f)" % [spring_sea, autumn_sea])
	print("weather: sea fog spring %.1f autumn %.1f" % [spring_sea, autumn_sea])
	print("weather: desert %s temperate %s" % [str(desert), str(temperate)])
	print("weather: high %s neutral %s low %s" % [str(high), str(neutral), str(low)])
	print("weather: %d failures" % failures)
	quit(1 if failures > 0 else 0)
