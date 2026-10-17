extends RefCounted

# Admin tool: bakes the starter tiles by starting a second, headless copy of
# this same Godot program in the background (the one-click version of
# bake_starter.bat). The game keeps running; poll() tells how it is going.
# Admin-only and kept apart from the client code on purpose
# (DESIGN_PRINCIPLES Section 5): the client only calls start() and poll().

const TILES := "2,3;2,4;2,5;3,3;3,4;3,5;4,3;4,4;4,5"
const STARTER_TILE := "worlds/base_world/tiles/tile_3_4.tile"

var running: bool = false
var _pid: int = -1
var _started_unix: int = 0
var _log_path: String = ""


# Starts the bake. Returns "" when it began, else the reason it did not.
func start() -> String:
	if running:
		return "A bake is already running."

	var project: String = ProjectSettings.globalize_path("res://")
	_log_path = ProjectSettings.globalize_path("user://bake.log")
	_started_unix = int(Time.get_unix_time_from_system())
	_pid = OS.create_process(OS.get_executable_path(), [
		"--headless", "--path", project,
		"--log-file", _log_path,
		"--script", "res://src/worldgen/tools/bake_tiles.gd",
		"--", "--tiles=" + TILES,
	])

	if _pid <= 0:
		return "Could not start the bake."

	running = true
	return ""


# "" while nothing new to say; a message once the bake has ended.
func poll() -> String:
	if not running or OS.is_process_running(_pid):
		return ""

	running = false
	var baked: int = 0
	var folder: String = ProjectSettings.globalize_path("res://worlds/base_world/tiles")

	for name in DirAccess.get_files_at(folder):
		if name.ends_with(".tile") and FileAccess.get_modified_time(folder + "/" + name) >= _started_unix:
			baked += 1

	if baked == 0:
		return "The bake ended without writing tiles. See %s" % _log_path

	return "Baked %d tiles. In GitHub Desktop commit %s and push, then restart the game." % [baked, STARTER_TILE]
