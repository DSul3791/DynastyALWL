extends RefCounted

# Weather (DESIGN_IDEAS 4.2, owner decisions 2026-10-20): a pure function of the world seed,
# the game clock (game_clock.gd, passed as its `seconds`), the zone (north to south), the altitude and a town-spirit modifier. Nothing
# is stored or sent: the server and every client get the same answer from the same inputs.
#
# Zone sets the climate (dry zones stay dry, polar zones get snow), the season swings it,
# fronts come and go every few game hours. Town spirit (-1 low .. 0 neutral .. +1 high) bends
# it: high spirit is mostly sun with gentle night rain for the crops, low spirit is storms,
# multi-day rain and blizzards. Town spirit does not exist yet, so callers pass 0.
#
# Static helpers only; thread safe.

const GameClockScript := preload("res://src/shared/game_clock.gd")   # the one time source; callers pass its `seconds`
const FRONT_HOURS := 12.0                  # game hours between weather fronts (the noise grid step)
const NIGHT_FROM := 21.0
const NIGHT_TO := 5.0

# Per zone group: how wet, the mean temperature (C) and the seasonal swing (C).
const ZONES := {
	"desert": {"wet": 0.04, "temp": 28.0, "swing": 8.0},
	"transition": {"wet": 0.17, "temp": 19.0, "swing": 11.0},
	"temperate": {"wet": 0.27, "temp": 10.0, "swing": 14.0},
	"arctic": {"wet": 0.22, "temp": -9.0, "swing": 14.0},
}

# Rain takes the edge off the air: up to this many degrees colder at full rain (Dave 3 Nov 2026: rain should cool things).
const RAIN_COOL_C := 4.0

# The year's phase, 0..1: spring starts at 0, high summer is about 0.375, winter's middle 0.875.
static func year_phase(game_s: float) -> float:
	var days: float = float(GameClockScript.DAYS_PER_YEAR)
	return fposmod(game_s / GameClockScript.SECONDS_PER_DAY, days) / days


static func season_of(game_s: float) -> String:
	return GameClockScript.SEASON_NAMES[int(year_phase(game_s) * 4.0) % 4]


# Hour of the game day, 0..24.
static func hour_of(game_s: float) -> float:
	return fposmod(game_s, GameClockScript.SECONDS_PER_DAY) / 3600.0


# The zone group of a tile row from the world's zone list ([[group, max_abs_row], ...], nearest
# the equator first), as the server sends it in the welcome.
static func zone_group(zones: Array, equator_row: int, tile_row: int) -> String:
	var abs_row: int = absi(tile_row - equator_row)

	for zone in zones:
		if abs_row <= int(zone[1]):
			return str(zone[0])

	return str(zones[zones.size() - 1][0]) if not zones.is_empty() else "temperate"


# How hard the weather pushes the rivers, 0 (dry) to 1 (a big storm). Owner (2026-10-20, Dave):
# in a big storm the flow rises from the x10 start flow to x20. Steady heavy rain alone gets
# 0.6 (x16); only a storm gets the whole way. The server lags this over several real minutes.
const RIVER_RAIN_SHARE := 0.6


static func river_push(weather_state: Dictionary) -> float:
	return clampf(maxf(float(weather_state.get("rain", 0.0)) * RIVER_RAIN_SHARE, float(weather_state.get("storm", 0.0))), 0.0, 1.0)


# Dry heat shrinks the rivers (Dave 2026-10-21: a hot spell dries them to a small smooth trickle, never off):
# 0 up to DRY_FROM_C, 1 from DRY_FULL_C, none while it rains.
const DRY_FROM_C := 22.0
const DRY_FULL_C := 32.0


static func river_dry(weather_state: Dictionary) -> float:
	var heat: float = clampf((float(weather_state.get("temp_c", 15.0)) - DRY_FROM_C) / (DRY_FULL_C - DRY_FROM_C), 0.0, 1.0)
	return heat * (1.0 - clampf(maxf(float(weather_state.get("rain", 0.0)) * 2.0, float(weather_state.get("storm", 0.0))), 0.0, 1.0))


# Air temperature (C) from the season (no day/night swing, no weather): zone mean and seasonal swing,
# cooler with altitude. The same number Weather.state reports as temp_c.
static func temp_at(game_s: float, group: String, altitude_m: float = 0.0) -> float:
	var zone: Dictionary = ZONES.get(group, ZONES["temperate"])
	return float(zone["temp"]) + float(zone["swing"]) * cos(TAU * (year_phase(game_s) - 0.375)) - maxf(altitude_m, 0.0) * 0.0065


# The day's swing of the air (docs/design/still_water_ice.md): the full range from the coldest hour to the warmest, per zone
# (judged, near the UK's 7 to 9 C on land; deserts wider, polar air narrower), shrunk to DAY_RANGE_WINTER of it in midwinter.
const DAY_RANGE_C := {"desert": 14.0, "transition": 10.0, "temperate": 8.0, "arctic": 5.0}
const DAY_RANGE_WINTER := 0.6
const DAY_COLDEST_HOUR := 5.0             # just before dawn (Met Office: the coolest air comes just before dawn)
const DAY_WARMEST_HOUR := 15.0            # mid afternoon


# Air temperature (C) with the day and night swing on top of temp_at: coldest at DAY_COLDEST_HOUR, warmest at
# DAY_WARMEST_HOUR, a smooth rise by day and a slower fall through the night; the day's mean is temp_at. No weather (clouds
# would narrow the swing; not yet). Used by the ice on still water (ice.gd); Weather.state's temp_c stays temp_at for now.
static func air_c(game_s: float, group: String, altitude_m: float = 0.0) -> float:
	var summer: float = 0.5 + 0.5 * cos(TAU * (year_phase(game_s) - 0.375))
	var swing: float = 0.5 * float(DAY_RANGE_C.get(group, DAY_RANGE_C["temperate"])) * lerpf(DAY_RANGE_WINTER, 1.0, summer)
	return temp_at(game_s, group, altitude_m) + swing * day_shape(hour_of(game_s))


# -1 at the coldest hour, +1 at the warmest, between them a half cosine each way (rising over 10 hours, falling over 14).
static func day_shape(hour: float) -> float:
	var rise_h: float = DAY_WARMEST_HOUR - DAY_COLDEST_HOUR
	var since: float = fposmod(hour - DAY_COLDEST_HOUR, 24.0)

	if since < rise_h:
		return -cos(PI * since / rise_h)

	return cos(PI * (since - rise_h) / (24.0 - rise_h))


# {"rain", "snow", "storm", "cloud", "sun", "wind" (all 0..1), "wind_dir" (radians), "temp_c", "season"}.
# wind_dir is the way the wind blows TOWARD, as an angle in the ground plane: direction = (cos, sin) on (x, z). It turns slowly
# (a new heading about every 20 game hours) and swings further in a storm; same on server and client, nothing saved.
static func state(seed_value: int, game_s: float, group: String, altitude_m: float = 0.0, spirit: float = 0.0) -> Dictionary:
	var zone: Dictionary = ZONES.get(group, ZONES["temperate"])
	var phase: float = year_phase(game_s)
	var temp: float = temp_at(game_s, group, altitude_m)
	# Wetter in autumn and winter, a little drier in high summer.
	var wet: float = float(zone["wet"]) * (1.0 + 0.2 * cos(TAU * (phase - 0.75)))
	var front: float = _noise(seed_value, 1, game_s / (FRONT_HOURS * 3600.0))
	var need: float = 1.0 - clampf(wet, 0.0, 0.95)
	var precip: float = smoothstep(need, need + 0.3, front)
	var hour: float = hour_of(game_s)
	var night: bool = hour >= NIGHT_FROM or hour < NIGHT_TO
	spirit = clampf(spirit, -1.0, 1.0)

	if spirit > 0.0:
		# High spirit: showers shrink to light rain, and the crops get a gentle rain most nights.
		precip *= 1.0 - 0.75 * spirit

		if night and group != "desert" and temp > 1.0:
			var gentle: float = smoothstep(0.55, 0.8, _noise(seed_value, 2, game_s / (FRONT_HOURS * 3600.0)))
			precip = maxf(precip, 0.22 * spirit * gentle)
	elif spirit < 0.0:
		# Low spirit: fronts last longer and hit harder, wherever rain can fall.
		var longer: float = smoothstep(need - 0.2 * -spirit, need + 0.2, front)
		precip = clampf(maxf(precip, longer) * (1.0 + 0.9 * -spirit), 0.0, 1.0) if group != "desert" else precip

	var storm: float = clampf((precip - 0.7) / 0.3, 0.0, 1.0) * (0.5 + 0.5 * -minf(spirit, 0.0)) if precip > 0.7 else 0.0
	var snowing: bool = temp < 0.5
	var cloud: float = clampf(maxf(precip, front * wet * 1.2), 0.0, 1.0)

	return {
		"rain": 0.0 if snowing else precip,
		"snow": precip if snowing else 0.0,
		"storm": storm,
		"cloud": cloud,
		"sun": clampf(1.0 - cloud * 1.1, 0.0, 1.0),
		"wind": clampf(0.15 + 0.45 * _noise(seed_value, 3, game_s / (6.0 * 3600.0)) + 0.4 * storm, 0.0, 1.0),
		"wind_dir": TAU * _noise(seed_value, 4, game_s / (20.0 * 3600.0)) + 0.8 * storm * (_noise(seed_value, 5, game_s / (2.0 * 3600.0)) - 0.5),
		"temp_c": temp - RAIN_COOL_C * (0.0 if snowing else precip),
		"season": season_of(game_s),
	}


# Smooth value noise in 0..1 along one axis, per (seed, stream).
static func _noise(seed_value: int, stream: int, t: float) -> float:
	var i: int = int(floor(t))
	var f: float = t - float(i)
	f = f * f * (3.0 - 2.0 * f)
	return lerpf(_hash(seed_value, stream, i), _hash(seed_value, stream, i + 1), f)


static func _hash(seed_value: int, stream: int, i: int) -> float:
	var h: int = (seed_value * 73856093) ^ (stream * 19349663) ^ (i * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0
