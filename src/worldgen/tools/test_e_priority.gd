extends SceneTree

# E does what the cursor is on first (Dave 1 Nov 2026): a chopping block in the cursor splits a log and does NOT also pick up the wood around it; the nearby
# pick-up runs only when the cursor is on nothing with an E action; held E does not sweep while the cursor is on something with its own action.
#   godot --headless --path . --script res://src/worldgen/tools/test_e_priority.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ViewScript := preload("res://src/client/inventory_view.gd")
const AutoPickup := preload("res://src/client/auto_pickup.gd")
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
	check(str(found.get("kind", "")) == "block" and bool(found.get("aimed", false)), "the cursor on the block: E is the block's action (%s)" % str(found.get("prompt", "")))
	check(view.cursor_kind() == "block", "the cursor is on the block")
	net.inventory_action.calls.clear()
	found["tap"].call()
	check(net.inventory_action.calls == [[Net.ACT_USE_STRUCT, 1]], "E splits at the block and picks up nothing else (%s)" % str(net.inventory_action.calls))

	# Facing the loose wood instead: the gather is the cursor's action.
	facing[0] = (Vector3(-0.6, 0.0, 0.5) - eye).normalized()
	found = view.current_interaction()
	check(str(found.get("kind", "")) == "pickup", "the cursor on the wood: E gathers it")
	check(view.cursor_kind() == "pickup", "the cursor is on loose wood")

	# Facing nothing with an E action: the nearby pick-up decides (priority order), as before.
	facing[0] = Vector3(0.0, 0.0, 1.0)   # level, at the sky
	found = view.current_interaction()
	check(not bool(found.get("aimed", false)) and str(found.get("kind", "")) == "pickup", "the cursor on nothing: the nearby gather stays")
	check(view.cursor_kind() == "", "nothing aimed")

	# Dave's three cases in every path (tap, hold, auto pickup) with a block and loose wood both in reach.
	view._prompt = Label.new()
	view.inventory = load("res://src/shared/inventory.gd").new(table)
	view.auto_pickup = AutoPickup.new("user://test_e_priority_input.cfg")
	view.auto_pickup.enabled = true
	view._death_msec = -100000
	view._world.clear()
	view._world[1] = {"node": null, "number": block, "count": 1, "pos": Vector3(1.6, 0.0, 0.0), "state": 7, "light": null}
	view._world[2] = {"node": null, "number": stick, "count": 3, "pos": Vector3(-0.6, 0.0, 0.5), "state": 0, "light": null}
	view._world[3] = {"node": null, "number": stick, "count": 1, "pos": Vector3(0.2, 0.0, -0.9), "state": 0, "light": null}
	var calls: Array = net.inventory_action.calls

	# 1. The cursor is on one pickable item: that item only.
	facing[0] = (Vector3(-0.6, 0.0, 0.5) - eye).normalized()
	calls.clear()
	view.current_interaction()["tap"].call()
	check(calls == [[Net.ACT_PICKUP, 2]], "case 1 tap: only the item in the cursor (%s)" % str(calls))
	calls.clear()
	view._hold_next_msec = 0
	check(view.hold_e_step(), "case 1 hold: the cursor is on something, no sweep")
	check(calls == [[Net.ACT_PICKUP, 2]], "case 1 hold: that item and no other (%s)" % str(calls))
	calls.clear()
	view._auto_pickup_tick(Time.get_ticks_msec() + 1000)
	check(calls.is_empty(), "case 1 auto pickup: stays out while the cursor is on a specific item (%s)" % str(calls))

	# 2. The cursor is on the chopping block: the block's action and nothing picked up, in every path.
	facing[0] = (Vector3(1.6, 0.4, 0.0) - eye).normalized()
	calls.clear()
	view.current_interaction()["tap"].call()
	check(calls == [[Net.ACT_USE_STRUCT, 1]], "case 2 tap: only the block (%s)" % str(calls))
	calls.clear()
	view._hold_next_msec = 0
	check(view.hold_e_step() and calls == [[Net.ACT_USE_STRUCT, 1]], "case 2 hold: the block repeats, nothing is picked up (%s)" % str(calls))
	calls.clear()
	view._auto_pickup_tick(Time.get_ticks_msec() + 2000)
	check(calls.is_empty(), "case 2 auto pickup: nothing is picked up beside the block (%s)" % str(calls))

	# 3. The cursor is on nothing specific: the nearby gather may run, in tap, hold and auto pickup.
	facing[0] = Vector3(0.0, 0.0, 1.0)
	calls.clear()
	view.current_interaction()["tap"].call()
	check(calls.size() == 1 and calls[0][0] == Net.ACT_PICKUP, "case 3 tap: the nearby gather runs (%s)" % str(calls))
	check(not view.hold_e_step(), "case 3 hold: the sweep may run")
	calls.clear()
	view._auto_pickup_tick(Time.get_ticks_msec() + 3000)
	check(calls.size() == 1 and calls[0][0] == Net.ACT_PICKUP, "case 3 auto pickup: picks up what is around (%s)" % str(calls))

	# A tool action in progress (a swing) blocks auto pickup whatever the cursor is on.
	view.auto_pickup_blocked = func(): return true
	calls.clear()
	view._auto_pickup_tick(Time.get_ticks_msec() + 6000)
	check(calls.is_empty(), "auto pickup waits while a tool action is in progress")

	# Prompts only in inspection mode (Dave 1 Nov): off, no "Press E" line; on, the line shows; a quiet prompt stays quiet.
	var inspecting: Array = [false]
	view.is_inspecting = func(): return inspecting[0]
	var sample: Dictionary = {"prompt": "Press E to split firewood", "quiet": false}
	check(view.prompt_text(sample) == "", "inspection off: no E prompt text")
	inspecting[0] = true
	check(view.prompt_text(sample) == "Press E to split firewood", "inspection on: the prompt shows")
	check(view.prompt_text({"prompt": "Press E to gather", "quiet": true}) == "", "a quiet prompt stays quiet")
	view.is_inspecting = Callable()
	check(view.prompt_text(sample) == "", "no inspection state known: no prompt")
	inspecting[0] = true
	view.is_inspecting = func(): return inspecting[0]
	var fire_label: String = view._fire_label({"state": 9, "burn": 240.0}, table.number_of("campfire_kit"))
	check(fire_label == "Campfire 00:04:00 Burn time", "the inspect-mode fire label is untouched (%s)" % fire_label)

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
