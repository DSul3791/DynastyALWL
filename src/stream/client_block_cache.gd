extends RefCounted

# The client's disk cache of terrain blocks (plan step 16, design Section
# 4.10).
#
# One Voxel Tools SQLite file per tile:
#   <cache dir>/tile_<x>_<z>_r<revision>.sqlite   (the tile's revision when the file was started)
#   <cache dir>/tile_<x>_<z>_r<revision>.stale    (the revision the file is good for since, and its outdated blocks)
# A block belongs to the tile under its first voxel. When the server's
# revision of a tile is newer than the file's at the join, the tile is held
# (read and saved as if empty) while the server is asked for the edits since
# (protocol 128); then only the blocks round them are outdated, or the file
# is dropped when the server cannot say (apply_catch_up). When the folder
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
var _base_dir: String = ""
var _generation: int = 0              # bumped by clear_all(): a fresh folder, the old one is purged at the next start
var _tile_size_m: float = 15360.0
var _world_min_m: float = -153600.0
var _period_m: float = 322560.0
var _tiles_per_side: int = 21
var _revisions: Dictionary = {}       # "x,z" -> revision
var _streams: Dictionary = {}         # "x,z" -> VoxelStreamSQLite
var _stale: Dictionary = {}           # Vector4i(block, lod) -> true: saved copies a ground edit has outdated (forget_area), kept in the .stale files
var _file_rev: Dictionary = {}        # "x,z" -> the revision in the name of the tile's file
var _valid: Dictionary = {}           # "x,z" -> the server revision the tile's file (with its outdated blocks) is good for
var _held: Dictionary = {}            # "x,z" -> true: waiting for the edits since _valid (apply_catch_up); the file is not read or written
var _catch_up: Array = []             # [tile, since] asks for take_catch_up
var _stale_dirty: bool = false
var _mutex: Mutex = Mutex.new()

const STALE_LODS := 16                # LODs an edit marks (more than any terrain uses)
const STALE_MARGIN_VOXELS := 2        # an edit also changes the distances this many voxels round it (the mesher's band)


# `world` holds tile_size_m, min_tile and tiles_per_side (from the server's
# welcome); `revisions` maps "x,z" to the tile's revision.
func setup(cache_dir: String, world: Dictionary, revisions: Dictionary, budget_mb: int) -> void:
	_base_dir = ProjectSettings.globalize_path(cache_dir)
	_generation = _read_generation()
	_dir = _generation_dir(_generation)
	DirAccess.make_dir_recursive_absolute(_dir)
	_purge_other_generations()
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
func _generation_dir(generation: int) -> String:
	return _base_dir if generation == 0 else "%s_g%d" % [_base_dir, generation]


func _generation_file() -> String:
	return _base_dir + "_generation.txt"


func _read_generation() -> int:
	var path: String = _generation_file()
	return int(FileAccess.get_file_as_string(path).strip_edges()) if FileAccess.file_exists(path) else 0


# Removes the folders of earlier generations (best effort; they may still be
# in use right after a clear, so this runs at the next start).
func _purge_other_generations() -> void:
	var parent: String = _base_dir.get_base_dir()
	var name: String = _base_dir.get_file()

	for folder in DirAccess.get_directories_at(parent):
		var is_mine: bool = folder == name or folder.begins_with(name + "_g")

		if is_mine and parent + "/" + folder != _dir:
			var path: String = parent + "/" + folder

			for file in DirAccess.get_files_at(path):
				DirAccess.remove_absolute(path + "/" + file)

			DirAccess.remove_absolute(path)


# Throws the saved ground away at once: a new empty folder is used from now on.
func clear_all() -> void:
	_mutex.lock()
	_generation += 1
	var file: FileAccess = FileAccess.open(_generation_file(), FileAccess.WRITE)

	if file != null:
		file.store_string(str(_generation))
		file.close()

	_streams.clear()
	_stale.clear()
	_file_rev.clear()
	_valid.clear()
	_held.clear()
	_catch_up.clear()
	_dir = _generation_dir(_generation)
	DirAccess.make_dir_recursive_absolute(_dir)
	_mutex.unlock()


# First run: copies the shipped starter ground (gzipped tile files in `res_dir`,
# built by running a client at the spawn) into an empty cache, so the ground
# under the spawn is there at once. Returns the number of files seeded. Call
# set_revisions afterward so stale starter files are dropped.
func seed_starter(res_dir: String, starter_stamp: String = "") -> int:
	var seeded: int = 0

	if not DirAccess.get_files_at(_dir).is_empty():
		return 0

	# The starter ground is only good for the tile file it was built from
	# (tiles_stamp.txt: terrain version _ Layout.tile_stamp of tile 3,4); after a re-bake it waits
	# for a rebuild and the ground comes from the server meanwhile.
	var stamp_path: String = res_dir + "/tiles_stamp.txt"
	var built_for: String = FileAccess.get_file_as_string(stamp_path).strip_edges() if FileAccess.file_exists(stamp_path) else ""

	if starter_stamp != "" and built_for != starter_stamp:
		return 0

	for file in DirAccess.get_files_at(res_dir):
		if not file.ends_with(".sqlite.gz"):
			continue

		var packed: PackedByteArray = FileAccess.get_file_as_bytes(res_dir + "/" + file)
		var bytes: PackedByteArray = packed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)

		if bytes.is_empty():
			continue

		var out: FileAccess = FileAccess.open(_dir + "/" + file.trim_suffix(".gz"), FileAccess.WRITE)

		if out != null:
			out.store_buffer(bytes)
			out.close()
			seeded += 1

	return seeded


# The server's revisions (at the welcome). A tile whose file is good for an older revision is held and asked to catch up
# (take_catch_up, then apply_catch_up with the server's answer); one that is up to date takes back its outdated blocks.
func set_revisions(revisions: Dictionary) -> void:
	_mutex.lock()

	for key in revisions:
		_revisions[str(key)] = int(revisions[key])

	var files: Array = Array(DirAccess.get_files_at(_dir))
	var newest: Dictionary = {}   # "x,z" -> [tile, file revision]

	for file in files:
		var parsed: Array = _parse_name(file)

		if parsed.is_empty():
			continue

		var key: String = "%d,%d" % [parsed[0].x, parsed[0].y]

		if newest.has(key) and int(newest[key][1]) >= int(parsed[1]):
			_remove_files(key, int(parsed[1]))   # an older file of the same tile (left over by an earlier version)
			continue

		if newest.has(key):
			_remove_files(key, int(newest[key][1]))

		newest[key] = parsed

	for file in files:
		# .stale files whose block file is gone (the size limit dropped it)
		if file.ends_with(".stale") and not FileAccess.file_exists(_dir + "/" + file.trim_suffix(".stale") + ".sqlite"):
			DirAccess.remove_absolute(_dir + "/" + file)

	for key in newest:
		var tile: Vector2i = newest[key][0]
		var file_rev: int = int(newest[key][1])
		var side: Dictionary = _read_side(key, file_rev)
		var valid: int = int(side.get("valid", file_rev))
		_file_rev[key] = file_rev
		_valid[key] = valid

		for k in side.get("stale", []):
			_stale[k] = true

		if valid != int(_revisions.get(key, 1)) and not _held.has(key):
			_held[key] = true
			_catch_up.append([tile, valid])

	_mutex.unlock()


# The tiles to ask the server about ([tile, since] each), once.
func take_catch_up() -> Array:
	_mutex.lock()
	var out: Array = _catch_up
	_catch_up = []
	_mutex.unlock()
	return out


# The server's answer for a held tile (protocol 128): the edits since (x, y, z, radius each) outdate only their blocks, or whole = true
# drops the tile's file. Returns the outdated keys (the stream drops its prefetched copies of them).
func apply_catch_up(tile: Vector2i, since: int, revision: int, spheres: PackedFloat32Array, whole: bool) -> Array:
	var key: String = "%d,%d" % [tile.x, tile.y]
	var keys: Array = []

	# Only the answer to this cache's own ask (an answer from before a reload or a reconnect is for another copy).
	if not _held.has(key) or since != int(_valid.get(key, -1)):
		return keys

	if whole:
		_mutex.lock()
		_streams.erase(key)
		_remove_files(key, int(_file_rev.get(key, revision)))
		_file_rev[key] = revision
		_valid[key] = revision
		_held.erase(key)
		_mutex.unlock()
		return keys

	for n in range(0, spheres.size() - 3, 4):
		keys.append_array(forget_area(Vector3(spheres[n], spheres[n + 1], spheres[n + 2]), spheres[n + 3]))

	_mutex.lock()
	_valid[key] = revision
	var rows: Dictionary = _side_rows([key])
	_held.erase(key)
	_mutex.unlock()
	_write_sides(rows)
	return keys


func _side_path(key: String, file_rev: int) -> String:
	var parts: PackedStringArray = key.split(",")
	return "%s/tile_%s_%s_r%d.stale" % [_dir, parts[0], parts[1], file_rev]


func _remove_files(key: String, file_rev: int) -> void:
	var side: String = _side_path(key, file_rev)
	DirAccess.remove_absolute(side.trim_suffix(".stale") + ".sqlite")
	DirAccess.remove_absolute(side)


# {"valid": revision, "stale": [Vector4i, ...]} from a tile's .stale file, or {} when it has none or it cannot be read.
func _read_side(key: String, file_rev: int) -> Dictionary:
	var path: String = _side_path(key, file_rev)

	if not FileAccess.file_exists(path):
		return {}

	var f: FileAccess = FileAccess.open(path, FileAccess.READ)

	if f == null:
		return {}

	var data: Variant = f.get_var()
	f.close()

	if typeof(data) != TYPE_DICTIONARY or not data.has("valid") or typeof(data.get("stale")) != TYPE_PACKED_INT32_ARRAY:
		return {}

	var stale: Array = []
	var flat: PackedInt32Array = data["stale"]

	for n in range(0, flat.size() - 3, 4):
		stale.append(Vector4i(flat[n], flat[n + 1], flat[n + 2], flat[n + 3]))

	return {"valid": int(data["valid"]), "stale": stale}


# The .stale contents of the given tiles: {path: {"valid", "stale": PackedInt32Array}}, the outdated blocks grouped by tile in one pass.
# Call with _mutex held; write them with _write_sides after letting it go.
func _side_rows(keys: Array) -> Dictionary:
	var flat: Dictionary = {}   # "x,z" -> PackedInt32Array

	for key in keys:
		if not _file_rev.has(key):
			_file_rev[key] = int(_valid.get(key, _revisions.get(key, 1)))

		flat[key] = PackedInt32Array()

	for k in _stale:
		var t: Vector2i = tile_of_block(Vector3i(k.x, k.y, k.z), k.w)
		var key: String = "%d,%d" % [t.x, t.y]

		if flat.has(key):
			(flat[key] as PackedInt32Array).append_array(PackedInt32Array([k.x, k.y, k.z, k.w]))

	var rows: Dictionary = {}

	for key in flat:
		rows[_side_path(key, int(_file_rev[key]))] = {"valid": int(_valid.get(key, 1)), "stale": flat[key]}

	return rows


func _write_sides(rows: Dictionary) -> void:
	for path in rows:
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)

		if f != null:
			f.store_var(rows[path])
			f.close()


# Writes pending blocks to disk. CACHE_SLOW_MS (a test setting) adds that many ms to each flush, to
# try a slow disk.
func flush() -> void:
	if OS.has_environment("CACHE_SLOW_MS"):
		OS.delay_msec(int(OS.get_environment("CACHE_SLOW_MS")))

	# The outdated blocks go to disk with the blocks, so a later join still knows them; held tiles are written when they catch up.
	# Taken before the blocks are flushed and written after: a block saved meanwhile stays marked (fetched once more), never the
	# other way round (a mark dropped for a block that never reached the disk).
	_mutex.lock()
	var streams: Array = _streams.values()
	var rows: Dictionary = {}

	if _stale_dirty:
		_stale_dirty = false
		rows = _side_rows(_file_rev.keys().filter(func(key): return not _held.has(key)))

	_mutex.unlock()

	for stream in streams:
		stream.flush()

	_write_sides(rows)


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
		if not _file_rev.has(key):
			_file_rev[key] = int(_revisions.get(key, 1))
			_valid[key] = _file_rev[key]

		stream.database_path = "%s/tile_%d_%d_r%d.sqlite" % [_dir, tile.x, tile.y, int(_file_rev[key])]
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
