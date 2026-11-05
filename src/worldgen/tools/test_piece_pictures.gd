extends SceneTree

# The building material pictures and the trodden-path picture (piece_look.gd) are drawn on a worker while the world loads (PieceLook.prewarm, called from the
# inventory view's prewarm): drawn on the main thread they took about 170 ms at the first hoe stroke or building piece (Steve, lag run 4 Nov 2026). Checks: after
# the prewarm, making the materials, the tier materials and a trodden path draws nothing on the main thread; every prewarmed picture is the same, pixel for pixel,
# as one drawn where it is asked for (the worker draws the same pictures); a picture not in the list is still drawn where it is asked for.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_piece_pictures.gd
const PieceLook := preload("res://src/client/piece_look.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


func _init() -> void:
	PieceLook.prewarm()
	var waited: int = 0

	while not PieceLook.prewarm_done() and waited < 600:
		await process_frame
		waited += 1

	_check(PieceLook.prewarm_done(), "the worker finishes (%d frames)" % waited)
	var t0: int = Time.get_ticks_usec()
	PieceLook._materials()
	PieceLook._tier_materials()
	var path: Node3D = PieceLook.trodden_path()
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	_check(PieceLook.drawn_here == 0, "nothing drawn on the main thread after the prewarm (%d drawn here)" % PieceLook.drawn_here)
	print("piece pictures: materials, tier materials and a path in %.1f ms after the prewarm" % ms)
	_check((path.get_child(0) as Decal).texture_albedo != null, "the path decal has its picture")

	for spec in PieceLook.PREWARM:
		var made: Image = PieceLook._draw(str(spec[0]), spec[1])
		var fresh: Image = PieceLook._picture(str(spec[0]), spec[1])
		_check(made != null and fresh != null and made.get_data() == fresh.get_data(), "%s %s is the same as one drawn here" % [spec[0], var_to_str(spec[1])])

	var before: int = PieceLook.drawn_here
	PieceLook._draw("blocks", [Color(0.2, 0.2, 0.2), 3, 999, 0.1])
	_check(PieceLook.drawn_here == before + 1, "a picture not in the list is drawn where it is asked for")
	path.free()
	print("piece pictures: %d failures" % _fails)
	quit(1 if _fails > 0 else 0)
