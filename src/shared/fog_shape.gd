extends RefCounted

# The fog's distance shape (Dave's fog instruction, 14 Nov 2026: docs/design/FOG_DESIGN_DAVE.md), shared by the client's look
# (fog_look.gd, weather_look.gd) and the server's animal sight (Weather.fog_shape, server_animals.gd), so both see one fog.
#
# The shape (Dave: "within roughly 10 metres ... easy to see; 10-20 m increasingly noticeable; 20-40 m silhouettes; beyond that mostly
# obscured; no clear bubble, no wall"): Godot's depth fog, amount = pow(smoothstep(begin, end, distance), curve). With begin 0, end
# 60 m and curve 1 that is 7 % at 10 m, 26 % at 20 m, 50 % at 30 m, 74 % at 40 m and all of it from 60 m, with no edge anywhere.
# Exponential fog (the old way) cannot do this: thick enough to hide 40 m it already hides a third of 10 m.
# Clear air keeps the old haze: the same depth fog fitted to Godot's exponential haze (end 3.25 / density, curve 0.35, within 4.4 %
# of it everywhere), so a clear day looks as before and the fog grows out of it with no jump.

const DENSE_END_M := 60.0          # full fog (strength 1, standing inside): everything is gone by this distance (Dave's dense-fog targets)
const BEGIN_M := 0.0               # the fog starts at the eye, thin (no clear bubble)
const FOG_CURVE := 1.0             # 1: Dave's targets above. Under 1 thickens the near part, over 1 clears it
const HAZE_END_K := 3.25           # clear-air haze as depth fog: end = HAZE_END_K / Godot density
const HAZE_CURVE := 0.35           # and this curve (the fit to exponential haze)
const VISIBILITY_AMOUNT := 0.95    # the visibility number: where the fog takes 95 % (Koschmieder's 5 % threshold)


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


# Godot's depth fog amount at a distance (the same sum the engine and the water shader use).
static func amount(distance: float, d: Vector3) -> float:
	return pow(smoothstep(d.x, d.y, distance), d.z)


# The distance at which the fog takes this share (0..1) of what lies behind it: amount's inverse.
static func distance_at(share: float, d: Vector3) -> float:
	var t: float = pow(clampf(share, 0.0, 1.0), 1.0 / maxf(d.z, 0.01))
	# smoothstep's inverse: t = 3s^2 - 2s^3, s = 0.5 - sin(asin(1 - 2t) / 3)
	var s: float = 0.5 - sin(asin(clampf(1.0 - 2.0 * t, -1.0, 1.0)) / 3.0)
	return d.x + (d.y - d.x) * s


# Distance at which the depth fog reaches 95 % (one visibility number for the HUD, the animals' rules and checks).
static func visibility(d: Vector3) -> float:
	return distance_at(VISIBILITY_AMOUNT, d)


# How much of a figure can be made out at distance `distance` through this fog: all of it while the fog takes under `full_share` of it,
# none once it takes `gone_share`, straight between (server_animals.gd sight; animals.json weather.fog sight_full_fog, sight_gone_fog).
static func sight_share(distance: float, d: Vector3, full_share: float, gone_share: float) -> float:
	var near_m: float = distance_at(full_share, d)
	var far_m: float = distance_at(gone_share, d)
	return clampf((far_m - distance) / maxf(far_m - near_m, 0.01), 0.0, 1.0)
