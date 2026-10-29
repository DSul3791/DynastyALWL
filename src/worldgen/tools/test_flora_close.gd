extends SceneTree
# Headless check of the per-species near distance masks in flora_view (_close_masks): which 32 m cells of a chunk are within a close distance.

const FloraView := preload("res://src/flora/flora_view.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var view = FloraView.new()
	view.chunk_m = 256.0
	_check(view._close_masks(Vector2i(0, 0), Vector3(10.0, 0.0, 10.0)).is_empty(), "no species asked for a near distance: no masks")
	view._close_ms[40.0] = true
	var here: Dictionary = view._close_masks(Vector2i(0, 0), Vector3(16.0, 0.0, 16.0))
	var mask: int = int(here.get(40.0, 0))
	_check((mask & 1) != 0 and (mask >> 1 & 1) != 0 and (mask >> 8 & 1) != 0, "the cell under the player and its neighbours within 40 m are set")
	_check((mask >> 7 & 1) == 0 and (mask >> 63 & 1) == 0, "cells farther than 40 m are not")
	_check(view._close_masks(Vector2i(5, 5), Vector3(16.0, 0.0, 16.0)).is_empty(), "a far chunk has no mask, so it is not redrawn as the player moves")
	view.free()
	print("flora close: %d failures" % failures)
	quit(1 if failures > 0 else 0)
