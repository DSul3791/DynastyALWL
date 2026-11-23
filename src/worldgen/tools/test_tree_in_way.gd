extends SceneTree

# Nothing is placed over a standing tree (physical world audit round 4; coordinator 23 Nov 2026: "yes to refusing placement over a standing
# tree"): its trunk stood up through the floor. server_items _place with PlacementRules.over_trunk; saplings have no trunk and are not listed.
#   godot --headless --path . --script res://src/worldgen/tools/test_tree_in_way.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const PlacementRules := preload("res://src/shared/placement_rules.gd")

const TRUNK := Vector3(20.0, 10.0, 20.0)
var failures: int = 0
var notices: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make():
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, t): notices.append(str(t))
	items.send_carry = func(_p, _id): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), "user://test_tree_in_way")
	items.admin_mode_on = func(_p): return false
	items.trunks_near = func(point: Vector3, radius: float) -> Array: return [[TRUNK, 0.4, 14.0]] if Vector2(point.x - TRUNK.x, point.z - TRUNK.z).length() <= radius + 0.4 else []
	items.peer_connected_hello(1, "test-tree-way-01")
	return items


# Lays one `structure` for peer 1 at `at` (place_piece: the hammer's placement with no tools or materials asked): true when it was set down.
func place(items, structure: String, at: Vector3) -> bool:
	items.report_position(1, at + Vector3(0.0, 0.0, 2.5))
	var before: int = items._items.size()
	notices.clear()
	items.place_piece(1, str(items._structures[structure]["kit"]), at)
	return items._items.size() > before


func _init() -> void:
	var items = make()
	var chest_kit: String = "chest" if items._structures.has("chest") else ""
	check(chest_kit != "", "a chest is a placeable structure")
	check(not place(items, chest_kit, TRUNK + Vector3(0.2, 0.0, 0.0)), "a chest over a standing tree is refused")
	check(notices.has("A tree is in the way: fell it first."), "with words that say why (%s)" % str(notices))
	check(not place(items, "workbench" if items._structures.has("workbench") else chest_kit, TRUNK + Vector3(0.0, 0.0, 0.3)), "so is a workbench set against the trunk")
	check(place(items, chest_kit, TRUNK + Vector3(3.0, 0.0, 0.0)), "3 m from the trunk it is set down (positive control)")
	var def: Dictionary = items._structures["foundation_section"]
	var kit: String = str(def["kit"])
	var row: Array = [[TRUNK, 0.4, 14.0]]
	check(PlacementRules.over_trunk(items._structures_cfg, kit, TRUNK + Vector3(1.9, 0.0, 0.0), 0.0, row), "a 4 m foundation whose edge takes in the trunk is over it")
	check(not PlacementRules.over_trunk(items._structures_cfg, kit, TRUNK + Vector3(2.6, 0.0, 0.0), 0.0, row), "one whose edge stops short of the bark is not")
	check(PlacementRules.over_trunk(items._structures_cfg, kit, TRUNK + Vector3(2.6, 0.0, 0.0), deg_to_rad(45.0), row), "the same spot turned 45 degrees: its corner reaches the trunk")
	check(not PlacementRules.over_trunk(items._structures_cfg, kit, TRUNK + Vector3(0.0, 8.0, 0.0), 0.0, row), "a floor 8 m up over a 14 m tree is above its trunk")
	print("tree in the way test: %d failures" % failures)
	quit(1 if failures > 0 else 0)
