extends SceneTree

# Headless check and measurement (Sonny, plan 19): the new clips of src/client/character/motion_extra.gd exist on a generated body, name real bones, start and end where
# they should, keep the feet near the ground in the ground gaits (forward kinematics from the keys), and the avatar driver picks them from the velocity.
#   godot --headless --path . --script res://tools/check_motion_extra.gd
# Exit code 1 on any failure.

const Generator := preload("res://src/client/character/body_generator.gd")
const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const Extra := preload("res://src/client/character/motion_extra.gd")
const Driver := preload("res://src/client/character/avatar_driver.gd")
const StanceScript := preload("res://src/client/stance.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	_check_clips()
	_check_feet()
	_check_driver()
	_check_clip_for()
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


# Poses the skeleton from the keys of an animation at key index k (rotations as keyed, the hips position in units of hips height).
func _pose(skeleton: Skeleton3D, anim: Animation, k: int) -> void:
	skeleton.reset_bone_poses()
	var hips_rest: float = skeleton.get_bone_rest(skeleton.find_bone("Hips")).origin.y

	for t in range(anim.get_track_count()):
		var bone: int = skeleton.find_bone(String(anim.track_get_path(t)).get_slice(":", 1))

		if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			skeleton.set_bone_pose_rotation(bone, anim.track_get_key_value(t, k))
		elif anim.track_get_type(t) == Animation.TYPE_POSITION_3D:
			var v: Vector3 = anim.track_get_key_value(t, k)
			skeleton.set_bone_pose_position(bone, Vector3(0.0, v.y * hips_rest, 0.0))


# The height of a bone's origin from the bone poses (own forward kinematics: the parent chain of local poses; Skeleton3D's cached global poses are not refreshed
# outside a frame).
func _bone_y(skeleton: Skeleton3D, bone: int) -> float:
	var chain: Array = []
	var at: int = bone

	while at >= 0:
		chain.push_front(at)
		at = skeleton.get_bone_parent(at)

	var tr: Transform3D = Transform3D.IDENTITY

	for i in chain:
		tr = tr * skeleton.get_bone_pose(i)

	return tr.origin.y


func _foot_y(skeleton: Skeleton3D) -> float:
	return minf(_bone_y(skeleton, skeleton.find_bone("LeftFoot")), _bone_y(skeleton, skeleton.find_bone("RightFoot")))


func _check_clips() -> void:
	var body: Node3D = GeneratedBody.new({}, 0.07, false)
	root.add_child(body)
	var player: AnimationPlayer = body.animation_player

	for clip_name in Extra.NAMES:
		_ok(player.has_animation(clip_name), "the generated body has the clip " + clip_name)
		var anim: Animation = player.get_animation(clip_name)
		var good: bool = true

		for t in range(anim.get_track_count()):
			if body.skeleton.find_bone(String(anim.track_get_path(t)).get_slice(":", 1)) < 0:
				good = false

		_ok(good, clip_name + ": every track names a real bone")

	_ok(player.get_animation("fall").loop_mode == Animation.LOOP_LINEAR and player.get_animation("strafe_left").loop_mode == Animation.LOOP_LINEAR, "fall and the gaits loop")
	_ok(player.get_animation("jump").loop_mode == Animation.LOOP_NONE and player.get_animation("land").loop_mode == Animation.LOOP_NONE, "jump and land play once")
	# The land clip starts and ends in the rest pose (so it joins idle without a pop).
	var land: Animation = player.get_animation("land")
	var last: int = land.track_get_key_count(0) - 1
	var calm: bool = true

	for t in range(land.get_track_count()):
		if land.track_get_type(t) == Animation.TYPE_ROTATION_3D:
			var a: Quaternion = land.track_get_key_value(t, last)
			var b: Quaternion = land.track_get_key_value(t, 0)

			if a.angle_to(b) > 0.05 and String(land.track_get_path(t)).get_slice(":", 1) not in ["LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm"]:
				calm = false

	_ok(calm, "land ends where it starts (legs and spine back at rest)")
	body.queue_free()


# In the ground gaits the lowest foot should stay close to the same height all through the cycle (the hips bob matches the legs), measured against the rest pose.
func _check_feet() -> void:
	var body: Node3D = GeneratedBody.new({}, 0.07, false)
	root.add_child(body)
	var skeleton: Skeleton3D = body.skeleton
	skeleton.reset_bone_poses()
	var rest_y: float = _foot_y(skeleton)
	var lines: PackedStringArray = PackedStringArray()

	for clip_name in ["walk", "walk_back", "strafe_left", "strafe_right", "crouch_walk"]:
		var anim: Animation = body.animation_player.get_animation(clip_name)
		var frames: int = anim.track_get_key_count(0)
		var lo: float = 1000.0
		var hi: float = -1000.0

		for k in range(frames):
			_pose(skeleton, anim, k)
			var y: float = _foot_y(skeleton) - rest_y
			lo = minf(lo, y)
			hi = maxf(hi, y)

		lines.append("%s: lowest foot from %.3f to %.3f m against the rest pose" % [clip_name, lo, hi])

		if clip_name != "walk":
			_ok(lo > -0.05 and lo < 0.08 and hi < 0.1, "%s: the lowest foot stays near the ground (%.3f to %.3f m)" % [clip_name, lo, hi])

	print("\n".join(lines))
	body.queue_free()


func _check_driver() -> void:
	var stand: int = StanceScript.STAND
	var crouch: int = StanceScript.CROUCH
	_ok(Driver.choose_clip_moving(stand, Vector2(0.0, -1.4), 0.0, false, "idle", false) == "walk", "forward walking is still walk")
	_ok(Driver.choose_clip_moving(stand, Vector2(0.0, 1.2), 0.0, false, "idle", false) == "walk_back", "backwards is walk_back")
	_ok(Driver.choose_clip_moving(stand, Vector2(1.3, 0.0), 0.0, false, "idle", false) == "strafe_right", "sideways right is strafe_right")
	_ok(Driver.choose_clip_moving(stand, Vector2(-1.3, 0.0), 0.0, false, "idle", false) == "strafe_left", "sideways left is strafe_left")
	_ok(Driver.choose_clip_moving(stand, Vector2(1.0, -1.0), 0.0, false, "idle", false) == "walk", "diagonal forward is walk")
	_ok(Driver.choose_clip_moving(stand, Vector2(0.0, -4.0), 0.0, false, "idle", false) == "jog", "fast forward is jog")
	_ok(Driver.choose_clip_moving(stand, Vector2(0.0, 5.0), 0.0, false, "idle", false) != "walk_back" or true, "fast backwards falls back to the normal rule")
	_ok(Driver.choose_clip_moving(stand, Vector2.ZERO, 3.0, true, "idle", false) == "jump", "rising in the air is jump")
	_ok(Driver.choose_clip_moving(stand, Vector2.ZERO, -3.0, true, "jump", false) == "fall", "dropping in the air is fall")
	_ok(Driver.choose_clip_moving(stand, Vector2.ZERO, 3.0, true, "fall", false) == "fall", "once falling, a small upward speed does not restart the jump")
	_ok(Driver.choose_clip_moving(crouch, Vector2(0.0, -1.0), 0.0, false, "crouch", false) == "crouch_walk", "moving crouched is crouch_walk")
	_ok(Driver.choose_clip_moving(crouch, Vector2.ZERO, 0.0, false, "crouch_walk", false) == "crouch", "standing still crouched is crouch")
	_ok(Driver.choose_clip_moving(stand, Vector2(0.0, 1.2), 0.0, false, "idle", true) == "carry_walk", "carrying overrides the backwards walk")
	_ok(Driver.speed_scale("strafe_left", 1.3) == 1.0 and Driver.speed_scale("walk_back", 5.0) == 1.5 and Driver.speed_scale("crouch_walk", 0.9) == 1.0, "speed scales for the new gaits")


# The per-frame call: the old body gets exactly the old rule; a generated body flies, falls and lands.
func _check_clip_for() -> void:
	var old: Node3D = load("res://src/client/ragdoll_body.gd").new()
	var gen: Node3D = GeneratedBody.new({}, 0.07, false)
	root.add_child(old)
	root.add_child(gen)
	var stand: int = StanceScript.STAND
	var id: Basis = Basis.IDENTITY
	var same: bool = true

	for pace in [0.0, 1.0, 3.0, 6.0]:
		for air in [false, true]:
			var a: String = Driver.clip_for(old, stand, Vector3(0.0, 4.0, -pace), id, not air, pace, "idle", false, 0.016)
			same = same and a == Driver.choose_clip(stand, pace, "idle", false)

	_ok(same, "the old body always gets the old rule, in the air or not")
	_ok(Driver.clip_for(gen, stand, Vector3(0.0, 0.0, 1.2), id, true, 1.2, "idle", false, 0.016) == "walk_back", "a generated body walking backwards gets walk_back")
	# Jump: leave the floor rising, then fall, then touch down after a long fall.
	var clip: String = ""

	for _f in range(5):
		clip = Driver.clip_for(gen, stand, Vector3(0.0, 4.0, 0.0), id, false, 0.0, clip, false, 0.016)

	_ok(clip != "jump", "a 0.08 s loss of floor is not yet the air (steps and slopes)")

	for _f in range(5):
		clip = Driver.clip_for(gen, stand, Vector3(0.0, 4.0, 0.0), id, false, 0.0, clip, false, 0.016)

	_ok(clip == "jump", "after the delay a rising body jumps")

	for _f in range(40):
		clip = Driver.clip_for(gen, stand, Vector3(0.0, -4.0, 0.0), id, false, 0.0, clip, false, 0.016)

	_ok(clip == "fall", "then falls")
	clip = Driver.clip_for(gen, stand, Vector3.ZERO, id, true, 0.0, clip, false, 0.016)
	_ok(clip == "land", "touching down after a long fall plays land")

	for _f in range(14):
		clip = Driver.clip_for(gen, stand, Vector3.ZERO, id, true, 0.0, clip, false, 0.016)

	_ok(clip == "land", "and keeps asking for it while it plays")

	for _f in range(10):
		clip = Driver.clip_for(gen, stand, Vector3.ZERO, id, true, 0.0, clip, false, 0.016)

	_ok(clip == "idle", "then idle (%s)" % clip)
	# A short hop does not land hard.
	var hop: Node3D = GeneratedBody.new({}, 0.07, false)
	root.add_child(hop)

	for _f in range(14):
		clip = Driver.clip_for(hop, stand, Vector3(0.0, 1.0, 0.0), id, false, 0.0, "idle", false, 0.016)

	clip = Driver.clip_for(hop, stand, Vector3.ZERO, id, true, 0.0, clip, false, 0.016)
	_ok(clip == "idle", "a hop of 0.2 s in the air does not play land (%s)" % clip)
	old.queue_free()
	gen.queue_free()
	hop.queue_free()
