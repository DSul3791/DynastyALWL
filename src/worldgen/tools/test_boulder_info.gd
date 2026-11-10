extends SceneTree

# The client keeps what the server sends of a boulder (inventory_view.gd boulder_info), so a look can tell an outcrop from a plain boulder:
# its ore (boulders.json ore: the item a pick takes out of it), radius, stones left and yaw.
#   godot --headless --path . --script res://src/worldgen/tools/test_boulder_info.gd

const ViewScript := preload("res://src/client/inventory_view.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var root: Node3D = Node3D.new()
	get_root().add_child.call_deferred(root)
	var view: Node = ViewScript.new()
	view.table = ItemTableScript.load_default()
	view._root = root
	view._ground_below = func(_at: Vector3) -> float: return 0.0
	view._player_position = func() -> Vector3: return Vector3.ZERO
	var tin_at: Vector3 = Vector3(4.0, 0.0, 2.0)
	view._on_world_items([[71, 0, 3000, tin_at, view.BOULDER_STATE, {"radius": 1.0, "yaw": 40.0, "total": 4000, "ore": "tin"}], [72, 0, 120, Vector3(-3.0, 0.0, 1.0), view.BOULDER_STATE, {"radius": 0.3, "yaw": 0.0, "total": 125}]], PackedInt32Array())
	var tin: Dictionary = view.boulder_info(71)
	check(str(tin.get("ore", "")) == "tin" and float(tin.get("radius", 0.0)) == 1.0 and int(tin.get("left", 0)) == 3000 and int(tin.get("total", 0)) == 4000, "an outcrop keeps its ore, radius and stones (%s)" % str(tin))
	check(float(tin.get("yaw", 0.0)) == 40.0 and (tin.get("pos", Vector3.ZERO) as Vector3) == tin_at, "and its yaw and place")
	check(float(tin.get("now", 0.0)) > 0.0 and float(tin.get("now", 2.0)) < 1.0, "the radius left shrinks with the stones taken (%.2f of 1.0)" % float(tin.get("now", 0.0)))
	check(str(view.boulder_info(72).get("ore", "x")) == "", "a plain boulder has no ore")
	view._on_world_items([[71, 0, 2000, tin_at, view.BOULDER_STATE, {"radius": 1.0, "yaw": 40.0, "total": 4000, "ore": "tin"}]], PackedInt32Array())
	check(int(view.boulder_info(71).get("left", 0)) == 2000 and str(view.boulder_info(71).get("ore", "")) == "tin", "a resend after a blow keeps the ore and updates the stones")
	view._on_world_items([], PackedInt32Array([71, 72]))
	check(view.boulder_info(71).is_empty() and view.boulder_info(72).is_empty(), "a boulder the server drops has no info")
	view.free()
	root.queue_free()
	print("test_boulder_info: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
