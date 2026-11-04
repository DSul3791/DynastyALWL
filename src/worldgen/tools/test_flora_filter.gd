extends SceneTree

# The plant filter of flora_view (Dave 3 Nov 2026: 0.8-1 s stalls after every dig, cut and hoe click): plants under a trunk, stump, boulder or
# path patch, or in a cleared spot, are dropped; trees stay; a queued new obstacle is tested alone.
#   godot --headless --path . --script res://src/worldgen/tools/test_flora_filter.gd

const FloraView := preload("res://src/flora/flora_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _chunk_items() -> Dictionary:
	# Species 1 is a tree, 2 a plant. Plants every 2 m along z = 10 from x = 1 to 99, a tree at (50, 10).
	var ids: PackedInt32Array = PackedInt32Array()
	var positions: PackedVector3Array = PackedVector3Array()
	var heights: PackedFloat32Array = PackedFloat32Array()
	var yaws: PackedFloat32Array = PackedFloat32Array()

	for k in range(50):
		ids.append((2 << 16) | k)
		positions.append(Vector3(1.0 + 2.0 * k, 0.0, 10.0))
		heights.append(1.0)
		yaws.append(0.0)

	ids.append((1 << 16) | 99)
	positions.append(Vector3(50.0, 0.0, 10.0))
	heights.append(10.0)
	yaws.append(0.0)
	return {"ids": ids, "positions": positions, "heights": heights, "yaws": yaws}


func _initialize() -> void:
	var view: Node3D = FloraView.new()
	view.chunk_m = 256.0
	view._species = {1: {"kind": FloraView.KIND_TREE}, 2: {"kind": FloraView.KIND_PLANT}}
	view._chunks[Vector2i(0, 0)] = {"items": _chunk_items(), "level": -1}
	view.clear_m = 5.0
	view.trunk_margin_m = 0.3
	# A boulder of 1 m at (21, 10) and a cleared spot at (50, 0, 10).
	view.trunks = [[21.0, 10.0, 21.0, 10.0, 1.0, 1.0]]
	view.cleared = [Vector3(50.0, 0.0, 10.0)]
	view._filter_cleared(Vector2i(0, 0), false)
	var items: Dictionary = view._chunks[Vector2i(0, 0)]["items"]
	var xs: Array = []

	for p in items["positions"]:
		xs.append(p.x)

	check(not xs.has(21.0), "the plant under the boulder is gone")
	check(xs.has(19.0) and xs.has(23.0), "plants 2 m off it stay (reach 1 m + 0.5 m)")
	check(not xs.has(47.0) and not xs.has(53.0) and xs.has(55.0) and xs.has(45.0), "plants within 5 m of the spot are gone, ones at 5 m stay")
	check(xs.count(50.0) == 1 and int(items["ids"][items["ids"].size() - 1]) >> 16 == 1, "the tree in the spot stays")
	check(items["ids"].size() == items["positions"].size() and items["heights"].size() == items["yaws"].size() and items["ids"].size() == items["heights"].size(), "the four arrays stay in step")
	var before: int = items["ids"].size()

	# A new hoe patch at (81, 10): queued alone and worked off.
	view._filter_queue = {}
	view.trunks = [[21.0, 10.0, 21.0, 10.0, 1.0, 1.0], [81.0, 10.0, 81.0, 10.0, 0.6, 0.6]]
	view._queue_filter_box(80.0, 9.0, 82.0, 11.0, "trunks", view.trunks[1])
	check(view._filter_queue.has(Vector2i(0, 0)) and (view._filter_queue[Vector2i(0, 0)]["trunks"] as Array).size() == 1, "only the new patch is queued")
	var job: Dictionary = view._filter_queue[Vector2i(0, 0)]
	view._filter_queue.erase(Vector2i(0, 0))
	view._filter_cleared(Vector2i(0, 0), false, job["trunks"], job["spots"])
	items = view._chunks[Vector2i(0, 0)]["items"]
	xs = []

	for p in items["positions"]:
		xs.append(p.x)

	check(items["ids"].size() == before - 1 and not xs.has(81.0) and xs.has(79.0) and xs.has(83.0), "the patch drops just the plant under it")

	# Timing: a full chunk of 40000 plants against 300 boulders, then one new patch.
	var big: Dictionary = {"ids": PackedInt32Array(), "positions": PackedVector3Array(), "heights": PackedFloat32Array(), "yaws": PackedFloat32Array()}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7

	for k in range(40000):
		big["ids"].append((2 << 16) | k)
		big["positions"].append(Vector3(rng.randf() * 256.0, 0.0, rng.randf() * 256.0))
		big["heights"].append(1.0)
		big["yaws"].append(0.0)

	var rocks: Array = []

	for k in range(300):
		var x: float = rng.randf() * 256.0
		var z: float = rng.randf() * 256.0
		rocks.append([x, z, x, z, 0.8, 0.8])

	view._chunks[Vector2i(0, 0)] = {"items": big, "level": -1}
	view.trunks = rocks
	view.cleared = []
	var t0: int = Time.get_ticks_usec()
	view._filter_cleared(Vector2i(0, 0), false)
	var full_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	t0 = Time.get_ticks_usec()
	view._filter_cleared(Vector2i(0, 0), false, [[128.0, 128.0, 128.0, 128.0, 0.6, 0.6]], [])
	var one_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("full filter %.1f ms, one new patch %.1f ms" % [full_ms, one_ms])
	# Loose bars (Tyler 3 Nov: the full refilter ran 200-220 ms on a loaded 4-core cloud runner): the full refilter runs once per chunk
	# load, so only a big regression matters; the point of #187 is that a new patch costs a small share of it, checked against the same run.
	check(full_ms < 500.0, "a full refilter of 40000 plants against 300 boulders takes under 500 ms (%.1f)" % full_ms)
	check(one_ms < 30.0 and one_ms < full_ms * 0.25, "one new patch in a 40000 plant chunk takes under 30 ms and under a quarter of the full refilter (%.1f vs %.1f)" % [one_ms, full_ms])
	view.free()
	print("Test done: %d failures" % failures)
	quit(1 if failures > 0 else 0)
