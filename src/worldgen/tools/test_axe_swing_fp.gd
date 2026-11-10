extends SceneTree

# Dave 10 Nov 2026: "in first person the axe swing when hitting a tree is still top to bottom and should be from right out of frame to left into the tree".
# The first-person swing_fp clip (ragdoll_body.gd) is a level, sideways stroke: this checks the right hand, with the arms at the camera pose, goes back far to the
# right, then sweeps leftward at one height (never up over the view) to the middle at the impact, and on past it to the left.
#   godot --headless --path . --script res://src/worldgen/tools/test_axe_swing_fp.gd

const RagdollBody := preload("res://src/client/ragdoll_body.gd")
const HeldItem := preload("res://src/client/held_item.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	_run()


func _run() -> void:
	var arms = RagdollBody.new(true)
	get_root().add_child(arms)
	await process_frame
	var player: AnimationPlayer = arms.animation_player
	var rig: Transform3D = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(HeldItem.ARMS_PITCH_DEG)).scaled(Vector3.ONE * HeldItem.ARMS_SCALE), HeldItem.ARMS_POS)
	var skeleton: Skeleton3D = arms.skeleton
	var at: Dictionary = {}

	# Start the clip once and let the player take it up (the first seek after play() can still show the previous clip), then sample each time with a seek
	# that applies at once, read straight away.
	player.play("swing_fp", 0.0)
	player.seek(0.0, true)
	player.advance(0.0)
	await process_frame
	await process_frame

	for t in [0.36, 0.44, 0.5, 0.7]:
		player.seek(t, true)
		player.advance(0.0)
		await process_frame
		player.seek(t, true)
		var hand: Transform3D = skeleton.get_bone_global_pose(skeleton.find_bone("hand_r"))
		at[t] = rig * (hand * Vector3(0.0, -0.07, 0.0))
		print("  %.2f s: right hand (%.2f, %.2f, %.2f)" % [t, at[t].x, at[t].y, at[t].z])

	check(at[0.36].x > 0.35 and at[0.36].z > -0.25, "wound back far to the right, beside the head, out of the view")
	check(at[0.36].x > at[0.44].x and at[0.44].x > at[0.5].x and at[0.5].x > at[0.7].x, "the stroke runs right to left")
	check(absf(at[0.5].x) < 0.2 and at[0.5].z < -0.3, "at the impact the hand is out in front, near the middle")
	var low: float = INF
	var high: float = -INF

	for t in at:
		low = minf(low, at[t].y)
		high = maxf(high, at[t].y)

	check(high < 0.0 and high - low < 0.1, "level: the hand stays below the eye and within 10 cm of one height (%.2f to %.2f)" % [low, high])
	print("test_axe_swing_fp: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
