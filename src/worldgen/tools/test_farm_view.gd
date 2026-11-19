extends SceneTree

# The inventory view's bed interaction (GOALS-REPAIR WP-R1B): E on a tilled bed or garden plot sends the request the bed's row and the hand call for (inventory_view._bed_interaction),
# with the right args: never a sow (Dave play test 19 Nov 2026: only the hoe's Plant grid sows), ACT_WATER_BED with the held container's pack slot as b, ACT_HARVEST; and the crop
# look follows the row's crop and stage (_note_crop): swapped when the stage changes, dropped when the crop goes, the wild plant's model when the flora has one, drawn again
# once the flora models are built; and the hoe Garden mode's bed lookup (bed_id_at, bed_crop). The rules behind the wording are in test_farm_prompt.gd; the server's in test_farming.gd.
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
	var said: Array = []
	view.notice_event = func(t): said.append(t)
	view._prompt = Label.new()   # setup() is not run here: the notice line a "none" tap shows
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

	# An empty bed: E sends nothing, with seeds in the pack or in hand; it says the hoe's Plant grid sows (Dave play test 19 Nov 2026).
	view._world[1] = {"node": null, "number": bed_number, "count": 1, "pos": Vector3(1.0, 0.0, 0.0), "state": 47, "light": null}
	var found: Dictionary = view._probe_structure_for(1)
	net.inventory_action.calls.clear()
	found["tap"].call()
	check(str(found.get("prompt", "")).contains("hoe") and net.inventory_action.calls.is_empty() and said.size() == 1 and str(said[0]).contains("hoe"), "an empty bed with seeds in the pack sends nothing and points to the hoe (%s, %s)" % [str(found.get("prompt", "")), str(net.inventory_action.calls)])
	held[0] = wheat_slot
	found = view._probe_structure_for(1)
	net.inventory_action.calls.clear()
	found["tap"].call()
	check(not str(found["prompt"]).contains("Press E to sow") and net.inventory_action.calls.is_empty(), "wheat seeds in hand sow nothing either (%s)" % str(net.inventory_action.calls))
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
	check(view._probe_structure_for(2).has("hold") and str(view._probe_structure_for(2).get("prompt", "")).contains("hoe"), "a garden plot says the hoe sows it, like a bed, and still comes down with hold E")

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

	# The wild plant's model (Dave play test 19 Nov 2026: the seedlings were green boxes though the plant has a model): a crop the flora knows wears it, a crop it does not
	# (wheat) wears its painted card without asking; one drawn while the flora models were still being built waits and is drawn again once they are.
	var ready: Array = [false]
	var asked: Array = []
	view.crop_model = func(crop: String, share: float, spots: Array):
		asked.append([crop, share, spots.size()])
		return Node3D.new() if ready[0] and crop == "chamomile" else null
	view.crop_models_ready = func(): return ready[0]
	view._note_crop(3, [3, bed_number, 1, Vector3.ZERO, 47, {"yaw": 0.0, "crop": "chamomile", "stage": 0}])
	var early: Node3D = view._world[3]["crop_node"]
	check(bool(early.get_meta("placeholder", false)) and view._crop_looks_waiting.has(3) and asked.size() == 1 and asked[0][0] == "chamomile" and asked[0][1] < 0.5 and asked[0][2] == 4, "flora not built yet: a placeholder for now and the bed waits (%s)" % str(asked))
	ready[0] = true
	view._crop_looks_msec = 0
	view._redo_crop_looks()
	var real: Node3D = view._world[3]["crop_node"]
	check(real != early and early.is_queued_for_deletion() and not bool(real.get_meta("placeholder", true)) and view._crop_looks_waiting.is_empty() and str(view._world[3]["crop"]) == "chamomile", "once the flora is built the seedling wears the chamomile model")
	var asks_before: int = asked.size()
	view._note_crop(3, [3, bed_number, 1, Vector3.ZERO, 47, {"yaw": 0.0, "crop": "wheat", "stage": 1}])
	check(not bool(view._world[3]["crop_node"].get_meta("placeholder", true)) and view._crop_looks_waiting.is_empty() and asked.size() == asks_before, "wheat has no wild plant: it wears its painted card at once, never asks the flora and nothing waits")
	view._note_crop(3, [3, bed_number, 1, Vector3.ZERO, 47, {"yaw": 0.0}])
	view.crop_model = Callable()
	view.crop_models_ready = Callable()

	# The hoe's Garden mode finds the bed under the crosshair by footprint (inventory_view.bed_id_at): a 1 m bed and a 2 m plot, a plot's blueprint site is skipped.
	view._world.clear()
	view._world[10] = {"node": null, "number": bed_number, "count": 1, "pos": Vector3(0.5, 0.0, 0.5), "state": 47, "yaw": 0.0, "light": null}
	view._world[11] = {"node": null, "number": table.number_of("wooden_garden_plot"), "count": 1, "pos": Vector3(10.0, 0.0, 10.0), "state": 157, "yaw": 0.0, "light": null, "crop": "wheat"}
	view._world[12] = {"node": null, "number": table.number_of("wooden_garden_plot"), "count": 1, "pos": Vector3(20.0, 0.0, 20.0), "state": 157, "yaw": 0.0, "light": null, "site": {}}
	check(view.bed_id_at(Vector3(0.5, 0.0, 0.5)) == 10 and view.bed_id_at(Vector3(0.95, 0.0, 0.1)) == 10 and view.bed_id_at(Vector3(1.2, 0.0, 0.5)) == 0, "bed_id_at: a 1 m bed holds its own square and not 0.7 m out")
	check(view.bed_id_at(Vector3(10.9, 0.0, 9.1)) == 11 and view.bed_id_at(Vector3(11.3, 0.0, 10.0)) == 0, "bed_id_at: a 2 m plot holds its corner and not 1.3 m out")
	check(view.bed_id_at(Vector3(20.0, 0.0, 20.0)) == 0, "bed_id_at: a plot still a blueprint site is not a bed")
	check(view.bed_crop(11) == "wheat" and view.bed_crop(10) == "" and view.bed_crop(99) == "", "bed_crop reads the row's crop, empty for none or an unknown id")
	# A plot holds a crop on each square metre (Dave 14 Nov 2026: Medium 4): the row's cells, in the server's order (across, then along); the grid reads the one it aims at.
	view._world[11]["cells"] = [["wheat", 1], ["", -1], ["", -1], ["barley", 2]]
	check(view.bed_cell_index(11, Vector3(9.6, 0.0, 9.4)) == 0 and view.bed_cell_index(11, Vector3(10.4, 0.0, 9.6)) == 1 and view.bed_cell_index(11, Vector3(10.6, 0.0, 10.7)) == 3 and view.bed_cell_index(10, Vector3(0.5, 0.0, 0.5)) == 0 and view.bed_cell_index(99, Vector3.ZERO) == -1, "bed_cell_index: a Medium plot's four square metres, a 1 m bed's one, -1 for an unknown id")
	check(view.bed_crop(11, Vector3(9.6, 0.0, 9.4)) == "wheat" and view.bed_crop(11, Vector3(10.4, 0.0, 9.6)) == "" and view.bed_crop(11, Vector3(10.6, 0.0, 10.7)) == "barley", "bed_crop at a point reads that square metre's crop")
	var near_rows: Array = view.bed_rows(Vector3(0.0, 0.0, 0.0), 3.0)
	check(near_rows.size() == 1 and int(near_rows[0][0]) == 10 and view.bed_rows().size() == 2, "bed_rows near a point keeps only the beds within reach (the site is never a bed)")
	view._prompt.free()
	print("farm view: %d failures" % failures)
	quit(1 if failures > 0 else 0)
