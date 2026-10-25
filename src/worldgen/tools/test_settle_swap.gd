extends SceneTree

# Thread-safety (25 Oct): the settled-copies object is swapped (set_settle) on the main thread while worker threads take it (_settle_now) and ask it for a block: every one taken must be valid and answer.
#   godot --headless --path . --script res://src/worldgen/tools/test_settle_swap.gd      Prints "Test done: N pass, N fail".

const StoreScript := preload("res://src/stream/server_block_store.gd")
const GroundSettle := preload("res://src/stream/ground_settle.gd")

var passes: int = 0
var failures: int = 0
var _stop: bool = false
var _bad: int = 0
var _reads: int = 0
var _mutex: Mutex = Mutex.new()


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


func _worker(store) -> void:
	var bad: int = 0
	var reads: int = 0

	while true:
		_mutex.lock()
		var stop: bool = _stop
		_mutex.unlock()

		if stop:
			break

		var current = store._settle_now()
		reads += 1

		if current == null or not is_instance_valid(current) or current.upto_of(Vector3i(reads % 7, 0, 0)) != 0:
			bad += 1

	_mutex.lock()
	_bad += bad
	_reads += reads
	_mutex.unlock()


func _init() -> void:
	var store = StoreScript.new()
	var threads: Array = []

	for n in range(3):
		var thread: Thread = Thread.new()
		thread.start(_worker.bind(store))
		threads.append(thread)

	var swaps: int = 0

	for n in range(100):
		var old = store._settle_now()
		store.set_settle(GroundSettle.new())
		old.close()
		swaps += 1
		OS.delay_msec(2)

	_mutex.lock()
	_stop = true
	_mutex.unlock()

	for thread in threads:
		thread.wait_to_finish()

	check(_bad == 0 and _reads > 100, "3 workers, %d swaps, %d reads: every settled object taken is valid and answers (%d bad)" % [swaps, _reads, _bad])
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
