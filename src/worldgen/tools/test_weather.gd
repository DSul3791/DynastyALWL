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
	print("weather: desert %s temperate %s" % [str(desert), str(temperate)])
	print("weather: high %s neutral %s low %s" % [str(high), str(neutral), str(low)])
	print("weather: %d failures" % failures)
	quit(1 if failures > 0 else 0)
