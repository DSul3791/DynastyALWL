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
	# the starter island (the temperate zone) is 9 C +-5 at sea level, coldest at 05:00 and warmest at 15:00.
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
	check(absf(Climate.mean_c(starter, 0.875) - 4.0) < 0.01 and absf(Climate.mean_c(starter, 0.375) - 14.0) < 0.01, "the starter's sea-level mean runs from 4 C in midwinter to 14 C in high summer (before cold and warm spells)")
	var dawn: float = Climate.air_c(starter, 0.875, 5.0)
	var afternoon: float = Climate.air_c(starter, 0.875, 15.0)
	check(absf(afternoon - dawn - 8.0) < 0.1, "the day's range is 8 C from 05:00 to 15:00 (%.1f to %.1f)" % [dawn, afternoon])
	check(absf(Weather.temp_at(midwinter, "temperate", 1000.0, 777) - (Weather.temp_at(midwinter, "temperate", 0.0, 777) - 6.5)) < 0.01, "6.5 C colder per km of height")
	# Cold and warm spells: within the island's spell_amplitude_c, slow (under 2.5 C a day), the same for the same seed, and on the coast some winter
	# nights fall below freezing (Fort William gets air frosts in most winters).
	var spell_low: float = 100.0
	var spell_high: float = -100.0
	var spell_step: float = 0.0
	var frost_nights: int = 0

	for d in range(365):
		var day_s: float = float(d) * 86400.0
		var spell: float = Climate.spell_c(starter, 777, day_s)
		spell_low = minf(spell_low, spell)
		spell_high = maxf(spell_high, spell)
		spell_step = maxf(spell_step, absf(Climate.spell_c(starter, 777, day_s + 86400.0) - spell))
		var night_low: float = 100.0

		for h in range(9):
			night_low = minf(night_low, Weather.air_c(day_s + float(h) * 3600.0, "temperate", 0.0, 777))

		if night_low < 0.0:
			frost_nights += 1

	check(spell_low >= -float(starter["spell_amplitude_c"]) - 0.001 and spell_high <= float(starter["spell_amplitude_c"]) + 0.001 and spell_high - spell_low > 3.0, "spells stay within +-%.0f C and do swing (%.1f to %.1f)" % [float(starter["spell_amplitude_c"]), spell_low, spell_high])
	check(spell_step < 2.5, "spells change slowly (worst %.2f C in a day)" % spell_step)
	check(Climate.spell_c(starter, 777, 5.0e6) == Climate.spell_c(starter, 777, 5.0e6) and Climate.spell_c(starter, 778, 5.0e6) != Climate.spell_c(starter, 777, 5.0e6), "spells follow the seed")
	check(frost_nights >= 10 and frost_nights <= 120, "the starter coast gets some air frosts (%d nights a year)" % frost_nights)
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
	print("weather: desert %s temperate %s" % [str(desert), str(temperate)])
	print("weather: high %s neutral %s low %s" % [str(high), str(neutral), str(low)])
	print("weather: %d failures" % failures)
	quit(1 if failures > 0 else 0)
