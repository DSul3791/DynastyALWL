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
	check(view.hold_e_step() and calls.is_empty(), "case 2 hold: aimed at the block, so no sweep, and the split does not repeat (%s)" % str(calls))
	view.current_interaction()["hold"].call()
	check(calls == [[Net.ACT_PICKUP, 1]], "case 2 hold: hold E picks up the block itself, like every structure (Dave 2 Nov 2026) (%s)" % str(calls))
	calls.clear()
	view._auto_pickup_tick(Time.get_ticks_msec() + 2000)
	check(calls.is_empty(), "case 2 auto pickup: nothing is picked up beside the block (%s)" % str(calls))

	# 3. The cursor is on nothing specific: the nearby gather may run, in tap, hold and auto pickup.
	view.sweep_reset()   # E let go between the cases (case 1 took the cursor's item: held E would wait reticle_pause_s first)
	facing[0] = Vector3(0.0, 0.0, 1.0)
	calls.clear()
	view.current_interaction()["tap"].call()
	check(calls.size() == 1 and calls[0][0] == Net.ACT_PICKUP, "case 3 tap: the nearby gather runs (%s)" % str(calls))
	check(not view.hold_e_step(), "case 3 hold: the sweep may run")
	calls.clear()
	view._auto_pickup_tick(Time.get_ticks_msec() + 3000)
	check(calls.size() == 1 and calls[0][0] == Net.ACT_PICKUP, "case 3 auto pickup: picks up what is around (%s)" % str(calls))

	# Dave 10 Nov 2026: held E on an item it cannot take (too heavy, refused) goes on to the next nearest that it can, and "too heavy" is said only when
	# nothing in reach could be taken. After the reticle's own item, held E waits reticle_pause_s (data/items/pickup_batch.json) before the sweep.
	view.sweep_reset()
	facing[0] = (Vector3(-0.6, 0.0, 0.5) - eye).normalized()   # the cursor on the 3 sticks (id 2)
	view._last_pick = 2
	view._on_reject(2)   # the server: too heavy
	check(not view.liftable(2) and not view.hold_e_step(), "held E on a refused item does not hold the sweep up")
	check(int(view.sweep_target(2.0)[0]) == 3, "the sweep goes on to the next nearest item it can take (%s)" % str(view.sweep_target(2.0)))
	view.sweep_reset()
	check(view.liftable(2), "letting E go forgets the refusal")
	view._hold_next_msec = 0
	calls.clear()
	check(view.hold_e_step() and calls == [[Net.ACT_PICKUP, 2]], "held E takes the cursor's item first (%s)" % str(calls))
	var took: Dictionary = view._world[2]
	view._world.erase(2)   # it came up
	facing[0] = Vector3(0.0, 0.0, 1.0)
	check(view.hold_e_step(), "then a pause before the items around (reticle_pause_s %.1f)" % (float(view.reticle_pause_ms()) / 1000.0))
	check(view.reticle_pause_ms() == 2000, "the pause is 2 s, from the json")
	view._reticle_took_msec = Time.get_ticks_msec() - view.reticle_pause_ms() - 1
	check(not view.hold_e_step(), "after the pause the sweep may run")
	view._world[2] = took
	view.sweep_reset()
	# Nothing in reach can be taken: the line comes, once.
	view._sweep_refused[2] = true
	view._sweep_refused[3] = true
	check(int(view.sweep_target(2.0)[0]) == 0 and view._sweep_heavy != 0, "nothing to take, a too heavy one noted")
	view._prompt.text = ""
	view.sweep_nothing()
	check(view._prompt.text == "Too heavy to carry any more", "then it says too heavy (%s)" % view._prompt.text)
	view._prompt.text = ""
	view.sweep_nothing()
	check(view._prompt.text == "", "once a hold")
	view.sweep_reset()

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

	# Dave 21 Nov 2026: "Im looking straight at something I want to pick up and i press e but it puts out the fire or lights the smelter or picks up
	# something else. it should always effect whatever is closest to my reticle first." The prompt and E are the same thing, the one nearest the reticle.
	view.view_direction = func(): return facing[0]
	view._world.clear()
	view.sweep_reset()
	var stone: int = table.number_of("stone") if table.has_id("stone") else stick
	var aim_at: Callable = func(p: Vector3): facing[0] = (p - eye).normalized()

	# 1. An item beside a lit campfire, with another item nearer the feet but off to the side: E takes the item looked at, not the fire, not the nearer item.
	view._world[10] = {"node": null, "number": 8, "count": 1, "pos": Vector3(1.2, 0.0, 0.35), "state": 1, "light": null}   # a burning campfire, just beside the line of sight
	view._world[11] = {"node": null, "number": stick, "count": 1, "pos": Vector3(1.4, 0.0, 0.0), "state": 0, "light": null}   # the stick looked at
	view._world[12] = {"node": null, "number": stone, "count": 1, "pos": Vector3(0.1, 0.0, -0.7), "state": 0, "light": null}   # nearer, off to the side
	aim_at.call(Vector3(1.4, 0.0, 0.0))
	check(view.in_aim(view.aim_point(10, Vector3.ZERO)), "the setup: the fire is in the aim cone too, so it competes")
	found = view.current_interaction()
	check(str(found.get("kind", "")) == "pickup" and int(found.get("id", 0)) == 11, "item beside a lit fire: the item looked at wins (%s %s)" % [str(found.get("kind", "")), str(found.get("id", ""))])
	calls.clear()
	found["tap"].call()
	check(calls == [[Net.ACT_PICKUP, 11]], "item beside a lit fire: E picks it up and does not put the fire out (%s)" % str(calls))
	aim_at.call(view.aim_point(10, Vector3.ZERO))
	found = view.current_interaction()
	check(str(found.get("kind", "")) == "fire" and str(found.get("prompt", "")) == view._fire_prompt(1), "looking at the fire itself: the fire's action and its prompt (%s)" % str(found.get("prompt", "")))

	# 2. An item a little farther than a smelter beside it (2.6 m, past the 2 m prompt reach and 2.5 m pick reach): the item looked at still wins.
	view._world.clear()
	view.sweep_reset()
	view._world[20] = {"node": null, "number": table.number_of("smelter") if table.has_id("smelter") else 8, "count": 1, "pos": Vector3(2.1, 0.0, 0.5), "state": 240, "light": null}   # cold smelter
	view._world[21] = {"node": null, "number": stick, "count": 1, "pos": Vector3(2.6, 0.0, 0.0), "state": 0, "light": null}
	aim_at.call(Vector3(2.6, 0.0, 0.0))
	check(view.in_aim(view.aim_point(20, Vector3.ZERO)), "the setup: the smelter is in the aim cone too")
	found = view.current_interaction()
	check(str(found.get("kind", "")) == "pickup" and int(found.get("id", 0)) == 21, "item beside a smelter: the item looked at wins (%s)" % str(found.get("prompt", "")))
	calls.clear()
	found["tap"].call()
	check(calls == [[Net.ACT_PICKUP, 21]], "item beside a smelter: E picks it up and does not light the smelter (%s)" % str(calls))
	aim_at.call(view.aim_point(20, Vector3.ZERO))
	found = view.current_interaction()
	check(str(found.get("kind", "")) == "structure" and str(found.get("prompt", "")) == "Press E to light", "looking at the smelter: \"Press E to light\" (%s)" % str(found.get("prompt", "")))

	# 3. Two items close together: the one the reticle is on, though the other is nearer the player; turning to the other takes that one.
	view._world.clear()
	view.sweep_reset()
	view._world[30] = {"node": null, "number": stick, "count": 1, "pos": Vector3(1.0, 0.0, 0.15), "state": 0, "light": null}
	view._world[31] = {"node": null, "number": stone, "count": 1, "pos": Vector3(1.3, 0.0, -0.15), "state": 0, "light": null}
	aim_at.call(Vector3(1.3, 0.0, -0.15))
	found = view.current_interaction()
	check(int(found.get("id", 0)) == 31, "two items close together: the one looked at, not the nearer (%s)" % str(found.get("id", "")))
	check(view.cursor_kind() == "pickup", "the cursor is on it")
	calls.clear()
	view._hold_next_msec = 0
	check(view.hold_e_step() and calls == [[Net.ACT_PICKUP, 31]], "held E takes the one looked at too (%s)" % str(calls))
	aim_at.call(Vector3(1.0, 0.0, 0.15))
	check(int(view.current_interaction().get("id", 0)) == 30, "turned to the other, it takes that one")
	facing[0] = Vector3(0.3, 0.0, 1.0).normalized()   # the reticle on nothing (item 30 in view, far outside the aim cone): the nearest, as before (Dave's case 3)
	check(int(view.current_interaction().get("id", 0)) == 30 and not bool(view.current_interaction().get("aimed", false)), "the reticle on nothing: the nearest item, unaimed")

	# 4. Two stations side by side: the one the reticle is on, though the other is nearer.
	view._world.clear()
	view._world[40] = {"node": null, "number": 8, "count": 1, "pos": Vector3(1.0, 0.0, 0.6), "state": 240, "light": null}
	view._world[41] = {"node": null, "number": 8, "count": 1, "pos": Vector3(2.0, 0.0, -0.3), "state": 240, "light": null}
	aim_at.call(view.aim_point(41, Vector3.ZERO))
	check(view._nearest_struct(true) == 41, "of two stations the one looked at, not the nearer")

	# reticle_index: the best centred inside the cone; none in the cone is -1.
	facing[0] = Vector3(1.0, 0.0, 0.0)
	check(view.reticle_index([Vector3(2.0, 1.6, 0.5), Vector3(2.0, 1.6, 0.1), Vector3(-2.0, 1.6, 0.0)]) == 1, "reticle_index: the best centred point")
	check(view.reticle_index([Vector3(0.0, 1.6, 2.0)]) == -1, "reticle_index: nothing in the cone")

	print("test_e_priority: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
