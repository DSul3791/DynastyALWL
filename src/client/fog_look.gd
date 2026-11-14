extends RefCounted

# How fog looks (Dave's fog instruction, 14 Nov 2026: docs/design/FOG_DESIGN_DAVE.md). Every number to tune the look is here.
# weather_look.gd calls these each frame; it still owns the weather (mist, sea fog, their tops) and the haze.
#
# The shape (Dave: "within roughly 10 metres ... easy to see; 10-20 m increasingly noticeable; 20-40 m silhouettes; beyond that mostly
# obscured; no clear bubble, no wall"): Godot's depth fog, amount = pow(smoothstep(begin, end, distance), curve). With begin 0, end
# 60 m and curve 1 that is 7 % at 10 m, 26 % at 20 m, 50 % at 30 m, 74 % at 40 m and all of it from 60 m, with no edge anywhere.
# Exponential fog (the old way) cannot do this: thick enough to hide 40 m it already hides a third of 10 m.
# Clear air keeps the old haze: the same depth fog fitted to Godot's exponential haze (end 3.25 / density, curve 0.35, within 4.4 %
# of it everywhere), so a clear day looks as before and the fog grows out of it with no jump.
#
# Cost: the depth fog, the sky hiding and the sun disc are a few values per frame (free). The volumetric part (Medium and up,
# docs: PRESETS) is the one that costs.

# --- the fog's shape ---
const DENSE_END_M := 60.0          # full fog (strength 1, standing inside): everything is gone by this distance (Dave's dense-fog targets)
const DENSE_END_VOL_M := 70.0      # the same on High and Ultra, where the drifting body (fog_volume.gd) adds its share on top
const BEGIN_M := 0.0               # the fog starts at the eye, thin (no clear bubble)
const FOG_CURVE := 1.0             # 1: Dave's targets above. Under 1 thickens the near part, over 1 clears it
const HAZE_END_K := 3.25           # clear-air haze as depth fog: end = HAZE_END_K / Godot density
const HAZE_CURVE := 0.35           # and this curve (the fit to exponential haze)

# --- the sky through the fog (Dave: deep fog hides the sky, stars and clouds; the sun or moon a soft faint disc; shallow ground fog
# leaves the sky visible) ---
const SKY_HIDE_DEEP := 0.94        # share of the sky hidden deep in full fog: a little is left, enough for the sun's disc
const OVERHEAD_M := 15.0           # fog this deep above the eye hides 63 % of what it can (1 - 1/e); 45 m hides 95 %
const SUN_DIM := 0.7               # share of the sunlight a full fog overhead takes: soft, weak shadows
const DISC := 0.35                 # brightness of the faint sun or moon disc through deep fog (over the fog colour)
const DISC_DEG := 1.6              # its soft radius in degrees

# --- per graphics preset (Dave 14 Nov 2026: "full on ultra setting but off on lowest setting") ---
# Low, Medium, High, Ultra.
#  weather: the weather fog (valley mist, sea fog, fog banks) is drawn. The clear-air haze and rain murk are always drawn (free).
#  sky: the fog hides the sky and dims the sun. volumetric: drifting fog with light halos (FogVolume), its froxel size and reach.
const PRESETS := [
	{"name": "Low", "weather": false, "sky": false, "volumetric": false, "vol_size": 0, "vol_depth": 0, "vol_length_m": 0.0},
	{"name": "Medium", "weather": true, "sky": true, "volumetric": false, "vol_size": 0, "vol_depth": 0, "vol_length_m": 0.0},
	{"name": "High", "weather": true, "sky": true, "volumetric": true, "vol_size": 48, "vol_depth": 48, "vol_length_m": 48.0},
	{"name": "Ultra", "weather": true, "sky": true, "volumetric": true, "vol_size": 64, "vol_depth": 96, "vol_length_m": 64.0},
]
# The lowest preset, until Dave says otherwise: "off" (his words: no weather fog drawn at all) or "distance" (the cheap distance
# fade only: no sky hiding, no layer seen from above), so a Low player does not see through fog that hides things from everyone else.
const LOW_WEATHER_FOG := "off"


static func preset(quality: int) -> Dictionary:
	return PRESETS[clampi(quality, 0, PRESETS.size() - 1)]


# Is the weather fog drawn at this preset? (Low follows LOW_WEATHER_FOG.)
static func weather_drawn(quality: int) -> bool:
	return bool(preset(quality)["weather"]) or (quality <= 0 and LOW_WEATHER_FOG == "distance")


# Does the fog hide the sky and the sun at this preset?
static func sky_drawn(quality: int) -> bool:
	return bool(preset(quality)["sky"])


# Depth fog end for the clear-air haze of this Godot exponential density (0: no haze).
static func haze_end(density: float) -> float:
	return HAZE_END_K / density if density > 1e-7 else 1e9


# The depth fog for haze of this exponential density and a fog of this strength at the eye (0 none .. 1 full and standing deep inside):
# [begin, end, curve]. The fog's end is the haze's end moved toward DENSE_END_M in log steps, so half strength sits halfway on a log
# scale (about 470 m in clear air) and a light mist leaves long views.
static func depth(density: float, fog: float, dense_end_m: float = DENSE_END_M) -> Vector3:
	var f: float = clampf(fog, 0.0, 1.0)
	var far: float = haze_end(density)
	var end_m: float = far * pow(minf(dense_end_m / far, 1.0), f) if far < 1e8 else (dense_end_m / maxf(f, 1e-4) if f > 0.0 else 1e9)
	return Vector3(BEGIN_M * f, maxf(end_m, BEGIN_M * f + 1.0), lerpf(HAZE_CURVE, FOG_CURVE, f))


# The dense end for this preset: longer where the volumetric body adds to it.
static func dense_end(quality: int) -> float:
	return DENSE_END_VOL_M if bool(preset(quality)["volumetric"]) else DENSE_END_M


# Godot's depth fog amount at a distance (the same sum the engine and the water shader use).
static func amount(distance: float, d: Vector3) -> float:
	return pow(smoothstep(d.x, d.y, distance), d.z)


# Distance at which the depth fog reaches 95 % (one visibility number for the HUD and checks; Koschmieder's 5 % threshold).
static func visibility(d: Vector3) -> float:
	var t: float = pow(0.95, 1.0 / maxf(d.z, 0.01))
	# smoothstep's inverse: t = 3s^2 - 2s^3, s = 0.5 - sin(asin(1 - 2t) / 3)
	var s: float = 0.5 - sin(asin(clampf(1.0 - 2.0 * t, -1.0, 1.0)) / 3.0)
	return d.x + (d.y - d.x) * s


# Share of the sky hidden: the fog's strength at the eye times how much fog is overhead (metres between the eye and the layer's top).
static func sky_hide(fog: float, overhead_m: float) -> float:
	return SKY_HIDE_DEEP * clampf(fog, 0.0, 1.0) * (1.0 - exp(-maxf(overhead_m, 0.0) / OVERHEAD_M))


# Share of the sunlight left under that much hidden sky.
static func sun_keep(hidden: float) -> float:
	return 1.0 - SUN_DIM * clampf(hidden / SKY_HIDE_DEEP, 0.0, 1.0)
