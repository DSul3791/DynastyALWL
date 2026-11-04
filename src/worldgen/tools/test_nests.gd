extends SceneTree

# Inland bird nests (Sal, 3 Nov 2026; data/items/nests.json): E at a grouse or songbird nest the fauna side placed gives eggs in its seasons, a robbed nest is empty for
# refill_days game days and then lays again, out of season it is an old empty nest, and a nest wins over the sea edge (both use ACT_GATHER_EDGE).
#   godot --headless --path . --script res://src/worldgen/tools/test_nests.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var failures: int = 0
var items
var clock: Array = [0.0]
var season: Array = ["spring"]
var nests: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func eggs() -> int:
	return items.inventory_of(1).count_of(items.table.number_of("egg"))


func _init() -> void:
	var dir: String = "user://test_nests"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 20.0
	items.game_seconds = func(): return clock[0]
	items.season_now = func(): return season[0]
	items.water_kind_at = func(_x, _z): return {"kind": "", "depth": 0.0}
	items.nests_near = func(pos, reach): return nests.filter(func(n): return (n["pos"] as Vector3).distance_to(pos) <= reach)
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "nesttest0001")
	items.report_position(1, Vector3(0.0, 20.0, 0.0))
	items.vitals_of(1)["weight"] = 2000.0

	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/nests.json"))
	var real: bool = true

	for kind in cfg["kinds"]:
		real = real and items.table.has_id(str(cfg["kinds"][kind]["item"]))

		if cfg["kinds"][kind].has("extra"):
			real = real and items.table.has_id(str(cfg["kinds"][kind]["extra"][0]))

	check(real, "nests.json names real items")

	# No nest near: nothing (and no sea either).
	check(not items.gather_edge(1, items.inventory_of(1)) and eggs() == 0, "no nest and no sea: nothing")

	# A grouse nest in spring.
	nests.append({"id": "g1", "kind": "grouse", "pos": Vector3(1.0, 20.0, 0.0)})
	check(items.gather_edge(1, items.inventory_of(1)), "E at a grouse nest in spring takes it")
	var first: int = eggs()
	check(first >= 3 and first <= 7, "a grouse clutch is 3 to 7 eggs (%d)" % first)
	check(not items.gather_edge(1, items.inventory_of(1)) and eggs() == first, "the robbed nest is empty the same day")
	clock[0] += 86400.0 * 4.0
	check(items.gather_edge(1, items.inventory_of(1)) and eggs() > first, "after refill_days it has laid again")

	# Out of season.
	season[0] = "autumn"
	clock[0] += 86400.0 * 10.0
	var before: int = eggs()
	check(not items.gather_edge(1, items.inventory_of(1)) and eggs() == before, "in autumn the nest is old and empty")

	# A songbird nest in summer, out of reach first.
	season[0] = "summer"
	nests.clear()
	nests.append({"id": "s1", "kind": "songbird", "pos": Vector3(6.0, 20.0, 0.0)})
	check(not items.take_nest(1, items.inventory_of(1)), "a nest 6 m away is out of reach")
	items.report_position(1, Vector3(5.0, 20.0, 0.0))
	check(items.take_nest(1, items.inventory_of(1)) and eggs() - before >= 2 and eggs() - before <= 4, "a songbird nest in summer gives 2 to 4 eggs")

	items._finish_writer()
	print("test_nests: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
