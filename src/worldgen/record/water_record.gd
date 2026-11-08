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


# --- the island water record (R6, Sonny's tools/watershed/record.py; docs/water/stage_e_readers_design.md 6b) ---
# One instance opens one world's <world>/record/: the manifest (versions, completeness, the field table), network.json (island-wide
# vectors, never clipped at a seam) and climate.json, and reads the per-tile rasters on demand, decoded by the manifest's field table.

const RECORD_VERSIONS := [1]
const TYPE_BYTES := {"f4": 4, "u1": 1, "u2": 2, "i4": 4}
const KEEP_TILES := 9              # rasters of at most this many tiles stay decoded (a bake frame's tile and its eight neighbours)
const POINT_KEYS := ["pos", "mouth", "lip", "spill"]
const LINE_KEYS := ["polyline", "outline"]

var dir: String = ""
var manifest: Dictionary = {}
var network: Dictionary = {}
var climate_rows: Dictionary = {}
var fields: Dictionary = {}        # name -> the manifest's field row {name, type, file, scale?, nodata?, codes_per_decade?}
var samples: int = 0               # per tile edge (tile_samples: T + 1, shared edges)
var tile_rect: Array = []          # [x0, z0, x1, z1] tile indices the record covers
var _cache: Dictionary = {}        # "tx_tz/name" -> PackedFloat32Array
var _cache_tiles: Array = []       # tile keys, oldest first
var _reach_by_id: Dictionary = {}


# Opens a record. Returns an error text, or "" when it loaded. A bake never opens an incomplete record (#622 writes complete false
# until R5's rivers exist); tools and tests may, with allow_incomplete.
func open(record_dir: String, allow_incomplete: bool = false) -> String:
	dir = record_dir
	_cache = {}
	_cache_tiles = []
	var m: Variant = _json(dir + "/manifest.json")

	if typeof(m) != TYPE_DICTIONARY:
		return "no record manifest at " + dir

	manifest = m

	if not RECORD_VERSIONS.has(int(manifest.get("version", -1))):
		return "record version %s is not one this reader knows %s" % [str(manifest.get("version")), str(RECORD_VERSIONS)]

	if not bool(manifest.get("complete", false)) and not allow_incomplete:
		return "the record is not complete (missing: %s); the bake refuses it" % str(manifest.get("summary", {}).get("missing", []))

	samples = int(manifest.get("tile_samples", 0))
	tile_rect = manifest.get("tiles", [])

	if samples < 2 or tile_rect.size() != 4:
		return "the record manifest has no tile_samples or tiles"

	fields = {}

	for row in manifest.get("fields", []):
		if not TYPE_BYTES.has(str(row.get("type", ""))):
			return "field %s has an unknown type %s" % [str(row.get("name")), str(row.get("type"))]

		fields[str(row["name"])] = row

	var net: Variant = _json(dir + "/network.json")
	network = net if typeof(net) == TYPE_DICTIONARY else {}
	var cl: Variant = _json(dir + "/climate.json")
	climate_rows = cl if typeof(cl) == TYPE_DICTIONARY else {}
	_reach_by_id = {}

	for r in network.get("reaches", []):
		_reach_by_id[int(r.get("id", -1))] = r

	return ""


static func _json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null

	return JSON.parse_string(FileAccess.get_file_as_string(path))


func has_tile(tx: int, tz: int) -> bool:
	return tile_rect.size() == 4 and tx >= int(tile_rect[0]) and tz >= int(tile_rect[1]) and tx <= int(tile_rect[2]) and tz <= int(tile_rect[3])


# One raster of one tile, decoded by its field row: metres, m3/s and codes as floats, no-data as NAN. Empty when the tile or field is
# missing or the file has the wrong length (error_of says why).
var error_of: String = ""


func raster(tx: int, tz: int, name: String) -> PackedFloat32Array:
	var key: String = "%d_%d/%s" % [tx, tz, name]

	if _cache.has(key):
		return _cache[key]

	error_of = ""
	var out: PackedFloat32Array = PackedFloat32Array()

	if not has_tile(tx, tz) or not fields.has(name):
		error_of = "no %s for tile %d,%d" % [name, tx, tz]
		return out

	var row: Dictionary = fields[name]
	var typ: String = str(row["type"])
	var path: String = "%s/tiles/%d_%d/%s" % [dir, tx, tz, str(row.get("file", name + "." + typ))]
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var count: int = samples * samples

	if raw.size() != count * int(TYPE_BYTES[typ]):
		error_of = "%s is %d bytes, not %d" % [path, raw.size(), count * int(TYPE_BYTES[typ])]
		return out

	out = decode(row, raw, count)
	_keep(key, "%d_%d" % [tx, tz], out)
	return out


# Decodes raw little-endian samples by a manifest field row.
static func decode(row: Dictionary, raw: PackedByteArray, count: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(count)
	var typ: String = str(row["type"])
	var scale: float = float(row.get("scale", 1.0))
	var has_nodata: bool = row.has("nodata") and str(row["nodata"]) != "NaN"
	var nodata: float = float(row["nodata"]) if has_nodata else NAN
	var cpd: float = float(row.get("codes_per_decade", 0.0))

	for k in count:
		var v: float

		match typ:
			"f4":
				v = raw.decode_float(k * 4)
			"u1":
				v = float(raw[k])
			"u2":
				v = float(raw.decode_u16(k * 2))
			_:
				v = float(raw.decode_s32(k * 4))

		if cpd > 0.0:
			out[k] = 0.0 if v == 0.0 else pow(10.0, v / cpd - 4.0)   # log-coded discharge (m3/s); code 0 is no flow
		elif has_nodata and v == nodata:
			out[k] = NAN
		else:
			out[k] = v * scale

	return out


func _keep(key: String, tile: String, values: PackedFloat32Array) -> void:
	_cache[key] = values
	_cache_tiles.erase(tile)
	_cache_tiles.append(tile)

	while _cache_tiles.size() > KEEP_TILES:
		var old: String = _cache_tiles.pop_front()

		for k in _cache.keys():
			if str(k).begins_with(old + "/"):
				_cache.erase(k)


# The bake frame: the tile's raster with `margin` (under a tile) samples on every side taken from its neighbours (shared edges: the
# neighbour's sample `margin` in from its own edge is the frame's first). Beyond a missing neighbour the nearest edge sample repeats, and
# frame_gaps counts those samples so the bake can report them.
var frame_gaps: int = 0


func frame(tile: Vector2i, margin: int, name: String) -> PackedFloat32Array:
	var n: int = samples + 2 * margin
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n * n)
	frame_gaps = 0
	var step: int = samples - 1
	var own: PackedFloat32Array = raster(tile.x, tile.y, name)

	if own.is_empty():
		out.fill(NAN)
		return out

	var near: Dictionary = {}   # Vector2i offset -> that neighbour's raster (empty: missing, its samples come from this tile's edge)

	for dz in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			near[Vector2i(dx, dz)] = raster(tile.x + dx, tile.y + dz, name) if margin > 0 else own

	for j in n:
		var gj: int = j - margin   # sample index along z relative to this tile's first sample
		var dtz: int = -1 if gj < 0 else (1 if gj > step else 0)

		for i in n:
			var gi: int = i - margin
			var dtx: int = -1 if gi < 0 else (1 if gi > step else 0)
			var vals: PackedFloat32Array = near[Vector2i(dtx, dtz)]
			var li: int = gi - dtx * step
			var lj: int = gj - dtz * step

			if vals.is_empty():
				vals = own   # a missing neighbour: repeat this tile's nearest edge sample
				li = clampi(gi, 0, step)
				lj = clampi(gj, 0, step)
				frame_gaps += 1

			out[j * n + i] = vals[clampi(lj, 0, step) * samples + clampi(li, 0, step)]

	return out


# Features of one network list with a point in rect (world x, z). Nothing is clipped: a reach across a seam is the same object, one id.
func features_in(list: String, rect: Rect2) -> Array:
	var out: Array = []

	for f in network.get(list, []):
		if _touches(f, rect):
			out.append(f)

	return out


static func _touches(f: Dictionary, rect: Rect2) -> bool:
	for key in POINT_KEYS:
		var p: Variant = f.get(key)

		if p is Array and (p as Array).size() >= 2 and _in(rect, p):
			return true

	for key in LINE_KEYS:
		for p in f.get(key, []):
			if p is Array and _in(rect, p):
				return true

	for key in f:
		var k: String = str(key)

		if k.ends_with("_x") and f.has(k.substr(0, k.length() - 2) + "_z") and f[key] != null and f[k.substr(0, k.length() - 2) + "_z"] != null:
			if rect.has_point(Vector2(float(f[key]), float(f[k.substr(0, k.length() - 2) + "_z"]))):
				return true

	return false


# A point [x, z] or [x, y, z].
static func _in(rect: Rect2, p: Array) -> bool:
	var z: float = float(p[2]) if p.size() >= 3 else float(p[1])
	return rect.has_point(Vector2(float(p[0]), z))


func reaches_in(rect: Rect2) -> Array:
	return features_in("reaches", rect)


func falls_in(rect: Rect2) -> Array:
	return features_in("falls", rect)


func lakes_in(rect: Rect2) -> Array:
	return features_in("lakes", rect)


func springs_in(rect: Rect2) -> Array:
	return features_in("springs", rect)


func cave_springs_in(rect: Rect2) -> Array:
	return features_in("cave_springs", rect)


func pools_in(rect: Rect2) -> Array:
	return features_in("cold_air_pools", rect)


func reach(id: int) -> Dictionary:
	return _reach_by_id.get(id, {})


# The reach ids from `id` to the sea, following each reach's `down` (-1 or missing: the sea). Stops on a loop (a record fault).
func downstream(id: int) -> Array:
	var out: Array = []
	var at: int = id

	while _reach_by_id.has(at) and not out.has(at):
		out.append(at)
		at = int(_reach_by_id[at].get("down", -1))

	return out


# An island's climate (A4): its by_island row, else the default. The live temperature is Weather.air_c; this only hands the numbers over.
func climate(island: String) -> Dictionary:
	return climate_rows.get("by_island", {}).get(island, climate_rows.get("default", {}))
