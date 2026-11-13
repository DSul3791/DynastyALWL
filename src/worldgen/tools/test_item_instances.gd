extends SceneTree

# Item instances (catalog Phase 1b, M001-T04; master s2.2, s2.9, s4 items 2, 15, 16): every slot carries optional instance data (sharpness used,
# current maximum durability, Tempered, craftsmanship, two magical slots). It survives the save and the wire, never merges with or into another
# stack, rides along every move (chest, ground, throw, worn, pack moves, hand-over, craft refunds, death), and a filled magical slot is permanent.
#   godot --headless --path . --script res://src/worldgen/tools/test_item_instances.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DIR := "user://test_item_instances"
const KEY := "instances001"
const FULL := {"sharp": 12, "max_d": 180, "temper": 1, "craft": 2, "magic": ["flaming", ""]}

var failures: int = 0
var slots_sent: Array = []
var worn_sent: Array = []
var notices: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make(dir: String = DIR):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, b): slots_sent.append(b)
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): notices.append(str(t))
	items.send_carry = func(_p, _id): pass
	items.send_chest = func(_p, _id, _b): pass
	items.send_chest_info = func(_p, _id, _k, _m): pass
	items.send_craft_stock = func(_p, _n, _c): pass
	items.send_craft_queue = func(_p, _e, _l): pass
	items.send_favourites = func(_p, _f): pass
	items.send_worn = func(_p, numbers, insts): worn_sent = [numbers, insts]
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.admin_mode_on = func(_p): return false
	items.peer_connected_hello(1, KEY)
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	return items


func empty_pack(inv) -> void:
	for slot in inv.slot_count:
		inv.clear_slot(slot)


# The slot holding `number` with exactly this instance data, or -1.
func slot_with(inv, number: int, inst: Dictionary) -> int:
	for slot in inv.slot_count:
		if inv.numbers[slot] == number and inv.inst_of(slot) == inst:
			return slot

	return -1


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	check(Net.PROTOCOL_VERSION >= 106, "PROTOCOL_VERSION is 106 or later (%d)" % Net.PROTOCOL_VERSION)
	check(InventoryScript.FORMAT == 4, "Inventory.FORMAT is 4 (protocol 115: the slot count after the format byte)")

	var items = make()
	var table = items.table
	var inv = items.inventory_of(1)
	empty_pack(inv)
	var axe: int = table.number_of("iron_axe") if table.number_of("iron_axe") > 0 else table.number_of("stone_axe")
	var stone: int = table.number_of("stone")
	var fibre: int = table.number_of("plant_fibre")
	var tunic: int = table.number_of("hide_tunic")
	var spear: int = table.number_of("wooden_spear")
	check(axe > 0 and stone > 0 and fibre > 0 and tunic > 0 and spear > 0, "the test items are in the table")

	# 1. The instance data itself: only known, non-default keys; the Phase 2c helpers read it.
	check(InventoryScript.clean_inst({"sharp": 0, "craft": 3, "temper": 0, "magic": ["", ""], "junk": 5}).is_empty(), "defaults and unknown keys read as plain")
	check(InventoryScript.clean_inst(JSON.parse_string(JSON.stringify(FULL))) == FULL, "every field survives JSON (floats back to whole numbers)")
	check(InventoryScript.make_inst(1, true) == {"craft": 1, "temper": 1} and InventoryScript.make_inst().is_empty(), "make_inst sets craftsmanship and Tempered, nothing else")
	inv.add(axe, 1, 30, FULL)
	var at: int = slot_with(inv, axe, FULL)
	check(at >= 0 and inv.wear[at] == 30, "add puts an instance in its own slot with its wear")
	check(inv.max_durability(at) == 180 and inv.sharpness_used(at) == 12, "max_durability and sharpness_used read the instance")
	inv.add(axe, 1)
	var plain_axe: int = slot_with(inv, axe, {})
	check(plain_axe >= 0 and inv.max_durability(plain_axe) == int(table.entry(table.id_of(axe)).get("durability", 0)) and inv.sharpness_used(plain_axe) == 0, "a plain slot falls back to the row's durability and full sharpness")

	# 2. Save and wire round trips of every field.
	var copy = InventoryScript.new(table)
	copy.from_json_array(JSON.parse_string(JSON.stringify(inv.to_json_array())))
	check(copy.inst_of(at) == FULL and copy.wear[at] == 30 and copy.inst_of(plain_axe).is_empty(), "the JSON save keeps every field (%s)" % str(copy.inst_of(at)))
	var row: Array = inv.to_json_array()[at]
	check(row.size() == 5 and int(row[3]) == 0, "an instance slot row is [number, count, wear, 0, inst] (%s)" % str(row))
	check((inv.to_json_array()[plain_axe] as Array).size() == 3, "a plain slot row stays [number, count, wear]")
	var bytes: PackedByteArray = inv.to_bytes()
	var wire = InventoryScript.new(table)
	check(bytes.size() > 2 + 30 * 8 + 2 and wire.from_bytes(bytes) and wire.inst_of(at) == FULL and wire.inst_of(plain_axe).is_empty(), "the bytes keep every field (%d bytes)" % bytes.size())
	var plain_bytes: PackedByteArray = InventoryScript.new(table).to_bytes()
	check(plain_bytes.size() == 2 + 30 * 8 + 2, "a pack with no instances is 244 bytes (format byte, slot count, 30 x 8, empty u16 length)")
	check(not wire.from_bytes(bytes.slice(0, 2 + 30 * 8)), "bytes cut short are refused")
	var old_bytes: PackedByteArray = plain_bytes.slice(1)
	old_bytes.insert(0, 3)
	check(not wire.from_bytes(old_bytes), "format 3 bytes are refused")

	# 3. No merge with or into an instance slot.
	empty_pack(inv)
	inv.add(stone, 5)
	inv.add(stone, 1, 0, {"craft": 1})
	inv.add(stone, 3)
	check(inv.count_of(stone) == 9 and slot_with(inv, stone, {"craft": 1}) >= 0 and inv.counts[slot_with(inv, stone, {"craft": 1})] == 1, "a plain add never joins the instance stack, an instance never joins a plain one")
	var plain_slot: int = slot_with(inv, stone, {})
	var inst_slot: int = slot_with(inv, stone, {"craft": 1})
	check(inv.counts[plain_slot] == 8, "the plain stones still merge with each other")
	inv.move(plain_slot, inst_slot)
	check(inv.inst_of(plain_slot) == {"craft": 1} and inv.counts[plain_slot] == 1 and inv.counts[inst_slot] == 8 and inv.inst_of(inst_slot).is_empty(), "moving onto an instance stack swaps, never merges")
	inv.move(plain_slot, inst_slot)
	check(inv.inst_of(inst_slot) == {"craft": 1} and inv.counts[inst_slot] == 1 and inv.counts[plain_slot] == 8, "and back: the instance goes with its stack")
	check(inv.remove(stone, 8) and inv.inst_of(inst_slot) == {"craft": 1} and inv.count_of(stone) == 1, "remove takes plain stacks before an instance")

	# 4. Magical slots: filled only while empty; nothing clears or moves them.
	empty_pack(inv)
	inv.add(axe, 1, 0, {"craft": 1})
	at = slot_with(inv, axe, {"craft": 1})
	check(inv.fill_magic(at, 0, "flaming") and inv.inst_of(at)["magic"] == ["flaming", ""], "fill_magic fills an empty magical slot")
	check(not inv.fill_magic(at, 0, "frost") and inv.inst_of(at)["magic"] == ["flaming", ""], "an occupied magical slot refuses another effect")
	check(not inv.fill_magic(at, 0, "") and not inv.fill_magic(at, 2, "might") and not inv.fill_magic(-1, 1, "might"), "an empty effect, a third slot and a bad slot are refused")
	check(inv.fill_magic(at, 1, "might") and inv.inst_of(at)["magic"] == ["flaming", "might"] and int(inv.inst_of(at)["craft"]) == 1, "the second slot fills too; craftsmanship stays")
	inv.add(stone, 2)
	check(not inv.fill_magic(slot_with(inv, stone, {}), 0, "flaming"), "a stack of two is not enchanted (one instance per unit)")
	var mighty: Dictionary = inv.inst_of(at).duplicate(true)

	# 5. Server moves: the wire message, ground, throw, chest, worn, hand-over, craft refunds, death, save and reload.
	slots_sent.clear()
	items.action(1, Net.ACT_MOVE, at, 25, 0, Vector3.ZERO)
	check(slot_with(inv, axe, mighty) == 25, "a pack move (ACT_MOVE) keeps the instance")
	var msg: PackedByteArray = slots_sent.back() if not slots_sent.is_empty() else PackedByteArray()
	var n: int = msg[0] if not msg.is_empty() else 0
	var wire_insts: Dictionary = InventoryScript.inst_from_bytes(msg, 1 + n * 9)
	check(n == 2 and msg.size() > 1 + n * 9 + 2 and wire_insts.get(25, {}) == mighty and not wire_insts.has(at), "inventory_slots: count, 9-byte records, then the moved slot's instance data (%s)" % str(wire_insts))
	items.action(1, Net.ACT_MOVE, 25, 3, 0, Vector3.ZERO)
	check(inv.key_slot(3) == 3 and inv.inst_of(3) == mighty and slot_with(inv, axe, mighty) == 3, "moved into hotbar slot 3 (key 4) it keeps its instance and is in one place")

	items.action(1, Net.ACT_DROP, 3, 0, 1, Vector3(1.0, 10.0, 0.0))
	var ground_id: int = -1

	for id in items._items:
		if int(items._items[id].get("number", 0)) == axe and items._items[id].get("inst", {}) == mighty:
			ground_id = id

	check(ground_id >= 0 and inv.count_of(axe) == 0, "a dropped instance lies on the ground with its data")
	inv.add(stone, 1, 0, {"craft": 1})
	items.action(1, Net.ACT_DROP, slot_with(inv, stone, {"craft": 1}), 0, 1, Vector3(1.0, 10.0, 0.0))
	items.action(1, Net.ACT_DROP, slot_with(inv, stone, {}), 0, 2, Vector3(1.0, 10.0, 0.0))
	var stone_piles: Array = []

	for id in items._items:
		if int(items._items[id].get("number", 0)) == stone:
			stone_piles.append([int(items._items[id]["count"]), items._items[id].get("inst", {})])

	check(stone_piles.size() == 2 and stone_piles.has([1, {"craft": 1}]) and stone_piles.has([2, {}]), "plain stones dropped beside an instance stone lie as their own pile (%s)" % str(stone_piles))
	items.action(1, Net.ACT_PICKUP, ground_id, 0, 0, Vector3.ZERO)
	at = slot_with(inv, axe, mighty)
	check(at >= 0 and not items._items.has(ground_id), "picked up, it comes back with its data")

	empty_pack(inv)
	inv.add(spear, 1, 4, {"craft": 2})
	items._last_throw.erase(1)
	items.action(1, Net.ACT_THROW, slot_with(inv, spear, {"craft": 2}), 0, 0, Vector3(1.0, 0.2, 0.0))
	check(inv.count_of(spear) == 0 and items._flights.size() == 1, "a thrown spear leaves the pack")

	for k in 200:
		if items._flights.is_empty():
			break

		items._fly(0.05)

	var landed: int = -1

	for id in items._items:
		if int(items._items[id].get("number", 0)) == spear:
			landed = id

	check(landed >= 0 and items._items[landed].get("inst", {}) == {"craft": 2}, "where it lands it keeps its data")

	empty_pack(inv)
	inv.add(axe, 1, 7, mighty)
	at = slot_with(inv, axe, mighty)
	var chest_id: int = items.dev_place("chest@1,0,0")
	var chest = items._chests.get(int(items._items.get(chest_id, {}).get("struct", {}).get("uid", -1)))
	check(chest != null, "a chest stands beside the player")
	items.action(1, Net.ACT_CHEST_OPEN, chest_id, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, at, chest_id, 1, Vector3.ZERO)
	var in_chest: int = slot_with(chest, axe, mighty) if chest != null else -1
	check(in_chest >= 0 and chest.wear[in_chest] == 7 and inv.count_of(axe) == 0, "put in a chest, it keeps its data and wear")
	chest.add(axe, 1)
	check(chest.inst_of(slot_with(chest, axe, mighty)) == mighty and chest.count_of(axe) == 2, "a plain axe beside it stays a separate slot")
	items._take_down(1, inv, chest_id)
	check(items._items.has(chest_id), "a chest holding it is not taken down (empty it first), so nothing is lost")
	items.action(1, Net.ACT_CHEST_TAKE, slot_with(chest, axe, mighty), chest_id, 1, Vector3.ZERO)
	at = slot_with(inv, axe, mighty)
	check(at >= 0 and inv.wear[at] == 7, "taken out again, it keeps its data and wear")
	chest.clear_slot(slot_with(chest, axe, {}))
	chest.add(stone, 1, 0, {"temper": 1})
	items.action(1, Net.ACT_BULK, 0, 0, 0, Vector3.ZERO)   # Take all
	check(slot_with(inv, stone, {"temper": 1}) >= 0, "Take all moves an instance with its data")
	items.action(1, Net.ACT_BULK, 1, 0, 0, Vector3.ZERO)   # Store all
	check(slot_with(chest, stone, {"temper": 1}) >= 0 and slot_with(inv, stone, {"temper": 1}) < 0, "Store all moves it into the chest with its data")
	items.action(1, Net.ACT_BULK, 0, 0, 0, Vector3.ZERO)
	inv.add(stone, 5)
	items._sort_slots(inv, 0, inv.slot_count, 1, true)
	check(slot_with(inv, stone, {"temper": 1}) >= 0 and slot_with(inv, axe, mighty) >= 0 and inv.count_of(stone) == 6, "Sort reorders the stacks with their data, never joining them")
	inv.add(stone, 4, 0, {"sharp": 2})
	items._split(inv, slot_with(inv, stone, {"sharp": 2}), 2)
	var halves: int = 0

	for slot in inv.slot_count:
		if inv.numbers[slot] == stone and inv.inst_of(slot) == {"sharp": 2} and inv.counts[slot] == 2:
			halves += 1

	check(halves == 2, "a split instance stack keeps its data on both halves")

	for slot in inv.slot_count:
		if inv.numbers[slot] == stone and inv.inst_of(slot) != {"temper": 1}:
			inv.clear_slot(slot)

	inv.add(tunic, 1, 9, {"craft": 1})
	items.action(1, Net.ACT_WEAR, slot_with(inv, tunic, {"craft": 1}), 0, 0, Vector3.ZERO)
	var body: int = items._worn_places().find("body:base")
	var worn: Array = items.worn_slots_of(1)
	check(int(worn[body][0]) == tunic and int(worn[body][2]) == 9 and worn[body][3] == {"craft": 1} and inv.count_of(tunic) == 0, "worn, the tunic is the slot [number, 1, wear, inst] (%s)" % str(worn[body]))
	check(worn_sent.size() == 2 and InventoryScript.inst_from_bytes(worn_sent[1], 0).get(body, {}) == {"craft": 1}, "the worn message carries its data")
	check(items._worn_entry(tunic) == [tunic, 1, 0, {}] and items._worn_entry(0) == [0, 0, 0, {}], "an old bare worn number reads as [n, 1, 0, {}]")
	items.action(1, Net.ACT_UNWEAR, body, 0, 0, Vector3.ZERO)
	var off: int = slot_with(inv, tunic, {"craft": 1})
	check(off >= 0 and inv.wear[off] == 9 and int(items.worn_of(1)[body]) == 0, "taken off, it comes back with its data and wear")
	items.action(1, Net.ACT_WEAR, off, 0, 0, Vector3.ZERO)

	inv.add(stone, 3)
	check(items.take_from(1, "stone", 3) and slot_with(inv, stone, {"temper": 1}) >= 0, "a hand-over (dialogue take_item) gives the plain stones first")

	for slot in inv.slot_count:
		if inv.numbers[slot] == stone:
			inv.clear_slot(slot)

	inv.add(fibre, 2)
	inv.add(fibre, 1, 6, {"craft": 2})
	items.action(1, Net.ACT_CRAFT_QUEUE, 1, 0, 1, Vector3.ZERO)
	var queue: Array = items._queue_of(1).get("entries", [])
	check(inv.count_of(fibre) == 0 and queue.size() == 1, "a queued Twine takes the three fibres, the instance one too")
	items._last_queue_act.erase(1)   # queue actions are paced
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	var back_fibre: int = slot_with(inv, fibre, {"craft": 2})
	check(inv.count_of(fibre) == 3 and back_fibre >= 0 and inv.wear[back_fibre] == 6, "a cancel gives the instance fibre back as it was, wear included (%s)" % str(queue))

	var undo = InventoryScript.new(table)
	undo.add(fibre, 2)
	undo.add(fibre, 1, 4, {"craft": 1})
	undo.usable = 0   # the Twine cannot go in, so the craft is undone
	check(not items.recipes.craft(1, undo) and slot_with(undo, fibre, {"craft": 1}) >= 0 and undo.wear[slot_with(undo, fibre, {"craft": 1})] == 4 and undo.count_of(fibre) == 3, "an undone recipe_table craft gives the instance back with its data and wear")

	inv.add(stone, 2)
	var stock: Dictionary = items._stock_of(1)
	check(items._stock_have(inv, stone, stock) - items._stock_have(inv, stone, stock, true) == 1, "building stock leaves the instance stone out (a blueprint keeps counts only)")
	var kit: int = table.number_of("campfire_kit")
	inv.add(kit, 1, 0, {"craft": 1})
	var things: int = items._items.size()
	items._place(1, inv, slot_with(inv, kit, {"craft": 1}), Vector3(-1.5, 10.0, -1.0))
	check(slot_with(inv, kit, {"craft": 1}) >= 0 and items._items.size() == things, "an instance item is never set down as a placed piece (it would turn plain)")
	inv.clear_slot(slot_with(inv, kit, {"craft": 1}))
	inv.add(kit, 1)
	items._place(1, inv, slot_with(inv, kit, {}), Vector3(-1.5, 10.0, -1.0))
	check(inv.count_of(kit) == 0 and items._items.size() == things + 1, "the same kit without instance data is set down there (positive control)")

	# Building costs and groups: an instance log lower in the log group's spend order is never taken; plain logs of another member are.
	var log_n: int = table.number_of("log")
	var order: PackedInt32Array = table.spend_order(log_n)
	check(order.size() >= 2, "the log group has two members to spend (%s)" % str(order))
	var low: int = order[0] if order.size() > 0 else 0
	var high: int = order[1] if order.size() > 1 else 0
	var logs = InventoryScript.new(table)
	logs.add(low, 1, 0, {"craft": 1})
	logs.add(high, 2)
	check(logs.count_fill(log_n, true) == 2 and logs.remove_fill(log_n, 2, [], true) and logs.count_of(high) == 0 and slot_with(logs, low, {"craft": 1}) >= 0, "remove_fill(plain_only) takes the plain logs and leaves the instance log first in spend order")
	check(not logs.remove_fill(log_n, 1, [], true) and slot_with(logs, low, {"craft": 1}) >= 0, "and refuses when only the instance log is left")
	inv.add(low, 1, 0, {"craft": 1})
	inv.add(high, 2)
	var took_logs: int = items._stock_take(inv, log_n, 2, items._stock_of(1), [], true)
	check(took_logs == 2 and slot_with(inv, low, {"craft": 1}) >= 0 and inv.count_of(high) == 0, "a blueprint's _stock_take(plain_only) does the same from the pack (took %d)" % took_logs)
	inv.clear_slot(slot_with(inv, low, {"craft": 1}))

	# A large log into a pack with every slot taken is never doubled: the pack grows for it (Dave 12 Nov 2026 23:06Z, protocol 115), so it moves
	# once, from the chest or the ground, and nothing is laid at the player's feet.
	var big: int = table.number_of("log_oak")
	var filler: Array = []

	for slot in inv.slot_count:
		if inv.numbers[slot] == 0:
			inv.numbers[slot] = fibre   # light, so only the slots (not the weight) are full
			inv.counts[slot] = 1
			filler.append(slot)

	var logs_out: Callable = func() -> int:
		var seen: int = chest.count_of(big)

		for id in items._items:
			if int(items._items[id].get("number", 0)) == big:
				seen += int(items._items[id]["count"])

		return seen

	var full_slots: int = inv.slot_count
	chest.add(big, 1)
	items.action(1, Net.ACT_CHEST_TAKE, chest.numbers.find(big), chest_id, 1, Vector3.ZERO)
	check(inv.count_of(big) == 1 and chest.count_of(big) == 0 and logs_out.call() == 0 and inv.slot_count > full_slots, "every slot taken: the pack grows (%d to %d slots) and takes the log from the chest; only one exists" % [full_slots, inv.slot_count])
	inv.clear_slot(inv.numbers.find(big))
	items.drop_in_world(big, 1, Vector3(1.0, 10.0, 0.0))
	var log_id: int = -1

	for id in items._items:
		if int(items._items[id].get("number", 0)) == big:
			log_id = id

	items.action(1, Net.ACT_PICKUP, log_id, 0, 0, Vector3.ZERO)
	check(inv.count_of(big) == 1 and not items._items.has(log_id) and logs_out.call() == 0, "and picked up from the ground, the log moves to the pack, only one exists")
	inv.clear_slot(inv.numbers.find(big))

	for slot in filler:
		inv.clear_slot(slot)

	# A craft cancel gives plain stacks back with their wear (food age, wet wood), not fresh.
	for slot in inv.slot_count:
		if inv.numbers[slot] == fibre:
			inv.clear_slot(slot)

	inv.add(fibre, 3, 7)
	items._last_queue_act.erase(1)
	items.action(1, Net.ACT_CRAFT_QUEUE, 1, 0, 1, Vector3.ZERO)
	check(inv.count_of(fibre) == 0, "the Twine takes the three worn fibres")
	items._last_queue_act.erase(1)
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	var aged: int = inv.numbers.find(fibre)
	check(inv.count_of(fibre) == 3 and aged >= 0 and inv.wear[aged] == 7, "a cancel gives plain units back with their recorded wear")

	# Perishable food: five queued crafts over two stacks of different age, two finished, then a cancel gives back the units still owed, at their own
	# age (rows run in the order taken; the last ones are owed). Recipe 31 (energy bar) takes three nuts and one nectar a craft.
	var nuts: int = table.number_of("nuts")
	var nectar: int = table.number_of("honeyspindle_nectar")
	var life: int = table.shelf_units(nuts)
	check(nuts > 0 and nectar > 0 and life > 100 and items.recipes.recipe(31).get("needs", []) == [[nuts, 3], [nectar, 1]], "nuts spoil and recipe 31 takes three nuts and a nectar (life %d)" % life)

	for slot in inv.slot_count:
		if inv.numbers[slot] in [nuts, nectar, fibre]:
			inv.clear_slot(slot)

	var young: int = 2
	var old_age: int = life / 2
	var free_slots: Array = []

	for slot in inv.slot_count:
		if inv.numbers[slot] == 0 and free_slots.size() < 2:
			free_slots.append(slot)

	# Written directly so the two ages stay two stacks, and only into empty slots (a write over a held slot would keep that slot's instance
	# data and lose the item): the young stack first, the old one in the later slot (taken first: last slot first).
	var young_at: int = int(free_slots[0])
	var old_at: int = int(free_slots[1])
	inv.numbers[young_at] = nuts
	inv.counts[young_at] = 9
	inv.wear[young_at] = young
	inv.numbers[old_at] = nuts
	inv.counts[old_at] = 6
	inv.wear[old_at] = old_age
	inv.add(nectar, 5)
	items._items[items._next_id] = {"number": table.number_of("food_preparation_table"), "count": 1, "pos": Vector3(1.5, 10.0, 0.0), "left": 1.0e9, "struct": {"kind": "food_preparation_table", "yaw": 0.0}}   # Nut cake is made at the table (Mission 001 phase 6)
	items._next_id += 1
	items._last_queue_act.erase(1)
	items.action(1, Net.ACT_CRAFT_QUEUE, 31, 0, 5, Vector3.ZERO)
	var food_queue: Array = items._queue_of(1).get("entries", [])
	check(inv.count_of(nuts) == 0 and food_queue.size() == 1 and int(food_queue[0][1]) == 5, "five energy bars are queued (%s)" % str(food_queue))

	if food_queue.size() == 1:
		food_queue[0][1] = 3   # two crafts finished (as _craft_tick counts them down); they used the six old nuts taken first

	items._last_queue_act.erase(1)
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	var ages: Array = []

	for slot in inv.slot_count:
		if inv.numbers[slot] == nuts:
			ages.append([inv.counts[slot], inv.wear[slot]])

	var young_back: int = 0

	for got in ages:
		young_back += int(got[0]) if int(got[1]) == young else 0

	check(young_back == 9 and inv.count_of(nuts) == 9 and inv.count_of(nuts, true) == 9 and inv.count_of(nectar) == 3, "the cancel gives back the nine young nuts still owed, plain and at their age, not the old ones (%s)" % str(ages))

	for slot in inv.slot_count:
		if inv.numbers[slot] in [nuts, nectar]:
			inv.clear_slot(slot)

	var berries: int = table.number_of("berries")

	if berries > 0 and table.shelf_units(berries) > 0:
		inv.add(berries, 1, 0, {"craft": 1})
		var rot_at: int = slot_with(inv, berries, {"craft": 1})
		items._spoil_inventory(inv, table.shelf_units(berries))
		check(inv.numbers[rot_at] != berries and inv.inst_of(rot_at).is_empty(), "food that rots turns plain, so the rotten stack can merge")
		inv.clear_slot(rot_at)
	else:
		check(false, "berries spoil (the rot check needs a perishable item)")

	for slot in inv.slot_count:
		if inv.numbers[slot] == stone and inv.inst_of(slot).is_empty():
			inv.clear_slot(slot)

	for slot in inv.slot_count:
		if inv.numbers[slot] == fibre:
			inv.clear_slot(slot)

	# Save and reload: pack, chest, ground and worn keep every field.
	chest.add(axe, 1, 3, FULL)
	var lying: int = -1

	for id in items._items:
		if int(items._items[id].get("number", 0)) == spear:
			lying = id

	items._dirty = true
	items.save()
	items._finish_writer()
	var back = make()
	var back_inv = back.inventory_of(1)
	var back_chest = back._chests.get(int(items._items[chest_id]["struct"]["uid"]))
	var back_ground: bool = false

	for id in back._items:
		if int(back._items[id].get("number", 0)) == spear and back._items[id].get("inst", {}) == {"craft": 2}:
			back_ground = true

	check(slot_with(back_inv, axe, mighty) >= 0 and back_inv.wear[slot_with(back_inv, axe, mighty)] == 7, "after a restart the pack keeps its instance")
	check(back_chest != null and slot_with(back_chest, axe, FULL) >= 0 and back_chest.wear[slot_with(back_chest, axe, FULL)] == 3, "the chest keeps every field")
	check(lying >= 0 and back_ground, "the ground item keeps its data")
	var back_worn: Array = back.worn_slots_of(1)
	check(int(back_worn[body][0]) == tunic and int(back_worn[body][2]) == 9 and back_worn[body][3] == {"craft": 1}, "the worn tunic keeps its data and wear (%s)" % str(back_worn[body]))
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(DIR + "/characters.json"))
	var saved_worn: Array = saved["players"][KEY]["worn"]
	check((saved_worn[body] as Array).size() == 4 and (saved_worn[0] as Array).size() == 4 and int(saved_worn[0][0]) == 0, "characters.json writes worn as slot arrays")

	# Death: the pack goes to the remains as it was.
	back.kill(1, "test")
	var remains = null

	for id in back.remains_ids():
		remains = back._chests.get(int(back._items[id]["struct"].get("uid", 0)))

	check(remains != null and slot_with(remains, axe, mighty) >= 0, "the remains keep the instance")

	# Craft-queue unit rows from a save: [number, inst] (oldest), [number, inst, wear] (T04), [number, inst, wear, count] (now) all load and refund.
	var dir2: String = DIR + "_queue"
	DirAccess.make_dir_recursive_absolute(dir2)

	for file in DirAccess.get_files_at(dir2):
		DirAccess.remove_absolute(dir2 + "/" + file)

	var rows: Array = [[fibre, {"craft": 1}], [fibre, {"craft": 2}, 5], [fibre, {}, 8, 2]]
	var file: FileAccess = FileAccess.open(dir2 + "/craft_queues.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "players": {KEY: {"entries": [[1, 2, [[fibre, 3, rows]], [], 0]], "elapsed": 0.0}}}))
	file.close()
	var third = make(dir2)
	var third_inv = third.inventory_of(1)
	empty_pack(third_inv)
	var loaded: Array = third._queue_of(1).get("entries", [[0, 0, [[0, 0, []]]]])[0][2][0][2]
	check(loaded == [[fibre, {"craft": 1}, 0, 1], [fibre, {"craft": 2}, 5, 1], [fibre, {}, 8, 2]], "two-, three- and four-value unit rows load (%s)" % str(loaded))
	third.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	var c1: int = slot_with(third_inv, fibre, {"craft": 1})
	var c2: int = slot_with(third_inv, fibre, {"craft": 2})
	var worn8: int = -1

	for slot in third_inv.slot_count:
		if third_inv.numbers[slot] == fibre and third_inv.inst_of(slot).is_empty() and third_inv.wear[slot] == 8:
			worn8 = slot

	check(third_inv.count_of(fibre) == 6 and c1 >= 0 and third_inv.wear[c1] == 0 and c2 >= 0 and third_inv.wear[c2] == 5 and worn8 >= 0, "the cancel gives each row back as it was, the rest plain (fibre does not age, so the plain ones join the worn stack) (%s)" % str(third_inv.to_json_array().filter(func(r): return int(r[0]) != 0)))
	for slot in third_inv.slot_count:
		if third_inv.numbers[slot] == fibre:
			third_inv.clear_slot(slot)

	third_inv.add(fibre, 3, 4)
	third._last_queue_act.erase(1)
	third.action(1, Net.ACT_CRAFT_QUEUE, 1, 0, 1, Vector3.ZERO)
	third._dirty = true
	third.save()
	third._finish_writer()
	var fourth = make(dir2)
	var saved_rows: Array = fourth._queue_of(1).get("entries", [[0, 0, [[0, 0, []]]]])[0][2][0]
	check(saved_rows.size() > 2 and not (saved_rows[2] as Array).is_empty() and int(saved_rows[2][0][2]) == 4 and int(saved_rows[2][0][3]) == 3, "a queued craft's unit rows survive a save and reload (%s)" % str(saved_rows))
	fourth._finish_writer()

	print("item instances: %d failures" % failures)
	items._finish_writer()
	back._finish_writer()
	quit(1 if failures > 0 else 0)
