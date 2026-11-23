extends RefCounted

# Where land fog lies (Dave's fog instruction, 14 Nov 2026: "Valleys and low ground: fog can collect and deepen in sheltered low areas
# while nearby slopes and hilltops remain clear ... Near rivers, lakes, and wetlands ... low drifting wisps"; docs/design/FOG_PLAN.md).
# The weather gives the fog's strength and depth (Weather mist, mist_depth_m, water_steam); this gives the place: the cold-air floor,
# the lowest ground within FLOOR_REACH_M, smoothed. The fog's top is that floor plus its depth, so a valley or a high basin fills while
# the slopes and hills round it stand clear, and the top is a property of the place, not of the player. Steam fog is a shallow layer
# over the water near rivers and lakes. A stand-in for the cold-air pooling record (docs/design/fog_pools_and_sea_fog.md part A).
#
# Built from the baked tiles (the coarse "low_height" map, 32 m, and the "fresh_m" distance to fresh water), in a WINDOW_M square round
# the player on a worker thread, rebuilt when the player has moved REBUILD_M from its centre. Only the server reads the tiles (the
# client is a separate install without them, server/client split A3): the server's own windows (server_animals.gd: animals' sight in
# fog) read them here; a client's window is read by the server (server_coarse_ground.gd), sent as cells (fog_cells, pack_cells) and
# built into the grid on the client (receive). Every function below the loader is pure.

const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")

const CELL_M := 32.0                # the grid's step: the tiles' coarse height map
const WINDOW_M := 4608.0            # the square read round the player
const REBUILD_M := 1024.0           # read again when the player is this far from its centre
const FLOOR_REACH_M := 320.0        # the cold-air floor: the lowest ground within this distance (a valley's floor seen from its slopes)
const VIEW_REACH_M := 1280.0       # the floor the layer is drawn at when seen from above (the valley below a hill, not the hill's own shoulder)
const SMOOTH_PASSES := 2            # 3 x 3 box passes over the floor, so the top has no steps
const STEAM_REACH_M := 60.0         # steam fog reaches this far from the water's edge, fading out
const STEAM_DEPTH_M := 4.0          # and lies this deep over the water (low wisps)
const FRESH_STEP_M := 2.0           # WaterRecord.FRESH_STEP_M: the fresh_m section's units
const PACK_STEP_M := 0.125          # TileFile.HEIGHT_STEP_M: heights go over the wire in the tiles' own step
const PACK_UNKNOWN := -32768        # a cell no tile covers
const ASK_AGAIN_MSEC := 15000       # client: asks again when the server has not answered in this long

var tiles_dir: String = ""          # the server's windows: set by server_animals.gd (the client has no tiles)
var tile_size_m: float = 15360.0
var grid: Dictionary = {}           # the last finished build (build_grid), empty until the first
var _task: int = -1
var _next: Dictionary = {}
var _centre: Vector2 = Vector2(INF, INF)
var who: String = "client"          # for the log line: "client" or "server"
var ask: Callable                   # client: asks the server for the cells of the window at an origin (Vector2); unset: read the tiles here
var _asked_msec: int = 0
var _asked: Vector2 = Vector2(INF, INF)   # client: the origin last asked for
var _pending: Array = []            # client: [origin, bytes] that came while a build was running


# Client: the server reads the tiles; `asker` sends it a window's origin (Vector2), and its fog_cells answer comes to receive().
func setup(asker: Callable) -> void:
	ask = asker


# Every frame or so: starts a read when the player has moved far enough, picks up a finished one.
func update(at: Vector3) -> void:
	if _task != -1:
		poll()
		return

	var here: Vector2 = Vector2(at.x, at.z)
	var origin: Vector2 = Vector2(snappedf(here.x - WINDOW_M * 0.5, CELL_M), snappedf(here.y - WINDOW_M * 0.5, CELL_M))

	if ask.is_valid():
		# The server answers with fog_cells (receive); asked again after ASK_AGAIN_MSEC with no answer (a refused or lost ask).
		if here.distance_to(_centre) >= REBUILD_M or (_asked_msec > 0 and Time.get_ticks_msec() - _asked_msec > ASK_AGAIN_MSEC):
			_centre = here
			_asked_msec = Time.get_ticks_msec()
			_asked = origin
			ask.call(origin)

		return

	if here.distance_to(_centre) < REBUILD_M:
		return

	_centre = here
	var dir: String = tiles_dir
	var size: float = tile_size_m
	var job: Callable = func() -> void:
		_next = with_range(read_window(dir, size, origin))

	_task = WorkerThreadPool.add_task(job, false, "fog ground")


# Client: the server's cells for the window at `origin` (fog_cells; empty bytes: no tile there), built into the grid on a worker.
func receive(origin: Vector2, bytes: PackedByteArray) -> void:
	if origin == _asked:
		_asked_msec = 0

	if _task != -1:
		_pending = [origin, bytes]
		return

	var job: Callable = func() -> void:
		var cells: Dictionary = unpack_cells(bytes)
		_next = with_range(build_grid(cells["heights"], cells["fresh"], int(cells["n"]), origin)) if not cells.is_empty() else {}

	_task = WorkerThreadPool.add_task(job, false, "fog ground")


# The centre (x, z) of the last read started (INF before any).
func centre() -> Vector2:
	return _centre


# Picks up a finished read without moving the window.
func poll() -> void:
	if _task != -1 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1

		if not _next.is_empty():
			grid = _next

		_log_read()

		if not _pending.is_empty():
			var next: Array = _pending
			_pending = []
			receive(next[0], next[1])


# One line per finished read, so a smoke can show the worker ran (client and server).
func _log_read() -> void:
	if _next.is_empty():
		print("fog ground (%s): no tile at %.0f, %.0f" % [who, _centre.x, _centre.y])
		return

	var span: Vector2 = _next.get("floor_range", Vector2.ZERO)
	print("fog ground (%s): read %d x %d cells round %.0f, %.0f; cold-air floor %.0f to %.0f m" % [who, int(_next["n"]), int(_next["n"]), _centre.x, _centre.y, span.x, span.y])


# Is a read running?
func busy() -> bool:
	return _task != -1


# Waits for a read still running (the client is closing).
func finish() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


# The cold-air floor at a point (m above sea level); 0 (sea level) where nothing is known, which is the old one-layer fog.
func floor_at(x: float, z: float) -> float:
	return sample(grid, "floor", x, z, 0.0)


# The floor of the wider ground (VIEW_REACH_M): where the layer seen from above lies.
func view_floor_at(x: float, z: float) -> float:
	return sample(grid, "view", x, z, 0.0)


# How near fresh water a point is for steam fog: 1 at the water's edge, 0 from STEAM_REACH_M.
func steam_near(x: float, z: float) -> float:
	return sample(grid, "near", x, z, 0.0)


# The water's level for steam fog (the lowest ground close by), m above sea level.
func water_level(x: float, z: float) -> float:
	return sample(grid, "low", x, z, 0.0)


# Under the island, not the sea (Dave 20 Nov 2026: a tunnel dug deep under the island hit water): the baked ground here, its lowest within
# 64 m counting only ground joined to the open sea ("sea_low", sea_reach), is above sea level by LAND_ABOVE_M. Then below 0 m is dry rock or a dug space, not sea. The coarse map is the generated ground,
# so digging never makes a sea. False where nothing is known (no grid yet, off the window): the old rule, all below 0 m is sea.
const LAND_ABOVE_M := 0.5
const SEA_ASK_BELOW_M := 40.0       # the client asks for the window without drawn fog too while the eye is this low (the sea check needs it)


func under_land(x: float, z: float) -> bool:
	return sample(grid, "sea_low", x, z, 0.0) > LAND_ABOVE_M


# --- pure, on any thread ---

# Reads the window [origin, origin + WINDOW_M] from the tiles it overlaps: {"origin", "n", "floor", "view", "near", "low", "sea_low"}; {} when no tile is there.
static func read_window(dir: String, tile_size: float, origin: Vector2) -> Dictionary:
	var cells: Dictionary = read_cells(dir, tile_size, origin)
	return build_grid(cells["heights"], cells["fresh"], int(cells["n"]), origin) if not cells.is_empty() else {}


# The window's cells from the tiles: {"n", "heights" (NAN unknown), "fresh" (m, INF none)}; {} when no tile is there.
static func read_cells(dir: String, tile_size: float, origin: Vector2) -> Dictionary:
	var n: int = int(WINDOW_M / CELL_M)
	var heights: PackedFloat32Array = PackedFloat32Array()
	var fresh: PackedFloat32Array = PackedFloat32Array()
	heights.resize(n * n)
	heights.fill(NAN)
	fresh.resize(n * n)
	fresh.fill(INF)
	var first: Vector2i = Vector2i(int(floor(origin.x / tile_size)), int(floor(origin.y / tile_size)))
	var last: Vector2i = Vector2i(int(floor((origin.x + WINDOW_M) / tile_size)), int(floor((origin.y + WINDOW_M) / tile_size)))
	var any: bool = false

	for ty in range(first.y, last.y + 1):
		for tx in range(first.x, last.x + 1):
			any = _read_tile(dir, Vector2i(tx, ty), tile_size, origin, n, heights, fresh) or any

	return {"n": n, "heights": heights, "fresh": fresh} if any else {}


# The floor's range for the log line, worked out on the worker, not on the main thread.
static func with_range(read: Dictionary) -> Dictionary:
	if not read.is_empty():
		var low_m: float = INF
		var high_m: float = -INF

		for value in read["floor"]:
			low_m = minf(low_m, value)
			high_m = maxf(high_m, value)

		read["floor_range"] = Vector2(low_m, high_m)

	return read


# Cells for the wire (fog_cells): u16 n, then n x n heights as s16 in steps of PACK_STEP_M (PACK_UNKNOWN: unknown), then n x n
# fresh-water distances as u8 in FRESH_STEP_M (255: none), zstd-compressed; about 60 KB before compression. Empty for no cells.
static func pack_cells(cells: Dictionary) -> PackedByteArray:
	if cells.is_empty():
		return PackedByteArray()

	var n: int = int(cells["n"])
	var heights: PackedFloat32Array = cells["heights"]
	var fresh: PackedFloat32Array = cells["fresh"]
	var raw: PackedByteArray = PackedByteArray()
	raw.resize(2 + n * n * 3)
	raw.encode_u16(0, n)

	for k in range(n * n):
		var h: float = heights[k]
		raw.encode_s16(2 + k * 2, PACK_UNKNOWN if is_nan(h) else clampi(roundi(h / PACK_STEP_M), -32767, 32767))
		raw[2 + n * n * 2 + k] = 255 if not is_finite(fresh[k]) else clampi(roundi(fresh[k] / FRESH_STEP_M), 0, 254)

	return raw.compress(FileAccess.COMPRESSION_ZSTD)


# The cells pack_cells sent: {"n", "heights", "fresh"}; {} for empty or damaged bytes.
static func unpack_cells(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}

	var n: int = int(WINDOW_M / CELL_M)
	var raw: PackedByteArray = bytes.decompress(2 + n * n * 3, FileAccess.COMPRESSION_ZSTD)

	if raw.size() != 2 + n * n * 3 or raw.decode_u16(0) != n:
		return {}

	var heights: PackedFloat32Array = PackedFloat32Array()
	var fresh: PackedFloat32Array = PackedFloat32Array()
	heights.resize(n * n)
	fresh.resize(n * n)

	for k in range(n * n):
		var h: int = raw.decode_s16(2 + k * 2)
		heights[k] = NAN if h == PACK_UNKNOWN else float(h) * PACK_STEP_M
		var f: int = raw[2 + n * n * 2 + k]
		fresh[k] = INF if f == 255 else float(f) * FRESH_STEP_M

	return {"n": n, "heights": heights, "fresh": fresh}


static func _read_tile(dir: String, tile: Vector2i, tile_size: float, origin: Vector2, n: int, heights: PackedFloat32Array, fresh: PackedFloat32Array) -> bool:
	var path: String = "%s/tile_%d_%d.tile" % [dir, tile.x, tile.y]

	if not FileAccess.file_exists(path):
		return false

	var head: Dictionary = TileFileScript.read_header(path)

	if not head["ok"]:
		return false

	var header: Dictionary = head["header"]
	var low: Dictionary = TileFileScript.read_section(path, head["table"], "low_height")

	if not low["ok"]:
		return false

	var low_n: int = int(header.get("low_res_samples", 0))
	var low_step: float = float(header.get("low_res_spacing_m", 32))
	var low_h: PackedFloat32Array = TileFileScript.decode_height(low["raw"], TileFileScript.height_step_of(header))

	if low_n < 2 or low_h.size() != low_n * low_n:
		return false

	var samples: int = int(header.get("samples", 0))
	var spacing: float = float(header.get("map_spacing_m", 8))
	var fresh_section: Dictionary = TileFileScript.read_section(path, head["table"], "fresh_m")   # optional: older tiles have none
	var fresh_raw: PackedByteArray = fresh_section["raw"] if fresh_section["ok"] and fresh_section["raw"].size() == samples * samples else PackedByteArray()
	var tile_origin: Vector2 = Vector2(float(tile.x), float(tile.y)) * tile_size

	for j in range(n):
		for i in range(n):
			var world: Vector2 = origin + Vector2((float(i) + 0.5) * CELL_M, (float(j) + 0.5) * CELL_M)
			var local: Vector2 = world - tile_origin

			if local.x < 0.0 or local.y < 0.0 or local.x >= tile_size or local.y >= tile_size:
				continue

			var li: int = clampi(int(local.x / low_step), 0, low_n - 1)
			var lj: int = clampi(int(local.y / low_step), 0, low_n - 1)
			heights[j * n + i] = low_h[lj * low_n + li]

			if not fresh_raw.is_empty():
				var fi: int = clampi(int(local.x / spacing), 0, samples - 1)
				var fj: int = clampi(int(local.y / spacing), 0, samples - 1)
				var raw: int = fresh_raw[fj * samples + fi]
				fresh[j * n + i] = INF if raw == 255 else float(raw) * FRESH_STEP_M

	return true


# The grid from heights (NAN unknown) and fresh-water distances on n x n cells of CELL_M from origin.
static func build_grid(heights: PackedFloat32Array, fresh: PackedFloat32Array, n: int, origin: Vector2) -> Dictionary:
	var filled: PackedFloat32Array = heights.duplicate()

	for k in range(n * n):
		if is_nan(filled[k]) or filled[k] < 0.0:
			filled[k] = 0.0         # unknown ground: sea level, the old layer; the sea bed: the sea's surface is the cold air's floor there

	var reach: int = maxi(int(round(FLOOR_REACH_M / CELL_M)), 1)
	var floor_m: PackedFloat32Array = min_filter(filled, n, reach)

	for pass_index in range(SMOOTH_PASSES):
		floor_m = box_blur(floor_m, n)

	var view: PackedFloat32Array = min_filter(filled, n, maxi(int(round(VIEW_REACH_M / CELL_M)), 1))

	for pass_index in range(SMOOTH_PASSES):
		view = box_blur(view, n)

	var near: PackedFloat32Array = PackedFloat32Array()
	near.resize(n * n)

	for k in range(n * n):
		near[k] = 1.0 - smoothstep(0.0, STEAM_REACH_M, fresh[k]) if is_finite(fresh[k]) else 0.0

	return {"origin": origin, "n": n, "floor": floor_m, "view": view, "near": near, "low": min_filter(filled, n, 2), "sea_low": min_filter(sea_reach(heights, n), n, 2)}


# The sea's own ground (fen flats drawn as white sea, Lane A 22 Nov 2026: flats a few decimetres below sea level, cut off from the sea by
# ground above it, had the sea plane over them): ground below sea level joined to the open sea through ground below sea level, flooded
# from the open sea bed (SEA_OPEN_M or deeper) and from unknown cells (the old rule there: sea). Those cells read 0; every other cell
# reads its ground but at least SEA_CUT_OFF_M, so an inland hollow below 0 m is land to the sea check (under_land, the sea plane's mask).
const SEA_OPEN_M := -1.0
const SEA_CUT_OFF_M := 1.0


static func sea_reach(heights: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n * n)
	var queue: PackedInt32Array = PackedInt32Array()

	for k in range(n * n):
		var h: float = heights[k]

		if is_nan(h) or h <= SEA_OPEN_M:
			out[k] = 0.0
			queue.append(k)
		else:
			out[k] = maxf(h, SEA_CUT_OFF_M)

	var head: int = 0

	while head < queue.size():
		var k: int = queue[head]
		head += 1
		var i: int = k % n
		var j: int = k / n

		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ni: int = i + step.x
			var nj: int = j + step.y

			if ni < 0 or nj < 0 or ni >= n or nj >= n:
				continue

			var m: int = nj * n + ni

			if out[m] != 0.0 and heights[m] < 0.0:
				out[m] = 0.0
				queue.append(m)

	return out


# The lowest value within `reach` cells (a square), in two passes (rows, then columns).
static func min_filter(values: PackedFloat32Array, n: int, reach: int) -> PackedFloat32Array:
	var rows: PackedFloat32Array = PackedFloat32Array()
	rows.resize(n * n)

	for j in range(n):
		for i in range(n):
			var low: float = INF

			for d in range(maxi(i - reach, 0), mini(i + reach, n - 1) + 1):
				low = minf(low, values[j * n + d])

			rows[j * n + i] = low

	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n * n)

	for j in range(n):
		for i in range(n):
			var low: float = INF

			for d in range(maxi(j - reach, 0), mini(j + reach, n - 1) + 1):
				low = minf(low, rows[d * n + i])

			out[j * n + i] = low

	return out


static func box_blur(values: PackedFloat32Array, n: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(n * n)

	for j in range(n):
		for i in range(n):
			var total: float = 0.0
			var count: int = 0

			for dj in range(-1, 2):
				for di in range(-1, 2):
					var a: int = i + di
					var b: int = j + dj

					if a >= 0 and b >= 0 and a < n and b < n:
						total += values[b * n + a]
						count += 1

			out[j * n + i] = total / float(count)

	return out


# How far a point lies inside a grid's window (m to its nearest edge); -1 when outside or no grid.
static func margin(g: Dictionary, x: float, z: float) -> float:
	if g.is_empty():
		return -1.0

	var origin: Vector2 = g["origin"]
	var size: float = float(int(g["n"])) * CELL_M
	var inside: float = minf(minf(x - origin.x, origin.x + size - x), minf(z - origin.y, origin.y + size - z))
	return inside if inside >= 0.0 else -1.0


# A grid value at a world point, bilinear between cell centres; `outside` when the grid is empty or the point is off it.
static func sample(g: Dictionary, key: String, x: float, z: float, outside: float) -> float:
	if g.is_empty():
		return outside

	var n: int = int(g["n"])
	var origin: Vector2 = g["origin"]
	var u: float = (x - origin.x) / CELL_M - 0.5
	var v: float = (z - origin.y) / CELL_M - 0.5

	if u < 0.0 or v < 0.0 or u > float(n - 1) or v > float(n - 1):
		return outside

	var values: PackedFloat32Array = g[key]
	var i: int = mini(int(u), n - 2)
	var j: int = mini(int(v), n - 2)
	var fu: float = u - float(i)
	var fv: float = v - float(j)
	var top: float = lerpf(values[j * n + i], values[j * n + i + 1], fu)
	var bottom: float = lerpf(values[(j + 1) * n + i], values[(j + 1) * n + i + 1], fu)
	return lerpf(top, bottom, fv)

