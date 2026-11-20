extends SceneTree

# Loads every .gd file under res://scenes, res://src and res://tools and counts the GDScript warnings Godot reports.
# A script that does not parse or compile is named on a "PARSE FAIL" line and the run exits 1.
# Run through tools/check_warnings.sh (it passes --ignore-error-breaks, so a parse error cannot stop the run at the
# debugger's "debug>" prompt). With "-- --self-check" it checks only two scripts it writes to user://, one with a
# warning and one that does not parse (tools/test_check_warnings.sh).

const SELF_CHECK_DIR := "user://check_warnings_self_check"


class Catcher extends Logger:
	var found: Array = []


	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING or error_type == Logger.ERROR_TYPE_SCRIPT:
			found.append([file, line, code, rationale, error_type])


func _initialize() -> void:
	var roots: Array = ["res://scenes", "res://src", "res://tools"]

	if OS.get_cmdline_user_args().has("--self-check"):
		roots = [_write_self_check()]

	var catcher: Catcher = Catcher.new()
	OS.add_logger(catcher)
	var files: PackedStringArray = PackedStringArray()

	for root in roots:
		_collect(root, files)

	var broken: PackedStringArray = PackedStringArray()

	for file in files:
		var script: Script = ResourceLoader.load(file, "", ResourceLoader.CACHE_MODE_IGNORE) as Script

		# A script with a parse or compile error still loads, but it is not valid and cannot be instantiated.
		if script == null or not script.can_instantiate():
			broken.append(_short(file))

	OS.remove_logger(catcher)
	var lines: PackedStringArray = PackedStringArray()

	for item in catcher.found:
		lines.append("%s:%d: %s %s" % [_short(str(item[0])), item[1], item[2], item[3]])

	lines.sort()
	var unique: PackedStringArray = PackedStringArray()

	for line in lines:
		if unique.is_empty() or unique[unique.size() - 1] != line:
			unique.append(line)

	lines = unique

	for line in lines:
		print("WARN ", line)

	for file in broken:
		print("PARSE FAIL ", file)

	print("scripts checked: %d, warnings: %d" % [files.size(), lines.size()])

	if not broken.is_empty():
		print("parse failures: %d" % broken.size())

	quit(1 if not broken.is_empty() else 0)


func _collect(dir: String, files: PackedStringArray) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd") and not file.ends_with("check_warnings.gd"):
			files.append(dir + "/" + file)

	for sub in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + sub, files)


# The path as the reports give it: from the project root (the self-check's from user://), so "file:line" splits on the first colon.
func _short(path: String) -> String:
	return path.replace("res://", "").replace("user://", "")


# A fresh folder with one script that warns (an unused local) and one that does not parse, its path.
func _write_self_check() -> String:
	DirAccess.make_dir_recursive_absolute(SELF_CHECK_DIR)

	for file in DirAccess.get_files_at(SELF_CHECK_DIR):
		DirAccess.remove_absolute(SELF_CHECK_DIR + "/" + file)

	var warns: FileAccess = FileAccess.open(SELF_CHECK_DIR + "/warns.gd", FileAccess.WRITE)
	warns.store_string("extends RefCounted\n\n\nfunc f() -> void:\n\tvar unused_here: int = 1\n")
	warns.close()
	var bad: FileAccess = FileAccess.open(SELF_CHECK_DIR + "/does_not_parse.gd", FileAccess.WRITE)
	bad.store_string("extends RefCounted\n\n\nfunc f() -> void\n\tvar x = (\n")
	bad.close()
	return SELF_CHECK_DIR
