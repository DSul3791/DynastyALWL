extends SceneTree

# BUG-024 (Dave's QA list, 3 Nov 2026: felled trees fall again after streaming out and back in; a cut tree must stay gone near and far).
#   godot --headless --path . --script res://src/worldgen/tools/test_felled_stays_gone.gd
# 1. A felled tree's stump is "fresh" (a client plays the fall) only until the fall lands, and a saved stump loads landed, so a client that sees it
#    again (coming back into range) draws the stump and the lying logs instead of felling the tree a second time.
# 2. A tree cut while the server is making its chunk on a worker thread is not kept in the server's packed copy
#    (every later asker, near or far, would get the standing tree back).

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ServerFloraScript := preload("res://src/stream/server_flora.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


# Three trees in every chunk, ids 1, 2 and 3 (the server flora only needs these four calls of the placer).
class FakePlacer:
	var chunk_m: float = 64.0

	func normalize(chunk: Vector2i) -> Vector2i:
		return chunk

	func chunk_origin(chunk: Vector2i) -> Vector2:
		return Vector2(chunk) * chunk_m

	func chunk_items(chunk: Vector2i, _trees_only: bool = false) -> Dictionary:
		var o: Vector2 = chunk_origin(chunk)
		return {
			"ids": PackedInt32Array([(1 << 16) | 1, (1 << 16) | 2, (1 << 16) | 3]),
			"positions": PackedVector3Array([Vector3(o.x + 5.0, 1.0, o.y + 5.0), Vector3(o.x + 20.0, 1.0, o.y + 20.0), Vector3(o.x + 40.0, 1.0, o.y + 40.0)]),
			"heights": PackedFloat32Array([12.0, 14.0, 16.0]),
			"yaws": PackedFloat32Array([0.0, 1.0, 2.0]),
		}

	func species_by_id(_id: int) -> Dictionary:
		return {}

	func species_of(_id: int) -> Dictionary:
		return {}   # server_flora's undergrowth index asks the kind (empty reads as a tree: no undergrowth)


func make_items(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), dir)
	return items


func _init() -> void:
	# 1. Landed after the fall (FALL_S of the server's own time).
	var dir: String = "user://test_felled_stays_gone_%d" % Time.get_ticks_usec()
	var w = make_items(dir)
	var first: int = w._next_id
	w._fell_record(Vector2i(0, 0), {"name": "oak", "position": Vector3(3.0, 10.0, 3.0), "height": 9.0, "trunk": 0.3}, Vector2(1.0, 0.0))
	var id: int = first
	var pieces: Array = range(first + 1, w._next_id)
	w._fall_tick(ItemsScript.FALL_S - 0.5)
	check(bool(w._items[id]["tree"].get("fresh", false)) and pieces.all(func(k): return w._items[k].has("fall")), "a tree still falling is fresh and its pieces carry the fall (a client near it sees it fall)")
	w._fall_tick(0.6)
	check(not w._items[id]["tree"].has("fresh") and pieces.all(func(k): return not w._items[k].has("fall")), "after its fall time the stump is landed and the pieces lie (seen again, no second fall)")

	# A tree saved while it was still coming down loads landed: the stump is not fresh and its logs lie.
	w._items[id]["tree"]["fresh"] = true
	w._dirty = true
	w.save()
	w._finish_writer()   # the write runs in the background
	var again = make_items(dir)
	var stumps: int = 0
	var fresh: int = 0
	var falling: int = 0

	for k in again._items:
		if again._items[k].has("tree"):
			stumps += 1
			fresh += 1 if again._items[k]["tree"].has("fresh") else 0
		elif again._items[k].has("fall"):
			falling += 1

	check(stumps == 1 and fresh == 0 and falling == 0, "a saved stump loads landed and its logs lie (%d fresh, %d falling, %d stumps)" % [fresh, falling, stumps])

	# 2. A cut while the chunk is being made.
	var flora = ServerFloraScript.new()
	flora.setup(FakePlacer.new(), dir)
	var chunk: Vector2i = Vector2i(2, -1)
	var victim: int = (1 << 16) | 2
	var cut_once: Array = [false]
	flora.dynamic = func(home: Vector2i) -> Dictionary:
		if not cut_once[0]:
			cut_once[0] = true
			flora.cut(home, victim)   # what the main thread does while a worker is between reading the removals and storing the bytes

		return {}

	var origin: Vector2 = Vector2(chunk) * 64.0
	var first: Dictionary = PlacerScript.decode(flora.chunk_bytes(chunk, false), origin)
	check(first["ids"].size() == 2 and first["ids"].find(victim) < 0, "the chunk made while the tree was cut leaves it out (%d trees)" % first["ids"].size())
	var later: Dictionary = PlacerScript.decode(flora.chunk_bytes(chunk, false), origin)
	check(later["ids"].find(victim) < 0, "the stored copy leaves it out too: far askers (trees only) never see it again")
	var full: Dictionary = PlacerScript.decode(flora.chunk_bytes(chunk, true), origin)
	check(full["ids"].find(victim) < 0 and full["ids"].size() == 2, "near askers (full chunk) do not see it either")
	check(not flora.cut(chunk, victim), "it cannot be cut twice")

	# The client side: chunks arriving after a cut drop it (terrain_client _recent_cuts uses FloraPlacer.without).
	var late: Dictionary = PlacerScript.without(FakePlacer.new().chunk_items(chunk), {victim: 1})
	check(late["ids"].size() == 2 and late["ids"].find(victim) < 0 and late["positions"].size() == 2, "a late chunk with the cut tree in it is filtered")

	print("test_felled_stays_gone: %s" % ("PASS" if failures == 0 else "FAIL (%d)" % failures))
	quit(1 if failures > 0 else 0)
