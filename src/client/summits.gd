extends RefCounted

# The summits near the player, for the cap cloud (cap_cloud.gd) and the summit snow (ground_material.gd), art_weather_light.md
# 7.1 and 8.2.1. Read on the player's machine from the baked tiles' coarse height map (the "low_height" section, 32 m), so
# there is no network traffic: the tiles around the player are read once on a worker thread, each about 230 000 heights.
# A summit is the highest coarse sample of its BLOCK_M block and the blocks round it, at least MIN_M high. Searched again only when the player
# moves into another tile.

const TileFile := preload("res://src/worldgen/tile/tile_file.gd")

const MIN_M := 300.0                   # lower tops are hills, not summits
const BLOCK_M := 640.0                 # a summit is the highest point of its block of this size and the eight round it
const KEEP := 12                       # the highest this many are kept

var tiles_dir: String = "res://worlds/base_world/tiles"
var tile_size_m: float = 15360.0
var list: Array = []                   # [Vector3(x, height, z)], highest first; empty until found
var ready: bool = false
var _task: int = -1
var _found: Array = []
var _took_ms: int = 0
var _tile: Vector2i = Vector2i(1 << 30, 0)


func setup(world: Dictionary) -> void:
	tile_size_m = float(world.get("tile_size_m", 15360))

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			tiles_dir = argument.trim_prefix("--world=").trim_suffix("/") + "/tiles"


# Every frame or so: starts a search when the player is in a new tile, picks up a finished one.
func update(at: Vector3) -> void:
	if _task != -1:
		if WorkerThreadPool.is_task_completed(_task):
			WorkerThreadPool.wait_for_task_completion(_task)
			_task = -1
			list = _found
			ready = true
			print("Summits: %d found round tile %s in %d ms, highest %.0f m" % [list.size(), str(_tile), _took_ms, list[0].y if not list.is_empty() else 0.0])

		return

	var tile: Vector2i = Vector2i(int(floor(at.x / tile_size_m)), int(floor(at.z / tile_size_m)))

	if tile == _tile:
		return

	_tile = tile
	var dir: String = tiles_dir
	var size: float = tile_size_m
	var job: Callable = func() -> void:
		var start: int = Time.get_ticks_msec()
		_found = search(dir, tile, size)
		_took_ms = Time.get_ticks_msec() - start

	_task = WorkerThreadPool.add_task(job, false, "summits")


# Waits for a search still running (the client is closing).
func finish() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


# The highest summit within `within_m` of `at` (Vector3(x, height, z)), or Vector3.ZERO when none is known.
func highest_near(at: Vector3, within_m: float) -> Vector3:
	for top in list:
		var dx: float = float(top.x) - at.x
		var dz: float = float(top.z) - at.z

		if dx * dx + dz * dz <= within_m * within_m:
			return top

	return Vector3.ZERO


# The summits on the tile `centre` and its eight neighbours (worker thread; pure file reading).
static func search(dir: String, centre: Vector2i, size_m: float) -> Array:
	var found: Array = []

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			found.append_array(_tile_summits(dir, centre + Vector2i(dx, dz), size_m))

	found.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y > b.y)
	return found.slice(0, KEEP)


@warning_ignore("integer_division")
static func _tile_summits(dir: String, tile: Vector2i, size_m: float) -> Array:
	var path: String = "%s/tile_%d_%d.tile" % [dir, tile.x, tile.y]

	if not FileAccess.file_exists(path):
		return []

	var head: Dictionary = TileFile.read_header(path)

	if not head["ok"]:
		return []

	var header: Dictionary = head["header"]
	var section: Dictionary = TileFile.read_section(path, head["table"], "low_height")

	if not section["ok"]:
		return []

	var n: int = int(header.get("low_res_samples", 0))
	var spacing: float = float(header.get("low_res_spacing_m", 32))
	var heights: PackedFloat32Array = TileFile.decode_height(section["raw"], TileFile.height_step_of(header))

	if n < 3 or heights.size() != n * n:
		return []

	# One pass: the highest sample in each block of BLOCK_M; a block's top is a summit when no block round it is higher.
	var b: int = maxi(int(BLOCK_M / spacing), 1)
	var blocks: int = (n + b - 1) / b
	var top_h: PackedFloat32Array = PackedFloat32Array()
	var top_at: PackedInt32Array = PackedInt32Array()
	top_h.resize(blocks * blocks)
	top_h.fill(-INF)
	top_at.resize(blocks * blocks)

	for j in range(n):
		var row: int = (j / b) * blocks

		for i in range(n):
			var h: float = heights[j * n + i]
			var k: int = row + i / b

			if h > top_h[k]:
				top_h[k] = h
				top_at[k] = j * n + i

	var out: Array = []
	var x0: float = float(tile.x) * size_m
	var z0: float = float(tile.y) * size_m

	for bj in range(blocks):
		for bi in range(blocks):
			var h: float = top_h[bj * blocks + bi]

			if h < MIN_M:
				continue

			var top: bool = true

			for v in range(maxi(bj - 1, 0), mini(bj + 2, blocks)):
				for u in range(maxi(bi - 1, 0), mini(bi + 2, blocks)):
					if top_h[v * blocks + u] > h:
						top = false

			if top:
				var at: int = top_at[bj * blocks + bi]
				out.append(Vector3(x0 + float(at % n) * spacing, h, z0 + float(at / n) * spacing))

	return out
