extends SceneTree
# Headless check of Report a problem (src/client/problem_report.gd): the bug form link carries the build, the report holds the build, the
# tester's note and the log's end, a long hex token is masked, and the file is written under user://reports.

const ProblemReport := preload("res://src/client/problem_report.gd")
const BuildStamp := preload("res://src/shared/build_stamp.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var url: String = ProblemReport.form_url()
	_check(url.begins_with("https://github.com/DSul3791/DynastyALWL-QA/issues/new?template=bug.yml&build=Build%20" + str(BuildStamp.number())), "the bug form link fills in the build (%s)" % url)

	var token: String = "0123456789abcdef0123456789abcdef0123456789abcdef"
	var text: String = ProblemReport.report_text("The fire would not light. " + token, "test at 1, 2, 3")
	_check(text.contains(ProblemReport.build_text()), "the report names the build")
	_check(text.contains("The fire would not light.") and text.contains("test at 1, 2, 3"), "the report holds the tester's note and where")
	_check(not text.contains(token), "a long hex token is masked")
	_check(ProblemReport.report_text("").contains("(nothing typed)"), "an empty note says so")

	var path: String = ProblemReport.write("A note from the test")
	_check(path != "" and FileAccess.file_exists(path) and FileAccess.get_file_as_string(path).contains("A note from the test"), "the report file is written (%s)" % path)
	_check(path.get_base_dir() == ProjectSettings.globalize_path(ProblemReport.REPORT_DIR), "in the reports folder the button opens")

	if path != "":
		DirAccess.remove_absolute(path)

	print("problem report: %d failures" % failures)
	quit(1 if failures > 0 else 0)
