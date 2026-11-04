extends SceneTree
# Flora filter cost (MikeW, 3 Nov 2026; Steve's log: "flora apply" stalls of about 1 s after digs and chops): when a new felled trunk, stump or
# cleared spot reaches a chunk, only the plants near it are tested, and the chunk is not refiltered against every trunk in it.
#   godot --headless --path . --script res://src/worldgen/tools/test_flora_filter_cost.gd

const FloraView := preload("res://src/flora/flora_view.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _make_view(count: int, trunk_count: int) -> Object:
	var view = FloraView.new()
	view.chunk_m = 256.0
	view._species[3] = {"kind": FloraView.KIND_PLANT}
	view._species[4] = {"kind": FloraView.KIND_TREE}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var ids: PackedInt32Array = PackedInt32Array()
	var positions: PackedVector3Array = PackedVector3Array()
	var heights: PackedFloat32Array = PackedFloat32Array()
	var yaws: PackedFloat32Array = PackedFloat32Array()

	for n in count:
		ids.append(((4 if n % 20 == 0 else 3) << 16) | (n & 0xffff))
		positions.append(Vector3(rng.randf() * 256.0, 0.0, rng.randf() * 256.0))
		heights.append(1.0)
		yaws.append(0.0)

	view._chunks[Vector2i(0, 0)] = {"items": {"ids": ids, "positions": positions, "heights": heights, "yaws": yaws}, "level": 1}
	var trunks: Array = []

	for k in trunk_count:
		var x: float = 10.0 + float(k % 6) * 40.0
		var z: float = 10.0 + float(k / 6) * 40.0
		trunks.append([x, z, x + 6.0, z + 1.0, 0.3, 0.2])

	view.trunks = trunks
	view.trunk_margin_m = 0.3
	view.cleared = [Vector3(128.0, 0.0, 128.0)]
	view.clear_m = 3.0
	return view


func _init() -> void:
	# 1. One new trunk in a chunk of 40,000 plants that already holds 30 trunks and a cleared spot.
	var view = _make_view(40000, 30)
	var before: int = (view._chunks[Vector2i(0, 0)]["items"]["ids"] as PackedInt32Array).size()
	var started: int = Time.get_ticks_usec()
	view._queue_filter_box(128.0, 128.0, 138.0, 133.0, "trunks", view.trunks[21])   # the trunk at 130,130 (beside the cleared spot) as the new one
	var queued: Dictionary = view._filter_queue.get(Vector2i(0, 0), {})
	view._filter_queue.clear()
	view._filter_cleared(Vector2i(0, 0), false, queued.get("trunks", []), queued.get("spots", []))
	var box_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	print("one new trunk, 40,000 plants, 30 trunks: %.1f ms" % box_ms)
	_check(box_ms < 50.0, "refiltering for one new trunk takes under 50 ms (%.1f ms)" % box_ms)
	var after: int = (view._chunks[Vector2i(0, 0)]["items"]["ids"] as PackedInt32Array).size()
	_check(after < before, "the plants under the new trunk are dropped (%d -> %d)" % [before, after])

	# 2. A full refilter (all trunks) removes the same plants as before: under trunks and in the cleared spot, never trees.
	var full = _make_view(40000, 30)
	started = Time.get_ticks_usec()
	full._filter_cleared(Vector2i(0, 0), false)
	var full_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	var items: Dictionary = full._chunks[Vector2i(0, 0)]["items"]
	var left_under: int = 0
	var trees: int = 0

	for n in (items["ids"] as PackedInt32Array).size():
		var p: Vector3 = items["positions"][n]

		if int(items["ids"][n]) >> 16 == 4:
			trees += 1
		elif full._under_trunk(p, full.trunks) or Vector2(p.x - 128.0, p.z - 128.0).length() < 3.0:
			left_under += 1

	print("full refilter: %.1f ms, %d of 40000 left" % [full_ms, (items["ids"] as PackedInt32Array).size()])
	_check(left_under == 0, "no plant is left under a trunk or in a cleared spot (%d)" % left_under)
	_check(trees == 2000, "trees are never filtered (%d of 2000)" % trees)
	_check((items["ids"] as PackedInt32Array).size() == (items["positions"] as PackedVector3Array).size() and (items["heights"] as PackedFloat32Array).size() == (items["yaws"] as PackedFloat32Array).size(), "the item arrays stay the same length")
	_check(full_ms < 150.0, "a full refilter of 40,000 plants takes under 150 ms (was about 400) (%.1f ms)" % full_ms)
	view.free()
	full.free()
	print("flora filter cost: %d failures" % failures)
	quit(1 if failures > 0 else 0)
