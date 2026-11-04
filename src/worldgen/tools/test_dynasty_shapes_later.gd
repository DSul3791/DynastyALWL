extends SceneTree

# The width and face shapes of Dave's body are made once per run on a worker (dynasty_shapes.gd). A body made while that worker runs (the player's own body at the join)
# used to wait for it on the main thread: 1 to 6 s with nothing drawn (Steve, lag run 4 Nov 2026). Checks: making that body does not wait (Shapes.ready is false right
# after it, and it wears the plain mesh); a few frames later the worker is done and the body has the shared shaped mesh, with its sliders as blend shape weights and its
# skin colour still on; a body made after that gets its shapes at once.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_dynasty_shapes_later.gd
const Body := preload("res://src/client/character/dynasty_body.gd")
const Shapes := preload("res://src/client/character/dynasty_shapes.gd")
const Generator := preload("res://src/client/character/body_generator.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


func _genome() -> Dictionary:
	var g: Dictionary = Generator.make_genome()
	g["build"] = 0.8
	g["jaw"] = -0.5
	return g


func _weight(body: Node3D, key: String) -> float:
	var i: int = (body.body_mesh as MeshInstance3D).find_blend_shape_by_name(key)
	return (body.body_mesh as MeshInstance3D).get_blend_shape_value(i) if i >= 0 else INF


func _init() -> void:
	if not Body.available():
		print("dynasty shapes later: the body glb is not imported; skipped")
		quit(0)
		return

	# Every pool thread sleeps for a moment first, so the shapes worker is still queued when the body asks for its shapes (as at the join, where the ground and
	# the loaders keep the pool busy). Without this a quiet machine finishes the worker before the body is even made.
	var sleepers: Array = []

	for i in range(OS.get_processor_count() * 2):
		sleepers.append(WorkerThreadPool.add_task(func() -> void: OS.delay_msec(800), false, "test sleeper"))

	var first: Node3D = Body.new()      # starts the shapes worker
	var t0: int = Time.get_ticks_msec()
	first.set_proportions(_genome())
	var took: int = Time.get_ticks_msec() - t0
	get_root().add_child(first)
	_check(not first.body_mesh.mesh.has_meta(Shapes.SHAPED_KEY), "the body made while the worker runs wears the plain mesh for now")
	_check(took < 400, "set_proportions did not wait for the worker (%d ms; the sleepers hold it 800 ms)" % took)

	for task in sleepers:
		WorkerThreadPool.wait_for_task_completion(task)

	var waited: int = 0

	while waited < 600 and not first.body_mesh.mesh.has_meta(Shapes.SHAPED_KEY):
		await process_frame
		waited += 1

	_check(first.body_mesh.mesh.has_meta(Shapes.SHAPED_KEY), "the body takes the shaped mesh once the worker is done (%d frames)" % waited)
	_check(absf(_weight(first, "build") - 0.8) < 0.001 and absf(_weight(first, "jaw") + 0.5) < 0.001, "its sliders are blend shape weights (build %.2f, jaw %.2f)" % [_weight(first, "build"), _weight(first, "jaw")])
	_check((first.body_mesh as MeshInstance3D).get_surface_override_material(0) != null, "its skin colour is put back on the new mesh")
	_check(not first.is_processing(), "it stops processing once shaped")

	var second: Node3D = Body.new()
	second.set_proportions(_genome())
	_check(second.body_mesh.mesh.has_meta(Shapes.SHAPED_KEY), "a body made after the worker is done is shaped at once")
	second.free()
	first.queue_free()
	await process_frame
	print("dynasty shapes later: %d failures" % _fails)
	quit(1 if _fails > 0 else 0)
