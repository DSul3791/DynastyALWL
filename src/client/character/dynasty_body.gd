extends Node3D

# Dave's own character (assets/character/Humanoid/Dynasty_Base_Male.glb, 1 Nov 2026) as a drop-in stand-in for the player body (Kathleen). It offers what terrain_client.gd,
# held_item.gd and avatar_driver.gd use on the avatar: skeleton, body_mesh, animation_player, hand_mount_r, hand_mount_l, head_mount, play, current, is_one_shot_playing, dress,
# set_shoulder_log. The glb is a skinned Mixamo rig (24 bones, 55 thousand triangles, one baked material, two 4096 px textures) with 84 clips; the game's clip names are mapped onto
# Dave's clips (CLIP_MAP below) and every clip stays available under its own name too.
# The player's body by default since 1 Nov 2026; `--oldbody` or Esc > Settings > Gameplay > "Old body (next Play)" (my_character.gd `dynasty_body_on`) brings back the previous one. NPCs and the first-person arms keep their own bodies.
# Known gaps (docs/DYNASTY_BODY.md): worn clothing is not hung (the worn pieces are written for other bones), the skin and clothes colours are baked into the texture, the log on the
# shoulder does not raise the arm, the lie clip is the nearest of Dave's, the first-person arms stay the ragdoll arms.

const GLB := "res://assets/character/Humanoid/Dynasty_Base_Male.glb"
const P := "mixamorig_"
const WornLook := preload("res://src/client/worn_look.gd")

# The game's clip name -> [Dave's clip, from s, to s (-1 = the end), loop, retime]. `retime` multiplies the clip's time: the gait clips are in place, so they are slowed or sped until the
# planted foot moves at the game's natural walk, jog and run speeds (1.4, 3.2, 6.0 m/s, avatar_driver.gd `speed_scale`); tools/dynasty_gait.gd measures the clips' real speeds.
const CLIP_MAP := {
	"idle": ["Idle", 0.0, -1.0, true, 1.0],
	"walk": ["Walking", 0.0, -1.0, true, 0.82],         # 1.15 m/s in place, 1.4 wanted
	"jog": ["Running", 0.0, -1.0, true, 1.22],           # 3.9 m/s in place, 3.2 wanted
	"run": ["RunFast", 0.0, -1.0, true, 1.22],           # 7.3 m/s in place, 6.0 wanted
	"crouch": ["CrouchLookAroundBow", 0.0, -1.0, true, 1.0],     # Dave's own crouch (hips 0.46 m), a slow look around
	# Crouched movement: the stride is retimed to the game's crouch pace of 0.9 m/s (avatar_driver.gd speed_scale); in place speeds 1.22, 0.87, 0.99 and 0.84 m/s.
	"crouch_walk": ["Cautious_Crouch_Walk_Forward", 0.0, -1.0, true, 1.36],
	"crouch_walk_back": ["Cautious_Crouch_Walk_Backward", 0.0, -1.0, true, 0.97],
	"crouch_walk_left": ["Cautious_Crouch_Walk_Left", 0.0, -1.0, true, 1.1],
	"crouch_walk_right": ["Cautious_Crouch_Walk_Right", 0.0, -1.0, true, 0.93],
	"sit": ["Chair_Sit_Idle_M", 0.0, -1.0, true, 1.0],
	"lie": ["Sleep_Normally", 0.0, -1.0, true, 1.0],
	"swing": ["Heavy_Hammer_Swing", 0.0, -1.0, false, 0.4],
	"swing_fp": ["Heavy_Hammer_Swing", 0.0, -1.0, false, 0.5],
	"chop": ["Heavy_Hammer_Swing", 0.0, -1.0, false, 0.52],
	"pick_overhead": ["Heavy_Hammer_Swing", 0.0, -1.0, false, 0.55],
	"jab": ["Right_Jab_from_Guard", 0.0, -1.0, false, 0.4],
	"throw": ["Charged_Spell_Cast", 0.0, -1.0, false, 0.4],
	"use": ["Push_Forward_and_Stop", 0.0, -1.0, false, 0.5],
	"carry_idle": ["Idle", 0.0, -1.0, true, 1.0],
	"carry_walk": ["Walking", 0.0, -1.0, true, 0.95],    # 1.15 m/s in place, 1.1 wanted
	# Not played by the game yet (needs a state hook, docs/DYNASTY_BODY.md): swimming, drinking, picking up, sitting down and standing up, waking.
	"swim": ["Swim_Forward", 0.0, -1.0, true, 1.0],
	"swim_idle": ["Swim_Idle", 0.0, -1.0, true, 1.0],
	"drink": ["Stand_and_Drink", 0.0, -1.0, false, 1.0],
	"pick_up": ["Male_Bend_Over_Pick_Up", 0.0, -1.0, false, 1.0],
	"sit_down": ["Stand_to_Sit_Transition_M", 0.0, -1.0, false, 1.0],
	"stand_up": ["Sit_to_Stand_Transition_M", 0.0, -1.0, false, 1.0],
	"wake_up": ["Wake_Up_and_Look_Up", 0.0, -1.0, false, 1.0],
}

static var _scene: PackedScene
static var _library: AnimationLibrary          # the game's names and Dave's own names, built once and shared

var arms_only: bool = false
var genome: Dictionary = {}
var skeleton: Skeleton3D
var body_mesh: MeshInstance3D
var animation_player: AnimationPlayer
var hand_mount_r: Marker3D
var hand_mount_l: Marker3D
var head_mount: Marker3D
var _log: MeshInstance3D
var _model: Node3D


func _init() -> void:
	name = "DynastyBody"

	if _scene == null:
		_scene = load(GLB) as PackedScene

	# Dave's rig faces +Z; the game faces -Z.
	_model = Node3D.new()
	_model.name = "Model"
	_model.rotation.y = PI
	add_child(_model)
	var inst: Node = _scene.instantiate()
	_model.add_child(inst)
	skeleton = inst.find_children("*", "Skeleton3D", true, false)[0]
	body_mesh = inst.find_children("*", "MeshInstance3D", true, false)[0]
	animation_player = inst.find_children("*", "AnimationPlayer", true, false)[0]
	set_meta("worn_skip_builders", WornLook.BUILDERS)      # the worn pieces are written for other bone frames: none is hung on this body yet
	_build_mounts()
	_build_animations()


# A mount on a bone, in the bone's rest frame turned so that its -Z points out along the bone (the fingers) and its +Y points to the front of the body, the same grip the old
# bodies give (assets/character/README.md). The skeleton is in centimetres under a 0.01 scale, so the marker is scaled back up: whatever is parented to it is in metres.
func _mount(bone: String, mount_name: String, offset_m: Vector3, along: Vector3, front: Vector3) -> Marker3D:
	var attachment: BoneAttachment3D = BoneAttachment3D.new()
	attachment.name = "Attach_" + mount_name
	skeleton.add_child(attachment)
	attachment.bone_name = P + bone
	var rest: Basis = skeleton.get_bone_global_rest(skeleton.find_bone(P + bone)).basis.orthonormalized()
	var z: Vector3 = -along.normalized()
	var y: Vector3 = (front - z * front.dot(z)).normalized()
	var x: Vector3 = y.cross(z)
	var wanted: Basis = Basis(x, y, z)
	var marker: Marker3D = Marker3D.new()
	marker.name = mount_name
	marker.transform = Transform3D((rest.inverse() * wanted).scaled(Vector3.ONE * 100.0), (rest.inverse() * (offset_m * 100.0)))
	attachment.add_child(marker)
	return marker


func _bone_dir(bone: String, child: String) -> Vector3:
	var a: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone(P + bone)).origin
	var b: Vector3 = skeleton.get_bone_global_rest(skeleton.find_bone(P + child)).origin
	return (b - a).normalized()


func _build_mounts() -> void:
	# Fingers point along the forearm; the grip is 7 cm into the palm, and the front is model +Z. Offsets are given in model space, turned by `rest` inside _mount.
	var front: Vector3 = Vector3(0.0, 0.0, 1.0)
	var right_dir: Vector3 = _bone_dir("RightForeArm", "RightHand")
	var left_dir: Vector3 = _bone_dir("LeftForeArm", "LeftHand")
	hand_mount_r = _mount("RightHand", "HandMount_R", right_dir * 0.07, right_dir, front)
	hand_mount_l = _mount("LeftHand", "HandMount_L", left_dir * 0.07, left_dir, front)
	head_mount = _mount("Head", "HeadMount", Vector3(0.0, 0.1, 0.0), Vector3(0.0, -1.0, 0.0), front)


# The game's names and Dave's own names, shared by every body. Hips travel is taken out of every clip (the game moves the body), see _clip.
func _build_animations() -> void:
	if _library == null:
		_library = AnimationLibrary.new()
		var own: AnimationLibrary = animation_player.get_animation_library(animation_player.get_animation_library_list()[0])

		for clip in own.get_animation_list():
			_library.add_animation(clip, _clip(own.get_animation(clip), 0.0, -1.0, true, 1.0))

		for game_name in CLIP_MAP:
			var row: Array = CLIP_MAP[game_name]
			_library.add_animation(game_name, _clip(own.get_animation(str(row[0])), float(row[1]), float(row[2]), bool(row[3]), float(row[4])))

	for library_name in animation_player.get_animation_library_list():
		animation_player.remove_animation_library(library_name)

	animation_player.add_animation_library("", _library)
	animation_player.play("idle")


# A copy of `src` between `from` and `to` seconds, its time multiplied by `retime`, looping or not. The hips travel on the ground is replaced by its deviation from a straight line, so
# a clip with root motion stays on the spot and a loop stays a loop.
static func _clip(src: Animation, from: float, to: float, loop: bool, retime: float) -> Animation:
	var end: float = src.length if to < 0.0 else minf(to, src.length)
	var out: Animation = Animation.new()
	out.length = maxf((end - from) * retime, 0.05)
	out.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

	for t in range(src.get_track_count()):
		var type: int = src.track_get_type(t)

		if type != Animation.TYPE_POSITION_3D and type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_SCALE_3D:
			continue

		var track: int = out.add_track(type)
		out.track_set_path(track, src.track_get_path(t))
		var times: Array = [from]

		for k in range(src.track_get_key_count(t)):
			var kt: float = src.track_get_key_time(t, k)

			if kt > from + 0.0001 and kt < end - 0.0001:
				times.append(kt)

		times.append(end)
		var hips: bool = type == Animation.TYPE_POSITION_3D and String(src.track_get_path(t)).ends_with(P + "Hips")
		var first: Vector3 = Vector3.ZERO
		var last: Vector3 = Vector3.ZERO

		if hips:
			first = src.position_track_interpolate(t, from)
			last = src.position_track_interpolate(t, end)

		for kt in times:
			var when: float = (float(kt) - from) * retime

			if type == Animation.TYPE_POSITION_3D:
				var p: Vector3 = src.position_track_interpolate(t, float(kt))

				if hips and end > from:
					var f: float = (float(kt) - from) / (end - from)
					var line: Vector3 = first.lerp(last, f)
					p.x -= line.x
					p.z -= line.z

				out.position_track_insert_key(track, when, p)
			elif type == Animation.TYPE_ROTATION_3D:
				out.rotation_track_insert_key(track, when, src.rotation_track_interpolate(t, float(kt)))
			else:
				out.scale_track_insert_key(track, when, src.scale_track_interpolate(t, float(kt)))

	return out


func play(animation: String, speed: float = 1.0, blend: float = 0.15) -> void:
	if animation_player != null and animation_player.has_animation(animation):
		animation_player.play(animation, blend, speed)


func current() -> String:
	return String(animation_player.current_animation) if animation_player != null else ""


func is_one_shot_playing() -> bool:
	return animation_player != null and animation_player.is_playing() and animation_player.get_animation(animation_player.current_animation).loop_mode == Animation.LOOP_NONE


# The colours are baked into Dave's texture; nothing to paint yet.
func dress(_skin_color: Color, _coat: Color, _trousers: Color, _shoes: Color = Color(0.14, 0.11, 0.09)) -> void:
	pass


func set_far(_on: bool) -> void:
	pass


func is_far() -> bool:
	return false


func set_clothed(_on: bool) -> void:
	pass


# A large log across the right shoulder: shown or hidden, `length` and `radius` in metres (the arm does not rise to steady it yet).
func set_shoulder_log(length: float, radius: float, color: Color = Color(0.32, 0.23, 0.15)) -> void:
	if length <= 0.0:
		if _log != null:
			_log.visible = false

		return

	if _log == null:
		var attachment: BoneAttachment3D = BoneAttachment3D.new()
		attachment.name = "Attach_ShoulderLog"
		skeleton.add_child(attachment)
		attachment.bone_name = P + "Spine2"
		_log = MeshInstance3D.new()
		_log.material_override = StandardMaterial3D.new()
		_log.scale = Vector3.ONE * 100.0
		attachment.add_child(_log)

	(_log.material_override as StandardMaterial3D).albedo_color = color
	var cyl: CylinderMesh = _log.mesh as CylinderMesh if _log.mesh != null else CylinderMesh.new()
	cyl.top_radius = radius * 0.8
	cyl.bottom_radius = radius
	cyl.height = length
	cyl.radial_segments = 12
	_log.mesh = cyl
	_log.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	_log.position = Vector3(-18.0, 9.0, -12.0)      # the right shoulder, a little behind (model space: right is -X, front +Z), in centimetres
	_log.visible = true
