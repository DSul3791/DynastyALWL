extends RefCounted

# WorkerThreadPool tasks that nothing else waits for (a tile prefetch, a flora chunk made for the cover or undergrowth index): add() starts
# one and keeps its id, and finish() waits for every one still running. An owner calls finish() when it shuts down, so no task of its own
# is still running while the engine shuts its worker pool down (main gate, 21 Nov 2026: the dedicated server crashed in engine teardown,
# "Index p_index = 1 is out of bounds (size() = 0)" then exit 132, after a clean stop in 5 of 16 stops on Lane B). Any thread.

var _mutex: Mutex = Mutex.new()
var _tasks: PackedInt64Array = PackedInt64Array()
var _closed: bool = false   # after finish(): add() starts nothing


# Starts `work` on the pool. Finished tasks are waited for (which frees them) as new ones start, so the list stays short. False after finish().
func add(work: Callable, what: String = "") -> bool:
	_mutex.lock()

	if _closed:
		_mutex.unlock()
		return false

	var still: PackedInt64Array = PackedInt64Array()

	for task in _tasks:
		if WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
		else:
			still.append(task)

	still.append(WorkerThreadPool.add_task(work, false, what))
	_tasks = still
	_mutex.unlock()
	return true


# Waits for every task started here; later add() calls start nothing. Not under the mutex: a task may itself call add().
func finish() -> void:
	_mutex.lock()
	_closed = true
	var left: PackedInt64Array = _tasks
	_tasks = PackedInt64Array()
	_mutex.unlock()

	for task in left:
		WorkerThreadPool.wait_for_task_completion(task)


func running() -> int:
	_mutex.lock()
	var count: int = _tasks.size()
	_mutex.unlock()
	return count
