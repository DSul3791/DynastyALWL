extends RefCounted

# Distance haze tied to the air (docs/design/art_weather_light.md 7.2). Off unless the client is started with --haze, until
# Dino's picture. Haze is tiny particles that swell with water as the air grows humid, and warm air carries far more water
# than cold: cold dry air is crisp and blue, warm humid air milky and white. Rain washes the air clear for about an hour after
# it stops; later the wet land steams and the haze comes back. This sets only the clear-air base: rain, snow, storm and the fog
# test kind still thicken the haze on top of it (weather_look.gd). Client only; the weather it reads is the same for everyone.

const EASE_S := 60.0                  # the haze follows the air over about this long
const WASH_H := 1.0                   # game hours of washed-clear air after rain
const WASH := 0.6                     # haze left in that hour
const DRY_TINT := Color(0.50, 0.64, 0.86)      # far land in crisp dry air: a deeper blue
const HUMID_TINT := Color(0.80, 0.82, 0.84)    # in humid air: pale grey-white
const GameClock := preload("res://src/shared/game_clock.gd")

var on: bool = false
var density_scale: float = 1.0        # x the clear-air haze (for checks)
var humid: float = 0.4                # 0 dry .. 1 humid, eased (for checks)
var _since_rain_h: float = 99.0       # game hours since rain last fell


func setup() -> void:
	on = OS.get_cmdline_user_args().has("--haze")


# Every frame from weather_look.gd: the air temperature, cloud, rain and mist now, and the ground's wetness (recent rain).
func update(delta: float, air_c: float, cloud: float, rain: float, mist: float, ground_wet: float) -> void:
	if not on:
		return

	_since_rain_h = 0.0 if rain > 0.1 else _since_rain_h + delta * GameClock.RATIO / 3600.0
	var moist: float = clampf(0.25 + 0.3 * cloud + 0.35 * ground_wet + 0.3 * mist, 0.0, 1.0)
	var warm: float = smoothstep(-5.0, 25.0, air_c)
	# The water the air carries: humid only when it is both damp and warm.
	var want_humid: float = clampf(moist * lerpf(0.35, 1.25, warm), 0.0, 1.0)
	var want: float = lerpf(0.6, 1.8, want_humid) / lerpf(0.6, 1.8, 0.4)     # 1.0 at an ordinary mild day (humid 0.4)
	want = clampf(want, 0.5, 2.0)

	if rain <= 0.1 and _since_rain_h < WASH_H:
		want *= lerpf(WASH, 1.0, smoothstep(0.6, 1.0, _since_rain_h / WASH_H))

	density_scale = move_toward(density_scale, want, delta / EASE_S)
	humid = move_toward(humid, want_humid, delta / EASE_S)


# The haze colour: the sky's horizon colour, pulled toward blue in dry air and white in humid air.
func tint(sky_horizon: Color) -> Color:
	if not on:
		return sky_horizon

	var toward: Color = DRY_TINT.lerp(HUMID_TINT, smoothstep(0.25, 0.75, humid))
	return sky_horizon.lerp(toward * maxf(sky_horizon.get_luminance(), 0.05) / maxf(toward.get_luminance(), 0.05), 0.35)


# How much of the sky colour behind the haze shows through it (Environment.fog_aerial_perspective): less in humid air.
func aerial(base: float) -> float:
	return base if not on else lerpf(base, 0.5, smoothstep(0.4, 0.9, humid))
