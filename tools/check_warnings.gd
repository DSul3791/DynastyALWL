extends SceneTree

# Loads every .gd file under res://scenes, res://src and res://tools and counts the GDScript warnings Godot reports.
# Run through tools/check_warnings.sh.

class Catcher extends Logger:
	var found: Array = []


	func _log_error(_function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _backtraces: Array) -> void:
		if error_type == Logger.ERROR_TYPE_WARNING or error_type == Logger.ERROR_TYPE_SCRIPT:
			found.append([file, line, code, rationale, error_type])


func _initialize() -> void:
	var catcher: Catcher = Catcher.new()
	OS.add_logger(catcher)
	var files: PackedStringArray = PackedStringArray()

	for root in ["res://scenes", "res://src", "res://tools"]:
		_collect(root, files)

	for file in files:
		var script: Script = load(file)

		if script is GDScript:
			(script as GDScript).reload(true)

	OS.remove_logger(catcher)
	var lines: PackedStringArray = PackedStringArray()

	for item in catcher.found:
		lines.append("%s:%d: %s %s" % [str(item[0]).replace("res://", ""), item[1], item[2], item[3]])

	lines.sort()

	for line in lines:
		print("WARN ", line)

	print("scripts checked: %d, warnings: %d" % [files.size(), lines.size()])
	quit(0)


func _collect(dir: String, files: PackedStringArray) -> void:
	for file in DirAccess.get_files_at(dir):
		if file.ends_with(".gd"):
			files.append(dir + "/" + file)

	for sub in DirAccess.get_directories_at(dir):
		_collect(dir + "/" + sub, files)
