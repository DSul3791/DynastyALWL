extends SceneTree

# A trap's catch lies in the trap (Dave 25 Nov 2026: "they should lay in the snare and if you press E on the snare with an animal in it you collect
# the animal and reset the snare"). Looking at a snare that holds a whole catch, E is the snare's: "Press E to collect the rabbit and reset the
# snare", sent as the snare's use; the carcass in it is not offered on its own. A snared carcass put down elsewhere is picked up with E; a cut
# one says to use the knife; an empty snare is as before.
#   godot --headless --path . --script res://src/worldgen/tools/test_trap_collect_prompt.gd

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
	view._prompt = Label.new()
	view._player_position = func(): return Vector3.ZERO
	var facing: Array = [Vector3(1.5, -1.6, 0.0).normalized()]
	view.view_direction = func(): return facing[0]
	var snare_state: int = 46   # structures.json snare_trap
	check(str(view._structure_by_state(snare_state).get("item", "")) == "snare_trap", "state 46 is the snare")
	view._world[1] = {"node": null, "number": table.number_of("snare_trap"), "count": 1, "pos": Vector3(1.5, 0.0, 0.0), "state": snare_state, "light": null, "catch": 2}
	view._world[2] = {"node": null, "number": table.number_of("carcass"), "count": 1, "pos": Vector3(1.5, 0.0, 0.0), "state": 19, "light": null, "sp": "rabbit", "whole": true}

	check(view._nearest_struct(true) == 1, "E aims at the snare, not the carcass in it (%d)" % view._nearest_struct(true))
	var found: Dictionary = view._probe_structure_for(1)
	check(str(found.get("prompt", "")).begins_with("Press E to collect the rabbit and reset the snare"), "the snare offers its catch (%s)" % str(found.get("prompt", "")))
	net.inventory_action.calls.clear()
	found["tap"].call()
	check(net.inventory_action.calls == [[Net.ACT_USE_STRUCT, 1]], "E sends the snare's use (%s)" % str(net.inventory_action.calls))

	# Cut once: the knife finishes it.
	view._world[2]["whole"] = false
	check(str(view._probe_structure_for(1).get("prompt", "")).begins_with("Finish cutting the rabbit"), "a cut catch says to finish it with the knife (%s)" % str(view._probe_structure_for(1).get("prompt", "")))

	# Empty: as before.
	view._world.erase(2)
	view._world[1].erase("catch")
	check(str(view._probe_structure_for(1).get("prompt", "")).begins_with("Hold E to take down"), "an empty snare is taken down as before (%s)" % str(view._probe_structure_for(1).get("prompt", "")))

	# A whole catch laid on the ground: E picks it up; a hunted or cut one is for the knife.
	view._world[3] = {"node": null, "number": table.number_of("carcass"), "count": 1, "pos": Vector3(1.5, 0.0, 2.0), "state": 19, "light": null, "sp": "rabbit", "whole": true}
	found = view._probe_structure_for(3)
	check(str(found.get("prompt", "")) == "Press E to pick up the rabbit", "a whole rabbit on the ground is picked up with E (%s)" % str(found.get("prompt", "")))
	net.inventory_action.calls.clear()
	found["tap"].call()
	check(net.inventory_action.calls == [[Net.ACT_PICKUP, 3]], "E sends the pick-up (%s)" % str(net.inventory_action.calls))
	view._world[3]["whole"] = false
	check(str(view._probe_structure_for(3).get("prompt", "")) == "Cut the rabbit with a knife", "a hunted or cut carcass is for the knife (%s)" % str(view._probe_structure_for(3).get("prompt", "")))

	# Through the world sync, as the server sends it: a snare seen empty, then re-sent holding a catch with the carcass added, then the catch cut,
	# then the snare emptied. The rows keep their state, so the client keeps their entries and must take the new extras.
	view._world.clear()
	var scene_root: Node3D = Node3D.new()
	get_root().add_child.call_deferred(scene_root)
	view._root = scene_root
	view._ground_below = func(_at: Vector3) -> float: return 0.0
	var snare_row: Array = [11, table.number_of("snare_trap"), 1, Vector3(1.5, 0.0, 0.0), snare_state, {"yaw": 0.0, "age": 0.0, "sp": "", "lit": false}]
	var body_row: Array = [12, table.number_of("carcass"), 1, Vector3(1.5, 0.0, 0.0), 19, {"yaw": 0.0, "age": 0.0, "sp": "rabbit", "lit": false, "whole": true}]
	view._on_world_items([snare_row], PackedInt32Array())
	check(str(view._probe_structure_for(11).get("prompt", "")).begins_with("Hold E to take down"), "synced: the empty snare is taken down (%s)" % str(view._probe_structure_for(11).get("prompt", "")))
	var held_row: Array = snare_row.duplicate(true)
	held_row[5]["catch"] = 12
	view._on_world_items([held_row, body_row], PackedInt32Array())
	check(view._nearest_struct(true) == 11 and str(view._probe_structure_for(11).get("prompt", "")).begins_with("Press E to collect the rabbit and reset the snare"), "synced: a catch made while you stand there is offered at the snare (%s)" % str(view._probe_structure_for(11).get("prompt", "")))
	var cut_row: Array = body_row.duplicate(true)
	cut_row[5].erase("whole")
	view._on_world_items([cut_row], PackedInt32Array())
	check(str(view._probe_structure_for(11).get("prompt", "")).begins_with("Finish cutting"), "synced: once cut it is for the knife (%s)" % str(view._probe_structure_for(11).get("prompt", "")))
	view._on_world_items([snare_row], PackedInt32Array([12]))
	check(not view._world[11].has("catch") and str(view._probe_structure_for(11).get("prompt", "")).begins_with("Hold E to take down"), "synced: emptied, the snare holds nothing again (%s)" % str(view._probe_structure_for(11).get("prompt", "")))

	view._prompt.free()
	view.free()
	scene_root.queue_free()
	print("Test done: %s" % ("pass" if failures == 0 else "%d fail" % failures))
	quit(1 if failures > 0 else 0)
