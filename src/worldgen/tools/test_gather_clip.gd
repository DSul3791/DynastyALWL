extends SceneTree

# E gathers with its own first-person arm clip (BACKLOG rank 5, was the generic "use"): the arms rig has a one-shot "gather" clip, and at its
# grab the arm reaches lower (less raised) with a straighter elbow than "use" does at its push, and the body leans in.
#   godot --headless --path . --script res://src/worldgen/tools/test_gather_clip.gd

const RagdollScript := preload("res://src/client/ragdoll_body.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var arms = RagdollScript.new(true)
	check(arms.animation_player.has_animation("gather"), "the arms have a gather clip")
	check(arms.animation_player.has_animation("use"), "the arms still have the use clip")

	if arms.animation_player.has_animation("gather"):
		check(arms.animation_player.get_animation("gather").loop_mode == Animation.LOOP_NONE, "gather plays once")

	var grab: Dictionary = arms._gather(0.5)
	var push: Dictionary = arms._use(0.5)
	check((grab["arm_r"] as Vector3).x < (push["arm_r"] as Vector3).x, "the grab reaches lower than the push (arm %.2f vs %.2f)" % [(grab["arm_r"] as Vector3).x, (push["arm_r"] as Vector3).x])
	check((grab["forearm_r"] as Vector3).x < (push["forearm_r"] as Vector3).x, "the elbow is straighter at the grab")
	check((grab["spine"] as Vector3).x < 0.0, "the body leans in to reach")
	check((arms._gather(0.75)["forearm_r"] as Vector3).x > 1.0, "the hand is drawn back to the chest after the grab")
	check((arms._gather(1.0)["arm_r"] as Vector3).is_equal_approx(arms._gather(0.0)["arm_r"]), "it ends where it began")
	arms.free()
	print("gather clip: %d failures" % failures)
	quit(1 if failures > 0 else 0)
