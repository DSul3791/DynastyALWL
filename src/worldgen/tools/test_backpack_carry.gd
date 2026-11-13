extends SceneTree

# DESIGN-001 (BUGLIST-001): a worn backpack improves the comfortable carry weight and the limit (items.json carry_bonus_kg: 12 Hide - Backpack,
# 18 Leather - Backpack, so quality matters) and never changes the pack's inventory slot count. Real server state: slots and thresholds measured
# before equipping, equipped and after unequipping; near capacity nothing is lost or doubled (the pack's slots follow what it holds, protocol 116);
# and the worn backpack and its thresholds survive a save and reload.
#   godot --headless --path . --script res://src/worldgen/tools/test_backpack_carry.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const DIR := "user://test_backpack_carry"
const KEY := "backpackcarry01"
const OVER_NOTICE := "You carry more than you can. It slows you down until you put something down."

var failures: int = 0
var notices: Array = []


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
	items.send_chest = func(_p, _id, _b): pass
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


# [slot_count, usable, limit kg, comfortable kg] of the player now: the numbers the server's pick-up check and the client's bar use.
func measure(items) -> Array:
	var inv = items.inventory_of(1)
	var body: float = items._carry_body(1)
	return [inv.slot_count, inv.usable, CarryRules.cap_kg(body, items._carry_cfg), CarryRules.comfort_kg(body, items._carry_cfg)]


func back_place(items) -> int:
	return items._worn_places().find("back:base")


func put_on(items, number: int) -> void:
	var inv = items.inventory_of(1)
	items.action(1, Net.ACT_WEAR, inv.numbers.find(number), 0, 0, Vector3.ZERO)


func take_off(items) -> void:
	items.action(1, Net.ACT_UNWEAR, back_place(items), 0, 0, Vector3.ZERO)


# Every unit of `number` in the pack and worn (a backpack is either).
func total(items, number: int) -> int:
	return items.inventory_of(1).count_of(number) + items.worn_of(1).count(number)


func empty(inv) -> void:
	for slot in inv.slot_count:
		inv.clear_slot(slot)

	inv.trim()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	var items = make()
	var table = items.table
	var inv = items.inventory_of(1)
	var hide: int = table.number_of("backpack")
	var leather: int = table.number_of("leather_backpack")
	var stone: int = table.number_of("stone")
	var axe: int = table.number_of("stone_axe")
	items.vitals_of(1)["weight"] = 75.0
	var cfg: Dictionary = items._carry_cfg
	empty(inv)

	# 1. The data: both backpacks name a weight effect, the better one a larger one.
	var hide_kg: float = float(table.entry("backpack").get("carry_bonus_kg", 0.0))
	var leather_kg: float = float(table.entry("leather_backpack").get("carry_bonus_kg", 0.0))
	check(hide > 0 and leather > 0 and hide_kg == 12.0 and leather_kg == 18.0 and leather_kg > hide_kg, "carry_bonus_kg: Hide - Backpack %.0f, Leather - Backpack %.0f (quality matters)" % [hide_kg, leather_kg])

	# 2. Before: 30 slots, the plain limit and comfortable load of a 75 kg body.
	var bare: Array = measure(items)
	print("INFO bare: slots %d, usable %d, limit %.2f kg, comfortable %.2f kg" % bare)
	check(bare[0] == 30 and is_equal_approx(bare[2], 52.5) and is_equal_approx(bare[3], 42.0), "before: 30 slots, limit 52.5 kg, comfortable 42 kg")

	# 3. Equipped: the slot count does not move; the limit and the comfortable load rise by the backpack's effect; leather beats hide.
	items.give(1, hide, 1)
	items.give(1, leather, 1)
	put_on(items, hide)
	var with_hide: Array = measure(items)
	print("INFO hide: slots %d, usable %d, limit %.2f kg, comfortable %.2f kg" % with_hide)
	check(items.worn_of(1)[back_place(items)] == hide, "the Hide - Backpack is worn")
	check(with_hide[0] == bare[0] and with_hide[1] == bare[1], "worn Hide - Backpack: the pack's slot count is unchanged (%d)" % with_hide[0])
	check(is_equal_approx(with_hide[2], bare[2] + 12.0) and is_equal_approx(with_hide[3], bare[3] + 12.0 * float(cfg.get("free_ratio", 0.8))), "worn Hide - Backpack: limit +12 kg and comfortable load +%.1f kg" % (with_hide[3] - bare[3]))
	put_on(items, leather)   # swaps: the hide pack comes off into the pack
	var with_leather: Array = measure(items)
	print("INFO leather: slots %d, usable %d, limit %.2f kg, comfortable %.2f kg" % with_leather)
	check(items.worn_of(1)[back_place(items)] == leather and inv.count_of(hide) == 1, "swapping to the Leather - Backpack returns the hide one to the pack")
	check(with_leather[0] == bare[0] and with_leather[1] == bare[1], "worn Leather - Backpack: the pack's slot count is unchanged (%d)" % with_leather[0])
	check(is_equal_approx(with_leather[2], bare[2] + 18.0) and with_leather[3] > with_hide[3], "worn Leather - Backpack: limit +18 kg, comfortable load above the hide pack's")

	# 4. Hindering follows the new comfortable load: a load that slows a bare body does not slow a pack-wearer.
	var load_kg: float = bare[3] + 3.0
	check(CarryRules.speed_factor(load_kg, 75.0, cfg) < 1.0 and is_equal_approx(CarryRules.speed_factor(load_kg, items._carry_body(1), cfg), 1.0), "%.0f kg slows a bare body but not one in a Leather - Backpack" % load_kg)

	# 5. Unequipped: the plain numbers return.
	take_off(items)
	var unworn: Array = measure(items)
	print("INFO unworn: slots %d, usable %d, limit %.2f kg, comfortable %.2f kg" % unworn)
	check(items.worn_of(1)[back_place(items)] == 0 and inv.count_of(leather) == 1, "the Leather - Backpack is back in the pack")
	check(unworn[0] == bare[0] and unworn[1] == bare[1] and is_equal_approx(unworn[2], bare[2]) and is_equal_approx(unworn[3], bare[3]), "unequipped: slots, limit and comfortable load are the plain ones again")

	# 6. Near capacity: a pack of more than 30 slots loaded to a weight only the worn backpack allows, then the backpack comes off: nothing is lost
	# or doubled, the player over the plain limit is slowed and told once, and the pack holds every item.
	empty(inv)
	inv.add(leather, 1)
	put_on(items, leather)
	inv.add(axe, 40)     # unstackable: 40 slots, 40 kg
	inv.add(stone, 28)   # 28 kg more: 68 kg, over the plain 52.5 and under 52.5 + 18 = 70.5 (a worn backpack's own weight is not counted)
	var axes: int = total(items, axe)
	var stones: int = total(items, stone)
	var packs: int = total(items, leather)
	var worn_state: Array = measure(items)
	var kg_worn: float = items.carried_kg_of(1)
	check(axes == 40 and stones == 28 and packs == 1 and worn_state[0] > 30 and kg_worn > bare[2] and kg_worn < worn_state[2], "near capacity worn: %d slots, %.1f kg carried, between the plain limit %.1f and the backpack's %.1f" % [worn_state[0], kg_worn, bare[2], worn_state[2]])
	var room: int = items._fit(1, inv, stone, 50)
	check(room > 0 and room < 50 and room == int((worn_state[2] - kg_worn) / CarryRules.weight_of("stone", cfg)), "the server's room for more is what is left under the backpack's limit (%d stone)" % room)
	notices.clear()
	take_off(items)
	items._carry_notice(1)
	items._carry_notice(1)
	var after: Array = measure(items)
	print("INFO near capacity unworn: slots %d, usable %d, limit %.2f kg, comfortable %.2f kg, carried %.2f kg" % [after[0], after[1], after[2], after[3], items.carried_kg_of(1)])
	check(total(items, axe) == axes and total(items, stone) == stones and total(items, leather) == packs and inv.count_of(leather) == 1 and items.worn_of(1)[back_place(items)] == 0, "taking the backpack off near capacity loses and doubles nothing (40 axes, 28 stones, 1 backpack, now in the pack)")
	check(after[0] >= 69 and after[1] >= 69 and is_equal_approx(after[2], bare[2]) and is_equal_approx(after[3], bare[3]), "the pack holds all 69 stacks in %d slots and the limit is the plain one again" % after[0])
	check(items.carried_kg_of(1) > after[2] and items._fit(1, inv, stone, 5) == 0 and notices.count(OVER_NOTICE) == 1, "over the plain limit now: nothing more is picked up, the player is told once and keeps everything")
	check(CarryRules.speed_factor(items.carried_kg_of(1), items._carry_body(1), cfg) < 1.0, "and the walk is slowed, not stripped")

	# 7. Back on, the same load is under the limit again with nothing changed.
	put_on(items, leather)
	check(items.carried_kg_of(1) < measure(items)[2] and total(items, axe) == axes and total(items, stone) == stones and total(items, leather) == 1, "worn again the same load is under the limit and nothing changed")
	empty(inv)
	check(inv.slot_count == 30, "an emptied pack gives its extra slots back to 30 (%d)" % inv.slot_count)

	# 8. Save and reload: a worn backpack is still worn and still raises the limit by the same amount; the pack holds what it held.
	inv.add(stone, 10)
	var saved: Array = measure(items)
	items.save()
	var back = make()
	var back_body: float = float(back.vitals_of(1).get("weight", 75.0))
	var back_inv = back.inventory_of(1)
	check(back.worn_of(1)[back_place(back)] == leather, "after a reload the Leather - Backpack is still worn")
	check(is_equal_approx(back._carry_body(1), back_body + 18.0 / 0.7) and back_inv.slot_count == saved[0] and back_inv.count_of(stone) == 10 and back_inv.count_of(leather) == 0, "and still raises the limit by 18 kg, with the same %d slots and 10 stones" % saved[0])
	take_off(back)
	check(back_inv.count_of(leather) == 1 and is_equal_approx(back._carry_body(1), back_body) and back_inv.slot_count == saved[0], "unequipped after the reload: the plain limit, the backpack in the pack, slot count unchanged")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
