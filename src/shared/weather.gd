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

# Prevailing wind (docs/design/prevailing_wind.md; always on, Dave 8 Nov: no flags). Each zone group has a mean bearing the wind
# comes FROM, a slow swing either side of it and a turn with every front, the southern hemisphere's way: the wind veers (W to NW to
# N) as a front comes and backs sharply (to SW) once it has passed. The starter island's temperate zone (34.3 S) follows Jamie's
# docs/knowledge/prevailing-wind-34s.md (#773): two spells, a south-easter (from WIND_EAST_FROM_DEG) under the summer high and the
# westerlies (from WIND_WEST_FROM_DEG) with their fronts in winter; each WIND_SPELL_H the wind keeps or changes spell, the westerlies
# winning in WIND_WEST_BY_MONTH of them, and a change of spell swings round through the south over WIND_SPELL_TURN_H. Fronts turn
# the wind fully in the westerlies and only WIND_EAST_FRONT of it in a south-easter (summer fronts are weak, a wind shift and cloud).
# On seeds 574716103 and 777 over ten years (a Python copy of this code) the months give, against Jamie's rose:
#   Summer 1: SE 37 to 39, S 22, E 17, W and NW 6 to 8 %, mean from 142 to 147 (141), constancy 0.53 to 0.57 (0.41)
#   Winter 1: W 27 to 29, NW 25 to 26, SW 15, N 11 %, mean from 275 to 276 (279), constancy 0.49 to 0.51 (0.46)
#   Spring 1 mixed: mean from 191 to 198 (202), constancy 0.23 to 0.29 (0.28); Autumn 1 turning: 222 to 235 (232)
# The other zone rows are judged guesses (trades and polar easterlies) until those islands have a page.
# from_deg: compass bearing the wind most often blows from. spread_deg: the slow swing either side (WIND_WANDER_H noise).
# veer_deg: the turn as a front comes (6 to 18 h); back_deg: the sharp turn once it has passed. reversal_deg: how far a rare
# blocked spell swings it. south: true south of the equator (the front rule turns the other way in the north). seasons: the
# temperate row's two spells by game month (below) instead of from_deg and reversal_deg.
const WIND_BY_ZONE := {
	"temperate": {"from_deg": 218.0, "spread_deg": 50.0, "veer_deg": 60.0, "back_deg": 85.0, "reversal_deg": 0.0, "south": true, "seasons": true},
	"transition": {"from_deg": 295.0, "spread_deg": 70.0, "veer_deg": 30.0, "back_deg": 60.0, "reversal_deg": -150.0, "south": true},
	"desert": {"from_deg": 120.0, "spread_deg": 25.0, "veer_deg": 15.0, "back_deg": 15.0, "reversal_deg": 60.0, "south": true},
	"arctic": {"from_deg": 110.0, "spread_deg": 40.0, "veer_deg": 30.0, "back_deg": 40.0, "reversal_deg": 120.0, "south": true},
}
const WIND_EAST_FROM_DEG := 140.0          # the summer south-easter (34 S page, Summer 1 mean from 141)
const WIND_WEST_FROM_DEG := 288.0          # the winter westerlies before a front's turn (the fronts' veer and back bring the mean to about 279)
# The westerlies' share of spells by game month, Spring 1 (days 0 to 30) .. Winter 3; read between month centres.
const WIND_WEST_BY_MONTH := [0.52, 0.45, 0.27, 0.22, 0.22, 0.33, 0.62, 0.82, 0.9, 0.9, 0.88, 0.72]
const WIND_SPELL_H := 48.0                 # a spell lasts at least two game days, often several in a row (34 S page: 2 to 6 days)
const WIND_SPELL_TURN_H := 8.0             # a change of spell swings the wind round through the south over this many game hours
const WIND_EAST_FRONT := 0.4               # how much of the front's turn a south-easter spell takes
const WIND_WANDER_H := 36.0                # the slow swing's noise step: one direction holds for a day or more
const WIND_FRONT_LAG_H := 6.0              # the front's trend: its strength now against this many hours ago
const WIND_FRONT_FROM := 0.35              # the turn starts once the front noise passes this (rain starts near 0.73 in the temperate zone)
const WIND_FRONT_FULL := 0.8
const WIND_FRONT_SHARP := 0.06             # the trend that gives the full turn: small, so the back at the front comes in an hour or two
const WIND_REVERSAL_FROM := 0.75           # the blocked-spell noise (3-day step) above this starts swinging the wind round
const WIND_REVERSAL_FULL := 0.9
const WIND_SPELL_STREAM := 11              # noise streams: 8 and 9 are the sea fog's, 10 the blocked spell's
const WIND_REVERSAL_STREAM := 10

# Local wind near the ground (local_wind below; the client only, for now): the coast, a crest's lee, the canopy, slope and sea breezes.
const WIND_MPS_AT_1 := 20.0                # wind 0..1 to m/s: m/s = 20 x wind^1.3 (as everywhere else)
const WIND_MPS_POWER := 1.3
const WIND_INLAND_SPEED := 0.85            # moorland 5 to 10 km inland keeps 0.8 to 0.9 of the open coast's wind (Jamie #714)
const WIND_CANOPY_KEEP := 0.2              # under a tree canopy, 0.1 to 0.3 (Jamie #714)
const WIND_LEE_KEEP := 0.35                # the lee of a crest steeper than 18 degrees keeps 0.25 to 0.5 (wind-over-terrain.md)
# Gusts (34 S page section 4): the peak 3 s gust over the 10 minute mean. The game's `wind` (0..1) is the mean and stays capped at 1
# (20 m/s); the gust in m/s is not capped, so a squall over a gale can reach the 27 m/s or so of the year's worst gusts. Anything
# that reads gusts on the 0..1 scale clamps them at 1 itself.
const WIND_GUST_COAST := 1.4               # open sea and headlands, a steady south-easter: 1.3 to 1.5
const WIND_GUST_INLAND := 1.7              # moorland inland: 1.6 to 1.8
const WIND_GUST_SQUALL := 2.0              # the cold front passing: 1.7 to 2.2 for 1 to 10 minutes
const WIND_GUST_CANOPY := 2.5              # under trees, in a crest's lee: a weak mean with sudden puffs, 2 to 3
const KATABATIC_MPS := [1.0, 3.0]          # down-slope at night, gentle .. steep slopes (wind-over-terrain.md: 1 to 3 on our hills)
const ANABATIC_MPS := [0.5, 1.5]           # up-slope by day in sun (wind-over-terrain.md: 1 to 2, judged)
const SLOPE_GRADE := [0.05, 0.3]           # rise over run where slope breezes start and where they are full
const SLOPE_CALM_MPS := [2.0, 6.0]         # a slope breeze is full under 2 m/s of the world's wind and gone at 6
const KATABATIC_FROM_SUNSET_H := [-0.5, 1.5]   # builds from half an hour before sunset to full 1.5 h after
const KATABATIC_TO_SUNRISE_H := [0.5, 2.0]     # holds through the night and dies 0.5 to 2 h after sunrise
const ANABATIC_FROM_SUNRISE_H := [1.5, 3.5]    # the slope must warm first: from 1.5 h after sunrise, full at 3.5
const ANABATIC_TO_SUNSET_H := [2.0, 0.5]       # fades from 2 h before sunset, gone half an hour before
const SEA_BREEZE_MPS := [2.0, 4.0]         # onshore on calm sunny days, spring/autumn .. high summer (Jamie #714: 2 to 4, judged)
const SEA_BREEZE_HOURS := [10.0, 14.5]     # starts about 10:00, full by 14:00 to 15:00, dies at sunset (Jamie #714)
const SEA_BREEZE_CALM_MPS := [2.0, 4.0]    # none when the world's wind is over 4 m/s (Jamie #714, sourced)
const LAND_BREEZE_MPS := 1.5               # offshore on clear calm nights (Jamie #714: 1 to 2)

# Land fog (Dave's fog instruction, 14 Nov 2026, docs/design/FOG_DESIGN_DAVE.md; it grew out of the valley fog of
# docs/design/valley_fog.md). Fog forms from moisture, cooling, wind and terrain, as tendencies with natural variation:
#  - radiation fog: calm, clear nights, gathering from the evening, deepest toward dawn, burning off after sunrise over 1.5 to 5
#    hours (longer when the air is damp: "sunrise should not instantly remove it");
#  - after rain: recent rain is moisture; it makes a cooling calm night's fog likelier and thicker, never fog by itself on a warm,
#    dry, windy afternoon;
#  - in rain: light, steady rain in cool, quiet air can bring a thin fog at any hour;
#  - steam fog: air much colder than the rivers and lakes raises wisps over the water (`water_steam`, any hour, calm air).
# `mist` (0..1) is the strength of the land fog and `mist_depth_m` how deep it lies above the local low ground (the client and the
# server find the low ground from the terrain, fog_ground.gd, so valleys and basins fill while slopes and hilltops stay clear; where no
# ground is known it is the height above sea level). Neither depends on the altitude passed in: one weather for the zone row.
const MIST_BY_ZONE := {"desert": 0.1, "transition": 0.45, "temperate": 1.0, "arctic": 0.5}
const MIST_FROM_SUNSET_H := 1.0            # the fog starts to gather this long after sunset ...
const MIST_GATHER_H := 6.0                 # ... and has gathered fully this long later (it deepens toward dawn)
const MIST_BURN_FROM_H := 0.5              # hours after sunrise when it starts to clear
const MIST_BURN_H := [1.5, 5.0]            # and how long it takes to go: dry air .. damp air
const MIST_CALM_WIND := 0.3                # full fog at or below this wind (0.15 is dead calm, 1 a storm)
const MIST_WINDY := 0.5                    # none at or above this (a shallow ground fog is mixed away; sea fog banks are carried, below)
const MIST_CLEAR_FRONT := 0.4              # a clear night (front noise at or below this: no cloud building)
const MIST_CLOUDY_FRONT := 0.6             # none from here (cloud cover stops the ground cooling)
const MIST_DEPTH_MIN_M := 15.0             # a full layer lies this deep over the low ground, a new depth each night, up to ...
const MIST_DEPTH_MAX_M := 90.0             # ... this
const MIST_WET_HOURS := [3.0, 8.0, 14.0]   # recent rain: the rain this many game hours ago counts as moisture
const MIST_WET_GAIN := 0.6                 # moisture from recent rain adds up to this share to a cooling night's fog
const MIST_DAMP_BASE := 0.35               # the air's own moisture without recent rain (autumn adds to it)
const RAIN_FOG := 0.45                     # fog in light, steady rain reaches at most this strength
const RAIN_FOG_PRECIP := [0.05, 0.25, 0.6] # rain from, full at, gone by (heavy rain washes the air instead)
const RAIN_FOG_COOL_C := [7.0, 14.0]       # full in air at or below 7 C, none from 14 C
const STEAM_WARMER_C := [3.0, 8.0]         # steam fog: the water warmer than the air by this, from .. full
const STEAM_WIND := 0.4                    # none at or above this wind
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
# The sun path of day_cycle.gd (AXIAL_TILT_DEG): the burn-off follows the real sunrise. Keep the two the same.
# One sky (docs/design/one_sky_design.md; the only sky since Dave's 8 Nov ruling): the latitude of the tile row (Climate.latitude_of_row)
# and the starter calendar's declination, calendar_sign() x 23.44 sin(2 pi phase), as day_cycle.gd draws them.
const SUN_TILT_DEG := 23.44

# The year's phase, 0..1: spring starts at 0, high summer is about 0.375, winter's middle 0.875.
static func year_phase(game_s: float) -> float:
	var days: float = float(GameClockScript.DAYS_PER_YEAR)
	return fposmod(game_s / GameClockScript.SECONDS_PER_DAY, days) / days


static func season_of(game_s: float) -> String:
	return GameClockScript.SEASON_NAMES[int(year_phase(game_s) * 4.0) % 4]


# The year phase of a tile row (Climate.local_year_phase): half a year on across the equator from the starter island, whose
# calendar the game clock keeps. On the starter's side of the equator: year_phase. STARTER_ROW is Climate.STARTER_ROW.
const STARTER_ROW := 4


static func year_phase_at(game_s: float, row: int = STARTER_ROW, equator_row: int = 0) -> float:
	var phase: float = year_phase(game_s)
	return Climate.local_year_phase(phase, row, equator_row)


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
# `row`, `equator_row`: the tile row, for its own seasons (half a year off across the equator) and the fog's sunrise at its
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
	# The fog's air is the low ground's (sea level), not the caller's altitude: one fog for the zone row, the same on server and client.
	var low_temp: float = air_c(game_s, group, 0.0, seed_value, row, equator_row)
	var low_snowing: bool = low_temp + Climate.snow_bias_c(Climate.of_zone(group)) < 0.5
	var low_air: float = low_temp - RAIN_COOL_C * (0.0 if low_snowing else precip)
	var mist: float = _mist(seed_value, game_s, group, phase, hour, wind, front, precip, spirit, latitude_deg, need, low_air)
	var sea_fog: float = _sea_fog(seed_value, game_s, group, phase, wind, front, precip)
	var sea_fog_land: float = sea_fog * _land_keeps_sea_fog(year_phase(game_s), hour, latitude_deg)   # the calendar's phase: the sunrise takes the hemisphere from the latitude

	return {
		"rain": 0.0 if snowing else precip,
		"snow": precip if snowing else 0.0,
		"storm": storm,
		"cloud": cloud,
		"sun": clampf(1.0 - cloud * 1.1, 0.0, 1.0),
		"wind": wind,
		"wind_dir": _wind_heading(seed_value, game_s, group) + 0.8 * storm * (_noise(seed_value, 5, game_s / (2.0 * 3600.0)) - 0.5),
		"wind_squall": front_squall(seed_value, game_s, group),
		"temp_c": temp - RAIN_COOL_C * (0.0 if snowing else precip),
		"season": GameClockScript.SEASON_NAMES[int(phase * 4.0) % 4],
		"mist": mist,
		"mist_depth_m": mist_depth_m(seed_value, game_s, mist),
		"water_steam": water_steam(low_air, group, wind, precip),
		"sea_fog": sea_fog,
		"sea_fog_land": sea_fog_land,
		"sea_fog_top_m": sea_fog_top_m(seed_value, game_s, sea_fog),
	}


# Visibility V (m) at a height, from a weather state: the rule the client's look drew its fog by until 14 Nov 2026 (Kathleen #724);
# the look now follows Dave's fog instruction (fog_look.gd, about 50 m in full fog) and the animals move to it in the third fog PR
# (docs/design/FOG_PLAN.md). So the server (animals in fog, docs/design/animals_in_fog_server.md) and the client agree on one V. Koschmieder with a
# 5 % threshold: V = 3 / extinction, the extinction the clear haze VIS_HAZE_DENSITY times 1 + 5 rain + 4 snow + 3 storm + VIS_MIST_THICK
# x how deep the point is in the valley fog (eased over VIS_MIST_EDGE_M across mist_depth_m above sea level until the third fog PR), at most VIS_THICK_MAX times. Clear air about
# 3.3 km, full valley fog about 220 m, the thickest about 170 m (Jamie #716: recognise at half V, detail at a quarter). No caves or water.
const VIS_HAZE_DENSITY := 0.0009      # = LookSettings.FOG_DENSITY (client)
const VIS_MIST_THICK := 14.0          # = WeatherLook.MIST_INSIDE_THICK
const VIS_MIST_EDGE_M := 6.0          # = WeatherLook.MIST_EDGE_M
const VIS_THICK_MAX := 20.0           # = the look's cap on the fog multiple


static func visibility_m(weather_state: Dictionary, height_m: float) -> float:
	var mist: float = clampf(float(weather_state.get("mist", 0.0)), 0.0, 1.0)
	var inside: float = mist * smoothstep(-VIS_MIST_EDGE_M, VIS_MIST_EDGE_M, float(weather_state.get("mist_depth_m", 0.0)) - height_m)
	var thick: float = 1.0 + 5.0 * float(weather_state.get("rain", 0.0)) + 4.0 * float(weather_state.get("snow", 0.0)) + 3.0 * float(weather_state.get("storm", 0.0)) + VIS_MIST_THICK * inside
	return 3.0 / (VIS_HAZE_DENSITY * minf(thick, VIS_THICK_MAX))


# Hour of sunrise (sun centre on the horizon) on a day of the year, for the sun path day_cycle.gd draws (`latitude_deg`: the tile
# row's; NAN takes the starter row's).
static func sunrise_hour(day_of_year: float, latitude_deg: float = NAN) -> float:
	var sky_lat: float = Climate.latitude_of_row(Climate.STARTER_ROW) if is_nan(latitude_deg) else latitude_deg
	var phi: float = deg_to_rad(sky_lat)
	var delta: float = Climate.calendar_sign() * deg_to_rad(SUN_TILT_DEG) * sin(TAU * day_of_year / float(GameClockScript.DAYS_PER_YEAR))
	var half_day_h: float = rad_to_deg(acos(clampf(-tan(phi) * tan(delta), -1.0, 1.0))) / 15.0
	return 12.0 - half_day_h


# Land fog strength, 0..1 (see the MIST_ and RAIN_FOG_ constants): the stronger of the radiation fog of a calm, clear night (made
# likelier and thicker by recent rain) and the thin fog of light, cool rain. A different night each time; strongest in autumn.
# `need`: the front noise above which rain falls (state()), so the rain of the last hours can be read back from the same noise.
static func _mist(seed_value: int, game_s: float, group: String, phase: float, hour: float, wind: float, front: float, precip: float, spirit: float, latitude_deg: float, need: float, temp_c: float) -> float:
	var day_of_year: float = year_phase(game_s) * float(GameClockScript.DAYS_PER_YEAR)   # the calendar's day: sunrise_hour takes the hemisphere from the latitude
	var sunrise: float = sunrise_hour(day_of_year, latitude_deg)
	var gather_from: float = 24.0 - sunrise + MIST_FROM_SUNSET_H              # sunset is as far after noon as sunrise is before it
	var since: float = fposmod(hour - gather_from, 24.0)                      # hours since the fog could start to gather
	var dawn_since: float = fposmod(sunrise - gather_from, 24.0)
	var calm: float = 1.0 - smoothstep(MIST_CALM_WIND, MIST_WINDY, wind)
	var zone: float = float(MIST_BY_ZONE.get(group, MIST_BY_ZONE["temperate"]))
	var spirit_gain: float = 1.0 + 0.5 * maxf(spirit, 0.0)                   # high spirit: clear mornings with valley mist
	# Moisture: the air's own (more in autumn) and the rain of the last hours (the same front noise state() rains from).
	var autumn: float = 0.55 + 0.45 * cos(TAU * (phase - 0.625))              # 1 in mid autumn, 0.1 in mid spring
	var wet_before: float = 0.0

	for hours in MIST_WET_HOURS:
		var past_front: float = _noise(seed_value, 1, (game_s - float(hours) * 3600.0) / (FRONT_HOURS * 3600.0))
		wet_before = maxf(wet_before, smoothstep(need, need + 0.3, past_front))

	var damp: float = clampf(MIST_DAMP_BASE + 0.35 * autumn + MIST_WET_GAIN * wet_before, 0.0, 1.0)
	# Radiation fog: the night's cooling, then a burn-off that takes longer in damp air.
	var burn_h: float = lerpf(float(MIST_BURN_H[0]), float(MIST_BURN_H[1]), damp)
	var burn_from: float = dawn_since + MIST_BURN_FROM_H
	var timing: float = smoothstep(0.0, MIST_GATHER_H, since) * (1.0 - smoothstep(burn_from, burn_from + burn_h, since))
	var clear: float = 1.0 - smoothstep(MIST_CLEAR_FRONT, MIST_CLOUDY_FRONT, front)
	var dry: float = 1.0 - smoothstep(0.02, 0.1, precip)
	var night: float = smoothstep(0.25, 0.75, _noise(seed_value, 6, game_s / GameClockScript.SECONDS_PER_DAY))   # some nights none
	var radiation: float = timing * calm * clear * dry * autumn * night * lerpf(0.7, 1.3, damp)
	# Fog in rain: light, steady rain in cool, quiet air, at any hour; heavy rain washes the air instead.
	var light_rain: float = smoothstep(float(RAIN_FOG_PRECIP[0]), float(RAIN_FOG_PRECIP[1]), precip) * (1.0 - smoothstep(float(RAIN_FOG_PRECIP[1]), float(RAIN_FOG_PRECIP[2]), precip))
	var cool: float = 1.0 - smoothstep(float(RAIN_FOG_COOL_C[0]), float(RAIN_FOG_COOL_C[1]), temp_c)
	var in_rain: float = RAIN_FOG * light_rain * cool * calm * smoothstep(0.2, 0.7, _noise(seed_value, 12, game_s / (FRONT_HOURS * 3600.0)))   # not every shower
	return clampf(maxf(radiation, in_rain) * zone * spirit_gain, 0.0, 1.0)


# Steam fog over rivers and lakes, 0..1: air much colder than the water (the water keeps near the year's mean warmth), in calm air,
# at any hour; heavy rain or snow ends it. The client draws it as low wisps over the water (fog_ground.gd).
static func water_steam(temp_c: float, group: String, wind: float, precip: float) -> float:
	var warmer: float = maxf(year_mean_c(group), 0.0) - temp_c      # water never colder than freezing (a frozen river raises no steam: ice)
	var calm: float = 1.0 - smoothstep(STEAM_WIND * 0.6, STEAM_WIND, wind)
	return clampf(smoothstep(float(STEAM_WARMER_C[0]), float(STEAM_WARMER_C[1]), warmer) * calm * (1.0 - smoothstep(0.2, 0.5, precip)), 0.0, 1.0)


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


# Depth of the land fog over the local low ground (m): a new depth each night between MIST_DEPTH_MIN_M and MIST_DEPTH_MAX_M, shallower
# while the fog is thin (it sinks as it clears, and starts as shallow mist). 0 when there is none.
static func mist_depth_m(seed_value: int, game_s: float, mist: float) -> float:
	if mist <= 0.0:
		return 0.0

	var full: float = lerpf(MIST_DEPTH_MIN_M, MIST_DEPTH_MAX_M, _noise(seed_value, 7, game_s / GameClockScript.SECONDS_PER_DAY))
	return full * (0.3 + 0.7 * mist)


# The heading the wind blows TOWARD (radians, as wind_dir) before the storm's swing.
static func _wind_heading(seed_value: int, game_s: float, group: String) -> float:
	# Not wrapped: the bearing never jumps, so neither does the heading (from bearing B the wind blows toward B + 180, at B + 90 rad).
	return deg_to_rad(_from_deg_unwrapped(seed_value, game_s, group) + 90.0)


# The compass bearing (degrees, 0 north, 90 east) the wind comes FROM, before the storm's swing.
static func prevailing_from_deg(seed_value: int, game_s: float, group: String) -> float:
	return fposmod(_from_deg_unwrapped(seed_value, game_s, group), 360.0)


static func _from_deg_unwrapped(seed_value: int, game_s: float, group: String) -> float:
	var zone: Dictionary = WIND_BY_ZONE.get(group, WIND_BY_ZONE["temperate"])
	var wander: float = float(zone["spread_deg"]) * (2.0 * _noise(seed_value, 4, game_s / (WIND_WANDER_H * 3600.0)) - 1.0)
	var west: float = westerly_spell(seed_value, game_s, group)
	var mean: float = float(zone["from_deg"])

	if bool(zone.get("seasons", false)):
		mean = lerpf(WIND_EAST_FROM_DEG, WIND_WEST_FROM_DEG, west)       # unwrapped, so a change of spell swings through the south
	else:
		mean += float(zone["reversal_deg"]) * smoothstep(WIND_REVERSAL_FROM, WIND_REVERSAL_FULL, _noise(seed_value, WIND_REVERSAL_STREAM, game_s / (3.0 * GameClockScript.SECONDS_PER_DAY)))

	return mean + wander + front_turn_deg(seed_value, game_s, group)


# The westerlies' share of the wind now, 0 (a south-easter spell) .. 1 (the westerlies), for a zone with seasons; 1 otherwise.
static func westerly_spell(seed_value: int, game_s: float, group: String) -> float:
	if not bool(WIND_BY_ZONE.get(group, WIND_BY_ZONE["temperate"]).get("seasons", false)):
		return 1.0

	var step: float = WIND_SPELL_H * 3600.0
	var i: int = int(floor(game_s / step))
	var frac: float = game_s / step - float(i)
	return lerpf(_spell_is_west(seed_value, i - 1), _spell_is_west(seed_value, i), smoothstep(0.0, WIND_SPELL_TURN_H * 3600.0 / step, frac))


static func _spell_is_west(seed_value: int, i: int) -> float:
	var phase: float = fposmod(float(i) * WIND_SPELL_H * 3600.0 / GameClockScript.SECONDS_PER_DAY, float(GameClockScript.DAYS_PER_YEAR)) / float(GameClockScript.DAYS_PER_YEAR)
	return 1.0 if _hash(seed_value, WIND_SPELL_STREAM, i) < west_share_of_month(phase) else 0.0


# WIND_WEST_BY_MONTH at a point of the year (0..1 from the spring equinox), read linearly between the twelve month centres.
static func west_share_of_month(phase: float) -> float:
	var x: float = fposmod(phase, 1.0) * 12.0 - 0.5
	var k: int = int(floor(x))
	var f: float = x - float(k)
	return lerpf(float(WIND_WEST_BY_MONTH[posmod(k, 12)]), float(WIND_WEST_BY_MONTH[posmod(k + 1, 12)]), f)


# How far a front turns the wind (degrees, + clockwise = veering): ahead of a front, while its noise is rising, the wind veers
# by up to veer_deg in the south (backs in the north); once it has peaked and falls, it backs by up to back_deg (veers in the
# north). The trend is the front's strength now against WIND_FRONT_LAG_H ago, so the turn round comes a few hours after the
# heaviest rain, as the cold front's change does. A south-easter spell takes only WIND_EAST_FRONT of it.
static func front_turn_deg(seed_value: int, game_s: float, group: String) -> float:
	var zone: Dictionary = WIND_BY_ZONE.get(group, WIND_BY_ZONE["temperate"])
	var now: float = _noise(seed_value, 1, game_s / (FRONT_HOURS * 3600.0))
	var before: float = _noise(seed_value, 1, (game_s - WIND_FRONT_LAG_H * 3600.0) / (FRONT_HOURS * 3600.0))
	var strength: float = smoothstep(WIND_FRONT_FROM, WIND_FRONT_FULL, maxf(now, before))
	var trend: float = clampf((now - before) / WIND_FRONT_SHARP, -1.0, 1.0)
	var turn: float = float(zone["veer_deg"]) * trend if trend > 0.0 else float(zone["back_deg"]) * trend
	var spell: float = lerpf(WIND_EAST_FRONT, 1.0, westerly_spell(seed_value, game_s, group))
	return strength * turn * spell * (1.0 if bool(zone["south"]) else -1.0)


# The cold front's squall, 0..1: how sharply the wind is backing behind a front now (the gust factor rises with it, local_wind).
static func front_squall(seed_value: int, game_s: float, group: String) -> float:
	var zone: Dictionary = WIND_BY_ZONE.get(group, WIND_BY_ZONE["temperate"])
	var turn: float = front_turn_deg(seed_value, game_s, group) * (1.0 if bool(zone["south"]) else -1.0)
	return clampf(-turn / maxf(float(zone["back_deg"]), 1.0), 0.0, 1.0)


# A compass bearing (degrees, 0 north, 90 east; north is -z, east +x) as a wind_dir angle on (x, z), and back.
static func heading_of_bearing(bearing_deg: float) -> float:
	return fposmod(deg_to_rad(bearing_deg - 90.0), TAU)


static func bearing_of_heading(heading: float) -> float:
	return fposmod(rad_to_deg(heading) + 90.0, 360.0)


static func wind_mps(wind: float) -> float:
	return WIND_MPS_AT_1 * pow(clampf(wind, 0.0, 1.0), WIND_MPS_POWER)


static func wind_of_mps(mps: float) -> float:
	return clampf(pow(maxf(mps, 0.0) / WIND_MPS_AT_1, 1.0 / WIND_MPS_POWER), 0.0, 1.0)


# The wind where someone stands (docs/design/prevailing_wind.md section 3): the world's wind made weaker and gustier inland,
# weaker again in a crest's lee or under trees, plus a slope breeze and a sea or land breeze on light-wind clear days and nights.
# Pure; the caller measures `here`:
#   "downhill": Vector2 on (x, z), the way the ground falls (ZERO on the flat); "grade": rise over run there
#   "sea_upwind": 0..1, how much of the ground upwind is open sea; "lee": 0..1, sheltered by a steep crest upwind
#   "sea_way": Vector2 on (x, z) toward the nearest sea, length 0..1 for how much of the ground near by is sea; "canopy": 0..1
# Returns a copy of `w` with "wind" and "wind_dir" changed, plus "wind_mps", "wind_gust" (gust over mean), "wind_gust_mps", "wind_slope_mps"
# (+ down-slope, - up-slope), "wind_sea_mps" (+ onshore, - offshore) and "wind_base_dir" (the world's heading).
static func local_wind(w: Dictionary, here: Dictionary, game_s: float) -> Dictionary:
	var out: Dictionary = w.duplicate()
	var sea: float = clampf(float(here.get("sea_upwind", 0.0)), 0.0, 1.0)
	var base_dir: float = float(w.get("wind_dir", 0.0))
	var base_mps: float = wind_mps(float(w.get("wind", 0.0)))
	var cloud: float = float(w.get("cloud", 0.0))
	var sun: float = float(w.get("sun", 1.0))
	var shelter: float = lerpf(1.0, WIND_LEE_KEEP, clampf(float(here.get("lee", 0.0)), 0.0, 1.0))
	shelter *= lerpf(1.0, WIND_CANOPY_KEEP, clampf(float(here.get("canopy", 0.0)), 0.0, 1.0))
	var flow: Vector2 = Vector2.from_angle(base_dir) * base_mps * lerpf(WIND_INLAND_SPEED, 1.0, sea)
	var downhill: Vector2 = here.get("downhill", Vector2.ZERO)
	var sea_way: Vector2 = here.get("sea_way", Vector2.ZERO)
	var slope: float = slope_breeze_mps(float(here.get("grade", 0.0)), game_s, base_mps, cloud, sun) if downhill.length() > 0.01 else 0.0
	var onshore: float = sea_breeze_mps(minf(sea_way.length(), 1.0), game_s, base_mps, cloud, sun) if sea_way.length() > 0.01 else 0.0

	if slope != 0.0:
		flow += downhill.normalized() * slope

	if onshore != 0.0:
		flow -= sea_way.normalized() * onshore

	flow *= shelter
	out["wind_base_dir"] = base_dir
	out["wind_slope_mps"] = slope
	out["wind_sea_mps"] = onshore
	out["wind_mps"] = flow.length()
	out["wind"] = wind_of_mps(flow.length())
	out["wind_dir"] = base_dir + angle_difference(base_dir, flow.angle()) if flow.length() > 0.05 else base_dir   # kept near the world's heading, no jump
	var gust: float = lerpf(WIND_GUST_INLAND, WIND_GUST_COAST, sea)
	gust = lerpf(gust, WIND_GUST_SQUALL, clampf(float(w.get("wind_squall", 0.0)), 0.0, 1.0))
	gust = lerpf(gust, WIND_GUST_CANOPY, clampf(maxf(float(here.get("canopy", 0.0)), float(here.get("lee", 0.0))), 0.0, 1.0))
	out["wind_gust"] = gust
	out["wind_gust_mps"] = flow.length() * gust                                      # not capped at 20 m/s
	return out


# The night-flow share 0..1 (katabatic and land breezes): builds from half an hour before sunset to full 1.5 h after, holds
# through the night and dies 0.5 to 2 h after sunrise. `rise` is the sunrise hour; sunset is 24 - rise.
static func _night_flow(hour: float, rise: float) -> float:
	var start: float = 24.0 - rise + KATABATIC_FROM_SUNSET_H[0]
	var t: float = fposmod(hour - start, 24.0)                                # hours since it started building
	var to_rise: float = fposmod(rise - start, 24.0)                          # sunrise, in the same hours

	if t >= to_rise + KATABATIC_TO_SUNRISE_H[1]:
		return 0.0

	var build: float = smoothstep(0.0, KATABATIC_FROM_SUNSET_H[1] - KATABATIC_FROM_SUNSET_H[0], t)
	return build * (1.0 - smoothstep(KATABATIC_TO_SUNRISE_H[0], KATABATIC_TO_SUNRISE_H[1], t - to_rise))


# The slope breeze (m/s): + down the slope (katabatic: clear nights), - up it (anabatic: sunny days from mid-morning). Only on
# light-wind days: full under 2 m/s of the world's wind, gone at 6. 0 on gentle ground (grade under 0.05).
static func slope_breeze_mps(grade: float, game_s: float, base_mps: float, cloud: float, sun: float) -> float:
	var steep: float = smoothstep(SLOPE_GRADE[0], SLOPE_GRADE[1], grade)

	if steep <= 0.0:
		return 0.0

	var calm: float = 1.0 - smoothstep(SLOPE_CALM_MPS[0], SLOPE_CALM_MPS[1], base_mps)
	var hour: float = hour_of(game_s)
	var rise: float = sunrise_hour(year_phase(game_s) * float(GameClockScript.DAYS_PER_YEAR))
	var day: float = smoothstep(ANABATIC_FROM_SUNRISE_H[0], ANABATIC_FROM_SUNRISE_H[1], hour - rise) * smoothstep(ANABATIC_TO_SUNSET_H[1], ANABATIC_TO_SUNSET_H[0], 24.0 - rise - hour)
	var clear: float = 1.0 - smoothstep(0.4, 0.8, cloud)
	var down: float = lerpf(KATABATIC_MPS[0], KATABATIC_MPS[1], steep) * _night_flow(hour, rise) * clear
	var up: float = lerpf(ANABATIC_MPS[0], ANABATIC_MPS[1], steep) * day * clampf(sun, 0.0, 1.0)
	return calm * (down - up)


# The sea or land breeze (m/s): + onshore on calm sunny days (stronger in summer), - offshore on clear calm nights. `near` is
# 0..1, how much of the ground near by is sea. None when the world's wind is over 4 m/s.
static func sea_breeze_mps(near: float, game_s: float, base_mps: float, cloud: float, sun: float) -> float:
	if near <= 0.0:
		return 0.0

	var calm: float = 1.0 - smoothstep(SEA_BREEZE_CALM_MPS[0], SEA_BREEZE_CALM_MPS[1], base_mps)
	var hour: float = hour_of(game_s)
	var rise: float = sunrise_hour(year_phase(game_s) * float(GameClockScript.DAYS_PER_YEAR))
	var set_h: float = 24.0 - rise
	var summer: float = 0.5 + 0.5 * cos(TAU * (year_phase(game_s) - 0.375))
	var day: float = smoothstep(SEA_BREEZE_HOURS[0], SEA_BREEZE_HOURS[1], hour) * (1.0 - smoothstep(set_h - 2.0, set_h, hour))
	var onshore: float = lerpf(SEA_BREEZE_MPS[0], SEA_BREEZE_MPS[1], summer) * day * clampf(sun, 0.0, 1.0)
	var offshore: float = LAND_BREEZE_MPS * _night_flow(hour, rise) * (1.0 - smoothstep(0.4, 0.8, cloud))
	return calm * near * (onshore - offshore)


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
