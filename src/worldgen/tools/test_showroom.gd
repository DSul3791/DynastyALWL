extends SceneTree
# Headless check of the admin showroom (data/items/showroom.json): the rows parse, ids resolve, the server is asked to fill the rows once
# (the things are real world items placed by the server, no longer drawn by the client), and the grass-clearing spots follow the rows.

const Showroom := preload("res://src/client/showroom.gd")
const ItemTable := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


class FakeRpc:
	extends RefCounted
	var calls: Array = []

	func rpc_id(peer: int, action: int, a: int, b: int, c: int, at: Vector3) -> void:
		calls.append([peer, action, a, b, c, at])


class FakeNet:
	extends RefCounted
	var inventory_action: FakeRpc = FakeRpc.new()


class FakeView:
	extends RefCounted
	var table
	var net: FakeNet = FakeNet.new()


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
	var spawn: Vector3 = Vector3(53301.0, 20.0, 68427.0)
	room.setup(view, spawn)
	_check(room.rows.size() >= 1, "the showroom rows load")
	var unknown: Array = []

	for row in room.rows:
		for entry in row.get("items", []):
			if not view.table.has_id(str(entry[0])):
				unknown.append(str(entry[0]))

	_check(unknown.is_empty(), "every showroom item id resolves %s" % str(unknown))
	_check(room.clear_spots().is_empty(), "nothing is cleared while the showroom is off")
	room.update(false, spawn)
	_check(view.net.inventory_action.calls.is_empty(), "off: the server is not asked")
	room.update(true, spawn)
	var calls: Array = view.net.inventory_action.calls
	_check(calls.size() == 1 and calls[0][1] == Net.ACT_SHOWROOM and calls[0][2] == 0, "on: the server is asked once to fill the rows")
	room.update(true, spawn)
	_check(view.net.inventory_action.calls.size() == 1, "on again: it is not asked twice")
	_check(not room.clear_spots().is_empty(), "on: the grass is cleared along the rows")
	room.respawn()
	_check(view.net.inventory_action.calls.size() == 2 and view.net.inventory_action.calls[1][2] == 1, "respawn asks the server to refill")
	room.update(true, Vector3(60000.0, 20.0, 68427.0))
	_check(room.clear_spots().is_empty(), "far from spawn: it goes away")
	print("showroom: %d failures" % failures)
	quit(1 if failures > 0 else 0)
