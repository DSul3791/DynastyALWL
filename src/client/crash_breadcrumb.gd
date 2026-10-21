extends RefCounted

# Crash breadcrumb (Dave 2026-10-21: the game just closed while he walked beside a felled trunk, no message). A flag file
# is written at start and removed on a clean exit; if it is still there at the next start the last run ended unexpectedly,
# and the last lines of that run's Godot log are kept in user://previous_run_log.txt, printed, and put on the clipboard
# so they can be pasted into the chat. Godot keeps the previous log as user://logs/godot<date>.log when a run starts.

const FLAG := "user://running.flag"
const KEPT := "user://previous_run_log.txt"
const LINES := 20


# Call once at start. Returns "" after a clean run, or the text of the last log lines of the run that ended unexpectedly.
static func check_previous() -> String:
	var text: String = ""

	if FileAccess.file_exists(FLAG):
		var flag: String = FileAccess.get_file_as_string(FLAG).strip_edges()
		var newest: String = ""
		var newest_time: int = 0

		for file in DirAccess.get_files_at("user://logs"):
			if file.begins_with("godot2") and file.ends_with(".log"):
				var modified: int = FileAccess.get_modified_time("user://logs/" + file)

				if modified >= newest_time:
					newest_time = modified
					newest = file

		var tail: PackedStringArray = PackedStringArray()

		if newest != "":
			var lines: PackedStringArray = FileAccess.get_file_as_string("user://logs/" + newest).split("\n")
			tail = lines.slice(maxi(lines.size() - LINES - 1, 0))

		text = "Previous run ended unexpectedly (%s). Last log lines of %s:\n%s" % [flag, newest if newest != "" else "(no log found)", "\n".join(tail)]
		var kept: FileAccess = FileAccess.open(KEPT, FileAccess.WRITE)

		if kept != null:
			kept.store_string(text)
			kept.close()

	return text


static func mark_running(build: int) -> void:
	var file: FileAccess = FileAccess.open(FLAG, FileAccess.WRITE)

	if file != null:
		file.store_string("build %d, started %s" % [build, Time.get_datetime_string_from_system(true)])
		file.close()


static func mark_clean() -> void:
	if FileAccess.file_exists(FLAG):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(FLAG))
