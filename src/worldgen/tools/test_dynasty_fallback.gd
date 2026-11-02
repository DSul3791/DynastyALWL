extends SceneTree

# A fresh checkout must never end up bodiless (Kathleen, 1 Nov 2026): when Dave's glb cannot be used, the game still gets a body with an AnimationPlayer, mounts and a clip, the avatar
# driver and the first-person arms work with it, and nothing errors. Run: godot --headless --path . --script res://src/worldgen/tools/test_dynasty_fallback.gd
const MyCharacter := preload("res://src/client/character/my_character.gd")
const DynastyBody := preload("res://src/client/character/dynasty_body.gd")
const DynastyArms := preload("res://src/client/character/dynasty_arms.gd")
const AvatarDriver := preload("res://src/client/character/avatar_driver.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


func _init() -> void:
	DynastyBody.force_unavailable = true
	_check(not DynastyBody.available(), "forced: the glb counts as unavailable")

	# The body the game would wear.
	var avatar: Node3D = MyCharacter.make_avatar()
	root.add_child(avatar)
	_check(avatar.name != "DynastyBody", "falls back to the previous body, got " + str(avatar.name))
	_check(avatar.get("animation_player") != null, "the fallback body has an AnimationPlayer")
	_check(avatar.get("hand_mount_r") != null and avatar.get("hand_mount_l") != null, "the fallback body has hand mounts")
	avatar.call("play", "idle")
	_check(String(avatar.call("current")) == "idle", "the fallback body plays idle")
	_check(AvatarDriver.clip_for(avatar, 0, Vector3.ZERO, Basis.IDENTITY, true, 0.0, "idle", false, 0.016) != "", "the avatar driver picks a clip")
	_check(AvatarDriver.clip_for(avatar, 1, Vector3(0, 0, -1.0), Basis.IDENTITY, true, 1.0, "crouch", false, 0.016) != "", "the avatar driver picks a crouch clip")

	# The Dynasty body itself, built anyway (the last guard), has no nulls.
	var empty: Node3D = DynastyBody.new()
	root.add_child(empty)
	_check(empty.animation_player != null and empty.hand_mount_r != null and empty.head_mount != null and empty.skeleton != null and empty.body_mesh != null, "an unusable Dynasty body is still a full object")
	empty.play("idle")
	_check(String(empty.current()) == "", "it plays nothing, without an error")

	# The first-person arms keep the old arms.
	var arms: Node3D = DynastyArms.new()
	root.add_child(arms)
	_check(arms.animation_player != null and arms.hand_mount_r != null, "the arms rig is whole")
	_check(arms.body_mesh.visible, "the old tube arms stay visible")
	_check(not arms.has_meta("own_hands"), "the arms do not claim Dave's hands")

	DynastyBody.force_unavailable = false
	print("dynasty fallback tests: %d failures" % _fails)
	quit()
