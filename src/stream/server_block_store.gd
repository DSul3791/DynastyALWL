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
const GroundOps := preload("res://src/stream/ground_ops.gd")
const GroundSettle := preload("res://src/stream/ground_settle.gd")

const BLOCK_SIZE := 16

var generator
var hide_ore_depth_m: float = 2.0
var _revisions_dirty: bool = false
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
var settle_enabled: bool = true         # data/network.json "settled_ground": 0 turns settled copies off (every load replays the whole log)
var settle = GroundSettle.new()        # settled copies of busy blocks (ground_settle.gd); the edit log stays the truth
var ops = GroundOps.new()               # the ground edit log (digs.dat, DIGS2): digs and fills replayed over every block


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
	var ops_error: String = ops.open(ProjectSettings.globalize_path(store_dir) + "/digs.dat")

	if ops_error != "":
		return ops_error

	print("server: %d ground edits loaded from digs.dat" % ops.count)
	_purge_old_settled()
	var settle_error: String = _open_settle()

	if settle_error != "":
		return settle_error

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


func _settled_stem() -> String:
	return ProjectSettings.globalize_path(_store_dir) + "/settled_g%d" % _generation


# The settled copies of earlier generations (a bake, a cleared cache) are deleted: they were made from other ground.
func _purge_old_settled() -> void:
	var folder: String = ProjectSettings.globalize_path(_store_dir)

	for file in DirAccess.get_files_at(folder):
		if file.begins_with("settled_g") and not file.begins_with("settled_g%d." % _generation):
			DirAccess.remove_absolute(folder + "/" + file)


func _open_settle() -> String:
	settle.ops = ops
	settle.base_loader = _load_base_lod0
	settle.guard = _settled_ok
	ops.settled_upto = settle.upto_of
	return settle.open(_settled_stem())


func _load_base_lod0(buffer: VoxelBuffer, block: Vector3i) -> void:
	_load_base(buffer, block, 0)


func _settled_ok(buffer: VoxelBuffer, block: Vector3i) -> bool:
	return not looks_zeroed(buffer) and _is_sane(buffer, block, 0)


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

	set_cache(_open_generated())
	# The settled copies were made over the ground just thrown away: new files for the new generation, the old ones deleted.
	settle.close()
	settle = GroundSettle.new()
	_purge_old_settled()
	_open_settle()


# The generated-ground cache is swapped on the main thread (clear_generated) while workers read it: workers take their own reference under _mutex, so a worker that
# started with the old stream finishes with it (refcounted) and never uses a freed one.
func _cache_now() -> VoxelStreamSQLite:
	_mutex.lock()
	var stream: VoxelStreamSQLite = _cache
	_mutex.unlock()
	return stream


func set_cache(stream: VoxelStreamSQLite) -> void:
	_mutex.lock()
	_cache = stream
	_mutex.unlock()


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
	if lod == 0:
		# A busy block has a settled copy with its first `upto` edits in it: replay only the rest (the same ground as replaying
		# them all, ground_settle.gd).
		var upto: int = settle.try_load(buffer, block) if settle_enabled else -1

		if upto >= 0:
			ops.apply_range(buffer, block, upto, 1 << 30)
			return

	_load_base(buffer, block, lod)

	if lod == 0:
		ops.apply(buffer, block)


# The block as generated, before any dig or fill (the tunnel watch tells man-made spaces from natural caves with it).
func load_natural(buffer: VoxelBuffer, block: Vector3i) -> void:
	_load_base(buffer, block, 0)


# Real ground is never a whole block of distance exactly 0 (a buffer nobody filled reads that way): 27 spread voxels, 20 at zero.
static func looks_zeroed(buffer: VoxelBuffer) -> bool:
	var size: Vector3i = buffer.get_size()
	var zero: int = 0

	for k in range(3):
		for j in range(3):
			for i in range(3):
				@warning_ignore("integer_division")
				if absf(buffer.get_voxel_f(1 + i * (size.x - 3) / 2, 1 + j * (size.y - 3) / 2, 1 + k * (size.z - 3) / 2, Layout.CHANNEL_SDF)) < 0.0005:
					zero += 1

	return zero >= 20


func _load_base(buffer: VoxelBuffer, block: Vector3i, lod: int) -> void:
	if _edits.load_voxel_block(buffer, block, lod) == VoxelStream.RESULT_BLOCK_FOUND:
		if not looks_zeroed(buffer):
			_count("edit")
			return

		_count("zeroed_edit")
		print("server: ZEROED BLOCK %s LOD %d from the saved edits (generating it again)" % [str(block), lod])

	var cache: VoxelStreamSQLite = _cache_now()

	if cache.load_voxel_block(buffer, block, lod) == VoxelStream.RESULT_BLOCK_FOUND:
		# A saved copy is checked again on the way out (2026-10-21, a solid block floating over the lake): one that
		# fails is dropped and made again below.
		if _is_sane(buffer, block, lod) and not looks_zeroed(buffer):
			_count("cache")
			return

		if looks_zeroed(buffer):
			print("server: ZEROED BLOCK %s LOD %d from the generated-ground cache (generating it again)" % [str(block), lod])

		_count("cache_dropped")

	var failed_before: int = generator.failed_tiles
	var t0: int = Time.get_ticks_usec()
	generator.generate(buffer, block * (BLOCK_SIZE << lod), lod)
	var t1: int = Time.get_ticks_usec()
	if _timing_on:
		_time("generate lod %d" % lod, t1 - t0)

	# A block built from a stand-in tile, or one that fails the check, is served this
	# once but never saved, so a bad build cannot become permanent.
	var sane: bool = generator.failed_tiles == failed_before and _is_sane(buffer, block, lod) and not looks_zeroed(buffer)
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

	var cache: VoxelStreamSQLite = _cache_now()

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

	@warning_ignore("integer_division")
	for layer in [BLOCK_SIZE - 1, BLOCK_SIZE / 2]:
		var y: float = origin.y + float(layer) * s

		@warning_ignore("integer_division")
		for cz in [0, BLOCK_SIZE / 2, BLOCK_SIZE - 1]:
			@warning_ignore("integer_division")
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


# Debug (Dave 2026-10-21, a solid block standing in the lake that only a saved copy kept): what every store
# holds for the voxel at (x, y, z) at LOD 0, as text for the client's "Dump ground here" button.
func dump_cell(x: float, y: float, z: float) -> String:
	var block: Vector3i = Vector3i(floori(x / float(BLOCK_SIZE)), floori(y / float(BLOCK_SIZE)), floori(z / float(BLOCK_SIZE)))
	var local: Vector3i = Vector3i(floori(x) - block.x * BLOCK_SIZE, floori(y) - block.y * BLOCK_SIZE, floori(z) - block.z * BLOCK_SIZE)
	var lines: PackedStringArray = PackedStringArray()
	lines.append("server: voxel (%d, %d, %d), block %s, terrain version %d, tiles %s" % [floori(x), floori(y), floori(z), str(block), Layout.TERRAIN_VERSION, tiles_stamp])
	lines.append("server: ground height here %.2f m (generator)" % float(generator.surface_height(x, z)))
	var fresh: VoxelBuffer = Layout.make_buffer(BLOCK_SIZE)
	generator.generate(fresh, block * BLOCK_SIZE, 0)
	lines.append("server: freshly generated: " + _cell_text(fresh, local))
	var cached: VoxelBuffer = Layout.make_buffer(BLOCK_SIZE)

	if _cache_now().load_voxel_block(cached, block, 0) == VoxelStream.RESULT_BLOCK_FOUND:
		lines.append("server: generated-ground cache: " + _cell_text(cached, local) + ("" if _is_sane(cached, block, 0) else "   <-- FAILS THE SANITY CHECK"))
	else:
		lines.append("server: generated-ground cache: no copy of this block")

	var near: Array = ops.edits_near(Vector3(x, y, z), 24.0)
	lines.append("server: %d logged dig/fill operations within 24 m of this voxel%s" % [near.size(), "" if near.is_empty() else ": " + ", ".join(near.slice(0, 6).map(func(op): return "%s r%.1f at %s" % ["fill" if int(op[0]) == 1 else "dig", float(op[2]), str(Vector3(op[1]).round())]))])
	var edited: VoxelBuffer = Layout.make_buffer(BLOCK_SIZE)

	if _edits.load_voxel_block(edited, block, 0) == VoxelStream.RESULT_BLOCK_FOUND:
		lines.append("server: saved edit of this block: " + _cell_text(edited, local))
	else:
		lines.append("server: no saved edit of this block")

	return "\n".join(lines)


func _cell_text(buffer: VoxelBuffer, local: Vector3i) -> String:
	return "sdf %.2f (negative = solid), soil %d, rock %d, block %s" % [
		buffer.get_voxel_f(local.x, local.y, local.z, Layout.CHANNEL_SDF),
		buffer.get_voxel(local.x, local.y, local.z, Layout.CHANNEL_SOIL),
		buffer.get_voxel(local.x, local.y, local.z, Layout.CHANNEL_ROCK),
		"all one value" if buffer.is_uniform(Layout.CHANNEL_SDF) else "mixed",
	]


# The block as it is sent to clients: buried ore hidden, compressed.
func block_bytes(block: Vector3i, lod: int) -> PackedByteArray:
	var buffer: VoxelBuffer = Layout.make_buffer(BLOCK_SIZE)
	var failed_before: int = generator.failed_tiles
	load_block(buffer, block, lod)

	# Built from a stand-in tile (its file would not load just now, for instance during a bake): not ready. An empty
	# answer makes the client drop the block, not cache it, and ask again.
	if generator.failed_tiles != failed_before:
		_count("not_ready")
		return PackedByteArray()

	if looks_zeroed(buffer):
		print("server: ZEROED BLOCK %s LOD %d after generating; serving it anyway (failed tile loads %d)" % [str(block), lod, generator.failed_tiles])

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


# Digs a sphere of ground (LOD 0 blocks only): the dig is appended to the ground edit log, and the
# tiles it touches get a new revision. Returns those tiles ([] when the log refused it: its block is
# full, or an earlier dig already covers it).
func dig_sphere(center: Vector3, radius: float) -> Array:
	return edit_sphere(GroundOps.KIND_DIG, 0, center, radius)


# Adds a sphere of ground of soil number `material` (a fill: a dam, a filled ditch).
func fill_sphere(center: Vector3, radius: float, material: int) -> Array:
	return edit_sphere(GroundOps.KIND_FILL, material, center, radius)


func edit_sphere(kind: int, material: int, center: Vector3, radius: float) -> Array:
	var changed_tiles: Dictionary = {}
	_edit_mutex.lock()

	for block in ops.add(kind, material, center, radius):
		changed_tiles[generator.tile_of(float(block.x * BLOCK_SIZE), float(block.z * BLOCK_SIZE))] = true
		if settle_enabled:
			settle.consider(block)

	for tile in changed_tiles:
		var key: String = "%d,%d" % [tile.x, tile.y]
		tile_revisions[key] = int(tile_revisions.get(key, 1)) + 1

	if not changed_tiles.is_empty():
		_revisions_dirty = true

	_edit_mutex.unlock()
	return changed_tiles.keys()


# The revision file is written at most once a second (the server calls this from its frame) and at flush: a held click used to
# rewrite it on every dig.
func save_revisions() -> void:
	_edit_mutex.lock()

	if _revisions_dirty:
		_revisions_dirty = false
		var revisions_file: FileAccess = FileAccess.open(_store_dir + "/revisions.json", FileAccess.WRITE)

		if revisions_file != null:
			revisions_file.store_string(JSON.stringify(tile_revisions, "\t", true))
			revisions_file.close()

	_edit_mutex.unlock()


func flush() -> void:
	settle.close()
	save_revisions()
	_cache_now().flush()
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
