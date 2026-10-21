extends Node

# Reference stills from the real world (cloud, lavapipe or a real GPU). The client creates this when
# started with --shots. Each shot: fly to a point, face a direction, freeze the game clock at an hour,
# optionally force the weather, wait for the ground and flora to stream in, save the 3D view as a PNG.
#
#   --shots="name:x,agl,z,yaw_deg,pitch_deg,hour[,weather];name2:..."   (weather: clear, storm, rain, snow)
#   agl is metres above the ground at x,z (a NEGATIVE y is an absolute height in metres instead): the runner first goes to 400 m above sea level there, waits until the
#   ground under it has loaded, then drops to the ground height plus agl
#   --shot-dir=DIR      where the PNGs go (default user://shots)
#   --shot-wait=S       seconds after connecting before the first shot (default 60)
#   --shot-settle=S     seconds per shot for streaming after the move (default 25)
#
# yaw 0 faces -Z (north), 90 faces -X, -90 faces +X (Godot rotation about Y). Quits after the last shot.

var client = null
var shots: Array = []
var dir: String = "user://shots"
var wait_s: float = 60.0
var settle_s: float = 25.0

var _index: int = -1
var _placed: bool = false
var _ground_wait_msec: int = 0
var _moved_msec: int = 0
var _hour: float = 12.0
var _weather: String = ""

const STORM := {"rain": 1.0, "snow": 0.0, "storm": 1.0, "cloud": 1.0, "sun": 0.0, "wind": 0.9, "wind_dir": 1.0, "temp_c": 8.0}
const RAIN := {"rain": 0.65, "snow": 0.0, "storm": 0.0, "cloud": 0.8, "sun": 0.0, "wind": 0.3, "wind_dir": 1.0, "temp_c": 9.0}
const SNOW := {"rain": 0.0, "snow": 0.6, "storm": 0.0, "cloud": 0.8, "sun": 0.0, "wind": 0.1, "wind_dir": 1.0, "temp_c": -3.0}
const CLEAR := {"rain": 0.0, "snow": 0.0, "storm": 0.0, "cloud": 0.15, "sun": 1.0, "wind": 0.1, "wind_dir": 1.0, "temp_c": 14.0}


func setup(owner_client, args: Array) -> void:
	client = owner_client

	for argument in args:
		if argument.begins_with("--shots="):
			for part in argument.trim_prefix("--shots=").split(";", false):
				var pieces: PackedStringArray = part.split(":", false)
				var numbers: PackedStringArray = pieces[1].split(",", false)
				shots.append({"name": pieces[0], "pos": Vector3(float(numbers[0]), float(numbers[1]), float(numbers[2])),
					"yaw": float(numbers[3]), "pitch": float(numbers[4]), "hour": float(numbers[5]) if numbers.size() > 5 else 12.0,
					"weather": numbers[6] if numbers.size() > 6 else ""})
		elif argument.begins_with("--shot-dir="):
			dir = argument.trim_prefix("--shot-dir=")
		elif argument.begins_with("--shot-wait="):
			wait_s = float(argument.trim_prefix("--shot-wait="))
		elif argument.begins_with("--shot-settle="):
			settle_s = float(argument.trim_prefix("--shot-settle="))

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))


func _process(_delta: float) -> void:
	if client == null or client.body == null or client.connected_msec == 0:
		return

	# Hold the hour and weather every frame, whatever the server says.
	if _index >= 0 and _index < shots.size():
		var seconds: float = floorf(client.game_clock.seconds / 86400.0) * 86400.0 + _hour * 3600.0
		client.game_clock.seconds = seconds
		client.game_clock._sync_msec = -1

		match _weather:
			"storm": client.weather = STORM.duplicate()
			"rain": client.weather = RAIN.duplicate()
			"snow": client.weather = SNOW.duplicate()
			"clear": client.weather = CLEAR.duplicate()

		client.body.velocity = Vector3.ZERO

		if client.held != null:
			client.held.set_first_person(false)

		if client._avatar != null:
			client._avatar.visible = false

	var now: int = Time.get_ticks_msec()

	if _index == -1:
		if now - client.connected_msec < int(wait_s * 1000.0):
			return

		_next(now)
		return

	if _index >= shots.size():
		return

	var shot_pos: Vector3 = shots[_index]["pos"]

	if not _placed:
		var ground: float = _ground(shot_pos.x, shot_pos.z)

		if is_nan(ground) and now - _ground_wait_msec < 300000:
			client.body.global_position = Vector3(shot_pos.x, 400.0, shot_pos.z)
			return

		_placed = true
		_moved_msec = now
		client.body.global_position = Vector3(shot_pos.x, -shot_pos.y if shot_pos.y < 0.0 else (shot_pos.y if is_nan(ground) else ground + shot_pos.y), shot_pos.z)
		return

	if now - _moved_msec < int(settle_s * 1000.0):
		return

	var image: Image = get_viewport().get_texture().get_image()
	var path: String = "%s/%s.png" % [dir, shots[_index]["name"]]
	image.save_png(path)
	var p: Vector3 = client.body.global_position
	print("shot runner: saved %s (%dx%d) at %s, ground %.1f" % [path, image.get_width(), image.get_height(), str(p), _ground(p.x, p.z)])
	var falls: Array = client.flora.fall_list()
	falls.sort_custom(func(a, b): return (a["base"] as Vector3).distance_to(p) < (b["base"] as Vector3).distance_to(p))

	for n in range(mini(falls.size(), 12)):
		var fall: Dictionary = falls[n]
		print("shot runner: fall %d top %s base %s flow %.1f width %.1f" % [n, str(fall["top"]), str(fall["base"]), float(fall["flow"]), float(fall["width"])])

	_next(now)


# The ground height under x, z from the voxel data (no collision needed), NAN while it is not loaded.
func _ground(x: float, z: float) -> float:
	var tool = client.terrain.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_SDF
	var hit = tool.raycast(Vector3(x, 1500.0, z), Vector3.DOWN, 2000.0)
	return float(hit.position.y) if hit != null else NAN


func _next(now: int) -> void:
	_index += 1

	if _index >= shots.size():
		print("shot runner: done")
		get_tree().quit()
		return

	var shot: Dictionary = shots[_index]
	client.flying = true
	_placed = false
	_ground_wait_msec = now
	client.body.global_position = Vector3(shot["pos"].x, 400.0, shot["pos"].z)
	client.body.rotation = Vector3(0.0, deg_to_rad(float(shot["yaw"])), 0.0)
	client.pitch = deg_to_rad(float(shot["pitch"]))
	client.camera.rotation.x = client.pitch
	client.third_person = false
	_hour = float(shot["hour"])
	_weather = str(shot["weather"])
	_moved_msec = now

	if client.hud != null:
		client.hud.visible = false

	if client.compass != null:
		client.compass.visible = false

	if client.held != null and client.held._arms != null:
		client.held._arms.visible = false

	if client._avatar != null:
		client._avatar.visible = false

	for child in client.get_children():
		if child is CanvasLayer:
			child.visible = false

	if client.hotbar_strip != null and client.hotbar_strip.has_method("hide"):
		client.hotbar_strip.hide()
