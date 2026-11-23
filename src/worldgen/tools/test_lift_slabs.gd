extends SceneTree

# Stacks dropped on a foundation before 23 Nov 2026 lay inside its slab: at load they are lifted onto its top (server_items _lift_out_of_slabs).
# Nothing made, merged or removed; a second load does nothing.
#   godot --headless --path . --script res://src/worldgen/tools/test_lift_slabs.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const PlacementRules := preload("res://src/shared/placement_rules.gd")

const DIR := "user://test_lift_slabs"
const GROUND := 10.0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make():
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.setup(ItemTableScript.load_default(), DIR)
	return items


func restart(items):
	items._dirty = true
	items.save()
	items._finish_writer()
	return make()


# The stone stack of `count` (each stack here has its own count: ids are made again at load).
func stack(items, count: int) -> Dictionary:
	for id in items._items:
		if int(items._items[id]["number"]) == items.table.number_of("stone") and int(items._items[id]["count"]) == count:
			return items._items[id]

	return {"pos": Vector3(NAN, NAN, NAN), "count": 0}


func add(items, row: Dictionary) -> int:
	var id: int = items._next_id
	items._items[id] = row
	items._next_id += 1

	if row.has("struct"):
		items._grid_add(id, row)

	return id


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	var items = make()
	var stone: int = items.table.number_of("stone")
	var base_item: int = items.table.number_of(str(items._structures["foundation_section"]["item"]))
	var top: float = GROUND + PlacementRules.anchor_top(items._structures["foundation_section"])
	add(items, {"number": base_item, "count": 1, "pos": Vector3(300.0, GROUND, 300.0), "left": 1.0e9, "struct": {"kind": "foundation_section", "yaw": 0.0, "uid": 1}})
	add(items, {"number": base_item, "count": 1, "pos": Vector3(320.0, GROUND + 1.0, 300.0), "left": 1.0e9, "struct": {"kind": "foundation_section", "yaw": 0.0, "uid": 2}})
	add(items, {"number": base_item, "count": 1, "pos": Vector3(340.0, GROUND, 300.0), "left": 1.0e9, "struct": {"kind": "foundation_section", "yaw": 0.0, "uid": 3, "site": {"have": {}}}})
	add(items, {"number": stone, "count": 7, "pos": Vector3(301.0, GROUND, 301.0), "left": 1.0e9, "wear": 0})
	add(items, {"number": stone, "count": 3, "pos": Vector3(321.0, GROUND, 299.0), "left": 1.0e9, "wear": 0})   # under a foundation lifted 1 m
	add(items, {"number": stone, "count": 2, "pos": Vector3(299.0, top, 299.0), "left": 1.0e9, "wear": 0})
	add(items, {"number": stone, "count": 4, "pos": Vector3(300.5, GROUND - 3.0, 300.5), "left": 1.0e9, "wear": 0})   # in a dug cellar under it
	add(items, {"number": stone, "count": 5, "pos": Vector3(340.5, GROUND, 300.5), "left": 1.0e9, "wear": 0})
	add(items, {"number": stone, "count": 6, "pos": Vector3(303.0, GROUND, 300.0), "left": 1.0e9, "wear": 0})
	var before: int = items._items.size()
	var stones: int = 0

	for id in items._items:
		stones += int(items._items[id]["count"]) if int(items._items[id]["number"]) == stone else 0

	items = restart(items)
	check(items.lifted_at_load == 2, "the load lifts the two stacks inside slabs (%d)" % items.lifted_at_load)
	check(absf(float(stack(items, 7)["pos"].y) - top) < 0.001 and is_equal_approx(stack(items, 7)["pos"].x, 301.0), "the buried stack lies on the foundation's top, same x and z")
	check(absf(float(stack(items, 3)["pos"].y) - (top + 1.0)) < 0.001, "the one under a lifted foundation on that one's top")
	check(is_equal_approx(float(stack(items, 2)["pos"].y), top), "a stack already on the top stays")
	check(is_equal_approx(float(stack(items, 4)["pos"].y), GROUND - 3.0), "one in a cellar 3 m under stays")
	check(is_equal_approx(float(stack(items, 5)["pos"].y), GROUND), "a blueprint site lifts nothing")
	check(is_equal_approx(float(stack(items, 6)["pos"].y), GROUND), "one beside the slab stays on the ground")
	var stones_now: int = 0

	for id in items._items:
		stones_now += int(items._items[id]["count"]) if int(items._items[id]["number"]) == stone else 0

	check(items._items.size() == before and stones_now == stones and int(stack(items, 7)["count"]) == 7, "nothing made, merged or removed (%d records, %d stones)" % [items._items.size(), stones_now])
	items = restart(items)
	check(items.lifted_at_load == 0 and absf(float(stack(items, 7)["pos"].y) - top) < 0.001, "saved on its top: the next load lifts nothing")
	print("lift slabs test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
