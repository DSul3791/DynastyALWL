extends RefCounted

# Crash reporting (Dave 2026-10-21: the game closed by itself twice, once beside a felled trunk and once in the inventory).
#
# While the game runs it keeps user://breadcrumbs.log: one line per key or mouse button press, menu change, script error or
# warning (Godot's Logger sees them from every thread) and a state line every 5 seconds (position, quality, fps, memory, video
# memory, windows open). Each line is flushed at once, so the file survives a crash. A flag file is written at start and removed
# at a clean exit. If the flag is still there at the next start, that run ended unexpectedly: the breadcrumbs and the end of
# Godot's log of that run (user://logs, the last 10 runs are kept) are bundled into
#   crash_reports/<date>_build<N>.txt
# inside the project folder (res://crash_reports, the folder the game is played from), under 200 KB, long hex tokens masked.
# It shows up as a changed file in GitHub Desktop; Dave commits and pushes it and it can be read here.
#
# The log of a hard native crash (a backtrace) is in Godot's own log file, which is why the end of that log is included.

const FLAG := "user://running.flag"
const BREAD := "user://breadcrumbs.log"
const REPORT_DIR := "res://crash_reports"
const KEEP_EVENTS := 150          # breadcrumb lines in a report
const KEEP_LOG_LINES := 300       # Godot log lines in a report
const MAX_BYTES := 190000
const FILE_LINES_MAX := 4000      # the breadcrumb file is cut back to its last 400 lines when it grows past this

var last_report: String = ""      # file name of the report made at this start ("" when the last run ended cleanly)
var _file: FileAccess
var _mutex: Mutex = Mutex.new()
var _lines_written: int = 0
var _logger: Logger
var _next_state_msec: int = 0
var _build: int = 0
var _last_tick_msec: int = 0


class BreadLogger extends Logger:
	var owner_report


	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array) -> void:
		if owner_report != null:
			owner_report.event("%s %s:%d %s %s (in %s)" % ["WARNING" if error_type == Logger.ERROR_TYPE_WARNING else "ERROR", file.get_file(), line, code, rationale, function])


# Call once at the start of the game. Makes the report of an unclean last run (if any), then marks this run as running.
func start(build: int, commit: String) -> void:
	_build = build
	last_report = _report_of_previous_run()
	var file: FileAccess = FileAccess.open(FLAG, FileAccess.WRITE)

	if file != null:
		file.store_string("build %d (%s), started %s" % [build, commit, Time.get_datetime_string_from_system(true)])
		file.close()

	_file = FileAccess.open(BREAD, FileAccess.WRITE)
	_lines_written = 0
	_logger = BreadLogger.new()
	_logger.owner_report = self
	OS.add_logger(_logger)
	event("start build %d (%s), %s, %s" % [build, commit, OS.get_name(), _machine()])


func mark_clean() -> void:
	event("clean exit")

	if _logger != null:
		OS.remove_logger(_logger)
		_logger = null

	_mutex.lock()

	if _file != null:
		_file.close()
		_file = null

	_mutex.unlock()

	if FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FLAG))


# One line in the breadcrumb file (any thread).
func event(text: String) -> void:
	_mutex.lock()

	if _file != null:
		var t: Dictionary = Time.get_time_dict_from_system()
		_file.store_line("[%02d:%02d:%02d.%03d] %s" % [t["hour"], t["minute"], t["second"], Time.get_ticks_msec() % 1000, text.replace("\n", " | ")])
		_file.flush()
		_lines_written += 1

	_mutex.unlock()


# Call every frame with a function that makes the state text; writes it every 5 seconds.
func tick(state: Callable) -> void:
	var now: int = Time.get_ticks_msec()

	if _last_tick_msec > 0 and now - _last_tick_msec > 1000:
		event("STALL: the main thread did not run for %d ms" % (now - _last_tick_msec))

	_last_tick_msec = now

	if now < _next_state_msec:
		return

	_next_state_msec = now + 5000
	event("state " + String(state.call()))

	if _lines_written > FILE_LINES_MAX:
		_trim()


func _trim() -> void:
	_mutex.lock()

	if _file != null:
		_file.close()
		var lines: PackedStringArray = FileAccess.get_file_as_string(BREAD).split("\n")
		var kept: PackedStringArray = lines.slice(maxi(lines.size() - 400, 0))
		_file = FileAccess.open(BREAD, FileAccess.WRITE)
		_file.store_string("\n".join(kept))
		_file.flush()
		_lines_written = kept.size()

	_mutex.unlock()


static func _machine() -> String:
	return "%s, %s, %d cores, ram %d MB, video memory %d MB" % [RenderingServer.get_video_adapter_name(), RenderingServer.get_video_adapter_api_version(), OS.get_processor_count(), int(OS.get_static_memory_usage() / 1048576), int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576)]


func _report_of_previous_run() -> String:
	if not FileAccess.file_exists(FLAG):
		return ""

	var flag: String = FileAccess.get_file_as_string(FLAG).strip_edges()
	var log_name: String = ""
	var log_time: int = 0

	for file in DirAccess.get_files_at("user://logs"):
		if file.begins_with("godot2") and file.ends_with(".log"):
			var modified: int = FileAccess.get_modified_time("user://logs/" + file)

			if modified >= log_time:
				log_time = modified
				log_name = file

	var text: String = "CRASH REPORT: the game ended unexpectedly.\nThe run that ended: %s\nThis report made by build %d at %s\n\n" % [flag, _build, Time.get_datetime_string_from_system(true)]
	var bread: PackedStringArray = FileAccess.get_file_as_string(BREAD).split("\n") if FileAccess.file_exists(BREAD) else PackedStringArray()
	var errors: PackedStringArray = PackedStringArray()

	for line in bread:
		if " ERROR " in line or " WARNING " in line:
			errors.append(line)

	text += "== Last %d breadcrumbs (key and mouse presses, menus, errors, a state line every 5 s) ==\n%s\n\n" % [KEEP_EVENTS, "\n".join(bread.slice(maxi(bread.size() - KEEP_EVENTS, 0)))]
	text += "== Errors and warnings of that run (last 40) ==\n%s\n\n" % "\n".join(errors.slice(maxi(errors.size() - 40, 0)))
	var log_lines: PackedStringArray = PackedStringArray()

	if log_name != "":
		var all_lines: PackedStringArray = FileAccess.get_file_as_string("user://logs/" + log_name).split("\n")
		log_lines = all_lines.slice(maxi(all_lines.size() - KEEP_LOG_LINES, 0))

	text += "== Last %d lines of Godot's log of that run (%s; a native crash writes its backtrace here) ==\n%s\n" % [KEEP_LOG_LINES, log_name if log_name != "" else "no log found", "\n".join(log_lines)]
	text = _clean(text)

	if text.length() > MAX_BYTES:
		text = text.substr(0, MAX_BYTES / 4) + "\n[... cut ...]\n" + text.substr(text.length() - MAX_BYTES * 3 / 4)

	var stamp: String = Time.get_datetime_string_from_system(false).replace(":", "-").replace("T", "_")
	var name: String = "%s_build%s.txt" % [stamp, _flag_build(flag)]
	var dir: String = REPORT_DIR
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var out: FileAccess = FileAccess.open(dir + "/" + name, FileAccess.WRITE)

	if out == null:
		dir = "user://crash_reports"
		DirAccess.make_dir_recursive_absolute(dir)
		out = FileAccess.open(dir + "/" + name, FileAccess.WRITE)

	if out != null:
		out.store_string(text)
		out.close()

	print("Crash report written: %s/%s" % [dir, name])
	return "%s/%s" % [dir.trim_prefix("res://"), name]


static func _flag_build(flag: String) -> String:
	var parts: PackedStringArray = flag.split(" ")
	return parts[1] if parts.size() > 1 and parts[0] == "build" else "unknown"


# Long hex strings (keys, tokens) are hidden; nothing else in these files is secret.
static func _clean(text: String) -> String:
	var regex: RegEx = RegEx.new()
	regex.compile("[0-9a-fA-F]{24,}")
	return regex.sub(text, "<hex hidden>", true)
