extends SceneTree

# Small, fast check of the water hub's live set and sleep/wake saving (seconds): a 3 x 3 block of made-up 33 x 33 tiles, each with a river across it, and a walk
# between them like test_water_soak's. Checks: never more than 4 live tiles, the tile the player stands in is always live, a tile that goes to sleep is saved with
# the volume it held (within the one-centimetre save format), a tile that wakes again carries on from its saved water, and the save file round-trips.
# What it cannot check: the 1.2 GB memory bound at the real 1921 x 1921 tile size (the big soak measured a peak of 956 MB of the 1228 MB limit on 30 Oct; a flat
# empty sim of that size takes only 21 MB, so no cheap stand-in is honest). test_water_soak stays as the manual before-a-release command for that.
#   godot --headless --path . --script res://src/worldgen/tools/test_water_hub_small.gd

const Hub := preload("res://src/water/water_hub.gd")
const WS := preload("res://src/water/water_store.gd")

const SIDE := 33
const CELL_M := 8.0


class Tile:
	extends RefCounted
	var heights: PackedFloat32Array
	var water_class: PackedByteArray
	var water_surface: PackedFloat32Array
	var sim_levels: PackedFloat32Array
	var samples: int = SIDE
	var spacing_m: float = CELL_M
	var tile: Vector2i = Vector2i.ZERO
	var x0: float = 0.0
	var z0: float = 0.0
	var placeholder: bool = false


class Gen:
	extends RefCounted
	var tiles_dir: String = ""
	var made: Dictionary = {}

	func _detail_at(_data, _x: float, _z: float, _spacing: float) -> float:
		return 0.0

	func tile_of(x: float, z: float) -> Vector2i:
		return Vector2i(int(floor(x / (float(SIDE - 1) * CELL_M))), int(floor(z / (float(SIDE - 1) * CELL_M))))

	func get_tile(tile: Vector2i):
		if made.has(tile):
			return made[tile]

		var data = Tile.new()
		data.tile = tile
		data.x0 = float(tile.x) * float(SIDE - 1) * CELL_M
		data.z0 = float(tile.y) * float(SIDE - 1) * CELL_M
		data.heights.resize(SIDE * SIDE)
		data.water_class.resize(SIDE * SIDE)
		data.water_surface.resize(SIDE * SIDE)

		if tile.x < 2 or tile.x > 4 or tile.y < 3 or tile.y > 5:
			data.placeholder = true

		for j in range(SIDE):
			for i in range(SIDE):
				var k: int = j * SIDE + i
				var ground: float = 20.0 - 0.1 * float(i + (tile.x - 2) * (SIDE - 1)) + 0.3 * absf(float(j) - 16.0)
				data.heights[k] = ground
				data.water_surface[k] = NAN

				if j == 16:
					data.water_class[k] = 3
					data.water_surface[k] = ground + 0.6

		made[tile] = data
		return data


var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _volume(path: String, ground: PackedFloat32Array) -> float:
	var depth: PackedFloat32Array = WS.load_depth(path, SIDE)
	var total: float = 0.0

	for k in range(depth.size()):
		if ground[k] > 0.0:
			total += depth[k] * CELL_M * CELL_M

	return total


func _all_live(hub, wanted: Array) -> bool:
	hub._mutex.lock()
	var loaded: Array = hub._tiles.keys()
	hub._mutex.unlock()

	for t in wanted:
		if not loaded.has(t):
			return false

	return true


func _init() -> void:
	var begun: int = Time.get_ticks_msec()
	var generator = Gen.new()
	var dir: String = ProjectSettings.globalize_path("user://water_hub_small")
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var hub = Hub.new()
	hub.setup(Vector2i(3, 4), dir, 3.0, generator, false)
	var phases: Array = [
		[Vector2i(3, 4)],
		[Vector2i(3, 4), Vector2i(4, 4)],
		[Vector2i(2, 3)],
		[Vector2i(4, 3), Vector2i(2, 5), Vector2i(3, 3), Vector2i(4, 4), Vector2i(3, 5)],
		[Vector2i(3, 4)],
		[Vector2i(4, 4), Vector2i(3, 5)],
	]
	var most: int = 0
	var seen: Dictionary = {}
	var centre_missing: int = 0
	var slept_ok: int = 0
	var slept: int = 0

	for tiles in phases:
		hub.set_live(tiles)
		var end: int = Time.get_ticks_msec() + 700
		var deadline: int = Time.get_ticks_msec() + 30000

		while Time.get_ticks_msec() < end or (not _all_live(hub, hub._wanted) and Time.get_ticks_msec() < deadline):
			OS.delay_msec(50)
			hub._mutex.lock()
			var loaded: Array = hub._tiles.keys()
			hub._mutex.unlock()
			most = maxi(most, loaded.size())

			for t in loaded:
				seen[t] = true

		hub._mutex.lock()
		var loaded_now: Array = hub._tiles.keys()
		hub._mutex.unlock()

		if not loaded_now.has(tiles[0]):
			centre_missing += 1

	# The volume each live tile holds now, then stop (the thread stops, tiles stay) and unload: the file must hold what the sim held.
	hub.stop()
	_check(centre_missing == 0, "the tile the player stands in was live after every move (%d misses)" % centre_missing)
	_check(most <= 4, "never more than 4 live tiles (most %d)" % most)
	_check(seen.size() >= 5, "the walk loaded %d of the nine tiles in turn" % seen.size())

	for tile in hub._tiles.keys():
		var live = hub._tiles[tile]
		var held: float = live.sim.total_volume()
		var raw: PackedFloat32Array = live.sim.get_depth()
		var wet: int = 0

		for k in range(raw.size()):
			if live.data.heights[k] > 0.0 and raw[k] > 0.004:
				wet += 1

		live.unload()
		var saved: float = _volume("%s/tile_%d_%d.water" % [dir, tile.x, tile.y], live.data.heights)
		var bound: float = float(wet) * 0.005 * CELL_M * CELL_M + 5.0
		slept += 1

		if absf(saved - held) <= bound:
			slept_ok += 1

		print("tile %s: held %.1f m3, saved %.1f m3, bound %.1f m3" % [str(tile), held, saved, bound])

	_check(slept > 0 and slept_ok == slept, "a tile put to sleep keeps its volume within the save format (%d of %d)" % [slept_ok, slept])

	# Tiles that went to sleep during the walk left a file at full size.
	var files: int = 0

	for tile in seen:
		var path: String = "%s/tile_%d_%d.water" % [dir, tile.x, tile.y]

		if FileAccess.file_exists(path):
			files += 1
			_check(WS.load_depth(path, SIDE).size() == SIDE * SIDE, "tile %s saved at full size" % str(tile))

	_check(files >= 4, "tiles that went to sleep were saved (%d files)" % files)

	# The save format on its own: a pond of known depths comes back within half a centimetre; a film under 4 mm is dropped.
	var depth: PackedFloat32Array = PackedFloat32Array()
	depth.resize(SIDE * SIDE)
	depth[100] = 1.234
	depth[101] = 0.002
	depth[102] = 0.0449
	WS.save(dir + "/format.water", SIDE, depth)
	var back: PackedFloat32Array = WS.load_depth(dir + "/format.water", SIDE)
	_check(absf(back[100] - 1.23) < 0.006 and back[101] == 0.0 and absf(back[102] - 0.04) < 0.006, "the save format keeps centimetres and drops films (%.3f, %.3f, %.3f)" % [back[100], back[101], back[102]])
	_check(WS.load_depth(dir + "/format.water", SIDE + 1).is_empty(), "a file saved at another size is refused")

	var took: float = float(Time.get_ticks_msec() - begun) / 1000.0
	print("water hub small: %d failures, %.1f s" % [failures, took])
	quit(1 if failures > 0 else 0)
