extends SceneTree

# The pack grows (Dave 12 Nov 2026 23:06Z: "a minimum of 20 and if they add more stuff just start adding more slots... they are limited by weight
# really"; protocol 115), as the server runs it: a change that grows or shrinks the pack is sent as the whole pack, a same-size change as slot
# updates; gains stop at the carry limit, not at a slot count; Split grows a full pack; a body's remains hold every slot of a grown pack and Take
# all reaches them all, and the pack starts over at 30.
#   godot --headless --path . --script res://src/worldgen/tools/test_pack_growth.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")

var failures: int = 0
var items
var full_sent: Array = []
var slots_sent: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func pack():
	return items.inventory_of(1)


func loose(number: int) -> int:
	var n: int = 0

	for id in items._items:
		if not items._items[id].has("struct") and int(items._items[id].get("number", 0)) == number:
			n += int(items._items[id]["count"])

	return n


func _init() -> void:
	var dir: String = "user://test_pack_growth"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, b): full_sent.append(b)
	items.send_slots = func(_p, b): slots_sent.append(b)
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.send_carry = func(_p, _id): pass
	items.send_chest = func(_p, _id, _b): pass
	items.send_remains = func(_p, _rows): pass
	items.send_died = func(_p, _c, _at): pass
	items.ground_height = func(_x, _z): return 10.0
	items.respawn_point = Vector3(5.0, 20.0, 5.0)
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "packgrowth01")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 2000.0   # a carry limit far above anything here, until section 3
	var axe: int = items.table.number_of("stone_axe")
	var stone: int = items.table.number_of("stone")
	var fibre: int = items.table.number_of("plant_fibre")
	check(axe > 0 and stone > 0 and fibre > 0 and pack().grows and pack().slot_count == 30, "a player's pack grows and starts at 30 slots")

	# 1. The wire: growing or shrinking sends the whole pack (FORMAT 4 carries the count); a same-size change sends slot updates.
	full_sent.clear()
	slots_sent.clear()
	items.give(1, fibre, 3)
	check(full_sent.is_empty() and slots_sent.size() == 1 and pack().slot_count == 30, "a gain that fits: a slot update, no whole pack")
	items.give(1, axe, 30)   # 19 fill the backpack beside the fibre, the other 11 need new slots (one then goes up to the hotbar by itself)
	var grown_to: int = pack().slot_count
	var wire = InventoryScript.pack(items.table)
	check(grown_to > 30 and pack().count_of(axe) == 30 and full_sent.size() == 1 and wire.from_bytes(full_sent[0]) and wire.slot_count == grown_to and wire.count_of(axe) == 30, "a gain that grows the pack to %d slots sends the whole pack, every slot in it" % grown_to)
	full_sent.clear()
	slots_sent.clear()
	var before: Array = items._snapshot(pack())
	pack().clear_slot(30)
	items._send_changes(1, pack(), before)
	check(pack().slot_count == grown_to and full_sent.is_empty() and slots_sent.size() == 1, "emptying a slot short of the last item: same size, a slot update")

	for slot in range(pack().slot_count - 1, 29, -1):
		before = items._snapshot(pack())
		pack().clear_slot(slot)
		items._send_changes(1, pack(), before)

	check(pack().slot_count == 30 and full_sent.size() >= 1 and wire.from_bytes(full_sent.back()) and wire.slot_count == 30, "emptying the new slots gives them back: the whole pack is sent at 30 slots")

	# 2. Split: a full backpack grows a step for the half that comes off.
	for slot in range(pack().hotbar_slots, pack().slot_count):
		if pack().numbers[slot] == 0:
			pack().numbers[slot] = axe
			pack().counts[slot] = 1

	pack().clear_slot(29)
	pack().numbers[29] = stone
	pack().counts[29] = 4
	items.action(1, Net.ACT_SPLIT, 29, 0, 2, Vector3.ZERO)
	check(pack().slot_count == 35 and pack().numbers[30] == stone and pack().counts[30] == 2 and pack().counts[29] == 2, "Split on a full backpack grows the pack and puts the half in the new slot")

	# 3. The carry limit, not a slot count, stops a gain; the rest lies at the player's feet.
	items.vitals_of(1)["weight"] = 75.0
	var fits: int = items._fit(1, pack(), stone, 1000)
	var stones_before: int = pack().count_of(stone)
	var on_ground_before: int = loose(stone)
	var took: int = items._take_in(1, pack(), stone, 1000)
	check(took == fits and pack().count_of(stone) == stones_before + fits and loose(stone) == on_ground_before + 1000 - fits, "a gain past the carry limit: %d taken in, the rest on the ground" % took)
	check(items._fit(1, pack(), stone, 1) == 0 and items._take_in(1, pack(), stone, 1) == 0, "at the limit nothing more goes in, however many slots the pack could grow")
	items.vitals_of(1)["weight"] = 2000.0

	# 4. Death with a grown pack: the remains hold every slot, the pack starts over at 30, and Take all reaches them all.
	var held: int = 0
	var units: int = 0

	for slot in pack().slot_count:
		held += 1 if pack().numbers[slot] != 0 else 0
		units += pack().counts[slot] if pack().numbers[slot] != 0 else 0

	var grown: int = pack().slot_count
	check(grown > 30 and items.kill(1, "test"), "a player with a %d-slot pack dies" % grown)
	check(pack().slot_count == 30 and pack().is_empty(), "the pack starts over: empty, 30 slots")
	items.vitals_of(1)["weight"] = 2000.0   # vitals start over at death too
	var ids: Array = items.remains_ids()
	var id: int = int(ids[0]) if ids.size() == 1 else 0
	var box = items._chests.get(int(items._items[id]["struct"]["uid"])) if id != 0 else null
	var on_body: int = 0

	if box != null:
		for slot in box.slot_count:
			on_body += 1 if box.numbers[slot] != 0 else 0

	check(box != null and box.slot_count == grown and on_body == held, "the remains hold all %d stacks in %d slots" % [on_body, box.slot_count if box != null else 0])

	if id != 0:
		items.report_position(1, items._items[id]["pos"] + Vector3(1.0, 0.0, 0.0))
		items.action(1, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
		items.action(1, Net.ACT_BULK, 0, 0, 0, Vector3.ZERO)   # Take all

	var left_on_body: int = 0
	var back: int = 0

	if box != null:
		for slot in box.slot_count:
			left_on_body += 1 if box.numbers[slot] != 0 else 0

	for slot in pack().slot_count:
		back += pack().counts[slot] if pack().numbers[slot] != 0 else 0

	check(left_on_body == 0 and back == units and pack().slot_count > 30, "Take all empties the remains, the slots past 30 too (%d stacks left, %d of %d items back)" % [left_on_body, back, units])

	items._finish_writer()
	print("test_pack_growth: %d failures" % failures)
	quit(1 if failures > 0 else 0)
