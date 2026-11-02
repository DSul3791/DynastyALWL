extends SceneTree

# PROTOTYPE (Sonny, 2026-10-30), plan 5: CPU cost of animating 20 generated bodies per frame, with an AnimationTree each and with a plain AnimationPlayer each.
#   godot --headless --path . --script res://tools/proto_motion_bench.gd
# Headless: this measures animation evaluation only (no drawing, no GPU skinning).

const Generator := preload("res://src/client/character/body_generator.gd")
const Motion := preload("res://src/client/character/motion_proto.gd")
const COUNT := 20
const FRAMES := 300


func _initialize() -> void:
	var rigs: Array = []

	for i in range(COUNT):
		var made: Dictionary = Generator.make_node(Generator.make_genome(["average", "broad", "lean", "stocky"][i % 4]), 0.06)
		var node: Node3D = made["node"]
		root.add_child(node)
		rigs.append({"skeleton": made["skeleton"], "parts": Motion.attach(node, made["skeleton"])})

	await process_frame
	await process_frame

	for r in rigs:
		((r["parts"] as Dictionary)["tree"] as AnimationTree)["parameters/Loco/blend_position"] = 1.4

	var t0: int = Time.get_ticks_usec()

	for _f in range(FRAMES):
		for r in rigs:
			((r["parts"] as Dictionary)["tree"] as AnimationTree).advance(1.0 / 60.0)

	var tree_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(FRAMES)

	for r in rigs:
		((r["parts"] as Dictionary)["tree"] as AnimationTree).active = false
		var player: AnimationPlayer = (r["parts"] as Dictionary)["player"]
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		player.play("walk")

	var t1: int = Time.get_ticks_usec()

	for _f in range(FRAMES):
		for r in rigs:
			((r["parts"] as Dictionary)["player"] as AnimationPlayer).advance(1.0 / 60.0)

	var player_ms: float = float(Time.get_ticks_usec() - t1) / 1000.0 / float(FRAMES)
	print("%d bodies, %d frames: AnimationTree %.3f ms per frame for all (%.3f ms each), AnimationPlayer %.3f ms per frame for all (%.3f ms each)" % [COUNT, FRAMES, tree_ms, tree_ms / COUNT, player_ms, player_ms / COUNT])
	quit()
