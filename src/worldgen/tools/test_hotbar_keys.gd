extends SceneTree

# The hotbar as real slots (Dave's playtest 12 Nov 2026, TEST-008 and TEST-006; replaces the 8 Nov pointer hotbar, OVERNIGHT_DECISIONS_8NOV.md row 24).
# Keys 1 to 9 and 0 are the pack's slots 0 to 9 and the backpack is slots 10 and up (20 at least, more as it fills, protocol 113): an item is in one place only. Pickups fill the backpack first. A tool or
# weapon whose kind is new in the pack moves into the first empty hotbar slot; food, materials and a second axe do not. ACT_MOVE moves a stack into the
# hotbar and back. A hotbar slot whose item is dropped, sold or used up is empty. "On the hotbar" for tools means in slots 0 to 9. Sort leaves the
# hotbar. The slots are saved with the pack; characters.json keeps no "hotbar". A craft of several is one queue request (test_craft_click.gd has the click rule).
#   godot --headless --path . --script res://src/worldgen/tools/test_hotbar_keys.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")

var failures: int = 0
var items
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


func give(number: int, count: int = 1) -> void:
	items.action(1, Net.ACT_ADMIN_GIVE, number, 0, count, Vector3.ZERO)


# A pickup as the server makes one: into the pack (backpack first), then the changes sent (where a new tool moves to the hotbar).
func pick_up(number: int, count: int = 1) -> void:
	var before: Array = items._snapshot(pack())
	pack().add(number, count)
	items._send_changes(1, pack(), before)


func empty_pack() -> void:
	for slot in pack().slot_count:
		pack().clear_slot(slot)


func make_items(dir: String):
	var w = ItemsScript.new()
	w.send_full = func(_p, _b): pass
	w.send_slots = func(_p, _b): pass
	w.send_world_items = func(_p, _a, _r): pass
	w.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	w.send_notice = func(_p, _t): pass
	w.send_carry = func(_p, _id): pass
	w.send_chest = func(_p, _id, _b): pass
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
	var net_script: Script = load("res://src/stream/terrain_net.gd")   # a Script value, so its reflection methods are called on the resource, not as statics
	var net_methods: Array = net_script.get_script_method_list().map(func(m: Dictionary) -> String: return str(m["name"]))
	check(Net.PROTOCOL_VERSION >= 112 and not net_script.get_script_constant_map().has("ACT_HOTBAR_SET") and not net_methods.has("hotbar"), "protocol 112: no ACT_HOTBAR_SET, no hotbar rpc")
	check(pack().hotbar_slots == 10 and pack().bag_from == 10 and InventoryScript.new(items.table).hotbar_slots == 0, "a pack has ten hotbar slots; a container has none")
	empty_pack()

	# 1. Pickups fill the backpack first; a tool new in the pack moves into the first empty hotbar slot, food and materials do not.
	pick_up(clay, 3)
	check(pack().numbers[10] == clay and pack().count_of(clay) == 3 and pack().numbers.slice(0, 10).count(0) == 10, "clay goes to backpack slot 10, the hotbar stays empty")
	pick_up(axe)
	check(pack().numbers[0] == axe and pack().numbers.count(axe) == 1 and pack().key_slot(0) == 0, "a new axe moves into hotbar slot 0 (key 1) and is nowhere else")
	pick_up(berries, 2)
	check(not pack().numbers.slice(0, 10).has(berries), "food stays in the backpack")
	pick_up(knife)
	check(pack().numbers[1] == knife, "a new knife moves into the next empty hotbar slot")
	pick_up(axe)
	check(pack().numbers.slice(0, 10).count(axe) == 1 and pack().numbers.slice(10, 30).count(axe) == 1, "a second axe stays in the backpack")

	# 2. Moving into the hotbar takes it out of the backpack, and moving it back reverses it (TEST-008).
	var stone_slot: int = pack().free_bag_slot()   # the first free backpack slot (the second axe is in 12)
	pack().numbers[stone_slot] = stone
	pack().counts[stone_slot] = 5
	items.action(1, Net.ACT_MOVE, stone_slot, 4, 0, Vector3.ZERO)
	check(pack().numbers[4] == stone and pack().counts[4] == 5 and pack().numbers[stone_slot] == 0 and pack().count_of(stone) == 5, "stones moved to key 5 leave the backpack (one place, same count)")
	items.action(1, Net.ACT_MOVE, 4, stone_slot, 0, Vector3.ZERO)
	check(pack().numbers[4] == 0 and pack().key_slot(4) == -1 and pack().numbers[stone_slot] == stone and pack().count_of(stone) == 5, "moved back, key 5 is empty and the stones are in the backpack")
	var bag_axe: int = 10 + pack().numbers.slice(10, 30).find(axe)
	pack().wear[bag_axe] = 3
	items.action(1, Net.ACT_MOVE, bag_axe, 1, 0, Vector3.ZERO)
	check(pack().numbers[1] == axe and pack().wear[1] == 3 and pack().numbers[bag_axe] == knife, "an axe dropped on the knife's key swaps with it and keeps its wear")
	items.action(1, Net.ACT_MOVE, 1, bag_axe, 0, Vector3.ZERO)

	# 3. A hotbar slot whose item is gone is empty, not a dimmed reminder (TEST-006): dropped, sold (the trade clears the slot) or used up.
	items.action(1, Net.ACT_DROP, 1, 0, 1, Vector3(1.0, 10.0, 0.0))
	check(pack().numbers[1] == 0 and pack().key_slot(1) == -1, "the knife dropped from key 2 leaves key 2 empty")
	pack().numbers[3] = stone
	pack().counts[3] = 2
	pack().remove(stone, 7)
	check(pack().numbers[3] == 0 and pack().key_slot(3) == -1 and pack().count_of(stone) == 0, "the last stones used up from key 4 leave it empty")

	# 4. "On the hotbar" for tools means in a hotbar slot.
	check(items._tool_slot(pack(), "axe") == 0, "the axe in key 1 counts as on the hotbar")
	items.action(1, Net.ACT_MOVE, 0, 20, 0, Vector3.ZERO)
	var axes_in_bag: bool = pack().numbers.slice(10, 30).count(axe) == 2
	check(axes_in_bag and items._tool_slot(pack(), "axe") < 0, "in the backpack it does not")
	items.action(1, Net.ACT_MOVE, 20, 0, 0, Vector3.ZERO)

	# 5. Sort leaves the hotbar slots (Store all and Stack to nearby skip them too).
	var bar: PackedInt32Array = pack().numbers.slice(0, 10)
	items.action(1, Net.ACT_BULK, 3, 1, 0, Vector3.ZERO)
	check(pack().numbers.slice(0, 10) == bar, "Sort leaves the hotbar as it was")

	# 6. Saved with the pack and back after a restart; the character keeps no "hotbar".
	var saved: PackedInt32Array = pack().numbers.duplicate()
	items.save()
	items._finish_writer()
	var again = make_items(dir)
	again.peer_connected_hello(1, "hotbarkeys01")
	check(again.inventory_of(1).numbers == saved and again.inventory_of(1).hotbar_slots == 10, "the hotbar and backpack slots load back as they were, as a pack")

	# 6b. A pointer-hotbar save (characters.json "hotbar", protocol 100 to 111): each key's item moves into its hotbar slot once, then the list is gone.
	again.inventory_of(1).clear_slot(5)
	again.inventory_of(1).numbers[15] = stone
	again.inventory_of(1).counts[15] = 5
	var clay_at: int = again.inventory_of(1).numbers.find(clay)
	again._characters["hotbarkeys01"]["hotbar"] = [axe, 0, clay, 0, 0, stone, 0, 0, 0, 0]   # clay was in the backpack; an old pack also kept key items in slots 0 to 9
	again._dirty = true
	again.save()
	again._finish_writer()
	var third = make_items(dir)
	third.peer_connected_hello(1, "hotbarkeys01")
	var old = third.inventory_of(1)
	check(old.numbers[5] == stone and old.counts[5] == 5 and old.numbers[15] == 0 and old.numbers[0] == axe and old.count_of(stone) == 5, "key 6's stones move into hotbar slot 5; the axe already in slot 0 stays")
	check(clay_at >= 0 and old.numbers[2] == clay and old.count_of(clay) == 3, "key 3's clay moves into hotbar slot 2")
	check(not third._characters["hotbarkeys01"].has("hotbar"), "the old key list is dropped after the move")

	# 7. Admin give still fills from slot 0 (tests and the admin tool); the item is still in one place.
	items = third
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 2000.0
	empty_pack()
	give(stone, 3)
	check(pack().numbers[0] == stone and pack().count_of(stone) == 3, "an admin give fills from slot 0")

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

	# 9. A torch put out by the rain stays in its hotbar slot: the key is the slot, so pressing it finds the doused torch to light again.
	var torch: int = items.table.number_of("torch")
	var doused: int = items.table.number_of("torch_doused")
	var bag = InventoryScript.pack(items.table)
	bag.numbers[2] = torch
	bag.counts[2] = 1
	check(torch > 0 and doused > 0 and bag.key_slot(2) == 2 and bag.on_hotbar(2), "the burning torch is key 3's")
	bag.numbers[2] = doused
	check(bag.key_slot(2) == 2, "put out by the rain, it is still key 3's")
	bag.clear_slot(2)
	check(bag.key_slot(2) == -1 and not bag.on_hotbar(2), "no torch at all: key 3 is empty")

	print("hotbar keys: %s" % ("all passed" if failures == 0 else "%d FAILED" % failures))
	quit(1 if failures > 0 else 0)
