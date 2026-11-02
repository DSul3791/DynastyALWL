extends SceneTree

# PROTOTYPE (Sonny, 2026-10-30), plan 2: headless checks of src/client/character/motion_proto.gd.
#   godot --headless --path . --script res://tools/proto_motion.gd
# Prints PASS or FAIL lines; exit code 1 when a check fails. Not used by the game.

const Generator := preload("res://src/client/character/body_generator.gd")
const Motion := preload("res://src/client/character/motion_proto.gd")

var _fails: int = 0


func _initialize() -> void:
	var rigs: Array = []

	for preset in ["lean", "stocky", "average", "average"]:
		var made: Dictionary = Generator.make_node(Generator.make_genome(preset), 0.06)
		var node: Node3D = made["node"]
		root.add_child(node)
		var skeleton: Skeleton3D = made["skeleton"]
		var parts: Dictionary = Motion.attach(node, skeleton)
		rigs.append({"preset": preset, "node": node, "skeleton": skeleton, "player": parts["player"], "tree": parts["tree"]})

	# An AnimationTree built in code is set up a frame later: without waiting, advance() changes nothing (found by this check).
	await process_frame
	await process_frame
	_run(rigs)
	print("fails: ", _fails)
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)

	if not ok:
		_fails += 1


func _bone_angle(skeleton: Skeleton3D, bone: String) -> float:
	var q: Quaternion = skeleton.get_bone_pose_rotation(skeleton.find_bone(bone))
	return q.get_euler().x


func _step(tree: AnimationTree, seconds: float) -> void:
	var left: float = seconds

	while left > 0.0:
		var dt: float = minf(left, 1.0 / 60.0)
		tree.advance(dt)
		left -= dt


func _run(rigs: Array) -> void:
	var a: Dictionary = rigs[0]
	var b: Dictionary = rigs[1]
	var tree_a: AnimationTree = a["tree"]
	var tree_b: AnimationTree = b["tree"]
	var sk_a: Skeleton3D = a["skeleton"]
	var sk_b: Skeleton3D = b["skeleton"]

	# 1. A tree on a code-built skeleton and player: idle stays near rest, walking moves the legs.
	tree_a["parameters/Loco/blend_position"] = 0.0
	_step(tree_a, 0.5)
	var idle_leg: float = absf(_bone_angle(sk_a, "LeftUpperLeg"))
	_check(idle_leg < 0.05, "idle: the thigh stays near rest (angle %.3f)" % idle_leg)
	tree_a["parameters/Loco/blend_position"] = 1.4
	var walk_max: float = 0.0

	for _i in range(60):
		_step(tree_a, 1.0 / 60.0)
		walk_max = maxf(walk_max, absf(_bone_angle(sk_a, "LeftUpperLeg")))

	_check(walk_max > 0.3, "walking: the thigh swings (max angle %.2f rad)" % walk_max)

	# 2. A filtered one-shot: arms follow the panic clip while the legs keep following locomotion. Two identical bodies (rigs 3 and 4)
	# are stepped the same way; only rig 3 fires the one-shot, so any leg difference would come from the shot.
	var tree_c: AnimationTree = (rigs[2] as Dictionary)["tree"]
	var tree_d: AnimationTree = (rigs[3] as Dictionary)["tree"]
	var sk_c: Skeleton3D = (rigs[2] as Dictionary)["skeleton"]
	var sk_d: Skeleton3D = (rigs[3] as Dictionary)["skeleton"]

	for t in [tree_c, tree_d]:
		t["parameters/Loco/blend_position"] = 3.5

	_step(tree_c, 0.5)
	_step(tree_d, 0.5)
	tree_c["parameters/Shot/request"] = AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE
	var leg_gap: float = 0.0
	var arm_gap: float = 0.0

	for _i in range(40):
		_step(tree_c, 1.0 / 60.0)
		_step(tree_d, 1.0 / 60.0)
		leg_gap = maxf(leg_gap, absf(_bone_angle(sk_c, "RightUpperLeg") - _bone_angle(sk_d, "RightUpperLeg")))
		arm_gap = maxf(arm_gap, absf(_bone_angle(sk_c, "LeftUpperArm") - _bone_angle(sk_d, "LeftUpperArm")))

	_check(leg_gap < 0.05, "one-shot: legs keep the locomotion (max leg difference %.3f rad)" % leg_gap)
	_check(arm_gap > 1.0, "one-shot: arms follow the panic clip (max arm difference %.2f rad)" % arm_gap)
	_check(bool(tree_c["parameters/Shot/active"]), "one-shot: reports active while the panic clip plays")

	# 3. Held poses: with INTERPOLATION_NEAREST the panic clip holds its value between keys. Sample the clip directly.
	var panic: Animation = (a["player"] as AnimationPlayer).get_animation("panic")
	var track: int = panic.find_track(NodePath("Skeleton3D:LeftUpperArm"), Animation.TYPE_ROTATION_3D)
	var q1: Quaternion = panic.rotation_track_interpolate(track, 0.40)
	var q2: Quaternion = panic.rotation_track_interpolate(track, 0.41)
	var q3: Quaternion = panic.rotation_track_interpolate(track, 0.50)
	_check(track >= 0 and panic.track_get_interpolation_type(track) == Animation.INTERPOLATION_NEAREST, "panic track uses INTERPOLATION_NEAREST")
	_check(q1.is_equal_approx(q2) or q1.angle_to(q2) < 0.0001, "panic: pose is held between nearby times (0.40 s and 0.41 s)")
	_check(q1.angle_to(q3) > 0.02, "panic: pose changes between different keys (0.40 s and 0.50 s)")

	# 4. One clip set on two bodies with different bone lengths: the hips follow each body's own height through motion_scale.
	tree_a["parameters/Loco/blend_position"] = 0.0
	tree_b["parameters/Loco/blend_position"] = 0.0
	_step(tree_a, 1.5)
	_step(tree_b, 1.5)
	var hips_a: float = sk_a.get_bone_pose_position(sk_a.find_bone("Hips")).y
	var hips_b: float = sk_b.get_bone_pose_position(sk_b.find_bone("Hips")).y
	var rest_a: float = sk_a.get_bone_rest(sk_a.find_bone("Hips")).origin.y
	var rest_b: float = sk_b.get_bone_rest(sk_b.find_bone("Hips")).origin.y
	_check(absf(hips_a - rest_a) < 0.03 and absf(hips_b - rest_b) < 0.03, "hips height follows each body (lean %.3f vs rest %.3f, stocky %.3f vs rest %.3f)" % [hips_a, rest_a, hips_b, rest_b])
	_check(absf(rest_a - rest_b) > 0.1, "the two bodies really differ in hips height (%.2f m vs %.2f m)" % [rest_a, rest_b])
