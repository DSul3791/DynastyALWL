extends RefCounted

# The bake's one reader of the water (docs/water/stage_e_readers_design.md, Stage E). Every system that needs to know where the water is asks
# here, never works it out again. Steps M0 and M1 read today's tile water (tile_water.gd); at R6 the same functions read Sonny's island water
# record (record/manifest.json, network.json and the per-tile rasters), and the systems that call them do not change.

const LAKE := 2    # tile_water.gd and the record's class codes (0 none, 1 ocean, 2 lake, 3 perennial river; 4 to 10 wetlands and seasonal water)
const RIVER := 3
const FRESH_STEP_M := 2.0   # the tile file's fresh_m section: one raw step; 255 means FRESH_STEP_M * 255 m or more

# For the island water record below. prepare(): every raster a threaded bake reads is decoded once, before the threads start, and
# nothing is written after, so the threads read the record at once with no lock (docs/water/generation_cost_audit.md, "The bake": the
# lock queued the tiles' record stage).
var _prepared: bool = false
var _problems: Dictionary = {}     # prepared: "tx_tz/name" -> why that raster is missing (a file of the wrong length, a field the record lacks)
var _code_lut: PackedFloat32Array = PackedFloat32Array()   # _code_to_id as floats, for decode


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
const KEEP_TILES := 9              # rasters of at most this many tiles stay decoded (a bake frame's tile and its eight neighbours); not when prepared
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
	_prepared = false
	_problems = {}
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
	_code_to_id = code_map()
	_code_lut = PackedFloat32Array()
	_code_lut.resize(256)

	for code in 256:
		_code_lut[code] = float(_code_to_id[code])

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
# missing or the file has the wrong length (error_of says why). Prepared: only what prepare() decoded, and nothing is written (the bake
# asks field_problem for the reason).
var error_of: String = ""


func raster(tx: int, tz: int, name: String) -> PackedFloat32Array:
	var key: String = "%d_%d/%s" % [tx, tz, name]

	if _cache.has(key):
		return _cache[key]

	if _prepared:
		return PackedFloat32Array()

	var got: Array = _load(tx, tz, name)
	error_of = got[1]

	if error_of == "":
		_keep(key, "%d_%d" % [tx, tz], got[0])

	return got[0]


# Why raster(tx, tz, name) is empty, or "" when it is not. Writes nothing when prepared, so bake threads may ask at once.
func field_problem(tx: int, tz: int, name: String) -> String:
	var key: String = "%d_%d/%s" % [tx, tz, name]

	if _cache.has(key):
		return ""

	if _prepared:
		return _problems.get(key, "no %s for tile %d,%d (not prepared)" % [name, tx, tz])

	return error_of if raster(tx, tz, name).is_empty() else ""


# Decodes, once, the rasters `names` of every tile of `tiles` inside the record and of their neighbours inside it (a bake frame's
# margin), and keeps them all; after it the record is read only, by any number of threads. A raster that cannot be read is kept as
# its reason (field_problem). bake_tiles.gd prepares one batch of tiles at a time, so the rasters held stay a batch's.
func prepare(tiles: Array, names: Array) -> void:
	_prepared = false
	_cache = {}
	_cache_tiles = []
	_problems = {}

	for tile in tiles:
		if not has_tile(tile.x, tile.y):
			continue

		for dz in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if not has_tile(tile.x + dx, tile.y + dz):
					continue   # beyond the record: the frame repeats the tile's edge, as before

				for name in names:
					var key: String = "%d_%d/%s" % [tile.x + dx, tile.y + dz, name]

					if _cache.has(key) or _problems.has(key):
						continue

					var got: Array = _load(tile.x + dx, tile.y + dz, name)

					if got[1] == "":
						_cache[key] = got[0]
					else:
						_problems[key] = got[1]

	_prepared = true


func is_prepared() -> bool:
	return _prepared


# [values, problem] for one raster, read from its file; writes no member.
func _load(tx: int, tz: int, name: String) -> Array:
	if not has_tile(tx, tz) or not fields.has(name):
		return [PackedFloat32Array(), "no %s for tile %d,%d" % [name, tx, tz]]

	var row: Dictionary = fields[name]
	var typ: String = str(row["type"])
	var path: String = "%s/tiles/%d_%d/%s" % [dir, tx, tz, str(row.get("file", name + "." + typ))]
	var raw: PackedByteArray = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	var count: int = samples * samples

	if raw.size() != count * int(TYPE_BYTES[typ]):
		return [PackedFloat32Array(), "%s is %d bytes, not %d" % [path, raw.size(), count * int(TYPE_BYTES[typ])]]

	# water_class: the record's code -> the game's table id (255: a code the table lacks), in the same pass.
	return [decode(row, raw, count, _code_lut if name == "water_class" else PackedFloat32Array()), ""]


# Decodes raw little-endian samples by a manifest field row. lut (256 values): each decoded code is replaced by lut[code].
# A plain field (no log code, no no-data number, scale 1) is its stored values: f4 is copied whole and the integer types take one
# short loop, the same numbers as the general loop below gives, which is what every field the bake reads is (8 Nov 2026 record).
static func decode(row: Dictionary, raw: PackedByteArray, count: int, lut: PackedFloat32Array = PackedFloat32Array()) -> PackedFloat32Array:
	var typ: String = str(row["type"])
	var scale: float = float(row.get("scale", 1.0))
	var has_nodata: bool = row.has("nodata") and str(row["nodata"]) != "NaN"
	var nodata: float = float(row["nodata"]) if has_nodata else NAN
	var cpd: float = float(row.get("codes_per_decade", 0.0))
	var out: PackedFloat32Array = raw.to_float32_array() if typ == "f4" else PackedFloat32Array()
	out.resize(count)

	if cpd <= 0.0 and not has_nodata and scale == 1.0:
		match typ:
			"u1":
				if lut.size() == 256:
					for k in count:
						out[k] = lut[raw[k]]

					return out

				for k in count:
					out[k] = float(raw[k])
			"u2":
				for k in count:
					out[k] = float(raw.decode_u16(k * 2))
			"i4":
				for k in count:
					out[k] = float(raw.decode_s32(k * 4))

		if lut.size() == 256 and typ != "u1":
			for k in count:
				out[k] = lut[int(out[k])]

		return out

	for k in count:
		var v: float

		match typ:
			"f4":
				v = out[k]
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

	if lut.size() == 256:
		for k in count:
			out[k] = lut[int(out[k])]

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
	var got: Array = frame_and_gaps(tile, margin, name)
	frame_gaps = got[1]
	return got[0]


# [the frame, its gap count], writing no member (bake threads call it at once on a prepared record). Each frame row is three runs,
# the left neighbour's, the tile's (or the column above or below it) and the right neighbour's, copied as slices of their rows
# (sample k of the frame is vals[clamp(lj) * samples + clamp(li)] as before; the slices are the same samples, not a sample at a time).
func frame_and_gaps(tile: Vector2i, margin: int, name: String) -> Array:
	var n: int = samples + 2 * margin
	var step: int = samples - 1
	var own: PackedFloat32Array = raster(tile.x, tile.y, name)

	if own.is_empty():
		var empty: PackedFloat32Array = PackedFloat32Array()
		empty.resize(n * n)
		empty.fill(NAN)
		return [empty, 0]

	var near: Array = []   # [dz + 1][dx + 1] -> that neighbour's raster (empty: missing, its samples come from this tile's edge)

	for dz in [-1, 0, 1]:
		var row_of: Array = []

		for dx in [-1, 0, 1]:
			row_of.append(raster(tile.x + dx, tile.y + dz, name) if margin > 0 else own)

		near.append(row_of)

	var out: PackedFloat32Array = PackedFloat32Array()
	var gaps: int = 0
	var runs: Array = [[-1, -margin, -1], [0, 0, step], [1, step + 1, step + margin]]   # [dtx, first gi, last gi]

	for j in n:
		var gj: int = j - margin   # sample index along z relative to this tile's first sample
		var dtz: int = -1 if gj < 0 else (1 if gj > step else 0)

		for run in runs:
			var dtx: int = run[0]
			var g0: int = run[1]
			var g1: int = run[2]

			if g1 < g0:
				continue

			var vals: PackedFloat32Array = near[dtz + 1][dtx + 1]

			if vals.is_empty():
				_append_run(out, own, clampi(gj, 0, step) * samples, g0, g1, step)   # a missing neighbour: this tile's nearest edge sample
				gaps += g1 - g0 + 1
			else:
				_append_run(out, vals, clampi(gj - dtz * step, 0, step) * samples, g0 - dtx * step, g1 - dtx * step, step)

	return [out, gaps]


# Appends vals[base + clamp(l, 0, step)] for l from l0 to l1: the samples before 0 repeat the row's first, those past step its last,
# and the rest are one slice.
static func _append_run(out: PackedFloat32Array, vals: PackedFloat32Array, base: int, l0: int, l1: int, step: int) -> void:
	var before: int = clampi(0 - l0, 0, l1 - l0 + 1)
	var after: int = clampi(l1 - step, 0, l1 - l0 + 1 - before)

	for k in before:
		out.append(vals[base])

	var a: int = maxi(l0, 0)
	var b: int = mini(l1, step)

	if b >= a:
		out.append_array(vals.slice(base + a, base + b + 1))

	for k in after:
		out.append(vals[base + step])


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


func heads_in(rect: Rect2) -> Array:
	return features_in("heads", rect)


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


# --- water classes (data/tables/water_classes.json; docs/water/stage_e_readers_design.md 6c) ---
# The table's ids are the game's (tile files, flora, land types); the record writes its own codes (0 none to 10 salt marsh), mapped to the
# table by each row's record_code. A "land" class (a wetland, a dry-season bed) is ground to the climate and the land types; its biome
# and soil are given to it after them. Today's bake writes only 0 to 3, so none of this changes a tile baked by the rules.

const CLASSES_PATH := "res://data/tables/water_classes.json"

var _code_to_id: PackedByteArray = PackedByteArray()


# Record code -> table id (255 for a code the table does not know), from the table file.
static func code_map() -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(256)
	out.fill(255)
	var parsed: Variant = _json(CLASSES_PATH)

	for row in (parsed.get("entries", []) if typeof(parsed) == TYPE_DICTIONARY else []):
		if row.has("record_code") and not bool(row.get("retired", false)):
			out[int(row["record_code"])] = int(row["id"])

	return out


# 256 flags: 1 where the class with that id is ground to the climate and the land types.
static func land_flags(tables) -> PackedByteArray:
	var out: PackedByteArray = PackedByteArray()
	out.resize(256)

	for row in tables.get_entries("water_classes"):
		if bool(row.get("land", false)) and not bool(row.get("retired", false)):
			out[int(row["id"])] = 1

	return out


# The water classes as the climate and the land types see them: "land" classes as 0 (ground). The same array when there are none.
static func land_view(water_class: PackedByteArray, tables) -> PackedByteArray:
	var flags: PackedByteArray = land_flags(tables)
	var any: bool = false

	for id in 256:
		if flags[id] == 1 and water_class.has(id):
			any = true
			break

	if not any:
		return water_class

	var out: PackedByteArray = water_class.duplicate()

	for k in out.size():
		if flags[out[k]] == 1:
			out[k] = 0

	return out


# After the climate and the land types: each "land" class cell takes its row's biome and soil (by name; a row without one keeps what
# the climate gave). Returns how many cells changed.
static func apply_wet_land(water_class: PackedByteArray, biome: PackedByteArray, soil: PackedByteArray, tables) -> int:
	var biome_of: PackedInt32Array = PackedInt32Array()
	var soil_of: PackedInt32Array = PackedInt32Array()
	biome_of.resize(256)
	soil_of.resize(256)
	biome_of.fill(-1)
	soil_of.fill(-1)
	var any: bool = false

	for row in tables.get_entries("water_classes"):
		if bool(row.get("land", false)) and not bool(row.get("retired", false)) and water_class.has(int(row["id"])):
			biome_of[int(row["id"])] = tables.id_of("biomes", str(row["biome"])) if row.has("biome") else -1
			soil_of[int(row["id"])] = tables.id_of("soils", str(row["soil"])) if row.has("soil") else -1
			any = true

	if not any:
		return 0

	var changed: int = 0

	for k in water_class.size():
		var c: int = water_class[k]

		if biome_of[c] >= 0:
			biome[k] = biome_of[c]

		if soil_of[c] >= 0:
			soil[k] = soil_of[c]

		if biome_of[c] >= 0 or soil_of[c] >= 0:
			changed += 1

	return changed


# --- placer traps (M1 step 3; docs/water/stage_e_readers_design.md 6d) ---
# Where along a river heavy grains settle: where the water slows. Kinds: "slope_break" (the bed's fall over the next stretch is under
# 1 / slope_ratio of the one above), "bend" (the course turns by bend_deg or more), "confluence" (the flow grows by confluence_x or more in one
# step: a tributary joins). The foot of a fall joins them at M2, from the record's falls list. `path` is the river walked
# downstream, one row per step: [x, z, bed height, flow]. Returns [[step index, kind], ...] in order, at most max_traps, never two within
# min_gap steps; when nothing qualifies, the gentlest step (where the water is slowest) so a source still gets one placer.
static func placer_traps(path: Array, rules: Dictionary) -> Array:
	var out: Array = []
	var n: int = path.size()

	if n < 3:
		return out

	var ratio: float = float(rules.get("slope_ratio", 2.0))
	var bend: float = deg_to_rad(float(rules.get("bend_deg", 35.0)))
	var conf: float = float(rules.get("confluence_x", 1.4))
	var gap: int = int(rules.get("min_gap", 2))
	var most: int = int(rules.get("max_traps", 4))
	var gentlest: int = 1
	var gentlest_g: float = INF

	for k in range(1, n - 1):
		var a: Array = path[k - 1]
		var b: Array = path[k]
		var c: Array = path[k + 1]
		var run_up: float = maxf(Vector2(b[0] - a[0], b[1] - a[1]).length(), 0.01)
		var run_down: float = maxf(Vector2(c[0] - b[0], c[1] - b[1]).length(), 0.01)
		var g_up: float = maxf(float(a[2]) - float(b[2]), 0.0) / run_up
		var g_down: float = maxf(float(b[2]) - float(c[2]), 0.0) / run_down
		var turn: float = absf(Vector2(b[0] - a[0], b[1] - a[1]).angle_to(Vector2(c[0] - b[0], c[1] - b[1])))
		var kind: String = ""

		if float(a[3]) > 0.0 and float(b[3]) >= float(a[3]) * conf:
			kind = "confluence"
		elif g_up > 0.002 and g_down * ratio <= g_up:
			kind = "slope_break"
		elif turn >= bend:
			kind = "bend"

		if g_down < gentlest_g:
			gentlest_g = g_down
			gentlest = k

		if kind != "" and (out.is_empty() or k - int(out.back()[0]) >= gap) and out.size() < most:
			out.append([k, kind])

	if out.is_empty():
		out.append([gentlest, "slow"])

	return out
