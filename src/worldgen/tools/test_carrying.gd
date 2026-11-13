extends SceneTree

# Carrying equipment (catalog Phase 5, M001-T15; master s3.9 rules 1-5, CATALOG_SAVE_MIGRATION.md rules 10-11): a bag is an item instance holding
# its own contents (instance data `bag`, src/shared/bag_rules.gd). Real server state throughout: a worn Fibre - Shoulder bag (a bag with slots; no back pack has any, Dave 13 Nov 2026) fills through its container
# window, is dropped, picked up, put in a chest and taken out by another player with nothing lost or doubled; a bag refuses a bag; a quiver holds
# its 40 arrows beside a backpack and the bow draws from it; a pouch refuses a log and needs a belt with a free point; contents spoil where the bag
# is, count toward the carry weight, and survive a save and reload worn and on the ground.
#   godot --headless --path . --script res://src/worldgen/tools/test_carrying.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const BagRules := preload("res://src/shared/bag_rules.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const TradeScript := preload("res://src/stream/server_trade.gd")

const DIR := "user://test_carrying"
const KEY := "carrying001"
const KEY2 := "carrying002"

var failures: int = 0
var notices: Array = []
var chest_sent: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make():
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): notices.append(str(t))
	items.send_carry = func(_p, _id): pass
	items.send_chest = func(p, id, b): chest_sent = [p, id, b]
	items.send_chest_info = func(_p, _id, _k, _m): pass
	items.send_craft_stock = func(_p, _n, _c): pass
	items.send_craft_queue = func(_p, _e, _l): pass
	items.send_favourites = func(_p, _f): pass
	items.send_worn = func(_p, _n, _i): pass
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), DIR)
	items.admin_mode_on = func(_p): return false
	items.peer_connected_hello(1, KEY)
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	return items


func give(items, peer: int, id: String, count: int = 1) -> int:
	var inv = items.inventory_of(peer)
	var n: int = items.table.number_of(id)
	items.action(peer, Net.ACT_ADMIN_GIVE, n, 0, count, Vector3.ZERO)
	return inv.numbers.find(n)


func wear(items, peer: int, id: String) -> void:
	var inv = items.inventory_of(peer)
	items.action(peer, Net.ACT_WEAR, inv.numbers.find(items.table.number_of(id)), 0, 0, Vector3.ZERO)


func place(items, at: String) -> int:
	return items._worn_places().find(at)


# The bag worn at a position as {number: count} of what it holds.
func held(items, peer: int, at: String) -> Dictionary:
	var entry: Array = items.worn_slots_of(peer)[place(items, at)]
	return rows_count(entry[3].get("bag", []))


func rows_count(rows: Array) -> Dictionary:
	var out: Dictionary = {}

	for row in rows:
		if int(row[0]) != 0:
			out[int(row[0])] = int(out.get(int(row[0]), 0)) + int(row[1])

	return out


func empty(inv) -> void:
	for slot in inv.slot_count:
		inv.clear_slot(slot)


# Every unit of `number` anywhere: both packs, everything worn and in bags, the chests and the ground (with what bags on the ground hold).
func everywhere(items, number: int) -> int:
	var total: int = 0

	for key in items._inventories:
		var inv = items._inventories[key]
		total += inv.count_of(number)

		for slot in inv.slot_count:
			total += int(rows_count(inv.inst_of(slot).get("bag", [])).get(number, 0))

	for key in items._characters:
		for raw in items._characters[key].get("worn", []):
			if typeof(raw) == TYPE_ARRAY and raw.size() > 3:
				total += (1 if int(raw[0]) == number else 0) + int(rows_count(raw[3].get("bag", [])).get(number, 0))

	for uid in items._chests:
		var chest = items._chests[uid]
		total += chest.count_of(number)

		for slot in chest.slot_count:
			total += int(rows_count(chest.inst_of(slot).get("bag", [])).get(number, 0))

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("number") and not it.has("struct"):
			total += (int(it.get("count", 0)) if int(it["number"]) == number else 0) + int(rows_count(it.get("inst", {}).get("bag", [])).get(number, 0))

	return total


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	check(Net.PROTOCOL_VERSION >= 109, "PROTOCOL_VERSION 109 or later (%d)" % Net.PROTOCOL_VERSION)
	var items = make()
	var table = items.table
	var inv = items.inventory_of(1)
	empty(inv)
	var places: Array = items._worn_places()
	var n: Callable = func(id: String) -> int: return table.number_of(id)

	# 1. The model: seven appended positions, every carrying row live with its own place; the five back packs (and only they) spread weight (carry_bonus_kg 12, 18, 8, 24 and 30 are in test_backpack_carry) and none has slots (DESIGN-001, Dave 13 Nov 2026).
	check(places.size() == 27 and places[19] == "body:mail" and places.slice(20) == ["back:roll", "waist:pouch", "waist:quiver", "waist:scabbard", "waist:tools", "shoulder:base", "strap:base"], "worn gains seven positions after body:mail (%s)" % str(places.slice(19)))
	var homes: Dictionary = {"backpack": "back:base", "leather_backpack": "back:base", "wicker_pack_basket": "back:base", "travellers_rucksack": "back:base",
		"quiver": "waist:quiver", "leather_quiver": "waist:quiver", "leather_belt": "waist:base", "belt_pouch": "waist:pouch", "weapon_scabbard": "waist:scabbard", "tool_roll": "waist:tools",
		"fibre_shoulder_bag": "shoulder:base", "leather_satchel": "shoulder:base", "utility_bandolier": "strap:base", "bedroll": "back:roll"}
	var wrong: Array = []

	for id in homes:
		if items._place_of(n.call(id)) != place(items, homes[id]) or bool(table.entry(id).get("future", false)) or table.entry(id).has("carry_bonus_kg") != (id in ["backpack", "leather_backpack", "wicker_pack_basket", "travellers_rucksack"]):
			wrong.append(id)

	check(wrong.is_empty(), "each carrying row is live, has its own worn position and a carry_bonus_kg only on the four back packs (%s)" % str(wrong))
	var no_slots: Array = []

	for id in ["backpack", "leather_backpack", "wicker_pack_basket", "travellers_rucksack"]:
		if BagRules.slots_of(table, n.call(id)) != 0 or table.entry(id).has("bag_takes") or table.entry(id).has("loaded_effort"):
			no_slots.append(id)

	check(no_slots.is_empty(), "no back pack has slots, bag_takes or loaded_effort (Dave 13 Nov 2026: they only give carry weight) (%s)" % str(no_slots))
	check(BagRules.slots_of(table, n.call("fibre_shoulder_bag")) == 4 and BagRules.slots_of(table, n.call("quiver")) == 2 and int(table.entry("quiver").get("ammo_capacity", 0)) == 40, "volume: Fibre - Shoulder bag 4 slots, Hide - Quiver 40 arrows")

	# 2. A backpack and a quiver are worn together; the pack spreads the load (its carry_bonus_kg raises the limit, test_backpack_carry measures it).
	var body_before: float = items._carry_body(1)
	give(items, 1, "backpack")
	give(items, 1, "quiver")
	wear(items, 1, "backpack")
	wear(items, 1, "quiver")
	var worn: Array = items.worn_of(1)
	check(worn[place(items, "back:base")] == n.call("backpack") and worn[place(items, "waist:quiver")] == n.call("quiver") and inv.count_of(n.call("backpack")) == 0, "a backpack and a quiver are worn together")
	check(is_equal_approx(items._carry_body(1), body_before + 12.0 / 0.7), "the worn Hide - Backpack raises the carry limit by its 12 kg")

	# The worn backpack cannot be opened or filled: it has no slots.
	var back_id: int = -1 - place(items, "back:base")
	chest_sent = []
	give(items, 1, "stone")
	items.action(1, Net.ACT_CHEST_OPEN, back_id, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, inv.numbers.find(n.call("stone")), back_id, 1, Vector3.ZERO)
	check(chest_sent.is_empty() and held(items, 1, "back:base").is_empty() and inv.count_of(n.call("stone")) == 1, "the worn Hide - Backpack is not opened and takes nothing")
	inv.clear_slot(inv.numbers.find(n.call("stone")))

	# A Fibre - Shoulder bag is the bag the rest of this test uses: the backpack is taken off and put away so its bonus stays out of the numbers below.
	items.action(1, Net.ACT_UNWEAR, place(items, "back:base"), 0, 0, Vector3.ZERO)
	inv.clear_slot(inv.numbers.find(n.call("backpack")))
	give(items, 1, "fibre_shoulder_bag")
	wear(items, 1, "fibre_shoulder_bag")
	check(items.worn_of(1)[place(items, "shoulder:base")] == n.call("fibre_shoulder_bag"), "a Fibre - Shoulder bag worn (a bag with 4 slots)")

	# 3. Fill the shoulder bag through its window (a worn bag is container -1 - its worn position).
	var pack_id: int = -1 - place(items, "shoulder:base")
	var stone: int = n.call("stone")
	var berries: int = n.call("berries")
	var axe: int = n.call("stone_axe")
	give(items, 1, "stone", 15)
	give(items, 1, "berries", 12)
	give(items, 1, "stone_axe")
	inv.inst[inv.numbers.find(axe)] = {"craft": 1}
	var kg_before: float = items.carried_kg_of(1)
	items.action(1, Net.ACT_CHEST_OPEN, pack_id, 0, 0, Vector3.ZERO)
	check(chest_sent.size() == 3 and int(chest_sent[1]) == pack_id, "opening the worn pack answers with its contents (container %d)" % pack_id)

	for id in ["stone", "berries", "stone_axe"]:
		items.action(1, Net.ACT_CHEST_PUT, inv.numbers.find(n.call(id)), pack_id, 99, Vector3.ZERO)

	var full: Dictionary = held(items, 1, "shoulder:base")
	check(full == {stone: 15, berries: 12, axe: 1} and inv.count_of(stone) == 0 and inv.count_of(berries) == 0 and inv.count_of(axe) == 0, "the worn pack holds what was put in and the pack gave it up (%s)" % str(full))
	var rows: Array = items.worn_slots_of(1)[place(items, "shoulder:base")][3]["bag"]
	check(rows.any(func(r: Array) -> bool: return int(r[0]) == axe and r.size() > 4 and r[4] == {"craft": 1}), "an item in the bag keeps its own instance data")
	check(absf(items.carried_kg_of(1) - kg_before) < 0.0001 and items.carried_kg_of(1) >= 15.0, "carrying weight counts what the worn bag holds (%.2f kg before, %.2f after)" % [kg_before, items.carried_kg_of(1)])
	var bag_inv = InventoryScript.new(table)
	check(bag_inv.from_bytes(chest_sent[2]) and bag_inv.count_of(stone) == 15, "chest_contents carries the bag's slots as inventory bytes")

	# 4. A bag refuses another bag (no nesting).
	give(items, 1, "leather_satchel")
	notices.clear()
	items.action(1, Net.ACT_CHEST_PUT, inv.numbers.find(n.call("leather_satchel")), pack_id, 1, Vector3.ZERO)
	check(inv.count_of(n.call("leather_satchel")) == 1 and not held(items, 1, "shoulder:base").has(n.call("leather_satchel")) and notices.has("A bag cannot go inside another bag."), "a bag refuses another bag")
	check(not InventoryScript.clean_inst({"bag": [[n.call("leather_satchel"), 1, 0, 0, {"bag": [[stone, 3, 0]], "craft": 1}]]})["bag"][0][4].has("bag"), "saved or sent data with a bag inside a bag loses the inner contents' key (clean_inst), never nests")

	# 5. The quiver holds its 40 arrows and takes nothing else; the bow draws from it first.
	var arrow: int = n.call("wooden_arrow")
	var quiver_id: int = -1 - place(items, "waist:quiver")
	give(items, 1, "wooden_arrow", 60)

	for i in 4:
		var at: int = inv.numbers.find(arrow)

		if at >= 0:
			items.action(1, Net.ACT_CHEST_PUT, at, quiver_id, inv.counts[at], Vector3.ZERO)

	check(int(held(items, 1, "waist:quiver").get(arrow, 0)) == 40 and inv.count_of(arrow) == 20, "the quiver holds its 40 arrows and the rest stay in the pack (%s)" % str(held(items, 1, "waist:quiver")))
	give(items, 1, "stone")
	items.action(1, Net.ACT_CHEST_PUT, inv.numbers.find(stone), quiver_id, 1, Vector3.ZERO)
	check(not held(items, 1, "waist:quiver").has(stone) and inv.count_of(stone) == 1, "the quiver takes only arrows")
	inv.clear_slot(inv.numbers.find(stone))
	var bow_at: int = give(items, 1, "wooden_bow")
	items.action(1, Net.ACT_SHOOT, bow_at, 800, 0, Vector3(0.0, 0.0, -1.0))
	check(int(held(items, 1, "waist:quiver").get(arrow, 0)) == 39 and inv.count_of(arrow) == 20, "a shot takes its arrow from the worn quiver, not the pack")

	# 6. The belt: a pouch needs one, refuses a log, and the belt has three points.
	give(items, 1, "belt_pouch")
	notices.clear()
	wear(items, 1, "belt_pouch")
	check(items.worn_of(1)[place(items, "waist:pouch")] == 0 and inv.count_of(n.call("belt_pouch")) == 1 and notices.has("A pouch hangs on a belt. Put a belt on first."), "a pouch needs a belt")
	give(items, 1, "leather_belt")
	wear(items, 1, "leather_belt")
	wear(items, 1, "belt_pouch")
	check(items.worn_of(1)[place(items, "waist:pouch")] == n.call("belt_pouch") and items.worn_of(1)[place(items, "waist:quiver")] == n.call("quiver"), "on a belt the pouch hangs beside the quiver")
	var pouch_id: int = -1 - place(items, "waist:pouch")
	give(items, 1, "log")
	items.action(1, Net.ACT_CHEST_PUT, inv.numbers.find(n.call("log")), pouch_id, 1, Vector3.ZERO)
	check(held(items, 1, "waist:pouch").is_empty() and inv.count_of(n.call("log")) == 1, "a pouch refuses a log")
	inv.clear_slot(inv.numbers.find(n.call("log")))
	give(items, 1, "berries", 5)
	items.action(1, Net.ACT_CHEST_PUT, inv.numbers.find(berries), pouch_id, 5, Vector3.ZERO)
	check(int(held(items, 1, "waist:pouch").get(berries, 0)) == 5, "a pouch takes small things")
	give(items, 1, "weapon_scabbard")
	wear(items, 1, "weapon_scabbard")
	give(items, 1, "tool_roll")
	notices.clear()
	wear(items, 1, "tool_roll")
	check(items.worn_of(1)[place(items, "waist:scabbard")] == n.call("weapon_scabbard") and items.worn_of(1)[place(items, "waist:tools")] == 0 and notices.has("Your belt has no free point. Take something off it first."), "the belt's three points are taken (quiver, pouch, scabbard): a tool roll is refused")
	notices.clear()
	items.action(1, Net.ACT_UNWEAR, place(items, "waist:base"), 0, 0, Vector3.ZERO)
	check(items.worn_of(1)[place(items, "waist:base")] == n.call("leather_belt") and notices.has("Take off what hangs on it first."), "the belt does not come off under its pouch and scabbard")
	var axe_two: int = give(items, 1, "stone_axe")
	items.action(1, Net.ACT_CHEST_PUT, axe_two, -1 - place(items, "waist:scabbard"), 1, Vector3.ZERO)
	check(held(items, 1, "waist:scabbard").is_empty(), "the scabbard refuses an axe (only a sword)")
	inv.clear_slot(inv.numbers.find(axe))

	# 7. Take a piece out, then the full pack off, drop it and pick it up: contents identical.
	items.action(1, Net.ACT_CHEST_TAKE, 0, pack_id, 5, Vector3.ZERO)
	var after_take: Dictionary = held(items, 1, "shoulder:base")
	check(int(after_take.get(stone, 0)) == 10 and inv.count_of(stone) == 5, "taking from the worn pack moves the stack to the pack (%s)" % str(after_take))
	items.action(1, Net.ACT_CHEST_PUT, inv.numbers.find(stone), pack_id, 5, Vector3.ZERO)
	var stones_all: int = everywhere(items, stone)
	var berries_all: int = everywhere(items, berries)
	var kg_worn: float = items.carried_kg_of(1)
	items.action(1, Net.ACT_UNWEAR, place(items, "shoulder:base"), 0, 0, Vector3.ZERO)
	var pack_slot: int = inv.numbers.find(n.call("fibre_shoulder_bag"))
	check(pack_slot >= 0 and rows_count(inv.inst_of(pack_slot).get("bag", [])) == full and items.worn_of(1)[place(items, "shoulder:base")] == 0, "taken off, the full pack goes to the pack with its contents")
	check(absf(items.carried_kg_of(1) - kg_worn - CarryRules.weight_of("fibre_shoulder_bag", items._carry_cfg)) < 0.0001, "its load weighs the same in the pack; only the pack's own weight is added, as for any piece taken off (%.2f -> %.2f kg)" % [kg_worn, items.carried_kg_of(1)])
	items.action(1, Net.ACT_DROP, pack_slot, 0, 1, Vector3(1.0, 10.0, 0.0))
	var ground: int = -1

	for id in items._items:
		if int(items._items[id].get("number", 0)) == n.call("fibre_shoulder_bag"):
			ground = id

	check(ground >= 0 and rows_count(items._items[ground].get("inst", {}).get("bag", [])) == full and inv.count_of(n.call("fibre_shoulder_bag")) == 0, "dropped, the pack lies on the ground with its contents")
	items.action(1, Net.ACT_PICKUP, ground, 0, 0, Vector3.ZERO)
	pack_slot = inv.numbers.find(n.call("fibre_shoulder_bag"))
	check(pack_slot >= 0 and rows_count(inv.inst_of(pack_slot).get("bag", [])) == full and not items._items.has(ground), "picked up, its contents are identical")
	check(everywhere(items, stone) == stones_all and everywhere(items, berries) == berries_all and stones_all == 15, "nothing lost or duplicated by drop and pick-up (%d stones)" % stones_all)

	# 8. Put the full pack in a chest; a second player takes it out.
	var chest_id: int = items.dev_place("chest@1,0,0")
	var chest = items._chests.get(int(items._items.get(chest_id, {}).get("struct", {}).get("uid", -1)))
	items.action(1, Net.ACT_CHEST_OPEN, chest_id, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, pack_slot, chest_id, 1, Vector3.ZERO)
	var in_chest: int = chest.numbers.find(n.call("fibre_shoulder_bag")) if chest != null else -1
	check(in_chest >= 0 and rows_count(chest.inst_of(in_chest).get("bag", [])) == full and inv.count_of(n.call("fibre_shoulder_bag")) == 0, "in a chest the pack keeps its contents")
	items.peer_connected_hello(2, KEY2)
	items.report_position(2, Vector3(0.0, 10.0, 0.0))
	var inv2 = items.inventory_of(2)
	empty(inv2)
	items.action(2, Net.ACT_CHEST_OPEN, chest_id, 0, 0, Vector3.ZERO)
	items.action(2, Net.ACT_CHEST_TAKE, in_chest, chest_id, 1, Vector3.ZERO)
	var slot2: int = inv2.numbers.find(n.call("fibre_shoulder_bag"))
	check(slot2 >= 0 and rows_count(inv2.inst_of(slot2).get("bag", [])) == full and chest.count_of(n.call("fibre_shoulder_bag")) == 0, "the second player takes it out full")
	check(everywhere(items, stone) == stones_all and everywhere(items, berries) == berries_all and everywhere(items, n.call("fibre_shoulder_bag")) == 1, "nothing lost or duplicated by the hand-over through the chest")
	check(items.carried_kg_of(2) >= 15.0, "its contents weigh on the second player (%.2f kg)" % items.carried_kg_of(2))

	# 9. Spoilage continues inside a bag, worn, on the ground and in a chest.
	var berry_age: Callable = func(rows_in: Array) -> int:
		for row in rows_in:
			if int(row[0]) == berries:
				return int(row[2])

		return -1

	var pouch_rows: Callable = func() -> Array: return items.worn_slots_of(1)[place(items, "waist:pouch")][3].get("bag", [])
	var worn_age: int = berry_age.call(pouch_rows.call())
	var carried_age: int = berry_age.call(inv2.inst_of(slot2).get("bag", []))

	for i in 40:
		items._spoil_tick(15.0)

	check(berry_age.call(pouch_rows.call()) > worn_age and berry_age.call(inv2.inst_of(slot2).get("bag", [])) > carried_age, "food in a worn pouch and in a carried pack ages (%d -> %d, %d -> %d)" % [worn_age, berry_age.call(pouch_rows.call()), carried_age, berry_age.call(inv2.inst_of(slot2).get("bag", []))])
	items.action(2, Net.ACT_DROP, slot2, 0, 1, Vector3(1.0, 10.0, 1.0))

	for id in items._items:
		if int(items._items[id].get("number", 0)) == n.call("fibre_shoulder_bag"):
			ground = id

	var ground_age: int = berry_age.call(items._items[ground]["inst"]["bag"])

	for i in 40:
		items._spoil_tick(15.0)

	check(berry_age.call(items._items[ground]["inst"]["bag"]) > ground_age, "food in a bag on the ground keeps ageing (%d -> %d)" % [ground_age, berry_age.call(items._items[ground]["inst"]["bag"])])

	# 10. Save and reload: the worn pouch (full) and the pack on the ground (full).
	var pouch_saved: Dictionary = held(items, 1, "waist:pouch")
	var ground_saved: Dictionary = rows_count(items._items[ground]["inst"]["bag"])
	items._dirty = true
	items.save()
	items._finish_writer()
	var back = make()
	back.peer_connected_hello(2, KEY2)
	var back_ground: Dictionary = {}

	for id in back._items:
		if int(back._items[id].get("number", 0)) == n.call("fibre_shoulder_bag"):
			back_ground = rows_count(back._items[id].get("inst", {}).get("bag", []))

	check(held(back, 1, "waist:pouch") == pouch_saved and not pouch_saved.is_empty(), "after a restart the worn pouch holds the same (%s)" % str(held(back, 1, "waist:pouch")))
	check(back_ground == ground_saved and int(ground_saved.get(stone, 0)) == 15, "and the dropped pack on the ground too (%s)" % str(back_ground))
	check(everywhere(back, stone) == stones_all and everywhere(back, berries) == berries_all, "nothing lost or duplicated by the save")
	check(int(held(back, 1, "waist:quiver").get(arrow, 0)) == 39, "the quiver's arrows are saved worn")

	# 11. Over the limit: slowed, not stripped, told once.
	back.vitals_of(1)["weight"] = 10.0
	give(back, 1, "stone", 10)
	notices.clear()
	back._carry_notice(1)
	back._carry_notice(1)
	check(notices.count("You carry more than you can. It slows you down until you put something down.") == 1 and back.inventory_of(1).count_of(stone) == 10, "over the carry limit a player is told once and keeps everything")

	# 12. No bag takes a large log (the retired pack frame was the only one that did, Dave 13 Nov 2026): a worn bag refuses it and it stays in the pack.
	var inv1 = back.inventory_of(1)
	empty(inv1)
	back.vitals_of(1)["weight"] = 75.0
	give(back, 1, "fibre_shoulder_bag")
	wear(back, 1, "fibre_shoulder_bag")
	back.action(1, Net.ACT_ADMIN_GIVE, n.call("log_oak"), 0, 1, Vector3.ZERO)
	notices.clear()
	back.action(1, Net.ACT_CHEST_PUT, inv1.numbers.find(n.call("log_oak")), -1 - place(back, "shoulder:base"), 1, Vector3.ZERO)
	check(held(back, 1, "shoulder:base").is_empty() and inv1.count_of(n.call("log_oak")) == 1 and notices.has("That is too big for a bag."), "a worn bag refuses a large log")
	inv1.clear_slot(inv1.numbers.find(n.call("log_oak")))

	# 13. Movement: nothing worn slows the walk or adds effort by itself any more (worn_speed_mult and loaded_effort are gone from the data, the frame is retired).
	var gone: Array = []

	for id in table.ids():
		if table.entry(id).has("worn_speed_mult") or table.entry(id).has("loaded_effort") or str(table.entry(id).get("bag_takes", "")) == "awkward":
			gone.append(id)

	check(gone.is_empty(), "no item row has worn_speed_mult, loaded_effort or bag_takes awkward (%s)" % str(gone))

	# 14. Wolves smell meat in a worn bag and in a bag carried in the pack, and take it from both.
	give(back, 1, "stone", 10)
	back.action(1, Net.ACT_CHEST_PUT, inv1.numbers.find(stone), -1 - place(back, "shoulder:base"), 10, Vector3.ZERO)
	give(back, 1, "raw_meat", 2)
	back.action(1, Net.ACT_CHEST_PUT, inv1.numbers.find(n.call("raw_meat")), -1 - place(back, "shoulder:base"), 2, Vector3.ZERO)
	check(inv1.count_of(n.call("raw_meat")) == 0 and back.carried_count(1, "raw_meat") == 2, "meat in the worn bag still counts as carried")

	# 15. Swapping one worn bag for another: the full one goes to the pack whole, the new one is worn empty.
	give(back, 1, "leather_satchel")
	wear(back, 1, "leather_satchel")
	var bag_at: int = inv1.numbers.find(n.call("fibre_shoulder_bag"))
	check(back.worn_of(1)[place(back, "shoulder:base")] == n.call("leather_satchel") and held(back, 1, "shoulder:base").is_empty() and bag_at >= 0 and rows_count(inv1.inst_of(bag_at).get("bag", [])) == {stone: 10, n.call("raw_meat"): 2}, "a satchel put on over a full shoulder bag: the shoulder bag goes to the pack with its load")
	check(back.carried_count(1, "raw_meat") == 2 and back.take_all_meat(1) == 2 and back.carried_count(1, "raw_meat") == 0 and rows_count(back.inventory_of(1).inst_of(bag_at).get("bag", [])) == {stone: 10}, "wolves take the meat out of the bag in the pack and leave the stones")

	# 16. Bulk buttons with a worn bag open: Store all stops at the quiver's 40, Take all empties it.
	var quiver_at: int = -1 - place(back, "waist:quiver")
	give(back, 1, "wooden_arrow", 20)
	give(back, 1, "stone", 3)

	for slot in inv1.hotbar_slots:   # an admin give fills from slot 0; Store all leaves the hotbar (TEST-008), so put the stacks in the backpack first
		if inv1.numbers[slot] == arrow or inv1.numbers[slot] == stone:
			back.action(1, Net.ACT_MOVE, slot, inv1.free_bag_slot(), 0, Vector3.ZERO)

	back.action(1, Net.ACT_CHEST_OPEN, quiver_at, 0, 0, Vector3.ZERO)
	back.action(1, Net.ACT_BULK, 1, 0, 0, Vector3.ZERO)
	check(int(held(back, 1, "waist:quiver").get(arrow, 0)) == 40 and inv1.count_of(arrow) == 19 and not held(back, 1, "waist:quiver").has(stone) and inv1.count_of(stone) == 3, "Store all fills the quiver to its 40 arrows and leaves the stones")
	back.action(1, Net.ACT_BULK, 0, 0, 0, Vector3.ZERO)
	check(held(back, 1, "waist:quiver").is_empty() and inv1.count_of(arrow) == 59, "Take all empties the quiver into the pack")

	# 18. A dropped bag that holds anything never despawns; an empty one does.
	back.action(1, Net.ACT_DROP, bag_at, 0, 1, Vector3(2.0, 10.0, 0.0))
	give(back, 1, "belt_pouch")
	back.action(1, Net.ACT_DROP, inv1.numbers.find(n.call("belt_pouch")), 0, 1, Vector3(2.0, 10.0, 1.0))
	back._expire_items(100000.0)
	var lying: Dictionary = {}

	for id in back._items:
		lying[int(back._items[id].get("number", 0))] = int(lying.get(int(back._items[id].get("number", 0)), 0)) + 1

	check(int(lying.get(n.call("fibre_shoulder_bag"), 0)) == 2 and not lying.has(n.call("belt_pouch")), "after the despawn time the full shoulder bags still lie there; the empty pouch is gone")

	# 19. A trader never buys a bag with something in it; empty, it sells.
	var trade = TradeScript.new()
	var trade_dir: String = DIR + "_trade"
	DirAccess.make_dir_recursive_absolute(trade_dir)
	trade.items = back
	trade.npcs = {"npcs": {"hob": {"dormant": false, "placed": true, "pos": Vector3(1.0, 10.0, 0.0)}}}
	trade.setup(trade_dir)
	trade.now = func(): return 1000.0
	trade.game_seconds = func(): return 0.0
	trade.send_shop = func(_a, _b, _c, _d, _e, _f, _g, _h, _i, _j, _k, _l): pass
	(trade._shops["hob"]["buys"] as Array).append("gear")
	give(back, 1, "belt_pouch")
	var spare: int = inv1.numbers.find(n.call("belt_pouch"))
	inv1.inst[spare] = {"bag": [[berries, 2, 0]]}
	check(trade.deal(1, "hob", 1, spare, 1) == "Empty the bag first." and rows_count(inv1.inst_of(spare).get("bag", [])) == {berries: 2}, "a trader will not buy a bag that holds something")
	inv1.inst[spare] = {}
	check(trade.deal(1, "hob", 1, spare, 1).begins_with("Sold") and inv1.count_of(n.call("belt_pouch")) == 0, "an empty one sells")

	print("test_carrying: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
