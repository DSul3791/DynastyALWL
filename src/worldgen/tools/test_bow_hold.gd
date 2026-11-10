extends SceneTree

# Dave 10 Nov 2026: "the bow is also too small ... resize it and have art department fix how its held because it isnt right". The bow is a self bow at the archer's
# height (basic_look.gd BOW_HALF_M), held in the LEFT hand at arm's length, the right hand drawing the string to the jaw (ragdoll_body.gd bow_draw, held_item.gd
# _pose_bow). This checks that the first-person arms at the camera pose put the hands where the pose was solved for, and that the string follows the nock point.
#   godot --headless --path . --script res://src/worldgen/tools/test_bow_hold.gd

const RagdollBody := preload("res://src/client/ragdoll_body.gd")
const HeldItem := preload("res://src/client/held_item.gd")
const BasicLook := preload("res://src/client/basic_look.gd")
const DynastyArms := preload("res://src/client/character/dynasty_arms.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# Where `side`'s closed fingers hold (dynasty_arms.gd GRIP_AT) in camera space, the arms at the camera pose (held_item.gd ARMS_POS, ARMS_PITCH_DEG, ARMS_SCALE).
func _grip_at(arms, side: String) -> Vector3:
	var rig: Transform3D = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(HeldItem.ARMS_PITCH_DEG)).scaled(Vector3.ONE * HeldItem.ARMS_SCALE), HeldItem.ARMS_POS)
	var skeleton: Skeleton3D = arms.skeleton
	var hand: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("hand_" + side))
	return rig * (hand * Vector3(DynastyArms.GRIP_AT[side]))


func _initialize() -> void:
	_run()


func _run() -> void:
	var arms = RagdollBody.new(true)
	get_root().add_child(arms)
	await process_frame
	var player: AnimationPlayer = arms.animation_player
	check(player.has_animation("bow_draw") and not player.has_animation("bow_idle"), "the arms have the bow clip (the first-person idle is bow_draw at 0, ready to shoot)")

	# The bow's plane runs through the eye (the string lies along the stave from the eye), the nock point 3 cm above the grip (ragdoll_body.gd BOW_ARM_L).
	for step in [[0.0, Vector3(-0.012, -0.070, -0.24)], [1.0, Vector3(-0.012, -0.070, -0.10)]]:
		player.play("bow_draw")
		player.seek(float(step[0]) * player.get_animation("bow_draw").length * 0.999, true)
		player.advance(0.0)
		await process_frame
		var left: Vector3 = _grip_at(arms, "l")
		var right: Vector3 = _grip_at(arms, "r")
		check(left.distance_to(Vector3(-0.018, -0.10, -0.40)) < 0.02, "draw %.0f: the left hand closed round the grip at arm's length (%.3f, %.3f, %.3f)" % [float(step[0]), left.x, left.y, left.z])
		check(right.distance_to(step[1]) < 0.02, "draw %.0f: the right hand's fingers on the string at (%.3f, %.3f, %.3f), wanted (%.3f, %.3f, %.3f)" % [float(step[0]), right.x, right.y, right.z, step[1].x, step[1].y, step[1].z])
		var plane: Vector3 = Vector3(cos(deg_to_rad(HeldItem.BOW_CANT_DEG)), -sin(deg_to_rad(HeldItem.BOW_CANT_DEG)), 0.0)   # the canted bow's plane through the eye
		check(absf(left.dot(plane)) < 0.01 and absf(right.dot(plane)) < 0.01, "draw %.0f: grip and string hand in the bow's plane through the eye (%.3f, %.3f)" % [float(step[0]), left.dot(plane), right.dot(plane)])

	# The grip shape (dynasty_arms.gd _grip_shape) on two points of a left hand: a finger point past the bend wraps round the bar at its own distance; the palm stays.
	var finger: Vector3 = Vector3(0.0, -0.15, 0.02)
	var palm: Vector3 = Vector3(0.0, -0.05, 0.02)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([finger, palm])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3(-1.0, 0.0, 0.0), Vector3(-1.0, 0.0, 0.0)])
	arrays[Mesh.ARRAY_TANGENT] = PackedFloat32Array([0.0, -1.0, 0.0, 1.0, 0.0, -1.0, 0.0, 1.0])
	var shape: Array = DynastyArms._grip_shape(arrays, DynastyArms.GRIP_CURL["l"], Transform3D.IDENTITY)
	var bent: Vector3 = shape[Mesh.ARRAY_VERTEX][0]
	var bar: Vector3 = DynastyArms.GRIP_AT["l"]
	check(absf(Vector2(bent.x - bar.x, bent.y - bar.y).length() - 0.032) < 0.001 and bent.x > 0.02 and bent.y < bar.y, "a finger point wraps round the grip bar (%.3f, %.3f)" % [bent.x, bent.y])
	check(Vector3(shape[Mesh.ARRAY_VERTEX][1]) == palm, "the palm does not move")
	check(absf(Vector3(shape[Mesh.ARRAY_NORMAL][0]).length() - 1.0) < 0.001, "the bent normal stays a unit vector")

	# The string: two cords from the tips to the nock point.
	var bow: Node3D = Node3D.new()

	for cord_name in ["StringTop", "StringBottom"]:
		var cord: MeshInstance3D = MeshInstance3D.new()
		cord.name = cord_name
		bow.add_child(cord)

	get_root().add_child(bow)
	var nock: Vector3 = Vector3(0.0, 0.0, -0.4)
	HeldItem._set_bow_string(bow, nock)
	var top: MeshInstance3D = bow.get_node("StringTop")
	var top_tip: Vector3 = top.transform * Vector3(0.0, -0.5, 0.0)
	var top_nock: Vector3 = top.transform * Vector3(0.0, 0.5, 0.0)
	check(top_tip.distance_to(Vector3(BasicLook.BOW_HALF_M, 0.0, 0.0)) < 0.002 and top_nock.distance_to(nock) < 0.002, "the upper cord runs from the top nock to the nock point")
	var bottom: MeshInstance3D = bow.get_node("StringBottom")
	check((bottom.transform * Vector3(0.0, -0.5, 0.0)).distance_to(Vector3(-BasicLook.BOW_HALF_M, 0.0, 0.0)) < 0.002, "the lower cord starts at the bottom nock")
	check(bow.get_meta("nock") == nock, "the nock point is kept on the bow (meta nock)")
	# The nocked arrow: its nock end on the string, the shaft straight ahead (the bow's +z, the view's forward, so it points at the crosshair) along the stave's left
	# side (mesh -y) (Dave 10 Nov 2026: "the bow and arrow should be adjusted so the arrow lines up with the crosshairs").
	var arrow: MeshInstance3D = MeshInstance3D.new()
	arrow.name = "NockedArrow"
	bow.add_child(arrow)
	var string_at: Vector3 = Vector3(HeldItem.BOW_NOCK_ABOVE_M, -HeldItem.BOW_ARROW_SIDE_M, -0.3)
	HeldItem._place_nocked_arrow(bow, string_at, true)
	var arrow_nock: Vector3 = arrow.transform * Vector3(-HeldItem.ARROW_NOCK_M, 0.0, 0.0)
	var arrow_dir: Vector3 = arrow.transform.basis.x.normalized()
	var at_grip: Vector3 = arrow_nock + arrow_dir * ((BasicLook.BOW_BRACE_M - arrow_nock.z) / arrow_dir.z)
	check(arrow.visible and arrow_nock.distance_to(string_at) < 0.002, "the arrow's nock sits on the string")
	check(arrow_dir.distance_to(Vector3(0.0, 0.0, 1.0)) < 0.001, "the shaft points straight ahead, at the crosshair")
	check(at_grip.y < -0.003 and at_grip.y > -0.01 and absf(at_grip.x - HeldItem.BOW_NOCK_ABOVE_M) < 0.002, "the shaft passes the grip on the bow's left side (%.3f)" % at_grip.y)
	HeldItem._place_nocked_arrow(bow, string_at, false)
	check(not arrow.visible, "no arrow in the pack: none on the string")

	print("test_bow_hold: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
