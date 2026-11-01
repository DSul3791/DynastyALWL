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

	for clip in ["idle", "walk", "jog", "run", "crouch", "crouch_walk", "crouch_walk_back", "crouch_walk_left", "crouch_walk_right", "crouch_walk_torch", "crouch_walk_left_torch", "crouch_walk_right_torch", "sit", "lie", "swing", "swing_fp", "jab", "throw", "use", "chop", "pick_overhead", "carry_idle", "carry_walk"]:
		_check(body.animation_player.has_animation(clip), "clip " + clip)

	_check(body.animation_player.get_animation("walk").loop_mode == Animation.LOOP_LINEAR, "walk loops")
	_check(body.animation_player.get_animation("swing").loop_mode == Animation.LOOP_NONE, "swing is a one-shot")
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
			_check(hips.y > 0.4 and hips.y < 0.65, "sit: hips about half a metre up")

	body.play("crouch", 1.0, 0.0)
	body.animation_player.seek(1.0, true)
	await process_frame
	await process_frame
	var crouch_hips: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_Hips"))).origin
	_check(crouch_hips.y > 0.35 and crouch_hips.y < 0.6, "crouch: hips low")

	print("dynasty body tests: %d failures" % _fails)
	quit()
