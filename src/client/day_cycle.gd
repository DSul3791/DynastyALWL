extends RefCounted
# The sun, the moon and the sky colours follow the game clock (Art direction job 6a, DESIGN_IDEAS 7.5): sunrise and
# sunset, long golden dusk and dawn, a blue moon and stars at night, never pitch black. Client only, no network traffic:
# `update(hour, day_of_year, days)` from the shared game clock (a game day is one real hour). weather_look.gd applies the
# numbers (it already owns the sun, ambient light, fog and sky uniforms and multiplies them by the weather).
#
# The sun path is the real one for the island's own latitude (below): it rises in the east, stands in the north at noon at the
# southern starter (north is -Z) and sets in the west; the noon sun is high in summer and low in winter, so days are long in summer
# and short in winter. The moon stands where its phase puts it on the ecliptic and lights the ground with one cold, dim directional
# light whose strength follows the moon's phase (below). There is one light
# (and one shadow map) in the game, so at night the same light is the moon; both are faded to nothing while the sun
# crosses the horizon, and the light snaps from sun to moon in that gap.
#
# Moon phases (docs/design/art_weather_light.md 5.3 and 12, decided 8 Nov 2026): the moon waxes and wanes over its real
# synodic month, so a few nights a month are moonless "eye nights", when a torch matters most and eyes shine at the edge of
# its light. Only the moonlight follows the phase: the night's ambient light and its floor are weather_look.gd's, so a
# moonless night is never darker than the outdoor floor (never pitch black outdoors, the decided rule). A new world starts on a
# full moon, the night it always had.
# Cost: a few trig calls twice a second and a handful of uniforms per frame; no extra light, no extra draw.

const AXIAL_TILT_DEG := 23.44
const Climate := preload("res://src/shared/climate.gd")

# One sky (docs/design/one_sky_design.md; Sonny's A4 "One sky", 8 Nov 2026; the only sky since Dave's 8 Nov ruling): the sky at the latitude of the player's tile row on the
# 21 x 21 world grid (Climate.latitude_of_row: the equator row 0, south negative; the starter row 4 is 57 S with the placeholder
# spread). The game calendar is the starter island's: day 0 its spring equinox, so the sun's
# declination is calendar_sign() x 23.44 sin(2 pi phase) (-1 for the southern starter) and midsummer stays at phase 0.25. At 57 S the noon sun stands
# due north (-Z) and shadows point south (+Z). The moon sits 360 x phase east of the sun along the ecliptic, so a
# full moon rides low in midsummer and high in midwinter.
static var sky_row_latitude: float = NAN         # the player's tile row's latitude, set by terrain_client; NAN: the starter row's

const SUN_WHITE := Color(1.0, 0.92, 0.80)       # the daytime colour (look_settings SUN_COLOR)
const SUN_GOLD := Color(1.0, 0.66, 0.36)        # low sun
const SUN_RED := Color(1.0, 0.42, 0.2)          # sun on the horizon
const MOON_COLOR := Color(0.62, 0.72, 1.0)
const MOON_ENERGY := 0.22                       # share of the daytime sun light energy the moon gives (a full moon)
const AMBIENT_NIGHT := 0.24                     # share of the daytime ambient light left at night
const SYNODIC_DAYS := 29.53                     # new moon to new moon, in game days
const MOON_FULL_DAY := 100.0                    # a full moon on this game day (a new world starts on day 100, game_clock START_SECONDS)
# Moon phases (Jamie's moonlight page #679, Kathleen 8 Nov 2026): the moonlight follows the standard phase formula (Allen: a quarter moon
# gives 8 to 9 % of a full moon's light, not 35 %), and the moon stands where its phase puts it: the sun's place turned back by phase x 360
# degrees on the same path. A new moon is up with the sun, a first quarter sets about midnight, a full moon is up all night, a last
# quarter rises about midnight; no moonlight while the moon is below the horizon.
var moon_elevation: float = -1.0                # sin of the moon's height
const STARS_DARK := 1.35                        # the stars on a moonless night, against a full moon's (1, as before): a bright moon washes out the faint ones

# Sky palettes: top, horizon, below the horizon, cloud shadow.
const DAY := [Color(0.33, 0.47, 0.68), Color(0.63, 0.68, 0.75), Color(0.63, 0.68, 0.75), Color(0.46, 0.52, 0.62)]
const DUSK := [Color(0.27, 0.32, 0.55), Color(0.92, 0.58, 0.42), Color(0.7, 0.45, 0.35), Color(0.45, 0.36, 0.45)]
const NIGHT := [Color(0.015, 0.025, 0.06), Color(0.05, 0.07, 0.13), Color(0.04, 0.05, 0.09), Color(0.02, 0.03, 0.06)]

var elevation: float = 0.5                      # sin of the sun's height above the horizon (negative: below it)
var light_basis: Basis = Basis.IDENTITY         # for the directional light: the sun by day, the moon by night
var light_color: Color = SUN_WHITE
var light_factor: float = 1.0                   # multiplies the daytime sun energy (look_settings SUN_ENERGY)
var ambient_factor: float = 1.0                 # multiplies the sky's ambient light
var night: float = 0.0                          # 0 day .. 1 night
var moon_phase: float = 0.5                     # 0 new .. 0.5 full .. 1 new again
var moon_light: float = 1.0                     # 0 new moon .. 1 full moon: multiplies the moonlight
var stars: float = 0.0                          # how bright the stars are (the sky shader's `night`): night, brighter when the moon is dark
var sky_top: Color = DAY[0]
var sky_horizon: Color = DAY[1]
var ground_horizon: Color = DAY[2]
var cloud_shadow: Color = DAY[3]


# `days`: game days since the world began (game_clock seconds / SECONDS_PER_DAY), for the moon's phase; below 0 keeps a full moon.
func update(hour: float, day_of_year: int, days: float = -1.0) -> void:
	moon_phase = moon_phase_at(days) if days >= 0.0 else 0.5
	moon_light = moon_light_phase(moon_phase)

	var phi: float = deg_to_rad(sky_latitude_deg())
	# Day 0 is the first day of spring (equinox): the sun's declination is zero, then follows the summer (sun_declination).
	var year_phase: float = (float(day_of_year) + hour / 24.0) / 365.0
	var delta: float = sun_declination(year_phase)
	var h: float = deg_to_rad((hour - 12.0) * 15.0)
	var sun_to: Vector3 = sky_direction(phi, delta, h)    # from the ground toward the sun
	var up: float = sun_to.y
	elevation = up

	var sun_up: float = smoothstep(-0.06, 0.02, up)
	var by_day: bool = up > -0.07
	var moon_to: Vector3 = moon_on_ecliptic(phi, year_phase, h, moon_phase)
	moon_elevation = moon_to.y
	moon_light *= smoothstep(0.0, 0.12, moon_to.y)        # none below the horizon; it brightens as it climbs
	var moon_up: float = smoothstep(-0.08, -0.02, -up)    # while the sun is down
	var toward: Vector3 = sun_to if by_day else (moon_to if moon_to.y > 0.0 else -sun_to)
	light_basis = Basis.looking_at(-toward, Vector3.UP if absf(toward.y) < 0.99 else Vector3.RIGHT)

	if by_day:
		var low: float = smoothstep(0.45, 0.1, up)      # 1 when the sun is low
		var horizon: float = smoothstep(0.1, 0.0, up)   # 1 on the horizon
		light_color = SUN_WHITE.lerp(SUN_GOLD, low).lerp(SUN_RED, horizon)
		light_factor = sun_up * (0.8 + 0.2 * smoothstep(0.0, 0.3, up))
	else:
		light_color = MOON_COLOR
		light_factor = MOON_ENERGY * moon_up * moon_light

	var day_w: float = smoothstep(0.0, 0.3, up)
	var night_w: float = smoothstep(0.0, -0.2, up)
	var dusk_w: float = clampf(1.0 - day_w - night_w, 0.0, 1.0)
	night = smoothstep(-0.03, -0.2, up)
	stars = night * lerpf(STARS_DARK, 1.0, moon_light)
	ambient_factor = lerpf(AMBIENT_NIGHT, 1.0, clampf(day_w + dusk_w * 0.55, 0.0, 1.0))
	sky_top = _mix(0, day_w, dusk_w, night_w)
	sky_horizon = _mix(1, day_w, dusk_w, night_w)
	ground_horizon = _mix(2, day_w, dusk_w, night_w)
	cloud_shadow = _mix(3, day_w, dusk_w, night_w)


# The moonlight by phase (Allen's formula; Jamie's two-line drop-in), 1 at full, about 0.09 at a quarter, 0 at new.
static func moon_light_phase(phase: float) -> float:
	var alpha: float = absf(fposmod(phase, 1.0) - 0.5) * 360.0       # phase angle in degrees, 0 at full .. 180 at new
	return pow(10.0, -0.4 * (0.026 * alpha + 4.0e-9 * pow(alpha, 4.0)))


# The sky's latitude in degrees, south negative: the player's tile row's (the starter row's until terrain_client sets it).
static func sky_latitude_deg() -> float:
	return Climate.latitude_of_row(Climate.STARTER_ROW) if is_nan(sky_row_latitude) else sky_row_latitude


# The sun's declination (radians) at a year phase: zero at the spring equinox (phase 0), and at phase 0.25 the summer's: -23.44 degrees
# for the starter island's southern summer (the sign of its row's hemisphere).
static func sun_declination(year_phase: float) -> float:
	return Climate.calendar_sign() * deg_to_rad(AXIAL_TILT_DEG) * sin(TAU * year_phase)


# From the ground toward a body in the sky (unit vector, north is -Z): latitude `phi`, declination `delta`, hour angle `h`, radians.
static func sky_direction(phi: float, delta: float, h: float) -> Vector3:
	var up: float = sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(h)
	var east: float = -cos(delta) * sin(h)
	var north: float = sin(delta) * cos(phi) - cos(delta) * sin(phi) * cos(h)
	return Vector3(east, up, -north)


# The moon 360 x phase east of the sun along the ecliptic (its 5 degree orbit tilt left out; Sonny's A4).
# The sun's ecliptic longitude is 2 pi x year phase + pi (so its declination is sun_declination's), the moon's that plus 2 pi x moon
# phase; the moon's declination is 23.44 sin(longitude) and its hour angle the sun's less the difference in right ascension.
# `phi` latitude and `h` the sun's hour angle, radians.
static func moon_on_ecliptic(phi: float, year_phase: float, h: float, phase: float) -> Vector3:
	var tilt: float = deg_to_rad(AXIAL_TILT_DEG)
	var sun_lon: float = TAU * year_phase + (PI if Climate.calendar_sign() < 0.0 else 0.0)   # the calendar's spring is the south's (autumn point) or the north's
	var moon_lon: float = sun_lon + TAU * phase
	var moon_delta: float = tilt * sin(moon_lon)
	var moon_h: float = h - (_right_ascension(moon_lon, tilt) - _right_ascension(sun_lon, tilt))
	return sky_direction(phi, moon_delta, moon_h)


static func _right_ascension(longitude: float, tilt: float) -> float:
	return atan2(cos(tilt) * sin(longitude), cos(longitude))


# The moon's phase on a game day: 0 new, 0.5 full (on MOON_FULL_DAY and every SYNODIC_DAYS after it), 1 new again.
static func moon_phase_at(days: float) -> float:
	return fposmod((days - MOON_FULL_DAY) / SYNODIC_DAYS + 0.5, 1.0)


func _mix(slot: int, day_w: float, dusk_w: float, night_w: float) -> Color:
	var total: float = maxf(day_w + dusk_w + night_w, 0.0001)
	var c: Color = (DAY[slot] as Color) * day_w + (DUSK[slot] as Color) * dusk_w + (NIGHT[slot] as Color) * night_w
	return Color(c.r / total, c.g / total, c.b / total, 1.0)
