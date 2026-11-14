extends Node

# The weather you can see (Art direction job 6b, owner rules 2026-10-20): rain needs clouds
# (never rain under a clear sky), bigger storms have darker clouds, the biggest storms have
# thick dark clouds and lightning. Client only, no network traffic: it reads the world weather
# the client already works out once a second (`terrain_client.weather`, from
# src/shared/weather.gd) and eases toward it, so a front rolls in over seconds.
#
# What it drives:
#  - the sky shader: cloud cover (`coverage`), `gloom` (clouds and sky turn dark grey) and
#    `flash` (lightning lights the clouds);
#  - the sun and the sky's ambient light, and the fog (thicker and greyer in rain and snow);
#  - valley fog from the weather's `mist` and `mist_top_m`: Godot's height fog below the layer's top, seen from above as
#    white low ground; from inside it, thick distance fog that hides the sky (docs/design/valley_fog.md);
#  - sea fog from `sea_fog`, `sea_fog_land` and `sea_fog_top_m` (docs/design/fog_pools_and_sea_fog.md): over the land as the same
#    layer, over the sea plane through the water shader's own fog, which also keeps the open sea clear under valley fog;
#  - the ground shader: `wet` (darker, glossier) and `snow` (level ground turns white),
#    read from the sound stage's ground memory so footsteps and looks agree; grass is
#    buried when snow lies;
#  - rain streaks and snowflakes (GPUParticles3D around the camera, count by quality);
#  - lightning: `flash_started(at_world, distance_m)` fires with the sound stage's strike
#    (`sound.weather.lightning`, so the flash and the thunder share one event); the sky
#    flashes, the ambient light jumps and, from Medium up, a jagged bolt is drawn from the
#    cloud base to the ground. Low gets the sky flash only. Strikes are cosmetic for now: a
#    strike that can start a fire or hurt someone needs a server position (DESIGN_IDEAS 4.2).
# The sound stage's weather test (Esc > Settings) drives the looks as well.
#
# Cost at Low: sky uniforms and a few environment values per frame, 500 rain streaks or 350
# flakes at most (amount_ratio follows the intensity), no turbulence, no bolt geometry.

const LookSettings := preload("res://src/client/look_settings.gd")
const SkyClouds := preload("res://src/client/sky_clouds.gd")
const CanopyMapScript := preload("res://src/client/canopy_map.gd")
const DayCycleScript := preload("res://src/client/day_cycle.gd")
const WaterMaterial := preload("res://src/client/water_material.gd")
const BuildingLook := preload("res://src/client/building_look.gd")

signal flash_started(at_world: Vector3, distance_m: float)

# Rain and storm darkening, the numbers to tweak (owner, 2026-10-20): how dark a full storm gets.
const RAIN_OVERCAST := 0.6               # cloud cover as soon as it rains (light rain), rising to 1 in heavy rain
const SUN_STORM := 0.05                  # share of the sun left under full cover
const AMBIENT_STORM_FLOOR := 1.1         # the same floor in a full storm: no moon shows through the cloud, the fill has to carry the night
const AMBIENT_NIGHT_COLOR := Color(0.24, 0.3, 0.44)   # the cold fill used on dark nights and storms
# Warm shade by day (Kathleen's proposal, art/CRITIQUES/starter_area_2026-11-03/SHADOW_TINT_PROPOSAL.md; Art_Direction.md: rich, warm colour): shade lit by
# the clear sky alone read blue-grey, so a quarter of the day's ambient is warm bounce from sunlit ground and leaves. It fades into the cold night fill.
const AMBIENT_DAY_WARM := Color(0.62, 0.56, 0.44)
const DAY_SKY_SHARE := 0.75              # share of the day's ambient from the sky (1 before: all sky)
const AMBIENT_FLOOR := 0.32             # ambient light never drops below this, so a storm night is not pure black
const AMBIENT_STORM := 0.4               # ambient light left in a full storm (1 clear)
# Night light (docs/design/art_weather_light.md 6.2 and 12, decided 8 Nov 2026). Never pitch black outdoors, a decided rule:
# in the open the ambient light never drops below OUTDOOR_FLOOR, whatever the moon, the weather, the tree crowns or a held
# torch do to it; only rock (caves and tunnels, `under_rock`) takes the light to nothing (#447).
const OUTDOOR_FLOOR := 0.18
# Under tree crowns at night the moon and the sky are blocked, so the forest is darker than the open by about half
# (the share of the crowns over the ground around the camera, from the canopy map, eased so walking between trees does not flicker).
const CANOPY_NIGHT_DIM := 0.45
const CANOPY_SAMPLE_M := 6.0             # the crowns are counted at the camera and at eight points this far round it
const CANOPY_EASE_S := 3.0
# A held torch or lantern at night: the eyes adapt to the flame, so the night beyond its light looks darker and eyes shine out of it.
# The design asks for a small exposure drop; it is done as a drop of the moon and sky light instead (the same picture
# beyond the flame), because the exposure would also dim the torch's own pool of light, which must stay as it is.
const TORCH_NIGHT_DIM := 0.15
const TORCH_ADAPT_S := 1.5               # the eyes take to the flame quickly
const TORCH_UNADAPT_S := 5.0             # and get used to the dark again slowly when it goes out
# Colour at night (art_weather_light.md 5.2): the eye loses colour in moonlight, so the picture keeps only part of its colour
# on a clear night, less when the moon is dark, on top of the weather's storm greying. A flame gives the colour back (warm
# against cold is the night's palette, 6.3): a burning torch or lantern in the hand, or a lit fire close by, returns most of it.
# Under rock there is no moonlight to grey, so caves keep their colour in torchlight. One saturation for the whole picture.
const NIGHT_COLOUR_FULL_MOON := 0.5      # share of the colour left on a clear full-moon night
const NIGHT_COLOUR_DARK := 0.4           # and on a moonless one
const FLAME_COLOUR_BACK := 0.8           # share of the lost colour a flame gives back
const FIRE_COLOUR_NEAR_M := 6.0          # a lit fire this close gives it all back
const FIRE_COLOUR_FAR_M := 14.0          # and none from this far (the biggest fire's light)
const FLAME_COLOUR_S := 1.5              # seconds to ease the colour in or out
# Rainbows on passing showers (art_weather_light.md 4): the sun up and under 42 degrees, rain within the last RAINBOW_HOLD_S,
# the sun breaking through (cloud cover clearing), not a storm. The bow itself is drawn by the sky shader (sky_clouds.gd).
const RAINBOW_HOLD_S := 90.0             # the rain is remembered this long (falling off evenly) after it stops
const RAINBOW_EASE_S := 4.0
const RAINBOW_SIN_MAX := 0.669           # sin 42 degrees: a higher sun puts the whole bow below the horizon
const CAVE_LIGHT_DARK := 0.0             # share of the sun and sky light left deep in a cave or tunnel, setting "Dark": none, pitch black without a torch or fire (Dave 5 Nov 2026)
const CAVE_LIGHT_NORMAL := 0.12          # the same, setting "Normal"
const CAVE_GO_DARK_S := 1.0              # the light fades out over this long on going in, and back over CAVE_COME_OUT_S
const CAVE_COME_OUT_S := 2.5             # (the eyes take longer to get used to the light again)
const CAVE_SHADOW_OFF := 0.05            # no sun shadows below this share of the light: nothing to cast
const CAVE_REFLECT_OFF := 0.3            # no sky reflections below this share of the light (the sky is not seen from in there)
const CAVE_DARK_FROM := 0.1              # rock enclosure (cave_sounds.gd) from which the light starts to fade
const CAVE_DARK_FULL := 0.6              # and at which it is fully gone
# Cave light (docs/design/cave_light_design.md, Jamie's cave page #664): daylight comes from the mouth, not from how enclosed the spot is.
# cave_sounds.gd measures how much of the view reaches open air (mouth_view) and how many bends lie between (bends). Mouth in view: the
# light is that share x CAVE_VIEW_GAIN; one bend: moonlight; two: none. The eyes: dark in a second going in, then over CAVE_ADAPT_IN_S a
# lift of up to CAVE_ADAPT_LIFT where some light exists (never above CAVE_ADAPT_CAP, so black stays black); coming out, the light is back at
# once and the still dark-adapted eyes see a glare (exposure x 1 + CAVE_GLARE) that settles over CAVE_ADAPT_OUT_S.
const CAVE_LIGHT_NORMAL_DEEP := 0.015     # with the switch, setting "Normal": a faint dusk deep in (not 12 %)
const CAVE_VIEW_GAIN := 0.6
const CAVE_BEND_LIGHT := 0.0005           # one bend: about moonlight
const CAVE_COME_OUT_FAST_S := 0.4
const CAVE_ADAPT_IN_S := 90.0
const CAVE_ADAPT_OUT_S := 2.0
const CAVE_ADAPT_LIFT := 3.0
const CAVE_ADAPT_CAP := 0.03
const CAVE_GLARE := 1.2
const CAVE_RAIN_FROM := 0.1              # rock enclosure from which falling rain and snow thin out (an overhang lets a little through)
const CAVE_RAIN_GONE := 0.5              # and at which none falls: in a cave (cave_sounds.gd's "in a cave" mark). Dave's QA list BUG-009, 3 Nov 2026
const EXPOSURE_CLEAR := 1.1
const EXPOSURE_STORM := 0.95
const SATURATION_CLEAR := 1.12
const SATURATION_STORM := 0.72
const DAY_STEP_MSEC := 1000                # sun direction and colour refresh
const SKY_STEP_MSEC := 4000                # sky palette refresh (see the comment where it is used)
const EASE_S := 8.0                      # seconds for a front to fade fully in or out
const RAIN_AMOUNT := [500, 1400, 2800, 4500]
const SNOW_AMOUNT := [350, 900, 2000, 3200]
const BOLT_FROM := 1                     # first quality level that draws the bolt itself
const TURBULENCE_FROM := 1               # snow drifts sideways from here up
const BOX_M := 24.0                      # half width of the box the precipitation falls through
const FLASH_S := 0.9
# Valley fog (docs/design/valley_fog.md): the weather's `mist` (0..1) and `mist_top_m` (its top above sea level).
const MIST_HEIGHT_DENSITY := 0.08        # per metre below the top at full mist: 5 m down about a third white, 30 m down nearly solid
const MIST_EDGE_M := 6.0                 # the camera goes from above the fog to inside it over this much height either side of the top
const MIST_INSIDE_THICK := 14.0          # the server's animal-sight rule (Weather.VIS_MIST_THICK, about 220 m in full fog) until the third fog PR; the look uses fog_look.gd
const MIST_WHITE := Color(0.9, 0.9, 0.9)
const MIST_WHITEN := 0.55                # how far the fog colour moves from the horizon colour toward white by day
const MIST_OWN_COLOR := 0.8              # the fog keeps its own colour instead of taking the sky's (aerial perspective) by this much
const MIST_ABOVE_CLEAR := 0.3           # above the layer the air is clear (the cold sits below): the distance haze x this, so hills above it stay sharp (#603 shot)
const MIST_SUN_SCATTER := 0.25           # glow toward the low sun through the fog
# Sea fog (docs/design/fog_pools_and_sea_fog.md part B): the weather's `sea_fog` over the sea, `sea_fog_land` over the land and
# `sea_fog_top_m`. The land layer is the stronger of valley fog and sea fog over land; the sea plane takes the sea fog only.
const SEA_FOG_WHITEN := 0.3              # sea fog is greyer than valley fog (Kathleen: "a grey bank offshore")
const SEA_LEVEL_EYE_M := 2.0             # a camera this low (swimming, on a beach) is in the sea fog layer too

# Rain streaks (docs/design/rain_look_design.md 3.1; a streak over a canopy is not drawn, the map is canopy_map.gd): lit by the scene (sun, moon, sky ambient, a held torch or a fire's light),
# never self-lit, with forward scatter so rain backlit by a low sun or a flame is the brightest; a dark night shows rain only in the light.
const RAIN_SHADER_LIT := """
shader_type spatial;
render_mode cull_disabled, blend_mix, specular_disabled;
uniform vec4 streak : source_color = vec4(0.78, 0.84, 0.95, 0.42);
uniform vec2 size_scale = vec2(1.0, 1.0);
uniform sampler2D canopy : filter_linear, hint_default_black;
uniform vec3 canopy_box = vec3(0.0, 0.0, 128.0);

void vertex() {
	vec3 o = MODEL_MATRIX[3].xyz;
	vec2 uv = (o.xz - canopy_box.xy) / canopy_box.z;
	if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
		VERTEX *= 1.0 - smoothstep(0.2, 0.8, textureLod(canopy, uv, 0.0).r);
	}
	VERTEX *= vec3(size_scale.x, size_scale.y, size_scale.x);
}

void fragment() {
	ALBEDO = streak.rgb;
	ALPHA = streak.a;
	NORMAL = VIEW;          // a drop has no face: it takes the light the same from any side
	ROUGHNESS = 1.0;
}

void light() {
	// Forward scatter: light from behind the drop, toward the eye, comes through brightest.
	float scatter = pow(max(dot(LIGHT, -VIEW), 0.0), 6.0);
	DIFFUSE_LIGHT += ATTENUATION * LIGHT_COLOR / PI * (0.35 + 2.5 * scatter);
}
"""
const RAIN_LOOK_LIFETIME_S := 2.4        # fixed (a change of lifetime restarts the particles): the slower the fall, the lower the streaks start
const RAIN_LOOK_BELOW_M := 8.0           # streaks end about this far below the eye
const RAIN_LOOK_FALL := [2.5, 9.0]       # m/s, drizzle to a downpour (Gunn and Kinzer: no drop falls faster than about 9 m/s)
const RAIN_LOOK_SPREAD := 0.12           # each streak's speed varies this much
const RAIN_LOOK_STREAK_S := 0.05         # a streak is as long as the drop falls in this time
const RAIN_LOOK_MAX_SLANT_DEG := 65.0
const RAIN_LOOK_GUST := 0.5              # gusts add up to this share of the mean wind (Jamie #637: gusts about 1.5 x the mean)
const MESH_STREAK_M := 0.6               # the streak mesh's own length (_make_rain)
# The splash sheet (rain_look_design.md 3.2, quality High and Ultra): the streaks stop on a heightfield of the ground around the eye and each
# hit throws a few droplets up a hand high; drawn only in a downpour. Grass cards hide it on turf, as real grass swallows the splashes.
const SPLASH_FROM_QUALITY := 2
const SPLASH_PER_HIT := 4
const SPLASH_AMOUNT := 2000
const SPLASH_FROM := 0.5                 # rain strength from which the sheet shows
const SPLASH_FIELD_M := 64.0
var _splash: GPUParticles3D
var _splash_field: GPUParticlesCollisionHeightField3D
var _splash_material: StandardMaterial3D
var _splash_sent: float = -1.0
var _bark_wet_sent: float = -1.0
var _bark_wind_sent: Vector2 = Vector2.INF
const RainDripsScript := preload("res://src/client/rain_drips.gd")
var drips                                # RainDrips: crowns and eaves dripping during and after rain (rain_look_design.md 3.3)
var rain_fall_ms: float = 0.0            # the streaks' fall and drift now, for checks
var rain_drift_ms: Vector2 = Vector2.ZERO


# Wind in m/s from the weather's 0..1 (Jamie #637: m/s = 20 x wind^1.3).
static func wind_ms(wind: float) -> float:
	return 20.0 * pow(clampf(wind, 0.0, 1.0), 1.3)


# How much the sky has clouded over for this rain or snow: 0 clear, about 0.8 at rain 0.15, 1 from 0.2. The rain sounds (rain_audio.gd AUDIBLE_FROM) are held until it is high.
static func wet_sky_share(rain: float, snow: float) -> float:
	return smoothstep(0.02, 0.2, maxf(rain, snow))


# How fast the drops fall at a rain strength (drizzle 2.5 m/s, a downpour 9 m/s).
static func rain_fall(hard: float) -> float:
	return lerpf(float(RAIN_LOOK_FALL[0]), float(RAIN_LOOK_FALL[1]), smoothstep(0.1, 0.9, hard))


# The streaks' sideways drift in m/s: the wind (with its gust share) along the way it blows toward, held to the slant cap.
static func rain_drift(fall: float, wind: float, heading: float, gust: float) -> Vector2:
	var speed: float = minf(wind_ms(wind) * (1.0 + RAIN_LOOK_GUST * clampf(gust, 0.0, 1.0)), fall * tan(deg_to_rad(RAIN_LOOK_MAX_SLANT_DEG)))
	return Vector2(cos(heading), sin(heading)) * speed


# A smooth 0..1 gust from the real time: two slow waves (periods 5.3 and 3.1 s), no repeat a player could hear or see.
static func gust_at(seconds: float) -> float:
	return clampf(0.5 + 0.25 * sin(seconds * TAU / 5.3) + 0.25 * sin(seconds * TAU / 3.1 + 1.7), 0.0, 1.0)


# What the sound stage's weather test kinds look like.
const TEST := {
	"clear": {"cloud": 0.15, "rain": 0.0, "snow": 0.0, "storm": 0.0, "wind": 0.1, "fog": 0.0, "mist": 0.0},
	"drizzle": {"cloud": 0.5, "rain": 0.3, "snow": 0.0, "storm": 0.0, "wind": 0.15, "fog": 0.0, "mist": 0.0},
	"rain": {"cloud": 0.8, "rain": 0.65, "snow": 0.0, "storm": 0.0, "wind": 0.3, "fog": 0.0, "mist": 0.0},
	"storm": {"cloud": 1.0, "rain": 1.0, "snow": 0.0, "storm": 1.0, "wind": 0.8, "fog": 0.0, "mist": 0.0},
	"snow": {"cloud": 0.8, "rain": 0.0, "snow": 0.6, "storm": 0.0, "wind": 0.1, "fog": 0.0, "mist": 0.0},
	"blizzard": {"cloud": 1.0, "rain": 0.0, "snow": 1.0, "storm": 0.7, "wind": 1.0, "fog": 0.0, "mist": 0.0},
	# The fog test is valley fog now (a layer with a top, docs/design/valley_fog.md), not an even haze: thick inside it, clear above it.
	"fog": {"cloud": 0.1, "rain": 0.0, "snow": 0.0, "storm": 0.0, "wind": 0.0, "fog": 0.0, "mist": 1.0, "mist_top_m": 90.0},   # the sea stays clear under it
}

var _client
var _quality: int = 2
var _s: Dictionary = {"cloud": 0.0, "rain": 0.0, "snow": 0.0, "storm": 0.0, "wind": 0.1, "fog": 0.0, "mist": 0.0, "mist_top_m": 0.0, "sea_fog": 0.0, "sea_fog_land": 0.0, "sea_fog_top_m": 0.0}
var mist_inside: float = 0.0             # 0 above or out of the valley fog .. 1 the camera is deep inside it (for the HUD and tests)
var fog_body                            # FogVolume: the fog's drifting body and the fire halos in it (High and Ultra)
var fog_sky: float = 0.0                 # share of the sky the fog overhead hides now (fog_look.gd sky_hide; dims the sun)
var _fog_veil_sent: float = -1.0
var canopy                              # CanopyMap: where trees shelter the ground
var _rain: GPUParticles3D
var _rain_material: ShaderMaterial
var _snow: GPUParticles3D
var _bolt: MeshInstance3D
var _bolt_material: StandardMaterial3D
var _flash_t: float = -1.0              # seconds since the last flash began, -1 when none
var _flash_scale: float = 1.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var flash_level: float = 0.0            # 0..1, for the HUD and tests
var gloom: float = 0.0
var day = DayCycleScript.new()         # sun, moon and sky colours from the game clock (day_cycle.gd), refreshed twice a second
var _day_next_msec: int = 0
var _fire_next_msec: int = 0            # the fires' smoke and sparks take the wind once a second
var _sky_next_msec: int = 0
var _cave_factor: float = 1.0           # share of the sun and sky light let in under rock, eased (1 open air)
var cave_adapt: float = 0.0             # 0 .. 1: the eyes adapted to the dark of a cave
var _dark: float = 0.0                  # 0 bright .. 1 stormy: sun, ambient light, exposure and colour follow it
var canopy_night: float = 0.0           # 0 open .. 1 under closed crowns, at night only, eased (CANOPY_NIGHT_DIM)
var torch_adapt: float = 0.0            # 0 .. 1: the eyes adapted to a held flame at night, eased (TORCH_NIGHT_DIM)
var flame_colour: float = 0.0           # 0 .. 1: how much a flame in the hand or a fire close by gives the colour back, eased
var night_colour: float = 1.0           # share of the colour left by the night, after a flame's share (1 by day), for checks
var rainbow: float = 0.0                # 0 .. 1 the bow's strength now, eased (for checks)
var _rain_memory: float = 0.0           # the recent rain, falling off over RAINBOW_HOLD_S
var _rainbow_sent: float = -1.0
var cloud_cover: float = 0.0
var clear_day: bool = false             # Esc > Admin "Day, sunny, no fog" (Dave 2026-10-23): noon light, clear sky, no fog, for testing and viewing; the clock and the world weather go on
var strikes_seen: int = 0
# One visibility for everyone who needs it (MikeW's animals in fog, the sky, sound; 8 Nov 2026): metres at which a dark object
# against the sky is just lost, from the fog actually drawn round the eye (rain, snow, storm, weather fog, inside valley fog, under
# water). Koschmieder with a 5 % threshold: V = 3 / extinction, and Godot's fog_density is the extinction per metre (Jamie #716:
# recognise at half V, detail at a quarter). Seen from above a valley fog the eye is in clear air, so V is the clear air's.
var visibility_m: float = VISIBILITY_MAX_M
const VISIBILITY_MAX_M := 50000.0          # no fog drawn (Esc > Admin clear day): call it 50 km


# Visibility (m) for a fog density (extinction per metre): 3 / density, at most VISIBILITY_MAX_M.
static func visibility_of_density(density: float) -> float:
	return VISIBILITY_MAX_M if density <= 3.0 / VISIBILITY_MAX_M else 3.0 / density


const FrameProbe := preload("res://src/debug/frame_probe.gd")
const WindCueScript := preload("res://src/client/wind_cue.gd")
const FireWeather := preload("res://src/client/fire_weather.gd")
const FogLook := preload("res://src/client/fog_look.gd")
const FogVolumeScript := preload("res://src/client/fog_volume.gd")
var _fire_light_next_msec: int = 0
const GameClock := preload("res://src/shared/game_clock.gd")
const FloraView := preload("res://src/flora/flora_view.gd")
var wind_cue                            # WindCue: drifting specks that show the wind heading (off at Low)
const BreathLookScript := preload("res://src/client/breath_look.gd")
var breath                              # BreathLook: breath puffs in the cold (art_weather_light.md 8.4)
const PuddlesScript := preload("res://src/client/puddles.gd")
const SummitsScript := preload("res://src/client/summits.gd")
const CapCloudScript := preload("res://src/client/cap_cloud.gd")
const WeatherRules := preload("res://src/shared/weather.gd")
const HazeScript := preload("res://src/client/haze.gd")
var haze = HazeScript.new()             # Haze: the clear-air haze follows temperature and humidity, (art_weather_light.md 7.2)
var summits                             # Summits: the tops near the player from the tiles' coarse heights (cap cloud, summit snow)
var cap_cloud                           # CapCloud: caps on high summits, (art_weather_light.md 7.1)
var summit_snow: Vector2 = Vector2.ZERO # what the ground was last told: summit height, lowest share (for checks)
var _summit_next_msec: int = 0
var _summits_set: bool = false
# Summit snow (art_weather_light.md 8.2.1): the lowest patches as a share of the island's summit, at the middle of spring,
# summer, autumn and winter, eased between them.
const SUMMIT_SNOW_SHARE := [0.62, 0.82, 0.70, 0.50]
const SUMMIT_NEAR_M := 10000.0
var puddles                             # Puddles: levels, ice and splashes for the puddles the ground draws (art_weather_light.md 8.1.1)

func setup(client) -> void:
	_client = client
	_rng.seed = 5150
	canopy = CanopyMapScript.new()
	_rain = _make_rain()
	_snow = _make_snow()
	add_child(_rain)
	add_child(_snow)

	_make_splash()
	var drip_material: ShaderMaterial = ShaderMaterial.new()
	var drip_shader: Shader = Shader.new()
	drip_shader.code = RAIN_SHADER_LIT      # lit like the streaks; no canopy map, so nothing hides them under the crowns they fall from
	drip_material.shader = drip_shader
	drip_material.set_shader_parameter("streak", Color(0.78, 0.84, 0.95, 0.32))
	drips = RainDripsScript.new()
	drips.setup(self, drip_material)
	drips.set_quality(_quality)
	wind_cue = WindCueScript.new()
	add_child(wind_cue)
	wind_cue.setup()
	breath = BreathLookScript.new()
	add_child(breath)
	breath.setup(client)
	fog_body = FogVolumeScript.new(self)
	puddles = PuddlesScript.new()
	add_child(puddles)
	puddles.setup(client)
	summits = SummitsScript.new()
	cap_cloud = CapCloudScript.new()
	add_child(cap_cloud)
	cap_cloud.setup(client)
	_bolt_material = StandardMaterial3D.new()
	_bolt_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_bolt_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bolt_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_bolt_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_bolt_material.disable_fog = true
	_bolt_material.albedo_color = Color(0.82, 0.88, 1.0, 0.0)
	_bolt = MeshInstance3D.new()
	_bolt.material_override = _bolt_material
	_bolt.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bolt.visible = false
	_bolt.top_level = true
	add_child(_bolt)

	if client.sound != null and client.sound.weather != null:
		client.sound.weather.lightning.connect(_on_lightning)


# The fog look now, 0 clear .. 1 thick, eased (sound_occlusion.gd: --sound-outdoors trims far high notes in fog).
func fog_now() -> float:
	return float(_s.get("fog", 0.0))


func set_quality(quality: int) -> void:
	_quality = clampi(quality, 0, RAIN_AMOUNT.size() - 1)
	_rain.amount = int(RAIN_AMOUNT[_quality])

	if drips != null:
		drips.set_quality(_quality)

	if _splash != null:
		# Changing these rebuilds the particle shader, so they follow the quality setting only, never the weather.
		var sheet: bool = _quality >= SPLASH_FROM_QUALITY
		var process: ParticleProcessMaterial = _rain.process_material as ParticleProcessMaterial
		process.collision_mode = ParticleProcessMaterial.COLLISION_HIDE_ON_CONTACT if sheet else ParticleProcessMaterial.COLLISION_DISABLED
		process.sub_emitter_mode = ParticleProcessMaterial.SUB_EMITTER_AT_COLLISION if sheet else ParticleProcessMaterial.SUB_EMITTER_DISABLED
		_splash_field.visible = sheet
	_snow.amount = int(SNOW_AMOUNT[_quality])
	(_snow.process_material as ParticleProcessMaterial).turbulence_enabled = _quality >= TURBULENCE_FROM

	if wind_cue != null:
		wind_cue.set_quality(_quality)


func _make_rain() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = int(RAIN_AMOUNT[_quality])
	particles.lifetime = RAIN_LOOK_LIFETIME_S
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-40.0, -40.0, -40.0), Vector3(80.0, 80.0, 80.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(BOX_M, 0.3, BOX_M)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 1.0
	process.initial_velocity_min = 15.0
	process.initial_velocity_max = 19.0
	process.gravity = Vector3.ZERO
	process.particle_flag_align_y = true
	particles.process_material = process
	# Two crossed thin quads: a streak seen from any side.
	var half: float = 0.005
	var length: float = 0.6
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-half, 0.0, 0.0), Vector3(half, 0.0, 0.0), Vector3(half, length, 0.0), Vector3(-half, length, 0.0),
		Vector3(0.0, 0.0, -half), Vector3(0.0, 0.0, half), Vector3(0.0, length, half), Vector3(0.0, length, -half)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader: Shader = Shader.new()
	shader.code = RAIN_SHADER_LIT
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("canopy", canopy.texture)
	_rain_material = material
	mesh.surface_set_material(0, material)
	particles.draw_pass_1 = mesh
	return particles


# Real fall speeds, a slant along the wind's own heading with gusts, streak length from the speed. The lifetime is fixed, so
# the box starts lower for slow drizzle and higher for a downpour, and upwind by half the drift so the streaks fill the view around the eye.
func _update_rain_look(eye: Vector3, hard: float, heading: float) -> void:
	var fall: float = rain_fall(hard)
	var drift: Vector2 = rain_drift(fall, float(_s["wind"]), heading, gust_at(float(Time.get_ticks_msec()) / 1000.0))
	rain_fall_ms = fall
	rain_drift_ms = drift
	var path: float = fall * RAIN_LOOK_LIFETIME_S
	var start: float = maxf(path - RAIN_LOOK_BELOW_M, 2.0)
	_rain.global_position = eye + Vector3(-drift.x * RAIN_LOOK_LIFETIME_S * 0.5, start, -drift.y * RAIN_LOOK_LIFETIME_S * 0.5)
	var velocity: Vector3 = Vector3(drift.x, -fall, drift.y)
	var speed: float = velocity.length()
	var process: ParticleProcessMaterial = _rain.process_material as ParticleProcessMaterial
	process.direction = velocity / maxf(speed, 0.001)
	process.spread = 0.6
	process.initial_velocity_min = speed * (1.0 - RAIN_LOOK_SPREAD)
	process.initial_velocity_max = speed * (1.0 + RAIN_LOOK_SPREAD)
	_rain_material.set_shader_parameter("size_scale", Vector2(lerpf(0.55, 1.7, hard), speed * RAIN_LOOK_STREAK_S / MESH_STREAK_M))


func _make_splash() -> void:
	_splash = GPUParticles3D.new()
	_splash.name = "RainSplash"
	_splash.amount = SPLASH_AMOUNT
	_splash.lifetime = 0.25
	_splash.local_coords = false
	_splash.visibility_aabb = AABB(Vector3(-40.0, -40.0, -40.0), Vector3(80.0, 80.0, 80.0))
	_splash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_splash.visible = false
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.direction = Vector3(0.0, 1.0, 0.0)
	process.spread = 55.0
	process.initial_velocity_min = 0.5
	process.initial_velocity_max = 1.5
	process.gravity = Vector3(0.0, -9.8, 0.0)
	process.scale_min = 0.6
	process.scale_max = 1.2
	_splash.process_material = process
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.012, 0.012)
	var drop: StandardMaterial3D = StandardMaterial3D.new()
	drop.albedo_color = Color(0.80, 0.84, 0.90, 0.45)
	drop.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	drop.roughness = 1.0
	drop.specular_mode = BaseMaterial3D.SPECULAR_DISABLED    # lit by the scene like the streaks, never self-lit
	quad.material = drop
	_splash_material = drop
	_splash.draw_pass_1 = quad
	add_child(_splash)
	_splash_field = GPUParticlesCollisionHeightField3D.new()
	_splash_field.size = Vector3(SPLASH_FIELD_M, 60.0, SPLASH_FIELD_M)
	_splash_field.resolution = GPUParticlesCollisionHeightField3D.RESOLUTION_256
	_splash_field.update_mode = GPUParticlesCollisionHeightField3D.UPDATE_MODE_WHEN_MOVED
	_splash_field.follow_camera_enabled = true
	add_child(_splash_field)
	_rain.collision_base_size = 0.02
	_rain.sub_emitter = _rain.get_path_to(_splash)
	var rain_process: ParticleProcessMaterial = _rain.process_material as ParticleProcessMaterial
	rain_process.sub_emitter_amount_at_collision = SPLASH_PER_HIT
	rain_process.collision_bounce = 0.0
	set_quality(_quality)


# The splash flecks on the ground and the splash sheet's strength: how hard it rains on open ground now (none in a cave).
func _update_splash(rain: float, open_sky: float) -> void:
	var on_ground: float = snappedf(rain * open_sky, 0.02)
	var material: ShaderMaterial = _client.terrain.material as ShaderMaterial

	if material != null and on_ground != _splash_sent:
		_splash_sent = on_ground
		material.set_shader_parameter("splash_rain", on_ground)

	if _splash != null:
		_splash.visible = _quality >= SPLASH_FROM_QUALITY and on_ground >= SPLASH_FROM and _rain.visible
		var tint: Color = _splash_material.albedo_color
		var alpha: float = lerpf(0.2, 0.45, smoothstep(SPLASH_FROM, 1.0, on_ground))

		if absf(tint.a - alpha) > 0.01:
			tint.a = alpha
			_splash_material.albedo_color = tint


func _make_snow() -> GPUParticles3D:
	var particles: GPUParticles3D = GPUParticles3D.new()
	particles.amount = int(SNOW_AMOUNT[_quality])
	particles.lifetime = 9.0
	particles.local_coords = false
	particles.visibility_aabb = AABB(Vector3(-40.0, -40.0, -40.0), Vector3(80.0, 80.0, 80.0))
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	var process: ParticleProcessMaterial = ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(BOX_M, 0.3, BOX_M)
	process.direction = Vector3(0.0, -1.0, 0.0)
	process.spread = 12.0
	process.initial_velocity_min = 1.0
	process.initial_velocity_max = 1.9
	process.gravity = Vector3.ZERO
	process.turbulence_noise_strength = 0.9
	process.turbulence_noise_scale = 3.0
	process.turbulence_enabled = _quality >= TURBULENCE_FROM
	particles.process_material = process
	var quad: QuadMesh = QuadMesh.new()
	quad.size = Vector2(0.07, 0.07)
	var gradient: Gradient = Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	gradient.offsets = PackedFloat32Array([0.3, 1.0])
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 32
	texture.height = 32
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = texture
	material.albedo_color = Color(0.95, 0.97, 1.0, 0.85)
	quad.material = material
	particles.draw_pass_1 = quad
	return particles


# The look the weather asks for: the sound stage's test kind when one is selected, else the world.
func _target() -> Dictionary:
	var out: Dictionary = {"cloud": 0.0, "rain": 0.0, "snow": 0.0, "storm": 0.0, "wind": 0.1, "fog": 0.0, "mist": 0.0, "mist_top_m": 0.0, "sea_fog": 0.0, "sea_fog_land": 0.0, "sea_fog_top_m": 0.0}

	if clear_day:
		return out

	if int(_client.sound_tests.weather_at) >= 0 and _client.sound != null and _client.sound.weather != null:
		return TEST.get(_client.sound.weather.kind, out)

	var world: Dictionary = _client.weather

	if not world.is_empty():
		for key in ["cloud", "rain", "snow", "storm", "wind", "mist", "mist_top_m", "sea_fog", "sea_fog_land", "sea_fog_top_m"]:
			out[key] = float(world.get(key, 0.0))

	return out


# Owner (2026-10-20): in a big storm the ocean and all land water turn darker and dirtier, then
# clear again. Land water lags the weather far more than the sea (rivers stay muddy after the rain).
# Real seconds to rise and to clear; the water material takes one uniform (water_material.gd, storm).
const LAND_MURK_RISE_S := 360.0
const LAND_MURK_CLEAR_S := 900.0
const SEA_MURK_RISE_S := 120.0
const SEA_MURK_CLEAR_S := 360.0
var land_murk: float = 0.0
var sea_murk: float = 0.0
var _liquid_rain: float = 0.0   # what the liquid water sheets were last told (liquid_surface.gd, rain rings)


# Water after rain (docs/design/water_look_after_rain.md 1 and 4): the cloud after rain follows the rivers' push with a lag, then clears on a
# half-life (running water as the clear reach class until the record gives one per reach; still water slower, at half the strength);
# the foam supply follows the season and the cloud. Game hours: one is 150 real seconds.
const LOOK_PUSH_LAG_S := 1.5 * 150.0
const LOOK_RUN_RISE_S := 0.5 * 150.0
const LOOK_RUN_HALF_S := 12.0 * 150.0
const LOOK_STILL_RISE_S := 3.0 * 150.0
const LOOK_STILL_HALF_S := 18.0 * 150.0
const LOOK_FOAM_SEASON := {"spring": 0.6, "summer": 0.6, "autumn": 1.0, "winter": 0.4}
var turbid: Vector2 = Vector2.ZERO      # the cloud in running and in still water (for checks)
var _look_push: float = 0.0
var _look_next_msec: int = 0


func _update_water_look(delta: float, storm: float, rain: float) -> void:
	var push: float = WeatherRules.river_push({"rain": rain, "storm": storm})
	_look_push += (push - _look_push) * (1.0 - exp(-delta / LOOK_PUSH_LAG_S))
	var run: float = turbid.x
	run = run + (_look_push - run) * (1.0 - exp(-delta / LOOK_RUN_RISE_S)) if _look_push > run else run * pow(0.5, delta / LOOK_RUN_HALF_S)
	var still_want: float = 0.5 * run
	var still: float = turbid.y
	still = still + (still_want - still) * (1.0 - exp(-delta / LOOK_STILL_RISE_S)) if still_want > still else still * pow(0.5, delta / LOOK_STILL_HALF_S)
	turbid = Vector2(run, still)
	var now: int = Time.get_ticks_msec()

	if now < _look_next_msec or _client.flora == null:
		return

	_look_next_msec = now + 2000            # new sheets pick it up within 2 s
	var season: float = float(LOOK_FOAM_SEASON.get(str(_client.weather.get("season", "summer")), 0.6))
	_client.flora.set_water_look(true, turbid, season * (1.0 + 0.6 * clampf(run * 1.6, 0.0, 1.0)))


func _update_water_murk(delta: float, storm: float, rain: float) -> void:
	_update_water_look(delta, storm, rain)

	var want: float = clampf(storm + 0.25 * rain, 0.0, 1.0)
	var land: float = move_toward(land_murk, want, delta / (LAND_MURK_RISE_S if want > land_murk else LAND_MURK_CLEAR_S))
	var sea: float = move_toward(sea_murk, want, delta / (SEA_MURK_RISE_S if want > sea_murk else SEA_MURK_CLEAR_S))

	if absf(land - land_murk) > 0.0005 and _client.flora != null:
		_client.flora.set_storm_murk(land)

	if absf(rain - _liquid_rain) > 0.02 and _client.flora != null and _client.flora.is_inside_tree():
		_liquid_rain = rain
		_client.flora.get_tree().call_group("liquid_sheet", "set_rain", clampf(rain, 0.0, 1.0))

	if absf(sea - sea_murk) > 0.0005 and _client.sea != null:
		var material: ShaderMaterial = _client.sea.material_override as ShaderMaterial

		if material != null:
			material.set_shader_parameter("storm", sea)

	land_murk = land
	sea_murk = sea


func _process(delta: float) -> void:
	var t: int = FrameProbe.start()
	_process_body(delta)
	FrameProbe.stop("weather look", t)


func _process_body(delta: float) -> void:
	if _client == null or _client._environment == null or _client.camera == null or _client.terrain == null:
		return

	var target: Dictionary = _target()

	for key in _s:
		if key == "mist_top_m" or key == "sea_fog_top_m":
			# A height in metres, not a 0..1 level: it follows the weather directly (the world's value changes smoothly), and it stays
			# where it was while the fog eases out, so a fading layer thins in place instead of dropping to sea level.
			if float(target.get("mist" if key == "mist_top_m" else "sea_fog", 0.0)) > 0.0 or clear_day:
				_s[key] = float(target.get(key, 0.0))
		else:
			_s[key] = float(target.get(key, 0.0)) if clear_day else move_toward(float(_s[key]), float(target.get(key, 0.0)), delta / EASE_S)

	# Rain and snow only ever fall from clouds.
	var rain: float = float(_s["rain"])
	var snow: float = float(_s["snow"])
	var storm: float = float(_s["storm"])
	# Any rain or snow means heavy cloud (owner, 2026-10-20: "the weather still doesn't get darker when it
	# rains"): the old cover barely moved in light rain and the sky's lighting cubemap is drawn once, so
	# the sun and the ambient light below carry the darkening.
	var wet_sky: float = wet_sky_share(rain, snow)
	cloud_cover = clampf(maxf(float(_s["cloud"]), maxf(wet_sky * (RAIN_OVERCAST + (1.0 - RAIN_OVERCAST) * maxf(rain, snow * 0.9)), storm)), 0.0, 1.0)
	gloom = clampf(0.3 * cloud_cover + 0.45 * rain + 0.2 * snow + 0.6 * storm, 0.0, 1.0)
	_dark = clampf(0.5 * cloud_cover + 0.35 * rain + 0.15 * snow + 0.35 * storm, 0.0, 1.0)

	_update_water_murk(delta, storm, rain)

	if _flash_t >= 0.0:
		_flash_t += delta
		flash_level = _flash_level(_flash_t) * _flash_scale

		if _flash_t > FLASH_S:
			_flash_t = -1.0
			flash_level = 0.0
			_bolt.visible = false
		elif _bolt.visible:
			_bolt_material.albedo_color.a = clampf(flash_level * 1.4, 0.0, 1.0)

	var environment: Environment = _client._environment
	var sky_material: ShaderMaterial = environment.sky.sky_material as ShaderMaterial

	var now_msec: int = Time.get_ticks_msec()

	if LookSettings.DAY_CYCLE and now_msec >= _day_next_msec and _client.get("game_clock") != null:
		_day_next_msec = now_msec + DAY_STEP_MSEC
		day.update(12.0 if clear_day else _client.game_clock.hour(), _client.game_clock.day_of_year(), float(_client.game_clock.seconds) / 86400.0)

		if _client._sun != null:
			_client._sun.basis = day.light_basis
			_client._sun.light_color = day.light_color

	if now_msec >= _fire_next_msec and _client.get("game_clock") != null:
		_fire_next_msec = now_msec + 1000
		var world_weather: Variant = _client.get("weather")
		var fire_heading: float = float(world_weather.get("wind_dir", 0.0)) if world_weather is Dictionary else 0.0
		var wind_now: float = float(_s["wind"])
		BuildingLook.set_fire_air(fire_wind_ms(wind_now), fire_heading, still_night(day.elevation, _client.game_clock.hour(), cloud_cover, wind_now))

	# The sky colours change in coarser steps than the sun: a changed sky shader parameter may make the engine redraw the
	# sky's lighting cubemap, so it is paid once every few seconds (two game minutes), not every frame. Check the GPU table
	# ("sky clouds at Low quality") and the frame time over a dusk if this is ever raised.
	if LookSettings.DAY_CYCLE and now_msec >= _sky_next_msec:
		_sky_next_msec = now_msec + SKY_STEP_MSEC

		if _client.flora != null:
			_client.flora.set_day_sky(day.sky_top, day.sky_horizon, day.cloud_shadow, day.ambient_factor)

		if _client.sea != null:
			WaterMaterial.apply_day(_client.sea.material_override as ShaderMaterial, day.sky_top, day.sky_horizon, day.cloud_shadow, day.ambient_factor)

			if _client._sun != null:
				(_client.sea.material_override as ShaderMaterial).set_shader_parameter("sun_toward", _client._sun.global_transform.basis.z.normalized())

		if sky_material != null:
			sky_material.set_shader_parameter("sky_top_color", day.sky_top)
			sky_material.set_shader_parameter("sky_horizon_color", day.sky_horizon)
			sky_material.set_shader_parameter("ground_horizon_color", day.ground_horizon)
			sky_material.set_shader_parameter("cloud_shadow_color", day.cloud_shadow)
			sky_material.set_shader_parameter("night", day.stars)   # the stars: brighter on a moonless night (day_cycle.gd)

	# A rainbow as a shower passes: recent rain, the sun low and breaking through the clearing cloud.
	_rain_memory = maxf(rain, _rain_memory - delta / RAINBOW_HOLD_S)
	var sun_through: float = clampf(1.0 - cloud_cover * 1.25, 0.0, 1.0)
	var sun_low: float = smoothstep(0.0, 0.05, day.elevation) * (1.0 - smoothstep(RAINBOW_SIN_MAX - 0.07, RAINBOW_SIN_MAX, day.elevation))
	var bow_target: float = 0.0 if clear_day else smoothstep(0.03, 0.25, _rain_memory) * smoothstep(0.15, 0.6, sun_through) * sun_low * (1.0 - storm)
	rainbow = move_toward(rainbow, bow_target, delta / RAINBOW_EASE_S)

	if sky_material != null:
		if absf(rainbow - _rainbow_sent) > 0.004:
			_rainbow_sent = rainbow
			sky_material.set_shader_parameter("rainbow", rainbow)

		sky_material.set_shader_parameter("coverage", lerpf(0.62, 0.30, cloud_cover))
		sky_material.set_shader_parameter("gloom", gloom)
		sky_material.set_shader_parameter("flash", flash_level)

	# Light: the sun fades behind cloud, the sky's own light dims a little, lightning jumps both. Under rock (a cave, a tunnel
	# dug into a hill) neither the sun nor the sky's light gets in, day or night: only torches and fires light it.
	var enclosed: float = _client.sound.cave.rock_enclosure if _client.sound != null and _client.sound.cave != null else 0.0
	var left: float = CAVE_LIGHT_DARK if _client.display.cave_dark else CAVE_LIGHT_NORMAL
	var cave_target: float = cave_light(enclosed, left)
	var come_out_s: float = CAVE_COME_OUT_S
	var glare: float = 0.0

	if _client.sound != null and _client.sound.cave != null:
		var cave = _client.sound.cave
		cave_target = cave_light_view(enclosed, float(cave.mouth_view), int(cave.bends), CAVE_LIGHT_DARK if _client.display.cave_dark else CAVE_LIGHT_NORMAL_DEEP)
		come_out_s = CAVE_COME_OUT_FAST_S

	_cave_factor = move_toward(_cave_factor, cave_target, delta / (CAVE_GO_DARK_S if cave_target < _cave_factor else come_out_s))
	var under_rock: float = _cave_factor

	cave_adapt = move_toward(cave_adapt, 1.0 if _cave_factor < 0.1 else 0.0, delta / (CAVE_ADAPT_IN_S if _cave_factor < 0.1 else CAVE_ADAPT_OUT_S))
	under_rock = adapted_light(_cave_factor, cave_adapt)
	glare = CAVE_GLARE * cave_adapt * smoothstep(0.3, 1.0, _cave_factor)
	var sun_amount: float = clampf(1.0 - cloud_cover * 1.25, 0.0, 1.0)
	# The night light (art_weather_light.md 6.2): crowns overhead and a flame in the hand each take a share of the moon and sky
	# light, at night only. They are eased, and capped below by OUTDOOR_FLOOR further down.
	var eye: Vector3 = _client.camera.global_position
	canopy_night = move_toward(canopy_night, canopy_density(eye.x, eye.z) * day.night, delta / CANOPY_EASE_S)
	var torch_target: float = day.night if held_flame() else 0.0
	torch_adapt = move_toward(torch_adapt, torch_target, delta / (TORCH_ADAPT_S if torch_target > torch_adapt else TORCH_UNADAPT_S))
	var night_keep: float = (1.0 - CANOPY_NIGHT_DIM * canopy_night) * (1.0 - TORCH_NIGHT_DIM * torch_adapt)

	if _client._sun != null:
		var shadows_wanted: bool = under_rock >= CAVE_SHADOW_OFF and float(_client.QUALITY_SHADOW_M[_client.quality]) > 0.0

		if shadows_wanted != _client._sun.shadow_enabled:
			_client._sun.shadow_enabled = shadows_wanted

		# The moon is shadowed by the crowns themselves (tree shadows), so only the eyes' adaptation to a flame takes from it.
		var moon_keep: float = 1.0 - TORCH_NIGHT_DIM * torch_adapt
		# Fog overhead dims the sun and the moon (fog_sky is last frame's; it is eased with the weather anyway).
		_client._sun.light_energy = (LookSettings.SUN_ENERGY * lerpf(SUN_STORM, 1.0, sun_amount) * day.light_factor * moon_keep * FogLook.sun_keep(fog_sky) + flash_level * 1.2) * under_rock

	var open_air: float = maxf(lerpf(1.0, AMBIENT_STORM, _dark * (1.0 - 0.7 * day.night)) * day.ambient_factor, lerpf(AMBIENT_FLOOR, AMBIENT_STORM_FLOOR, _dark))
	# Never pitch black outdoors: the crowns and the flame never take the ambient below OUTDOOR_FLOOR. The same share is taken
	# from the sky's part of the ambient below, so the two parts stay in step.
	var keep: float = clampf(maxf(night_keep, OUTDOOR_FLOOR / maxf(open_air, 0.001)), 0.0, 1.0)
	environment.ambient_light_energy = under_rock * (open_air * keep + flash_level * 2.0)
	# The sky's own light is near black on a dark night or a storm night, so a cold moonlit blue is mixed in
	# (ambient colour counts where the sky contribution is below 1): trees and ground stay readable, never pure black.
	var dim: float = clampf(maxf(day.night, _dark * 0.6), 0.0, 1.0)
	# Under rock the sky's share goes too (Dave 4 Nov 2026: "its day time and its light in the tunnels even at the very back"). The engine scales only the ambient
	# colour by ambient_light_energy; the sky's share of the ambient (and the sky reflections) keep the full sky, so by day three quarters of the open-air ambient
	# still reached the back of a tunnel. The sky's share now fades with the light, and the sky reflections (bright on damp rock and cave pools) go off under rock.
	sky_under_rock(environment, lerpf(DAY_SKY_SHARE, 0.3, dim) * keep, under_rock)   # night 0.3 as before, less under crowns or by a flame
	environment.ambient_light_color = AMBIENT_DAY_WARM.lerp(AMBIENT_NIGHT_COLOR, dim)
	# The whole picture goes dimmer and greyer with the weather.
	environment.tonemap_exposure = lerpf(EXPOSURE_CLEAR, EXPOSURE_STORM, _dark) * (1.0 + glare)
	var fire_m: float = float(_client.sound.fire.nearest_lit_m) if _client.sound != null and _client.sound.fire != null else INF
	var flame_target: float = maxf(1.0 if held_flame() else 0.0, 1.0 - smoothstep(FIRE_COLOUR_NEAR_M, FIRE_COLOUR_FAR_M, fire_m))
	flame_colour = move_toward(flame_colour, flame_target, delta / FLAME_COLOUR_S)
	var moonlit: float = lerpf(NIGHT_COLOUR_DARK, NIGHT_COLOUR_FULL_MOON, day.moon_light)
	var grey: float = (1.0 - moonlit) * day.night * under_rock * (1.0 - FLAME_COLOUR_BACK * flame_colour)
	night_colour = 1.0 - grey
	environment.adjustment_saturation = lerpf(SATURATION_CLEAR, SATURATION_STORM, _dark) * night_colour

	if not _client.underwater:
		var ground_wet: float = puddles.wet_mean      # the ground's own wetness, which dries in game hours (rain_look_design.md 3.4)

		haze.update(delta, float(_client.weather.get("temp_c", 10.0)), float(_s["cloud"]), rain, float(_client.weather.get("mist", 0.0)), ground_wet)
		# The weather fog is drawn by graphics preset (fog_look.gd PRESETS; Dave: off on the lowest, full on Ultra).
		var fog_shown: bool = not clear_day and FogLook.weather_drawn(_quality)
		var mist: float = float(_s["mist"]) if fog_shown else 0.0
		# The clear-air base is the haze rule's share, thickened by rain, snow, storm, fog and the valley fog inside it.
		var sea_fog: float = float(_s["sea_fog"]) if fog_shown else 0.0
		var sea_land: float = float(_s["sea_fog_land"]) if fog_shown else 0.0
		var sea_top: float = float(_s["sea_fog_top_m"])
		# The land layer: the stronger of the valley fog and the sea fog lying over the land, with that one's top.
		var land: float = maxf(mist, sea_land)
		var land_top: float = float(_s["mist_top_m"]) if mist >= sea_land else sea_top
		var eye_y: float = _client.camera.global_position.y
		var eye_in_land: float = smoothstep(-MIST_EDGE_M, MIST_EDGE_M, land_top - eye_y)   # 0 above the layer's top .. 1 below it, whatever its strength
		var in_land: float = land * eye_in_land
		var in_sea: float = sea_fog * smoothstep(-MIST_EDGE_M, MIST_EDGE_M, sea_top - eye_y) if eye_y < SEA_LEVEL_EYE_M else 0.0
		mist_inside = maxf(in_land, in_sea) * under_rock
		# How foggy the air looks overall, and how much of it is the grey sea fog rather than the white valley fog.
		var foggy: float = maxf(land, sea_fog)
		var sea_share: float = maxf(sea_fog, sea_land) / maxf(mist + maxf(sea_fog, sea_land), 0.0001)
		var thick: float = haze.density_scale + 5.0 * rain + 4.0 * snow + 3.0 * storm + 12.0 * float(_s["fog"])
		# Above the layer the air is clear (#672): valley fog or a sea fog bank, whichever is the thicker.
		var haze_density: float = LookSettings.FOG_DENSITY * minf(thick, 20.0) * above_clear(foggy, mist_inside)
		# Depth fog (fog_look.gd): the haze fitted as before, the fog at the eye pulling its end in toward Dave's dense-fog distances.
		var shape: Vector3 = FogLook.depth(haze_density, mist_inside, FogLook.dense_end(_quality))
		environment.fog_mode = Environment.FOG_MODE_DEPTH
		environment.fog_depth_begin = shape.x
		environment.fog_depth_end = shape.y
		environment.fog_depth_curve = shape.z
		environment.fog_density = 0.0 if clear_day else 1.0      # in depth mode: the most fog there can be
		visibility_m = VISIBILITY_MAX_M if clear_day else minf(FogLook.visibility(shape), VISIBILITY_MAX_M)
		# The fog is sky-coloured haze: under rock it must go dark with the light, or a long tunnel glows (pitch black means black).
		# Valley fog is whiter than the haze: lit by the sky and the sun (white by day, warm at sunrise from the dusk horizon colour,
		# blue-grey at night from the night horizon), never a flat grey card (art_weather_light.md section 7 rule 2).
		var fog_tint: Color = _graded(haze.tint(day.sky_horizon), gloom)
		fog_tint = fog_tint.lerp(fog_tint.lerp(MIST_WHITE, lerpf(MIST_WHITEN, SEA_FOG_WHITEN, sea_share) * (1.0 - day.night)), foggy)
		environment.fog_light_color = Color(fog_tint.r * under_rock, fog_tint.g * under_rock, fog_tint.b * under_rock, fog_tint.a)
		# Inside the fog the sky is hidden by the fog overhead: deep fog hides it (a faint sun or moon disc left), shallow ground fog
		# leaves it, above the layer it is clear (Dave's fog instruction). The sun dims with it (applied next frame, above).
		var overhead: float = maxf(land_top - eye_y if in_land >= in_sea else sea_top - eye_y, 0.0)
		fog_sky = FogLook.sky_hide(mist_inside, overhead) if FogLook.sky_drawn(_quality) else 0.0
		environment.fog_sky_affect = fog_sky
		_send_fog_veil(sky_material)
		environment.fog_aerial_perspective = haze.aerial(LookSettings.FOG_AERIAL) * under_rock * (1.0 - MIST_OWN_COLOR * foggy)
		environment.fog_sun_scatter = MIST_SUN_SCATTER * foggy * (1.0 - day.night)
		# Fog has a top (rule 1): Godot's height fog thickens below fog_height and is nothing above it. Seen from above, the low
		# ground fills white with a soft top. Inside the layer the height fog steps aside (it would whiten the ground at your feet
		# as much as the far valley) and the distance fog above carries it. Under rock it goes, like the light.
		environment.fog_height = land_top
		environment.fog_height_density = layer_height_density(land, eye_in_land) * under_rock if FogLook.sky_drawn(_quality) else 0.0
		# The water draws its own fog with the same sums (water_material.gd): rivers and lakes take the land layer, the sea plane only
		# the sea fog, so a calm night's valley fog leaves the open sea clear (radiation fog forms over land, not the open sea).
		var heading_now: float = float(_client.weather.get("wind_dir", 0.0)) if _client.weather is Dictionary else 0.0
		# The body belongs to the layer the eye is in or over: the land layer, or the sea fog only down at sea level (not inland).
		var sea_here: float = sea_fog if eye_y < SEA_LEVEL_EYE_M else 0.0
		fog_body.update(delta, environment, _quality, _client.camera.global_position, mist_inside, maxf(land, sea_here) * under_rock, land_top if land >= sea_here else sea_top, MIST_EDGE_M, wind_ms(float(_s["wind"])), heading_now)
		_water_fog(environment, sea_top, MIST_HEIGHT_DENSITY * sea_fog * (1.0 - mist_inside) * under_rock if FogLook.sky_drawn(_quality) else 0.0, under_rock)
	else:
		_underwater_fog(environment, 1.0 - day.night, cloud_cover)
		fog_body.update(delta, environment, _quality, _client.camera.global_position, 0.0, 0.0, 0.0, MIST_EDGE_M, 0.0, 0.0)
		_water_fog(environment, environment.fog_height, environment.fog_height_density, 1.0)

	canopy.update(_client.flora, Vector2(_client.camera.global_position.x, _client.camera.global_position.z))
	_rain_material.set_shader_parameter("canopy_box", Vector3(canopy.origin.x, canopy.origin.y, canopy.METRES))
	_update_ground(rain, snow)
	var heading: float = float(_client.weather.get("wind_dir", 0.0)) if _client.weather is Dictionary else 0.0
	var cave_open: float = clampf((_cave_factor - CAVE_LIGHT_DARK) / maxf(1.0 - CAVE_LIGHT_DARK, 0.001), 0.0, 1.0)
	puddles.update(delta, rain, float(_s["wind"]), Vector2(cos(heading), sin(heading)), smoothstep(0.6, 0.95, cave_open), _client.terrain.material as ShaderMaterial)

	var sun_now: float = clampf(1.0 - float(_s["cloud"]) * 1.1, 0.0, 1.0) * smoothstep(0.0, 0.2, day.elevation)
	puddles.update_wet(delta, rain, float(_s["wind"]), sun_now, Vector2(cos(heading), sin(heading)), _client.terrain.material as ShaderMaterial)
	# The bark takes the rock's wetness (a hard surface that sheds water) and the wind's side; sent only when it changes.
	var bark_wet: float = snappedf(float(puddles.wet[5]), 0.02)
	var bark_wind: Vector2 = Vector2(cos(heading), sin(heading)).snapped(Vector2(0.1, 0.1))

	if _client.flora != null and (bark_wet != _bark_wet_sent or bark_wind != _bark_wind_sent):
		_bark_wet_sent = bark_wet
		_bark_wind_sent = bark_wind
		_client.flora.set_wet(bark_wet, bark_wind)

	_update_summits(delta, heading)
	_update_particles(rain, snow, float(_s["wind"]))
	breath.update(delta)
	_update_tree_wind()


# The water shader writes its own fog (FOG), so it is fed the environment's fog each frame: the same distance and height fog,
# colour, aerial colour and sun glow. sea_height and sea_density are the sea plane's own height layer.
func _water_fog(environment: Environment, sea_height: float, sea_density: float, light_left: float) -> void:
	var aerial: Color = _graded(day.sky_horizon, gloom)
	var sun_color: Color = _client._sun.light_color if _client._sun != null else Color.WHITE
	var sun_energy: float = _client._sun.light_energy if _client._sun != null else 0.0

	for material in [_client.sea.material_override if _client.sea != null else null, _client.flora.water_material() if _client.flora != null else null]:
		if material is ShaderMaterial:
			var m: ShaderMaterial = material
			m.set_shader_parameter("fog_color", environment.fog_light_color)
			m.set_shader_parameter("fog_energy", environment.fog_light_energy)
			m.set_shader_parameter("fog_density", environment.fog_density)
			m.set_shader_parameter("fog_depth_mode", environment.fog_mode == Environment.FOG_MODE_DEPTH)
			m.set_shader_parameter("fog_depth", Vector3(environment.fog_depth_begin, environment.fog_depth_end, environment.fog_depth_curve))
			m.set_shader_parameter("fog_aerial", environment.fog_aerial_perspective)
			m.set_shader_parameter("fog_sky_color", Color(aerial.r * light_left, aerial.g * light_left, aerial.b * light_left))
			m.set_shader_parameter("fog_height", environment.fog_height)
			m.set_shader_parameter("fog_height_density", environment.fog_height_density)
			m.set_shader_parameter("sea_fog_height", sea_height)
			m.set_shader_parameter("sea_fog_height_density", sea_density)
			m.set_shader_parameter("fog_sun_scatter", environment.fog_sun_scatter)
			m.set_shader_parameter("fog_sun_color", sun_color)
			m.set_shader_parameter("fog_sun_energy", sun_energy)

			if _client._sun != null:
				m.set_shader_parameter("sun_toward", _client._sun.global_transform.basis.z.normalized())


# Under water (Dave 2 Nov 2026: "being under the water looking up looks fake"): no flat blue screen. The water itself is the fog:
# blue-green, lit by the day (dark at night, greyer under cloud), thicker with depth below the surface so the deep falls away to
# dark and the surface above stays bright. The haze takes the water's colour, not the sky's.
const UNDER_FOG_DENSITY := 0.035       # about 25 m to near blindness in clear water, looking level
const UNDER_DEEP_DENSITY := 0.06       # extra per metre below the surface (Godot height fog)
const UNDER_DAY_COLOR := Color(0.10, 0.36, 0.42)
const UNDER_NIGHT_COLOR := Color(0.01, 0.03, 0.05)


func _underwater_fog(environment: Environment, daylight: float, cover: float) -> void:
	environment.fog_sun_scatter = 0.0
	mist_inside = 0.0
	var lit: float = clampf(daylight, 0.0, 1.0) * lerpf(1.0, 0.55, cover)
	environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL     # the water's own fog is exponential (open air uses depth fog)
	environment.fog_density = UNDER_FOG_DENSITY
	visibility_m = visibility_of_density(UNDER_FOG_DENSITY)
	fog_sky = 0.0
	var color: Color = UNDER_NIGHT_COLOR.lerp(UNDER_DAY_COLOR, lit)
	environment.fog_light_color = color
	environment.fog_light_energy = 1.0
	environment.fog_sky_affect = 1.0
	environment.fog_aerial_perspective = 0.0
	environment.fog_height = float(_client.underwater_surface)
	environment.fog_height_density = UNDER_DEEP_DENSITY


# Share of the falling rain and snow that reaches the player at this rock enclosure: 1 in the open, 0 in a cave (BUG-009).
static func sky_share(rock_enclosure: float) -> float:
	return 1.0 - smoothstep(CAVE_RAIN_FROM, CAVE_RAIN_GONE, rock_enclosure)


# The sky's part of the light under rock: its share of the ambient (`sky_share` in the open) fades with the square of the cave light `under_rock` (1 open ..
# CAVE_LIGHT_DARK deep in), so the ambient left is about under_rock like the sun's, and the sky reflections are off below CAVE_REFLECT_OFF.
static func sky_under_rock(environment: Environment, sky_part: float, under_rock: float) -> void:
	environment.ambient_light_sky_contribution = sky_part * under_rock * under_rock     # the sky part is not dimmed by the energy: x under_rock twice keeps the total near under_rock
	var reflect: Environment.ReflectionSource = Environment.REFLECTION_SOURCE_SKY if under_rock >= CAVE_REFLECT_OFF else Environment.REFLECTION_SOURCE_DISABLED

	if environment.reflected_light_source != reflect:
		environment.reflected_light_source = reflect


# Height fog of the valley fog layer (per metre below its top) for a layer of this strength, the eye `eye_in` inside it (0 above the
# top .. 1 below it). Godot's height fog whitens a point by its depth below the top, not by the distance to it, so seen from inside
# the layer it would whiten the grass at your feet as much as the far valley: inside, it steps aside and the distance fog carries
# the mist. Stepping aside follows where the eye is, not the layer's strength: scaled by strength (as before 14 Nov 2026), a thinning
# morning mist (strength 0.3 to 0.8) left 0.013 to 0.02 per metre on, and 30 m down in a valley everything near was a third to a half
# white under a clear sky (Dave's shots, 14 Nov 2026).
static func layer_height_density(strength: float, eye_in: float) -> float:
	return MIST_HEIGHT_DENSITY * clampf(strength, 0.0, 1.0) * (1.0 - clampf(eye_in, 0.0, 1.0))


# The sky shader's faint sun or moon disc through deep fog: sent in steps, since a changed sky parameter can redraw the sky's lighting.
func _send_fog_veil(sky_material: ShaderMaterial) -> void:
	var veil: float = snappedf(fog_sky, 0.05)

	if sky_material != null and veil != _fog_veil_sent:
		_fog_veil_sent = veil
		sky_material.set_shader_parameter("fog_veil", veil)
		sky_material.set_shader_parameter("fog_disc", FogLook.DISC)
		sky_material.set_shader_parameter("fog_disc_rad", deg_to_rad(FogLook.DISC_DEG))


# Share of the sun and sky light that reaches the player at this rock enclosure (0 open air .. 1 a tunnel).
static func cave_light(rock_enclosure: float, left: float = CAVE_LIGHT_DARK) -> float:
	var shut: float = smoothstep(CAVE_DARK_FROM, CAVE_DARK_FULL, rock_enclosure)
	return lerpf(1.0, left, shut)


# Dino's #603 fog_above shot: the hill standing above the layer was washed snow-white, because in mist the fog colour turns white and the
# ordinary distance haze took it. Above a valley fog the air is clear, so the haze thins there; the layer itself is height fog and stays white.
static func above_clear(mist: float, inside: float) -> float:
	return lerpf(1.0, MIST_ABOVE_CLEAR, clampf(mist, 0.0, 1.0) * (1.0 - clampf(inside, 0.0, 1.0)))


# Cave light: the same from the mouth. `view` is the share of the view rays that reach open air, `bends` 0 (mouth in view), 1 or 2
# (two or more), `deep` the least left (the setting: 0 Dark, CAVE_LIGHT_NORMAL_DEEP Normal).
static func cave_light_view(rock_enclosure: float, view: float, bends: int, deep: float) -> float:
	var shut: float = smoothstep(CAVE_DARK_FROM, CAVE_DARK_FULL, rock_enclosure)
	var lit: float = clampf(view * CAVE_VIEW_GAIN, 0.0, 1.0) if bends <= 0 else (CAVE_BEND_LIGHT if bends == 1 else 0.0)
	return lerpf(1.0, maxf(lit, deep), shut)


# The light as the eyes see it: dark-adapted eyes lift what light there is, up to CAVE_ADAPT_CAP and never more than the open air; none stays none.
static func adapted_light(light: float, adapt: float) -> float:
	if light >= CAVE_ADAPT_CAP:
		return light

	return minf(light * (1.0 + CAVE_ADAPT_LIFT * clampf(adapt, 0.0, 1.0)), CAVE_ADAPT_CAP)


# Fire smoke (fire_smoke_wind_design.md): the wind 0..1 in m/s (Jamie's wind page #637: 20 x wind^1.3).
static func fire_wind_ms(wind: float) -> float:
	return 20.0 * pow(clampf(wind, 0.0, 1.0), 1.3)


# 0 .. 1: a still, clear night, when smoke stops at the cold layer and spreads flat. From about an hour after sunset to an hour after
# sunrise (`elevation` the sin of the sun's height), little cloud, little wind. The same shares as the sound outdoors work.
static func still_night(elevation: float, hour: float, cloud: float, wind: float) -> float:
	var night: float = 1.0 - smoothstep(0.02, 0.17, elevation) if hour < 12.0 else 1.0 - smoothstep(-0.17, -0.02, elevation)
	return night * (1.0 - smoothstep(0.3, 0.5, cloud)) * (1.0 - smoothstep(0.2, 0.35, wind))


# The same grading the sky shader applies, so the fog meets the sky's horizon.
static func _graded(color: Color, g: float) -> Color:
	var grey: float = (color.r + color.g + color.b) / 3.0 * (1.0 - 0.6 * g)
	return color.lerp(Color(grey, grey, grey), 0.85 * g)


func _update_ground(rain: float, snow: float) -> void:
	var wet: float = rain
	var lying: float = snow

	if _client.sound != null and _client.sound.weather != null:
		# The ground remembers the weather (soaks, dries slowly, snow settles and melts).
		wet = float(_client.sound.weather.ground_wet)
		lying = float(_client.sound.weather.ground_snow)

	var material: ShaderMaterial = _client.terrain.material as ShaderMaterial

	if material != null:
		material.set_shader_parameter("wet", wet)
		material.set_shader_parameter("snow", lying)
		material.set_shader_parameter("canopy", canopy.texture)
		# Moving cloud shadows on the ground: off at Low, weaker the more overcast (the sun is already dimmed then).
		var drift: float = float(Time.get_ticks_msec()) / 1000.0
		material.set_shader_parameter("cloud_shade", Vector4((1.0 - 0.8 * cloud_cover) if _quality >= 1 else 0.0, drift * 9.0, drift * 4.0, lerpf(0.62, 0.30, cloud_cover)))

		if _client._sun != null:
			material.set_shader_parameter("sun_toward", _client._sun.global_transform.basis.z.normalized())
		material.set_shader_parameter("canopy_box", Vector3(canopy.origin.x, canopy.origin.y, canopy.METRES))

	if _client.grass != null:
		_client.grass.visible = lying < 0.5      # snow buries the grass

	# Firelight in fog and snow (firelight_weather_design.md): reach and halo of every fire light, once a second.
	if Time.get_ticks_msec() >= _fire_light_next_msec:
		_fire_light_next_msec = Time.get_ticks_msec() + 1000
		FireWeather.update(get_tree(), mist_inside, snow, lying, 1.0 - day.night)   # any fog at the eye, valley or sea (mist_inside has the strength in it)

	# Snow on the branches and crowns (art_weather_light.md 8.2.2): the crowns keep their own memory, which holds in frost and sheds in a
	# thaw or a strong wind, never more than the ground's.
	_update_crown_snow(snow, lying)


# Snow that holds and sheds (docs/design/trees_weather_design.md part C, Jamie #675 "Snow on trees"; always on since Dave's 8 Nov ruling). Conifers catch
# about half a snowfall and hold it for weeks in frost, losing about 1 % a game hour; above 0 °C or in a wind over 8 m/s they
# shed it within about 3 game hours. Bare broadleaves hold a thin line only (0.35); in leaf they load like a conifer.
# Crown snow is never more than its share of the ground's snow memory (weather_sounds.gd), so a tree is never white over bare ground.
const CROWN_CONIFER_CAP := 0.5
const CROWN_BARE_CAP := 0.35
const CROWN_FROST_KEEP := 0.99         # share kept each game hour in frost
const CROWN_SHED_TAU_H := 1.0          # thaw or wind: e-folding time in game hours (0.5 -> 0.025 after 3 h)
const CROWN_SHED_WIND_MS := 8.0
const CROWN_FALLING := 0.05            # eased snow above this loads the crowns
var crown_snow_conifer: float = 0.0
var crown_snow_broad: float = 0.0
var _crown_next_msec: int = 0
var _crown_last_msec: int = 0
var _crown_sent: Vector2 = Vector2(-1.0, -1.0)


# One step of one crown kind's snow: value now, its cap, the ground's snow memory (0..1), the eased falling snow (0..1), air
# temperature, wind in m/s and the game hours since the last step.
static func crown_snow_step(value: float, cap: float, ground: float, falling: float, temp_c: float, wind_mps: float, hours: float) -> float:
	var top: float = cap * clampf(ground, 0.0, 1.0)

	if wind_mps > CROWN_SHED_WIND_MS or (temp_c > 0.0 and falling <= CROWN_FALLING):
		value *= exp(-hours / CROWN_SHED_TAU_H)
	elif falling > CROWN_FALLING:
		value = maxf(value, top)
	else:
		value *= pow(CROWN_FROST_KEEP, hours)

	return clampf(minf(value, top), 0.0, 1.0)


func _update_crown_snow(falling: float, ground: float) -> void:
	if _client.flora == null:
		return

	var now_msec: int = Time.get_ticks_msec()

	if now_msec < _crown_next_msec:
		return

	_crown_next_msec = now_msec + 1000
	var hours: float = 0.0 if _crown_last_msec == 0 else float(now_msec - _crown_last_msec) / 1000.0 * GameClock.RATIO / 3600.0
	_crown_last_msec = now_msec
	var temp_c: float = 10.0
	var crown_wind: float = wind_ms(float(_s["wind"]))

	if _client.sound != null and _client.sound.weather != null:
		temp_c = float(_client.sound.weather.temp_c)

	var broad_cap: float = CROWN_BARE_CAP if str(_client.flora.season) == "winter" else CROWN_CONIFER_CAP
	crown_snow_conifer = crown_snow_step(crown_snow_conifer, CROWN_CONIFER_CAP, ground, falling, temp_c, crown_wind, hours)
	crown_snow_broad = crown_snow_step(crown_snow_broad, broad_cap, ground, falling, temp_c, crown_wind, hours)
	var now: Vector2 = Vector2(crown_snow_conifer, crown_snow_broad)

	if absf(now.x - _crown_sent.x) > 0.01 or absf(now.y - _crown_sent.y) > 0.01:
		_crown_sent = now
		_client.flora.set_snow_kinds(now.x, now.y)


# Trees sway by the eased world wind (trees_weather_design.md part A), once a second. Wind in m/s = 20 x wind^1.3 (#637).
var _tree_wind_next_msec: int = 0


static func tree_wind_ms(wind: float) -> float:
	return 20.0 * pow(clampf(wind, 0.0, 1.0), 1.3)


func _update_tree_wind() -> void:
	if _client == null or _client.flora == null:
		return

	var now_msec: int = Time.get_ticks_msec()

	if now_msec < _tree_wind_next_msec:
		return

	_tree_wind_next_msec = now_msec + 1000
	var world: Dictionary = _client.weather if _client.weather is Dictionary else {}
	_client.flora.set_wind(tree_wind_ms(float(_s["wind"])), float(world.get("wind_dir", 0.0)))


func _exit_tree() -> void:
	if summits != null:
		summits.finish()


# The summits near the player (found on a worker thread), the summit snow line on the ground, and the cap clouds.
func _update_summits(delta: float, heading: float) -> void:
	if _client.world.is_empty():
		return

	if not _summits_set:
		_summits_set = true
		summits.setup(_client.world)

	var eye: Vector3 = _client.camera.global_position
	summits.update(eye)
	cap_cloud.update(delta, float(_s["cloud"]), float(_s["rain"]), float(_s["storm"]), float(_s["wind"]), Vector2(cos(heading), sin(heading)), summits)
	var now: int = Time.get_ticks_msec()

	if now < _summit_next_msec:
		return

	_summit_next_msec = now + 1000
	var top: Vector3 = summits.highest_near(eye, SUMMIT_NEAR_M)
	var phase: float = WeatherRules.year_phase(float(_client.game_clock.seconds)) * 4.0 - 0.5
	var from: int = posmod(int(floor(phase)), 4)
	var share: float = lerpf(float(SUMMIT_SNOW_SHARE[from]), float(SUMMIT_SNOW_SHARE[(from + 1) % 4]), smoothstep(0.0, 1.0, phase - floor(phase)))
	var want: Vector2 = Vector2(top.y, share)
	var material: ShaderMaterial = _client.terrain.material as ShaderMaterial

	if material != null and (absf(want.x - summit_snow.x) > 1.0 or absf(want.y - summit_snow.y) > 0.002):
		summit_snow = want
		material.set_shader_parameter("summit_snow", want)


func _update_particles(rain: float, snow: float, wind: float) -> void:
	var eye: Vector3 = _client.camera.global_position
	var under: bool = _client.underwater
	var tilt: float = wind * 0.4
	_rain.global_position = eye + Vector3(0.0, 12.0, 0.0)
	_snow.global_position = eye + Vector3(0.0, 10.0, 0.0)
	wind_cue.update(get_process_delta_time(), eye, _client.weather, rain, snow, under, 1.0 - day.night)
	# BUG-009 (Dave's QA list, 3 Nov 2026): rain showed inside caves. The particles fall from above the eye, so under rock they would fall through it;
	# they thin out under an overhang and stop in a cave, the same rock enclosure that dims the light.
	var enclosed: float = _client.sound.cave.rock_enclosure if _client.sound != null and _client.sound.cave != null else 0.0
	var open_sky: float = sky_share(enclosed)
	var sheltered: bool = open_sky <= 0.0
	_rain.emitting = rain > 0.04 and not under and not sheltered
	_snow.emitting = snow > 0.04 and not under and not sheltered
	# Falling streaks still in the air when you dive read as light rays fanned overhead (Dave's underwater shot, 2 Nov 2026).
	_rain.visible = not under and not sheltered
	_snow.visible = not under and not sheltered
	_rain.amount_ratio = clampf(rain * open_sky, 0.05, 1.0)
	# Streak size and strength follow how hard it rains (and the storm): drizzle fine, short and faint; a storm long, thick and denser.
	var hard: float = clampf(maxf(rain, float(_s.get("storm", 0.0))), 0.0, 1.0)
	_rain_material.set_shader_parameter("size_scale", Vector2(lerpf(0.55, 1.7, hard), lerpf(0.5, 1.4, hard)))
	_rain_material.set_shader_parameter("streak", Color(0.78, 0.84, 0.95, lerpf(0.10, 0.26, hard)))
	_snow.amount_ratio = clampf(snow * open_sky, 0.05, 1.0)

	_update_rain_look(eye, hard, float(_client.weather.get("wind_dir", 0.0)) if _client.weather is Dictionary else 0.0)
	_update_splash(rain if _rain.emitting else 0.0, open_sky)
	var sun_now: float = clampf(1.0 - float(_s["cloud"]) * 1.1, 0.0, 1.0) * smoothstep(0.0, 0.2, day.elevation)
	var stands: Dictionary = _client.sound.treewind._density if _client.sound != null and _client.sound.get("treewind") != null else {}
	var conifer: float = float(stands.get("conifer", 0.0))
	var broad: float = float(stands.get("broadleaf", 0.0))
	drips.conifer_share = conifer / (conifer + broad) if conifer + broad > 0.01 else 0.0
	drips.winter = _client.flora != null and str(_client.flora.season) == "winter"

	drips.update(get_process_delta_time(), rain, wind, sun_now, eye, canopy, Callable(_client, "_ground_below"), under or sheltered)

	if _client.sound != null and _client.sound.weather != null:
		_client.sound.weather.canopy_drip = drips.store   # the drip sound after the rain (canopy_drip_design.md)

	if _snow.emitting:
		(_snow.process_material as ParticleProcessMaterial).direction = Vector3(tilt * 0.8, -1.0, tilt * 0.3).normalized()


# Flash level over time: a hard first pulse, a flicker, a softer return.
static func _flash_level(t: float) -> float:
	var a: float = exp(-t * 14.0)
	var b: float = 0.7 * exp(-absf(t - 0.14) * 22.0)
	var c: float = 0.9 * exp(-absf(t - 0.27) * 12.0)
	return clampf(maxf(a, maxf(b, c)), 0.0, 1.0)


# A strike: `at` is the offset from the player, as the sound stage reports it.
func _on_lightning(at: Vector3, distance_m: float) -> void:
	strikes_seen += 1
	_flash_t = 0.0
	_flash_scale = clampf(1.3 - distance_m / 3500.0, 0.3, 1.0)
	var eye: Vector3 = _client.camera.global_position
	var world: Vector3 = Vector3(eye.x + at.x, eye.y - 1.0, eye.z + at.z)
	flash_started.emit(world, distance_m)

	if _quality >= BOLT_FROM and distance_m < 3200.0:
		_bolt.mesh = _make_bolt(world, eye, distance_m)
		_bolt.global_transform = Transform3D.IDENTITY
		_bolt.visible = true


# A jagged ribbon from the cloud base down to `ground`, with two forks, facing the camera.
func _make_bolt(ground: Vector3, eye: Vector3, distance_m: float) -> ArrayMesh:
	var top: Vector3 = Vector3(ground.x + _rng.randf_range(-0.15, 0.15) * distance_m, maxf(1400.0, eye.y + 900.0), ground.z + _rng.randf_range(-0.15, 0.15) * distance_m)
	var width: float = maxf(0.5, distance_m * 0.0035)
	var vertices: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var main: Array = _jagged(top, ground, 16, 40.0 + 0.02 * distance_m)
	_ribbon(vertices, indices, main, eye, width)

	for k in range(2):
		var from: Vector3 = main[_rng.randi_range(4, 11)]
		var drift: Vector3 = Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)).normalized() * _rng.randf_range(0.1, 0.25) * (top.y - ground.y)
		var to: Vector3 = from + drift + Vector3(0.0, -_rng.randf_range(0.2, 0.4) * (top.y - ground.y), 0.0)
		_ribbon(vertices, indices, _jagged(from, to, 7, 30.0 + 0.015 * distance_m), eye, width * 0.45)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _jagged(from: Vector3, to: Vector3, steps: int, amount: float) -> Array:
	var points: Array = [from]

	for i in range(1, steps):
		var p: Vector3 = from.lerp(to, float(i) / float(steps))
		p += Vector3(_rng.randf_range(-1.0, 1.0), 0.0, _rng.randf_range(-1.0, 1.0)) * amount
		points.append(p)

	points.append(to)
	return points


static func _ribbon(vertices: PackedVector3Array, indices: PackedInt32Array, points: Array, eye: Vector3, width: float) -> void:
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var side: Vector3 = (b - a).cross(eye - (a + b) * 0.5)

		if side.length() < 0.0001:
			continue

		side = side.normalized() * width * 0.5
		var first: int = vertices.size()
		vertices.append_array([a - side, a + side, b + side, b - side])
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])


# How much of the ground around a point is under crowns (or roofs), 0 open .. 1 closed: the canopy map at the point and at
# eight points CANOPY_SAMPLE_M round it, averaged, so one crown overhead in a meadow counts for little and a forest for all.
func canopy_density(x: float, z: float) -> float:
	if canopy == null:
		return 0.0

	var total: float = canopy.cover_at(x, z)

	for i in 8:
		var a: float = TAU * float(i) / 8.0
		total += canopy.cover_at(x + cos(a) * CANOPY_SAMPLE_M, z + sin(a) * CANOPY_SAMPLE_M)

	return total / 9.0


# True while a burning torch or lantern is held in either hand (the flame sounds already track it, held_item.gd).
func held_flame() -> bool:
	return _client.sound != null and _client.sound.flame != null and str(_client.sound.flame.held) != ""


# The shared cover query (canopy only so far): 0 in the open, 1 under a tree's crown; for sound,
# fire and building placement. Valid within about 64 m of the player.
func cover_at(world: Vector3) -> float:
	return canopy.cover_at(world.x, world.z)
