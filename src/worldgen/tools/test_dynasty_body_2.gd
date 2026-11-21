extends SceneTree

# The second body model, body_2 (Dave's female player character, Playercharacter_Female_01.glb, 20 Nov 2026: "she should be the female selection now and be fully adjustable").
# Her file (Dave's 99-action v2, 20 Nov 2026) holds her own 4 clips and body_1's set retargeted to her rig. Checks: she is available and wears her own file; every game clip
# exists on her and comes from her own file; the idle hangs her arms down (not her T-pose rest) with her toes where body_1's are;
# lie, sit and crouch put her hips where they should be, and the cross-legged sit puts her knees forward and her hands by them; the creator's sliders work on her (height,
# legs, the width shapes made from her own mesh); an unknown body id wears body_1.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_dynasty_body_2.gd
const Body := preload("res://src/client/character/dynasty_body.gd")
const BodyModels := preload("res://src/client/character/body_models.gd")
const Generator := preload("res://src/client/character/body_generator.gd")

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

	# Her own file holds every clip the game plays (Dave's 99-action file, 20 Nov 2026: her own 4 and body_1's set retargeted to her rig), so none is missing on her.
	var her_file: Node = (load(BodyModels.glb("body_2")) as PackedScene).instantiate()
	var her_player: AnimationPlayer = her_file.find_children("*", "AnimationPlayer", true, false)[0]

	for clip in Body.CLIP_MAP:
		var source: String = str(Body.CLIP_MAP[clip][0])
		_check(her_player.has_animation(source), "her file holds %s (the game's %s)" % [source, clip])

	her_file.free()

	# The idle: arms hang at the sides, not out in her T-pose rest.
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
		# Round, not pointed (Dave 21 Nov 2026: "if you increase the breasts they get pointy they should get big, round and voluptuous"): 3 cm from the left breast's
		# front, up, down and to either side, the shaped surface is still within 2.5 cm of it (offline on her mesh about 1 to 1.5 cm; the old cone 4.4 cm).
		var tip: Vector3 = Vector3(0.0, 0.0, -INF)

		for p in raised:
			if p.x > 0.01 and absf(p.y - 1.3) < 0.2 and p.z > tip.z:
				tip = p

		var worst: float = 0.0

		for step in [Vector2(0.03, 0.0), Vector2(-0.03, 0.0), Vector2(0.0, 0.03), Vector2(0.0, -0.03)]:
			var at: Vector2 = Vector2(tip.x, tip.y) + step
			var front_there: float = -INF

			for p in raised:
				if p.x > 0.01 and Vector2(p.x, p.y).distance_to(at) < 0.012:
					front_there = maxf(front_there, p.z)

			worst = maxf(worst, tip.z - front_there)

		_check(worst < 0.025, "Bust +1: round at the front (falls %.3f m within 3 cm of it)" % worst)
		# The shape carries its own normals, so the light follows the round.
		var raised_n: PackedVector3Array = (shaped_mesh.surface_get_blend_shape_arrays(0)[bust] as Array)[Mesh.ARRAY_NORMAL]
		var base_n: PackedVector3Array = shaped_mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
		var turned: int = 0

		for v in range(base.size()):
			if raised_n[v].dot(base_n[v]) < 0.98:
				turned += 1

		_check(turned > 100, "Bust +1: %d normals turn with the shape" % turned)
		# Nothing folds through: the top's creases under the breast once met on the shape and showed through each other (Lane A, 21 Nov 2026). Count the triangles turned over.
		var idx: PackedInt32Array = shaped_mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
		var flipped: int = 0

		for t in range(0, idx.size() - 2, 3):
			var f0: Vector3 = (base[idx[t + 1]] - base[idx[t]]).cross(base[idx[t + 2]] - base[idx[t]])
			var f1: Vector3 = (raised[idx[t + 1]] - raised[idx[t]]).cross(raised[idx[t + 2]] - raised[idx[t]])

			if f0.dot(f1) < 0.0:
				flipped += 1

		_check(flipped < 5, "Bust +1: %d triangles turned over" % flipped)

	print("dynasty body 2 tests: %d failures" % _fails)
	her.free()
	him.free()
	quit()
