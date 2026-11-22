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

	# A door a friend hung in your doorway: the frame's builder may take it out (else neither could ever come down); a third player may not.
	var at: Vector3 = Vector3(20.0, 10.0, 20.0)
	b._next_id += 1
	var door: int = b._next_id   # the door's id first: the frame lookup must not take the door (it carries "opening" too) for its frame
	b._items[door] = {"number": b.table.number_of("crude_door"), "count": 1, "pos": at, "left": 1.0e9, "struct": {"kind": "crude_door", "yaw": 0.0, "owner": "friend-key-00002"}}
	b._next_id += 1
	var frame: int = b._next_id
	b._items[frame] = {"number": b.table.number_of("log_doorway"), "count": 1, "pos": at, "left": 1.0e9, "struct": {"kind": "log_doorway", "yaw": 0.0, "owner": "builder-key-0001"}}
	b.peer_connected_hello(3, "stranger-key-003")
	check(b._may_take_down(1, b._items[door]), "the doorway's builder may take out a door another player hung in it")
	check(not b._may_take_down(3, b._items[door]) and b._may_take_down(2, b._items[door]), "a stranger may not; the door's own hanger still may")
	check(not b._may_take_down(2, b._items[frame]), "the door's hanger still cannot take the frame")
	b._items[frame]["struct"].erase("owner")   # a frame saved before owners: open to all, so its door is too (else the frame could never come down)
	check(b._may_take_down(3, b._items[door]), "a door in an old unowned frame may be taken out by anyone")
	b._items.erase(door)
	b._items.erase(frame)

	# Pieces laid by hand record their maker too: a torch (the tilled bed is in test_farming).
	b.give_to(1, "torch", 1)
	b.report_position(1, Vector3(30.0, 10.0, 30.0))
	b._place_torch(1, b.inventory_of(1), b.inventory_of(1).numbers.find(b.table.number_of("torch")), false, 0, Vector3(30.5, 10.0, 30.0))
	var torch_owner: String = ""

	for id in b._items:
		if b._items[id].has("struct") and str(b._items[id]["struct"]["kind"]).contains("torch"):
			torch_owner = str(b._items[id]["struct"].get("owner", ""))

	check(torch_owner == "builder-key-0001", "a placed torch records who set it (%s)" % torch_owner)
	var torch_id: int = -1

	for id in b._items:
		if b._items[id].has("struct") and str(b._items[id]["struct"]["kind"]).contains("torch"):
			torch_id = int(id)

	b.report_position(2, Vector3(30.0, 10.0, 30.0))
	b._take_down(2, b.inventory_of(2), torch_id)
	check(b._items.has(torch_id), "another player cannot pick up a torch someone set")

	b._finish_writer()
	print("test_take_down_owner: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
