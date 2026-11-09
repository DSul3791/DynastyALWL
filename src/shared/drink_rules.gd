extends RefCounted

# Where a player can drink (docs/design/drinking_water_design.md; Sonny's docs/water/springs_and_drinking_water.md). Pure rules, static, thread
# safe: the caller gives the water rows within reach and the moment (season, rain, air); this picks the cleanest open source, or says why
# not. No sickness: Dave's 21 Oct rule (sickness.json) has one kind of water, so the kind is carried only for the look and later rules.
#
# A row: {"kind": "spring" | "river" | "lake" | "brook" | "puddle" | "salt", "iced": bool (the ice rule at that spot, #616)}, and by kind:
#   spring: "dry_m3_s" (its August flow; 0 means it fails in a drought), "temp_c" (its water: the year mean at its height, Jamie #739)
#   brook:  "regime" (1 perennial, 2 intermittent, 3 ephemeral), "dry_ok" (this polyline row keeps baseflow in a drought),
#           "below_spring_m" (how far below its spring, INF without one), "q_m3_s", "width_m", "spring_c" (the spring's water)
# ctx: {"season", "rain_h_ago" (game hours since it last rained, INF never), "raining" (bool), "air_c", "wind" (0..1, the weather's)}

const ORDER := ["spring", "river", "lake", "brook", "puddle"]   # cleanest first (Sonny's physical order); salt is never picked
const RHO_C := 4.19e6   # J/m3K, water


# Spring rows from a tile's ground springs (TileTerrainData.ground_springs: [Vector3 head, m3_s, cover], the record's spring heads baked into the
# tile at R6) within reach of pos, measured level (docs/design/drinking_water_design.md 7, step 2a: no new bake). Until the baked drink rows give each
# spring its own dry flow (design 5, Sonny's addition 1), the head's flow stands in for it, so a head the record gave no flow fails in a dry summer.
# temp_c is mean_c.call(head): the year mean at the spring's height (Jamie #739), so it never freezes and drinks cool in summer.
static func ground_spring_rows(springs: Array, pos: Vector3, reach: float, mean_c: Callable) -> Array:
	var rows: Array = []

	for spring in springs:
		var head: Vector3 = spring[0]

		if Vector2(head.x - pos.x, head.z - pos.z).length() <= reach:
			rows.append({"kind": "spring", "dry_m3_s": float(spring[1]), "temp_c": float(mean_c.call(head))})

	return rows


# The source rows within reach of pos on one baked tile (TileTerrainData), for vitals.json thirst.sources: the terrain server's water_source
# and the drink_near check (src/worldgen/tools/drink_near.gd) both call this, so the check reads what the game reads. mean_c(height) is the
# year mean there (the caller's climate zone). At the same five points as water_near: a spring cave's stream is spring water; the record's
# ground springs are spring rows (step 2a); ocean and estuary cells are salt; a sample on a record channel (the tile's drink sections) is a
# brook by regime, which runs or lies dry by the season (runs) whatever the sim shows (step 2b); otherwise wet lake and river cells are lakes
# and rivers, and any other cell the live sim has wet is a puddle. No ice field: server_items puts its own ice rule (_on_ice) on each row.
static func tile_rows(tile_data, pos: Vector3, reach: float, mean_c: Callable) -> Array:
	var rows: Array = []

	if tile_data.placeholder or tile_data.water_class.is_empty():
		return rows

	if not tile_data.cave_streams.is_empty() and tile_data.near_cave_water(pos, reach):
		rows.append({"kind": "spring"})

	if not tile_data.ground_springs.is_empty():
		rows.append_array(ground_spring_rows(tile_data.ground_springs, pos, reach, func(head: Vector3) -> float: return float(mean_c.call(head.y))))

	var sim: PackedFloat32Array = tile_data.sim_snapshot()

	for offset in [Vector2.ZERO, Vector2(reach, 0.0), Vector2(-reach, 0.0), Vector2(0.0, reach), Vector2(0.0, -reach)]:
		var k: int = tile_data.nearest(pos.x + offset.x, pos.z + offset.y)
		var cls: int = int(tile_data.water_class[k])

		if cls == 1 or cls == 5:
			rows.append({"kind": "salt"})   # ocean, estuary (data/tables/water_classes.json)
			continue

		var brook: Dictionary = tile_data.drink_row(k, mean_c) if cls != 2 else {}

		if not brook.is_empty():
			rows.append(brook)
			continue

		var wet: bool = (not is_nan(sim[k])) if not sim.is_empty() else (cls > 1 and not is_nan(tile_data.water_surface[k]))

		if wet:
			rows.append({"kind": "lake" if cls == 2 else ("river" if cls == 3 else "puddle")})

	return rows


# The record's drink points in one flora chunk, for the client's E-to-drink prompt where the settled water shows nothing
# (docs/design/drink_prompt_design.md (a)): [cells, springs]. cells: PackedInt32Array of (gi, gj, kind) triplets, gi and gj the world sample
# grid (x = gi * spacing_m), kind 1 + the brook's regime, for every channel sample in the chunk that tile_rows makes a brook (not a lake, the
# sea or an estuary); springs: PackedFloat32Array of (x, z) pairs, the ground spring heads in the chunk. A client finds a brook by the same
# nearest-sample rule tile_rows uses, and a spring within reach of its head.
static func chunk_points(tile_data, origin: Vector2, chunk_m: float) -> Array:
	var cells: PackedInt32Array = PackedInt32Array()
	var springs: PackedFloat32Array = PackedFloat32Array()

	if tile_data.placeholder or tile_data.water_class.is_empty():
		return [cells, springs]

	var spacing: float = float(tile_data.spacing_m)

	if tile_data.has_drink():
		var n: int = int(tile_data.samples)
		var i0: int = clampi(ceili((origin.x - tile_data.x0) / spacing), 0, n - 1)
		var i1: int = clampi(ceili((origin.x + chunk_m - tile_data.x0) / spacing) - 1, 0, n - 1)
		var j0: int = clampi(ceili((origin.y - tile_data.z0) / spacing), 0, n - 1)
		var j1: int = clampi(ceili((origin.y + chunk_m - tile_data.z0) / spacing) - 1, 0, n - 1)
		var gi0: int = roundi(tile_data.x0 / spacing)
		var gj0: int = roundi(tile_data.z0 / spacing)

		for j in range(j0, j1 + 1):
			for i in range(i0, i1 + 1):
				var k: int = j * n + i
				var regime: int = tile_data.drink_regime_at(k)
				var cls: int = int(tile_data.water_class[k])

				if regime > 0 and cls != 1 and cls != 2 and cls != 5:
					cells.append_array([gi0 + i, gj0 + j, 1 + regime])

	for spring in tile_data.ground_springs:
		var head: Vector3 = spring[0]

		if head.x >= origin.x and head.x < origin.x + chunk_m and head.z >= origin.y and head.z < origin.y + chunk_m:
			springs.append_array([head.x, head.z])

	return [cells, springs]


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


# Frozen over: a spring never; a brook below a spring past its open length on a frosty night (open_length_m, Jamie #739) and only where
# the ice rule at that spot also says ice (row "iced", _on_ice: Kathleen #729, coordinator 8 Nov), so a hole is asked for only where the
# look shows a sheet; any other water by the ice rule at that spot.
static func frozen(cfg: Dictionary, row: Dictionary, ctx: Dictionary) -> bool:
	var kind: String = str(row.get("kind", ""))

	if kind == "spring":
		return false

	var air: float = float(ctx.get("air_c", 10.0))

	if kind == "brook" and is_finite(float(row.get("below_spring_m", INF))):
		if air >= 0.0:
			return false

		return bool(row.get("iced", false)) and float(row["below_spring_m"]) > open_length_m(cfg, row, air, float(ctx.get("wind", 0.0)))

	return bool(row.get("iced", false))


# lambda = rho c Q / (h W): the metres over which a brook's water cools by a factor e toward the air (Sonny), for its temperature.
static func open_scale_m(row: Dictionary, h: float) -> float:
	return RHO_C * float(row.get("q_m3_s", 0.0)) / maxf(h * float(row.get("width_m", 1.0)), 0.01)


# How far below its spring a brook stays open on a night at air_c (Jamie #739's game rule, a fit to the heat-loss sums within about 30%):
# open_m (440) x sqrt(flow in L/s) in calm air at -5 C, times cold_x by the air (1.8 at -2, 1.0 at -5, 0.6 at -10, 0.4 at -15, straight
# between, held past the ends), halved (breeze_x) at wind breeze_wind or more. INF above 0 C. A 2 L/s spring on the starter island's worst
# night (about -7.5 C) keeps 230 m (breeze) to 460 m (calm) open.
static func open_length_m(cfg: Dictionary, row: Dictionary, air_c: float, wind: float) -> float:
	if air_c >= 0.0:
		return INF

	var points: Array = cfg.get("cold_x", [[-2.0, 1.8], [-5.0, 1.0], [-10.0, 0.6], [-15.0, 0.4]])
	var x: float = float(points[0][1]) if air_c >= float(points[0][0]) else float(points[points.size() - 1][1])

	for k in points.size() - 1:
		var hi: Array = points[k]
		var lo: Array = points[k + 1]

		if air_c <= float(hi[0]) and air_c >= float(lo[0]):
			x = lerpf(float(hi[1]), float(lo[1]), (float(hi[0]) - air_c) / (float(hi[0]) - float(lo[0])))

	var length: float = float(cfg.get("open_m", 440.0)) * sqrt(maxf(float(row.get("q_m3_s", 0.0)) * 1000.0, 0.0)) * x
	return length * (float(cfg.get("breeze_x", 0.5)) if wind >= float(cfg.get("breeze_wind", 0.3)) else 1.0)
