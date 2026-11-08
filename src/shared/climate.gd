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


# Latitude comes from the world grid (Dave, 8 Nov): 21 x 21 tiles, the centre row (world.json `equator_tile_row`) is the equator.
# North is -Z, so a row with a larger number than the equator's lies south, and its latitude is negative. Read by the sun and moon
# (and the fog's sunrise) with --one-sky.
# world_settings.gd latitude_for_z runs from 0 at the equator row's centre to 1 at the poles (the wrap seam half the world away), so
# latitude in degrees is that x 90 (Jamie, 8 Nov), and one row is 90 / 10.5 = 8.57 degrees: the starter row 4's centre is 34.3 S.
const TILES_Z := 21                       # worlds/base_world/world.json tiles_z
const DEG_PER_ROW := 90.0 / (float(TILES_Z) * 0.5)
const STARTER_ROW := 4                    # the starter island's tile row (world.json starter_tiles: [3, 4]; the cave tile 3,4)


# The tile row a world z (metres) lies in: row 0 runs from z 0 to one tile south (+Z), as terrain_client's weather zone counts it.
static func row_of_z(z_m: float, tile_size_m: float) -> int:
	return floori(z_m / tile_size_m)


# One tile row in, its signed latitude in degrees out (south negative), held to the poles: latitude_for_z x 90 at the row's centre.
static func latitude_of_row(row: int, equator_row: int = 0) -> float:
	return clampf(-float(row - equator_row) * DEG_PER_ROW, -90.0, 90.0)


# The game calendar is the starter island's (day 0 its spring equinox, midsummer at phase 0.25), so the sun's declination takes the
# sign of the starter's hemisphere: -1 south of the equator, +1 north.
static func calendar_sign() -> float:
	return -1.0 if latitude_of_row(STARTER_ROW) < 0.0 else 1.0


# A row's own year phase (0 its spring equinox, 0.25 its midsummer) from the calendar's: half a year on across the equator from the
# starter's hemisphere, the same on its side and on the equator row itself. For season reads by place (Steve's season_at).
static func local_year_phase(year_phase: float, row: int, equator_row: int = 0) -> float:
	var lat: float = latitude_of_row(row, equator_row)
	var across: bool = lat != 0.0 and signf(lat) != calendar_sign()
	return fposmod(year_phase + (0.5 if across else 0.0), 1.0)


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
