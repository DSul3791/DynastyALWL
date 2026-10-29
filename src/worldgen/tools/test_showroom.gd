extends SceneTree
# Headless check of the admin showroom client (data/items/showroom.json): the rows parse, the server is asked to fill them once per visit, and the
# grass-clearing spots follow the rows. (The things themselves are real world items; the server side is in test_server_items.)

const Showroom := preload("res://src/client/showroom.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


class FakeAction:
	extends RefCounted
	var calls: Array = []

	func rpc_id(peer: int, kind: int, a: int, b: int, count: int, at: Vector3) -> void:
		calls.append([peer, kind, a, b, count, at])


class FakeNet:
	extends RefCounted
	var inventory_action: FakeAction = FakeAction.new()


# The showroom reads the inventory view's net (the things themselves are real world items the server places).
class FakeView:
	extends RefCounted
	var net: FakeNet = FakeNet.new()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var view: FakeView = FakeView.new()
	var room = Showroom.new()
	var spawn: Vector3 = Vector3(53301.0, 20.0, 68427.0)
	room.setup(view, spawn)
	var calls: Array = view.net.inventory_action.calls
	_check(room.rows.size() >= 1, "the showroom rows load")
	_check(room.clear_spots().is_empty(), "nothing is cleared while the showroom is off")
	room.update(false, spawn)
	_check(calls.is_empty(), "off: the server is not asked")
	room.update(true, spawn)
	_check(calls.size() == 1 and calls[0][1] == Net.ACT_SHOWROOM and calls[0][2] == 0, "on and near: the server is asked once to fill the rows")
	room.update(true, spawn)
	_check(calls.size() == 1, "and not again while the player stays")
	_check(not room.clear_spots().is_empty(), "on: the grass is cleared along the rows")
	room.update(true, Vector3(60000.0, 20.0, 68427.0))
	_check(room.clear_spots().is_empty(), "far from spawn: it goes away")
	room.update(true, spawn)
	_check(calls.size() == 2, "coming back asks again")
	room.respawn()
	_check(calls.size() == 3 and calls[2][2] == 1, "the admin button asks the server to clear and fill again")
	print("showroom: %d failures" % failures)
	quit(1 if failures > 0 else 0)
