extends SceneTree

# A hand closed on what it holds (BugsList 177, dynasty_grip.gd): Dave's body has no finger bones, so while a hand mount holds something drawn the hand bone
# is drawn shorter along the hand and a little thicker, the mount is scaled back so the tool keeps its size and turn, and the old ball fist is not drawn;
# with nothing held the hand opens again. A body without the modifier keeps the ball.
#   godot --headless --path . --script res://src/worldgen/tools/test_hand_grip.gd

const Grip := preload("res://src/client/character/dynasty_grip.gd")
const HeldItem := preload("res://src/client/held_item.gd")
const MyCharacter := preload("res://src/client/character/my_character.gd")
const DynastyBodyScript := preload("res://src/client/character/dynasty_body.gd")
const Generator := preload("res://src/client/character/body_generator.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _initialize() -> void:
	# The scale alone: open is the hand as drawn; closed is shorter along the hand and thicker through the palm, the third axis untouched.
	check(Grip.closed_scale(0.0, 1, 2).is_equal_approx(Vector3.ONE), "an open hand is drawn as it is")
	var shut: Vector3 = Grip.closed_scale(1.0, 1, 2)
	check(is_equal_approx(shut.y, Grip.CLOSED_LENGTH) and is_equal_approx(shut.z, Grip.CLOSED_THICK) and is_equal_approx(shut.x, 1.0), "a closed hand is shorter along it and thicker through the palm (%s)" % str(shut))

	# A mount with nothing on it holds nothing; a hidden tool neither.
	var mount: Marker3D = Marker3D.new()
	root.add_child(mount)
	check(not Grip.holds(mount), "an empty hand holds nothing")
	var thing: Node3D = Node3D.new()
	mount.add_child(thing)
	check(not Grip.holds(mount), "a thing carried in the palm (no grip fist on it, a kit) is not gripped")
	HeldItem.third_fist_on(thing, Color.WHITE)
	check(Grip.holds(mount), "a tool with its grip fist on it is gripped")
	thing.visible = false
	check(not Grip.holds(mount), "a hidden tool is not held")
	mount.queue_free()

	# A ball fist on a model whose holder has no Grip modifier stays a ball.
	var bare: Node3D = Node3D.new()
	var bare_mount: Marker3D = Marker3D.new()
	bare.add_child(bare_mount)
	root.add_child(bare)
	var stick: Node3D = Node3D.new()
	bare_mount.add_child(stick)
	check(HeldItem.third_fist_on(stick, Color.WHITE).mesh != null, "a body without its own closing hand keeps the ball fist")
	bare.queue_free()

	if not DynastyBodyScript.available():
		print("test_hand_grip: Dave's body is not imported here; the body checks are skipped")
		_done()
		return

	var avatar: Node3D = MyCharacter.make_avatar()
	var g: Dictionary = Generator.make_genome()
	g["hands"] = 1.0    # big hands on short arms: the hand bone's own scale (hands / arms) differs from the grip's, so the test can tell them apart
	g["arms"] = -1.0
	root.add_child(avatar)
	avatar.call("set_proportions", g)

	for _i in 3:
		await process_frame   # the first skeleton updates have run: the open hand is drawn
	var hand_mount: Marker3D = avatar.get("hand_mount_r")
	var wrist: Node3D = hand_mount.get_parent() as Node3D   # the BoneAttachment3D on the hand bone: it sits at the wrist and follows the drawn (modified) pose
	var grip: Node = avatar.get("grip")
	check(grip != null, "the body has its Grip modifier")

	if grip == null:
		_done()
		return

	check(int(grip._axes[0]) >= 0 and int(grip._thick[0]) >= 0 and int(grip._thick[0]) != int(grip._axes[0]), "the hand's length and palm axes are two different axes (%d, %d)" % [int(grip._axes[0]), int(grip._thick[0])])
	var left_mount: Marker3D = avatar.get("hand_mount_l")
	var left_wrist: Node3D = left_mount.get_parent() as Node3D
	var left_open: float = left_mount.global_position.distance_to(left_wrist.global_position)
	var open_scale: float = hand_mount.global_basis.get_scale().x
	var open_grip: float = hand_mount.global_position.distance_to(wrist.global_position)
	var skeleton: Skeleton3D = avatar.get("skeleton")
	var fore_at: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(skeleton.find_bone("mixamorig_RightForeArm"))).origin
	var along: Vector3 = (wrist.global_position - fore_at).normalized()
	var fingers: Vector3 = -hand_mount.global_basis.z.normalized()
	print("open hand: grip %.3f m from the wrist, the mount's fingers %.2f along the forearm, hand scale %.3f" % [open_grip, fingers.dot(along), float(avatar.call("hand_scale"))])
	check(fingers.dot(along) > 0.9, "the open mount's -Z points down the hand from the forearm (%.2f)" % fingers.dot(along))
	check(open_grip > 0.07 and open_grip < 0.16, "the open grip is about GRIP_FROM_WRIST_M (0.11 m, times the hand slider) from the wrist: %.3f m" % open_grip)
	(hand_mount.get_parent() as BoneAttachment3D).on_skeleton_update()
	var early_open: Vector3 = hand_mount.global_basis.get_scale()   # read before the modifiers, as player_view.gd follow_hand does
	var tool: Node3D = HeldItem.look_tool_node("stone_knife")
	hand_mount.add_child(tool)
	HeldItem.third_hold(tool, "", "knife")
	var fist: MeshInstance3D = HeldItem.third_fist_on(tool, Color.WHITE)
	fist.visible = true
	check(fist.mesh == null, "on Dave's body the ball fist is not drawn: his own hand closes")

	for _i in 30:
		await process_frame

	var closed_grip: float = hand_mount.global_position.distance_to(wrist.global_position)
	check(closed_grip < open_grip * (Grip.CLOSED_LENGTH + 0.03) and closed_grip > open_grip * (Grip.CLOSED_LENGTH - 0.1), "holding a knife the hand is drawn a little shorter: the grip %.3f m from the wrist, open %.3f m" % [closed_grip, open_grip])
	# The fingers curl round the handle (27 Nov 2026): the finger bone turns CURL_DEG from the hand's line, toward the palm.
	var finger_bone: int = skeleton.find_bone("mixamorig_Right" + Grip.FINGERS_BONE)
	var body_mesh: MeshInstance3D = avatar.get("body_mesh")
	var bound: bool = false

	for b in range(body_mesh.skin.get_bind_count()):
		bound = bound or String(body_mesh.skin.get_bind_name(b)) == "mixamorig_Right" + Grip.FINGERS_BONE

	check(finger_bone >= 0 and bound, "each hand has a finger bone and the body's fingers are skinned to it (bone %d, bound %s)" % [finger_bone, str(bound)])
	var curl: float = _curl_deg(skeleton, finger_bone, int(grip._axes[0]))
	print("closed hand: the fingers turned %.0f degrees from the hand's line" % curl)
	check(absf(curl - Grip.CURL_DEG) < 15.0, "holding a knife the fingers curl %.0f degrees (want about %.0f)" % [curl, Grip.CURL_DEG])
	var held_scale: Vector3 = tool.global_basis.get_scale()
	check(absf(held_scale.x - open_scale) < 0.02 and absf(held_scale.y - open_scale) < 0.02 and absf(held_scale.z - open_scale) < 0.02, "and the knife keeps its size: its scale %s, open %.3f" % [str(held_scale), open_scale])
	# Read before the frame's modifiers ran (player_view.gd follow_hand moves the attachment to the clip's pose at once): the mount carries no hand scale there either.
	(hand_mount.get_parent() as BoneAttachment3D).on_skeleton_update()
	var early_scale: Vector3 = hand_mount.global_basis.get_scale()
	check(early_scale.distance_to(early_open) < 0.02, "read before the modifiers, the closed mount's scale %s is the open one's %s: a spear placed then is not squashed" % [str(early_scale), str(early_open)])
	tool.queue_free()

	# The left hand closes on a torch's grip the same way.
	var torch: Node3D = Node3D.new()
	left_mount.add_child(torch)
	HeldItem.third_fist_on(torch, Color.WHITE)

	for _i in 30:
		await process_frame

	var left_closed: float = left_mount.global_position.distance_to(left_wrist.global_position)
	check(left_closed < left_open * (Grip.CLOSED_LENGTH + 0.03), "the left hand closes too: its grip %.3f m from the wrist, open %.3f m" % [left_closed, left_open])
	torch.queue_free()

	for _i in 30:
		await process_frame

	var again: float = hand_mount.global_position.distance_to(wrist.global_position)
	check(absf(again - open_grip) < 0.005, "with nothing held the hand opens again: the grip %.3f m from the wrist, open %.3f m" % [again, open_grip])
	check(_curl_deg(skeleton, finger_bone, int(grip._axes[0])) < 3.0, "and the fingers straighten again (%.1f degrees)" % _curl_deg(skeleton, finger_bone, int(grip._axes[0])))
	avatar.queue_free()
	_done()


# How far the finger bone's line along the hand is turned from the hand's own (degrees).
func _curl_deg(skeleton: Skeleton3D, finger_bone: int, axis: int) -> float:
	if finger_bone < 0 or axis < 0:
		return -1.0

	var hand: int = skeleton.get_bone_parent(finger_bone)
	var local: Vector3 = Vector3.ZERO
	local[axis] = 1.0
	var a: Vector3 = (skeleton.get_bone_global_pose(hand).basis * local).normalized()
	var b: Vector3 = (skeleton.get_bone_global_pose(finger_bone).basis * local).normalized()
	return rad_to_deg(a.angle_to(b))


func _done() -> void:
	print("test_hand_grip: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
