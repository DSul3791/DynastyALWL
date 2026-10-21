extends RefCounted
# The sun, the moon and the sky colours follow the game clock (Art direction job 6a, DESIGN_IDEAS 7.5): sunrise and
# sunset, long golden dusk and dawn, a blue moon and stars at night, never pitch black. Client only, no network traffic:
# `update(hour, day_of_year)` from the shared game clock (a game day is one real hour). weather_look.gd applies the
# numbers (it already owns the sun, ambient light, fog and sky uniforms and multiplies them by the weather).
#
# The sun path is the real one for LATITUDE_DEG: it rises in the east, stands in the south at noon (north is -Z) and sets
# in the west; the noon sun is high in summer and low in winter, so days are long in summer and short in winter. The moon
# is always opposite the sun (a full moon) and lights the ground with one cold, dim directional light. There is one light
# (and one shadow map) in the game, so at night the same light is the moon; both are faded to nothing while the sun
# crosses the horizon, and the light snaps from sun to moon in that gap.
# Cost: a few trig calls twice a second and a handful of uniforms per frame; no extra light, no extra draw.

const LATITUDE_DEG := 52.0
const AXIAL_TILT_DEG := 23.44

const SUN_WHITE := Color(1.0, 0.92, 0.80)       # the daytime colour (look_settings SUN_COLOR)
const SUN_GOLD := Color(1.0, 0.66, 0.36)        # low sun
const SUN_RED := Color(1.0, 0.42, 0.2)          # sun on the horizon
const MOON_COLOR := Color(0.62, 0.72, 1.0)
const MOON_ENERGY := 0.22                       # share of the daytime sun light energy the moon gives (a full moon)
const AMBIENT_NIGHT := 0.24                     # share of the daytime ambient light left at night

# Sky palettes: top, horizon, below the horizon, cloud shadow.
const DAY := [Color(0.33, 0.47, 0.68), Color(0.63, 0.68, 0.75), Color(0.63, 0.68, 0.75), Color(0.46, 0.52, 0.62)]
const DUSK := [Color(0.27, 0.32, 0.55), Color(0.92, 0.58, 0.42), Color(0.7, 0.45, 0.35), Color(0.45, 0.36, 0.45)]
const NIGHT := [Color(0.015, 0.025, 0.06), Color(0.05, 0.07, 0.13), Color(0.04, 0.05, 0.09), Color(0.02, 0.03, 0.06)]

var elevation: float = 0.5                      # sin of the sun's height above the horizon (negative: below it)
var light_basis: Basis = Basis.IDENTITY         # for the directional light: the sun by day, the moon by night
var light_color: Color = SUN_WHITE
var light_factor: float = 1.0                   # multiplies the daytime sun energy (look_settings SUN_ENERGY)
var ambient_factor: float = 1.0                 # multiplies the sky's ambient light
var night: float = 0.0                          # 0 day .. 1 night: stars
var sky_top: Color = DAY[0]
var sky_horizon: Color = DAY[1]
var ground_horizon: Color = DAY[2]
var cloud_shadow: Color = DAY[3]


func update(hour: float, day_of_year: int) -> void:
	var phi: float = deg_to_rad(LATITUDE_DEG)
	# Day 0 is the first day of spring (equinox): the sun's declination is zero, peaks in summer.
	var delta: float = deg_to_rad(AXIAL_TILT_DEG) * sin(TAU * (float(day_of_year) + hour / 24.0) / 365.0)
	var h: float = deg_to_rad((hour - 12.0) * 15.0)
	var up: float = sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(h)
	var east: float = -cos(delta) * sin(h)
	var north: float = sin(delta) * cos(phi) - cos(delta) * sin(phi) * cos(h)
	var sun_to: Vector3 = Vector3(east, up, -north).normalized()    # from the ground toward the sun
	elevation = up

	var sun_up: float = smoothstep(-0.06, 0.02, up)
	var moon_up: float = smoothstep(-0.08, -0.02, -up) * smoothstep(0.0, 0.12, -up)
	var by_day: bool = up > -0.07
	var toward: Vector3 = sun_to if by_day else -sun_to
	light_basis = Basis.looking_at(-toward, Vector3.UP if absf(toward.y) < 0.99 else Vector3.RIGHT)

	if by_day:
		var low: float = smoothstep(0.45, 0.1, up)      # 1 when the sun is low
		var horizon: float = smoothstep(0.1, 0.0, up)   # 1 on the horizon
		light_color = SUN_WHITE.lerp(SUN_GOLD, low).lerp(SUN_RED, horizon)
		light_factor = sun_up * (0.8 + 0.2 * smoothstep(0.0, 0.3, up))
	else:
		light_color = MOON_COLOR
		light_factor = MOON_ENERGY * moon_up

	var day_w: float = smoothstep(0.0, 0.3, up)
	var night_w: float = smoothstep(0.0, -0.2, up)
	var dusk_w: float = clampf(1.0 - day_w - night_w, 0.0, 1.0)
	night = smoothstep(-0.03, -0.2, up)
	ambient_factor = lerpf(AMBIENT_NIGHT, 1.0, clampf(day_w + dusk_w * 0.55, 0.0, 1.0))
	sky_top = _mix(0, day_w, dusk_w, night_w)
	sky_horizon = _mix(1, day_w, dusk_w, night_w)
	ground_horizon = _mix(2, day_w, dusk_w, night_w)
	cloud_shadow = _mix(3, day_w, dusk_w, night_w)


func _mix(slot: int, day_w: float, dusk_w: float, night_w: float) -> Color:
	var total: float = maxf(day_w + dusk_w + night_w, 0.0001)
	var c: Color = (DAY[slot] as Color) * day_w + (DUSK[slot] as Color) * dusk_w + (NIGHT[slot] as Color) * night_w
	return Color(c.r / total, c.g / total, c.b / total, 1.0)
