extends SceneTree

# The periodic save never waits for the worker pool. After every server start the first save froze the server tick 55-110 s: save() waited
# for its queued log lines, and those sat behind the flora cover chunks a join starts (5-56 s each) on the pool's few low-priority threads
# (David4 15 Nov 2026, diagnostic f90983f9). Here every low-priority pool thread is held, a log line is queued, and the periodic save must
# return at once with the files written, the line printed anyway (high priority), and the held jobs untouched.
#   godot --headless --path . --script res://src/worldgen/tools/test_save_no_pool_wait.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

const DIR := "user://test_save_no_pool_wait"
const HOLD_TASKS := 64        # more than every low-priority thread of any pool (30 % of the threads)
const RELEASE_AFTER_MS := 4000   # a save that still waited would end only when the held jobs are let go
const SAVE_MAX_MS := 500.0

var failures: int = 0
var _gate: Semaphore = Semaphore.new()


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _held_job() -> void:
	_gate.wait()


func _release_later() -> void:
	OS.delay_msec(RELEASE_AFTER_MS)

	for n in range(HOLD_TASKS):
		_gate.post()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.setup(ItemTableScript.load_default(), DIR)

	var held: Array = []

	for n in range(HOLD_TASKS):
		held.append(WorkerThreadPool.add_task(_held_job, false, "held low-priority job"))

	var releaser: Thread = Thread.new()
	releaser.start(_release_later)   # so a save that waits on the pool fails slowly instead of hanging the run
	OS.delay_msec(100)   # the held jobs take their threads

	items._log_off_main("test_save_no_pool_wait: a log line queued while the low-priority pool threads are held")
	items._dirty = true
	var t0: int = Time.get_ticks_usec()
	items._async_writes = true   # as the periodic save in tick()
	items.save()
	items._async_writes = false
	items._start_writer()
	var save_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("periodic save with the low-priority pool held: %.1f ms" % save_ms)
	check(save_ms < SAVE_MAX_MS, "the periodic save waited %.0f ms for the worker pool (at most %.0f)" % [save_ms, SAVE_MAX_MS])

	var line_ms: float = -1.0

	while line_ms < 0.0 and Time.get_ticks_usec() - t0 < 2000000:
		if items._log_tasks.is_empty() or WorkerThreadPool.is_task_completed(items._log_tasks[0]):
			line_ms = float(Time.get_ticks_usec() - t0) / 1000.0
		else:
			OS.delay_msec(5)

	check(line_ms >= 0.0 and line_ms < 2000.0, "the log line was not printed while the low-priority threads were held")

	var done_early: int = 0

	for task in held:
		if WorkerThreadPool.is_task_completed(task):
			done_early += 1

	check(done_early == 0, "%d held jobs ended before they were let go (the hold did not hold)" % done_early)

	items._finish_writer()
	check(FileAccess.file_exists(DIR + "/world_items.json") and FileAccess.file_exists(DIR + "/inventories.json"), "the periodic save did not write its files")

	releaser.wait_to_finish()

	for task in held:
		WorkerThreadPool.wait_for_task_completion(task)

	items._finish_writer()

	if failures == 0:
		print("test_save_no_pool_wait: PASS")
		quit(0)
	else:
		print("test_save_no_pool_wait: FAIL (%d)" % failures)
		quit(1)
