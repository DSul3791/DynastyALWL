extends SceneTree

# The client reads no world tiles (server/client split A3, /mnt/project-files/server-client-split/PLAN.md): the server answers the
# summits round a tile and the valley-fog cells (src/stream/server_coarse_ground.gd, protocol 132), and no client source opens the tiles.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_coarse_ground.gd

const FogGround := preload("res://src/shared/fog_ground.gd")
const CoarseGround := preload("res://src/stream/server_coarse_ground.gd")
const Summits := preload("res://src/client/summits.gd")

const TILES := "res://worlds/base_world/tiles"
const SPAWN := Vector2(53296.0, 68080.0)
const CLIENT_DIRS := ["res://src/client", "res://scenes/terrain_client"]

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1

	print("%s %s" % ["ok  " if ok else "FAIL", what])


func _initialize() -> void:
	# The wire form keeps every cell: heights in the tiles' 0.125 m step, unknown ground, fresh-water distances and none.
	var n: int = int(FogGround.WINDOW_M / FogGround.CELL_M)
	var heights: PackedFloat32Array = PackedFloat32Array()
	var fresh: PackedFloat32Array = PackedFloat32Array()
	heights.resize(n * n)
	fresh.resize(n * n)

	for k in range(n * n):
		heights[k] = NAN if k % 97 == 0 else float((k * 37) % 60000 - 30000) * 0.125
		fresh[k] = INF if k % 5 == 0 else float(k % 255) * FogGround.FRESH_STEP_M

	var bytes: PackedByteArray = FogGround.pack_cells({"n": n, "heights": heights, "fresh": fresh})
	var back: Dictionary = FogGround.unpack_cells(bytes)
	var same: bool = not back.is_empty() and int(back["n"]) == n

	for k in range(n * n):
		if not same:
			break

		var h: float = back["heights"][k]
		var f: float = back["fresh"][k]
		same = (is_nan(h) if is_nan(heights[k]) else h == heights[k]) and f == fresh[k]

	_check(same, "fog cells come back from the wire exactly (%d cells, %d bytes)" % [n * n, bytes.size()])
	_check(FogGround.pack_cells({}).is_empty() and FogGround.unpack_cells(PackedByteArray()).is_empty(), "no tile there: empty bytes, no cells")
	_check(FogGround.unpack_cells(PackedByteArray([1, 2, 3, 4])).is_empty(), "damaged bytes give no cells and no crash")

	# The client side: asks once per tile, takes only the answer for the tile it is on.
	var summits = Summits.new()
	var asked: Array = []
	summits.setup({"tile_size_m": 15360}, func(tile: Vector2i) -> void: asked.append(tile))
	summits.update(Vector3(SPAWN.x, 0.0, SPAWN.y))
	summits.update(Vector3(SPAWN.x + 10.0, 0.0, SPAWN.y))
	_check(asked == [Vector2i(3, 4)], "the client asks the server for the summits round its tile once (%s)" % str(asked))
	summits.receive(Vector2i(2, 4), PackedVector3Array([Vector3(1.0, 900.0, 1.0)]))
	_check(summits.list.is_empty(), "an answer for a tile the player has left is dropped")
	summits.receive(Vector2i(3, 4), PackedVector3Array([Vector3(SPAWN.x, 900.0, SPAWN.y)]))
	_check(summits.highest_near(Vector3(SPAWN.x, 0.0, SPAWN.y), 100.0).y == 900.0, "the answer for its tile is used")

	var fog = FogGround.new()
	var origins: Array = []
	fog.setup(func(origin: Vector2) -> void: origins.append(origin))
	fog.update(Vector3(SPAWN.x, 0.0, SPAWN.y))
	fog.update(Vector3(SPAWN.x + 100.0, 0.0, SPAWN.y))
	_check(origins.size() == 1, "the client asks for a fog window once until it moves %.0f m" % FogGround.REBUILD_M)

	# The server half on the real tiles, if this checkout has them: the same grid as reading the tiles directly.
	if DirAccess.dir_exists_absolute(TILES):
		var origin: Vector2 = origins[0]
		var direct: Dictionary = FogGround.read_window(TILES, 15360.0, origin)
		fog.receive(origin, FogGround.pack_cells(FogGround.read_cells(TILES, 15360.0, origin)))
		while fog.busy():
			fog.poll()
			OS.delay_msec(5)
		var a: float = FogGround.sample(direct, "floor", SPAWN.x, SPAWN.y, NAN)
		var b: float = fog.floor_at(SPAWN.x, SPAWN.y)
		_check(not direct.is_empty() and is_finite(a) and absf(a - b) < 0.1, "the fog floor at the spawn from the server's cells is the tiles' own (%.2f m, %.2f m)" % [a, b])
		var tops: Array = CoarseGround.search(TILES, Vector2i(3, 4), 15360.0)
		_check(not tops.is_empty() and tops.size() <= CoarseGround.SUMMIT_KEEP and float(tops[0].y) >= CoarseGround.SUMMIT_MIN_M, "the server finds the summits round the starter tile (%d, highest %.0f m)" % [tops.size(), float(tops[0].y) if not tops.is_empty() else 0.0])

	# No client source opens the world's tiles or the tile reader, so a client install without them stands on its own.
	var readers: Array = []

	for dir in CLIENT_DIRS:
		_scan(dir, readers)

	_check(readers.is_empty(), "no client source reads the world tiles %s" % str(readers))

	print("test_coarse_ground: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	quit(0 if _fails == 0 else 1)


func _scan(dir: String, out: Array) -> void:
	for sub in DirAccess.get_directories_at(dir):
		_scan(dir + "/" + sub, out)

	for file in DirAccess.get_files_at(dir):
		if not file.ends_with(".gd"):
			continue

		var text: String = FileAccess.get_file_as_string(dir + "/" + file)

		for needle in ["base_world/tiles", "tile_file.gd", "TileFile.", "erosion_delta", "preload(\"res://src/admin/"]:
			if text.contains(needle):
				out.append("%s/%s: %s" % [dir, file, needle])
