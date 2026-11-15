extends SceneTree

# ServerFlora places each flora chunk once however many threads ask for it (15 Nov 2026: at a join a third of the chunk lists were placed
# twice side by side), different chunks still place side by side, a failed placement frees its chunk, and new tiles drop a placement in flight.
#   godot --headless --path . --script res://src/worldgen/tools/test_flora_place_gate.gd

const ServerFloraScript := preload("res://src/stream/server_flora.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# Takes 40 ms a chunk and counts calls and how many run at once.
class SlowPlacer:
	var chunk_m: float = 64.0
	var calls: Dictionary = {}
	var running: int = 0
	var most: int = 0
	var lock: Mutex = Mutex.new()

	func normalize(chunk: Vector2i) -> Vector2i:
		return chunk

	func chunk_origin(chunk: Vector2i) -> Vector2:
		return Vector2(chunk) * chunk_m

	func chunk_items(chunk: Vector2i, trees_only: bool = false):   # untyped: chunk (99, 99) fails the way a script error does (null)
		lock.lock()
		var key: Vector3i = Vector3i(chunk.x, chunk.y, 0 if trees_only else 1)
		calls[key] = int(calls.get(key, 0)) + 1
		running += 1
		most = maxi(most, running)
		lock.unlock()
		OS.delay_msec(40)
		lock.lock()
		running -= 1
		lock.unlock()
		if chunk == Vector2i(99, 99):
			return null

		var o: Vector2 = chunk_origin(chunk)
		return {"ids": PackedInt32Array([(1 << 16) | 1]), "positions": PackedVector3Array([Vector3(o.x + 5.0, 1.0, o.y + 5.0)]),
			"heights": PackedFloat32Array([12.0]), "yaws": PackedFloat32Array([0.0])}

	func species_by_id(_id: int) -> Dictionary:
		return {}

	func species_of(_id: int) -> Dictionary:
		return {}


func _ask(flora, chunks: Array, full: bool) -> void:
	for c in chunks:
		flora.chunk_bytes(c, full)


func _init() -> void:
	var placer = SlowPlacer.new()
	var flora = ServerFloraScript.new()
	flora.setup(placer, "user://test_flora_place_gate")
	var same: Array = [Vector2i(1, 1)]
	var threads: Array = []

	# Eight threads ask for the same chunk, full, at once; four more ask for its items (the warm job) at once.
	for n in range(8):
		var t: Thread = Thread.new()
		t.start(_ask.bind(flora, same, true))
		threads.append(t)

	for n in range(4):
		var t: Thread = Thread.new()
		t.start(func() -> void: flora.items_of(Vector2i(1, 1)))
		threads.append(t)

	for t in threads:
		t.wait_to_finish()

	check(int(placer.calls.get(Vector3i(1, 1, 1), 0)) == 1, "a chunk twelve threads ask for at once is placed once (%d)" % int(placer.calls.get(Vector3i(1, 1, 1), 0)))

	# Twelve threads, each its own four chunks trees only: they place side by side (no queue behind one lock), and every chunk once.
	threads.clear()
	placer.most = 0

	for n in range(12):
		var mine: Array = []

		for k in range(4):
			mine.append(Vector2i(10 + n, k))

		var t: Thread = Thread.new()
		t.start(_ask.bind(flora, mine, false))
		threads.append(t)

	for t in threads:
		t.wait_to_finish()

	var once: bool = true

	for n in range(12):
		for k in range(4):
			once = once and int(placer.calls.get(Vector3i(10 + n, k, 0), 0)) == 1

	check(placer.most >= 2, "different chunks place side by side (%d at once)" % placer.most)
	check(once, "each of the 48 chunks is placed once")

	# A failed placement frees its chunk: the next asker places it again instead of waiting forever, and nothing is kept.
	flora.items_of(Vector2i(99, 99))
	flora.items_of(Vector2i(99, 99))
	check(int(placer.calls.get(Vector3i(99, 99, 1), 0)) == 2 and flora.items_cached(Vector2i(99, 99)).is_empty(), "a failed placement is asked again, not waited on or kept")

	# New tiles (clear_memory) while a chunk is being placed: that old-ground list is not kept.
	var early: Thread = Thread.new()
	early.start(func() -> void: flora.items_of(Vector2i(5, 5)))
	while int(placer.calls.get(Vector3i(5, 5, 1), 0)) == 0:   # its placement has begun (it runs 40 ms)
		OS.delay_msec(1)

	flora.clear_memory()
	early.wait_to_finish()
	check(flora.items_cached(Vector2i(5, 5)).is_empty(), "a placement begun before new tiles is not kept")
	flora.items_of(Vector2i(5, 5))
	check(not flora.items_cached(Vector2i(5, 5)).is_empty(), "the next ask places it on the new ground and keeps it")
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
