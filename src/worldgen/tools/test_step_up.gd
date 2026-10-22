extends SceneTree

# Step-over test: a walker hops onto a low log (0.35 m) and is stopped by a wall (1.2 m) but slides along it.
# godot --headless --path . --script res://src/worldgen/tools/test_step_up.gd

const StepUp := preload("res://src/client/step_up.gd")

var failures: int = 0


func _check(ok: bool, text: String) -> void:
	print(("ok   " if ok else "FAIL ") + text)

	if not ok:
		failures += 1


func _initialize() -> void:
	var root_node: Node3D = Node3D.new()
	root.add_child.call_deferred(root_node)
	await process_frame
	_box(root_node, Vector3(0.0, -0.5, 0.0), Vector3(40.0, 1.0, 40.0))
	_box(root_node, Vector3(3.0, 0.175, 0.0), Vector3(0.6, 0.35, 6.0))     # a log lying across the way, 0.35 m
	_box(root_node, Vector3(-3.0, 0.6, 0.0), Vector3(0.6, 1.2, 40.0))      # a wall, 1.2 m
	var body: CharacterBody3D = CharacterBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.8
	shape.shape = capsule
	body.add_child(shape)
	body.wall_min_slide_angle = 0.0
	root_node.add_child(body)
	body.global_position = Vector3(1.0, 0.95, 0.0)
	await physics_frame
	await physics_frame
	await physics_frame
	var delta: float = 1.0 / 60.0

	# Walk east into the log at an angle (diagonal), 6 m/s.
	for i in 120:
		body.velocity = Vector3(6.0, body.velocity.y - 20.0 * delta, 2.0)
		StepUp.try(body, Vector3(body.velocity.x, 0.0, body.velocity.z) * delta, 0.5) if body.is_on_floor() else 0.0
		body.move_and_slide()
		await physics_frame

	_check(body.global_position.x > 4.5, "walks over a 0.35 m log (x %.2f)" % body.global_position.x)

	# Walk west into the 1.2 m wall at an angle: it is not climbed, the walker slides along it.
	body.global_position = Vector3(-1.0, 0.95, 0.0)
	body.velocity = Vector3.ZERO
	var z0: float = body.global_position.z

	for i in 120:
		body.velocity = Vector3(-6.0, body.velocity.y - 20.0 * delta, 2.0)
		StepUp.try(body, Vector3(body.velocity.x, 0.0, body.velocity.z) * delta, 0.5) if body.is_on_floor() else 0.0
		body.move_and_slide()
		await physics_frame

	_check(body.global_position.x > -2.5, "stopped by a 1.2 m wall (x %.2f)" % body.global_position.x)
	_check(body.global_position.y < 1.1, "did not climb the wall (y %.2f)" % body.global_position.y)
	_check(body.global_position.z - z0 > 2.0, "slid along the wall (z moved %.2f)" % (body.global_position.z - z0))
	print("step up: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _box(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var static_body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	static_body.add_child(shape)
	static_body.position = at
	parent.add_child(static_body)
