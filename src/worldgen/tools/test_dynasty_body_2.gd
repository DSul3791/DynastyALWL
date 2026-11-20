extends SceneTree

# The second body model, body_2 (Dave's female player character, Playercharacter_Female_01.glb, 20 Nov 2026: "she should be the female selection now and be fully adjustable").
# Her file holds 4 clips; the rest are carried over from body_1 (dynasty_body.gd _borrow_clips). Checks: she is available and wears her own file; every game clip exists on her;
# body_1's Walking carried over to her rig matches her own Walking (the carry-over turns each bone the right way); the carried idle hangs her arms down (not her T-pose rest);
# lie, sit and crouch put her hips where they should be, and the cross-legged sit puts her knees forward and her hands by them; the creator's sliders work on her (height,
# legs, the width shapes made from her own mesh); an unknown body id wears body_1.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_dynasty_body_2.gd
const Body := preload("res://src/client/character/dynasty_body.gd")
const BodyModels := preload("res://src/client/character/body_models.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const ARM_BONES := ["mixamorig_Spine2", "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_Head"]

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


# A bone's place as drawn. A SkeletonModifier3D (the sliders, dynasty_proportions.gd) changes the poses only while the skeleton updates and Godot puts the clip's pose back
# after, so the places are read in skeleton_updated (as test_dynasty_proportions.gd does) and looked up here; before the first update, the plain pose.
func _at(body: Node3D, bone: String) -> Vector3:
	var drawn: Dictionary = body.get_meta("drawn", {})

	if drawn.has(bone):
		return drawn[bone]

	var s: Skeleton3D = body.skeleton
	return (s.global_transform * s.get_bone_global_pose(s.find_bone(bone))).origin


func _watch(body: Node3D) -> void:
	var s: Skeleton3D = body.skeleton
	s.skeleton_updated.connect(func() -> void:
		var drawn: Dictionary = {}

		for i in range(s.get_bone_count()):
			drawn[s.get_bone_name(i)] = (s.global_transform * s.get_bone_global_pose(i)).origin

		body.set_meta("drawn", drawn))


func _pose(body: Node3D, clip: String, at: float) -> void:
	body.play(clip, 1.0, 0.0)
	body.animation_player.seek(at, true)
	await process_frame
	await process_frame


func _init() -> void:
	_check(Body.available("body_2"), "body_2 is imported and usable")
	var her: Node3D = Body.new("body_2")
	root.add_child(her)
	_watch(her)
	_check(her.model == "body_2", "body_2 wears her own model (got %s)" % her.model)
	var him: Node3D = Body.new()
	root.add_child(him)
	_check(him.model == "body_1", "the default body is body_1")
	var stray: Node3D = Body.new("no_such_body")
	_check(stray.model == "body_1", "an unknown body id wears body_1")
	stray.free()

	for clip in Body.CLIP_MAP:
		_check(her.animation_player.has_animation(clip), "body_2 has the game clip " + clip)

	for clip in ["idle_torch", "walk_torch", "Alert", "All_Night_Dance", "Formal_Bow"]:
		_check(her.animation_player.has_animation(clip), "body_2 has " + clip)

	# The carry-over, checked on the one clip both files hold: his Walking carried to her rig against her own Walking, key by key.
	var her_file: Node = (load(BodyModels.glb("body_2")) as PackedScene).instantiate()
	var his_file: Node = (load(BodyModels.glb("body_1")) as PackedScene).instantiate()
	var her_skel: Skeleton3D = her_file.find_children("*", "Skeleton3D", true, false)[0]
	var his_skel: Skeleton3D = his_file.find_children("*", "Skeleton3D", true, false)[0]
	var her_player: AnimationPlayer = her_file.find_children("*", "AnimationPlayer", true, false)[0]
	var his_player: AnimationPlayer = his_file.find_children("*", "AnimationPlayer", true, false)[0]
	var her_walk: Animation = her_player.get_animation("Walking")
	var his_walk: Animation = his_player.get_animation("Walking")
	var fix: Dictionary = Body.rig_fix(his_skel, his_walk, her_skel, her_walk)
	var prefix: String = String(her_walk.track_get_path(0)).get_slice(":", 0)
	var carried: Animation = Body.carry_clip(his_walk, fix, prefix, his_skel, her_skel)
	var worst: float = 0.0

	for bone in ARM_BONES:
		var mine: int = her_walk.find_track(NodePath(prefix + ":" + bone), Animation.TYPE_ROTATION_3D)
		var got: int = carried.find_track(NodePath(prefix + ":" + bone), Animation.TYPE_ROTATION_3D)

		if mine < 0 or got < 0:
			continue

		for n in range(8):
			var t: float = her_walk.length * float(n) / 8.0
			worst = maxf(worst, rad_to_deg(her_walk.rotation_track_interpolate(mine, t).angle_to(carried.rotation_track_interpolate(got, t))))

	_check(worst < 3.0, "body_1's Walking carried to body_2 matches her own Walking on the spine, arms and head (worst %.1f degrees)" % worst)
	her_file.free()
	his_file.free()

	# The carried idle: arms hang at the sides, not out in her T-pose rest.
	await _pose(her, "idle", 0.5)
	var hand_l: Vector3 = _at(her, "mixamorig_LeftHand")
	var hand_r: Vector3 = _at(her, "mixamorig_RightHand")
	var arm_l: Vector3 = _at(her, "mixamorig_LeftArm")
	_check(arm_l.y - hand_l.y > 0.35, "idle: her left hand hangs below the shoulder (%.2f m below)" % (arm_l.y - hand_l.y))
	_check(absf(hand_l.x - hand_r.x) < 0.75, "idle: her hands are at her sides, not out in a T (%.2f m apart)" % absf(hand_l.x - hand_r.x))
	var head: Vector3 = _at(her, "mixamorig_HeadTop_End")
	_check(head.y > 1.5 and head.y < 1.85, "idle: she stands about 1.7 m tall (%.2f m)" % head.y)
	var foot: float = minf(_at(her, "mixamorig_LeftToeBase").y, _at(her, "mixamorig_RightToeBase").y)
	_check(foot > -0.08 and foot < 0.12, "idle: her feet are on the ground (toes at %.2f m)" % foot)
	await _pose(him, "idle", 0.5)
	var his_foot: float = minf(_at(him, "mixamorig_LeftToeBase").y, _at(him, "mixamorig_RightToeBase").y)
	_check(absf(foot - his_foot) < 0.03, "idle: her toes stand where body_1's do (%.2f m, his %.2f m)" % [foot, his_foot])

	await _pose(her, "lie", 0.5)
	_check(_at(her, "mixamorig_Hips").y < 0.3, "lie: her hips are low")
	await _pose(her, "sit", 0.5)
	var sit_hips: float = _at(her, "mixamorig_Hips").y
	_check(sit_hips > 0.05 and sit_hips < 0.35, "sit: cross-legged on the ground (hips %.2f m)" % sit_hips)
	var s: Skeleton3D = her.skeleton
	var sit_root: Vector3 = s.get_bone_global_pose(s.find_bone("mixamorig_Hips")).origin

	for side in ["Left", "Right"]:
		var knee: Vector3 = s.get_bone_global_pose(s.find_bone("mixamorig_%sLeg" % side)).origin
		var hand: Vector3 = s.get_bone_global_pose(s.find_bone("mixamorig_%sHand" % side)).origin
		_check(knee.z - sit_root.z > 10.0, "sit: her %s knee is forward of the hips (%.0f cm)" % [side, knee.z - sit_root.z])
		_check(hand.distance_to(knee) < 18.0, "sit: her %s hand rests by its knee (%.0f cm)" % [side, hand.distance_to(knee)])

	await _pose(her, "crouch", 1.0)
	var crouch_hips: float = _at(her, "mixamorig_Hips").y
	_check(crouch_hips > 0.3 and crouch_hips < 0.65, "crouch: hips low (%.2f m)" % crouch_hips)

	# The creator's sliders on her: height makes her taller with her feet still down, legs lift her hips, and the width shapes are made for her mesh.
	await _pose(her, "idle", 0.5)
	var plain_head: float = _at(her, "mixamorig_HeadTop_End").y
	var plain_hips: float = _at(her, "mixamorig_Hips").y
	var tall: Dictionary = Generator.make_genome()
	tall["height"] = 1.0
	her.set_proportions(tall)
	await process_frame
	await process_frame
	_check(_at(her, "mixamorig_HeadTop_End").y > plain_head * 1.08, "Height +1: her head is higher (%.2f m from %.2f)" % [_at(her, "mixamorig_HeadTop_End").y, plain_head])
	var legs: Dictionary = Generator.make_genome()
	legs["legs"] = 1.0
	legs["build"] = 0.8
	legs["hips"] = -0.6
	her.set_proportions(legs)
	Body.Shapes.wait()

	for n in range(4):
		await process_frame

	_check(_at(her, "mixamorig_Hips").y > plain_hips + 0.03, "Legs +1: her hips are lifted (%.2f m from %.2f)" % [_at(her, "mixamorig_Hips").y, plain_hips])
	var long_foot: float = minf(_at(her, "mixamorig_LeftToeBase").y, _at(her, "mixamorig_RightToeBase").y)
	_check(absf(long_foot - foot) < 0.04, "Legs +1: her feet stay on the ground (toes at %.2f m, %.2f m before)" % [long_foot, foot])
	var build: int = her.body_mesh.find_blend_shape_by_name("build")
	_check(build >= 0 and absf(her.body_mesh.get_blend_shape_value(build) - 0.8) < 0.01, "Build 0.8: her mesh carries the width shapes")
	_check(her.body_mesh.mesh.has_meta(Body.Shapes.SHAPED_KEY), "her body wears the shaped copy of her own mesh")
	# The bust slider (Dave 20 Nov 2026: "yes we need a bust slider"): -1 ("none") leaves her as modelled, +1 is the fullest, and the shape raises the chest front.
	var full: Dictionary = Generator.make_genome()
	full["bust"] = 1.0
	her.set_proportions(full)
	var bust: int = her.body_mesh.find_blend_shape_by_name("bust")
	_check(bust >= 0 and absf(her.body_mesh.get_blend_shape_value(bust) - 1.0) < 0.01, "Bust +1: the bust shape is at its fullest on her")
	var none: Dictionary = Generator.make_genome()
	_check(absf(Body.Shapes.shape_weight(none, "bust")) < 0.001 and absf(Body.Shapes.shape_weight(full, "bust") - 1.0) < 0.001, "the bust's -1 (none) weighs 0, +1 weighs 1")
	_check(absf(Body.Shapes.shape_weight({"bust": float(Generator.FRAMES["neutral"]["bust"])}, "bust")) < 0.001 and is_equal_approx(Body.Shapes.BUST_FROM, float(Generator.FRAMES["neutral"]["bust"])), "the Even frame's bust leaves her as modelled (the mound starts at the Even frame's value)")

	if bust >= 0:
		var shaped_mesh: ArrayMesh = her.body_mesh.mesh as ArrayMesh
		var base: PackedVector3Array = shaped_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var raised: PackedVector3Array = (shaped_mesh.surface_get_blend_shape_arrays(0)[bust] as Array)[Mesh.ARRAY_VERTEX]
		var most: float = 0.0
		var high: float = 0.0

		for v in range(base.size()):
			if raised[v].z - base[v].z > most:
				most = raised[v].z - base[v].z
				high = base[v].y

		_check(most > 0.03 and most < 0.12, "Bust +1: the chest front comes forward %.3f m" % most)
		_check(high > 1.1 and high < 1.45, "Bust +1: at chest height (%.2f m)" % high)

	print("dynasty body 2 tests: %d failures" % _fails)
	her.free()
	him.free()
	quit()
