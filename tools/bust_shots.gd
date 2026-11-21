extends SceneTree

# Pictures of the Bust slider (dynasty_shapes.gd "bust") on every body model, close on the chest, in the idle pose: front, three-quarter and side, at slider values
# -0.6 (the Even frame: as modelled), 0, 0.5 and 1. For checking the shape by eye (Dave 21 Nov 2026: "if you increase the breasts they get pointy they should get
# big, round and voluptuous"). No world, no server. Needs a real renderer (a window on the PC).
#   godot --path . --script res://tools/bust_shots.gd -- --out=E:/somewhere/bust_shots [--values=-0.6,0,0.5,1]
# Writes <out>/bust_<body>_<value>_<view>.png at the window's size. A picture is taken only once the body wears its shaped mesh at that weight; "bust_shots: FAIL"
# when a body never does.

const Body := preload("res://src/client/character/dynasty_body.gd")
const BodyModels := preload("res://src/client/character/body_models.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const Shapes := preload("res://src/client/character/dynasty_shapes.gd")
const HairModels := preload("res://src/client/character/hair_models.gd")

const VIEWS := {"front": 180.0, "three_quarter": 135.0, "side": 90.0}      # camera yaw round the body; 180 looks at the front
const CAMERA_M := 1.0
const SETTLE_FRAMES := 8
const SHAPES_FRAMES := 900       # the most frames to wait for the shared shapes (made on a worker at the first body)

var _out: String = "user://bust_shots"
var _values: Array = [-0.6, 0.0, 0.5, 1.0]
var _jobs: Array = []        # [body id, bust value]
var _body: Node3D
var _cam: Camera3D
var _job: int = -1
var _view: int = 0
var _wait: int = 0
var _shaped_wait: int = 0
var _fails: int = 0


func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			_out = a.trim_prefix("--out=")
		elif a.begins_with("--values="):
			_values = []

			for x in a.trim_prefix("--values=").split(","):
				_values.append(float(x))

	DirAccess.make_dir_recursive_absolute(_out)

	for model in BodyModels.ids():
		for value in _values:
			_jobs.append([model, value])

	root.size = Vector2i(900, 900)
	var env: WorldEnvironment = WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.62, 0.74, 0.86)
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	root.add_child(env)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 150, 0)      # from the front left, so the round of the chest shows in light and shade
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
	g["bust"] = float(_jobs[_job][1])
	g["hair_model"] = HairModels.NONE      # nothing over the shoulders
	_body.set_proportions(g)
	_body.play("idle", 1.0, 0.0)
	_body.animation_player.seek(0.5, true)
	_body.animation_player.pause()
	_view = 0
	_shaped_wait = SHAPES_FRAMES
	return true


# True once the body draws the bust at its weight: the shaped mesh is on, or no shape is needed (weight 0 keeps Dave's own mesh).
func _shaped() -> bool:
	var want: float = Shapes.shape_weight({"bust": float(_jobs[_job][1])}, "bust")
	var mesh: MeshInstance3D = _body.body_mesh
	var i: int = mesh.find_blend_shape_by_name("bust")

	if i < 0:
		return want < 0.001

	return absf(mesh.get_blend_shape_value(i) - want) < 0.001


func _place_camera() -> void:
	var s: Skeleton3D = _body.skeleton
	var aim: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_Spine2"))).origin - Vector3(0.0, 0.06, 0.0)
	var yaw: float = deg_to_rad(float(VIEWS.values()[_view]))
	_cam.look_at_from_position(aim + Vector3(sin(yaw) * CAMERA_M, 0.0, cos(yaw) * CAMERA_M), aim)


func _process(_delta: float) -> bool:
	if _job < 0:
		if not _next_job():
			return true

		_wait = SETTLE_FRAMES
		return false

	if not _shaped():
		_shaped_wait -= 1

		if _shaped_wait > 0:
			return false

		print("bust_shots: FAIL %s at %s never wore its bust shape" % [_jobs[_job][0], str(_jobs[_job][1])])
		_fails += 1
		_view = VIEWS.size() - 1
		_wait = 0

	_wait -= 1

	if _wait == 2:
		_place_camera()      # the pose is settled; the camera follows the drawn chest

	if _wait > 0:
		return false

	if _shaped():
		var file: String = "bust_%s_%s_%s.png" % [_jobs[_job][0], str(_jobs[_job][1]), VIEWS.keys()[_view]]
		root.get_texture().get_image().save_png(_out.path_join(file))
		print("saved ", _out.path_join(file))

	_view += 1
	_wait = 3

	if _view >= VIEWS.size():
		if not _next_job():
			print("bust_shots: done, %d pictures, %d failures" % [_jobs.size() * VIEWS.size() - _fails * VIEWS.size(), _fails])
			quit(1 if _fails > 0 else 0)
			return true

		_wait = SETTLE_FRAMES

	return false
