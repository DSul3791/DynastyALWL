extends RefCounted

# Admin tool: bakes the starter tiles by starting a second, headless copy of
# this same Godot program in the background (the one-click version of
# bake_starter.bat). The game keeps running; poll() tells how it is going.
# Admin-only and kept apart from the client code on purpose
# (DESIGN_PRINCIPLES Section 5): the client only calls start() and poll().

const TILES := "2,3;2,4;2,5;3,3;3,4;3,5;4,3;4,4;4,5"
const STARTER_TILE := "worlds/base_world/tiles/tile_3_4.tile"
const WATER_FILE := "worlds/base_world/water/tile_3_4.water"
# The world starts with dry fresh water and the springs fill it live (owner, 2026-10-18),
# so the baked water file is not needed any more; set true to settle it again.
const SETTLE_AFTER_BAKE := false
const SETTLE_TICKS := 800   # about 3 to 5 minutes on a modern computer

var running: bool = false
var _pid: int = -1
var _started_unix: int = 0
var _started_msec: int = 0
var _log_path: String = ""
var _settle_log_path: String = ""     # its own log, so the water settle never overwrites the tile bake log
var _stage: int = 1               # 1 baking tiles, 2 settling the water
var _settle_msec: int = 0
var _baked: int = 0


# Starts the bake. Returns "" when it began, else the reason it did not.
func start() -> String:
	if running:
		return "A bake is already running."

	var project: String = ProjectSettings.globalize_path("res://")
	_log_path = ProjectSettings.globalize_path("user://bake.log")
	_started_unix = int(Time.get_unix_time_from_system())
	_started_msec = Time.get_ticks_msec()
	_pid = OS.create_process(OS.get_executable_path(), [
		"--headless", "--path", project,
		"--log-file", _log_path,
		"--script", "res://src/worldgen/tools/bake_tiles.gd",
		"--", "--tiles=" + TILES,
	])

	if _pid <= 0:
		return "Could not start the bake."

	running = true
	_stage = 1
	return ""


# How far the bake is, read from its log (one \"baked in\" line per finished tile).
func status() -> String:
	if not running:
		return ""

	if _stage == 2:
		var ticks: int = 0

		if FileAccess.file_exists(_settle_log_path):
			var text: String = FileAccess.get_file_as_string(_settle_log_path)
			var at: int = text.rfind("  tick ")

			if at >= 0:
				ticks = int(text.substr(at + 7).get_slice(":", 0)) + 1

		var seconds: int = (Time.get_ticks_msec() - _settle_msec) / 1000
		return "Step 2 of 2, settling the water: tick %d of %d, %d s so far (step 1: all %d tiles are baked)" % [ticks, SETTLE_TICKS, seconds, _baked]

	var done: int = 0
	var total: int = TILES.split(";").size()

	if FileAccess.file_exists(_log_path):
		done = FileAccess.get_file_as_string(_log_path).count(" baked in ")

	if done == 0:
		return "Baking starter tiles: starting up"

	# Time left from the pace so far (the first tile also carries the setup).
	var elapsed_min: float = float(Time.get_ticks_msec() - _started_msec) / 60000.0
	var left_min: float = elapsed_min / float(done) * float(total - done)
	return "Baking starter tiles: %d of %d done, about %d min left" % [done, total, maxi(int(ceil(left_min)), 1)]


# "" while nothing new to say; a message once the bake and the water settle have ended.
func poll() -> String:
	if not running or OS.is_process_running(_pid):
		return ""

	if _stage == 1:
		var baked: int = 0
		var folder: String = ProjectSettings.globalize_path("res://worlds/base_world/tiles")

		for name in DirAccess.get_files_at(folder):
			if name.ends_with(".tile") and FileAccess.get_modified_time(folder + "/" + name) >= _started_unix:
				baked += 1

		if baked == 0:
			running = false
			return "The bake ended without writing tiles. See %s" % _log_path

		_baked = baked

		if not SETTLE_AFTER_BAKE:
			running = false
			return "FINISHED: baked %d tiles and reloaded the ground. In GitHub Desktop commit everything under worlds/base_world and push." % _baked

		# Second step: settle the water on the freshly baked starter tile.
		_stage = 2
		_settle_msec = Time.get_ticks_msec()
		_started_unix = int(Time.get_unix_time_from_system())
		_settle_log_path = ProjectSettings.globalize_path("user://settle.log")
		_pid = OS.create_process(OS.get_executable_path(), [
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--log-file", _settle_log_path,
			"--script", "res://src/worldgen/tools/settle_water.gd",
			"--", "--tile=3,4", "--ticks=%d" % SETTLE_TICKS, "--rate=3.0",
		])

		if _pid <= 0:
			running = false
			return "FINISHED: baked %d tiles, but the water settle could not start. Commit the tiles in worlds/base_world/tiles and push." % _baked

		return ""

	running = false
	var settled: bool = FileAccess.file_exists(ProjectSettings.globalize_path("res://" + WATER_FILE)) and FileAccess.get_modified_time(ProjectSettings.globalize_path("res://" + WATER_FILE)) >= _started_unix
	var note: String = "the water is settled" if settled else "the water settle did not finish (see %s)" % _settle_log_path
	return "FINISHED: baked %d tiles and %s. In GitHub Desktop commit everything under worlds/base_world (tiles and water) and push, then restart the game." % [_baked, note]
