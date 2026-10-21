extends RefCounted

# Ice on still water (River start thread, tech/ICE_DESIGN.md, approved by Technical direction
# 2026-10-21). A pure function of the game clock, the zone and the altitude, like weather: the
# server and every client compute the same number, so there is no traffic and nothing to save.
#
# The sheet thickens in freezing air and thins in warm air (hourly steps over the last
# LOOKBACK_DAYS game days): growth is the Stefan law, thickness squared rising with degree-hours of
# frost (about 19 cm after five days at -10 C), melting about 2.4 cm a day per degree above
# freezing. `cover` is thickness over WALK_M * 2: 0 open water, 0.5 a sheet that bears a person
# (10 cm), 1 a full sheet. Pond and lake ice always holds: at or above WALK_COVER you cannot fall in.

const Weather := preload("res://src/shared/weather.gd")

const LOOKBACK_DAYS := 30
const HOUR_S := 3600.0
const DAY_S := 86400.0
const FREEZE_K := 1.5e-5         # m2 per C-hour: thickness squared grows by 2 K per degree-hour of frost
const MELT_M_PER_C_H := 0.001    # m of ice lost per C-hour above freezing
const SEED_M := 0.02             # a new sheet starts this thick (open water freezes over)
const FULL_M := 0.2              # thickness at cover 1
const WALK_COVER := 0.5          # cover from which a sheet bears steps (10 cm)


# Ice cover 0..1 on still water at `altitude_m` in `zone_group` at game time `game_s`; `depth_m` is
# how deep the pond is (shallow water freezes faster than a deep lake).
static func cover(game_s: float, zone_group: String, altitude_m: float, depth_m: float = 3.0) -> float:
	var thickness: float = 0.0
	var k: float = FREEZE_K * lerpf(1.4, 0.8, clampf((depth_m - 1.0) / 9.0, 0.0, 1.0))
	var steps: int = LOOKBACK_DAYS * 24
	var start: float = game_s - float(steps) * HOUR_S

	for n in range(steps + 1):
		var temp: float = Weather.temp_at(start + float(n) * HOUR_S, zone_group, altitude_m)

		if temp < 0.0:
			var grown: float = maxf(thickness, SEED_M)
			thickness = sqrt(grown * grown + 2.0 * k * -temp)
		elif thickness > 0.0:
			thickness = maxf(thickness - MELT_M_PER_C_H * temp, 0.0)

	return clampf(thickness / FULL_M, 0.0, 1.0)


static func bears(cover_value: float) -> bool:
	return cover_value >= WALK_COVER
