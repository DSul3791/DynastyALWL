extends SceneTree

# E does what the cursor is on first (Dave 1 Nov 2026): a chopping block in the cursor splits a log and does NOT also pick up the wood around it; the nearby
# pick-up runs only when the cursor is on nothing with an E action; held E does not sweep while the cursor is on something with its own action.
#   godot --headless --path . --script res://src/worldgen/tools/test_e_priority.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ViewScript := preload("res://src/client/inventory_view.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


class Rec:
	extends RefCounted
	var calls: Array = []

	func rpc_id(_peer, kind, a, _b, _c, _v) -> void:
		calls.append([kind, a])


class NetStub:
	extends RefCounted
	var inventory_action: Rec = Rec.new()


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var table = ItemTableScript.load_default()
	var view = ViewScript.new()
	var net = NetStub.new()
	view.net = net
	view.table = table
	view._player_position = func(): return Vector3.ZERO
	var eye: Vector3 = Vector3(0.0, 1.6, 0.0)
	var facing: Array = [Vector3(1.6, -1.6, 0.0).normalized()]
	view.view_direction = func(): return facing[0]
	view._register_builtin_interactables()
	var stick: int = table.number_of("stick")
	var block: int = table.number_of("chopping_block")
	view._world[1] = {"node": null, "number": block, "count": 1, "pos": Vector3(1.6, 0.0, 0.0), "state": 7, "light": null}   # the block, ahead of the cursor
	view._world[2] = {"node": null, "number": stick, "count": 3, "pos": Vector3(-0.6, 0.0, 0.5), "state": 0, "light": null}   # firewood lying beside and behind the player

	var found: Dictionary = view.current_interaction()
	check(str(found.get("kind", "")) == "structure" and bool(found.get("aimed", false)), "the cursor on the block: E is the block's action (%s)" % str(found.get("prompt", "")))
	check(view.cursor_blocks_sweep(), "held E does not sweep while the cursor is on the block")
	net.inventory_action.calls.clear()
	found["tap"].call()
	check(net.inventory_action.calls == [[Net.ACT_USE_STRUCT, 1]], "E splits at the block and picks up nothing else (%s)" % str(net.inventory_action.calls))

	# Facing the loose wood instead: the gather is the cursor's action.
	facing[0] = (Vector3(-0.6, 0.0, 0.5) - eye).normalized()
	found = view.current_interaction()
	check(str(found.get("kind", "")) == "pickup", "the cursor on the wood: E gathers it")
	check(not view.cursor_blocks_sweep(), "held E may sweep when the cursor is on loose wood")

	# Facing nothing with an E action: the nearby pick-up decides (priority order), as before.
	facing[0] = Vector3(0.0, 0.0, 1.0)   # level, at the sky
	found = view.current_interaction()
	check(not bool(found.get("aimed", false)) and str(found.get("kind", "")) == "pickup", "the cursor on nothing: the nearby gather stays")
	check(not view.cursor_blocks_sweep(), "nothing aimed: held E sweeps as before")

	# Two fires or stations: the one in the cursor, not just the nearest.
	view._world.clear()
	view._world[3] = {"node": null, "number": 8, "count": 1, "pos": Vector3(0.8, 0.0, -1.2), "state": 40, "light": null}   # nearer, to the side
	view._world[4] = {"node": null, "number": 8, "count": 1, "pos": Vector3(2.0, 0.0, 0.0), "state": 41, "light": null}   # farther, in the cursor
	facing[0] = (Vector3(2.0, 0.0, 0.0) - eye).normalized()
	check(view._nearest_fire() == 4, "of two fires E takes the one in the cursor")
	facing[0] = (Vector3(0.8, 0.0, -1.2) - eye).normalized()
	check(view._nearest_fire() == 3, "turned to the other, it takes that one")
	view._world[3]["state"] = 40
	view._world.erase(4)
	view.view_direction = Callable()
	check(view._nearest_fire() == 3, "a small fire (state 40) is found like any other")

	print("test_e_priority: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
