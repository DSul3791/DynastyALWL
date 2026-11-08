extends RefCounted

# How the open air moves a world sound (docs/design/sound_outdoors_design.md, behind --sound-outdoors; client only).
# Pure functions: sound_occlusion.gd sums them for each world voice at its 0.5 s scan and moves the level through the
# player's unit_size (inverse distance: unit x k is exactly 20 log10 k dB at every distance), the cutoff through the
# scan's own target. Each returns Vector2(dB, cutoff factor). From Jamie's research page docs/knowledge/sound-outdoors.md.
#
# - Wind (3.1): past 50 m, a few dB up downwind, down crosswind, a deep shadow upwind that comes and goes with the gusts.
# - Night (3.2): clear calm nights carry far sounds 4.5 dB up (cold air at the ground bends them back down); a foggy
#   morning does the same at 60 % for big low sounds.
# - Forest (3.3): 10 dB per 100 m of trees around the listener, at most 18 dB.
# - Cold and fog (3.5): frost eats the far high end about twice as fast; fog trims it past 100 m. Near sounds stay crisp.

const NEAR_M := 50.0                    # closer than this the wind changes nothing
const FULL_M := 100.0                   # the wind's effect is full from here
const DOWN_DB := 3.0                    # listener downwind of the source
const CROSS_DB := -5.0
const UP_DB := [-10.0, -20.0]           # listener upwind: from wind 0.3 (4 m/s) to 0.6
const UP_CUT := 0.6                     # and the cutoff upwind
const UP_FAR_M := [224.0, 1000.0]       # far out turbulence scatters sound back into the shadow
const UP_FAR_KEEP := 0.6
const GUST_SCATTER := 0.35              # a full gust fills the shadow this much

const NIGHT_DB := 4.5
const NIGHT_M := [150.0, 300.0]         # the carry grows over this distance
const NIGHT_MAX_M := 2000.0
const NIGHT_CUT := 1.15
const FOG_CARRY := 0.6
const FOG_LOW_UNIT := 12.0              # only big low sounds (unit_size this or more) carry in fog

const FOREST_DB_PER_100 := -10.0
const FOREST_MAX_M := 300.0
const FOREST_FLOOR_DB := -18.0

const COLD_CUT := 0.55                  # the far cutoff in hard frost
const COLD_M := [100.0, 500.0]
const COLD_STRETCH := 0.8               # air bands: the effective distance grows by this much in hard frost
const FOG_CUT := 0.8
const FOG_M := [100.0, 150.0]

const MAX_DB := 6.0                     # the sum is held inside these
const MIN_DB := -30.0


# `from_source`: listener minus source on the ground (x, z). `toward`: where the wind blows toward (weather_look heading).
static func wind_effect(from_source: Vector2, distance: float, wind: float, toward: Vector2, gust: float) -> Vector2:
	if distance <= NEAR_M or wind <= 0.0 or from_source.length_squared() < 0.0001 or toward.length_squared() < 0.0001:
		return Vector2(0.0, 1.0)

	var c: float = clampf(from_source.normalized().dot(toward.normalized()), -1.0, 1.0)
	var fade: float = smoothstep(NEAR_M, FULL_M, distance)
	var down: float = DOWN_DB * smoothstep(0.05, 0.15, wind)
	var cross: float = CROSS_DB * smoothstep(0.1, 0.4, wind)
	var shadow: float = smoothstep(0.1, 0.3, wind)
	var up: float = lerpf(float(UP_DB[0]), float(UP_DB[1]), smoothstep(0.3, 0.6, wind)) * shadow
	up *= lerpf(1.0, UP_FAR_KEEP, smoothstep(float(UP_FAR_M[0]), float(UP_FAR_M[1]), distance)) * (1.0 - GUST_SCATTER * clampf(gust, 0.0, 1.0))

	if c >= 0.0:
		return Vector2(lerpf(cross, down, c) * fade, 1.0)

	return Vector2(lerpf(cross, up, -c) * fade, lerpf(1.0, UP_CUT, -c * shadow * fade))


# 0 day .. 1 night for the cold layer: from about an hour after sunset to an hour after sunrise. `elevation` is the sin of the sun's height.
static func night_share(elevation: float, hour: float) -> float:
	if hour < 12.0:
		return 1.0 - smoothstep(0.02, 0.17, elevation)

	return 1.0 - smoothstep(-0.17, -0.02, elevation)


static func calm_share(cloud: float, wind: float) -> float:
	return (1.0 - smoothstep(0.3, 0.5, cloud)) * (1.0 - smoothstep(0.2, 0.35, wind))


static func night_effect(distance: float, night: float, calm: float, fog: float, unit: float) -> Vector2:
	if distance > NIGHT_MAX_M:
		return Vector2(0.0, 1.0)

	var carry: float = clampf(night, 0.0, 1.0) * clampf(calm, 0.0, 1.0)

	if unit >= FOG_LOW_UNIT:
		carry = maxf(carry, FOG_CARRY * clampf(fog, 0.0, 1.0))

	carry *= smoothstep(float(NIGHT_M[0]), float(NIGHT_M[1]), distance)
	return Vector2(NIGHT_DB * carry, lerpf(1.0, NIGHT_CUT, carry))


static func forest_db(distance: float, forest: float) -> float:
	return maxf(FOREST_DB_PER_100 * clampf(forest, 0.0, 1.0) * minf(distance, FOREST_MAX_M) / 100.0, FOREST_FLOOR_DB)


# 0 at 10 C and warmer .. 1 at -5 C and colder.
static func cold_share(temp_c: float) -> float:
	return 1.0 - smoothstep(-5.0, 10.0, temp_c)


static func air_cutoff(distance: float, temp_c: float, fog: float) -> float:
	var cold: float = lerpf(1.0, COLD_CUT, cold_share(temp_c) * smoothstep(float(COLD_M[0]), float(COLD_M[1]), distance))
	return cold * lerpf(1.0, FOG_CUT, clampf(fog, 0.0, 1.0) * smoothstep(float(FOG_M[0]), float(FOG_M[1]), distance))


static func band_stretch(temp_c: float) -> float:
	return 1.0 + COLD_STRETCH * cold_share(temp_c)


# Everything for one voice. `air`: {"wind", "toward" (Vector2), "gust", "night", "calm", "fog", "temp_c", "forest"}.
static func total(listener: Vector3, source: Vector3, unit: float, air: Dictionary) -> Vector2:
	var to: Vector3 = listener - source
	var distance: float = to.length()
	var w: Vector2 = wind_effect(Vector2(to.x, to.z), distance, float(air.get("wind", 0.0)), air.get("toward", Vector2.ZERO), float(air.get("gust", 0.0)))
	var n: Vector2 = night_effect(distance, float(air.get("night", 0.0)), float(air.get("calm", 0.0)), float(air.get("fog", 0.0)), unit)
	var db: float = w.x + n.x + forest_db(distance, float(air.get("forest", 0.0)))
	var cut: float = w.y * n.y * air_cutoff(distance, float(air.get("temp_c", 10.0)), float(air.get("fog", 0.0)))
	return Vector2(clampf(db, MIN_DB, MAX_DB), cut)
