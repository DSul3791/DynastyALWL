extends RefCounted

# Bog iron (Sonny, docs: water_flow_rules section 11, 10 Nov 2026). Groundwater that soaked through iron-bearing ground seeps out into a wetland,
# meets the air and leaves limonite under the turf. So a deposit can lie under a fen, marsh, swamp or bog sample of the baked tile (never under
# salt marsh, estuary, seasonal beds, rivers, lakes or the sea), most often at the wetland's edge, where the seeps come out. It is read from the
# tile's own water_class map with a hash of the world sample, so it needs no bake and the server, the client look and the tests all agree.
#
# cfg is digging.json "bog_iron": {"classes": {water class id: weight}, "chance", "edge_mult", "size": [min, max], "per_dig": [min, max],
# "regrow_game_days", "item", "seen_m", "first_find"}.
#
# A deposit key is the world sample "gi,gj" (tile sample plus the tile's first sample), so a sample on the shared edge of two tiles is one deposit.

const SECONDS_PER_GAME_DAY := 86400.0


# The deposit under world point (x, z) of a loaded tile (TileTerrainData), or {}: {"key": "gi,gj", "size": ore when full, "edge": bool}.
static func deposit_at(tile_data, x: float, z: float, cfg: Dictionary) -> Dictionary:
	if tile_data == null or tile_data.placeholder or tile_data.samples <= 0 or cfg.is_empty():
		return {}

	var k: int = tile_data.nearest(x, z)
	var side: int = tile_data.samples
	@warning_ignore("integer_division")
	var j: int = k / side
	var i: int = k % side
	return deposit_at_sample(tile_data.water_class, side, i, j, i + first_sample(tile_data.x0, tile_data.spacing_m), j + first_sample(tile_data.z0, tile_data.spacing_m), cfg)


# The world sample index of a tile's sample 0 along one axis.
static func first_sample(origin_m: float, spacing_m: float) -> int:
	return int(round(origin_m / maxf(spacing_m, 0.001)))


# The deposit on sample (i, j) of a side x side water_class map whose world sample is (gi, gj), or {}.
static func deposit_at_sample(water_class: PackedByteArray, side: int, i: int, j: int, gi: int, gj: int, cfg: Dictionary) -> Dictionary:
	if i < 0 or j < 0 or i >= side or j >= side or water_class.size() != side * side:
		return {}

	var weight: float = float(cfg.get("classes", {}).get(str(water_class[j * side + i]), 0.0))

	if weight <= 0.0:
		return {}

	var edge: bool = is_edge(water_class, side, i, j)
	var chance: float = float(cfg.get("chance", 0.0)) * weight * (float(cfg.get("edge_mult", 1.0)) if edge else 1.0)
	var h: int = hash([gi, gj, "bog_iron"])

	if float(h % 10000) >= 10000.0 * chance:
		return {}

	var size: Array = cfg.get("size", [6, 12])
	var low: int = int(size[0])
	var span: int = maxi(int(size[1]) - low + 1, 1)
	@warning_ignore("integer_division")
	var draw: int = h / 10000   # the hash's upper digits size the deposit; the lower four decided whether there is one
	return {"key": "%d,%d" % [gi, gj], "size": low + draw % span, "edge": edge}


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
