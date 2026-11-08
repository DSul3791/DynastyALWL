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
const Climate := preload("res://src/shared/climate.gd")             # the island climate and the one air temperature
const FRONT_HOURS := 12.0                  # game hours between weather fronts (the noise grid step)
const NIGHT_FROM := 21.0
const NIGHT_TO := 5.0

# Per zone group: how wet. The temperatures come from the island climate (climate.gd).
const ZONES := {
	"desert": {"wet": 0.04},
	"transition": {"wet": 0.17},
	"temperate": {"wet": 0.27},
	"arctic": {"wet": 0.22},
}

# Rain takes the edge off the air: up to this many degrees colder at full rain (Dave 3 Nov 2026: rain should cool things).
const RAIN_COOL_C := 4.0

# Valley fog (radiation fog; docs/design/valley_fog.md, art_weather_light.md section 7, coordinator decision 6 of 8 Nov 2026).
# It forms on calm, clear nights in low ground, is thickest at dawn and burns off 1 to 3 hours after sunrise; most common in
# autumn. `mist` (0..1) is the strength of the fog layer and `mist_top_m` the height of its top above sea level (0 when there
# is none). Neither depends on the altitude passed in: the layer is one for the whole zone row, the same for everyone.
const MIST_BY_ZONE := {"desert": 0.1, "transition": 0.45, "temperate": 1.0, "arctic": 0.5}
const MIST_FROM_HOUR := 22.0               # the fog starts to gather from here (it is full four hours later)
const MIST_GATHER_H := 4.0
const MIST_BURN_FROM_H := 1.0              # hours after sunrise when it starts to burn off
const MIST_BURN_TO_H := 3.0                # and when it is gone
const MIST_CALM_WIND := 0.3                # full fog at or below this wind (0.15 is dead calm, 1 a storm)
const MIST_WINDY := 0.5                    # none at or above this
const MIST_CLEAR_FRONT := 0.4              # a clear night (front noise at or below this: no cloud building)
const MIST_CLOUDY_FRONT := 0.6             # none from here (cloud cover stops the ground cooling)
const MIST_TOP_MIN_M := 30.0               # the top of a full layer lies between these, a new height each night
const MIST_TOP_MAX_M := 140.0
# Sea fog (advection fog, haar; docs/design/fog_pools_and_sea_fog.md part B): mild moist air over a colder sea, carried in by a
# light onshore wind, most in late spring and early summer while the land warms and the sea stays cold, none in a calm or a gale.
# `sea_fog` is its strength over the sea, `sea_fog_land` how far it lies over the land (thinned by the afternoon's heating, back
# in the evening), `sea_fog_top_m` its top above sea level (0 when there is none).
const SEA_FOG_BY_ZONE := {"desert": 0.6, "transition": 0.8, "temperate": 1.0, "arctic": 0.8}
const SEA_FOG_PEAK_PHASE := 0.2            # late spring
const SEA_FOG_WIND_FROM := 0.2             # none in a calm (wind 0.15 is dead calm) ...
const SEA_FOG_WIND_FULL := 0.3             # ... full in a light breeze ...
const SEA_FOG_WIND_EASE := 0.55            # ... thinning from here ...
const SEA_FOG_WIND_GONE := 0.7             # ... and blown away by this
const SEA_FOG_LAND_AFTERNOON := 0.35       # share left over the land in the warmest hours
const SEA_FOG_TOP_MIN_M := 60.0
const SEA_FOG_TOP_MAX_M := 200.0
# The sun path of day_cycle.gd (LATITUDE_DEG, AXIAL_TILT_DEG): the burn-off follows the real sunrise. Keep the two the same.
const SUN_LATITUDE_DEG := 52.0
const SUN_TILT_DEG := 23.44
# --one-sky (docs/design/one_sky_design.md): the latitude of the tile row (Climate.latitude_of_row; the starter row 4 is 57 S with the
# placeholder spread) and the starter calendar's declination, calendar_sign() x 23.44 sin(2 pi phase), as day_cycle.gd draws them.
# Off: 52 N as before.
static var one_sky_on: bool = AppConfig.has_flag("one-sky")

# The year's phase, 0..1: spring starts at 0, high summer is about 0.375, winter's middle 0.875.
static func year_phase(game_s: float) -> float:
	var days: float = float(GameClockScript.DAYS_PER_YEAR)
	return fposmod(game_s / GameClockScript.SECONDS_PER_DAY, days) / days


static func season_of(game_s: float) -> String:
	return GameClockScript.SEASON_NAMES[int(year_phase(game_s) * 4.0) % 4]


# --one-sky: the year phase of a tile row (Climate.local_year_phase): half a year on across the equator from the starter island, whose
# calendar the game clock keeps. Off, or on the starter's side of the equator: year_phase as before. STARTER_ROW is Climate.STARTER_ROW.
const STARTER_ROW := 4


static func year_phase_at(game_s: float, row: int = STARTER_ROW, equator_row: int = 0) -> float:
	var phase: float = year_phase(game_s)
	return Climate.local_year_phase(phase, row, equator_row) if one_sky_on else phase


# The season name at a world position (z metres; the world's tile_size_m and equator_tile_row), for season reads by place.
static func season_at(game_s: float, z_m: float, tile_size_m: float, equator_row: int = 0) -> String:
	return GameClockScript.SEASON_NAMES[int(year_phase_at(game_s, Climate.row_of_z(z_m, tile_size_m), equator_row) * 4.0) % 4]


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


# The day's mean air temperature (C): the island's climate (climate.gd) for the season and this spell (from the world seed), cooler with
# altitude; no day and night swing.
static func temp_at(game_s: float, group: String, altitude_m: float = 0.0, seed_value: int = 0) -> float:
	var climate: Dictionary = Climate.of_zone(group)
	return Climate.mean_c(climate, year_phase(game_s), altitude_m) + Climate.spell_c(climate, seed_value, game_s)


# The air temperature (C) at this hour: temp_at plus the day and night swing (Climate.air_c: coldest 05:00, warmest 15:00). The one
# live temperature (docs/design/one_temperature.md): Weather.state's temp_c is this, less the rain's cooling. Pass the world seed:
# the spells come from it, so the server and every client agree.
static func air_c(game_s: float, group: String, altitude_m: float = 0.0, seed_value: int = 0, row: int = STARTER_ROW, equator_row: int = 0) -> float:
	var climate: Dictionary = Climate.of_zone(group)
	return Climate.air_c(climate, year_phase_at(game_s, row, equator_row), hour_of(game_s), altitude_m) + Climate.spell_c(climate, seed_value, game_s)


# The air the snow and ice layer reads (C): air_c plus the island's snow_bias_c (climate.gd; OVERNIGHT_DECISIONS_8NOV.md row 21). Ice on
# still water and whether rain falls as snow use it; everything else reads air_c.
static func snow_air_c(game_s: float, group: String, altitude_m: float = 0.0, seed_value: int = 0, row: int = STARTER_ROW, equator_row: int = 0) -> float:
	return air_c(game_s, group, altitude_m, seed_value, row, equator_row) + Climate.snow_bias_c(Climate.of_zone(group))


# temp_at for the snow and ice layer: the day's mean plus snow_bias_c.
static func snow_temp_at(game_s: float, group: String, altitude_m: float = 0.0, seed_value: int = 0) -> float:
	return temp_at(game_s, group, altitude_m, seed_value) + Climate.snow_bias_c(Climate.of_zone(group))


static func day_shape(hour: float) -> float:
	return Climate.day_shape(hour)


# The day and night part of the air (C) at this hour: daily_range_c / 2 x day_shape, what air_c adds to temp_at (cave mouths halve it, #709).
static func day_part_c(game_s: float, group: String) -> float:
	return 0.5 * float(Climate.of_zone(group).get("daily_range_c", 0.0)) * Climate.day_shape(hour_of(game_s))


# The year's mean air (C) for a zone group at `altitude_m` (Climate.year_mean_c): what still cave air sits at (Jamie #664).
static func year_mean_c(group: String, altitude_m: float = 0.0) -> float:
	return Climate.year_mean_c(Climate.of_zone(group), altitude_m)


# {"rain", "snow", "storm", "cloud", "sun", "wind" (all 0..1), "wind_dir" (radians), "temp_c", "season"}.
# wind_dir is the way the wind blows TOWARD, as an angle in the ground plane: direction = (cos, sin) on (x, z). It turns slowly
# (a new heading about every 20 game hours) and swings further in a storm; same on server and client, nothing saved.
# `row`, `equator_row` (--one-sky): the tile row, for its own seasons (half a year off across the equator) and the fog's sunrise at its
# latitude. The default is the starter row.
static func state(seed_value: int, game_s: float, group: String, altitude_m: float = 0.0, spirit: float = 0.0, row: int = STARTER_ROW, equator_row: int = 0) -> Dictionary:
	var zone: Dictionary = ZONES.get(group, ZONES["temperate"])
	var phase: float = year_phase_at(game_s, row, equator_row)
	var latitude_deg: float = Climate.latitude_of_row(row, equator_row)
	var temp: float = air_c(game_s, group, altitude_m, seed_value, row, equator_row)
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
	var snowing: bool = temp + Climate.snow_bias_c(Climate.of_zone(group)) < 0.5   # rain or snow: the snow layer's air (snow_bias_c, row 21)
	var cloud: float = clampf(maxf(precip, front * wet * 1.2), 0.0, 1.0)
	var wind: float = clampf(0.15 + 0.45 * _noise(seed_value, 3, game_s / (6.0 * 3600.0)) + 0.4 * storm, 0.0, 1.0)
	var mist: float = _mist(seed_value, game_s, group, phase, hour, wind, front, precip, spirit, latitude_deg)
	var sea_fog: float = _sea_fog(seed_value, game_s, group, phase, wind, front, precip)
	var sea_fog_land: float = sea_fog * _land_keeps_sea_fog(year_phase(game_s), hour, latitude_deg)   # the calendar's phase: the sunrise takes the hemisphere from the latitude

	return {
		"rain": 0.0 if snowing else precip,
		"snow": precip if snowing else 0.0,
		"storm": storm,
		"cloud": cloud,
		"sun": clampf(1.0 - cloud * 1.1, 0.0, 1.0),
		"wind": wind,
		"wind_dir": TAU * _noise(seed_value, 4, game_s / (20.0 * 3600.0)) + 0.8 * storm * (_noise(seed_value, 5, game_s / (2.0 * 3600.0)) - 0.5),
		"temp_c": temp - RAIN_COOL_C * (0.0 if snowing else precip),
		"season": GameClockScript.SEASON_NAMES[int(phase * 4.0) % 4],
		"mist": mist,
		"mist_top_m": mist_top_m(seed_value, game_s, mist),
		"sea_fog": sea_fog,
		"sea_fog_land": sea_fog_land,
		"sea_fog_top_m": sea_fog_top_m(seed_value, game_s, sea_fog),
	}


# Visibility V (m) at a height, from a weather state: the same rule the client's look draws its fog by (weather_look.gd visibility_m,
# Kathleen #724), so the server (animals in fog, docs/design/animals_in_fog_server.md) and the client agree on one V. Koschmieder with a
# 5 % threshold: V = 3 / extinction, the extinction the clear haze VIS_HAZE_DENSITY times 1 + 5 rain + 4 snow + 3 storm + VIS_MIST_THICK
# x how deep the point is in the valley fog (eased over VIS_MIST_EDGE_M across mist_top_m), at most VIS_THICK_MAX times. Clear air about
# 3.3 km, full valley fog about 220 m, the thickest about 170 m (Jamie #716: recognise at half V, detail at a quarter). No caves or water.
const VIS_HAZE_DENSITY := 0.0009      # = LookSettings.FOG_DENSITY (client)
const VIS_MIST_THICK := 14.0          # = WeatherLook.MIST_INSIDE_THICK
const VIS_MIST_EDGE_M := 6.0          # = WeatherLook.MIST_EDGE_M
const VIS_THICK_MAX := 20.0           # = the look's cap on the fog multiple


static func visibility_m(weather_state: Dictionary, height_m: float) -> float:
	var mist: float = clampf(float(weather_state.get("mist", 0.0)), 0.0, 1.0)
	var inside: float = mist * smoothstep(-VIS_MIST_EDGE_M, VIS_MIST_EDGE_M, float(weather_state.get("mist_top_m", 0.0)) - height_m)
	var thick: float = 1.0 + 5.0 * float(weather_state.get("rain", 0.0)) + 4.0 * float(weather_state.get("snow", 0.0)) + 3.0 * float(weather_state.get("storm", 0.0)) + VIS_MIST_THICK * inside
	return 3.0 / (VIS_HAZE_DENSITY * minf(thick, VIS_THICK_MAX))


# Hour of sunrise (sun centre on the horizon) on a day of the year, for the sun path day_cycle.gd draws (`latitude_deg`: the tile
# row's, which --one-sky reads; NAN takes the starter row's).
static func sunrise_hour(day_of_year: float, latitude_deg: float = NAN) -> float:
	var sky_lat: float = Climate.latitude_of_row(Climate.STARTER_ROW) if is_nan(latitude_deg) else latitude_deg
	var phi: float = deg_to_rad(sky_lat if one_sky_on else SUN_LATITUDE_DEG)
	var delta: float = (Climate.calendar_sign() if one_sky_on else 1.0) * deg_to_rad(SUN_TILT_DEG) * sin(TAU * day_of_year / float(GameClockScript.DAYS_PER_YEAR))
	var half_day_h: float = rad_to_deg(acos(clampf(-tan(phi) * tan(delta), -1.0, 1.0))) / 15.0
	return 12.0 - half_day_h


# Valley fog strength, 0..1 (see the MIST_ constants): calm, clear nights in a humid zone, gathering from 22:00, thickest at
# dawn, burnt off 1 to 3 hours after sunrise, strongest in autumn, a different night each time. None while rain or snow falls.
static func _mist(seed_value: int, game_s: float, group: String, phase: float, hour: float, wind: float, front: float, precip: float, spirit: float, latitude_deg: float = NAN) -> float:
	var since: float = fposmod(hour - MIST_FROM_HOUR, 24.0)                  # hours since the fog started to gather
	var day_of_year: float = year_phase(game_s) * float(GameClockScript.DAYS_PER_YEAR)   # the calendar's day: sunrise_hour takes the hemisphere from the latitude
	var sunrise_since: float = fposmod(sunrise_hour(day_of_year, latitude_deg) - MIST_FROM_HOUR, 24.0)
	var timing: float = smoothstep(0.0, MIST_GATHER_H, since) * (1.0 - smoothstep(sunrise_since + MIST_BURN_FROM_H, sunrise_since + MIST_BURN_TO_H, since))

	if timing <= 0.0:
		return 0.0

	var calm: float = 1.0 - smoothstep(MIST_CALM_WIND, MIST_WINDY, wind)
	var clear: float = 1.0 - smoothstep(MIST_CLEAR_FRONT, MIST_CLOUDY_FRONT, front)
	var dry: float = 1.0 - smoothstep(0.02, 0.1, precip)
	var autumn: float = 0.55 + 0.45 * cos(TAU * (phase - 0.625))              # 1 in mid autumn, 0.1 in mid spring
	var night: float = smoothstep(0.25, 0.75, _noise(seed_value, 6, game_s / GameClockScript.SECONDS_PER_DAY))   # some nights none
	var zone: float = float(MIST_BY_ZONE.get(group, MIST_BY_ZONE["temperate"]))
	var spirit_gain: float = 1.0 + 0.5 * maxf(spirit, 0.0)                   # high spirit: clear mornings with valley mist
	return clampf(timing * calm * clear * dry * autumn * night * zone * spirit_gain, 0.0, 1.0)


# Sea fog strength over the sea, 0..1 (see the SEA_FOG_ constants). None while rain or snow falls or under thick cloud.
static func _sea_fog(seed_value: int, game_s: float, group: String, phase: float, wind: float, front: float, precip: float) -> float:
	var season: float = 0.5 + 0.5 * cos(TAU * (phase - SEA_FOG_PEAK_PHASE))
	var breeze: float = smoothstep(SEA_FOG_WIND_FROM, SEA_FOG_WIND_FULL, wind) * (1.0 - smoothstep(SEA_FOG_WIND_EASE, SEA_FOG_WIND_GONE, wind))
	var dry: float = 1.0 - smoothstep(0.02, 0.1, precip)
	var not_overcast: float = 1.0 - smoothstep(MIST_CLEAR_FRONT, MIST_CLOUDY_FRONT, front)
	var day: float = smoothstep(0.45, 0.85, _noise(seed_value, 8, game_s / GameClockScript.SECONDS_PER_DAY))
	var zone: float = float(SEA_FOG_BY_ZONE.get(group, SEA_FOG_BY_ZONE["temperate"]))
	return clampf(season * breeze * dry * not_overcast * day * zone, 0.0, 1.0)


# Share of the sea fog that lies over the land: all of it at night and in the early morning, SEA_FOG_LAND_AFTERNOON in the
# afternoon (the warm land burns it back toward the coast; it comes in again in the evening).
static func _land_keeps_sea_fog(phase: float, hour: float, latitude_deg: float = NAN) -> float:
	var sunrise: float = sunrise_hour(phase * float(GameClockScript.DAYS_PER_YEAR), latitude_deg)
	var heating: float = smoothstep(sunrise + 2.0, sunrise + 5.0, hour) * (1.0 - smoothstep(17.0, 20.0, hour))
	return lerpf(1.0, SEA_FOG_LAND_AFTERNOON, heating)


# Top of the sea fog above sea level (m): a new height each day between SEA_FOG_TOP_MIN_M and SEA_FOG_TOP_MAX_M, lower while it
# is thin. 0 when there is none.
static func sea_fog_top_m(seed_value: int, game_s: float, sea_fog: float) -> float:
	if sea_fog <= 0.0:
		return 0.0

	var full: float = lerpf(SEA_FOG_TOP_MIN_M, SEA_FOG_TOP_MAX_M, _noise(seed_value, 9, game_s / GameClockScript.SECONDS_PER_DAY))
	return full * (0.6 + 0.4 * sea_fog)


# Top of the fog layer above sea level (m): a new height each night between MIST_TOP_MIN_M and MIST_TOP_MAX_M, lower while
# the layer is thin (it sinks as it burns off). 0 when there is no fog.
static func mist_top_m(seed_value: int, game_s: float, mist: float) -> float:
	if mist <= 0.0:
		return 0.0

	var full: float = lerpf(MIST_TOP_MIN_M, MIST_TOP_MAX_M, _noise(seed_value, 7, game_s / GameClockScript.SECONDS_PER_DAY))
	return full * (0.5 + 0.5 * mist)


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
