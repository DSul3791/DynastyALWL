extends SceneTree

# DESIGN-001 (BUGLIST-001): a worn back pack improves the comfortable carry weight and the limit (items.json carry_bonus_kg; Dave 15 Nov 2026, four
# tiers that replace the old packs: Simple 5, Improved 15, Quality 30, Advanced 50, so quality matters) and never changes the pack's inventory slot count.
# The four old packs (Hide and Leather backpacks, Wicker pack basket, Traveller's rucksack) are retired; a saved one loads as its new tier (renames.json).
# No back pack has slots of its own or can be opened (Dave 13 Nov 2026: "Backpacks do not have slots. The only thing they do is give you more
# carry weight." and "no backpacks have slots they only improve the weight you can carry due to ergonomics"); an older save's back pack that
# still carries bag contents loads plain, and a real bag (the Fibre - Shoulder bag) keeps its contents. Real server state: slots and thresholds measured
# before equipping, equipped and after unequipping; near capacity nothing is lost or doubled (the pack's slots follow what it holds, protocol 116);
# and the worn backpack and its thresholds survive a save and reload.
#   godot --headless --path . --script res://src/worldgen/tools/test_backpack_carry.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const BagRules := preload("res://src/shared/bag_rules.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")   # the hand slot a craft holds its tool in (protocol 126)

const DIR := "user://test_backpack_carry"
const KEY := "backpackcarry01"
const OVER_NOTICE := "You carry more than you can. It slows you down until you put something down."

var failures: int = 0
var notices: Array = []
var chest_opens: int = 0   # container windows the server sent


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
	items.send_chest = func(_p, _id, _b): chest_opens += 1
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


# True when the worn backpack is not a container: opening it sends no window and a put leaves the item in the pack, the worn instance stays plain.
func refuses_container(items) -> bool:
	var inv = items.inventory_of(1)
	var opens: int = chest_opens
	var stone: int = items.table.number_of("stone")
	items.give(1, stone, 1)
	var before: int = inv.count_of(stone)
	items.action(1, Net.ACT_CHEST_OPEN, -1 - back_place(items), 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, inv.numbers.find(stone), -1 - back_place(items), 1, Vector3.ZERO)
	var ok: bool = chest_opens == opens and inv.count_of(stone) == before and not items.worn_slots_of(1)[back_place(items)][3].has("bag")
	inv.clear_slot(inv.numbers.find(stone))
	return ok


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
	var hide: int = table.number_of("simple_backpack")
	var leather: int = table.number_of("improved_backpack")
	var stone: int = table.number_of("stone")
	var axe: int = table.number_of("stone_axe")
	items.vitals_of(1)["weight"] = 75.0
	var cfg: Dictionary = items._carry_cfg
	empty(inv)

	# 0. The four recipes as Dave gave them (15 Nov 2026): Simple by hand, Improved and Quality at the Leatherworking table, Advanced at the Advanced
	# smithy (brick_forge level 3); the old packs' recipes are retired. The Quality pack asks for Copper nails (new, item 1487) and takes any nails.
	var made_as: Dictionary = {
		"simple_backpack": [[["hide", 5], ["twine", 20], ["stick", 4]], "", 1],
		"improved_backpack": [[["leather", 5], ["twine", 20], ["hardwood_board", 1]], "leatherworking_table", 1],
		"quality_backpack": [[["leather", 10], ["sinew", 20], ["copper_nails", 15], ["hardwood_board", 2]], "leatherworking_table", 1],
		"advanced_backpack": [[["steel_ingot", 2], ["leather", 25], ["sinew", 40]], "brick_forge", 3],
	}

	for id in made_as:
		var makers: Array = items.recipes.makers_of(table.number_of(id))
		var r: Dictionary = items.recipes.recipe(int(makers[0])) if makers.size() == 1 else {}
		var needs: Array = []

		for need in r.get("needs", []):
			needs.append([table.id_of(int(need[0])), int(need[1])])

		check(needs == made_as[id][0] and str(r.get("station", "")) == made_as[id][1] and int(r.get("station_level", 1)) == made_as[id][2] and bool(r.get("known", false)), "%s: one known recipe, %s at %s" % [id, str(needs), made_as[id][1] if made_as[id][1] != "" else "hand"])

	for id in ["backpack", "leather_backpack", "wicker_pack_basket", "travellers_rucksack"]:
		check(items.recipes.makers_of(table.number_of(id)).is_empty(), "the old %s is not made any more (its recipe is retired)" % id)

	var copper_nails: int = table.number_of("copper_nails")
	var copper_makers: Array = items.recipes.makers_of(copper_nails)
	var copper_group: PackedInt32Array = table.group_members(copper_nails)
	check(copper_nails == 1487 and copper_group.has(table.number_of("bronze_nails")) and copper_group.has(table.number_of("nails")) and not table.group_members(table.number_of("nails")).has(copper_nails) and copper_makers.size() == 1 and str(items.recipes.recipe(int(copper_makers[0])).get("station", "")) == "forge", "Copper nails are made at the Primitive smithy; a Copper nails need takes any nails, and a building's nails cost does not take Copper nails")
	inv.add(table.number_of("leather"), 10)
	inv.add(table.number_of("sinew"), 20)
	inv.add(copper_nails, 15)
	inv.add(table.number_of("hardwood_board"), 2)
	check(items.recipes.craft(int(items.recipes.makers_of(table.number_of("quality_backpack"))[0]), inv) and inv.count_of(table.number_of("quality_backpack")) == 1 and inv.count_of(copper_nails) == 0, "a Quality - Backpack takes 15 Copper nails for its nails")
	empty(inv)
	inv.add(table.number_of("leather"), 10)
	inv.add(table.number_of("sinew"), 20)
	inv.add(table.number_of("bronze_nails"), 10)
	inv.add(table.number_of("nails"), 5)
	inv.add(table.number_of("hardwood_board"), 2)
	check(items.recipes.craft(int(items.recipes.makers_of(table.number_of("quality_backpack"))[0]), inv) and inv.count_of(table.number_of("quality_backpack")) == 1 and inv.count_of(table.number_of("bronze_nails")) == 0 and inv.count_of(table.number_of("nails")) == 0, "and any nails do: 10 Bronze and 5 iron Nails (Dave: \"really it can use any nails\")")
	empty(inv)
	inv.add(table.number_of("hide"), 5)
	inv.add(table.number_of("twine"), 20)
	inv.add(table.number_of("stick"), 4)
	items.action(1, Net.ACT_CRAFT_QUEUE, int(items.recipes.makers_of(hide)[0]), 0, 1, CraftHand.at(items, 1, int(items.recipes.makers_of(hide)[0])))

	for _tick in 200:
		items._craft_tick(0.25)

	check(inv.count_of(hide) == 1 and inv.count_of(table.number_of("hide")) == 0, "a Simple - Backpack is made by hand from 5 Hide, 20 Twine and 4 Sticks")
	empty(inv)

	# 1. The data: the Simple and Improved backpacks name a weight effect, the better one a larger one.
	var hide_kg: float = float(table.entry("simple_backpack").get("carry_bonus_kg", 0.0))
	var leather_kg: float = float(table.entry("improved_backpack").get("carry_bonus_kg", 0.0))
	check(hide > 0 and leather > 0 and hide_kg == 5.0 and leather_kg == 15.0 and leather_kg > hide_kg, "carry_bonus_kg: Simple - Backpack %.0f, Improved - Backpack %.0f (quality matters)" % [hide_kg, leather_kg])
	check(BagRules.slots_of(table, hide) == 0 and BagRules.slots_of(table, leather) == 0 and not table.entry("simple_backpack").has("bag_takes") and not table.entry("improved_backpack").has("bag_takes"), "neither backpack has slots (no bag_slots, no bag_takes): they only give carry weight")

	# 1b. The four tiers (Dave 15 Nov 2026: lowest +5, top +50 kg; the middle two are provisional): no slots, a carry bonus that raises the server's limit, never opened.
	var back_packs: Dictionary = {"simple_backpack": 5.0, "improved_backpack": 15.0, "quality_backpack": 30.0, "advanced_backpack": 50.0}
	var body_plain: float = items._carry_body(1)

	for id in back_packs:
		var number: int = table.number_of(id)
		items.give(1, number, 1)
		put_on(items, number)
		var entry: Dictionary = table.entry(id)
		check(BagRules.slots_of(table, number) == 0 and not entry.has("bag_slots") and not entry.has("bag_takes") and not entry.has("loaded_effort") and float(entry.get("carry_bonus_kg", 0.0)) == back_packs[id], "%s: no slots, carry_bonus_kg %.0f" % [id, back_packs[id]])
		check(items.worn_of(1)[back_place(items)] == number and is_equal_approx(items._carry_body(1), body_plain + float(back_packs[id]) / 0.7), "%s worn raises the carry limit by %.0f kg" % [id, back_packs[id]])
		check(refuses_container(items), "%s worn is not opened and takes nothing" % id)
		take_off(items)

	check(is_equal_approx(items._carry_body(1), body_plain), "with none worn the limit is the plain one")
	check(not table.entry("wooden_pack_frame").has("slot") and bool(table.entry("wooden_pack_frame").get("retired", false)) and not table.entry("wooden_pack_frame").has("worn_speed_mult"), "the Wooden - Pack frame is retired (Dave 13 Nov 2026): no slot to wear it in, no speed penalty left")
	var replaced_by: Dictionary = {"backpack": "simple_backpack", "leather_backpack": "improved_backpack", "wicker_pack_basket": "simple_backpack", "travellers_rucksack": "quality_backpack"}

	for id in replaced_by:
		var old_row: Dictionary = table.entry(id)
		check(bool(old_row.get("retired", false)) and not old_row.has("slot") and not old_row.has("carry_bonus_kg") and table.current_number(table.number_of(id)) == table.number_of(replaced_by[id]), "%s is retired (Dave 15 Nov 2026): nothing to wear, and a saved one loads as %s" % [id, replaced_by[id]])
	empty(inv)

	# 2. Before: 30 slots, the plain limit and comfortable load of a 75 kg body.
	var bare: Array = measure(items)
	print("INFO bare: slots %d, usable %d, limit %.2f kg, comfortable %.2f kg" % bare)
	check(bare[0] == 30 and is_equal_approx(bare[2], 52.5) and is_equal_approx(bare[3], 42.0), "before: 30 slots, limit 52.5 kg, comfortable 42 kg")

	# 3. Equipped: the slot count does not move; the limit and the comfortable load rise by the backpack's effect; Improved beats Simple.
	items.give(1, hide, 1)
	items.give(1, leather, 1)
	put_on(items, hide)
	var with_hide: Array = measure(items)
	print("INFO hide: slots %d, usable %d, limit %.2f kg, comfortable %.2f kg" % with_hide)
	check(items.worn_of(1)[back_place(items)] == hide, "the Simple - Backpack is worn")
	check(refuses_container(items), "the worn Simple - Backpack cannot be opened as a container and takes nothing")
	check(with_hide[0] == bare[0] and with_hide[1] == bare[1], "worn Simple - Backpack: the pack's slot count is unchanged (%d)" % with_hide[0])
	check(is_equal_approx(with_hide[2], bare[2] + 5.0) and is_equal_approx(with_hide[3], bare[3] + 5.0 * float(cfg.get("free_ratio", 0.8))), "worn Simple - Backpack: limit +5 kg and comfortable load +%.1f kg" % (with_hide[3] - bare[3]))
	put_on(items, leather)   # swaps: the Simple pack comes off into the pack
	var with_leather: Array = measure(items)
	print("INFO leather: slots %d, usable %d, limit %.2f kg, comfortable %.2f kg" % with_leather)
	check(items.worn_of(1)[back_place(items)] == leather and inv.count_of(hide) == 1, "swapping to the Improved - Backpack returns the Simple one to the pack")
	check(refuses_container(items), "the worn Improved - Backpack cannot be opened as a container and takes nothing")
	check(with_leather[0] == bare[0] and with_leather[1] == bare[1], "worn Improved - Backpack: the pack's slot count is unchanged (%d)" % with_leather[0])
	check(is_equal_approx(with_leather[2], bare[2] + 15.0) and with_leather[3] > with_hide[3], "worn Improved - Backpack: limit +15 kg, comfortable load above the Simple pack's")

	# The client's carry_body_kg is CarryRules.carry_body_kg over its worn numbers (the server's worn_of): the same call gives the same body value.
	check(is_equal_approx(CarryRules.carry_body_kg(75.0, items.worn_of(1), table, cfg), items._carry_body(1)) and is_equal_approx(CarryRules.carry_body_kg(75.0, [0, 0, 0], table, cfg), 75.0), "client and server work the carry body weight out through one shared helper (%.2f kg worn)" % items._carry_body(1))

	# 4. Hindering follows the new comfortable load: a load that slows a bare body does not slow a pack-wearer.
	var load_kg: float = bare[3] + 3.0
	check(CarryRules.speed_factor(load_kg, 75.0, cfg) < 1.0 and is_equal_approx(CarryRules.speed_factor(load_kg, items._carry_body(1), cfg), 1.0), "%.0f kg slows a bare body but not one in a Improved - Backpack" % load_kg)

	# 5. Unequipped: the plain numbers return.
	take_off(items)
	var unworn: Array = measure(items)
	print("INFO unworn: slots %d, usable %d, limit %.2f kg, comfortable %.2f kg" % unworn)
	check(items.worn_of(1)[back_place(items)] == 0 and inv.count_of(leather) == 1, "the Improved - Backpack is back in the pack")
	check(unworn[0] == bare[0] and unworn[1] == bare[1] and is_equal_approx(unworn[2], bare[2]) and is_equal_approx(unworn[3], bare[3]), "unequipped: slots, limit and comfortable load are the plain ones again")

	# 6. Near capacity: a pack of more than 30 slots loaded to a weight only the worn backpack allows, then the backpack comes off: nothing is lost
	# or doubled, the player over the plain limit is slowed and told once, and the pack holds every item.
	empty(inv)
	inv.add(leather, 1)
	put_on(items, leather)
	inv.add(axe, 40)     # unstackable: 40 slots, 40 kg
	inv.add(stone, 50)   # 25 kg more (50 stones of 0.5 kg, Dave 19 Nov 2026): 65 kg, over the plain 52.5 and under 52.5 + 15 = 67.5 (a worn backpack's own weight is not counted)
	var axes: int = total(items, axe)
	var stones: int = total(items, stone)
	var packs: int = total(items, leather)
	var worn_state: Array = measure(items)
	var kg_worn: float = items.carried_kg_of(1)
	check(axes == 40 and stones == 50 and packs == 1 and worn_state[0] > 30 and kg_worn > bare[2] and kg_worn < worn_state[2], "near capacity worn: %d slots, %.1f kg carried, between the plain limit %.1f and the backpack's %.1f" % [worn_state[0], kg_worn, bare[2], worn_state[2]])
	var room: int = items._fit(1, inv, stone, 50)
	check(room > 0 and room < 50 and room == int((worn_state[2] - kg_worn) / CarryRules.weight_of("stone", cfg)), "the server's room for more is what is left under the backpack's limit (%d stone)" % room)
	notices.clear()
	take_off(items)
	items._carry_notice(1)
	items._carry_notice(1)
	var after: Array = measure(items)
	print("INFO near capacity unworn: slots %d, usable %d, limit %.2f kg, comfortable %.2f kg, carried %.2f kg" % [after[0], after[1], after[2], after[3], items.carried_kg_of(1)])
	check(total(items, axe) == axes and total(items, stone) == stones and total(items, leather) == packs and inv.count_of(leather) == 1 and items.worn_of(1)[back_place(items)] == 0, "taking the backpack off near capacity loses and doubles nothing (40 axes, 50 stones, 1 backpack, now in the pack)")
	var occupied: int = 0

	for slot in inv.slot_count:
		occupied += 1 if inv.numbers[slot] != 0 else 0

	check(occupied == 42 and after[0] >= 42 and after[1] >= 42 and is_equal_approx(after[2], bare[2]) and is_equal_approx(after[3], bare[3]), "the pack holds all 42 stacks (40 axes, 1 stack of stones, the backpack) in %d slots and the limit is the plain one again" % after[0])
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
	items._finish_writer()
	var back = make()
	var back_body: float = float(back.vitals_of(1).get("weight", 75.0))
	var back_inv = back.inventory_of(1)
	check(back.worn_of(1)[back_place(back)] == leather, "after a reload the Improved - Backpack is still worn")
	check(is_equal_approx(back._carry_body(1), back_body + 15.0 / 0.7) and back_inv.slot_count == saved[0] and back_inv.count_of(stone) == 10 and back_inv.count_of(leather) == 0, "and still raises the limit by 15 kg, with the same %d slots and 10 stones" % saved[0])
	take_off(back)
	check(back_inv.count_of(leather) == 1 and is_equal_approx(back._carry_body(1), back_body) and back_inv.slot_count == saved[0], "unequipped after the reload: the plain limit, the backpack in the pack, slot count unchanged")

	# 9. An older save: backpacks that still carry `bag` rows load plain (a pack row, a worn one and one on the ground), their contents add no
	# weight, and a real bag with contents keeps them through the same load.
	var wicker: int = table.number_of("quality_backpack")
	var real_bag: int = table.number_of("fibre_shoulder_bag")
	var kg_stone: float = CarryRules.weight_of("stone", cfg)
	empty(back_inv)
	back.give(1, hide, 1)
	back.give(1, wicker, 1)
	back.give(1, real_bag, 1)
	back.give(1, leather, 1)
	put_on(back, leather)
	back.give(1, hide, 1)
	var hide_at: int = back_inv.numbers.find(hide)
	back_inv.inst[hide_at] = {"bag": [[stone, 5, 0]]}   # written straight into the instance, as an older save would hold it
	var wicker_at: int = back_inv.numbers.find(wicker)
	back_inv.inst[wicker_at] = {"bag": [[stone, 2, 0]]}
	var real_at: int = back_inv.numbers.find(real_bag)
	back_inv.inst[real_at] = {"bag": [[stone, 2, 0]]}
	var worn_row: Array = back._characters[back._peer_key[1]]["worn"]
	worn_row[back_place(back)] = [leather, 1, 0, {"bag": [[stone, 4, 0]]}]
	back.action(1, Net.ACT_DROP, back_inv.numbers.find(hide, hide_at + 1), 0, 1, Vector3(1.0, 10.0, 0.0))
	var on_ground: int = -1

	for id in back._items:
		if int(back._items[id].get("number", 0)) == hide:
			on_ground = id

	back._items[on_ground]["inst"] = {"bag": [[stone, 6, 0]]}
	var kg_with_bags: float = back.carried_kg_of(1)
	back._dirty = true
	back.save()
	back._finish_writer()
	var older = make()
	var older_inv = older.inventory_of(1)
	var older_hide: int = older_inv.numbers.find(hide)
	var older_wicker: int = older_inv.numbers.find(wicker)
	var older_real: int = older_inv.numbers.find(real_bag)
	var older_ground: Dictionary = {}

	for id in older._items:
		if int(older._items[id].get("number", 0)) == hide:
			older_ground = older._items[id].get("inst", {})

	check(older_hide >= 0 and not older_inv.inst_of(older_hide).has("bag"), "an older save's Simple - Backpack in the pack loads with no bag contents")
	check(older.worn_of(1)[back_place(older)] == leather and not older.worn_slots_of(1)[back_place(older)][3].has("bag"), "an older save's worn Improved - Backpack loads with no bag contents")
	check(on_ground >= 0 and not older_ground.has("bag"), "an older save's Simple - Backpack on the ground loads with no bag contents")
	check(older_wicker >= 0 and not older_inv.inst_of(older_wicker).has("bag"), "an older save's Quality - Backpack (no slots now) loads with no bag contents")
	check(absf(kg_with_bags - older.carried_kg_of(1) - 11.0 * kg_stone) < 0.001, "the dropped contents leave no invisible weight (%.2f kg before, %.2f after: the 11 kg of the Simple pack, the worn backpack and the Quality pack are gone)" % [kg_with_bags, older.carried_kg_of(1)])
	check(older_real >= 0 and older_inv.inst_of(older_real).get("bag", []) == [[stone, 2, 0]], "a real bag (the Fibre - Shoulder bag) keeps its contents through the same load")

	# 10. A save from before the four tiers (Dave 15 Nov 2026): the retired packs it holds, in the pack and worn, load as their new tiers
	# (renames.json), and the worn one raises the limit by its new tier's bonus.
	empty(older_inv)
	older.inventory_of(1).add(table.number_of("leather_backpack"), 1)
	older.inventory_of(1).add(table.number_of("wicker_pack_basket"), 1)
	older.inventory_of(1).add(table.number_of("travellers_rucksack"), 1)
	older._characters[older._peer_key[1]]["worn"][back_place(older)] = [table.number_of("backpack"), 1, 0, {}]
	older._dirty = true
	older.save()
	older._finish_writer()
	var renamed = make()
	var renamed_inv = renamed.inventory_of(1)
	var quality: int = table.number_of("quality_backpack")
	check(renamed.worn_of(1)[back_place(renamed)] == hide and renamed_inv.count_of(leather) == 1 and renamed_inv.count_of(hide) == 1 and renamed_inv.count_of(quality) == 1, "an older save's Hide backpack (worn), Leather backpack, Wicker basket and Traveller's rucksack load as Simple (worn), Improved, Simple and Quality")
	check(is_equal_approx(renamed._carry_body(1), float(renamed.vitals_of(1).get("weight", 75.0)) + 5.0 / 0.7), "the worn pack from the older save raises the limit by the Simple - Backpack's 5 kg")

	print("FAILURES: %d" % failures)
	quit(1 if failures > 0 else 0)
