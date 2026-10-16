extends RefCounted

# The client's disk cache of terrain blocks (plan step 16, design Section
# 4.10).
#
# One Voxel Tools SQLite file per tile and tile revision:
#   <cache dir>/tile_<x>_<z>_r<revision>.sqlite
# A block belongs to the tile under its first voxel. When the server says a
# tile's revision rose, that tile's older files are deleted. When the folder
# grows past the size the player chose, whole tiles are deleted, farthest
# from the player first (never the player's tile or its neighbors), as
# decided in Section 4.10.
#
# Thread safe: load and save run on Voxel Tools' worker threads.

const BLOCK_SIZE := 16

var budget_bytes: int = 2 * 1024 * 1024 * 1024
var hits: int = 0
var misses: int = 0

var _dir: String = ""
var _tile_size_m: float = 15360.0
var _world_min_m: float = -153600.0
var _period_m: float = 322560.0
var _tiles_per_side: int = 21
var _revisions: Dictionary = {}       # "x,z" -> revision
var _streams: Dictionary = {}         # "x,z" -> VoxelStreamSQLite
var _mutex: Mutex = Mutex.new()


# `world` holds tile_size_m, min_tile and tiles_per_side (from the server's
# welcome); `revisions` maps "x,z" to the tile's revision.
func setup(cache_dir: String, world: Dictionary, revisions: Dictionary, budget_mb: int) -> void:
	_dir = ProjectSettings.globalize_path(cache_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	_tile_size_m = float(world["tile_size_m"])
	_tiles_per_side = int(world["tiles_per_side"])
	_world_min_m = float(world["min_tile"]) * _tile_size_m
	_period_m = float(_tiles_per_side) * _tile_size_m
	budget_bytes = budget_mb * 1024 * 1024
	set_revisions(revisions)


func tile_of_block(block: Vector3i, lod: int) -> Vector2i:
	var size: float = float(BLOCK_SIZE << lod)
	var x: float = _world_min_m + fposmod(float(block.x) * size - _world_min_m, _period_m)
	var z: float = _world_min_m + fposmod(float(block.z) * size - _world_min_m, _period_m)
	return Vector2i(int(floor(x / _tile_size_m)), int(floor(z / _tile_size_m)))


# Applies the server's revisions: files of older revisions are deleted.
func set_revisions(revisions: Dictionary) -> void:
	_mutex.lock()

	for key in revisions:
		_revisions[str(key)] = int(revisions[key])

	for file in DirAccess.get_files_at(_dir):
		var parsed: Array = _parse_name(file)

		if parsed.is_empty():
			continue

		var key: String = "%d,%d" % [parsed[0].x, parsed[0].y]

		if int(parsed[1]) != int(_revisions.get(key, 1)):
			_streams.erase(key)
			DirAccess.remove_absolute(_dir + "/" + file)

	_mutex.unlock()


func set_revision(tile: Vector2i, revision: int) -> void:
	set_revisions({"%d,%d" % [tile.x, tile.y]: revision})


func load_block(buffer: VoxelBuffer, block: Vector3i, lod: int) -> bool:
	var stream: VoxelStreamSQLite = _stream_for(tile_of_block(block, lod))
	var found: bool = stream.load_voxel_block(buffer, block, lod) == VoxelStream.RESULT_BLOCK_FOUND
	_mutex.lock()

	if found:
		hits += 1
	else:
		misses += 1

	_mutex.unlock()
	return found


func save_block(buffer: VoxelBuffer, block: Vector3i, lod: int) -> void:
	_stream_for(tile_of_block(block, lod)).save_voxel_block(buffer, block, lod)


# Writes pending blocks to disk.
func flush() -> void:
	_mutex.lock()
	var streams: Array = _streams.values()
	_mutex.unlock()

	for stream in streams:
		stream.flush()


func size_bytes() -> int:
	var total: int = 0

	for file in DirAccess.get_files_at(_dir):
		var f: FileAccess = FileAccess.open(_dir + "/" + file, FileAccess.READ)

		if f != null:
			total += f.get_length()
			f.close()

	return total


# Deletes whole tiles, farthest from `player_tile` first, until the cache
# fits its budget. Returns the number of tiles removed.
func enforce_budget(player_tile: Vector2i) -> int:
	var total: int = size_bytes()

	if total <= budget_bytes:
		return 0

	var files: Array = []

	for file in DirAccess.get_files_at(_dir):
		var parsed: Array = _parse_name(file)

		if parsed.is_empty():
			continue

		var distance: int = _tile_distance(parsed[0], player_tile)

		if distance <= 1:
			continue

		files.append([distance, file, parsed[0]])

	files.sort_custom(func(a, b): return a[0] > b[0])
	var removed: int = 0

	for entry in files:
		if total <= budget_bytes:
			break

		var path: String = _dir + "/" + entry[1]
		var f: FileAccess = FileAccess.open(path, FileAccess.READ)
		var length: int = f.get_length() if f != null else 0

		if f != null:
			f.close()

		_mutex.lock()
		_streams.erase("%d,%d" % [entry[2].x, entry[2].y])
		_mutex.unlock()

		if DirAccess.remove_absolute(path) == OK:
			total -= length
			removed += 1

	return removed


func _stream_for(tile: Vector2i) -> VoxelStreamSQLite:
	var key: String = "%d,%d" % [tile.x, tile.y]
	_mutex.lock()
	var stream: VoxelStreamSQLite = _streams.get(key)

	if stream == null:
		stream = VoxelStreamSQLite.new()
		stream.database_path = "%s/tile_%d_%d_r%d.sqlite" % [_dir, tile.x, tile.y, int(_revisions.get(key, 1))]
		_streams[key] = stream

	_mutex.unlock()
	return stream


# Tile distance across the wrap (the larger of the two axis distances).
func _tile_distance(a: Vector2i, b: Vector2i) -> int:
	var dx: int = posmod(a.x - b.x, _tiles_per_side)
	var dz: int = posmod(a.y - b.y, _tiles_per_side)
	return maxi(mini(dx, _tiles_per_side - dx), mini(dz, _tiles_per_side - dz))


static func _parse_name(file: String) -> Array:
	if not file.begins_with("tile_") or not file.ends_with(".sqlite"):
		return []

	var parts: PackedStringArray = file.trim_prefix("tile_").trim_suffix(".sqlite").split("_")

	if parts.size() != 3 or not parts[2].begins_with("r"):
		return []

	return [Vector2i(int(parts[0]), int(parts[1])), int(parts[2].trim_prefix("r"))]
