extends RefCounted

# Cave air by depth and season (docs/design/cave_climate_design.md; Jamie #709, underground-climate.md; coordinator 8 Nov 2026). Static helpers
# only, thread safe. `cfg` is warmth.json cave_climate. Deep in, the air is the year mean at the height (Climate.year_mean_c, 5.5 C at cave
# 8002); in from the mouth it blends from the outside air to that with smoothstep(near_m, reach_m, depth_m), the band set by which way the
# cave runs and the season. depth_m is the straight distance to the nearest mouth (a first pass; bends are not counted).

const RISES := 1     # the passage climbs from the mouth (8002): summer air climbs in far, winter cold pools near the mouth
const LEVEL := 0     # level or not known
const DROPS := -1    # a pit or a descending passage: the reverse, winter cold sinks in and stays

const DEFAULT_BANDS := {"rises_summer": [10.0, 60.0], "rises_winter": [5.0, 20.0], "drops_winter": [10.0, 60.0], "drops_summer": [5.0, 20.0], "level": [10.0, 40.0]}


# Which way a cave runs from its mouth, from the mouth node and the next node in: a grade over min_grade either way, else level.
static func kind_of(mouth: Vector3, inner: Vector3, min_grade: float = 0.05) -> int:
	var run: float = Vector2(inner.x - mouth.x, inner.z - mouth.z).length()
	var grade: float = (inner.y - mouth.y) / maxf(run, 1.0)

	if grade > min_grade:
		return RISES

	return DROPS if grade < -min_grade else LEVEL


# [near_m, reach_m] for this cave and season. Summer is the outside warmer than the cave.
static func band(cfg: Dictionary, kind: int, summer: bool) -> Vector2:
	var bands: Dictionary = cfg.get("bands", DEFAULT_BANDS)
	var key: String = "level"

	if kind == RISES:
		key = "rises_summer" if summer else "rises_winter"
	elif kind == DROPS:
		key = "drops_summer" if summer else "drops_winter"

	var row: Array = bands.get(key, DEFAULT_BANDS[key])
	return Vector2(float(row[0]), float(row[1]))


# The air (C) at depth_m in from the mouth. outside_c is the day's air at the mouth, day_part_c the day and night part of it
# (Climate: daily_range_c / 2 x day_shape), halved inside the cave; deep_c is the year mean at the height.
static func air_c(cfg: Dictionary, outside_c: float, day_part_c: float, deep_c: float, depth_m: float, kind: int) -> float:
	var span: Vector2 = band(cfg, kind, outside_c > deep_c)
	var outside: float = outside_c - (1.0 - float(cfg.get("day_swing_kept", 0.5))) * day_part_c
	return lerpf(outside, deep_c, smoothstep(span.x, maxf(span.y, span.x + 0.1), depth_m))


# The draught at the mouth in m/s: draught_per_c for each degree between outside and cave, up to draught_max_ms, inside draught_m; none past.
# Storms change nothing for caves this size (Jamie #709 lesson 3).
static func draught_ms(cfg: Dictionary, outside_c: float, deep_c: float, depth_m: float) -> float:
	if depth_m >= float(cfg.get("draught_m", 10.0)):
		return 0.0

	return minf(float(cfg.get("draught_per_c", 0.06)) * absf(outside_c - deep_c), float(cfg.get("draught_max_ms", 0.6)))


# The same as the game's 0..1 wind (the shared mapping, wind-over-terrain.md: m/s = 20 x wind^1.3).
static func wind_of_ms(ms: float) -> float:
	return pow(maxf(ms, 0.0) / 20.0, 1.0 / 1.3)


# The share of dry_cover_per_h a sheltered player dries at here: past dry_mouth_m the air is 98 to 100% humid (none); at the mouth in winter
# (outside winter_dry_c or more colder than the cave) the incoming air is dry (winter_dry_share, half); at a summer or mild mouth none.
static func dry_share(cfg: Dictionary, outside_c: float, deep_c: float, depth_m: float) -> float:
	if depth_m >= float(cfg.get("dry_mouth_m", 20.0)):
		return 0.0

	return float(cfg.get("winter_dry_share", 0.5)) if outside_c <= deep_c - float(cfg.get("winter_dry_c", 3.0)) else 0.0
