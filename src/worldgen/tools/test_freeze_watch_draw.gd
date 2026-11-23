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
	watch.stop()
	check(not RenderingServer.frame_pre_draw.is_connected(watch._on_pre_draw) and not RenderingServer.frame_post_draw.is_connected(watch._on_post_draw), "a stopped watch lets go of the renderer's signals")
	watch.start()
	watch.stop()
	check(not RenderingServer.frame_pre_draw.is_connected(watch._on_pre_draw), "a second start and stop leaves nothing connected")
	print("test_freeze_watch_draw: %d failures" % failures)
	quit(1 if failures > 0 else 0)
