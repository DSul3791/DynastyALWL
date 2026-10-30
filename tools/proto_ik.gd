extends SceneTree

# PROTOTYPE (Sonny, 2026-10-30), plan 5: can the Godot 4.6+ TwoBoneIK3D plant a foot of a generated body on a raised target (a step or a slope)?
#   godot --headless --path . --script res://tools/proto_ik.gd
# Prints PASS or FAIL lines; exit code 1 on a failure.

const Generator := preload("res://src/client/character/body_generator.gd")

var _fails: int = 0


func _initialize() -> void:
	var made: Dictionary = Generator.make_node(Generator.make_genome("lean"), 0.06)
	var rig: Node3D = made["node"]
	var sk: Skeleton3D = made["skeleton"]
	root.add_child(rig)
	var ik: TwoBoneIK3D = TwoBoneIK3D.new()
	ik.name = "FootIK"
	sk.add_child(ik)
	var counter: Array = [0, 0]
	ik.modification_processed.connect(func() -> void: counter[0] += 1)
	var seen: Dictionary = {}
	sk.skeleton_updated.connect(func() -> void:
		counter[1] += 1
		for bone in ["LeftFoot", "RightFoot", "LeftLowerLeg", "LeftUpperLeg"]:
			seen[bone] = sk.get_bone_global_pose(sk.find_bone(bone)).origin)
	ik.setting_count = 2
	var sides: Array = ["Left", "Right"]
	var raise: Array = [0.15, 0.0]               # the left foot is lifted onto a 15 cm step, the right foot stays on the ground

	for i in range(2):
		var target: Node3D = Node3D.new()
		target.name = "Target" + sides[i]
		rig.add_child(target)
		var pole: Node3D = Node3D.new()
		pole.name = "Pole" + sides[i]
		rig.add_child(pole)
		var ankle: Vector3 = sk.get_bone_global_rest(sk.find_bone(sides[i] + "Foot")).origin
		target.position = ankle + Vector3(0.0, raise[i], 0.0)
		var knee: Vector3 = sk.get_bone_global_rest(sk.find_bone(sides[i] + "LowerLeg")).origin
		pole.position = knee + Vector3(0.0, 0.0, -0.6)          # the knee should point forward (-Z)
		ik.set_root_bone_name(i, sides[i] + "UpperLeg")
		ik.set_middle_bone_name(i, sides[i] + "LowerLeg")
		ik.set_end_bone_name(i, sides[i] + "Foot")
		ik.set_target_node(i, ik.get_path_to(target))
		ik.set_pole_node(i, ik.get_path_to(pole))

	# A straight chain is a degenerate case for most two-bone solvers, so the legs start slightly bent (as every walking pose does).
	for side in sides:
		sk.set_bone_pose_rotation(sk.find_bone(side + "UpperLeg"), Quaternion.from_euler(Vector3(0.25, 0.0, 0.0)))
		sk.set_bone_pose_rotation(sk.find_bone(side + "LowerLeg"), Quaternion.from_euler(Vector3(-0.5, 0.0, 0.0)))

	for _i in range(6):
		await process_frame

	print("dbg seen ", seen)
	print("dbg root ", ik.get_root_bone_name(0), " ", ik.get_root_bone(0), " mid ", ik.get_middle_bone(0), " end ", ik.get_end_bone(0), " target ", ik.get_target_node(0), " resolved ", ik.get_node_or_null(ik.get_target_node(0)), " active ", ik.active, " influence ", ik.influence, " mode ", sk.modifier_callback_mode_process)
	for i in range(2):
		var foot: Vector3 = sk.global_transform * (seen[sides[i] + "Foot"] as Vector3)
		var want: Vector3 = (rig.get_node("Target" + sides[i]) as Node3D).global_position
		_check(foot.distance_to(want) < 0.02, "%s foot reaches its target (distance %.3f m, wanted height %.2f, got %.2f)" % [sides[i], foot.distance_to(want), want.y, foot.y])

	var knee_l: Vector3 = seen["LeftLowerLeg"]
	var hip_l: Vector3 = seen["LeftUpperLeg"]
	var foot_l: Vector3 = seen["LeftFoot"]
	_check(knee_l.z < (hip_l.z + foot_l.z) * 0.5 - 0.005, "the lifted leg's knee bends forward (knee z %.3f, hip-foot middle %.3f)" % [knee_l.z, (hip_l.z + foot_l.z) * 0.5])
	print("fails: ", _fails)
	quit(1 if _fails > 0 else 0)


func _check(ok: bool, what: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + what)

	if not ok:
		_fails += 1
