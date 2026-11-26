extends SceneTree

# Dynasty body (src/client/character/dynasty_body.gd): every game clip name exists and has a length, the mounts exist and are metre-scale, the lie clip puts the head toward +Z,
# the sit clip puts the hips about half a metre up. Run: godot --headless --path . --script res://src/worldgen/tools/test_dynasty_body.gd
const Body := preload("res://src/client/character/dynasty_body.gd")
const AvatarDriverScript := preload("res://src/client/character/avatar_driver.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


# Every rotation key of the clip is its first: one pose held.
func _still(anim: Animation) -> bool:
	for t in range(anim.get_track_count()):
		for k in range(1, anim.track_get_key_count(t)):
			if anim.track_get_type(t) == Animation.TYPE_ROTATION_3D and not (anim.track_get_key_value(t, 0) as Quaternion).is_equal_approx(anim.track_get_key_value(t, k) as Quaternion):
				return false

	return true


# How far the hips are turned from the shoulders about the vertical, in degrees (+ the hips to the body's left), from the skeleton's posed joints: the line from
# the right hip joint to the left against the line from the right shoulder to the left (skeleton space, up +Y).
func _twist(s: Skeleton3D) -> float:
	var hip: Vector3 = s.get_bone_global_pose(s.find_bone("mixamorig_LeftUpLeg")).origin - s.get_bone_global_pose(s.find_bone("mixamorig_RightUpLeg")).origin
	var top: Vector3 = s.get_bone_global_pose(s.find_bone("mixamorig_LeftArm")).origin - s.get_bone_global_pose(s.find_bone("mixamorig_RightArm")).origin
	return rad_to_deg(wrapf(atan2(-hip.z, hip.x) - atan2(-top.z, top.x), -PI, PI))

func _init() -> void:
	var body: Node3D = Body.new()
	root.add_child(body)

	for clip in ["idle", "walk", "jog", "run", "crouch", "crouch_walk", "crouch_walk_back", "crouch_walk_left", "crouch_walk_right", "crouch_walk_torch", "crouch_walk_left_torch", "crouch_walk_right_torch", "sit", "sit_chair", "idle_torch", "walk_torch", "jog_torch", "run_torch", "lie", "swing", "swing_fp", "jab", "throw", "use", "chop", "pick_overhead", "carry_idle", "carry_walk", "jump", "fall", "land"]:
		_check(body.animation_player.has_animation(clip), "clip " + clip)

	_check(body.animation_player.get_animation("walk").loop_mode == Animation.LOOP_LINEAR, "walk loops")
	_check(body.animation_player.get_animation("swing").loop_mode == Animation.LOOP_NONE, "swing is a one-shot")
	# Bug 10 (2 Nov 2026): the air clips come from Jump_Run; the driver asks for jump rising, fall dropping, land after a long fall, and plain clips on the floor.
	_check(body.animation_player.get_animation("jump").loop_mode == Animation.LOOP_NONE and body.animation_player.get_animation("land").loop_mode == Animation.LOOP_NONE and body.animation_player.get_animation("fall").loop_mode == Animation.LOOP_LINEAR, "jump and land play once, fall loops")
	_check(AvatarDriverScript.clip_for(body, 0, Vector3(0, 4.0, 0), Basis.IDENTITY, false, 0.0, "idle", false, 0.3) == "jump", "rising in the air: jump")
	_check(AvatarDriverScript.clip_for(body, 0, Vector3(0, -4.0, 0), Basis.IDENTITY, false, 0.0, "jump", false, 0.3) == "fall", "dropping in the air: fall")
	_check(AvatarDriverScript.clip_for(body, 0, Vector3(0, 0, -1.0), Basis.IDENTITY, true, 1.0, "fall", false, 0.016) == "land", "back on the floor after a long fall: land")
	_check(AvatarDriverScript.clip_for(body, 0, Vector3(0, 0, -1.0), Basis.IDENTITY, true, 1.0, "land", false, 0.5) == "walk", "once the landing is over: the plain walk (no strafe clips on this body)")
	# QA #15 (25 Nov 2026): a running jump lands straight back into the gait (the land clip plants both feet, at a run they slid), and the fall is one still air pose.
	AvatarDriverScript.clip_for(body, 0, Vector3(0, -4.0, -6.0), Basis.IDENTITY, false, 6.0, "run", false, 0.5)
	_check(AvatarDriverScript.clip_for(body, 0, Vector3(0, 0, -6.0), Basis.IDENTITY, true, 6.0, "fall", false, 0.016) != "land", "back on the floor at a run after a long fall: no land clip")
	_check(_still(body.animation_player.get_animation("fall")), "the fall holds one air pose (no legs running in the air)")
	# QA #15 ("character still looking around too much"): the standing idle is Idle's first frame held still (it breathes by dynasty_breath.gd), head included.
	_check(_still(body.animation_player.get_animation("idle")) and _still(body.animation_player.get_animation("carry_idle")), "the idle and the carry idle hold still (no looking around)")
	# No jog since 10 Nov 2026 (the walk is 3.2 m/s): walking backwards on this body plays the gait in reverse; forwards it plays as is.
	var back_clip: String = AvatarDriverScript.clip_for(body, 0, Vector3(0, 0, 3.2), Basis.IDENTITY, true, 3.2, "walk", false, 0.5)
	_check(AvatarDriverScript.backward_sign(body, back_clip) < 0.0, "walking backwards at 3.2 m/s: the %s clip plays in reverse" % back_clip)
	var ahead_clip: String = AvatarDriverScript.clip_for(body, 0, Vector3(0, 0, -3.2), Basis.IDENTITY, true, 3.2, back_clip, false, 0.5)
	_check(AvatarDriverScript.backward_sign(body, ahead_clip) > 0.0, "walking forwards: the %s clip plays forwards" % ahead_clip)
	_check(AvatarDriverScript.choose_clip_moving(0, Vector2(0.0, 3.2), 0.0, false, "jog", false) == "walk_back" and AvatarDriverScript.choose_clip_moving(0, Vector2(3.2, 0.0), 0.0, false, "jog", false) == "strafe_right", "a generated body walking back or sideways at 3.2 m/s gets walk_back and strafe_right")
	_check(body.animation_player.get_animation("crouch").loop_mode == Animation.LOOP_LINEAR, "crouch loops")
	# Chop sound sync (1 Nov 2026): one swing is one blow, and the clip is the length of the game's swing so the blow lands at held_item's HIT_AT (the sound and the hit).
	_check(absf(body.animation_player.get_animation("chop").length - 0.95) < 0.02, "chop clip is the 0.95 s swing (%.3f)" % body.animation_player.get_animation("chop").length)
	_check(absf(body.animation_player.get_animation("pick_overhead").length - 1.0) < 0.02, "pick clip is the 1.0 s swing (%.3f)" % body.animation_player.get_animation("pick_overhead").length)
	_check(AvatarDriverScript.crouch_walk_clip(Vector2(0.0, -1.0)) == "crouch_walk" and AvatarDriverScript.crouch_walk_clip(Vector2(0.0, 1.0)) == "crouch_walk_back" and AvatarDriverScript.crouch_walk_clip(Vector2(1.0, 0.0)) == "crouch_walk_right", "crouch clip by direction")
	_check(body.hand_mount_r != null and body.hand_mount_l != null and body.head_mount != null, "mounts")
	await process_frame      # in the tree first: in _init a global transform is not ready (the engine said "!is_inside_tree()" and gave the identity, Lane A pr1961)
	_check(body.hand_mount_r.is_inside_tree() and absf(body.hand_mount_r.global_transform.basis.get_scale().x - 1.0) < 0.01, "right mount is metre scale")
	var s: Skeleton3D = body.skeleton

	for spec in [["lie", 0.5], ["sit", 0.5]]:
		body.play(spec[0], 1.0, 0.0)
		body.animation_player.seek(spec[1], true)
		await process_frame
		await process_frame
		var hips: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_Hips"))).origin
		var head: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_Head"))).origin

		if spec[0] == "lie":
			_check(head.z - hips.z > 0.4, "lie: head toward +Z")
			_check(hips.y < 0.3, "lie: hips low")
		else:
			_check(hips.y > 0.05 and hips.y < 0.35, "sit: cross-legged on the ground, hips low (%.2f m)" % hips.y)

	# The ground sit holds still through the chair clip's loop (PC shot 5 Nov: a lunge at a later time): hips and knees in the same place at any time.
	var sit_at: Array = []

	for at in [0.0, 2.5, 5.1, 8.0]:
		body.play("sit", 1.0, 0.0)
		body.animation_player.seek(at, true)
		await process_frame
		await process_frame
		sit_at.append([(s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_Hips"))).origin, (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_LeftLeg"))).origin, (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_RightLeg"))).origin])

	# Cross-legged (PC shot 5 Nov): the knees forward of the hips, not straight out at the sides, and each hand resting near its knee (skeleton space, centimetres; front +Z).
	body.play("sit", 1.0, 0.0)
	body.animation_player.seek(0.5, true)
	await process_frame
	await process_frame
	var sit_hips: Vector3 = s.get_bone_global_pose(s.find_bone("mixamorig_Hips")).origin

	for side in ["Left", "Right"]:
		var knee: Vector3 = s.get_bone_global_pose(s.find_bone("mixamorig_%sLeg" % side)).origin
		var hand: Vector3 = s.get_bone_global_pose(s.find_bone("mixamorig_%sHand" % side)).origin
		_check(knee.z - sit_hips.z > 10.0, "sit: %s knee forward of the hips (%.0f cm)" % [side, knee.z - sit_hips.z])
		_check(hand.distance_to(knee) < 18.0, "sit: %s hand rests by its knee (%.0f cm)" % [side, hand.distance_to(knee)])

	for row in sit_at:
		_check((row[0] as Vector3).distance_to(sit_at[0][0]) < 0.03 and (row[1] as Vector3).distance_to(sit_at[0][1]) < 0.03 and (row[2] as Vector3).distance_to(sit_at[0][2]) < 0.03, "sit: hips and knees hold still through the loop")

	# Sitting on a seat (E on a chair, 5 Nov): hips at seat height, the feet on the ground in front, still through the loop.
	var chair_at: Array = []

	for at in [0.0, 5.1]:
		body.play("sit_chair", 1.0, 0.0)
		body.animation_player.seek(at, true)
		await process_frame
		await process_frame
		chair_at.append((s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_Hips"))).origin)

	var chair_foot: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_LeftFoot"))).origin
	_check((chair_at[0] as Vector3).y > 0.45 and (chair_at[0] as Vector3).y < 0.6, "sit_chair: hips at seat height (%.2f m)" % (chair_at[0] as Vector3).y)
	_check(chair_foot.y < 0.2, "sit_chair: feet on the ground (%.2f m)" % chair_foot.y)
	_check((chair_at[1] as Vector3).distance_to(chair_at[0]) < 0.03, "sit_chair: holds still through the loop")

	# The torch carry (Dave's infographic, 6 Nov): walking with a torch in the left hand, the left hand is up in front (about 1.2 m, well forward of the hips) and
	# holds still against the body, while the right arm keeps swinging.
	var torch_rows: Array = []

	for at in [0.1, 0.5]:
		body.play("walk_torch", 1.0, 0.0)
		body.animation_player.seek(at, true)
		await process_frame
		await process_frame
		var g_hips: Vector3 = s.get_bone_global_pose(s.find_bone("mixamorig_Hips")).origin
		torch_rows.append([(s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_LeftHand"))).origin, s.get_bone_global_pose(s.find_bone("mixamorig_LeftHand")).origin - g_hips, (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_RightHand"))).origin])

	var torch_hand: Vector3 = torch_rows[0][0]
	_check(torch_hand.y > 1.0 and torch_hand.y < 1.45, "walk_torch: left hand up at chest height (%.2f m)" % torch_hand.y)
	_check((torch_rows[0][1] as Vector3).z > 15.0, "walk_torch: left hand in front of the body (%.0f cm)" % (torch_rows[0][1] as Vector3).z)
	_check((torch_rows[0][2] as Vector3).distance_to(torch_rows[1][2]) > 0.05, "walk_torch: the right arm still swings")

	body.play("crouch", 1.0, 0.0)
	body.animation_player.seek(1.0, true)
	await process_frame
	await process_frame
	var crouch_hips: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_Hips"))).origin
	_check(crouch_hips.y > 0.35 and crouch_hips.y < 0.6, "crouch: hips low")

	# Foot slide (26 Nov 2026, Dave's basics: no sliding): walking sideways or on a diagonal the legs turn toward the travel, the chest stays on the look
	# (avatar_driver.gd leg_turn, dynasty_leg_turn.gd; offline the forward clip's feet slid 62 cm a step sideways, 43 on a diagonal).
	var d: Vector2 = Vector2(-1.0, -1.0).normalized() * 3.2
	_check(is_equal_approx(AvatarDriverScript.leg_turn("jog", Vector2(3.2, 0.0), false), -AvatarDriverScript.LEG_TURN_MAX), "walking right: the legs turn right, at most 80 degrees")
	_check(absf(AvatarDriverScript.leg_turn("jog_torch", d, false) - PI * 0.25) < 0.01, "walking forward and left: the legs turn 45 degrees left (with a torch too)")
	_check(absf(AvatarDriverScript.leg_turn("jog", Vector2(d.x, -d.y), true) + PI * 0.25) < 0.01, "walking back and left, the gait in reverse: the legs turn 45 degrees right")
	_check(absf(AvatarDriverScript.leg_turn("jog", Vector2(0.0, -3.2), false)) < 0.001 and absf(AvatarDriverScript.leg_turn("jog", Vector2(0.0, 3.2), true)) < 0.001, "straight ahead or straight back: no turn")
	_check(AvatarDriverScript.leg_turn("jog", Vector2(0.3, 0.0), false) == 0.0 and AvatarDriverScript.leg_turn("swing", Vector2(3.2, 0.0), false) == 0.0 and AvatarDriverScript.leg_turn("carry_walk", Vector2(1.0, 0.0), false) == 0.0, "standing still, swinging or carrying: no turn")
	var c: Vector2 = Vector2(-sin(PI / 3.0), -cos(PI / 3.0)) * 0.64
	_check(AvatarDriverScript.crouch_walk_clip(c) == "crouch_walk_left" and absf(AvatarDriverScript.leg_turn("crouch_walk_left", c, false) + PI / 6.0) < 0.01, "crouched 60 degrees left: the left crouch walk, its legs turned 30 degrees back toward ahead")
	_check(absf(AvatarDriverScript.leg_turn("crouch_walk_torch", d * 0.2, false) - PI * 0.25) < 0.01, "crouched forward and left: the forward crouch walk, its legs turned 45 degrees left")

	# The drawn pose, as the game draws it (Lane A pr1961: the modifier passed a direct call while the drawn legs did not turn): the jog playing, the skeleton's final
	# pose read when it is handed to the skin (skeleton_updated, after every modifier), the hip line against the shoulder line seen from above.
	body.set_meta("backward", false)
	var twists: Array = []

	for local in [Vector2.ZERO, Vector2(3.2, 0.0)]:
		body.set_meta("leg_local", local)
		body.play("jog", 1.0, 0.0)

		for i in range(3000):
			await process_frame

			if absf(float(body.leg_turn.angle) - AvatarDriverScript.leg_turn("jog", local, false)) < 0.001:
				break

		# Both read at the same point of the jog (the hips and shoulders counter-turn through the stride), paused there; the pose is read once, when the skeleton
		# hands it to the skin, and the wait is bounded.
		body.animation_player.seek(0.2, true)
		body.animation_player.pause()
		var seen: Array = []
		s.skeleton_updated.connect(func() -> void: seen.append(_twist(s)), CONNECT_ONE_SHOT)

		for i in range(30):
			await process_frame

			if not seen.is_empty():
				break

		twists.append(float(seen[0]) if not seen.is_empty() else INF)

	_check(absf(float(twists[0])) < 20.0, "the jog straight ahead as drawn: hips and shoulders in line (%.1f degrees)" % float(twists[0]))
	_check(float(twists[1]) - float(twists[0]) < -65.0 and float(twists[1]) - float(twists[0]) > -95.0, "walking right as drawn: the hips turned right of the shoulders by %.1f degrees (80 asked)" % (float(twists[0]) - float(twists[1])))
	_check(is_equal_approx(body.leg_turn.step_angle(0.0, 1.4, 0.1), 0.5), "the turn eases in at 5 radians a second, no snap")
	body.set_meta("leg_local", Vector2.ZERO)
	body.leg_turn.angle = 0.0
	body.play("idle", 1.0, 0.0)

	# Turning on the spot (dynasty_leg_turn.gd _plant): standing still the feet stay planted while the body turns a little, then step round, each foot lifted.
	for i in range(3000):
		await process_frame

		if absf(float(body.leg_turn.angle)) < 0.001 and absf(float(body.leg_turn.twist)) < 0.001 and not body.leg_turn.stepping:
			break

	# Each drawn pose (skeleton space, centimetres): [twist degrees, left foot height, right foot height, left knee ahead, right knee ahead].
	var poses: Array = []
	var bone_at: Callable = func(bone: String) -> Vector3: return s.get_bone_global_pose(s.find_bone("mixamorig_" + bone)).origin
	var knee_ahead: Callable = func(leg_side: String) -> float:   # the knee ahead of its hip joint, along the hips' own front (the hip line crossed with up)
		var hip_line: Vector3 = (bone_at.call("LeftUpLeg") as Vector3) - (bone_at.call("RightUpLeg") as Vector3)
		return ((bone_at.call(leg_side + "Leg") as Vector3) - (bone_at.call(leg_side + "UpLeg") as Vector3)).dot(hip_line.cross(Vector3.UP).normalized())
	var watch: Callable = func() -> void: poses.append([_twist(s), (bone_at.call("LeftFoot") as Vector3).y, (bone_at.call("RightFoot") as Vector3).y, float(knee_ahead.call("Left")), float(knee_ahead.call("Right"))])
	s.skeleton_updated.connect(watch)

	for i in range(60):
		await process_frame

		if poses.size() >= 2:
			break

	var rest: Array = poses[poses.size() - 1] if not poses.is_empty() else [0.0, 0.0, 0.0, 0.0, 0.0]
	body.rotation.y += 0.4   # 23 degrees to the left: under STEP_FROM, the feet stay put
	poses.clear()

	for i in range(60):
		await process_frame

		if poses.size() >= 3:
			break

	var small: Array = poses[poses.size() - 1] if not poses.is_empty() else [INF, 0.0, 0.0, 0.0, 0.0]
	_check(not body.leg_turn.stepping and float(small[0]) - float(rest[0]) < -18.0 and float(small[0]) - float(rest[0]) > -28.0, "a 23 degree turn standing still: the hips stay on the planted feet, %.1f degrees right of the shoulders" % (float(rest[0]) - float(small[0])))
	body.rotation.y += 1.0   # on to 80 degrees: the feet step round
	poses.clear()
	var stepped: bool = false

	for i in range(1200):
		await process_frame
		stepped = stepped or body.leg_turn.stepping

		if stepped and not body.leg_turn.stepping:
			break

	await process_frame
	await process_frame
	s.skeleton_updated.disconnect(watch)
	var up: Array = [0.0, 0.0]       # each foot's highest rise, cm
	var knee_fwd: Array = [0.0, 0.0]     # each knee's furthest forward, cm
	var first_up: Array = [-1, -1]   # the pose each foot first rose 2 cm

	for k in range(poses.size()):
		for f in range(2):
			var rise: float = float(poses[k][1 + f]) - float(rest[1 + f])
			up[f] = maxf(float(up[f]), rise)
			knee_fwd[f] = maxf(float(knee_fwd[f]), float(poses[k][3 + f]) - float(rest[3 + f]))

			if rise > 2.0 and int(first_up[f]) < 0:
				first_up[f] = k

	var end: Array = poses[poses.size() - 1] if not poses.is_empty() else [INF, 0.0, 0.0, 0.0, 0.0]
	_check(stepped and not body.leg_turn.stepping, "an 80 degree turn standing still: the feet step round and stop (in 1200 frames)")
	_check(float(up[0]) > 4.0 and float(up[1]) > 4.0, "both feet lift as they step (%.1f and %.1f cm)" % [float(up[0]), float(up[1])])
	_check(float(knee_fwd[0]) > 5.0 and float(knee_fwd[1]) > 5.0, "each stepping knee comes forward, not back (%.1f and %.1f cm)" % [float(knee_fwd[0]), float(knee_fwd[1])])
	_check(int(first_up[0]) >= 0 and int(first_up[0]) < int(first_up[1]), "turning left the left foot steps first (poses %d and %d)" % [int(first_up[0]), int(first_up[1])])
	_check(absf(float(end[0]) - float(rest[0])) < 3.0, "after the steps the hips are under the shoulders again (%.1f degrees)" % (float(end[0]) - float(rest[0])))
	_check(absf(float(end[1]) - float(rest[1])) < 1.0 and absf(float(end[2]) - float(rest[2])) < 1.0, "and both feet are down")

	# A yaw jump (a respawn, a wake at a camp) re-plants the feet where he now stands: no steps.
	body.rotation.y += PI * 0.9

	for i in range(3):
		await process_frame

	_check(not body.leg_turn.stepping and absf(float(body.leg_turn.twist)) < 0.001, "a 162 degree jump in one frame re-plants the feet, no steps")
	body.rotation.y = 0.0

	print("dynasty body tests: %d failures" % _fails)
	quit()
