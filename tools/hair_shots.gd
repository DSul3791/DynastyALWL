extends SceneTree

# Pictures of every hair style (hair_models.gd) on every body model, close on the head, in the idle pose: front, three-quarter, side and back. For checking the fit by eye
# (Dave 20 Nov 2026: hair styles in the character creator). No world, no server. Needs a real renderer (a window on the PC).
#   godot --path . --script res://tools/hair_shots.gd -- --out=E:/somewhere/hair_shots [--colour=0.7,0.55,0.25]
# Writes <out>/hair_<body>_<style>_<view>.png, 900 x 900. --colour gives the hair colour (the creator's default leaves the hair as painted).

const Body := preload("res://src/client/character/dynasty_body.gd")
const BodyModels := preload("res://src/client/character/body_models.gd")
const HairModels := preload("res://src/client/character/hair_models.gd")
const Generator := preload("res://src/client/character/body_generator.gd")

const VIEWS := {"front": 180.0, "three_quarter": 135.0, "side": 90.0, "back": 0.0}      # camera yaw round the body; 180 looks at the face
const CAMERA_M := 0.75
const SETTLE_FRAMES := 8

var _out: String = "user://hair_shots"
var _colour: Variant = null
var _jobs: Array = []        # [body id, style id]
var _body: Node3D
var _cam: Camera3D
var _job: int = -1
var _view: int = 0
var _wait: int = 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--colour="):
			var c: PackedStringArray = a.trim_prefix("--colour=").split(",")
			_colour = Color(float(c[0]), float(c[1]), float(c[2]))

	DirAccess.make_dir_recursive_absolute(_out)

	for model in BodyModels.ids():
		for style in HairModels.STYLES:
			_jobs.append([model, style])

	root.size = Vector2i(900, 900)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.86)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	root.add_child(sun)
	_cam = Camera3D.new()
	_cam.fov = 40.0
	root.add_child(_cam)
	_cam.current = true


func _next_job() -> bool:
	_job += 1

	if _body != null:
		_body.queue_free()
		_body = null

	if _job >= _jobs.size():
		return false

	_body = Body.new(str(_jobs[_job][0]))
	root.add_child(_body)
	var g: Dictionary = Generator.make_genome()
	g["hair_model"] = str(_jobs[_job][1])

	if _colour != null:
		g["hair"] = _colour

	_body.set_proportions(g)
	_body.play("idle", 1.0, 0.0)
	_body.animation_player.seek(0.5, true)
	_body.animation_player.pause()
	_view = 0
	return true


func _place_camera() -> void:
	var s: Skeleton3D = _body.skeleton
	var head: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_Head"))).origin
	var top: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_HeadTop_End"))).origin
	var aim: Vector3 = (head + top) * 0.5
	var yaw: float = deg_to_rad(float(VIEWS.values()[_view]))
	_cam.look_at_from_position(aim + Vector3(sin(yaw) * CAMERA_M, 0.05, cos(yaw) * CAMERA_M), aim)


func _process(_delta: float) -> bool:
	if _job < 0:
		if not _next_job():
			return true

		_wait = SETTLE_FRAMES
		return false

	_wait -= 1

	if _wait == 2:
		_place_camera()      # the pose is settled; the camera follows the drawn head

	if _wait > 0:
		return false

	var file: String = "hair_%s_%s_%s.png" % [_jobs[_job][0], _jobs[_job][1], VIEWS.keys()[_view]]
	root.get_texture().get_image().save_png(_out.path_join(file))
	print("saved ", _out.path_join(file))
	_view += 1
	_wait = 3

	if _view >= VIEWS.size():
		if not _next_job():
			print("hair_shots: done, %d pictures" % (_jobs.size() * VIEWS.size()))
			return true

		_wait = SETTLE_FRAMES

	return false
