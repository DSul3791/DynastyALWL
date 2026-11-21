extends RefCounted

# Writes a log file's lines on a worker, so the thread that logs a line never waits for the disk (lag while running, 21 Nov 2026: on
# Dave's PC the client's main thread stalled 205 to 521 ms in the crash report and telemetry ticks, which flushed their files line by line).
# add() only queues the line; one worker task at a time takes the queue and writes and flushes it, so lines reach the file a few ms
# later and in order. When the file passes `cut_at` lines it is cut back to its last `keep` lines, on the worker too. drain() writes
# what is queued on the calling thread (a report about to read the file, a clean exit).

var path: String = ""

var _file: FileAccess
var _lines: int = 0
var _cut_at: int = 0
var _keep: int = 0
var _queue: PackedStringArray = PackedStringArray()
var _mutex: Mutex = Mutex.new()        # the queue and the task: held only for a moment, never over the disk
var _file_mutex: Mutex = Mutex.new()   # the file: one writer at a time (the worker or drain()), the queue taken under it so lines keep their order
var _task: int = -1
var _busy: bool = false                # a task is running or about to take the queue


# Starts the file afresh at `file_path` (after writing what an earlier file still had queued). False when it cannot be opened.
func open(file_path: String, cut_at: int, keep: int) -> bool:
	close()
	_file_mutex.lock()
	path = file_path
	_cut_at = cut_at
	_keep = keep
	_lines = 0
	_file = FileAccess.open(file_path, FileAccess.WRITE)
	var opened: bool = _file != null
	_file_mutex.unlock()
	return opened


# Queues one line (any thread).
func add(line: String) -> void:
	_mutex.lock()
	_queue.append(line)

	if not _busy:
		_busy = true

		if _task >= 0:
			WorkerThreadPool.wait_for_task_completion(_task)   # done already: it cleared _busy as its last step

		_task = WorkerThreadPool.add_task(_run, false, "log lines")

	_mutex.unlock()


# Writes the queued lines now, on the calling thread.
func drain() -> void:
	_file_mutex.lock()
	_write_batch(_take())
	_file_mutex.unlock()


# Writes what is queued and closes the file.
func close() -> void:
	drain()
	_file_mutex.lock()

	if _file != null:
		_file.close()
		_file = null

	_file_mutex.unlock()


func _take() -> PackedStringArray:
	_mutex.lock()
	var lines: PackedStringArray = _queue
	_queue = PackedStringArray()
	_mutex.unlock()
	return lines


func _run() -> void:
	while true:
		_file_mutex.lock()
		_mutex.lock()
		var lines: PackedStringArray = _queue
		_queue = PackedStringArray()

		if lines.is_empty():
			_busy = false
			_mutex.unlock()
			_file_mutex.unlock()
			return

		_mutex.unlock()
		_write_batch(lines)
		_file_mutex.unlock()


# Under _file_mutex.
func _write_batch(lines: PackedStringArray) -> void:
	if _file == null or lines.is_empty():
		return

	for line in lines:
		_file.store_line(line)

	_file.flush()
	_lines += lines.size()

	if _cut_at > 0 and _lines > _cut_at:
		_file.close()
		var all: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
		var kept: PackedStringArray = all.slice(maxi(all.size() - _keep, 0))
		_file = FileAccess.open(path, FileAccess.WRITE)

		if _file != null:
			_file.store_string("\n".join(kept))
			_file.flush()

		_lines = kept.size()
