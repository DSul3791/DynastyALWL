extends RefCounted

# Bog iron (Sonny, docs: water_flow_rules section 11, 10 Nov 2026). Groundwater that soaked through iron-bearing ground seeps out into a wetland,
# meets the air and leaves limonite under the turf. So it lies under fen, marsh, swamp and bog samples of the baked tile (never under salt marsh,
# estuary, seasonal beds, rivers, lakes or the sea), in runs along the wetland's wet edge, where the seeps come out.
#
# Fields, not single spots (Dave 21 Nov 2026: "if the bog had one spot it probably has a few"): the world is cut into field_m squares. A square
# either bears iron or not (field_chance, by a hash of the square). One that bears and holds at least min_wet wetland samples gets a cluster of
# patches round one seed sample at its wet edge: every wetland sample within spread_m of the seed is a candidate, edge samples and the richer
# classes first, and patches[0] + candidates / wet_per_patch of them are taken (at most patches[1]), spacing_m apart. A bigger wetland gives
# more candidates and so a bigger field. It is read from the tile's own water_class map with hashes of world samples, so it needs no bake and
# the server and the tests agree. PROVISIONAL numbers (BI-3, 21 Nov 2026): field_m 512, field_chance 0.5, min_wet 12, spread_m 64, patches 3 to 8,
# wet_per_patch 25, spacing_m 14, size 6 to 12 ore, radius_m 2.5 to 4.0 by size.
#
# cfg is digging.json "bog_iron": {"classes": {water class id: weight}, "field_m", "field_chance", "min_wet", "spread_m", "patches": [min, max],
# "wet_per_patch", "spacing_m", "size": [min, max], "radius_m": [min, max], "per_dig": [min, max], "regrow_game_days", "refill_game_days", "item",
# "seen_m", "first_find"}.
#
# A patch key is its world sample "gi,gj" (tile sample plus the tile's first sample). A field square lies inside one tile (field_m divides the
# tile size), so a patch belongs to one tile.

const SECONDS_PER_GAME_DAY := 86400.0
# The soil a silted hole is filled with, by water class: the wetland's own soil (fen and bog peat, swamp and marsh mud; water_classes.json).
# A fill sets only the soil channel (ground_ops.gd apply_op): the draw material stays the column's generated one (the fen, bog or swamp look,
# Layout.MATERIAL_FEN ..), so a filled hole looks like the wetland round it and digs as its soil.
const SILT_MATERIAL := {7: 6, 8: 6, 6: 16, 4: 16}   # fen, bog: peat 6; swamp, marsh: mud 16 (soils.json; Layout.WETLAND_SOIL)
const EDGE_FIRST := 0.25          # an edge sample's draw is scaled by this: the patches lie mostly along the wet edge, where the seeps come out


# The world field square holding world point (x, z).
static func field_of(x: float, z: float, cfg: Dictionary) -> Vector2i:
	var m: float = maxf(float(cfg.get("field_m", 512.0)), 1.0)
	return Vector2i(floori(x / m), floori(z / m))


# The patches of field square (fx, fz) on a loaded tile (TileTerrainData) that holds it: [{"key", "x", "z", "size", "r"}, ...], [] when the square
# bears none. The same every time for the same tile and cfg.
static func field(tile_data, fx: int, fz: int, cfg: Dictionary) -> Array:
	if tile_data == null or tile_data.placeholder or tile_data.samples <= 0 or cfg.is_empty():
		return []

	var h: int = hash([fx, fz, "bog_field"])

	if float(h % 10000) >= 10000.0 * float(cfg.get("field_chance", 0.5)):
		return []

	var spacing: float = maxf(tile_data.spacing_m, 0.001)
	var per: int = maxi(int(round(float(cfg.get("field_m", 512.0)) / spacing)), 1)
	return field_on_map(tile_data.water_class, tile_data.samples, first_sample(tile_data.x0, spacing), first_sample(tile_data.z0, spacing), fx * per, fz * per, per, spacing, cfg)


# The patches of the per x per samples from world sample (gi0, gj0) of a side x side water_class map whose sample 0 is world sample (ti0, tj0).
# No bearing roll here: field() makes it.
static func field_on_map(water_class: PackedByteArray, side: int, ti0: int, tj0: int, gi0: int, gj0: int, per: int, spacing: float, cfg: Dictionary) -> Array:
	if water_class.size() != side * side:
		return []

	var classes: Dictionary = cfg.get("classes", {})
	var wet: Array = []   # [gi, gj, edge, weight]

	for j in range(maxi(gj0 - tj0, 0), mini(gj0 - tj0 + per, side)):
		for i in range(maxi(gi0 - ti0, 0), mini(gi0 - ti0 + per, side)):
			var weight: float = float(classes.get(str(water_class[j * side + i]), 0.0))

			if weight > 0.0:
				wet.append([ti0 + i, tj0 + j, is_edge(water_class, side, i, j), weight])

	if wet.size() < int(cfg.get("min_wet", 12)):
		return []

	# The seed: the edge sample (any sample when the wetland has no dry edge in the square) with the lowest hash share for its weight.
	var origin: Array = []
	var best: float = INF

	for edge_only in [true, false]:
		for w in wet:
			if edge_only and not bool(w[2]):
				continue

			var s: float = float(hash([w[0], w[1], "bog_seed"]) % 10000) / 10000.0 / float(w[3])

			if s < best:
				best = s
				origin = w

		if not origin.is_empty():
			break

	var spread: float = float(cfg.get("spread_m", 64.0))
	var candidates: Array = []   # [score, gi, gj]

	for w in wet:
		var di: float = float(int(w[0]) - int(origin[0])) * spacing
		var dj: float = float(int(w[1]) - int(origin[1])) * spacing

		if di * di + dj * dj <= spread * spread:
			candidates.append([float(hash([w[0], w[1], "bog_patch"]) % 10000) / 10000.0 / float(w[3]) * (EDGE_FIRST if bool(w[2]) else 1.0), int(w[0]), int(w[1])])

	candidates.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and (a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]))))
	var counts: Array = cfg.get("patches", [3, 8])
	@warning_ignore("integer_division")
	var want: int = clampi(int(counts[0]) + candidates.size() / maxi(int(cfg.get("wet_per_patch", 25)), 1), int(counts[0]), int(counts[1]))
	var gap: float = float(cfg.get("spacing_m", 14.0))
	var size_range: Array = cfg.get("size", [6, 12])
	var low: int = int(size_range[0])
	var span: int = maxi(int(size_range[1]) - low + 1, 1)
	var radius_range: Array = cfg.get("radius_m", [2.5, 4.0])
	var patches: Array = []

	for c in candidates:
		if patches.size() >= want:
			break

		var ph: int = hash([c[1], c[2], "bog_size"])
		# A little off the sample, so the patches do not sit on the 8 m grid (at most a quarter of a sample, still on the wet sample).
		var x: float = float(c[1]) * spacing + (float((ph >> 8) % 100) / 100.0 - 0.5) * 0.5 * spacing
		var z: float = float(c[2]) * spacing + (float((ph >> 16) % 100) / 100.0 - 0.5) * 0.5 * spacing
		var clear: bool = true

		for p in patches:
			if Vector2(float(p["x"]) - x, float(p["z"]) - z).length() < gap:
				clear = false
				break

		if not clear:
			continue

		var size: int = low + ph % span
		var share: float = float(size - low) / float(maxi(span - 1, 1))
		patches.append({"key": "%d,%d" % [c[1], c[2]], "x": x, "z": z, "size": size, "r": lerpf(float(radius_range[0]), float(radius_range[1]), share)})

	return patches


# The world sample index of a tile's sample 0 along one axis.
static func first_sample(origin_m: float, spacing_m: float) -> int:
	return int(round(origin_m / maxf(spacing_m, 0.001)))


# The soil a dug hole at world point (x, z) of a loaded tile silts back in with (SILT_MATERIAL), or 0 when the point is not on a
# wetland class that can hold bog iron (cfg "classes"): only there does a dug hole silt back in (refill_game_days).
static func silt_material(tile_data, x: float, z: float, cfg: Dictionary) -> int:
	if tile_data == null or tile_data.placeholder or tile_data.samples <= 0 or tile_data.water_class.size() != tile_data.samples * tile_data.samples:
		return 0

	var cls: int = int(tile_data.water_class[tile_data.nearest(x, z)])
	return int(SILT_MATERIAL.get(cls, 0)) if float(cfg.get("classes", {}).get(str(cls), 0.0)) > 0.0 else 0


# A wetland sample with dry ground (class 0) among its 8 neighbours: where the seeps come out. Neighbours off the map do not count.
static func is_edge(water_class: PackedByteArray, side: int, i: int, j: int) -> bool:
	for dj in range(-1, 2):
		for di in range(-1, 2):
			var ni: int = i + di
			var nj: int = j + dj

			if (di == 0 and dj == 0) or ni < 0 or nj < 0 or ni >= side or nj >= side:
				continue

			if water_class[nj * side + ni] == 0:
				return true

	return false


# A deposit's saved row [ore left, game seconds it is counted to] brought up to now_s: one ore comes back every regrow_game_days, up to its
# size. The clock moves on only by the whole steps used, so nothing is lost between digs; a full deposit's clock starts again now (the
# first ore taken from it comes back regrow_game_days later). An untouched deposit has no row: pass [size, now_s].
static func regrown(row: Array, size: int, now_s: float, cfg: Dictionary) -> Array:
	var left: int = mini(int(row[0]), size)
	var since: float = float(row[1])
	var step: float = float(cfg.get("regrow_game_days", 3.0)) * SECONDS_PER_GAME_DAY

	if left >= size or step <= 0.0:
		return [size if step > 0.0 else left, now_s]

	var steps: int = int(floor((now_s - since) / step))

	if steps <= 0:
		return [left, since]

	left = mini(size, left + steps)
	return [left, now_s if left >= size else since + float(steps) * step]
