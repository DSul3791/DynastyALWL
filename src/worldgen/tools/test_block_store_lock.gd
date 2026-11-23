extends SceneTree

# The generated-ground cache under load from many threads (robot play test 23 Nov 2026: "ERROR: database is locked" twice at load_block while
# the workers built ground). Five threads do what the workers and idle builders do: look a block up, make and save it when it is missing, read
# old ones again, while the SQLite stream writes its cached blocks out. Through the block store's _cache_load and _cache_save every read either
# finds its block or reports it missing (no read fails, no saved block comes back wrong) and no read waits long. The settled copies (ground
# settle) take their own lock round every SQLite call.
#   godot --headless --path . --script res://src/worldgen/tools/test_block_store_lock.gd

const BlockStore := preload("res://src/stream/server_block_store.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const THREADS := 5
const PER_THREAD := 6000
const WAIT_MAX_US := 300000   # without the lock a read beside a write-out waited about a second, then failed

var failures: int = 0
var store
var stream: VoxelStreamSQLite
var counts: Array = [0, 0, 0]
var wrong: int = 0
var worst_us: int = 0
var next_key: int = 0
var saved: Dictionary = {}   # every key saved
var m: Mutex = Mutex.new()


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func key_of(k: int) -> Vector3i:
	@warning_ignore("integer_division")
	return Vector3i(k % 300, 0, k / 300)


func worker() -> void:
	var buf: VoxelBuffer = Layout.make_buffer(16)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(OS.get_thread_caller_id())

	for i in PER_THREAD:
		m.lock()
		var k: int = next_key
		next_key += 1
		m.unlock()
		var key: Vector3i = key_of(k) if rng.randf() < 0.7 else key_of(rng.randi_range(0, maxi(k - THREADS * 4, 0)))
		var t0: int = Time.get_ticks_usec()
		var r: int = store._cache_load(stream, buf, key, 0)
		var dt: int = Time.get_ticks_usec() - t0
		m.lock()
		counts[r] += 1
		worst_us = maxi(worst_us, dt)

		if r == VoxelStream.RESULT_BLOCK_FOUND and buf.get_voxel(1, 1, 1, Layout.CHANNEL_ROCK) != key.x % 200 + 1:
			wrong += 1

		m.unlock()

		if r != VoxelStream.RESULT_BLOCK_FOUND:
			buf.fill(key.x % 200 + 1, Layout.CHANNEL_ROCK)
			store._cache_save(stream, BlockStore.copy_of(buf), key, 0)
			m.lock()
			saved[key] = true
			m.unlock()


func _init() -> void:
	var path: String = ProjectSettings.globalize_path("user://test_block_store_lock.sqlite")
	DirAccess.remove_absolute(path)
	store = BlockStore.new()
	stream = VoxelStreamSQLite.new()
	stream.database_path = path
	store._warm(stream)
	var threads: Array = []
	var t_start: int = Time.get_ticks_msec()

	for n in THREADS:
		var t := Thread.new()
		t.start(worker)
		threads.append(t)

	for t in threads:
		t.wait_to_finish()

	var took: int = Time.get_ticks_msec() - t_start
	print("  %d reads in %d ms: %d failed, %d missing, %d found; longest read %d us" % [THREADS * PER_THREAD, took, counts[0], counts[1], counts[2], worst_us])
	check(counts[0] == 0, "no read of the generated-ground cache fails while other threads save (%d failed)" % counts[0])
	check(wrong == 0 and counts[2] > 0, "every block read back is the one saved (%d wrong of %d)" % [wrong, counts[2]])
	check(worst_us < WAIT_MAX_US, "no read waits long beside a write-out (%d us)" % worst_us)

	# After a flush taken under the same lock, every block saved is in the file.
	store._cache_db_mutex.lock()
	stream.flush()
	store._cache_db_mutex.unlock()
	var again: VoxelStreamSQLite = VoxelStreamSQLite.new()
	again.database_path = path
	var buf: VoxelBuffer = Layout.make_buffer(16)
	var missing: int = 0

	for key in saved:
		if again.load_voxel_block(buf, key, 0) != VoxelStream.RESULT_BLOCK_FOUND or buf.get_voxel(1, 1, 1, Layout.CHANNEL_ROCK) != key.x % 200 + 1:
			missing += 1

	check(saved.size() > 10000 and missing == 0, "after the flush, every one of the %d saved blocks is in the file, as saved (%d missing)" % [saved.size(), missing])

	# Every SQLite call of the block store's cache and of the settled copies goes through its lock.
	var src: String = FileAccess.get_file_as_string("res://src/stream/server_block_store.gd")
	var settle_src: String = FileAccess.get_file_as_string("res://src/stream/ground_settle.gd")
	check(src.count("cache.load_voxel_block(") == 1 and src.count("cache.save_voxel_block(") == 1 and not src.contains("_cache_now().load_voxel_block(") and not src.contains("stream.load_voxel_block("), "the block store reads and writes its cache only through _cache_load and _cache_save")
	check(settle_src.count("_db.load_voxel_block(") == 2 and settle_src.count("_db_mutex.lock()") == 2, "the settled copies read and write their file under their own lock")
	print("block store lock: %d failures" % failures)
	quit(1 if failures > 0 else 0)
