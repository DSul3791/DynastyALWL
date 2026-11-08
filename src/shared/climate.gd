extends RefCounted

# One climate per island (Sonny's record, docs/water/watershed_rebuild_design.md A4: record/climate.json, one object per island id),
# and the one air temperature everything reads (docs/design/one_temperature.md, coordinator 8 Nov 2026):
#   air at a place = sea_level_mean_c + seasonal_swing_c x cos(TAU (year phase - warmest_year_phase)) + the spell (spell_amplitude_c, spell_days)
#                    + daily_range_c / 2 x day_shape(hour) - lapse_c_per_km x height / 1000
# Weather (temp_c, so snow, breath, the HUD and the server's warmth), ice and snow all use it. Until the record exists the values come
# from DEFAULTS below; at R6 the record's objects replace them with the same field names. Static helpers only; thread safe.

# The starter island: Fort William at the foot of Ben Nevis (Sonny, A4: about 9 C over the year, a swing of about +-5 C). daily_range_c 8
# is the coordinator's starter value (judged, near the UK's land figures). rain_mm_yr is the island's background rain, carried for the
# record's shape; the live weather does not read it yet (its wetness stays per zone). The other zones keep the weather's old zone
# numbers in the same fields until their islands have records.
const DEFAULTS := {
	"starter": {"sea_level_mean_c": 9.0, "seasonal_swing_c": 5.0, "warmest_year_phase": 0.375, "daily_range_c": 8.0, "lapse_c_per_km": 6.5, "rain_mm_yr": 2000.0, "spell_amplitude_c": 4.0, "spell_days": [3.0, 6.0], "spell_stream": 31},
	"desert": {"sea_level_mean_c": 28.0, "seasonal_swing_c": 8.0, "warmest_year_phase": 0.375, "daily_range_c": 14.0, "lapse_c_per_km": 6.5, "rain_mm_yr": 150.0, "spell_amplitude_c": 3.0, "spell_days": [3.0, 6.0], "spell_stream": 32},
	"transition": {"sea_level_mean_c": 19.0, "seasonal_swing_c": 11.0, "warmest_year_phase": 0.375, "daily_range_c": 10.0, "lapse_c_per_km": 6.5, "rain_mm_yr": 700.0, "spell_amplitude_c": 3.0, "spell_days": [3.0, 6.0], "spell_stream": 33},
	"arctic": {"sea_level_mean_c": -9.0, "seasonal_swing_c": 14.0, "warmest_year_phase": 0.375, "daily_range_c": 5.0, "lapse_c_per_km": 6.5, "rain_mm_yr": 400.0, "spell_amplitude_c": 3.0, "spell_days": [3.0, 6.0], "spell_stream": 34},
}

# The weather's zone groups and the island each stands for until islands are looked up by position (the starter is the temperate island).
const ISLAND_OF_ZONE := {"temperate": "starter", "desert": "desert", "transition": "transition", "arctic": "arctic"}

# Cold and warm spells (coordinator and Sonny, 8 Nov 2026): a departure of the day's mean from the season, the same on server and client
# from the world seed and the island. Sonny's fields: spell_amplitude_c (the +- size; starter 4 C, judged so the coast gets air frosts on
# some winter nights like Fort William; a small ocean island about 2) and spell_days ([shortest, longest] spell). Two smooth noises, one on
# a grid of the longest and one of the shortest, mixed SPELL_LONG_SHARE to the rest: a bounded walk that always relaxes back to the
# season. spell_stream is ours (the noise stream per island). The record and the baked snow window use the climate WITHOUT spells
# (the long-run average); the live air adds them.
const SPELL_LONG_SHARE := 0.6

const DAY_COLDEST_HOUR := 5.0             # just before dawn (Met Office: the coolest air comes just before dawn)
const DAY_WARMEST_HOUR := 15.0            # mid afternoon


static func of_zone(group: String) -> Dictionary:
	return DEFAULTS.get(ISLAND_OF_ZONE.get(group, "starter"), DEFAULTS["starter"])


# The spell (C) on this island at game time `game_s`: -spell_amplitude_c .. +spell_amplitude_c, smooth, the same for every caller with the same seed.
static func spell_c(climate: Dictionary, seed_value: int, game_s: float) -> float:
	var stream: int = int(climate.get("spell_stream", 31))
	var spell_days: Array = climate.get("spell_days", [3.0, 6.0])
	var day: float = game_s / 86400.0
	var long_part: float = _noise(seed_value, stream, day / float(spell_days[1]))
	var short_part: float = _noise(seed_value, stream + 100, day / float(spell_days[0]))
	var mix: float = SPELL_LONG_SHARE * long_part + (1.0 - SPELL_LONG_SHARE) * short_part
	return float(climate.get("spell_amplitude_c", 0.0)) * (2.0 * mix - 1.0)


# The day's mean air (C) at `altitude_m`: the season and the height, no day and night swing.
static func mean_c(climate: Dictionary, year_phase: float, altitude_m: float = 0.0) -> float:
	var seasonal: float = float(climate["seasonal_swing_c"]) * cos(TAU * (year_phase - float(climate["warmest_year_phase"])))
	return float(climate["sea_level_mean_c"]) + seasonal - float(climate["lapse_c_per_km"]) * maxf(altitude_m, 0.0) / 1000.0


# The year's mean air (C) at `altitude_m`: no season and no day and night swing. Still cave air sits at it (Jamie's caves page, #664).
static func year_mean_c(climate: Dictionary, altitude_m: float = 0.0) -> float:
	return float(climate["sea_level_mean_c"]) - float(climate["lapse_c_per_km"]) * maxf(altitude_m, 0.0) / 1000.0


# The air (C) at `altitude_m` at this hour: the day's mean plus half the day's range times day_shape.
static func air_c(climate: Dictionary, year_phase: float, hour: float, altitude_m: float = 0.0) -> float:
	return mean_c(climate, year_phase, altitude_m) + 0.5 * float(climate["daily_range_c"]) * day_shape(hour)


# -1 at the coldest hour, +1 at the warmest, between them a half cosine each way (rising over 10 hours, falling over 14), so the day's
# mean is 0.
static func day_shape(hour: float) -> float:
	var rise_h: float = DAY_WARMEST_HOUR - DAY_COLDEST_HOUR
	var since: float = fposmod(hour - DAY_COLDEST_HOUR, 24.0)

	if since < rise_h:
		return -cos(PI * since / rise_h)

	return cos(PI * (since - rise_h) / (24.0 - rise_h))


# Smooth value noise in 0..1 along one axis, per (seed, stream): the weather's own noise (weather.gd _noise), copied so this file needs no
# other script.
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
