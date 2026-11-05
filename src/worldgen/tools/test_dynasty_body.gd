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


func _init() -> void:
	var body: Node3D = Body.new()
	root.add_child(body)

	for clip in ["idle", "walk", "jog", "run", "crouch", "crouch_walk", "crouch_walk_back", "crouch_walk_left", "crouch_walk_right", "crouch_walk_torch", "crouch_walk_left_torch", "crouch_walk_right_torch", "sit", "sit_chair", "lie", "swing", "swing_fp", "jab", "throw", "use", "chop", "pick_overhead", "carry_idle", "carry_walk", "jump", "fall", "land"]:
		_check(body.animation_player.has_animation(clip), "clip " + clip)

	_check(body.animation_player.get_animation("walk").loop_mode == Animation.LOOP_LINEAR, "walk loops")
	_check(body.animation_player.get_animation("swing").loop_mode == Animation.LOOP_NONE, "swing is a one-shot")
	# Bug 10 (2 Nov 2026): the air clips come from Jump_Run; the driver asks for jump rising, fall dropping, land after a long fall, and plain clips on the floor.
	_check(body.animation_player.get_animation("jump").loop_mode == Animation.LOOP_NONE and body.animation_player.get_animation("land").loop_mode == Animation.LOOP_NONE and body.animation_player.get_animation("fall").loop_mode == Animation.LOOP_LINEAR, "jump and land play once, fall loops")
	_check(AvatarDriverScript.clip_for(body, 0, Vector3(0, 4.0, 0), Basis.IDENTITY, false, 0.0, "idle", false, 0.3) == "jump", "rising in the air: jump")
	_check(AvatarDriverScript.clip_for(body, 0, Vector3(0, -4.0, 0), Basis.IDENTITY, false, 0.0, "jump", false, 0.3) == "fall", "dropping in the air: fall")
	_check(AvatarDriverScript.clip_for(body, 0, Vector3(0, 0, -1.0), Basis.IDENTITY, true, 1.0, "fall", false, 0.016) == "land", "back on the floor after a long fall: land")
	_check(AvatarDriverScript.clip_for(body, 0, Vector3(0, 0, -1.0), Basis.IDENTITY, true, 1.0, "land", false, 0.5) == "walk", "once the landing is over: the plain walk (no strafe clips on this body)")
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

	body.play("crouch", 1.0, 0.0)
	body.animation_player.seek(1.0, true)
	await process_frame
	await process_frame
	var crouch_hips: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_Hips"))).origin
	_check(crouch_hips.y > 0.35 and crouch_hips.y < 0.6, "crouch: hips low")

	print("dynasty body tests: %d failures" % _fails)
	quit()
