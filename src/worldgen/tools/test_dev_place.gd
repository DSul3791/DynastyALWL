extends SceneTree

# --dev-place (testing only; server_items.gd dev_place / dev_place_later): structures placed without a kit for rigs and screenshots. A lean-to and a bed in it, a lit fireplace and torch,
# a lit campfire, a chest with its store; an unknown name or missing ground places nothing; a spec waits for its ground and is placed when the ground is there.
#   godot --headless --path . --script res://src/worldgen/tools/test_dev_place.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const CoverScript := preload("res://src/shared/cover.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var dir: String = "user://test_dev_place"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var ground_ready: Array = [true]
	var index = CoverScript.Index.new()
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0 if ground_ready[0] else NAN
	items.roof_add = func(roof): return index.add_roof(roof)
	items.setup(ItemTableScript.load_default(), dir)
	var lean: int = items.dev_place("lean_to@10,10,0")
	var bed: int = items.dev_place("rough_bed@10,10,0")
	check(lean != 0 and bed != 0 and CoverScript.at(Vector3(10.0, 11.0, 10.0), index) > 0.5, "a lean-to with a bed in it is placed and has its roof")
	var fireplace: int = items.dev_place("fireplace@15,10,90,lit")
	check(fireplace != 0 and bool(items._items[fireplace]["struct"].get("lit", false)) and float(items._items[fireplace]["struct"]["fuel_left"]) > 0.0, "a fireplace placed lit burns")
	var torch: int = items.dev_place("wall_torch@16,10,0")
	check(torch != 0 and not bool(items._items[torch]["struct"].get("lit", false)), "a torch placed without `lit` is out")
	var fire: int = items.dev_place("campfire@20,20,0,lit")
	check(fire != 0 and items.fire_is_lit(int(items._items[fire]["fire"]["state"])), "a lit campfire is laid")
	var chest: int = items.dev_place("chest@25,25,0")
	check(chest != 0 and items._chests.has(int(items._items[chest]["struct"]["uid"])), "a chest gets its store")
	check(items.dev_place("no_such_thing@1,1,0") == 0 and items.dev_place("garbage") == 0, "an unknown name or a bad spec places nothing")
	ground_ready[0] = false
	check(items.dev_place("chest@30,30,0") == 0, "no ground yet: nothing")
	items.dev_place_later("chest@31,31,0")
	items._dev_pending_tick(2.0)
	check(items._dev_pending.size() == 1, "and the spec waits")
	ground_ready[0] = true
	items._dev_pending_tick(2.0)
	check(items._dev_pending.is_empty(), "and is placed once the ground is there")
	print("dev place: %d failures" % failures)
	quit(1 if failures > 0 else 0)
