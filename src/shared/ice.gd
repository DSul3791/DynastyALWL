extends RefCounted

# Ice on still water (River start thread, tech/ICE_DESIGN.md, approved by Technical direction 2026-10-21; the day and night
# rules from Art, docs/design/still_water_ice.md, 8 Nov 2026). A pure function of the game clock, the zone and the altitude,
# like weather: the server and every client compute the same number, so there is no traffic and nothing to save.
#
# Hourly steps over the last LOOKBACK_DAYS game days of the air with its day and night swing, as the snow and ice layer reads it
# (Weather.snow_air_c: the air plus the island's snow_bias_c, OVERNIGHT_DECISIONS_8NOV.md row 21):
#   - the water first has to cool: it follows the air with a lag of WATER_LAG_SHALLOW_D (a 1 m pond) to WATER_LAG_DEEP_D
#     (a 10 m lake) days, and no ice forms until it is down to OPEN_UNTIL_C (a lake turns over at 4 C before it can freeze);
#   - then the sheet thickens in freezing air by the Stefan law (thickness squared rising with degree-hours of frost);
#   - it thins in warm air (MELT_M_PER_C_H per degree above freezing), and thin ice (under SUN_THIN_M) faster in daylight
#     (SUN_MELT_M_PER_H from SUN_FROM_HOUR to SUN_TO_HOUR), so a frosty night's thin shore ice is gone by early afternoon
#     above 2 C, while a thick winter sheet loses only a little each mild day.
# `cover` is thickness over FULL_M: 0 open water, 0.5 a sheet that bears a person (10 cm), 1 a full sheet. Pond and lake
# ice always holds: at or above WALK_COVER you cannot fall in.
#
# The sea never freezes (Art, 8 Nov 2026), except in the arctic zone, where salt water freezes at SEA_FREEZE_C: sea_cover.

const Weather := preload("res://src/shared/weather.gd")

const LOOKBACK_DAYS := 30
const HOUR_S := 3600.0
const DAY_S := 86400.0
const FREEZE_K := 1.5e-5         # m2 per C-hour: thickness squared grows by 2 K per degree-hour of frost
const MELT_M_PER_C_H := 0.001    # m of ice lost per C-hour above freezing
const SUN_MELT_M_PER_H := 0.004  # and this much more per daylight hour above freezing on thin ice (judged: a night's ice gone by early afternoon)
const SUN_THIN_M := 0.05         # only ice thinner than this takes the sun's melt (thin ice is dark and takes the sun in; a thick sheet is white)
const SUN_FROM_HOUR := 8.0
const SUN_TO_HOUR := 16.0
const SEED_M := 0.005            # a new skin of ice starts this thick (a frosty night's first film)
const FULL_M := 0.2              # thickness at cover 1
const WALK_COVER := 0.5          # cover from which a sheet bears steps (10 cm)
const OPEN_UNTIL_C := 4.0        # the water must be this cold before ice can form
const WATER_LAG_SHALLOW_D := 2.0 # days for the water to follow the air, a 1 m pond
const WATER_LAG_DEEP_D := 12.0   # and a 10 m lake
const SEA_FREEZE_C := -1.8       # salt water freezes here
const SEA_DEPTH_M := 12.0
const SEA_ZONES := ["arctic"]    # the only zones whose sea freezes (a cold island type may join later)


# Ice cover 0..1 on still water at `altitude_m` in `zone_group` at game time `game_s`; `depth_m` is
# how deep the pond is (shallow water cools and freezes faster than a deep lake). Pass the world seed: the cold spells come from it.
static func cover(game_s: float, zone_group: String, altitude_m: float = 0.0, depth_m: float = 3.0, seed_value: int = 0) -> float:
	return clampf(_thickness(game_s, zone_group, altitude_m, depth_m, 0.0, seed_value) / FULL_M, 0.0, 1.0)


# Ice cover 0..1 on the sea: always 0 outside SEA_ZONES.
static func sea_cover(game_s: float, zone_group: String, seed_value: int = 0) -> float:
	if not SEA_ZONES.has(zone_group):
		return 0.0

	return clampf(_thickness(game_s, zone_group, 0.0, SEA_DEPTH_M, SEA_FREEZE_C, seed_value) / FULL_M, 0.0, 1.0)


# The look's season (docs/design/frozen_water_look.md, client only): {"cover", "peak"}, the cover now and the thickest cover over the
# last LOOKBACK_DAYS. 1 - cover / peak is how far a thaw has gone (the shore moat opens first). The same loop as `cover`, so they always agree.
static func season(game_s: float, zone_group: String, altitude_m: float = 0.0, depth_m: float = 3.0, seed_value: int = 0) -> Dictionary:
	var run: Array = _run(game_s, zone_group, altitude_m, depth_m, 0.0, seed_value)
	return {"cover": clampf(float(run[0]) / FULL_M, 0.0, 1.0), "peak": clampf(float(run[1]) / FULL_M, 0.0, 1.0)}


static func _thickness(game_s: float, zone_group: String, altitude_m: float, depth_m: float, freeze_c: float, seed_value: int) -> float:
	return float(_run(game_s, zone_group, altitude_m, depth_m, freeze_c, seed_value)[0])


# [the thickness now, the thickest over the lookback], in metres (an Array, so the floats stay 64-bit and `cover` gives exactly what it gave).
static func _run(game_s: float, zone_group: String, altitude_m: float, depth_m: float, freeze_c: float, seed_value: int) -> Array:
	var deep: float = clampf((depth_m - 1.0) / 9.0, 0.0, 1.0)
	var k: float = FREEZE_K * lerpf(1.4, 0.8, deep)
	var lag_h: float = 24.0 * lerpf(WATER_LAG_SHALLOW_D, WATER_LAG_DEEP_D, deep)
	var steps: int = LOOKBACK_DAYS * 24
	var start: float = game_s - float(steps) * HOUR_S
	var water: float = maxf(Weather.snow_temp_at(start, zone_group, altitude_m, seed_value), freeze_c)
	var thickness: float = 0.0
	var peak: float = 0.0

	for n in range(steps + 1):
		var t: float = start + float(n) * HOUR_S
		var air: float = Weather.snow_air_c(t, zone_group, altitude_m, seed_value)   # the snow and ice layer's air: plus snow_bias_c (climate.gd)

		if thickness <= 0.0:
			water = maxf(water + (air - water) / lag_h, freeze_c)

		if air < freeze_c and (thickness > 0.0 or water <= OPEN_UNTIL_C + freeze_c):
			var grown: float = maxf(thickness, SEED_M)
			thickness = sqrt(grown * grown + 2.0 * k * (freeze_c - air))
		elif thickness > 0.0:
			var melt: float = MELT_M_PER_C_H * maxf(air - freeze_c, 0.0)
			var hour: float = Weather.hour_of(t)

			if hour >= SUN_FROM_HOUR and hour < SUN_TO_HOUR and thickness < SUN_THIN_M:
				melt += SUN_MELT_M_PER_H

			thickness = maxf(thickness - melt, 0.0)

		peak = maxf(peak, thickness)

	return [thickness, peak]


static func bears(cover_value: float) -> bool:
	return cover_value >= WALK_COVER
