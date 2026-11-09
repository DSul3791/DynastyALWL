extends SceneTree

# A zeroed block (every SDF exactly 0: a box to the mesher) is never stored (design_notes/zeroed_block_note.md, 9 Nov 2026): ensure_block
# and the second build in _load_base skip the save, and block_bytes names the path in its log line and still serves it (the client refuses it
# and asks again). A good block is stored as before.
#   godot --headless --path . --script res://src/worldgen/tools/test_block_zeroed.gd      Prints "Test done: N pass, N fail".

const StoreScript := preload("res://src/stream/server_block_store.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")

var passes: int = 0
var failures: int = 0


class FakeGenerator:
	var failed_tiles: int = 0
	var zeroed: bool = true

	func generate(buffer: VoxelBuffer, _origin: Vector3i, _lod: int) -> void:
		buffer.fill_f(0.0 if zeroed else 40.0, Layout.CHANNEL_SDF)   # zeroed: nobody wrote the distances; else air 40 m over the ground

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

	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
