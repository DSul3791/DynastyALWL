extends SceneTree

# A hand closed on what it holds (BugsList 177, dynasty_grip.gd): Dave's body has no finger bones, so while a hand mount holds something drawn the hand bone
# is drawn shorter along the hand and a little thicker, the mount is scaled back so the tool keeps its size and turn, and the old ball fist is not drawn;
# with nothing held the hand opens again. A body without the modifier keeps the ball.
#   godot --headless --path . --script res://src/worldgen/tools/test_hand_grip.gd

const Grip := preload("res://src/client/character/dynasty_grip.gd")
const HeldItem := preload("res://src/client/held_item.gd")
const MyCharacter := preload("res://src/client/character/my_character.gd")
const DynastyBodyScript := preload("res://src/client/character/dynasty_body.gd")

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
	check(Grip.holds(mount), "a hand with a tool on it holds it")
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
	root.add_child(avatar)
	await process_frame
	var hand_mount: Marker3D = avatar.get("hand_mount_r")
	var wrist: Node3D = hand_mount.get_parent() as Node3D   # the BoneAttachment3D on the hand bone: it sits at the wrist and follows the drawn (modified) pose
	var grip: Node = avatar.get("grip")
	check(grip != null, "the body has its Grip modifier")
	var open_scale: float = hand_mount.global_basis.get_scale().x
	var open_grip: float = hand_mount.global_position.distance_to(wrist.global_position)
	var tool: Node3D = HeldItem.look_tool_node("stone_knife")
	hand_mount.add_child(tool)
	HeldItem.third_hold(tool, "", "knife")
	var fist: MeshInstance3D = HeldItem.third_fist_on(tool, Color.WHITE)
	fist.visible = true
	check(fist.mesh == null, "on Dave's body the ball fist is not drawn: his own hand closes")

	for _i in 30:
		await process_frame

	var closed_grip: float = hand_mount.global_position.distance_to(wrist.global_position)
	check(closed_grip < open_grip * 0.7 and closed_grip > open_grip * 0.4, "holding a knife the hand is drawn shorter: the grip %.3f m from the wrist, open %.3f m" % [closed_grip, open_grip])
	var held_scale: Vector3 = hand_mount.global_basis.get_scale()
	check(absf(held_scale.x - open_scale) < 0.02 and absf(held_scale.y - open_scale) < 0.02 and absf(held_scale.z - open_scale) < 0.02, "and the knife keeps its size: the mount's scale %s, open %.3f" % [str(held_scale), open_scale])
	tool.queue_free()

	for _i in 30:
		await process_frame

	var again: float = hand_mount.global_position.distance_to(wrist.global_position)
	check(absf(again - open_grip) < 0.005, "with nothing held the hand opens again: the grip %.3f m from the wrist, open %.3f m" % [again, open_grip])
	avatar.queue_free()
	_done()


func _done() -> void:
	print("test_hand_grip: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
