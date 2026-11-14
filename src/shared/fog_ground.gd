extends RefCounted

# Where land fog lies (Dave's fog instruction, 14 Nov 2026: "Valleys and low ground: fog can collect and deepen in sheltered low areas
# while nearby slopes and hilltops remain clear ... Near rivers, lakes, and wetlands ... low drifting wisps"; docs/design/FOG_PLAN.md).
# The weather gives the fog's strength and depth (Weather mist, mist_depth_m, water_steam); this gives the place: the cold-air floor,
# the lowest ground within FLOOR_REACH_M, smoothed. The fog's top is that floor plus its depth, so a valley or a high basin fills while
# the slopes and hills round it stand clear, and the top is a property of the place, not of the player. Steam fog is a shallow layer
# over the water near rivers and lakes. A stand-in for the cold-air pooling record (docs/design/fog_pools_and_sea_fog.md part A).
#
# Read on the player's machine from the baked tiles (the coarse "low_height" map, 32 m, and the "fresh_m" distance to fresh water), in a
# WINDOW_M square round the player on a worker thread, rebuilt when the player has moved REBUILD_M from its centre. No network traffic.
# Every function below the loader is pure, so the server can build the same grid from its own tiles (third fog PR).

const TileFile := preload("res://src/worldgen/tile/tile_file.gd")

const CELL_M := 32.0                # the grid's step: the tiles' coarse height map
const WINDOW_M := 4608.0            # the square read round the player
const REBUILD_M := 1024.0           # read again when the player is this far from its centre
const FLOOR_REACH_M := 320.0        # the cold-air floor: the lowest ground within this distance (a valley's floor seen from its slopes)
const VIEW_REACH_M := 1280.0       # the floor the layer is drawn at when seen from above (the valley below a hill, not the hill's own shoulder)
const SMOOTH_PASSES := 2            # 3 x 3 box passes over the floor, so the top has no steps
const STEAM_REACH_M := 60.0         # steam fog reaches this far from the water's edge, fading out
const STEAM_DEPTH_M := 4.0          # and lies this deep over the water (low wisps)
const FRESH_STEP_M := 2.0           # WaterRecord.FRESH_STEP_M: the fresh_m section's units

var tiles_dir: String = "res://worlds/base_world/tiles"
var tile_size_m: float = 15360.0
var grid: Dictionary = {}           # the last finished build (build_grid), empty until the first
var _task: int = -1
var _next: Dictionary = {}
var _centre: Vector2 = Vector2(INF, INF)


func setup(world: Dictionary) -> void:
	tile_size_m = float(world.get("tile_size_m", 15360))

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			tiles_dir = argument.trim_prefix("--world=").trim_suffix("/") + "/tiles"


# Every frame or so: starts a read when the player has moved far enough, picks up a finished one.
func update(at: Vector3) -> void:
	if _task != -1:
		if WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1

			if not _next.is_empty():
				grid = _next

		return

	var here: Vector2 = Vector2(at.x, at.z)

	if here.distance_to(_centre) < REBUILD_M:
		return

	_centre = here
	var dir: String = tiles_dir
	var size: float = tile_size_m
	var origin: Vector2 = Vector2(snappedf(here.x - WINDOW_M * 0.5, CELL_M), snappedf(here.y - WINDOW_M * 0.5, CELL_M))
	var job: Callable = func() -> void:
		_next = read_window(dir, size, origin)

	_task = WorkerThreadPool.add_task(job, false, "fog ground")


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


# --- pure, on any thread ---

# Reads the window [origin, origin + WINDOW_M] from the tiles it overlaps: {"origin", "n", "floor", "view", "near", "low"}; {} when no tile is there.
static func read_window(dir: String, tile_size: float, origin: Vector2) -> Dictionary:
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

	return build_grid(heights, fresh, n, origin) if any else {}


static func _read_tile(dir: String, tile: Vector2i, tile_size: float, origin: Vector2, n: int, heights: PackedFloat32Array, fresh: PackedFloat32Array) -> bool:
	var path: String = "%s/tile_%d_%d.tile" % [dir, tile.x, tile.y]

	if not FileAccess.file_exists(path):
		return false

	var head: Dictionary = TileFile.read_header(path)

	if not head["ok"]:
		return false

	var header: Dictionary = head["header"]
	var low: Dictionary = TileFile.read_section(path, head["table"], "low_height")

	if not low["ok"]:
		return false

	var low_n: int = int(header.get("low_res_samples", 0))
	var low_step: float = float(header.get("low_res_spacing_m", 32))
	var low_h: PackedFloat32Array = TileFile.decode_height(low["raw"], TileFile.height_step_of(header))

	if low_n < 2 or low_h.size() != low_n * low_n:
		return false

	var samples: int = int(header.get("samples", 0))
	var spacing: float = float(header.get("map_spacing_m", 8))
	var fresh_section: Dictionary = TileFile.read_section(path, head["table"], "fresh_m")   # optional: older tiles have none
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

	return {"origin": origin, "n": n, "floor": floor_m, "view": view, "near": near, "low": min_filter(filled, n, 2)}


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

