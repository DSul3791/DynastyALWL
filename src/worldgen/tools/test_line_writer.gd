extends SceneTree

# LineWriter: log lines are written on a worker, in order, and drain() writes what is still queued (lag while running, 21 Nov 2026).
#   godot --headless --path . --script res://src/worldgen/tools/test_line_writer.gd

const LineWriterScript := preload("res://src/shared/line_writer.gd")
const EventLogScript := preload("res://src/shared/event_log.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _lines_of(path: String) -> PackedStringArray:
	return FileAccess.get_file_as_string(path).strip_edges().split("\n")


func _init() -> void:
	var path: String = "user://test_line_writer.log"
	var writer = LineWriterScript.new()
	check(writer.open(path, 0, 0), "the file opens")

	for n in range(200):
		writer.add("line %d" % n)

	var waited: int = 0

	while _lines_of(path).size() < 200 and waited < 2000:   # the worker writes them without drain()
		OS.delay_msec(10)
		waited += 10

	var lines: PackedStringArray = _lines_of(path)
	check(lines.size() == 200, "the worker wrote every line (%d)" % lines.size())
	check(lines.size() == 200 and lines[0] == "line 0" and lines[199] == "line 199", "in order")

	# Lines from several threads all arrive, and drain() leaves nothing queued.
	var tasks: Array = []

	for t in range(4):
		tasks.append(WorkerThreadPool.add_task(func() -> void:
			for n in range(50):
				writer.add("thread %d line %d" % [t, n])))

	for task in tasks:
		WorkerThreadPool.wait_for_task_completion(task)

	writer.drain()
	check(_lines_of(path).size() == 400, "drain() writes what is still queued (%d)" % _lines_of(path).size())
	writer.close()

	# Past cut_at lines the file is cut back to its last `keep` lines.
	var cut = LineWriterScript.new()
	cut.open(path, 100, 30)

	for n in range(150):
		cut.add("cut %d" % n)

	cut.close()
	var kept: PackedStringArray = _lines_of(path)
	check(kept.size() >= 30 and kept.size() <= 79, "the file was cut back (%d lines)" % kept.size())
	check(kept[kept.size() - 1] == "cut 149", "and keeps the newest line (%s)" % kept[kept.size() - 1])

	# EventLog goes through it: a line is in the file after drain().
	var events = EventLogScript.new()
	events.start("test_line_writer_events.log", "user://line_writer_test")
	events.event("hello")
	events.drain()
	check(FileAccess.get_file_as_string("user://line_writer_test/test_line_writer_events.log").contains("] hello"), "EventLog lines reach the file")

	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://line_writer_test/test_line_writer_events.log"))
	print("test_line_writer: %s" % ("PASS" if failures == 0 else "%d failures" % failures))
	quit(1 if failures > 0 else 0)
