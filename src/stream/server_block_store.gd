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
var blocks_generated: int = 0
var cache_hits: int = 0
var edit_hits: int = 0

var _store_dir: String = ""
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

	# Generated blocks from an older terrain version are thrown away.
	var version_path: String = store_dir + "/terrain_version.txt"
	var version: String = FileAccess.get_file_as_string(version_path).strip_edges() if FileAccess.file_exists(version_path) else ""

	if version != str(Layout.TERRAIN_VERSION):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(store_dir + "/generated.sqlite"))
		var file: FileAccess = FileAccess.open(version_path, FileAccess.WRITE)

		if file != null:
			file.store_string(str(Layout.TERRAIN_VERSION))
			file.close()

	_cache = VoxelStreamSQLite.new()
	_cache.database_path = ProjectSettings.globalize_path(store_dir + "/generated.sqlite")
	_edits = VoxelStreamSQLite.new()
	_edits.database_path = ProjectSettings.globalize_path(store_dir + "/edits.sqlite")
	var path: String = store_dir + "/revisions.json"

	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))

		if typeof(parsed) == TYPE_DICTIONARY:
			for key in parsed:
				tile_revisions[str(key)] = int(parsed[key])

	return ""


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

	if _cache.load_voxel_block(buffer, block, lod) == VoxelStream.RESULT_BLOCK_FOUND:
		_count("cache")
		return

	generator.generate(buffer, block * (BLOCK_SIZE << lod), lod)
	_cache.save_voxel_block(buffer, block, lod)
	_count("generated")


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
