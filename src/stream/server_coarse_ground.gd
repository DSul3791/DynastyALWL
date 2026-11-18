extends RefCounted

# The client's questions about the coarse ground, answered from the server's baked tiles, so the client needs no tiles of its own
# (server/client split A3, /mnt/project-files/server-client-split/PLAN.md): the summits round a tile (summits.gd: cap clouds and
# summit snow) and the cells of a valley-fog window (fog_ground.gd). One read at a time on a worker thread; the answer goes to the
# asking player only. Asks are limited by data/limits.json coarse_ground, refused far from the player (terrain_server.gd), and at most
# PEER_MAX per player and QUEUE_MAX in all wait. shortcut: the summits round a tile are read again for each player, cache them per tile if many join at once.

const FogGroundScript := preload("res://src/shared/fog_ground.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")

const QUEUE_MAX := 32
const PEER_MAX := 4                    # waiting asks per player, so one player cannot fill the queue
const SUMMIT_MIN_M := 300.0            # lower tops are hills, not summits
const SUMMIT_BLOCK_M := 640.0          # a summit is the highest point of its block of this size and the eight round it
const SUMMIT_KEEP := 12                # the highest this many are kept

var net                                # TerrainNet: summits and fog_cells go out through it
var tiles_dir: String = ""
var tile_size_m: float = 15360.0
var _queue: Array = []                 # [peer id, "summits" or "fog", Vector2i tile or Vector2 origin]
var _task: int = -1
var _job: Array = []
var _answer: Variant = null


func ask_summits(peer_id: int, tile: Vector2i) -> void:
	_add([peer_id, "summits", tile])


func ask_fog(peer_id: int, origin: Vector2) -> void:
	_add([peer_id, "fog", origin])


func _add(job: Array) -> void:
	if _queue.has(job):
		return

	if _queue.size() >= QUEUE_MAX or _queue.filter(func(other: Array) -> bool: return other[0] == job[0]).size() >= PEER_MAX:
		return

	_queue.append(job)


# Every server frame: sends a finished answer, starts the next read.
func tick() -> void:
	if _task != -1:
		if not WorkerThreadPool.is_task_completed(_task):
			return

		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		var peer_id: int = int(_job[0])

		if net.multiplayer.get_peers().has(peer_id):
			if _job[1] == "summits":
				net.summits.rpc_id(peer_id, _job[2], _answer)
			else:
				net.fog_cells.rpc_id(peer_id, _job[2], _answer)

	if _queue.is_empty():
		return

	_job = _queue.pop_front()
	var dir: String = tiles_dir
	var size: float = tile_size_m
	var kind: String = _job[1]
	var key: Variant = _job[2]
	var work: Callable = func() -> void:
		if kind == "summits":
			_answer = PackedVector3Array(search(dir, key, size))
		else:
			_answer = FogGroundScript.pack_cells(FogGroundScript.read_cells(dir, size, key))

	_task = WorkerThreadPool.add_task(work, false, "coarse ground")


# Waits for a read still running (the server is closing).
func finish() -> void:
	if _task != -1:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1


# A player left: their waiting asks go.
func drop(peer_id: int) -> void:
	_queue = _queue.filter(func(job: Array) -> bool: return int(job[0]) != peer_id)


# The summits on the tile `centre` and its eight neighbours (worker thread; pure file reading).
static func search(dir: String, centre: Vector2i, size_m: float) -> Array:
	var found: Array = []

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			found.append_array(_tile_summits(dir, centre + Vector2i(dx, dz), size_m))

	found.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y > b.y)
	return found.slice(0, SUMMIT_KEEP)


static func _tile_summits(dir: String, tile: Vector2i, size_m: float) -> Array:
	var path: String = "%s/tile_%d_%d.tile" % [dir, tile.x, tile.y]

	if not FileAccess.file_exists(path):
		return []

	var head: Dictionary = TileFileScript.read_header(path)

	if not head["ok"]:
		return []

	var header: Dictionary = head["header"]
	var section: Dictionary = TileFileScript.read_section(path, head["table"], "low_height")

	if not section["ok"]:
		return []

	var n: int = int(header.get("low_res_samples", 0))
	var spacing: float = float(header.get("low_res_spacing_m", 32))
	var heights: PackedFloat32Array = TileFileScript.decode_height(section["raw"], TileFileScript.height_step_of(header))

	if n < 3 or heights.size() != n * n:
		return []

	# One pass: the highest sample in each block of SUMMIT_BLOCK_M; a block's top is a summit when no block round it is higher.
	var b: int = maxi(int(SUMMIT_BLOCK_M / spacing), 1)
	@warning_ignore("integer_division")
	var blocks: int = (n + b - 1) / b
	var top_h: PackedFloat32Array = PackedFloat32Array()
	var top_at: PackedInt32Array = PackedInt32Array()
	top_h.resize(blocks * blocks)
	top_h.fill(-INF)
	top_at.resize(blocks * blocks)

	for j in range(n):
		@warning_ignore("integer_division")
		var row: int = (j / b) * blocks

		for i in range(n):
			var h: float = heights[j * n + i]
			@warning_ignore("integer_division")
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

			if h < SUMMIT_MIN_M:
				continue

			var top: bool = true

			for v in range(maxi(bj - 1, 0), mini(bj + 2, blocks)):
				for u in range(maxi(bi - 1, 0), mini(bi + 2, blocks)):
					if top_h[v * blocks + u] > h:
						top = false

			if top:
				var at: int = top_at[bj * blocks + bi]
				@warning_ignore("integer_division")
				out.append(Vector3(x0 + float(at % n) * spacing, h, z0 + float(at / n) * spacing))

	return out
