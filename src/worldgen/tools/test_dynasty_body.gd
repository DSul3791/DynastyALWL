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
	_check(absf(body.hand_mount_r.global_transform.basis.get_scale().x - 1.0) < 0.01, "right mount is metre scale")
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

	var hips_i: int = s.find_bone("mixamorig_Hips")
	var chest_i: int = s.find_bone("mixamorig_Spine2")
	# The modifier on the drawn pose (called here as the skeleton calls it, as test_head_look.gd does): the clip's pose, then the same pose with the legs turned.
	body.set_meta("leg_local", Vector2(3.2, 0.0))
	body.set_meta("backward", false)
	body.play("jog", 1.0, 0.0)
	body.animation_player.seek(0.2, true)
	var poses: Array = [[s.get_bone_global_pose(hips_i).basis.get_rotation_quaternion(), s.get_bone_global_pose(chest_i).basis.get_rotation_quaternion()]]
	body.leg_turn.angle = AvatarDriverScript.leg_turn("jog", Vector2(3.2, 0.0), false)
	body.leg_turn._process_modification_with_delta(0.0)
	poses.append([s.get_bone_global_pose(hips_i).basis.get_rotation_quaternion(), s.get_bone_global_pose(chest_i).basis.get_rotation_quaternion(), float(body.leg_turn.angle)])
	var hips_turn: Quaternion = (poses[1][0] as Quaternion) * (poses[0][0] as Quaternion).inverse()
	var chest_turn: Quaternion = (poses[1][1] as Quaternion) * (poses[0][1] as Quaternion).inverse()
	_check(absf(rad_to_deg(hips_turn.get_angle()) - 80.0) < 1.0 and absf(hips_turn.get_axis().y) > 0.99, "walking right: the hips turn %.1f degrees about the vertical (the legs' angle %.1f)" % [rad_to_deg(hips_turn.get_angle()), rad_to_deg(float(poses[1][2]))])
	_check(rad_to_deg(chest_turn.get_angle()) < 1.0, "and the chest stays on the look (%.2f degrees)" % rad_to_deg(chest_turn.get_angle()))
	_check(is_equal_approx(body.leg_turn.step_angle(0.0, 1.4, 0.1), 0.5), "the turn eases in at 5 radians a second, no snap")
	body.set_meta("leg_local", Vector2.ZERO)
	body.leg_turn.angle = 0.0

	print("dynasty body tests: %d failures" % _fails)
	quit()
