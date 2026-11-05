extends SceneTree

# Dave 4 Nov 2026 ("these rocks are floating in the air above a cave opening"): pebbles, litter and grass laid on the coarse ground collision that comes
# first while the ground loads hung in the air once the fine ground arrived. A grass cell now casts a few of its ground hits again later and is built
# again where the ground moved (grass_view.gd _check_ground). This checks the test behind it, GrassView.ground_moved, on a box of ground.
#   godot --headless --path . --script res://src/worldgen/tools/test_grass_ground_check.gd

const GrassView := preload("res://src/client/grass_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _ground(top: float) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(20.0, 2.0, 20.0)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0.0, top - 1.0, 0.0)
	return body


func _initialize() -> void:
	_run()


func _run() -> void:
	var world: Node3D = Node3D.new()
	get_root().add_child(world)
	var ground: StaticBody3D = _ground(10.0)
	world.add_child(ground)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	check(not GrassView.ground_moved(space, 1.0, 1.0, 10.0), "ground where the cell found it: not moved")
	check(not GrassView.ground_moved(space, 1.0, 1.0, 10.2), "a hit within a few cm: not moved")
	# The coarse ground the cell was laid on (10 m) gives way to the fine ground 3 m lower (a cave mouth carved in).
	ground.position.y = 7.0 - 1.0
	await physics_frame
	await physics_frame
	check(GrassView.ground_moved(space, 1.0, 1.0, 10.0), "the ground dropped 3 m: moved")
	# The fine ground came in higher than the coarse one (the ray starts inside it, so it finds nothing).
	ground.position.y = 14.0 - 1.0
	await physics_frame
	await physics_frame
	check(GrassView.ground_moved(space, 1.0, 1.0, 10.0), "the ground rose 4 m: moved")
	ground.position.y = 10.0 - 1.0
	var trunk: StaticBody3D = _ground(11.5)
	trunk.set_meta("species_ids", [1])
	world.add_child(trunk)
	await physics_frame
	await physics_frame
	check(not GrassView.ground_moved(space, 1.0, 1.0, 10.0), "a tree trunk in the way says nothing about the ground")
	trunk.queue_free()
	ground.queue_free()
	await physics_frame
	await physics_frame
	check(GrassView.ground_moved(space, 1.0, 1.0, 10.0), "the ground is gone: moved")
	print("grass ground check: %d failures" % failures)
	quit(1 if failures > 0 else 0)
