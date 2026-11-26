extends SceneTree

# The game's clips of Dave's body (dynasty_body.gd _build_animations) are made once per run. In the game's window the first body hands that to a worker thread
# (Lane A Low route, 26 Nov 2026: 143 clips took 276 ms on the main thread in the join's first-body frame). Checks, with clips_on_worker on as the game client
# sets it: making the first body does not wait (it has no game clip yet and plays nothing), a second body made meanwhile starts no second worker, a play()
# meanwhile is no error; a few frames later both wear the one shared library, with the same clips, tracks and keys as the clips made at once on the main
# thread (clips_on_worker off, as headless runs, tools and menus make them).
# Run: godot --headless --path . --script res://src/worldgen/tools/test_dynasty_clips_worker.gd
const Body := preload("res://src/client/character/dynasty_body.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


# The clip's tracks (path and type) and each track's key count and last key value, as text: two libraries made the two ways must agree on every clip.
func _sign(anim: Animation) -> String:
	var parts: PackedStringArray = PackedStringArray(["%.4f %d" % [anim.length, anim.loop_mode]])

	for t in range(anim.get_track_count()):
		var n: int = anim.track_get_key_count(t)
		parts.append("%s %d %d %s" % [anim.track_get_path(t), anim.track_get_type(t), n, str(anim.track_get_key_value(t, n - 1)) if n > 0 else "-"])

	return "|".join(parts)


func _init() -> void:
	if not Body.available():
		print("dynasty clips worker: the body glb is not imported; skipped")
		quit(0)
		return

	Body.clips_on_worker = false
	var made_here: Node3D = Body.new()
	var here: AnimationLibrary = made_here.animation_player.get_animation_library("")
	_check(here != null and here.has_animation("walk"), "clips made on the main thread at once (clips_on_worker off)")
	made_here.free()
	Body._libraries.clear()   # as at the join: no body of this model made yet this run

	# Every pool thread sleeps for a moment first, so the clip worker is still queued when the second body is made (as at the join, where the ground and the
	# loaders keep the pool busy).
	var sleepers: Array = []

	for i in range(OS.get_processor_count()):
		sleepers.append(WorkerThreadPool.add_task(func() -> void: OS.delay_msec(800), true, "test sleeper"))   # high priority, as the clip worker is: they hold the threads it would take

	Body.clips_on_worker = true
	var t0: int = Time.get_ticks_msec()
	var first: Node3D = Body.new()
	var took: int = Time.get_ticks_msec() - t0
	get_root().add_child(first)
	var second: Node3D = Body.new()
	get_root().add_child(second)
	_check(took < 400, "making the first body did not wait for its clips (%d ms; the sleepers hold the worker 800 ms)" % took)
	_check(not first.animation_player.has_animation("walk") and not first.animation_player.is_playing(), "meanwhile it has no game clip and plays nothing")
	_check(Body._library_jobs.size() == 1, "a body made meanwhile starts no second worker (%d)" % Body._library_jobs.size())
	first.play("walk")
	_check(first.current() == "", "a play() meanwhile does nothing")

	for task in sleepers:
		WorkerThreadPool.wait_for_task_completion(task)

	var waited: int = 0
	var deadline: int = Time.get_ticks_msec() + 20000   # a time limit, not a frame count: a loaded lane machine runs fewer frames

	while Time.get_ticks_msec() < deadline and (first.get("_clips_later") or second.get("_clips_later")):
		await process_frame
		waited += 1

	var worn: AnimationLibrary = first.animation_player.get_animation_library("") if first.animation_player.has_animation_library("") else null
	_check(worn != null and worn.has_animation("walk"), "the body wears the game's clips once the worker is done (%d frames)" % waited)
	_check(second.animation_player.has_animation_library("") and second.animation_player.get_animation_library("") == worn, "the second body wears the same shared library")
	_check(Body._library_jobs.is_empty() and Body.clips_ready(first.model), "the worker is taken and gone")
	_check(first.current() == "idle", "it stands in the idle once its clips are on (%s)" % first.current())
	_check(not first.is_processing() or bool(first.get("_widths_later")) or bool(first.get("_shells_later")), "it stops processing once its clips are on (unless shapes or layers still wait)")

	if worn != null:
		var names_here: Array = Array(here.get_animation_list())
		var names_worn: Array = Array(worn.get_animation_list())
		names_here.sort()
		names_worn.sort()
		_check(names_here == names_worn, "the same %d clips both ways (worker %d)" % [names_here.size(), names_worn.size()])
		var differ: Array = []

		for clip in names_here:
			if worn.has_animation(clip) and _sign(here.get_animation(clip)) != _sign(worn.get_animation(clip)):
				differ.append(clip)

		_check(differ.is_empty(), "every clip has the same tracks and keys both ways (differ: %s)" % str(differ.slice(0, 8)))

	var third: Node3D = Body.new()
	_check(third.animation_player.has_animation("walk") and not bool(third.get("_clips_later")), "a body made after the worker is done wears its clips at once")
	third.free()
	Body.clips_on_worker = false
	first.queue_free()
	second.queue_free()
	await process_frame
	print("dynasty clips worker: %d failures" % _fails)
	quit(1 if _fails > 0 else 0)
