extends SceneTree

# Head tracking (head_look.gd, animal_view.look_strength; docs/design/ANIMAL_GAIT.md "Head tracking"): an animal's head turns toward
# the nearest player in range, held to its limits, never to one behind the shoulder; it eases there; a turned bone turns about its
# own joint whatever its parent's frame; and only a still animal on watch (or a calm one, nearer and less) looks.
#   godot --headless --path . --script res://src/worldgen/tools/test_head_look.gd

const HeadLook := preload("res://src/client/head_look.gd")
const AnimalViewScript := preload("res://src/client/animal_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.01


func _initialize() -> void:
	var at: Vector3 = Vector3(0.0, 1.0, 0.0)
	var facing: Basis = Basis.IDENTITY      # faces -Z

	var g: Vector3 = HeadLook.goal(at, facing, [Vector3(-5.0, 1.0, -5.0)], 30.0, 1.0)
	check(near(g.x, 1.0) and near(g.y, deg_to_rad(45.0)) and near(g.z, 0.0), "a player ahead and to the left: 45 degrees left, level")
	g = HeadLook.goal(at, facing, [Vector3(5.0, 1.0, -5.0)], 30.0, 1.0)
	check(near(g.y, deg_to_rad(-45.0)), "ahead and to the right: 45 degrees right")
	g = HeadLook.goal(at, facing, [Vector3(-10.0, 1.0, -1.0)], 30.0, 1.0)
	check(near(g.y, HeadLook.YAW_MAX), "nearly beside it: held to YAW_MAX")
	g = HeadLook.goal(at, facing, [Vector3(0.0, 1.0, 5.0)], 30.0, 1.0)
	check(g == Vector3.ZERO, "behind it: not watched")
	g = HeadLook.goal(at, facing, [Vector3(0.0, 1.0, -40.0)], 30.0, 1.0)
	check(g == Vector3.ZERO, "out of range: not watched")
	g = HeadLook.goal(at, facing, [Vector3(0.0, 4.0, -3.0)], 30.0, 1.0)
	check(near(g.z, HeadLook.PITCH_UP), "a player above: looks up, held to PITCH_UP")
	g = HeadLook.goal(at, facing, [Vector3(0.0, 1.0, -20.0), Vector3(-3.0, 1.0, -3.0)], 30.0, 0.6)
	check(near(g.x, 0.6) and near(g.y, deg_to_rad(45.0)), "the nearest of two players, at the given strength")
	var turned: Basis = Basis(Vector3.UP, deg_to_rad(90.0))      # faces -X
	g = HeadLook.goal(at, turned, [Vector3(-5.0, 1.0, 0.0)], 30.0, 1.0)
	check(near(g.y, 0.0), "the body's own frame: a turned animal looking straight ahead")

	var look = HeadLook.new()
	look.steer(Vector3(1.0, 1.0, 0.0), 0.1)
	check(near(look.weight, 0.25) and near(look.yaw, 0.3), "it eases: weight 2.5/s, turn 3 rad/s")
	look.steer(Vector3.ZERO, 0.1)
	check(near(look.weight, 0.0) and near(look.yaw, 0.3), "stopping: the weight fades, the angle stays")

	check(AnimalViewScript.look_strength(3, 0.0, false, false) == Vector2(1.0, AnimalViewScript.LOOK_WATCH_M), "alert: watches far")
	check(AnimalViewScript.look_strength(0, 0.0, false, false) == Vector2(AnimalViewScript.LOOK_CALM_STRENGTH, AnimalViewScript.LOOK_CALM_M), "grazing: watches near, less")
	check(AnimalViewScript.look_strength(3, 4.0, false, false) == Vector2.ZERO, "moving: looks where it goes")
	check(AnimalViewScript.look_strength(10, 0.0, true, false) == Vector2.ZERO, "a one-shot clip: its own head")
	check(AnimalViewScript.look_strength(7, 0.0, false, false) == Vector2.ZERO, "an attack: its own head")
	check(AnimalViewScript.look_strength(21, 0.0, false, true).x == 1.0 and AnimalViewScript.look_strength(21, 0.0, false, false) == Vector2.ZERO, "drinking: only when the head is up")

	# A bone turns about its own joint by the rotation given in the skeleton's frame, whatever its parent's frame.
	var sk: Skeleton3D = Skeleton3D.new()
	root.add_child(sk)
	await process_frame
	sk.add_bone("root")
	sk.add_bone("neck")
	sk.add_bone("head")
	sk.set_bone_parent(1, 0)
	sk.set_bone_parent(2, 1)
	sk.set_bone_pose_rotation(0, Quaternion(Vector3.RIGHT, deg_to_rad(-90.0)))
	sk.set_bone_pose_position(1, Vector3(0.0, 1.0, 0.0))
	sk.set_bone_pose_rotation(1, Quaternion(Vector3.FORWARD, deg_to_rad(30.0)))
	sk.set_bone_pose_position(2, Vector3(0.0, 0.5, 0.0))
	var before: Quaternion = sk.get_bone_global_pose(2).basis.get_rotation_quaternion()
	var joint: Vector3 = sk.get_bone_global_pose(2).origin
	var q: Quaternion = Quaternion(Vector3.UP, deg_to_rad(40.0))
	HeadLook._turn_bone(sk, 2, q)
	var after: Quaternion = sk.get_bone_global_pose(2).basis.get_rotation_quaternion()
	check(after.angle_to(q * before) < 0.01, "the head bone turned 40 degrees about up in the skeleton's frame (%.3f)" % after.angle_to(q * before))
	check(sk.get_bone_global_pose(2).origin.distance_to(joint) < 0.001, "its joint stayed where it was")

	sk.queue_free()
	look.free()
	print("test_head_look: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
