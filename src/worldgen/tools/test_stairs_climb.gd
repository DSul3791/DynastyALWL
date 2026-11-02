extends SceneTree

# Can the player walk up Kathleen's wooden stairs with the existing step-up logic (Sal and the moderator asked, 31 Oct 2026)? The real model (piece_look.gd stairs(): ten treads of
# 0.24 m rise and 0.24 m run, 0.9 m wide, stepped solid blocks, foot at z +1.2, top at z -1.2) on a flat floor, a capsule body like the player's, walking straight at it and slightly off
# centre at walking pace, with data/movement.json step_up_m; then walking back down. Passes when the body ends on the top tread (y about 2.4 m) and comes back to the floor.
#   godot --headless --path . --script res://src/worldgen/tools/test_stairs_climb.gd

const StepUp := preload("res://src/client/step_up.gd")
const PieceLook := preload("res://src/client/piece_look.gd")

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("ok   " if ok else "FAIL ") + text)

	if not ok:
		failures += 1


func _initialize() -> void:
	var step_limit: float = float(JSON.parse_string(FileAccess.get_file_as_string("res://data/movement.json"))["step_up_m"])
	var root_node: Node3D = Node3D.new()
	root.add_child.call_deferred(root_node)
	await process_frame
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(60.0, 1.0, 60.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	root_node.add_child(floor_body)
	var stairs: Node3D = PieceLook.stairs()
	root_node.add_child(stairs)
	# A landing at the top so the walker has somewhere to stand once up (a floor piece at 2.4 m).
	var landing: StaticBody3D = StaticBody3D.new()
	var landing_shape: CollisionShape3D = CollisionShape3D.new()
	var landing_box: BoxShape3D = BoxShape3D.new()
	landing_box.size = Vector3(3.0, 0.2, 3.0)
	landing_shape.shape = landing_box
	landing.add_child(landing_shape)
	landing.position = Vector3(0.0, 2.3, -2.7)
	root_node.add_child(landing)
	var body: CharacterBody3D = CharacterBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	body.wall_min_slide_angle = 0.0
	root_node.add_child(body)
	body.global_position = Vector3(0.05, 0.95, 3.5)
	await physics_frame
	await physics_frame
	await physics_frame
	var delta: float = 1.0 / 60.0
	var best_y: float = 0.0

	# Walk north (-z) into the foot of the stairs at walking pace (about 3 m/s).
	for i in 360:
		body.velocity = Vector3(0.0, body.velocity.y - 20.0 * delta, -3.0)
		StepUp.try(body, Vector3(body.velocity.x, 0.0, body.velocity.z) * delta, step_limit) if body.is_on_floor() else 0.0
		body.move_and_slide()
		best_y = maxf(best_y, body.global_position.y)
		await physics_frame

	print("stairs: step_up_m %.2f, highest feet y reached %.2f (the walker went on over the landing and off its far edge)" % [step_limit, best_y - 0.9])
	_check(step_limit >= 0.24, "the step-up limit (%.2f m) is above the riser (0.24 m)" % step_limit)
	_check(best_y - 0.9 > 2.2, "the walker climbed the flight and stood at the top (highest feet y %.2f of 2.4)" % (best_y - 0.9))

	# The game walking pace (terrain_client.gd WALK_SPEED 1.4 m/s; the jog is 3.2, the first leg above uses 3.0).
	body.global_position = Vector3(0.05, 0.95, 3.5)
	body.velocity = Vector3.ZERO
	best_y = 0.0

	for i in 900:
		body.velocity = Vector3(0.0, body.velocity.y - 20.0 * delta, -1.4)
		StepUp.try(body, Vector3(body.velocity.x, 0.0, body.velocity.z) * delta, step_limit) if body.is_on_floor() else 0.0
		body.move_and_slide()
		best_y = maxf(best_y, body.global_position.y)
		await physics_frame

	_check(best_y - 0.9 > 2.2, "an ordinary walker at the 1.4 m/s walking pace climbs it too (highest feet y %.2f)" % (best_y - 0.9))
	print("stairs climb: %d failures" % failures)
	quit(1 if failures > 0 else 0)
