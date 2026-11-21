extends RefCounted

# Plot moisture (buildables plan, batch B5, Morgan 10 Nov 2026; Sonny's water rules 10 Nov 2026, section 8; garden moisture, Dave 19 Nov 2026: "the rain
# should water it pretty good ... if it needs water it should show its moisture content that can slowly reduce on hot days with no rain"): every tilled
# bed and garden plot holds 0 to 100 percent of a soil store of store_mm over its area (data/items/crops.json "moisture"). Heavy rain fills it, lighter
# rain wets it, water poured or piped in adds its litres over the store (litres_per_pct), and the dry weather takes it away as the weather's
# evaporation, not a clock: evap_mm a day from cool_mm at cool_c to hot_mm at hot_c (less below freezing, more in wind), out of store_mm, times the
# plot's moisture_factor (a framed bed holds its water: Wooden 0.7). A crop's day is a wet day when its bed holds at least wet_min_pct; a dry day grows
# it only dry_growth of a day. Numbers (PROVISIONAL, docs/design/GARDEN_MOISTURE.md): a 1 m bed's 25 mm store is 25 L, so one 8 L bucket is 32 percent,
# a hot day (4 mm) 16 percent, a cool one 5. Pure functions: the server keeps the values (server_items _plots_tick).

const DAY_S := 86400.0   # game seconds in a game day (server_items _game_day)


# Millimetres of water a bare soil gives up in a game day at `temp_c` with `wind` 0..1 (no rain).
static func evaporation_mm(cfg: Dictionary, temp_c: float, wind: float) -> float:
	var cool_c: float = float(cfg.get("cool_c", 5.0))
	var hot_c: float = float(cfg.get("hot_c", 25.0))
	var cool_mm: float = float(cfg.get("cool_mm", 1.25))
	var hot_mm: float = float(cfg.get("hot_mm", 4.0))
	var mm: float = 0.0

	if temp_c >= cool_c:
		mm = lerpf(cool_mm, hot_mm, clampf((temp_c - cool_c) / maxf(hot_c - cool_c, 0.1), 0.0, 1.0))
	else:
		mm = cool_mm * clampf(temp_c / maxf(cool_c, 0.1), 0.0, 1.0)   # down to nothing at freezing

	return mm * (1.0 + float(cfg.get("wind_x", 0.3)) * clampf(wind, 0.0, 1.0))


# The plot's moisture after `dt_days` game days of this weather, from `pct`.
static func step(cfg: Dictionary, pct: float, dt_days: float, temp_c: float, wind: float, rain: float, factor: float = 1.0) -> float:
	if rain >= float(cfg.get("rain_heavy", 0.5)):
		return 100.0

	if rain >= float(cfg.get("rain_any", 0.05)):
		return minf(100.0, pct + float(cfg.get("rain_gain_pct_per_day", 200.0)) * rain * dt_days)

	var loss: float = evaporation_mm(cfg, temp_c, wind) / maxf(float(cfg.get("store_mm", 25.0)), 0.1) * 100.0 * factor
	return maxf(0.0, pct - loss * dt_days)


# Litres a bed or plot of `area_m2` takes for 1 percent of moisture: its store over its area (25 mm on 1 m2: 0.25 L; on 2 x 2 m: 1 L).
static func litres_per_pct(cfg: Dictionary, area_m2: float) -> float:
	return maxf(float(cfg.get("store_mm", 25.0)) * maxf(area_m2, 0.01) / 100.0, 0.01)


# The moisture after `litres` are poured or piped onto a bed whose percent costs `per_pct` litres, up to full.
static func pour(pct: float, litres: float, per_pct: float) -> float:
	return minf(100.0, pct + maxf(litres, 0.0) / maxf(per_pct, 0.01))


static func is_wet(cfg: Dictionary, pct: float) -> bool:
	return pct >= float(cfg.get("wet_min_pct", 25.0))


# One day's growth for a crop: a whole day on a wet day, dry_growth of one on a dry one (the soil below wet_min_pct all day's end).
static func day_growth(cfg: Dictionary, wet: bool) -> float:
	return 1.0 if wet else clampf(float(cfg.get("dry_growth", 0.5)), 0.0, 1.0)


# The word the look-at line gives a moisture: "wet" from wet_pct, "damp" from wet_min_pct (still a wet day), else "dry" (the crop needs water).
static func word(cfg: Dictionary, pct: float) -> String:
	if pct >= float(cfg.get("wet_pct", 70.0)):
		return "wet"

	return "damp" if is_wet(cfg, pct) else "dry"
