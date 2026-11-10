extends SceneTree

# Dave 10 Nov 2026: "the bow is also too small ... resize it and have art department fix how its held because it isnt right". The bow is a self bow at the archer's
# height (basic_look.gd BOW_HALF_M), held in the LEFT hand at arm's length, the right hand drawing the string to the jaw (ragdoll_body.gd bow_draw, held_item.gd
# _pose_bow). This checks that the first-person arms at the camera pose put the hands where the pose was solved for, and that the string follows the nock point.
#   godot --headless --path . --script res://src/worldgen/tools/test_bow_hold.gd

const RagdollBody := preload("res://src/client/ragdoll_body.gd")
const HeldItem := preload("res://src/client/held_item.gd")
const BasicLook := preload("res://src/client/basic_look.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# The hand mount of `side` in camera space, the arms at the camera pose (held_item.gd ARMS_POS, ARMS_PITCH_DEG, ARMS_SCALE).
func _mount_at(arms, side: String) -> Vector3:
	var rig: Transform3D = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(HeldItem.ARMS_PITCH_DEG)).scaled(Vector3.ONE * HeldItem.ARMS_SCALE), HeldItem.ARMS_POS)
	var skeleton: Skeleton3D = arms.skeleton
	var hand: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("hand_" + side))
	return rig * (hand * Vector3(0.0, -0.07, 0.0))


func _initialize() -> void:
	_run()


func _run() -> void:
	var arms = RagdollBody.new(true)
	get_root().add_child(arms)
	await process_frame
	var player: AnimationPlayer = arms.animation_player
	check(player.has_animation("bow_idle") and player.has_animation("bow_draw"), "the arms have the bow clips")

	for step in [[0.0, Vector3(0.015, -0.10, -0.24)], [1.0, Vector3(0.015, -0.10, -0.10)]]:
		player.play("bow_draw")
		player.seek(float(step[0]) * player.get_animation("bow_draw").length * 0.999, true)
		player.advance(0.0)
		await process_frame
		var left: Vector3 = _mount_at(arms, "l")
		var right: Vector3 = _mount_at(arms, "r")
		check(left.distance_to(Vector3(0.015, -0.10, -0.40)) < 0.04, "draw %.0f: the left hand on the grip at arm's length (%.2f, %.2f, %.2f)" % [float(step[0]), left.x, left.y, left.z])
		check(right.distance_to(step[1]) < 0.04 and absf(right.x - left.x) < 0.03 and absf(right.y - left.y) < 0.03, "draw %.0f: the right hand at (%.2f, %.2f, %.2f), wanted (%.2f, %.2f, %.2f)" % [float(step[0]), right.x, right.y, right.z, step[1].x, step[1].y, step[1].z])

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
	# The nocked arrow: its nock end on the string, the shaft crossing the grip on the bow's left side (mesh -y), in line with the string (Dave 10 Nov 2026).
	var arrow: MeshInstance3D = MeshInstance3D.new()
	arrow.name = "NockedArrow"
	bow.add_child(arrow)
	var string_at: Vector3 = Vector3(HeldItem.BOW_NOCK_ABOVE_M, 0.0, -0.3)
	HeldItem._place_nocked_arrow(bow, string_at, true)
	var arrow_nock: Vector3 = arrow.transform * Vector3(-HeldItem.ARROW_NOCK_M, 0.0, 0.0)
	var arrow_dir: Vector3 = arrow.transform.basis.x.normalized()
	var at_grip: Vector3 = arrow_nock + arrow_dir * ((BasicLook.BOW_BRACE_M - arrow_nock.z) / arrow_dir.z)
	check(arrow.visible and arrow_nock.distance_to(string_at) < 0.002, "the arrow's nock sits on the string")
	check(at_grip.y < -0.01 and at_grip.y > -0.03 and absf(at_grip.x - HeldItem.BOW_NOCK_ABOVE_M) < 0.002, "the shaft crosses the grip on the bow's left side (%.3f)" % at_grip.y)
	HeldItem._place_nocked_arrow(bow, string_at, false)
	check(not arrow.visible, "no arrow in the pack: none on the string")

	print("test_bow_hold: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
