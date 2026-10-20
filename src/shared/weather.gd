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


# {"rain", "snow", "storm", "cloud", "sun", "wind" (all 0..1), "temp_c", "season"}.
static func state(seed_value: int, game_s: float, zone_group: String, altitude_m: float = 0.0, spirit: float = 0.0) -> Dictionary:
	var zone: Dictionary = ZONES.get(zone_group, ZONES["temperate"])
	var phase: float = year_phase(game_s)
	var temp: float = float(zone["temp"]) + float(zone["swing"]) * cos(TAU * (phase - 0.375)) - maxf(altitude_m, 0.0) * 0.0065
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

		if night and zone_group != "desert" and temp > 1.0:
			var gentle: float = smoothstep(0.55, 0.8, _noise(seed_value, 2, game_s / (FRONT_HOURS * 3600.0)))
			precip = maxf(precip, 0.22 * spirit * gentle)
	elif spirit < 0.0:
		# Low spirit: fronts last longer and hit harder, wherever rain can fall.
		var longer: float = smoothstep(need - 0.2 * -spirit, need + 0.2, front)
		precip = clampf(maxf(precip, longer) * (1.0 + 0.9 * -spirit), 0.0, 1.0) if zone_group != "desert" else precip

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
		"temp_c": temp,
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
