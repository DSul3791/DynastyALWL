extends SceneTree

# The freeze watch names the draw's own ends (Lane A, 23 Nov 2026: the join's 9 s frame was "stuck after held item" with no word whether the
# deferred calls, the draw or the physics step held it): after the draw starts the last piece is DRAW_START, after it ends DRAWN, and a
# stop lets go of the renderer's signals.
# A headless run never draws, so the handlers are called by hand here; a drawn client is where the signals come.
#   godot --headless --path . --script res://src/worldgen/tools/test_freeze_watch_draw.gd

const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var watch = FreezeWatchScript.new()
	watch.start()
	await process_frame
	# A headless run draws nothing (no window), so the renderer's signals never come: the watch's handlers are called as they would be.
	check(RenderingServer.frame_pre_draw.is_connected(watch._on_pre_draw) and RenderingServer.frame_post_draw.is_connected(watch._on_post_draw), "a started watch listens for the draw's start and end")
	FreezeWatchScript.note("a piece")
	watch._on_pre_draw()
	check(FreezeWatchScript._last_piece == FreezeWatchScript.DRAW_START, "at the draw's start the last piece is the draw start (%s)" % FreezeWatchScript._last_piece)
	watch._on_post_draw()
	check(FreezeWatchScript._last_piece == FreezeWatchScript.DRAWN, "after the draw the last piece is drawn (%s)" % FreezeWatchScript._last_piece)
	# The wall split of a frame (PR #1935): stamps set by hand, beat() reads them.
	FreezeWatchScript.physics_mark()
	check(FreezeWatchScript._last_piece == FreezeWatchScript.PHYSICS_STEP, "the last physics callback names the physics step (%s)" % FreezeWatchScript._last_piece)
	var now: int = Time.get_ticks_usec()
	FreezeWatchScript._beat_usec = now - 100000
	FreezeWatchScript._pre_usec = now - 90000
	FreezeWatchScript._post_usec = now - 60000
	FreezeWatchScript._phys_usec = now - 20000
	FreezeWatchScript.beat()
	check(FreezeWatchScript.split.begins_with("process 10, draw 30, present 40, physics step and poll 2"), "a drawn frame splits into its parts (%s)" % FreezeWatchScript.split)
	FreezeWatchScript._pre_usec = FreezeWatchScript._beat_usec - 5000   # no draw since that beat
	FreezeWatchScript.beat()
	check(FreezeWatchScript.split == "no draw", "a frame with no draw says so, not the last frame's split (%s)" % FreezeWatchScript.split)
	now = Time.get_ticks_usec()
	FreezeWatchScript._beat_usec = now - 50000
	FreezeWatchScript._pre_usec = now - 40000
	FreezeWatchScript._post_usec = now - 30000
	FreezeWatchScript._phys_usec = now - 70000   # no physics step in this frame: the whole rest is the present
	FreezeWatchScript.beat()
	check(FreezeWatchScript.split.ends_with("physics step and poll 0") and FreezeWatchScript.split.contains("present 3"), "a frame without a physics step puts the rest in the present (%s)" % FreezeWatchScript.split)
	watch.stop()
	check(not RenderingServer.frame_pre_draw.is_connected(watch._on_pre_draw) and not RenderingServer.frame_post_draw.is_connected(watch._on_post_draw), "a stopped watch lets go of the renderer's signals")
	watch.start()
	watch.stop()
	check(not RenderingServer.frame_pre_draw.is_connected(watch._on_pre_draw), "a second start and stop leaves nothing connected")
	print("test_freeze_watch_draw: %d failures" % failures)
	quit(1 if failures > 0 else 0)
