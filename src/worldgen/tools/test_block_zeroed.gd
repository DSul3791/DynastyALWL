extends SceneTree

# A zeroed block (every SDF exactly 0: a box to the mesher) is never stored (design_notes/zeroed_block_note.md, 9 Nov 2026): ensure_block
# and the second build in _load_base skip the save, and block_bytes names the path in its log line and still serves it (the client refuses it
# and asks again). A good block is stored as before.
# Also the cause (9 Nov, Dino's zeroed_check: the rebuild was good ground): Voxel Tools 1.7 moves a saved buffer into the SQLite stream's memory
# cache when that block is already there, and leaves the caller's buffer all zero. Two builds of one block at once (the join rush) served the
# emptied one. The store and the client cache now save a copy (server_block_store.copy_of).
#   godot --headless --path . --script res://src/worldgen/tools/test_block_zeroed.gd      Prints "Test done: N pass, N fail".

const StoreScript := preload("res://src/stream/server_block_store.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const CacheScript := preload("res://src/stream/client_block_cache.gd")

var passes: int = 0
var failures: int = 0


class FakeGenerator:
	var failed_tiles: int = 0
	var zeroed: bool = true
	var meanwhile: Callable = Callable()   # runs at the end of a build: another worker saving the same block in the meantime

	func generate(buffer: VoxelBuffer, _origin: Vector3i, _lod: int) -> void:
		buffer.fill_f(0.0 if zeroed else 40.0, Layout.CHANNEL_SDF)   # zeroed: nobody wrote the distances; else air 40 m over the ground

		if meanwhile.is_valid():
			meanwhile.call()

	func surface_height(_x: float, _z: float, _lod: int) -> float:
		return 0.0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _db(name: String) -> VoxelStreamSQLite:
	var path: String = ProjectSettings.globalize_path("user://test_block_zeroed_%s.sqlite" % name)

	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

	var db: VoxelStreamSQLite = VoxelStreamSQLite.new()
	db.database_path = path
	return db


func _init() -> void:
	var gen: FakeGenerator = FakeGenerator.new()
	var store = StoreScript.new()
	store.generator = gen
	store.settle_enabled = false
	store._edits = _db("edits")
	var cache: VoxelStreamSQLite = _db("cache")
	store.set_cache(cache)
	var block: Vector3i = Vector3i(0, 5, 0)
	var back: VoxelBuffer = Layout.make_buffer(StoreScript.BLOCK_SIZE)

	# 1. Idle pre-building: a zeroed build is not saved.
	check(store.ensure_block(block, 0), "ensure_block builds the block")
	check(cache.load_voxel_block(back, block, 0) != VoxelStream.RESULT_BLOCK_FOUND, "ensure_block does not save a zeroed block")

	# 2. Asked for: the zeroed build fails the check, is built again, and the second (still zeroed) build is not saved either; it is served.
	var bytes: PackedByteArray = store.block_bytes(block, 0)
	check(not bytes.is_empty(), "block_bytes still serves a zeroed block (the client refuses it and asks again)")
	check(cache.load_voxel_block(back, block, 0) != VoxelStream.RESULT_BLOCK_FOUND, "the second build of a zeroed block is not saved")

	# 3. The path a block came from.
	var trace: Array = []
	var buffer: VoxelBuffer = Layout.make_buffer(StoreScript.BLOCK_SIZE)
	store.load_block(buffer, block, 0, trace)
	check(trace.size() >= 1 and str(trace[0]).begins_with("generated twice"), "a zeroed build is traced as generated twice (%s)" % str(trace))

	# 4. A good block is saved and then comes from the cache.
	gen.zeroed = false
	check(store.ensure_block(block, 0), "nothing was stored before, so the good block is built")
	check(cache.load_voxel_block(back, block, 0) == VoxelStream.RESULT_BLOCK_FOUND and not StoreScript.looks_zeroed(back), "a good block is saved")
	trace = []
	store.load_block(buffer, block, 0, trace)
	check(trace.size() >= 1 and str(trace[0]) == "the generated-ground cache", "a saved block is traced to the cache (%s)" % str(trace))

	# 5. The engine trap itself: a second save of a block still in the stream's memory cache empties the saved buffer.
	var trap_db: VoxelStreamSQLite = _db("trap")
	var air: VoxelBuffer = Layout.make_buffer(StoreScript.BLOCK_SIZE)
	air.fill_f(40.0, Layout.CHANNEL_SDF)
	trap_db.save_voxel_block(air, block, 0)
	check(absf(air.get_voxel_f(8, 8, 8, Layout.CHANNEL_SDF) - 40.0) < 0.1, "a first save leaves the buffer as it was")
	trap_db.save_voxel_block(air, block, 0)
	check(StoreScript.looks_zeroed(air), "Voxel Tools: a second save before the flush leaves the buffer zeroed (if this fails, copy_of may no longer be needed)")
	air.fill_f(40.0, Layout.CHANNEL_SDF)
	trap_db.save_voxel_block(StoreScript.copy_of(air), block, 0)
	check(absf(air.get_voxel_f(8, 8, 8, Layout.CHANNEL_SDF) - 40.0) < 0.1, "saving a copy leaves the buffer as it was")
	var copied: VoxelBuffer = StoreScript.copy_of(air)
	check(copied.get_size() == air.get_size() and absf(copied.get_voxel_f(3, 9, 12, Layout.CHANNEL_SDF) - 40.0) < 0.1, "copy_of copies the distances")

	# 6. The join rush: while a block is being built, another worker builds and saves the same block. The block served must still be the good build.
	var rush: Vector3i = Vector3i(1, 5, 0)
	gen.meanwhile = func():
		gen.meanwhile = Callable()
		var other: VoxelBuffer = Layout.make_buffer(StoreScript.BLOCK_SIZE)
		other.fill_f(40.0, Layout.CHANNEL_SDF)
		cache.save_voxel_block(other, rush, 0)
	var served: PackedByteArray = store.block_bytes(rush, 0)
	var got: VoxelBuffer = Layout.make_buffer(StoreScript.BLOCK_SIZE)
	VoxelBlockSerializer.deserialize_from_byte_array(served, got, true)
	check(not StoreScript.looks_zeroed(got) and absf(got.get_voxel_f(8, 8, 8, Layout.CHANNEL_SDF) - 40.0) < 0.1, "a block saved by another worker meanwhile is not served zeroed")

	# 7. The client cache: a block saved twice before its stream flushes (asked for again) leaves the buffer the mesher gets intact.
	var dir: String = "user://test_block_zeroed_client"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var client_cache = CacheScript.new()
	client_cache.setup(dir, {"tile_size_m": 15360.0, "min_tile": -10, "tiles_per_side": 21}, {}, 64)
	var mesh_me: VoxelBuffer = Layout.make_buffer(StoreScript.BLOCK_SIZE)
	mesh_me.fill_f(40.0, Layout.CHANNEL_SDF)
	client_cache.save_block(mesh_me, block, 0)
	client_cache.save_block(mesh_me, block, 0)
	check(absf(mesh_me.get_voxel_f(8, 8, 8, Layout.CHANNEL_SDF) - 40.0) < 0.1, "the client cache leaves a buffer saved twice intact")
	var cached: VoxelBuffer = Layout.make_buffer(StoreScript.BLOCK_SIZE)
	check(client_cache.load_block(cached, block, 0) and absf(cached.get_voxel_f(8, 8, 8, Layout.CHANNEL_SDF) - 40.0) < 0.1, "and the cached copy is the block")

	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
