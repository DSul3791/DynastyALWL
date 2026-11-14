extends RefCounted

# How fog looks (Dave's fog instruction, 14 Nov 2026: docs/design/FOG_DESIGN_DAVE.md). Every number to tune the look is here, and
# the fog's distance shape (shared with the server's animal sight) is in src/shared/fog_shape.gd.
# weather_look.gd calls these each frame; it still owns the weather (mist, sea fog, their tops) and the haze.
#
# Cost: the depth fog, the sky hiding and the sun disc are a few values per frame (free). The volumetric part (High and up,
# docs: PRESETS) is the one that costs.

const FogShape := preload("res://src/shared/fog_shape.gd")

const DENSE_END_VOL_M := 70.0      # FogShape.DENSE_END_M on High and Ultra, where the drifting body (fog_volume.gd) adds its share on top

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


# The dense end for this preset: longer where the volumetric body adds to it.
static func dense_end(quality: int) -> float:
	return DENSE_END_VOL_M if bool(preset(quality)["volumetric"]) else FogShape.DENSE_END_M


# Which fog layer is the land layer at the eye: the one the eye is most inside (strength x how far below its top, eased over
# `edge` m), or, when the eye is above them all, the strongest. Tops and strengths in the same order.
static func pick_layer(eye_y: float, strengths: PackedFloat32Array, tops: PackedFloat32Array, edge: float) -> int:
	var best: int = 0
	var best_in: float = -1.0

	for k in range(strengths.size()):
		var inside: float = strengths[k] * smoothstep(-edge, edge, tops[k] - eye_y)

		if inside > best_in + 1e-6:
			best_in = inside
			best = k

	if best_in > 1e-6:
		return best

	for k in range(strengths.size()):
		if strengths[k] > strengths[best]:
			best = k

	return best


# Share of the sky hidden: the fog's strength at the eye times how much fog is overhead (metres between the eye and the layer's top).
static func sky_hide(fog: float, overhead_m: float) -> float:
	return SKY_HIDE_DEEP * clampf(fog, 0.0, 1.0) * (1.0 - exp(-maxf(overhead_m, 0.0) / OVERHEAD_M))


# Share of the sunlight left under that much hidden sky.
static func sun_keep(hidden: float) -> float:
	return 1.0 - SUN_DIM * clampf(hidden / SKY_HIDE_DEEP, 0.0, 1.0)
