extends RefCounted

# Where a player can drink (docs/design/drinking_water_design.md; Sonny's docs/water/springs_and_drinking_water.md). Pure rules, static, thread
# safe: the caller gives the water rows within reach and the moment (season, rain, air); this picks the cleanest open source, or says why
# not. No sickness: Dave's 21 Oct rule (sickness.json) has one kind of water, so the kind is carried only for the look and later rules.
#
# A row: {"kind": "spring" | "river" | "lake" | "brook" | "puddle" | "salt", "iced": bool (the ice rule at that spot, #616)}, and by kind:
#   spring: "dry_m3_s" (its August flow; 0 means it fails in a drought), "temp_c" (its water, about the year mean + 1)
#   brook:  "regime" (1 perennial, 2 intermittent, 3 ephemeral), "dry_ok" (this polyline row keeps baseflow in a drought),
#           "below_spring_m" (how far below its spring, INF without one), "q_m3_s", "width_m", "spring_c" (the spring's water)
# ctx: {"season", "rain_h_ago" (game hours since it last rained, INF never), "raining" (bool), "air_c"}

const ORDER := ["spring", "river", "lake", "brook", "puddle"]   # cleanest first (Sonny's physical order); salt is never picked
const RHO_C := 4.19e6   # J/m3K, water


# {"kind", "temp_c", "frozen"} for the source to drink from, or {"refused": "salt" | "dry"} when only salt or dry beds are in reach, or {}.
static func pick(cfg: Dictionary, rows: Array, ctx: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_rank: int = ORDER.size()
	var salt: bool = false
	var dry: bool = false

	for row in rows:
		var kind: String = str(row.get("kind", ""))

		if kind == "salt":
			salt = true
			continue

		var rank: int = ORDER.find(kind)

		if rank < 0 or rank >= best_rank:
			continue

		if not runs(cfg, row, ctx):
			dry = true
			continue

		best_rank = rank
		best = {"kind": kind, "temp_c": water_c(row, ctx), "frozen": frozen(cfg, row, ctx)}

	if not best.is_empty():
		return best

	if salt:
		return {"refused": "salt"}

	return {"refused": "dry"} if dry else {}


# Whether the water there runs now. A spring runs while its drought flow is above 0. A brook by regime: 1 always; 2 except in a dry summer
# (no rain for rain_memory_h); 3 only in rain or within flash_memory_h of it. In a dry summer a brook row runs only where its baseflow lasts.
static func runs(cfg: Dictionary, row: Dictionary, ctx: Dictionary) -> bool:
	var kind: String = str(row.get("kind", ""))

	if kind == "spring":
		return float(row.get("dry_m3_s", 1.0)) > 0.0 or str(ctx.get("season", "")) != "summer"

	if kind != "brook":
		return true

	var rain_h: float = float(ctx.get("rain_h_ago", INF))
	var raining: bool = bool(ctx.get("raining", false))
	var regime: int = int(row.get("regime", 1))

	if regime == 3:
		return raining or rain_h <= float(cfg.get("flash_memory_h", 6.0))

	var dry_summer: bool = str(ctx.get("season", "")) == "summer" and not raining and rain_h > float(cfg.get("rain_memory_h", 24.0))

	if not dry_summer:
		return true

	return regime == 1 or bool(row.get("dry_ok", false))


# The water's temperature: a spring's own; a brook below a spring cools toward the air over its open length; else the air, never under 0.
static func water_c(row: Dictionary, ctx: Dictionary) -> float:
	var air: float = float(ctx.get("air_c", 10.0))

	match str(row.get("kind", "")):
		"spring":
			return float(row.get("temp_c", air))
		"brook":
			if is_finite(float(row.get("below_spring_m", INF))):
				var spring_c: float = float(row.get("spring_c", air))
				var span: float = open_scale_m(row, 20.0)
				return air + (spring_c - air) * exp(-float(row["below_spring_m"]) / maxf(span, 0.01))

	return maxf(air, 0.0)


# Frozen over: a spring never; a brook below a spring past its open length on a frosty night (Sonny: x0 = lambda ln((Tw - Ta)/(0 - Ta)));
# any other water by the ice rule at that spot (row "iced").
static func frozen(cfg: Dictionary, row: Dictionary, ctx: Dictionary) -> bool:
	var kind: String = str(row.get("kind", ""))

	if kind == "spring":
		return false

	var air: float = float(ctx.get("air_c", 10.0))

	if kind == "brook" and is_finite(float(row.get("below_spring_m", INF))):
		if air >= 0.0:
			return false

		return float(row["below_spring_m"]) > open_length_m(row, air, float(cfg.get("night_h_w_m2k", 20.0)))

	return bool(row.get("iced", false))


# lambda = rho c Q / (h W): the metres over which a brook's water cools by a factor e toward the night air.
static func open_scale_m(row: Dictionary, h: float) -> float:
	return RHO_C * float(row.get("q_m3_s", 0.0)) / maxf(h * float(row.get("width_m", 1.0)), 0.01)


# x0: how far below its spring a brook stays open on a night at air_c (under 0); INF when the spring water is no warmer than 0.
static func open_length_m(row: Dictionary, air_c: float, h: float) -> float:
	var spring_c: float = float(row.get("spring_c", 0.0))

	if air_c >= 0.0:
		return INF

	if spring_c <= 0.0:
		return 0.0

	return open_scale_m(row, h) * log((spring_c - air_c) / (0.0 - air_c))
