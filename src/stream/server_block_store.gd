extends RefCounted

# The server's terrain blocks (plan step 16).
#
# A block is looked up in three places, in order:
#   1. the edits store: blocks players have changed (permanent, never wiped)
#   2. the generated-block cache: blocks made before, so nothing is made twice
#      (can be deleted at any time, for example after a generator change)
#   3. the runtime terrain generator, whose result goes into the cache
#
# Blocks are 16 voxels on a side (Voxel Tools' data block size) at any LOD.
# Both stores are Voxel Tools SQLite files in the server's store folder.
#
# Before a block is sent, ore buried deeper than `hide_ore_depth_m` below
# any surface (ground or cave) is removed from the copy that goes out, so a
# modified client cannot see through rock (design Section 4.9). The stores
# keep the full block.
#
# Every tile has a revision that rises when one of its blocks is edited, so
# clients know when their cached copy is stale. Revisions are kept in
# `revisions.json` in the store folder.
#
# Thread safe: block_bytes may run on many worker threads at once.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

const BLOCK_SIZE := 16

var generator
var hide_ore_depth_m: float = 2.0
var tile_revisions: Dictionary = {}     # "x,z" -> revision (missing = 1)
var tiles_stamp: String = ""            # fingerprint of the tile files the ground is made from
var _tile_dates: String = ""            # tile file names, sizes and dates last seen
var _dates_changed_msec: int = -1       # when they last changed (a bake is writing)
var blocks_generated: int = 0
var cache_hits: int = 0
var edit_hits: int = 0
var bad_blocks: int = 0                 # built blocks that failed the sanity check (not saved)

var _store_dir: String = ""
var _generation: int = 0
var _cache: VoxelStreamSQLite
var _edits: VoxelStreamSQLite
var _mutex: Mutex = Mutex.new()
var _edit_mutex: Mutex = Mutex.new()


# Returns "" or an error.
func setup(terrain_generator, store_dir: String) -> String:
	generator = terrain_generator
	_store_dir = store_dir
	var error: int = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(store_dir))

	if error != OK and not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(store_dir)):
		return "cannot create %s" % store_dir

	# Generated blocks from an older terrain version, or from other tile files
	# (a re-bake), are thrown away.
	var version_path: String = store_dir + "/terrain_version.txt"
	var version: String = FileAccess.get_file_as_string(version_path).strip_edges() if FileAccess.file_exists(version_path) else ""
	tiles_stamp = Layout.tiles_stamp(generator.tiles_dir)
	var wanted: String = "%d %s" % [Layout.TERRAIN_VERSION, tiles_stamp]
	_generation = int(FileAccess.get_file_as_string(store_dir + "/generated_generation.txt").strip_edges()) if FileAccess.file_exists(store_dir + "/generated_generation.txt") else 0

	if version != wanted:
		# A new generation: every older generated file is deleted below.
		_generation += 1
		_write(store_dir + "/generated_generation.txt", str(_generation))
		_write(version_path, wanted)
		print("server: terrain or tile files changed, old generated ground thrown away")

	_purge_old_generated()
	_cache = _open_generated()
	_edits = VoxelStreamSQLite.new()
	_edits.database_path = ProjectSettings.globalize_path(store_dir + "/edits.sqlite")
	var path: String = store_dir + "/revisions.json"

	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

		if typeof(parsed) == TYPE_DICTIONARY:
			for key in parsed:
				tile_revisions[str(key)] = int(parsed[key])

	return ""


# Called every few seconds: true once the tile files have changed (a bake
# finished) and then stayed still for TILES_SETTLE_MSEC. The generated ground
# is then thrown away (edits kept) and tiles_stamp is the new fingerprint.
const TILES_SETTLE_MSEC := 15000


func check_tiles(now_msec: int) -> bool:
	var parts: PackedStringArray = PackedStringArray()

	for file in DirAccess.get_files_at(generator.tiles_dir):
		if file.ends_with(".tile"):
			var path: String = generator.tiles_dir + "/" + file
			parts.append("%s:%d" % [file, FileAccess.get_modified_time(path)])

	var dates: String = ",".join(parts)

	if _tile_dates == "":
		_tile_dates = dates
		return false

	if dates != _tile_dates:
		_tile_dates = dates
		_dates_changed_msec = now_msec
		return false

	if _dates_changed_msec < 0 or now_msec - _dates_changed_msec < TILES_SETTLE_MSEC:
		return false

	_dates_changed_msec = -1
	var stamp: String = Layout.tiles_stamp(generator.tiles_dir)

	if stamp == tiles_stamp:
		return false

	tiles_stamp = stamp
	clear_generated()
	_write(_store_dir + "/terrain_version.txt", "%d %s" % [Layout.TERRAIN_VERSION, tiles_stamp])
	return true


func _write(path: String, text: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file != null:
		file.store_string(text)
		file.close()


func _generated_name() -> String:
	return "generated.sqlite" if _generation == 0 else "generated_g%d.sqlite" % _generation


func _open_generated() -> VoxelStreamSQLite:
	var stream: VoxelStreamSQLite = VoxelStreamSQLite.new()
	stream.database_path = ProjectSettings.globalize_path(_store_dir + "/" + _generated_name())
	return stream


# Deletes generated ground files of other generations (best effort).
func _purge_old_generated() -> void:
	var folder: String = ProjectSettings.globalize_path(_store_dir)

	for file in DirAccess.get_files_at(folder):
		if file.begins_with("generated") and file.contains(".sqlite") and not file.begins_with(_generated_name()):
			DirAccess.remove_absolute(folder + "/" + file)


# Throws the generated ground away at once (edits are kept): later blocks are
# made again into a fresh file; the old file is deleted at the next start.
func clear_generated() -> void:
	_generation += 1
	var file: FileAccess = FileAccess.open(_store_dir + "/generated_generation.txt", FileAccess.WRITE)

	if file != null:
		file.store_string(str(_generation))
		file.close()

	_cache = _open_generated()


func revision_of(tile: Vector2i) -> int:
	_edit_mutex.lock()
	var revision: int = int(tile_revisions.get("%d,%d" % [tile.x, tile.y], 1))
	_edit_mutex.unlock()
	return revision


func revisions() -> Dictionary:
	_edit_mutex.lock()
	var copy: Dictionary = tile_revisions.duplicate()
	_edit_mutex.unlock()
	return copy


# The full block (nothing hidden) into `buffer`.
func load_block(buffer: VoxelBuffer, block: Vector3i, lod: int) -> void:
	if _edits.load_voxel_block(buffer, block, lod) == VoxelStream.RESULT_BLOCK_FOUND:
		_count("edit")
		return

	var cache: VoxelStreamSQLite = _cache

	if cache.load_voxel_block(buffer, block, lod) == VoxelStream.RESULT_BLOCK_FOUND:
		_count("cache")
		return

	var failed_before: int = generator.failed_tiles
	generator.generate(buffer, block * (BLOCK_SIZE << lod), lod)

	# A block built from a stand-in tile, or one that fails the check, is served this
	# once but never saved, so a bad build cannot become permanent.
	if generator.failed_tiles == failed_before and _is_sane(buffer, block, lod):
		cache.save_voxel_block(buffer, block, lod)
	elif generator.failed_tiles == failed_before:
		generator.generate(buffer, block * (BLOCK_SIZE << lod), lod)

		if _is_sane(buffer, block, lod):
			cache.save_voxel_block(buffer, block, lod)

	_count("generated")


# Makes and saves a block nobody has asked for yet (idle pre-building).
# Returns true when it had to be generated, false when it already existed
# (as an edit or in the cache).
func ensure_block(block: Vector3i, lod: int) -> bool:
	var buffer: VoxelBuffer = Layout.make_buffer(BLOCK_SIZE)

	if _edits.load_voxel_block(buffer, block, lod) == VoxelStream.RESULT_BLOCK_FOUND:
		return false

	var cache: VoxelStreamSQLite = _cache

	if cache.load_voxel_block(buffer, block, lod) == VoxelStream.RESULT_BLOCK_FOUND:
		return false

	var failed_before: int = generator.failed_tiles
	generator.generate(buffer, block * (BLOCK_SIZE << lod), lod)

	if generator.failed_tiles == failed_before and _is_sane(buffer, block, lod):
		cache.save_voxel_block(buffer, block, lod)

	_count("generated")
	return true


# The ground is solid exactly where a voxel lies below its column's surface (caves
# only add air), so a solid voxel well above the ground is a bad build. Checks the
# top and middle layers of nine columns against the height the generator reports.
func _is_sane(buffer: VoxelBuffer, block: Vector3i, lod: int) -> bool:
	var s: float = float(1 << lod)
	var origin: Vector3 = Vector3(block * (BLOCK_SIZE << lod))

	for layer in [BLOCK_SIZE - 1, BLOCK_SIZE / 2]:
		var y: float = origin.y + float(layer) * s

		for cz in [0, BLOCK_SIZE / 2, BLOCK_SIZE - 1]:
			for cx in [0, BLOCK_SIZE / 2, BLOCK_SIZE - 1]:
				var h: float = generator.surface_height(origin.x + float(cx) * s, origin.z + float(cz) * s, lod)

				if y > h + 2.0 * s and buffer.get_voxel_f(cx, layer, cz, Layout.CHANNEL_SDF) < 0.0:
					_report_bad(block, lod, cx, layer, cz, y, h)
					return false

	return true


func _report_bad(block: Vector3i, lod: int, cx: int, layer: int, cz: int, y: float, h: float) -> void:
	_mutex.lock()
	bad_blocks += 1
	_mutex.unlock()
	push_error("server: bad block %s at LOD %d: solid at column (%d, %d) layer %d, y %.1f, but the ground there is %.1f; not saved" % [str(block), lod, cx, cz, layer, y, h])


# The block as it is sent to clients: buried ore hidden, compressed.
func block_bytes(block: Vector3i, lod: int) -> PackedByteArray:
	var buffer: VoxelBuffer = Layout.make_buffer(BLOCK_SIZE)
	load_block(buffer, block, lod)
	hide_buried_ore(buffer, hide_ore_depth_m * float(1 << lod))
	return VoxelBlockSerializer.serialize_to_byte_array(buffer, VoxelBlockSerializer.COMPRESSION_ZSTD)


static func hide_buried_ore(buffer: VoxelBuffer, depth: float) -> void:
	if buffer.is_uniform(Layout.CHANNEL_RESOURCE) and buffer.get_voxel(0, 0, 0, Layout.CHANNEL_RESOURCE) == 0:
		return

	var size: Vector3i = buffer.get_size()

	for z in range(size.z):
		for x in range(size.x):
			for y in range(size.y):
				if buffer.get_voxel(x, y, z, Layout.CHANNEL_RESOURCE) != 0 and buffer.get_voxel_f(x, y, z, Layout.CHANNEL_SDF) < -depth:
					buffer.set_voxel(0, x, y, z, Layout.CHANNEL_RESOURCE)


# Removes a sphere of ground (LOD 0 blocks only) and stores the changed
# blocks as edits. Returns the tiles whose revision rose.
func dig_sphere(center: Vector3, radius: float) -> Array:
	var low: Vector3i = Vector3i(((center - Vector3.ONE * (radius + 2.0)) / float(BLOCK_SIZE)).floor())
	var high: Vector3i = Vector3i(((center + Vector3.ONE * (radius + 2.0)) / float(BLOCK_SIZE)).floor())
	var changed_tiles: Dictionary = {}
	_edit_mutex.lock()

	for bz in range(low.z, high.z + 1):
		for by in range(low.y, high.y + 1):
			for bx in range(low.x, high.x + 1):
				var block: Vector3i = Vector3i(bx, by, bz)
				var origin: Vector3 = Vector3(block * BLOCK_SIZE)

				if Vector3(clampf(center.x, origin.x, origin.x + BLOCK_SIZE), clampf(center.y, origin.y, origin.y + BLOCK_SIZE), clampf(center.z, origin.z, origin.z + BLOCK_SIZE)).distance_to(center) > radius + 2.0:
					continue

				var buffer: VoxelBuffer = Layout.make_buffer(BLOCK_SIZE)
				load_block(buffer, block, 0)

				for z in range(BLOCK_SIZE):
					for y in range(BLOCK_SIZE):
						for x in range(BLOCK_SIZE):
							var d: float = (origin + Vector3(x, y, z)).distance_to(center) - radius

							if d > 2.0:
								continue

							var sdf: float = buffer.get_voxel_f(x, y, z, Layout.CHANNEL_SDF)

							if -d > sdf:
								buffer.set_voxel_f(-d, x, y, z, Layout.CHANNEL_SDF)

							if d < 0.0:
								buffer.set_voxel(0, x, y, z, Layout.CHANNEL_ROCK)
								buffer.set_voxel(0, x, y, z, Layout.CHANNEL_SOIL)
								buffer.set_voxel(0, x, y, z, Layout.CHANNEL_RESOURCE)

				_edits.save_voxel_block(buffer, block, 0)
				changed_tiles[generator.tile_of(origin.x, origin.z)] = true

	_edits.flush()

	for tile in changed_tiles:
		var key: String = "%d,%d" % [tile.x, tile.y]
		tile_revisions[key] = int(tile_revisions.get(key, 1)) + 1

	var file: FileAccess = FileAccess.open(_store_dir + "/revisions.json", FileAccess.WRITE)

	if file != null:
		file.store_string(JSON.stringify(tile_revisions, "\t", true))
		file.close()

	_edit_mutex.unlock()
	return changed_tiles.keys()


func flush() -> void:
	_cache.flush()
	_edits.flush()


func _count(kind: String) -> void:
	_mutex.lock()

	match kind:
		"edit":
			edit_hits += 1
		"cache":
			cache_hits += 1
		_:
			blocks_generated += 1

	_mutex.unlock()
