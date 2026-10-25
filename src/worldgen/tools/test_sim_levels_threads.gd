extends SceneTree

# Thread-safety (25 Oct): TileTerrainData.set_sim() on the main thread while reader threads take sim_snapshot() and index it; take_pair() returns levels and falls together.
#   godot --headless --path . --script res://src/worldgen/tools/test_sim_levels_threads.gd      Prints "Test done: N pass, N fail".

const DataScript := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const LiveScript := preload("res://src/water/water_live.gd")

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


func _reader(data) -> void:
	var local_bad: int = 0
	var local_reads: int = 0

	while true:
		_mutex.lock()
		var stop: bool = _stop
		_mutex.unlock()

		if stop:
			break

		var sim: PackedFloat32Array = data.sim_snapshot()
		var falls: PackedFloat32Array = data.falls_snapshot()
		local_reads += 1

		if not sim.is_empty():
			var last: float = sim[sim.size() - 1]      # check and index on the same local: must be a whole array every time

			if sim.size() != 1089 or last != 7.0:
				local_bad += 1

		if not falls.is_empty() and falls.size() != 1089:
			local_bad += 1

	_mutex.lock()
	_bad += local_bad
	_reads += local_reads
	_mutex.unlock()


func _init() -> void:
	var data = DataScript.new()
	var threads: Array = []

	for n in range(4):
		var thread: Thread = Thread.new()
		thread.start(_reader.bind(data))
		threads.append(thread)

	var full: PackedFloat32Array = PackedFloat32Array()
	full.resize(1089)
	full.fill(7.0)
	var start: int = Time.get_ticks_msec()
	var writes: int = 0

	while Time.get_ticks_msec() - start < 3000:
		data.set_sim(full.duplicate(), full.duplicate())
		data.set_sim(PackedFloat32Array(), PackedFloat32Array())
		writes += 2

	_mutex.lock()
	_stop = true
	_mutex.unlock()

	for thread in threads:
		thread.wait_to_finish()

	check(_bad == 0, "4 readers, %d writes, %d reads: every snapshot is a whole array (%d bad)" % [writes, _reads, _bad])
	check(writes > 100 and _reads > 100, "the loop ran (%d writes, %d reads)" % [writes, _reads])

	var live = LiveScript.new()
	check((live.take_pair()[0] as PackedFloat32Array).is_empty() and live.take_pair().size() == 2, "take_pair on an idle sim: an empty pair of two")
	live._pending = full.duplicate()
	live._pending_falls = full.duplicate()
	var pair: Array = live.take_pair()
	check((pair[0] as PackedFloat32Array).size() == 1089 and (pair[1] as PackedFloat32Array).size() == 1089, "take_pair returns the levels and their matching falls")
	check((live.take_pair()[0] as PackedFloat32Array).is_empty(), "the levels are taken once")
	# Timing (Tyler: the snapshot must not slow the join): 100000 snapshots and indexes of a full 1089-sample array.
	data.set_sim(full.duplicate(), full.duplicate())
	var t0: int = Time.get_ticks_usec()
	var sum: float = 0.0

	for n in range(100000):
		var snap: PackedFloat32Array = data.sim_snapshot()
		sum += snap[n % 1089]

	var per_call_us: float = float(Time.get_ticks_usec() - t0) / 100000.0
	print("timing: sim_snapshot + index %.3f us per call (sum %.0f)" % [per_call_us, sum])
	check(per_call_us < 5.0, "a snapshot costs under 5 us per call (%.3f)" % per_call_us)
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
