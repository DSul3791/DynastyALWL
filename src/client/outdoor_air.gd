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
# - Masking (3.4): rain and a gale hide small sounds past a mask distance (12 dB down over one more of it); big low sounds come through.
# - Rivers (3.7): river voices fade like a line out to 50 m (line_db; sound_occlusion.gd adds it for voices marked "air_line").
# - Fresh snow (3.5): far sounds 4 dB down and duller on fresh snow; the freshness lasts about 2 game days, faster gone in a thaw or rain.

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

const RAIN_MASK := [[0.15, 30.0], [0.4, 15.0], [0.7, 8.0], [1.0, 5.0]]   # rain -> metres past which small sounds are lost (Jamie's table)
const RAIN_MASK_FROM := 0.1             # no mask under this rain
const LEAVES_MASK := 0.7                # under crowns the rain on leaves is louder: the mask distance x this
const GALE_FROM := 0.5
const GALE_MASK_M := [60.0, 25.0]       # from wind 0.5 to 1.0
const MASK_DB := -12.0                  # past the mask distance, over one more of it
const SMALL_UNIT := [6.0, 15.0]         # unit_size: small sounds (fully masked) .. big low ones (never)
const SNOW_FRESH_H := 48.0              # fresh snow ages to settled over this many game hours
const SNOW_THAW_FASTER := 3.0           # above 0 C or in rain
const SNOW_FAR_DB := -4.0
const SNOW_CUT := 0.3
const LINE_REACH_M := 150.0             # a river reach's length until R7's record gives each its own (judged)
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


# Metres past which rain hides small sounds (INF none). `under_leaves` 0..1 under crowns.
static func rain_mask_m(rain: float, under_leaves: float = 0.0) -> float:
	if rain < RAIN_MASK_FROM:
		return INF

	var metres: float = float(RAIN_MASK[0][1])

	for k in range(1, RAIN_MASK.size()):
		var a: Array = RAIN_MASK[k - 1]
		var b: Array = RAIN_MASK[k]

		if rain >= float(a[0]):
			metres = lerpf(float(a[1]), float(b[1]), clampf((rain - float(a[0])) / (float(b[0]) - float(a[0])), 0.0, 1.0))

	return metres * lerpf(1.0, LEAVES_MASK, clampf(under_leaves, 0.0, 1.0))


static func gale_mask_m(wind: float) -> float:
	if wind < GALE_FROM:
		return INF

	return lerpf(float(GALE_MASK_M[0]), float(GALE_MASK_M[1]), smoothstep(GALE_FROM, 1.0, wind))


# 1 for a small sound (a step, a rustle, a thump) .. 0 for a big low one (a bear, a wolf, a fall, a bell), by its unit_size.
static func small_share(unit: float) -> float:
	return clampf((float(SMALL_UNIT[1]) - unit) / (float(SMALL_UNIT[1]) - float(SMALL_UNIT[0])), 0.0, 1.0)


static func mask_db(distance: float, mask_m: float, unit: float) -> float:
	if is_inf(mask_m):
		return 0.0

	return MASK_DB * smoothstep(mask_m, 2.0 * mask_m, distance) * small_share(unit)


# One step of the snow's freshness (1 just fallen .. 0 settled, crusted or wet) over `hours` of game time.
static func snow_fresh_step(fresh: float, hours: float, snowing: bool, temp_c: float, raining: bool) -> float:
	if snowing:
		return 1.0

	var faster: float = SNOW_THAW_FASTER if temp_c > 0.0 or raining else 1.0
	return maxf(fresh - hours / SNOW_FRESH_H * faster, 0.0)


static func snow_effect(distance: float, fresh: float, ground_snow: float) -> Vector2:
	var on: float = clampf(fresh, 0.0, 1.0) * clampf(ground_snow, 0.0, 1.0)
	return Vector2(SNOW_FAR_DB * on * smoothstep(50.0, 100.0, distance), 1.0 - SNOW_CUT * on * smoothstep(50.0, 100.0, distance))


# Rivers as a line (3.7): a long reach fades 3 dB a doubling, not 6, out to a third of its length, then as a point. Added to an
# inverse-distance voice of size `unit` (which falls 6 dB a doubling), so 10 log10(d / unit) up to that knee. Outside the +6 dB hold.
static func line_db(distance: float, unit: float, reach_m: float = LINE_REACH_M) -> float:
	if unit <= 0.0 or distance <= unit:
		return 0.0

	return 10.0 * log(minf(distance, reach_m / 3.0) / unit) / log(10.0)


# Everything for one voice. `air`: {"wind", "toward" (Vector2), "gust", "night", "calm", "fog", "temp_c", "forest"}, and from step 2
# "rain", "leaves" (under crowns 0..1), "snow_fresh", "ground_snow" (missing keys: none of it).
static func total(listener: Vector3, source: Vector3, unit: float, air: Dictionary) -> Vector2:
	var to: Vector3 = listener - source
	var distance: float = to.length()
	var w: Vector2 = wind_effect(Vector2(to.x, to.z), distance, float(air.get("wind", 0.0)), air.get("toward", Vector2.ZERO), float(air.get("gust", 0.0)))
	var n: Vector2 = night_effect(distance, float(air.get("night", 0.0)), float(air.get("calm", 0.0)), float(air.get("fog", 0.0)), unit)
	var snow: Vector2 = snow_effect(distance, float(air.get("snow_fresh", 0.0)), float(air.get("ground_snow", 0.0)))
	var mask_m: float = minf(rain_mask_m(float(air.get("rain", 0.0)), float(air.get("leaves", 0.0))), gale_mask_m(float(air.get("wind", 0.0))))
	var db: float = w.x + n.x + snow.x + forest_db(distance, float(air.get("forest", 0.0))) + mask_db(distance, mask_m, unit)
	var cut: float = w.y * n.y * snow.y * air_cutoff(distance, float(air.get("temp_c", 10.0)), float(air.get("fog", 0.0)))
	return Vector2(clampf(db, MIN_DB, MAX_DB), cut)
