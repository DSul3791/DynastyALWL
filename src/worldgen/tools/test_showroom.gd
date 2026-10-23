extends SceneTree
# Headless check of the admin showroom (data/items/showroom.json): the rows parse, ids resolve, spots are laid out and the grass-clearing
# spots follow the rows.

const Showroom := preload("res://src/client/showroom.gd")
const ItemTable := preload("res://src/shared/item_table.gd")

var failures: int = 0


class FakeView:
	extends RefCounted
	var table
	@warning_ignore("unused_private_class_variable")   # read by the showroom through the view
	var _root: Node3D = Node3D.new()
	@warning_ignore("unused_private_class_variable")
	var _ground_below: Callable = func(_p: Vector3) -> float: return 10.0
	var made: int = 0

	func make_display_item(_number: int, _seed_id: int) -> Node3D:
		made += 1
		return Node3D.new()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var view: FakeView = FakeView.new()
	view.table = ItemTable.load_default()
	var room = Showroom.new()
	room.setup(view, Vector3(53301.0, 20.0, 68427.0))
	_check(room.rows.size() >= 1, "the showroom rows load")
	_check(room.clear_spots().is_empty(), "nothing is cleared while the showroom is off")
	room.update(false, Vector3(53301.0, 20.0, 68427.0))
	_check(view.made == 0, "off: nothing is drawn")
	room.update(true, Vector3(53301.0, 20.0, 68427.0))
	_check(view.made >= 4 and room.skipped == 0, "on: the rows are drawn and every id resolves (%d drawn)" % view.made)
	_check(not room.clear_spots().is_empty(), "on: the grass is cleared along the rows")
	room.update(true, Vector3(60000.0, 20.0, 68427.0))
	_check(room.clear_spots().is_empty(), "far from spawn: it goes away")
	print("showroom: %d failures" % failures)
	quit(1 if failures > 0 else 0)
