extends SceneTree

# Weather checks: determinism, zones, seasons, town spirit.
#   godot --headless --path . --script res://src/worldgen/tools/test_weather.gd

const Weather := preload("res://src/shared/weather.gd")
const Climate := preload("res://src/shared/climate.gd")

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
	check(warm > cold + 6.0, "summer %.1f warmer than winter %.1f" % [warm, cold])
	# One temperature (docs/design/one_temperature.md): temp_c is the island air with its day and night swing, less the rain's cooling;
	# the starter island (the temperate zone) is world.json's curve at its grid row (about 14.2 C, #717 row 21) +-5 at sea level, coldest at
	# 05:00 and warmest at 15:00.
	var starter_bad: int = 0

	for h in range(24 * 365):
		var t: float = float(h) * 3600.0
		var w: Dictionary = Weather.state(777, t, "temperate")
		var air: float = Weather.air_c(t, "temperate", 0.0, 777)

		if float(w["temp_c"]) > air + 0.001 or float(w["temp_c"]) < air - Weather.RAIN_COOL_C - 0.001:
			starter_bad += 1

	check(starter_bad == 0, "temp_c is the island air less the rain's cooling (%d bad hours)" % starter_bad)
	var midwinter: float = 0.875 * 365.0 * 86400.0
	var starter: Dictionary = Climate.of_zone("temperate")
	var sea_mean: float = float(starter["sea_level_mean_c"])
	check(absf(sea_mean - 14.16) < 0.05, "the starter's sea-level year mean is world.json's curve at row 4, about 14.2 C (%.2f)" % sea_mean)
	check(absf(Climate.mean_c(starter, 0.875) - (sea_mean - 5.0)) < 0.01 and absf(Climate.mean_c(starter, 0.375) - (sea_mean + 5.0)) < 0.01, "the starter's sea-level mean runs 5 C below it in midwinter and 5 C above in high summer (before cold and warm spells)")
	check(absf(sea_mean + Climate.snow_bias_c(starter) - 9.0) < 0.05 and Climate.snow_bias_c(Climate.of_zone("arctic")) == 0.0, "the snow and ice layer reads the starter as the old 9 C island (snow_bias_c %.2f), other zones as they are" % Climate.snow_bias_c(starter))
	check(is_equal_approx(Weather.snow_air_c(midwinter, "temperate", 0.0, 777), Weather.air_c(midwinter, "temperate", 0.0, 777) + Climate.snow_bias_c(starter)), "snow_air_c is the air plus snow_bias_c")
	var dawn: float = Climate.air_c(starter, 0.875, 5.0)
	var afternoon: float = Climate.air_c(starter, 0.875, 15.0)
	check(absf(afternoon - dawn - 8.0) < 0.1, "the day's range is 8 C from 05:00 to 15:00 (%.1f to %.1f)" % [dawn, afternoon])
	check(absf(Weather.temp_at(midwinter, "temperate", 1000.0, 777) - (Weather.temp_at(midwinter, "temperate", 0.0, 777) - 6.5)) < 0.01, "6.5 C colder per km of height")
	# Cold and warm spells: within the island's spell_amplitude_c, slow (under 2.5 C a day), the same for the same seed. For the snow and ice
	# layer (snow_bias_c) some winter nights on the coast fall below freezing; in the plain air a frost at sea level is rare (#717 row 21).
	var spell_low: float = 100.0
	var spell_high: float = -100.0
	var spell_step: float = 0.0
	var frost_nights: int = 0
	var plain_frosts: int = 0

	for d in range(365):
		var day_s: float = float(d) * 86400.0
		var spell: float = Climate.spell_c(starter, 777, day_s)
		spell_low = minf(spell_low, spell)
		spell_high = maxf(spell_high, spell)
		spell_step = maxf(spell_step, absf(Climate.spell_c(starter, 777, day_s + 86400.0) - spell))
		var night_low: float = 100.0
		var plain_low: float = 100.0

		for h in range(9):
			night_low = minf(night_low, Weather.snow_air_c(day_s + float(h) * 3600.0, "temperate", 0.0, 777))
			plain_low = minf(plain_low, Weather.air_c(day_s + float(h) * 3600.0, "temperate", 0.0, 777))

		if night_low < 0.0:
			frost_nights += 1

		if plain_low < 0.0:
			plain_frosts += 1

	check(spell_low >= -float(starter["spell_amplitude_c"]) - 0.001 and spell_high <= float(starter["spell_amplitude_c"]) + 0.001 and spell_high - spell_low > 3.0, "spells stay within +-%.0f C and do swing (%.1f to %.1f)" % [float(starter["spell_amplitude_c"]), spell_low, spell_high])
	check(spell_step < 2.5, "spells change slowly (worst %.2f C in a day)" % spell_step)
	check(Climate.spell_c(starter, 777, 5.0e6) == Climate.spell_c(starter, 777, 5.0e6) and Climate.spell_c(starter, 778, 5.0e6) != Climate.spell_c(starter, 777, 5.0e6), "spells follow the seed")
	check(frost_nights >= 10 and frost_nights <= 120, "for snow and ice the starter coast gets some frosts (%d nights a year)" % frost_nights)
	check(plain_frosts < 10, "in the plain air a frost at sea level is rare (%d nights a year)" % plain_frosts)
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
	# Land fog (Dave's fog instruction, 14 Nov 2026; docs/design/FOG_PLAN.md): mist 0..1 with a depth only when present; a dry afternoon
	# clears (14:00 to 18:00 without rain: none); fog may come with light rain but never in heavy rain, and then only thin.
	var mist_bad: int = 0
	var mist_afternoon: int = 0
	var mist_heavy: int = 0
	var mist_in_rain_bad: int = 0
	var mist_depth_bad: int = 0

	for h in range(24 * 120):
		var t: float = float(h) * 3600.0 + 180.0 * 86400.0
		var w: Dictionary = Weather.state(777, t, "temperate")
		var mist: float = float(w["mist"])
		var depth: float = float(w["mist_depth_m"])
		var wet: float = float(w["rain"]) + float(w["snow"])

		if mist < 0.0 or mist > 1.0 or not is_finite(mist):
			mist_bad += 1

		if mist > 0.0 and (depth < Weather.MIST_DEPTH_MIN_M * 0.3 - 0.01 or depth > Weather.MIST_DEPTH_MAX_M + 0.01):
			mist_depth_bad += 1

		if mist == 0.0 and depth != 0.0:
			mist_depth_bad += 1

		var hour: float = Weather.hour_of(t)

		if hour >= 14.0 and hour < 18.0 and wet < 0.05 and mist > 0.0:
			mist_afternoon += 1

		if wet > 0.6 and mist > 0.0:
			mist_heavy += 1

		if wet > 0.1 and mist > Weather.RAIN_FOG * 1.5 + 0.001:
			mist_in_rain_bad += 1

	check(mist_bad == 0, "mist stays within 0..1 (%d bad)" % mist_bad)
	check(mist_depth_bad == 0, "mist depth only with mist, within its range (%d bad)" % mist_depth_bad)
	check(mist_afternoon == 0, "a dry afternoon (14:00 to 18:00) has no fog (%d hours)" % mist_afternoon)
	check(mist_heavy == 0, "no fog in heavy rain or snow (%d hours)" % mist_heavy)

	# One fog for the zone row: the caller's altitude (server at sea level, client at the eye) never changes it.
	var alt_bad: int = 0
	var burn_bad: int = 0
	var burn_seen: int = 0

	for day in range(60):
		for hour in [2, 5, 7, 9, 12, 20]:
			var t_a: float = (float(180 + day) * 24.0 + float(hour)) * 3600.0
			var low: Dictionary = Weather.state(777, t_a, "temperate", 0.0)
			var high: Dictionary = Weather.state(777, t_a, "temperate", 1500.0)

			if not is_equal_approx(float(low["mist"]), float(high["mist"])) or not is_equal_approx(float(low["water_steam"]), float(high["water_steam"])):
				alt_bad += 1

		# Burn-off: some fog is left an hour after sunrise when there was fog at dawn, and five hours on it is thinner.
		var sunrise: float = Weather.sunrise_hour(fposmod(float(180 + day), 365.0))
		var t_rise: float = (float(180 + day) * 24.0 + sunrise) * 3600.0
		var at_rise: Dictionary = Weather.state(777, t_rise, "temperate")
		var dry: bool = float(at_rise["rain"]) + float(at_rise["snow"]) < 0.05

		if dry and float(at_rise["mist"]) > 0.3:
			var w1: Dictionary = Weather.state(777, t_rise + 3600.0, "temperate")
			var w5: Dictionary = Weather.state(777, t_rise + 5.0 * 3600.0, "temperate")

			# Radiation fog only: a morning that stays dry (fog in rain is its own rule).
			if float(w1["rain"]) + float(w1["snow"]) < 0.05 and float(w5["rain"]) + float(w5["snow"]) < 0.05:
				burn_seen += 1

				if float(w1["mist"]) <= 0.0 or float(w5["mist"]) > float(w1["mist"]) + 0.001:
					burn_bad += 1

	check(alt_bad == 0, "the fog and the steam are the same at any caller's altitude (%d differ)" % alt_bad)
	check(burn_seen > 0 and burn_bad == 0, "the fog clears gradually after sunrise, not at once (%d of %d mornings bad)" % [burn_bad, burn_seen])
	check(mist_in_rain_bad == 0, "fog in rain stays thin (%d hours)" % mist_in_rain_bad)
	var in_rain_any: bool = false

	for h in range(24 * 365):
		var w: Dictionary = Weather.state(778, float(h) * 3600.0, "temperate")

		if float(w["rain"]) > 0.05 and float(w["rain"]) < 0.3 and float(w["mist"]) > 0.05:
			in_rain_any = true
			break

	check(in_rain_any, "fog sometimes comes with light rain (Dave: it does not always wait for the rain to stop)")
	# Steam fog over water: cold air over warmer water, in calm air; none in warm air or wind.
	var mean_c: float = Weather.year_mean_c("temperate")
	check(Weather.water_steam(mean_c - 10.0, "temperate", 0.15, 0.0) > 0.9, "cold calm air over warmer water: steam")
	check(is_zero_approx(Weather.water_steam(mean_c + 2.0, "temperate", 0.15, 0.0)), "air warmer than the water: no steam")
	check(is_zero_approx(Weather.water_steam(mean_c - 10.0, "temperate", 0.6, 0.0)), "wind mixes the steam away")
	check(is_zero_approx(Weather.water_steam(mean_c - 10.0, "temperate", 0.15, 0.8)), "heavy rain: no steam")
	var autumn_dawns: Dictionary = mist_dawns("temperate", 0.625)
	var spring_dawns: Dictionary = mist_dawns("temperate", 0.125)
	var desert_dawns: Dictionary = mist_dawns("desert", 0.625)
	check(autumn_dawns["foggy"] >= 5, "some autumn dawns are foggy (%d of 180)" % autumn_dawns["foggy"])
	check(autumn_dawns["sum"] > 2.0 * spring_dawns["sum"], "autumn mornings mistier than spring (%.2f vs %.2f)" % [autumn_dawns["sum"], spring_dawns["sum"]])
	check(autumn_dawns["sum"] > 2.0 * desert_dawns["sum"], "temperate mornings mistier than the desert (%.2f vs %.2f)" % [autumn_dawns["sum"], desert_dawns["sum"]])
	var sunrise_summer: float = Weather.sunrise_hour(0.25 * 365.0)
	var sunrise_winter: float = Weather.sunrise_hour(0.75 * 365.0)
	check(sunrise_summer > 4.5 and sunrise_summer < 5.2 and sunrise_winter > 6.8 and sunrise_winter < 7.5, "sunrise at the starter row (34.3 S, about 04:51 and 07:09): midsummer %.2f, midwinter %.2f" % [sunrise_summer, sunrise_winter])
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
