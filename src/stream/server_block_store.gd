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
var _timing_on: bool = OS.has_environment("BLOCKTIME")
var _timing: Dictionary = {}            # piece -> [calls, microseconds]; printed at exit when BLOCKTIME is set
var _edit_mutex: Mutex = Mutex.new()
var _digs: PackedFloat32Array = PackedFloat32Array()   # the dig log: x, y, z, radius per dig, in order (digs.dat, DIGGING_DESIGN.md)
var _dig_index: Dictionary = {}         # block (Vector3i) -> PackedInt32Array of dig numbers that reach it


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
	_load_digs()
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
const BAKE_LOCK_STALE_SEC := 1800   # a bake lock this old is left over from a bake that died


func check_tiles(now_msec: int) -> bool:
	# Owner (2026-10-19): while a bake runs, wait; reload once when all its tiles are written.
	if baking():
		_dates_changed_msec = -1
		return false

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


# A bake is writing the tile files (bake_tiles.gd keeps a lock file there, touched after
# every tile; one older than BAKE_LOCK_STALE_SEC is left over from a bake that died).
func baking() -> bool:
	var lock: String = generator.tiles_dir + "/baking.lock"

	if not FileAccess.file_exists(lock):
		return false

	return int(Time.get_unix_time_from_system()) - FileAccess.get_modified_time(lock) < BAKE_LOCK_STALE_SEC


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


# The full block (nothing hidden) into `buffer`: the ground as generated (or kept from an older edit), with
# every logged dig that reaches it cut again on top, so a re-bake keeps the holes.
func load_block(buffer: VoxelBuffer, block: Vector3i, lod: int) -> void:
	_load_base(buffer, block, lod)

	if lod == 0:
		_apply_digs(buffer, block)


func _load_base(buffer: VoxelBuffer, block: Vector3i, lod: int) -> void:
	if _edits.load_voxel_block(buffer, block, lod) == VoxelStream.RESULT_BLOCK_FOUND:
		_count("edit")
		return

	var cache: VoxelStreamSQLite = _cache

	if cache.load_voxel_block(buffer, block, lod) == VoxelStream.RESULT_BLOCK_FOUND:
		_count("cache")
		return

	var failed_before: int = generator.failed_tiles
	var t0: int = Time.get_ticks_usec()
	generator.generate(buffer, block * (BLOCK_SIZE << lod), lod)
	var t1: int = Time.get_ticks_usec()
	if _timing_on:
		_time("generate lod %d" % lod, t1 - t0)

	# A block built from a stand-in tile, or one that fails the check, is served this
	# once but never saved, so a bad build cannot become permanent.
	var sane: bool = generator.failed_tiles == failed_before and _is_sane(buffer, block, lod)
	var t2: int = Time.get_ticks_usec()
	if _timing_on:
		_time("sanity check", t2 - t1)

	if sane:
		cache.save_voxel_block(buffer, block, lod)
		if _timing_on:
			_time("save to sqlite", Time.get_ticks_usec() - t2)
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
	var t0: int = Time.get_ticks_usec()
	var bytes: PackedByteArray = VoxelBlockSerializer.serialize_to_byte_array(buffer, VoxelBlockSerializer.COMPRESSION_ZSTD)
	if _timing_on:
		_time("serialize zstd", Time.get_ticks_usec() - t0)
	return bytes


static func hide_buried_ore(buffer: VoxelBuffer, depth: float) -> void:
	if buffer.is_uniform(Layout.CHANNEL_RESOURCE) and buffer.get_voxel(0, 0, 0, Layout.CHANNEL_RESOURCE) == 0:
		return

	var size: Vector3i = buffer.get_size()

	for z in range(size.z):
		for x in range(size.x):
			for y in range(size.y):
				if buffer.get_voxel(x, y, z, Layout.CHANNEL_RESOURCE) != 0 and buffer.get_voxel_f(x, y, z, Layout.CHANNEL_SDF) < -depth:
					buffer.set_voxel(0, x, y, z, Layout.CHANNEL_RESOURCE)


# The dig log (digs.dat, version 1): "DIGS1", then x, y, z, radius as four float32 per dig, appended in order.
const DIGS_MAGIC := "DIGS1"


func _load_digs() -> void:
	_digs = PackedFloat32Array()
	_dig_index = {}
	var path: String = _store_dir + "/digs.dat"

	if not FileAccess.file_exists(path):
		return

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var head: int = DIGS_MAGIC.length()

	if bytes.size() < head or bytes.slice(0, head).get_string_from_ascii() != DIGS_MAGIC:
		push_warning("server: digs.dat is not a version 1 dig log, ignored")
		return

	var body: PackedByteArray = bytes.slice(head, head + ((bytes.size() - head) / 16) * 16)
	_digs = body.to_float32_array()

	for n in range(_digs.size() / 4):
		_index_dig(n)

	print("server: %d dug holes loaded from digs.dat" % (_digs.size() / 4))


# The blocks a dig reaches (a margin of 2 m for the surface band) and the tiles they lie in.
func _dig_blocks(center: Vector3, radius: float) -> Array:
	var low: Vector3i = Vector3i(((center - Vector3.ONE * (radius + 2.0)) / float(BLOCK_SIZE)).floor())
	var high: Vector3i = Vector3i(((center + Vector3.ONE * (radius + 2.0)) / float(BLOCK_SIZE)).floor())
	var blocks: Array = []

	for bz in range(low.z, high.z + 1):
		for by in range(low.y, high.y + 1):
			for bx in range(low.x, high.x + 1):
				var block: Vector3i = Vector3i(bx, by, bz)
				var origin: Vector3 = Vector3(block * BLOCK_SIZE)

				if Vector3(clampf(center.x, origin.x, origin.x + BLOCK_SIZE), clampf(center.y, origin.y, origin.y + BLOCK_SIZE), clampf(center.z, origin.z, origin.z + BLOCK_SIZE)).distance_to(center) <= radius + 2.0:
					blocks.append(block)

	return blocks


func _index_dig(n: int) -> void:
	var center: Vector3 = Vector3(_digs[n * 4], _digs[n * 4 + 1], _digs[n * 4 + 2])

	for block in _dig_blocks(center, _digs[n * 4 + 3]):
		var list: PackedInt32Array = _dig_index.get(block, PackedInt32Array())
		list.append(n)
		_dig_index[block] = list


# Cuts every logged dig that reaches `block` out of the freshly made block, oldest first.
func _apply_digs(buffer: VoxelBuffer, block: Vector3i) -> void:
	_edit_mutex.lock()
	var list: PackedInt32Array = _dig_index.get(block, PackedInt32Array())
	var records: PackedFloat32Array = PackedFloat32Array()

	for n in list:
		records.append_array(_digs.slice(n * 4, n * 4 + 4))

	_edit_mutex.unlock()
	var origin: Vector3 = Vector3(block * BLOCK_SIZE)

	for n in range(records.size() / 4):
		_cut_sphere(buffer, origin, Vector3(records[n * 4], records[n * 4 + 1], records[n * 4 + 2]), records[n * 4 + 3])


# Removes a sphere of ground from one block (origin = the block's corner in metres).
static func _cut_sphere(buffer: VoxelBuffer, origin: Vector3, center: Vector3, radius: float) -> void:
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


# Digs a sphere of ground (LOD 0 blocks only): the dig is appended to the dig log, and the tiles it
# touches get a new revision. Returns those tiles.
func dig_sphere(center: Vector3, radius: float) -> Array:
	var changed_tiles: Dictionary = {}
	_edit_mutex.lock()
	var path: String = _store_dir + "/digs.dat"
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE) if FileAccess.file_exists(path) else FileAccess.open(path, FileAccess.WRITE)

	if file != null:
		if file.get_length() == 0:
			file.store_buffer(DIGS_MAGIC.to_ascii_buffer())

		file.seek_end()
		file.store_buffer(PackedFloat32Array([center.x, center.y, center.z, radius]).to_byte_array())
		file.close()

	_digs.append_array(PackedFloat32Array([center.x, center.y, center.z, radius]))
	_index_dig(_digs.size() / 4 - 1)

	for block in _dig_blocks(center, radius):
		changed_tiles[generator.tile_of(float(block.x * BLOCK_SIZE), float(block.z * BLOCK_SIZE))] = true

	for tile in changed_tiles:
		var key: String = "%d,%d" % [tile.x, tile.y]
		tile_revisions[key] = int(tile_revisions.get(key, 1)) + 1

	var revisions_file: FileAccess = FileAccess.open(_store_dir + "/revisions.json", FileAccess.WRITE)

	if revisions_file != null:
		revisions_file.store_string(JSON.stringify(tile_revisions, "\t", true))
		revisions_file.close()

	_edit_mutex.unlock()
	return changed_tiles.keys()


func flush() -> void:
	_cache.flush()
	_edits.flush()


func _time(piece: String, usec: int) -> void:
	_mutex.lock()
	var entry: Array = _timing.get(piece, [0, 0])
	entry[0] += 1
	entry[1] += usec
	_timing[piece] = entry
	_mutex.unlock()


func timing_report() -> String:
	var lines: PackedStringArray = PackedStringArray()

	for piece in _timing:
		lines.append("  %-16s %6d calls  avg %7.2f ms" % [piece, _timing[piece][0], float(_timing[piece][1]) / 1000.0 / float(maxi(_timing[piece][0], 1))])

	return "block timing:\n" + "\n".join(lines)


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
