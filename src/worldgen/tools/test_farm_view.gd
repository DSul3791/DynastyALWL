extends SceneTree

# The inventory view's bed interaction (GOALS-REPAIR WP-R1B): E on a tilled bed or garden plot sends the request the bed's row and the hand call for (inventory_view._bed_interaction),
# with the right args: ACT_SOW with the seed's pack slot, ACT_WATER_BED with the held container's pack slot as b, ACT_HARVEST; and the crop look follows the row's crop and stage
# (_note_crop): swapped when the stage changes, dropped when the crop goes. The rules behind the wording are in test_farm_prompt.gd; the server's in test_farming.gd.
#   godot --headless --path . --script res://src/worldgen/tools/test_farm_view.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ViewScript := preload("res://src/client/inventory_view.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0


class Rec:
	extends RefCounted
	var calls: Array = []

	func rpc_id(_peer, kind, a, b, _count, _at) -> void:
		calls.append([kind, a, b])


class NetStub:
	extends RefCounted
	var inventory_action: Rec = Rec.new()


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var table = ItemTableScript.load_default()
	var view = ViewScript.new()
	var net = NetStub.new()
	var held: Array = [-1]
	view.net = net
	view.table = table
	view._player_position = func(): return Vector3.ZERO
	view.held_slot_now = func(): return held[0]
	view.inventory = load("res://src/shared/inventory.gd").new(table)
	var inv = view.inventory
	inv.add(table.number_of("flax_seeds"), 3)
	inv.add(table.number_of("wheat_seeds"), 2)
	inv.add(table.number_of("bucket"), 1)
	inv.add(table.number_of("clay_jug"), 1)
	var flax_slot: int = inv.numbers.find(table.number_of("flax_seeds"))
	var wheat_slot: int = inv.numbers.find(table.number_of("wheat_seeds"))
	var bucket_slot: int = inv.numbers.find(table.number_of("bucket"))
	var jug_slot: int = inv.numbers.find(table.number_of("clay_jug"))
	var bed_number: int = table.number_of("tilled_bed")

	# An empty bed: E sows the seed in hand, else the first seed in the pack; the request is ACT_SOW with the bed id and that pack slot.
	view._world[1] = {"node": null, "number": bed_number, "count": 1, "pos": Vector3(1.0, 0.0, 0.0), "state": 47, "light": null}
	var found: Dictionary = view._probe_structure_for(1)
	check(str(found.get("prompt", "")).begins_with("Press E to sow"), "an empty bed with seeds in the pack offers a sow (%s)" % str(found.get("prompt", "")))
	net.inventory_action.calls.clear()
	found["tap"].call()
	check(net.inventory_action.calls == [[Net.ACT_SOW, 1, flax_slot]], "no seed in hand: the first pack seed is sown, ACT_SOW bed 1 slot %d (%s)" % [flax_slot, str(net.inventory_action.calls)])
	held[0] = wheat_slot
	found = view._probe_structure_for(1)
	net.inventory_action.calls.clear()
	found["tap"].call()
	check(str(found["prompt"]).contains("wheat") and net.inventory_action.calls == [[Net.ACT_SOW, 1, wheat_slot]], "wheat seeds in hand are sown before the first pack seed (%s)" % str(net.inventory_action.calls))
	check(not found.has("hold"), "a tilled bed has no hold-E take down")

	# A growing crop: a filled container in hand waters (b = that slot); an empty or no container does not send a request.
	view._world[1]["crop"] = "flax"
	view._world[1]["stage"] = 1
	inv.wear[bucket_slot] = 8000
	held[0] = bucket_slot
	found = view._probe_structure_for(1)
	net.inventory_action.calls.clear()
	found["tap"].call()
	check(str(found["prompt"]).begins_with("Press E to water the flax") and net.inventory_action.calls == [[Net.ACT_WATER_BED, 1, bucket_slot]], "a filled bucket in hand waters: ACT_WATER_BED bed 1, b = the bucket's slot %d (%s)" % [bucket_slot, str(net.inventory_action.calls)])
	inv.wear[jug_slot] = 500
	held[0] = jug_slot
	found = view._probe_structure_for(1)
	net.inventory_action.calls.clear()
	found["tap"].call()
	check(net.inventory_action.calls == [[Net.ACT_WATER_BED, 1, jug_slot]], "the held container is the one named, not the first filled one (b = %d)" % jug_slot)
	inv.wear[jug_slot] = 0
	found = view._probe_structure_for(1)
	check(str(found["prompt"]).begins_with("Flax, young") and not str(found["prompt"]).begins_with("Press E to water"), "an empty container in hand offers no pour: the prompt gives the stage (%s)" % str(found["prompt"]))
	held[0] = flax_slot
	found = view._probe_structure_for(1)
	check(not str(found["prompt"]).begins_with("Press E to sow") and not str(found["prompt"]).begins_with("Press E to water"), "seeds in hand do not sow a bed that has a crop")

	# A ripe crop: ACT_HARVEST, nothing else in the args.
	view._world[1]["stage"] = 3
	found = view._probe_structure_for(1)
	net.inventory_action.calls.clear()
	found["tap"].call()
	check(str(found["prompt"]).begins_with("Press E to harvest the flax") and net.inventory_action.calls == [[Net.ACT_HARVEST, 1, 0]], "a ripe crop is harvested: ACT_HARVEST bed 1 (%s)" % str(net.inventory_action.calls))

	# A garden plot keeps its take-down on hold E.
	view._world[2] = {"node": null, "number": table.number_of("wooden_garden_plot"), "count": 1, "pos": Vector3(0.0, 0.0, 1.0), "state": 157, "light": null}
	check(view._probe_structure_for(2).has("hold") and str(view._probe_structure_for(2).get("prompt", "")).begins_with("Press E to sow"), "a garden plot sows like a bed and still comes down with hold E")

	# The crop look follows the row: made, swapped on a new stage, dropped when the crop goes.
	var node: Node3D = Node3D.new()
	view._world[3] = {"node": node, "number": bed_number, "count": 1, "pos": Vector3.ZERO, "state": 47, "light": null}
	view._note_crop(3, [3, bed_number, 1, Vector3.ZERO, 47, {"yaw": 0.0, "crop": "flax", "stage": 0}])
	var first = view._world[3]["crop_node"]
	check(first is Node3D and node.get_child_count() == 1 and str(view._world[3]["crop"]) == "flax" and int(view._world[3]["stage"]) == 0, "a row with a crop hangs a look on the bed")
	view._note_crop(3, [3, bed_number, 1, Vector3.ZERO, 47, {"yaw": 0.0, "crop": "flax", "stage": 0}])
	check(view._world[3]["crop_node"] == first, "the same crop and stage again leaves the look alone")
	view._note_crop(3, [3, bed_number, 1, Vector3.ZERO, 47, {"yaw": 0.0, "crop": "flax", "stage": 2}])
	var second = view._world[3]["crop_node"]
	check(second != first and first.is_queued_for_deletion() and node.get_child_count() == 2 and int(view._world[3]["stage"]) == 2, "a new stage swaps the look and frees the old one")
	view._note_crop(3, [3, bed_number, 1, Vector3.ZERO, 47, {"yaw": 0.0}])
	check(view._world[3]["crop_node"] == null and second.is_queued_for_deletion() and str(view._world[3]["crop"]) == "", "a row with no crop drops the look")
	print("farm view: %d failures" % failures)
	quit(1 if failures > 0 else 0)
