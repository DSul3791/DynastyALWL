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

	# Distance thinning (Dave 3 Nov 2026): far impostor trees are drawn at FAR_TREE_SHARE, chosen stably per tree id; near tiers are never thinned.
	var kept: int = 0

	for id in range(20000):
		kept += 1 if FloraView.far_tree_keep(id * 7 + 3, 0.6) else 0

	_check(absf(float(kept) / 20000.0 - 0.6) < 0.03, "about 60 percent of far trees stay at share 0.6 (%.1f percent)" % (100.0 * kept / 20000.0))
	_check(FloraView.far_tree_keep(12345, 0.6) == FloraView.far_tree_keep(12345, 0.6) and FloraView.far_tree_keep(999, 1.0), "the choice is stable per tree, and share 1 keeps every tree")
	_check(FloraView.FAR_TREE_SHARE.size() == FloraView.IMPOSTOR_M.size() and FloraView.FAR_TREE_SHARE[0] <= FloraView.FAR_TREE_SHARE[3], "a far-tree share for every quality, Low thinnest")
	view.free()
	print("flora close: %d failures" % failures)
	quit(1 if failures > 0 else 0)
