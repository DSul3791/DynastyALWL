extends Node3D

# Dave's own character (assets/character/Humanoid/Dynasty_Base_Male.glb, 1 Nov 2026) as a drop-in stand-in for the player body (Kathleen). It offers what terrain_client.gd,
# held_item.gd and avatar_driver.gd use on the avatar: skeleton, body_mesh, animation_player, hand_mount_r, hand_mount_l, head_mount, play, current, is_one_shot_playing, dress,
# set_shoulder_log. The glb is a skinned Mixamo rig (24 bones, 55 thousand triangles, one baked material, two 4096 px textures) with 84 clips; the game's clip names are mapped onto
# Dave's clips (CLIP_MAP below) and every clip stays available under its own name too.
# The player's body by default since 1 Nov 2026; `--oldbody` or Esc > Settings > Gameplay > "Old body (next Play)" (my_character.gd `dynasty_body_on`) brings back the previous one. NPCs and the first-person arms keep their own bodies.
# Known gaps (docs/DYNASTY_BODY.md): worn clothing is not hung (the worn pieces are written for other bones), the skin and clothes colours are baked into the texture, the log on the
# shoulder does not raise the arm, the lie clip is the nearest of Dave's, the first-person arms stay the ragdoll arms.

const GLB := "res://assets/character/Humanoid/Dynasty_Base_Male.glb"
const ARMS_GLB := "res://assets/character/Humanoid/Dynasty_Base_Male_Parts_Split.glb"   # dynasty_arms.gd PARTS_GLB, warmed with the body
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
	# The same with a torch in the hand (Dave's own clips): in place speeds 1.07, 1.03 and 1.11 m/s, retimed to 0.9; there is no backward torch clip, so backwards stays the plain one.
	"crouch_walk_torch": ["Crouch_Walk_with_Torch", 0.0, -1.0, true, 1.19],
	"crouch_walk_left_torch": ["Crouch_Walk_Left_with_Torch", 0.0, -1.0, true, 1.14],
	"crouch_walk_right_torch": ["Crouch_Walk_Right_with_Torch", 0.0, -1.0, true, 1.23],
	# Jumping (bug 10, 2 Nov 2026): Dave's only jump is Jump_Run (2.03 s; hips 0.0-0.3 s the take-off squat, 0.3-0.5 s the spring, 0.5-0.8 s in the air, then a run). Cut into the game's three air clips:
	# jump = the spring and the top (played once when the body is rising), fall = the air pose held as a short loop, land = the squat and recovery (played after a fall of 0.4 s or more).
	# Cut points read from the hips height in the glb; not yet seen in the game, rate by picture.
	"jump": ["Jump_Run", 0.3, 0.7, false, 1.0],
	"fall": ["Jump_Run", 0.55, 0.8, true, 1.0],
	"land": ["Jump_Run", 0.1, 0.5, false, 1.0],
	"sit": ["Chair_Sit_Idle_M", 0.0, -1.0, true, 1.0],
	"lie": ["Sleep_Normally", 0.0, -1.0, true, 1.0],
	# Heavy_Hammer_Swing is 1.83 s and holds ONE blow, read from the hand's height in the playing clip (1 Nov 2026): the stance dips at 0.46 s, the hands rise from 0.5 s to the top at 1.2 s, and
	# the strike comes down from 1.4 s, fastest at 1.53 s, hands lowest at 1.73 s; the clip ends at 1.83 s. (The speed peak at 0.73 s is the rise, not a blow.) The game wants the blow at 0.5 s
	# of 0.95 s (0.52 of 1.0 for the pick, held_item.gd HIT_AT), so the rise is squeezed before the impact (taken at 1.68 s, the hands nearly at their lowest) and the short follow-through is
	# stretched after it. The last element is [impact in the source, new length, new impact time].
	"swing": ["Heavy_Hammer_Swing", 0.5, -1.0, false, 1.0, [1.68, 0.7, 0.37]],
	"swing_fp": ["Heavy_Hammer_Swing", 0.5, -1.0, false, 1.0, [1.68, 0.95, 0.5]],
	"chop": ["Heavy_Hammer_Swing", 0.5, -1.0, false, 1.0, [1.68, 0.95, 0.5]],
	"pick_overhead": ["Heavy_Hammer_Swing", 0.5, -1.0, false, 1.0, [1.68, 1.0, 0.52]],
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
static var _checked: int = -1                  # -1 not tried yet, 0 the glb cannot be used, 1 it can
static var force_unavailable: bool = false     # tests: pretend the glb is not imported
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


# True when Dave's glb is imported and holds a skeleton, a mesh and an AnimationPlayer. Checked once per run; when it is not (a fresh checkout before `godot --import`) one line says so and the
# game keeps the body it wore before (my_character.gd make_avatar), so the player is never bodiless.
# Dave 3 Nov 2026 (log: a 3 s freeze at the welcome): the body file (two 4096 textures) and the arm parts file (365 thousand triangles) were read on
# the main thread when the player was made. warm() starts both on loader threads as the client starts, long before the welcome; load_warm()
# takes the finished one (waiting only if it is still loading), or reads it the old way when nothing was started.
static func warm() -> void:
	for path in [GLB, ARMS_GLB]:
		if ResourceLoader.exists(path) and ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			ResourceLoader.load_threaded_request(path, "", true)


static func load_warm(path: String) -> Resource:
	var status: int = ResourceLoader.load_threaded_get_status(path)

	if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS or status == ResourceLoader.THREAD_LOAD_LOADED:
		var got: Resource = ResourceLoader.load_threaded_get(path)

		if got != null:
			return got

	return load(path)


static func available() -> bool:
	if force_unavailable:
		return false

	if _checked < 0:
		_checked = 0

		if ResourceLoader.exists(GLB):
			var packed: PackedScene = load_warm(GLB) as PackedScene

			if packed != null:
				var probe: Node = packed.instantiate()
				var ok: bool = not probe.find_children("*", "Skeleton3D", true, false).is_empty() and not probe.find_children("*", "MeshInstance3D", true, false).is_empty() and not probe.find_children("*", "AnimationPlayer", true, false).is_empty()
				probe.free()

				if ok:
					_scene = packed
					_checked = 1

		if _checked == 0:
			print("dynasty body: %s is not imported or has no skeleton, mesh or animations: using the previous body this run (run godot --import once)" % GLB)

	return _checked == 1


func _init() -> void:
	name = "DynastyBody"

	if not available():
		_make_empty()
		return

	if _scene == null:
		_scene = load_warm(GLB) as PackedScene

	# Dave's rig faces +Z; the game faces -Z.
	_model = Node3D.new()
	_model.name = "Model"
	_model.rotation.y = PI
	add_child(_model)
	var inst: Node = _scene.instantiate()
	_model.add_child(inst)
	skeleton = inst.find_children("*", "Skeleton3D", true, false)[0]
	body_mesh = inst.find_children("*", "MeshInstance3D", true, false)[0]
	body_mesh.layers |= 1 << 19   # no ground decals on the body (piece_look.gd NO_DECAL_LAYER)
	animation_player = inst.find_children("*", "AnimationPlayer", true, false)[0]
	_build_mounts()
	set_meta("worn_frames", _worn_frames())      # worn clothing (worn_look.gd) hangs on these frames, so nothing is skipped any more (docs/DYNASTY_BODY.md gap 1)
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


# Worn clothing on Dave's body (Kathreen, 3 Nov 2026; docs/DYNASTY_BODY.md gap 1). worn_look.gd writes its pieces in the old ragdoll's bone frames: every frame upright and
# square to the body (X right, Y up, Z back, the body facing -Z) at that body's joints, limbs hanging along -Y. Here each old bone gets one of Dave's bones and a frame under it:
# the same axes in the game's facing (Dave's rig faces +Z, so game X and Z are his -X and -Z), down the bone for a limb, standing at the old joint's place on his body, and
# stretched along the limb by his length over the old one, so a sleeve or a legging ends at his elbow or knee. In centimetres like the skeleton: the pieces stay in metres.
# Widths are left at 1: his chest, hips, thighs, shins, arms and head measure within a centimetre or two of the pieces' sizes (measured from the glb's rest mesh).
# old bone: [Dave's bone, "limb" (down the bone to the named child), "after" (on along the line from the named parent: his hands have no finger bones) or "upright",
# that bone, the old body's length of the limb in metres (0: no stretch)].
const WORN_BONES := {
	"hips": ["Hips", "upright", "", 0.0], "chest": ["Spine1", "upright", "", 0.0], "head": ["Head", "upright", "", 0.0],
	"arm_r": ["RightArm", "limb", "RightForeArm", 0.29], "forearm_r": ["RightForeArm", "limb", "RightHand", 0.26], "hand_r": ["RightHand", "after", "RightForeArm", 0.0],
	"arm_l": ["LeftArm", "limb", "LeftForeArm", 0.29], "forearm_l": ["LeftForeArm", "limb", "LeftHand", 0.26], "hand_l": ["LeftHand", "after", "LeftForeArm", 0.0],
	"thigh_r": ["RightUpLeg", "limb", "RightLeg", 0.45], "shin_r": ["RightLeg", "limb", "RightFoot", 0.4], "foot_r": ["RightFoot", "upright", "", 0.0],
	"thigh_l": ["LeftUpLeg", "limb", "LeftLeg", 0.45], "shin_l": ["LeftLeg", "limb", "LeftFoot", 0.4], "foot_l": ["LeftFoot", "upright", "", 0.0],
}


func _worn_frames() -> Dictionary:
	var frames: Dictionary = {}
	var back: Vector3 = Vector3(0.0, 0.0, -1.0)        # the game's +Z (the back of the body) in Dave's rig
	var upright: Basis = Basis(Vector3(-1.0, 0.0, 0.0), Vector3.UP, back)
	var neck: Vector3 = _rest_origin("Neck")
	var top: Vector3 = _rest_origin("HeadTop_End")

	for old in WORN_BONES:
		var row: Array = WORN_BONES[old]
		var index: int = skeleton.find_bone(P + str(row[0]))

		if index < 0:
			continue

		var rest: Transform3D = skeleton.get_bone_global_rest(index)
		rest.basis = rest.basis.orthonormalized()
		var axes: Basis = upright
		var at: Vector3 = rest.origin
		var stretch: float = 1.0

		if str(row[1]) != "upright" and skeleton.find_bone(P + str(row[2])) >= 0:
			var along: Vector3 = (_rest_origin(str(row[2])) - rest.origin) if str(row[1]) == "limb" else (rest.origin - _rest_origin(str(row[2])))
			var y: Vector3 = -along.normalized()
			var z: Vector3 = (back - y * back.dot(y)).normalized()
			axes = Basis(y.cross(z), y, z)

			if float(row[3]) > 0.0:
				stretch = along.length() / 100.0 / float(row[3])

		match old:
			"chest":
				at = Vector3(neck.x, neck.y - 22.0, neck.z)        # the old chest joint stood 22 cm under the neck: the collar of a tunic lands at his neck
			"head":
				at = Vector3(rest.origin.x, top.y - 24.0, rest.origin.z)      # the old head's top was 27 cm over its joint; 24 here so a hood shell covers his crown in the idle pose, where his head dips
			"foot_r", "foot_l":
				at = Vector3(rest.origin.x, 5.0, rest.origin.z)    # the old ankle was 5 cm up; his is higher, so the sole of a boot would float

		var frame: Transform3D = Transform3D(Basis(axes.x * 100.0, axes.y * 100.0 * stretch, axes.z * 100.0), at)
		frames[old] = [P + str(row[0]), rest.affine_inverse() * frame]

	return frames


func _rest_origin(bone: String) -> Vector3:
	var index: int = skeleton.find_bone(P + bone)
	return skeleton.get_bone_global_rest(index).origin if index >= 0 else Vector3.ZERO


# The game's names and Dave's own names, shared by every body. Hips travel is taken out of every clip (the game moves the body), see _clip.
func _build_animations() -> void:
	if _library == null:
		_library = AnimationLibrary.new()
		var own: AnimationLibrary = animation_player.get_animation_library(animation_player.get_animation_library_list()[0])

		for clip in own.get_animation_list():
			_library.add_animation(clip, _clip(own.get_animation(clip), 0.0, -1.0, true, 1.0))

		for game_name in CLIP_MAP:
			var row: Array = CLIP_MAP[game_name]
			_library.add_animation(game_name, _clip(own.get_animation(str(row[0])), float(row[1]), float(row[2]), bool(row[3]), float(row[4]), row[5] if row.size() > 5 else []))

	for library_name in animation_player.get_animation_library_list():
		animation_player.remove_animation_library(library_name)

	animation_player.add_animation_library("", _library)
	animation_player.play("idle")


# A copy of `src` between `from` and `to` seconds, its time multiplied by `retime`, looping or not. The hips travel on the ground is replaced by its deviation from a straight line, so
# a clip with root motion stays on the spot and a loop stays a loop.
static func _clip(src: Animation, from: float, to: float, loop: bool, retime: float, shape: Array = []) -> Animation:
	var end: float = src.length if to < 0.0 else minf(to, src.length)
	var out: Animation = Animation.new()
	out.length = maxf((end - from) * retime, 0.05)

	# `shape` = [impact in the source, new length, new impact time]: the time before the impact and the time after it are scaled separately.
	var impact: float = float(shape[0]) if shape.size() == 3 else -1.0
	var first_scale: float = 1.0
	var second_scale: float = 1.0

	if impact > 0.0:
		first_scale = float(shape[2]) / (impact - from)
		second_scale = (float(shape[1]) - float(shape[2])) / maxf(end - impact, 0.01)
		out.length = float(shape[1])
	out.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE

	for t in range(src.get_track_count()):
		var type: int = src.track_get_type(t)

		if type != Animation.TYPE_POSITION_3D and type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_SCALE_3D:
			continue

		var track: int = out.add_track(type)
		out.track_set_path(track, src.track_get_path(t))
		var times: Array = [from]

		if impact > 0.0:
			times.append(impact)

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

			if impact > 0.0:
				when = (float(kt) - from) * first_scale if float(kt) <= impact else float(shape[2]) + (float(kt) - impact) * second_scale

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


# A harmless stand-in when the glb cannot be used, so nothing that holds this body meets a null (my_character.gd make_avatar never picks it; this is the last guard).
func _make_empty() -> void:
	skeleton = Skeleton3D.new()
	add_child(skeleton)
	body_mesh = MeshInstance3D.new()
	add_child(body_mesh)
	animation_player = AnimationPlayer.new()
	add_child(animation_player)
	animation_player.add_animation_library("", AnimationLibrary.new())
	hand_mount_r = Marker3D.new()
	hand_mount_l = Marker3D.new()
	head_mount = Marker3D.new()
	add_child(hand_mount_r)
	add_child(hand_mount_l)
	add_child(head_mount)


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
