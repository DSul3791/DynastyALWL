extends SceneTree

# The pointer hotbar and craft queue requests (docs/design/INVENTORY_CRAFTING_REPORT.md step 4; decisions in docs/design/OVERNIGHT_DECISIONS_8NOV.md row 24, 8 Nov 2026).
# Keys 1 to 9 and 0 hold item numbers, not pack slots: sorting and moving never change them. A key points at the pack slot holding its item (an unbroken one
# first). A tool or weapon new in the pack goes on the first empty key, unless a key already holds it; food and materials do not. A key whose item has run
# out keeps it, dimmed, and the next one comes back to it. ACT_HOTBAR_SET puts any item on a key (one key per item). "On the hotbar" for tools means a key
# points at it. The keys are saved with the character; a character saved before them gets the items of its old slots 1 to 10, once. The pack fills from
# slot 1. A craft of several is one queue request (the click rule of row 24 (7) was replaced on 12 Nov 2026: test_craft_click.gd).
#   godot --headless --path . --script res://src/worldgen/tools/test_hotbar_keys.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")

var failures: int = 0
var items
var keys_sent: Dictionary = {}   # peer -> the last hotbar rpc
var axe: int = 0
var knife: int = 0
var clay: int = 0
var stone: int = 0
var berries: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func pack():
	return items.inventory_of(1)


func keys() -> Array:
	return Array(pack().hotbar)


func give(number: int, count: int = 1) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, number, 0, count, Vector3.ZERO)


func make_items(dir: String):
	var w = ItemsScript.new()
	w.send_full = func(_p, _b): pass
	w.send_slots = func(_p, _b): pass
	w.send_world_items = func(_p, _a, _r): pass
	w.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	w.send_notice = func(_p, _t): pass
	w.send_carry = func(_p, _id): pass
	w.send_chest = func(_p, _id, _b): pass
	w.send_hotbar = func(p, k): keys_sent[p] = Array(k)
	w.ground_height = func(_x, _z): return 10.0
	w.setup(ItemTableScript.load_default(), dir)
	return w


func _init() -> void:
	var dir: String = "user://test_hotbar_keys"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = make_items(dir)
	items.admin_ok = func(_p): return true
	items.peer_connected_hello(1, "hotbarkeys01")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 2000.0
	axe = items.table.number_of("stone_axe")
	knife = items.table.number_of("stone_knife")
	clay = items.table.number_of("clay")
	stone = items.table.number_of("stone")
	berries = items.table.number_of("berries") if items.table.number_of("berries") > 0 else items.table.number_of("raw_meat")
	check(axe > 0 and knife > 0 and clay > 0 and stone > 0 and berries > 0, "the test items are in the table")
	check(Net.PROTOCOL_VERSION >= 100 and Net.ACT_HOTBAR_SET == 68, "protocol 100: ACT_HOTBAR_SET 68")
	check(keys_sent.has(1) and keys().size() == 10 and keys().count(0) == 10, "a new character has ten empty keys and is told them at the join")

	for slot in pack().SLOTS:
		pack().numbers[slot] = 0
		pack().counts[slot] = 0
		pack().wear[slot] = 0

	# 1. The pack fills from slot 1; a tool new in the pack goes on the first empty key, food and materials do not.
	give(clay, 3)
	check(pack().numbers[0] == clay and keys().count(0) == 10, "clay goes to slot 1 and on no key")
	give(axe)
	var axe_slot: int = pack().numbers.find(axe)
	check(keys()[0] == axe and pack().key_slot(0) == axe_slot and keys_sent[1][0] == axe, "a new axe goes on key 1, which points at its slot (%d)" % axe_slot)
	give(berries, 2)
	check(not keys().has(berries), "food goes on no key by itself")
	give(knife)
	check(keys()[1] == knife, "a new knife goes on the next empty key")
	give(axe)
	check(keys().count(axe) == 1 and keys()[2] == 0, "a second axe takes no second key")

	# 2. Sorting and moving never change the keys; the key follows its item.
	items.action(1, Net.ACT_MOVE, axe_slot, 25, 0, Vector3.ZERO)
	check(keys()[0] == axe and pack().numbers[pack().key_slot(0)] == axe, "moving the axe leaves key 1 on the axe, wherever it lies")
	items.action(1, Net.ACT_BULK, 3, 1, 0, Vector3.ZERO)
	check(keys()[0] == axe and keys()[1] == knife and pack().numbers[pack().key_slot(1)] == knife, "Sort leaves every key as it was")

	# 3. An unbroken one first; a key whose item has gone keeps it (dimmed) and the next one comes back to it.
	var first_axe: int = pack().numbers.find(axe)
	var other_axe: int = -1

	for slot in pack().SLOTS:
		if slot != first_axe and pack().numbers[slot] == axe:
			other_axe = slot

	pack().wear[first_axe] = 100000
	check(pack().key_slot(0) == other_axe, "with one axe worn out the key points at the unbroken one")
	pack().wear[first_axe] = 0
	pack().take_from_slot(first_axe, 1)
	pack().take_from_slot(other_axe, 1)
	check(keys()[0] == axe and pack().key_slot(0) == -1, "with no axe left key 1 keeps it and points at nothing")
	give(axe)
	check(keys()[0] == axe and keys().count(axe) == 1 and pack().key_slot(0) == pack().numbers.find(axe), "a new axe comes back to key 1")

	# 4. Keys by hand: any item, one key per item, 0 clears, a bad key is ignored.
	items.action(1, Net.ACT_HOTBAR_SET, 4, stone, 0, Vector3.ZERO)
	check(keys()[4] == stone and keys_sent[1][4] == stone, "a stone can be put on key 5 by hand")
	items.action(1, Net.ACT_HOTBAR_SET, 6, axe, 0, Vector3.ZERO)
	check(keys()[6] == axe and keys()[0] == 0, "putting the axe on key 7 takes it off key 1")
	items.action(1, Net.ACT_HOTBAR_SET, 4, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_HOTBAR_SET, 12, knife, 0, Vector3.ZERO)
	check(keys()[4] == 0 and keys()[1] == knife, "0 clears a key; key 13 does not exist")

	# 5. "On the hotbar" for tools: a key points at it.
	check(items._tool_slot(pack(), "axe") == pack().numbers.find(axe), "the axe on key 7 counts as on the hotbar")
	items.action(1, Net.ACT_HOTBAR_SET, 6, 0, 0, Vector3.ZERO)
	check(items._tool_slot(pack(), "axe") < 0, "off every key it does not, wherever it lies in the pack")
	items.action(1, Net.ACT_HOTBAR_SET, 0, axe, 0, Vector3.ZERO)

	# 6. Saved with the character and back after a restart.
	var saved_keys: Array = keys()
	items.save()
	items._finish_writer()
	var again = make_items(dir)
	keys_sent.clear()
	again.peer_connected_hello(1, "hotbarkeys01")
	check(Array(again.inventory_of(1).hotbar) == saved_keys and keys_sent.has(1), "the keys are saved and sent again at the next join")

	# 7. A character saved before the keys: the items in its old slots 1 to 10 become its keys, once.
	again._characters["hotbarkeys01"].erase("hotbar")
	var old_pack = again.inventory_of(1)

	for slot in old_pack.SLOTS:
		old_pack.numbers[slot] = 0
		old_pack.counts[slot] = 0
		old_pack.wear[slot] = 0

	old_pack.numbers[0] = knife
	old_pack.counts[0] = 1
	old_pack.numbers[3] = stone
	old_pack.counts[3] = 5
	old_pack.numbers[12] = axe
	old_pack.counts[12] = 1
	again.peer_connected_hello(1, "hotbarkeys01")
	var migrated: Array = Array(again.inventory_of(1).hotbar)
	check(migrated[0] == knife and migrated[3] == stone and not migrated.has(axe) and again._characters["hotbarkeys01"].has("hotbar"), "old slots 1 to 10 become the keys (knife on 1, stone on 4); slot 13's axe does not")
	old_pack.numbers[0] = 0
	old_pack.counts[0] = 0
	again.peer_connected_hello(1, "hotbarkeys01")
	check(Array(again.inventory_of(1).hotbar)[0] == knife, "only once: the next join keeps the keys")

	var pot_recipe: int = 0

	for k in items.recipes.numbers():
		if str(items.recipes.recipe(int(k)).get("id", "")) == "clay_pot":
			pot_recipe = int(k)

	items.recipes.recipe(pot_recipe)["station"] = ""   # the pot is fired at a campfire now (recipe audit 10 Nov 2026); this test is about the craft, not the station

	give(clay, 60)
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, pot_recipe, 0, 5, Vector3.ZERO)
	var queued: Array = items.craft_queue_of(1)
	check(pot_recipe > 0 and queued.size() == 1 and int(queued[0][1]) == 5, "five pots (the Craft button's quantity) go in one queue request (%s)" % str(queued))
	items.action(1, Net.ACT_CRAFT_QUEUE, pot_recipe, 0, 1, Vector3.ZERO)
	check(int(items.craft_queue_of(1)[0][1]) == 5 and items.craft_queue_of(1).size() == 1, "a second request straight after is paced away: why a craft of several is one request")

	# 9. A torch and the same torch put out are one item to a key (items.json doused_item / relit_item): rain turns the slot into the doused torch while
	# the key keeps the burning torch's number, and pressing the key must still find it to light it again (the eat run's torch_doused, 9 Nov 2026).
	var torch: int = items.table.number_of("torch")
	var doused: int = items.table.number_of("torch_doused")
	var bag = InventoryScript.new(items.table)
	bag.numbers[4] = torch
	bag.counts[4] = 1
	bag.hotbar[2] = torch
	check(torch > 0 and doused > 0 and bag.key_slot(2) == 4 and bag.key_of_slot(4) == 2, "the burning torch is on key 3")
	bag.numbers[4] = doused
	check(bag.key_slot(2) == 4 and bag.key_of_slot(4) == 2, "put out by the rain, it is still key 3's (slot %d)" % bag.key_slot(2))
	bag.hotbar[2] = doused
	bag.numbers[4] = torch
	check(bag.key_slot(2) == 4 and bag.key_of_slot(4) == 2, "a key given the doused torch finds it lit again")
	bag.numbers[4] = stone
	check(bag.key_slot(2) == -1 and bag.key_of_slot(4) == -1, "no torch at all: the key points nowhere")

	print("hotbar keys: %s" % ("all passed" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
