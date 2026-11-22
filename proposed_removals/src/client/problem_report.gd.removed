extends RefCounted
# Report a problem (testers, 22 Nov 2026; server-client-split PLAN.md B1, the coordinator's ask for friends without a GitHub account).
# One button on the Esc menu (Settings) and on the server pick page. It writes a small report file into user://reports: the build, the
# time, this computer's system, the tester's own note, the last breadcrumbs (crash_report.gd's key presses, menus, errors) and the end of
# this run's Godot log. Then it opens that folder, so the file can be sent to Dave by any means (mail, chat). Testers with a GitHub account
# can also open the bug form in DynastyALWL-QA with the build already filled in (GitHub fills a form field from the link) and drag the
# file in. Nothing is sent from inside the game: the plan keeps reporting out of the client, which may be the thing that is broken.

const BuildStamp := preload("res://src/shared/build_stamp.gd")
const GitStamp := preload("res://src/debug/git_stamp.gd")
const CrashReport := preload("res://src/client/crash_report.gd")

const REPORT_DIR := "user://reports"
const FORM_URL := "https://github.com/DSul3791/DynastyALWL-QA/issues/new?template=bug.yml"
const BREAD := "user://breadcrumbs.log"   # crash_report.gd BREAD
const KEEP_BREAD := 150
const KEEP_LOG := 400
const MAX_CHARS := 400000                 # the file stays small enough to mail


# "Build 8883" (the title page's words), with the commit in a build without a release stamp.
static func build_text() -> String:
	var commit: String = GitStamp.short_commit()

	if BuildStamp.stamped_build() > 0 or commit == "":
		return "Build %d" % BuildStamp.number()

	return "Build %d (%s)" % [BuildStamp.number(), commit]


# The bug form with the build filled in.
static func form_url() -> String:
	return FORM_URL + "&build=" + build_text().uri_encode()


# The report as text (tests read it without a file).
static func report_text(note: String, where: String = "") -> String:
	var text: String = "DYNASTY PROBLEM REPORT\n%s\nMade %s (UTC)\nSystem: %s, %s, %s\n" % [
		build_text(), Time.get_datetime_string_from_system(true, true), OS.get_name(), OS.get_processor_name(), RenderingServer.get_video_adapter_name()]

	if where != "":
		text += "Where: %s\n" % where

	text += "\n== What the tester wrote ==\n%s\n" % (note.strip_edges() if note.strip_edges() != "" else "(nothing typed)")
	text += "\n== Last %d breadcrumbs (key and mouse presses, menus, errors) ==\n%s\n" % [KEEP_BREAD, _tail(BREAD, KEEP_BREAD)]
	text += "\n== Last %d lines of this run's game log ==\n%s\n" % [KEEP_LOG, _tail("user://logs/godot.log", KEEP_LOG)]

	var crash: String = _latest_crash()

	if crash != "":
		text += "\n== The newest crash report (%s) ==\n%s\n" % [crash, FileAccess.get_file_as_string(crash).substr(0, 100000)]

	text = CrashReport._clean(text)   # long hex tokens masked, as in a crash report

	if text.length() > MAX_CHARS:
		text = text.substr(text.length() - MAX_CHARS)

	return text


# Writes the report and returns the full path of the file on this computer ("" when it could not be written).
static func write(note: String, where: String = "") -> String:
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	var stamp: String = Time.get_datetime_string_from_system(false).replace(":", "-").replace("T", "_")
	var path: String = "%s/report_%s_build%d.txt" % [REPORT_DIR, stamp, BuildStamp.number()]
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)

	if file == null:
		return ""

	file.store_string(report_text(note, where))
	file.close()
	return ProjectSettings.globalize_path(path)


# Opens the reports folder in the computer's file manager (it holds the report just written).
static func open_folder() -> void:
	DirAccess.make_dir_recursive_absolute(REPORT_DIR)
	OS.shell_open(ProjectSettings.globalize_path(REPORT_DIR))


static func open_form() -> void:
	OS.shell_open(form_url())


# The newest crash report on this computer (crash_report.gd writes res://crash_reports, else user://crash_reports), "" when none.
static func _latest_crash() -> String:
	var best: String = ""
	var best_time: int = 0

	for dir in [CrashReport.REPORT_DIR, "user://crash_reports"]:
		if not DirAccess.dir_exists_absolute(dir):
			continue

		for name in DirAccess.get_files_at(dir):
			if not name.ends_with(".txt") or name.begins_with("telemetry"):
				continue

			var modified: int = FileAccess.get_modified_time(dir + "/" + name)

			if modified > best_time:
				best_time = modified
				best = dir + "/" + name

	return best


static func _tail(path: String, lines: int) -> String:
	if not FileAccess.file_exists(path):
		return "(none)"

	var all: PackedStringArray = FileAccess.get_file_as_string(path).split("\n")
	return "\n".join(all.slice(maxi(all.size() - lines, 0)))
