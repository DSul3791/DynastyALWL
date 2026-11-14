extends RefCounted

# Plot moisture (buildables plan, batch B5, Morgan 10 Nov 2026; Sonny's water rules 10 Nov 2026, section 8): every tilled bed and garden plot holds
# 0 to 100 percent of a soil store (data/items/crops.json "moisture"). Heavy rain fills it, light rain wets it, a pour adds pour_pct, and the dry
# weather takes it away as the weather's evaporation, not a clock: evap_mm a day from cool_mm at cool_c to hot_mm at hot_c (less below freezing,
# more in wind), out of store_mm, times the plot's moisture_factor (a framed bed holds its water: Thatch 0.85, Wooden 0.7, Stone and Brick 0.6).
# Numbers (first pass): a 2 x 2 plot's store of 25 mm is 100 L, so one 8 L bucket is 8 percent, a hot day (4 mm) about 16 percent, a cool one 5.
# A crop's day is a wet day when its bed holds at least wet_min_pct. Pure functions: the server keeps the values (server_items _plots_tick).

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


static func pour(cfg: Dictionary, pct: float, bucket_share: float = 1.0) -> float:   # bucket_share: the part of a bucket (pour_ml) poured
	return minf(100.0, pct + float(cfg.get("pour_pct", 8.0)) * bucket_share)


static func is_wet(cfg: Dictionary, pct: float) -> bool:
	return pct >= float(cfg.get("wet_min_pct", 25.0))
