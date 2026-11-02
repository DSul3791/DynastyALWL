extends SceneTree
# Headless check of the flora load order (Dave, 2 Nov 2026: loading far too slow after a flight): finished chunk drawings are put in the scene nearest
# first (a drawing already begun is finished first), and no more than MAX_PLAN_TASKS chunk plans run at once.

const FloraView := preload("res://src/flora/flora_view.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _job(chunk: Vector2i, draw: int = 0) -> Dictionary:
	return {"chunk": chunk, "draw": draw, "shape": 0}


func _init() -> void:
	var view = FloraView.new()
	view.chunk_m = 256.0
	view._last_position = Vector3(10.0, 0.0, 10.0)
	view._jobs = [_job(Vector2i(5, 5)), _job(Vector2i(3, 0)), _job(Vector2i(0, 0)), _job(Vector2i(1, 1))]
	view._nearest_job_first()
	_check(view._jobs[0]["chunk"] == Vector2i(0, 0), "the chunk under the player is drawn first")
	_check(view._jobs.size() == 4, "no drawing is lost by the reorder")
	view._jobs = [_job(Vector2i(5, 5), 2), _job(Vector2i(0, 0))]
	view._nearest_job_first()
	_check(view._jobs[0]["chunk"] == Vector2i(5, 5), "a drawing already begun is finished first")
	view._tasks = []

	for k in range(view.MAX_PLAN_TASKS):
		view._tasks.append(-1)

	for k in range(10):
		view._plan_wait[Vector2i(k, 0)] = true

	view._launch_plans(view._last_position)
	_check(view._plan_wait.size() == 10 and view._tasks.size() == view.MAX_PLAN_TASKS, "with the task cap reached, no plan starts")
	view._tasks = []
	view._launch_plans(view._last_position)
	_check(view._plan_wait.is_empty(), "with room, waiting plans are taken off the wait list (chunks no longer held are skipped)")
	view.free()
	print("flora load order: %d failures" % failures)
	quit(1 if failures > 0 else 0)
