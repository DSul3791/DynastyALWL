extends RefCounted

# The bake's one reader of the water (docs/water/stage_e_readers_design.md, Stage E). Every system that needs to know where the water is asks
# here, never works it out again. Steps M0 and M1 read today's tile water (tile_water.gd); at R6 the same functions read Sonny's island water
# record (record/manifest.json, network.json and the per-tile rasters), and the systems that call them do not change.

const LAKE := 2    # tile_water.gd and the record's class codes (0 none, 1 ocean, 2 lake, 3 perennial river; 4 to 10 wetlands and seasonal water)
const RIVER := 3
const FRESH_STEP_M := 2.0   # the tile file's fresh_m section: one raw step; 255 means FRESH_STEP_M * 255 m or more


# Distance (m) from each sample to the nearest perennial fresh water (a lake or a river cell), by a two-pass chamfer (steps 1 and sqrt 2) over
# the whole bake frame, so a tile's edge samples see the water beyond the edge and neighbouring tiles agree up to the frame margin.
# R6: the record's island-wide fresh_m raster replaces this.
static func fresh_distance(water_class: PackedByteArray, n: int, cell_m: float) -> PackedFloat32Array:
	var dist: PackedFloat32Array = PackedFloat32Array()
	dist.resize(n * n)
	dist.fill(INF)
	var diag: float = cell_m * sqrt(2.0)

	for k in n * n:
		if water_class[k] == LAKE or water_class[k] == RIVER:
			dist[k] = 0.0

	for j in range(n):
		for i in range(n):
			var k: int = j * n + i
			var d: float = dist[k]

			if i > 0:
				d = minf(d, dist[k - 1] + cell_m)

			if j > 0:
				d = minf(d, dist[k - n] + cell_m)

				if i > 0:
					d = minf(d, dist[k - n - 1] + diag)

				if i < n - 1:
					d = minf(d, dist[k - n + 1] + diag)

			dist[k] = d

	for j in range(n - 1, -1, -1):
		for i in range(n - 1, -1, -1):
			var k: int = j * n + i
			var d: float = dist[k]

			if i < n - 1:
				d = minf(d, dist[k + 1] + cell_m)

			if j < n - 1:
				d = minf(d, dist[k + n] + cell_m)

				if i < n - 1:
					d = minf(d, dist[k + n + 1] + diag)

				if i > 0:
					d = minf(d, dist[k + n - 1] + diag)

			dist[k] = d

	return dist


static func encode_fresh(dist: PackedFloat32Array) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(dist.size())

	# 255 is kept for "far": a distance of 255 steps or more, and INF (no fresh water in the frame). Finite distances round to 0..254, so 509 m
	# reads back as 508 m, not as far (round(254.5) is 255). int(INF) is not a number GDScript can clamp (it came out 0, "at the water"), so INF and
	# NAN are caught before the division.
	var far_m: float = FRESH_STEP_M * 255.0

	for k in dist.size():
		var d: float = dist[k]
		out[k] = 255 if not is_finite(d) or d >= far_m else clampi(int(round(d / FRESH_STEP_M)), 0, 254)

	return out


static func decode_fresh(raw: PackedByteArray) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(raw.size())

	for k in raw.size():
		out[k] = INF if raw[k] == 255 else float(raw[k]) * FRESH_STEP_M

	return out
