extends SceneTree

# Food on the hotbar is eaten straight from it (Dave's play test 19 Nov 2026: "if you click on food in a hotbar or hold down the hotbar key on a food
# item it should just eat the food and keep eating it like holding E in the inventory"). Its number key (HeldItem.press_slot) or a click on its box
# (InventoryView.eat_from_hotbar) sends one bite through the same ACT_EAT and hold as E in the pack, the hand keeps what it held, a non-food key is
# left to the hand, and the hold goes on bite by bite only while the key or button is held and the slot still holds that food.
#   godot --headless --path . --script res://src/worldgen/tools/test_hotbar_eat.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ViewScript := preload("res://src/client/inventory_view.gd")
const HeldScript := preload("res://src/client/held_item.gd")
const VitalsRules := preload("res://src/shared/vitals_rules.gd")
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
	view.net = net
	view.table = table
	view._vitals_cfg = VitalsRules.load_config()
	view.inventory = load("res://src/shared/inventory.gd").pack(table)   # pack(): the ten hotbar keys
	var inv = view.inventory
	var berries: int = table.number_of("raspberries")
	inv.numbers[0] = table.number_of("stone_axe")
	inv.counts[0] = 1
	inv.numbers[2] = berries
	inv.counts[2] = 5
	check(berries > 0 and view.edible_slot(2) and not view.edible_slot(0), "raspberries are food, the axe is not")

	# A non-food key is left to the hand.
	check(not view.eat_from_hotbar(0) and net.inventory_action.calls.is_empty(), "the axe's key sends no bite")
	check(not view.eat_from_hotbar(5) and net.inventory_action.calls.is_empty(), "an empty key sends no bite")

	# The number key: one bite through the pack's own eat request; the hand keeps the axe.
	var held = HeldScript.new()
	held._inv = view
	held.holding = true
	held.held_key = 0
	held.press_slot(2)
	check(net.inventory_action.calls == [[Net.ACT_EAT, 2, 0]], "key 3 on raspberries sends one bite of slot 2 (%s)" % str(net.inventory_action.calls))
	check(held.holding and held.held_key == 0, "the axe stays in hand")
	check(view._eat_hold_slot == 2, "the hold starts on that slot")

	# A quick tap: the key is up by the next frame, so the hold ends after the one bite (headless, no key is down).
	view._eat_hold_tick(Time.get_ticks_msec() + 5000)
	check(view._eat_hold_slot == -1 and net.inventory_action.calls.size() == 1, "a tap eats one bite")

	# A click on the box: nothing on the press itself, one bite when the button comes up on the box without a drag (headless, no button is down).
	net.inventory_action.calls.clear()
	view.open = true
	view.hotbar_hover = 2
	check(view.eat_from_hotbar(2, true) and net.inventory_action.calls.is_empty(), "pressing the box sends nothing yet")
	view._hotbar_press_tick(Time.get_ticks_msec())
	check(net.inventory_action.calls == [[Net.ACT_EAT, 2, 0]] and view._eat_hold_slot == -1 and view._hotbar_press.is_empty(), "let go on the box: one bite, no hold")

	# A press that leaves the box (a drag to the pack) eats nothing.
	net.inventory_action.calls.clear()
	view.eat_from_hotbar(2, true)
	view.hotbar_hover = -1
	view._hotbar_press_tick(Time.get_ticks_msec())
	check(net.inventory_action.calls.is_empty() and view._hotbar_press.is_empty(), "a press dragged off the box eats nothing")
	view.hotbar_hover = 2

	# Held: the next bite goes only once the last one landed (the slot changed) and the server's pace has passed.
	held.press_slot(2)
	check(net.inventory_action.calls.size() == 1, "the key again: one bite")
	view._eat_hold_still = func() -> bool: return true   # stands for the key held down
	var sent: int = view._eat_hold_sent_msec
	var pace: int = view._eat_hold_pace(2)
	view._eat_hold_tick(sent + pace + 10)
	check(net.inventory_action.calls.size() == 1, "no second bite before the first landed")
	inv.counts[2] = 4   # the server applied the bite
	view._eat_hold_tick(sent + pace - 1)
	check(net.inventory_action.calls.size() == 1, "nor sooner than the server's pace")
	view._eat_hold_tick(sent + pace + 10)
	check(net.inventory_action.calls.size() == 2 and net.inventory_action.calls[1] == [Net.ACT_EAT, 2, 0], "held, the next bite follows")

	# The last berry eaten: the slot is empty and the hold ends.
	inv.numbers[2] = 0
	inv.counts[2] = 0
	view._eat_hold_tick(sent + 5 * pace)
	check(view._eat_hold_slot == -1 and net.inventory_action.calls.size() == 2, "an emptied slot ends the hold")

	# Let go: the hold ends.
	inv.numbers[2] = berries
	inv.counts[2] = 3
	held.press_slot(2)
	view._eat_hold_still = func() -> bool: return false
	view._eat_hold_tick(view._eat_hold_sent_msec + 5 * pace)
	check(view._eat_hold_slot == -1 and net.inventory_action.calls.size() == 3, "letting go ends the hold")

	print("hotbar eat: %d failures" % failures)
	quit(1 if failures > 0 else 0)
