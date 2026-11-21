extends RefCounted

# print() on a worker, in order (D-LAG-1, BugsList 108): on Dave's PC a debug build flushes stdout and the log file on every print, and one
# print held the client's main thread 400 ms to 1.6 s while running (Lane A, 21 Nov 2026; the server moved its prints off the tick for the
# same reason, server_items #397). line() only queues; one worker task at a time prints the queue, so lines come out a few ms later and in
# order. drain() waits for them (a clean exit). The same shape as LineWriter (src/shared/line_writer.gd), for the console instead of a file.

var _queue: PackedStringArray = PackedStringArray()
var _mutex: Mutex = Mutex.new()
var _task: int = -1
var _busy: bool = false   # a task is running or about to take the queue


# Queues one line (any thread).
func line(text: String) -> void:
	var finished: int = -1
	_mutex.lock()
	_queue.append(text)

	if not _busy:
		_busy = true
		finished = _task   # the last task, done already (it cleared _busy as its last step): waited for once, below, outside the lock
		_task = WorkerThreadPool.add_task(_run, true, "print lines")   # high priority: low-priority workers can be held a minute by flora chunks (#397)

	_mutex.unlock()

	if finished >= 0:
		WorkerThreadPool.wait_for_task_completion(finished)


# Waits until every queued line is printed.
func drain() -> void:
	_mutex.lock()
	var last: int = _task
	_task = -1
	_mutex.unlock()

	if last >= 0:
		WorkerThreadPool.wait_for_task_completion(last)   # it prints until the queue is empty, then ends


func _run() -> void:
	while true:
		_mutex.lock()
		var lines: PackedStringArray = _queue
		_queue = PackedStringArray()

		if lines.is_empty():
			_busy = false
			_mutex.unlock()
			return

		_mutex.unlock()

		for text in lines:
			print(text)
