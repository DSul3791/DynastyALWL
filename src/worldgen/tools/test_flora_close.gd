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

	# Distance thinning (Dave 3 Nov 2026, the grass rule in data/look/grass_far.json): full out to fade_start of the view distance, then down to far_share at the edge.
	_check(is_equal_approx(FloraView.far_share_at(100.0, 450.0, 0.5, 0.3), 1.0) and is_equal_approx(FloraView.far_share_at(225.0, 450.0, 0.5, 0.3), 1.0), "every tree is drawn out to half the view distance")
	var band: int = FloraView.far_band_of(100.0, -1)
	var paced: Array = []

	for d in [95.0, 97.0, 99.0, 94.0, 98.0, 100.0]:
		band = FloraView.far_band_of(d, band)
		paced.append(band)

	_check(paced.count(paced[0]) == paced.size(), "pacing at a band edge (94 to 100 m) keeps one thinning band %s" % str(paced))
	_check(FloraView.far_band_of(160.0, FloraView.far_band_of(100.0, -1)) == 3, "walking 60 m on (past the slack) moves to the next band")
	var mid: float = FloraView.far_share_at(337.0, 450.0, 0.5, 0.3)
	_check(mid < 0.8 and mid > 0.5 and is_equal_approx(FloraView.far_share_at(450.0, 450.0, 0.5, 0.3), 0.3), "the share falls smoothly to 30 percent at the edge (%.2f at 337 m)" % mid)
	var kept: int = 0

	for id in range(20000):
		kept += 1 if FloraView.far_keep(id * 7 + 3, 0.6) else 0

	_check(absf(float(kept) / 20000.0 - 0.6) < 0.03, "about 60 percent of trees stay at share 0.6 (%.1f percent)" % (100.0 * kept / 20000.0))
	_check(FloraView.far_keep(12345, 0.6) == FloraView.far_keep(12345, 0.6) and FloraView.far_keep(999, 1.0), "the choice is stable per tree, and share 1 keeps every tree")
	view.free()
	print("flora close: %d failures" % failures)
	quit(1 if failures > 0 else 0)
