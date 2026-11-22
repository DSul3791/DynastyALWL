extends SceneTree

# Only the builder takes a placed piece down (coordinator for Dave, 22 Nov 2026: friends must not take each other's houses apart for the
# materials). An admin in admin mode may; a piece with no owner (saved before owners were kept on every piece) stays open to anyone.
# The owner survives a save and load.
#   godot --headless --path . --script res://src/worldgen/tools/test_take_down_owner.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_craft_queue = func(_p, _e, _l): pass
	items.send_notice = func(_p, text): said.append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	return items


func bench_of(items) -> int:
	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "workbench":
			return int(id)

	return -1


func _init() -> void:
	var dir: String = "user://test_take_down_owner"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var a = make(dir)
	a.peer_connected_hello(1, "builder-key-0001")
	a.peer_connected_hello(2, "friend-key-00002")
	a.report_position(1, Vector3(0.0, 10.0, 0.0))
	a.report_position(2, Vector3(1.0, 10.0, 1.0))
	a.place_piece(1, "workbench_kit", Vector3(1.5, 10.0, 0.0))
	var bench: int = bench_of(a)
	check(bench >= 0 and str(a._items[bench]["struct"].get("owner", "")) == "builder-key-0001", "a placed piece records its builder")

	said.clear()
	a._take_down(2, a.inventory_of(2), bench)
	check(a._items.has(bench), "another player cannot take it down")
	check(not said.is_empty() and str(said[said.size() - 1]).contains("built it"), "and is told why: \"%s\"" % (str(said[said.size() - 1]) if not said.is_empty() else ""))

	a._admin_mode_on[2] = true
	check(a._may_take_down(2, a._items[bench]), "an admin in admin mode may")
	a._admin_mode_on.erase(2)

	a._dirty = true
	a.save()
	a._finish_writer()
	var b = make(dir)
	var bench_b: int = bench_of(b)
	check(bench_b >= 0 and str(b._items[bench_b]["struct"].get("owner", "")) == "builder-key-0001", "the builder is kept through a save and load")

	b.peer_connected_hello(1, "builder-key-0001")
	b.peer_connected_hello(2, "friend-key-00002")
	b.report_position(1, Vector3(0.0, 10.0, 0.0))
	b.report_position(2, Vector3(1.0, 10.0, 1.0))
	b._items[bench_b]["struct"].erase("owner")   # a piece saved before owners were kept
	b._take_down(2, b.inventory_of(2), bench_b)
	check(not b._items.has(bench_b), "a piece with no owner can be taken down by anyone, as before")

	b.place_piece(1, "workbench_kit", Vector3(1.5, 10.0, 0.0))
	var mine: int = bench_of(b)
	b._take_down(1, b.inventory_of(1), mine)
	check(mine >= 0 and not b._items.has(mine), "the builder takes their own piece down")

	b._finish_writer()
	print("test_take_down_owner: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
