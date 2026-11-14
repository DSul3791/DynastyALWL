extends SceneTree

# Item table and inventory checks.
#   godot --headless --path . --script res://src/worldgen/tools/test_inventory.gd

const ItemTable := preload("res://src/shared/item_table.gd")
const Inventory := preload("res://src/shared/inventory.gd")
const RecipeTable := preload("res://src/shared/recipe_table.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var table = ItemTable.new()
	check(table.load_file(ItemTable.PATH) and table.load_file(ItemTable.GATHERED_PATH), "table loads")
	var stone: int = table.number_of("stone")
	var axe: int = table.number_of("stone_axe")
	check(stone == 1 and table.id_of(1) == "stone", "stone is number 1")
	check(table.stack_of(stone) == ItemTable.COUNT_MAX, "stone stacks to the count maximum (no stack caps)")

	var numbers: Dictionary = {}

	for id in table.ids():
		var n: int = table.number_of(id)
		check(not numbers.has(n), "unique number %d" % n)
		numbers[n] = true

	var inv = Inventory.new(table)
	check(inv.add(stone, 45) == 0, "45 stone fit")
	check(inv.count_of(stone) == 45, "45 stone counted")
	check(inv.numbers[0] == stone and inv.counts[0] == 45, "45 stone sit in one slot")
	check(inv.add(axe, 2) == 0 and inv.count_of(axe) == 2, "tools do not stack, take two slots")
	check(inv.remove(stone, 10) and inv.count_of(stone) == 35, "remove 10")
	check(not inv.remove(stone, 99) and inv.count_of(stone) == 35, "removing too many changes nothing")

	var full = Inventory.new(table)
	check(full.add(axe, 35) == 5, "a container's 30 slots hold 30 axes, 5 left over")

	# A pack grows (Dave 12 Nov 2026 23:06Z: "a minimum of 20 and if they add more stuff just start adding more slots"; protocol 116):
	# never full by slots (the server's carry limit is the cap), and empty slots at its end go back, GROW_STEP at a time, down to 30.
	var bag = Inventory.pack(table)
	check(bag.slot_count == 30 and bag.slot_count - bag.hotbar_slots == 20, "a new pack has the hotbar 10 and a backpack of 20")
	check(bag.add(axe, 21) == 0 and bag.slot_count == 35 and bag.usable == 35 and bag.numbers.slice(0, 10).count(0) == 10 and bag.numbers[30] == axe, "a full backpack grows a step before anything lands in the empty hotbar")
	check(bag.add(axe, 14) == 0 and bag.slot_count == 45 and bag.count_of(axe) == 35, "35 axes: nothing left over, the pack grows to 45 slots")
	check(bag.add(axe, 1) == 0 and bag.slot_count == 50 and bag.numbers[45] == axe, "one more adds a step of 5 slots, the axe in the first new one")
	var bag_bytes = Inventory.pack(table)
	check(bag_bytes.from_bytes(bag.to_bytes()) and bag_bytes.slot_count == 50 and bag_bytes.count_of(axe) == 36, "the bytes carry the 50 slots")
	var bag_json = Inventory.pack(table)
	bag_json.from_json_array(JSON.parse_string(JSON.stringify(bag.to_json_array())))
	check(bag_json.slot_count == 50 and bag_json.count_of(axe) == 36, "so does the save")
	check(not bag.trim() and bag.slot_count == 50, "trim keeps a step that holds an item")
	bag.clear_slot(45)
	check(bag.trim() and bag.slot_count == 45, "an empty last step is given back")

	for i in range(30, 45):
		bag.clear_slot(i)

	check(bag.trim() and bag.slot_count == 30, "down to 30")
	bag.clear_slot(29)
	check(not bag.trim() and bag.slot_count == 30, "never below 30 (the backpack's 20)")
	check(bag.free_bag_slot() == 29, "a free backpack slot is named")
	bag.add(axe, 1)
	check(bag.free_bag_slot() == 30, "a full backpack names the slot just past its end")
	bag.move(10, 30)
	check(bag.slot_count == 35 and bag.numbers[30] == axe and bag.numbers[10] == 0, "a move there grows the pack by a step")
	bag.move(11, 36)
	check(bag.slot_count == 35 and bag.numbers[11] == axe, "a move further past the end is ignored")
	bag.clear_slot(31)
	bag.move(11, 35)
	check(bag.slot_count == 35 and bag.numbers[11] == axe, "a move past the end while a backpack slot is free is ignored")
	check(bag.make_room() == 10 and bag.slot_count == 35, "make_room names a free slot without growing")
	bag.add(axe, 5)   # slots 10 and 31 to 34
	check(bag.make_room() == 35 and bag.slot_count == 40, "and grows a full backpack by a step")
	var short = Inventory.pack(table)
	short.from_json_array(Inventory.new(table).to_json_array())
	bag.from_json_array(Inventory.new(table).to_json_array())
	check(bag.slot_count == 30 and bag.count_of(axe) == 0 and short.slot_count == 30, "loading 30 empty rows empties and shrinks a grown pack")
	check(bag.add(axe, 300) == 300 - (Inventory.MAX_SLOTS) and bag.slot_count == Inventory.MAX_SLOTS, "it stops at MAX_SLOTS (the one-byte slot index)")
	var copied = bag.copy()
	check(copied.grows and copied.slot_count == Inventory.MAX_SLOTS and copied.count_of(axe) == Inventory.MAX_SLOTS, "a copy keeps the slots, the contents and that it grows")

	inv.move(0, 5)
	check(inv.numbers[5] == stone and inv.numbers[0] == 0, "move to empty slot")
	inv.move(5, 1)
	check(inv.counts[1] == 20 and inv.counts[5] == 0 or inv.count_of(stone) == 35, "merge keeps total")
	check(inv.count_of(stone) == 35, "move keeps total")

	var copy = Inventory.new(table)
	check(copy.from_bytes(inv.to_bytes()), "bytes decode")
	check(copy.count_of(stone) == 35 and copy.count_of(axe) == 2, "bytes round trip")
	var copy2 = Inventory.new(table)
	copy2.from_json_array(JSON.parse_string(JSON.stringify(inv.to_json_array())))
	check(copy2.count_of(stone) == 35 and copy2.count_of(axe) == 2, "json round trip")

	var recipes = RecipeTable.load_default(table)
	var crafter = Inventory.new(table)
	check(not recipes.craft(1, crafter), "cannot craft without fibre")
	crafter.add(table.number_of("plant_fibre"), 7)
	check(recipes.craft(1, crafter) and recipes.craft(1, crafter), "twist twine twice")
	check(crafter.count_of(table.number_of("twine")) == 2 and crafter.count_of(table.number_of("plant_fibre")) == 1, "fibre used, twine made")
	check(not recipes.craft(3, crafter), "stone spear needs stones and a stick")
	var herbs = Inventory.new(table)
	herbs.add(table.number_of("plantain_leaves"), 4)
	herbs.add(table.number_of("plant_fibre"), 2)
	herbs.add(table.number_of("mortar_pestle"), 1)   # grinding herbs keeps the mortar and pestle (item system, Part C)
	check(recipes.craft(8, herbs) and herbs.count_of(table.number_of("poultice")) == 1 and herbs.count_of(table.number_of("plantain_leaves")) == 1, "plantain poultice takes 3 leaves")
	check(recipes.craft(10, herbs) and herbs.count_of(table.number_of("bandage")) == 1 and herbs.count_of(table.number_of("plant_fibre")) == 0, "leaf bandage takes 1 leaf and 2 fibre")
	check(recipes.recipe(8)["identify"] == [table.number_of("plantain_leaves")], "poultice asks for the herb to be identified")
	crafter.add(table.number_of("stick"), 3)
	crafter.add(table.number_of("stone"), 3)
	check(recipes.craft(5, crafter) and crafter.count_of(table.number_of("wooden_spear")) == 1, "wooden spear made")
	check(crafter.count_of(table.number_of("stone")) == 3 and crafter.count_of(table.number_of("stick")) == 2, "the sharpening stone is kept, the stick is used")
	crafter.add(table.number_of("plant_fibre"), 30)
	var twined: int = 0

	for n in range(10):   # twine is twisted by hand from fibre, no bench or tool (recipe 1, known from the start)
		twined += 1 if recipes.craft(1, crafter) else 0

	check(twined == 10 and recipes.recipe(1).get("station", "") == "" and bool(recipes.recipe(1).get("known", false)), "ten twine twisted by hand from fibre")
	var twine_before: int = crafter.count_of(table.number_of("twine"))
	var stone_before: int = crafter.count_of(table.number_of("stone"))
	var stick_before: int = crafter.count_of(table.number_of("stick"))
	check(recipes.craft(3, crafter) and crafter.count_of(table.number_of("spear")) == 1, "stone spear made")
	check(crafter.count_of(table.number_of("twine")) == twine_before - 2 and crafter.count_of(table.number_of("wooden_spear")) == 0, "stone spear used the wooden spear and 2 twine")
	check(crafter.count_of(table.number_of("stone")) == stone_before - 1 and crafter.count_of(table.number_of("stick")) == stick_before, "the stone spear (recipe 3: wooden spear + 2 twine + its stone head, master s3.6) takes one stone and no stick")
	crafter.add(table.number_of("stone"), 1)
	check(recipes.craft(2, crafter) and crafter.count_of(table.number_of("stone_axe")) == 1, "stone axe made")
	var packed = Inventory.new(table)
	check(packed.add(table.number_of("wooden_spear"), 30) == 0, "fill every slot")
	packed.numbers[0] = 0
	packed.counts[0] = 0
	packed.add(table.number_of("plant_fibre"), 3)
	packed.numbers[1] = 0
	packed.counts[1] = 0
	check(recipes.can_make(1, packed) and recipes.craft(1, packed), "fibre slot is freed for the result")

	# Liquid ingredients (GOALS-REPAIR GA-04): water is filled by the water in containers, 500 mL a unit, pooled across them; stacks first; salt never.
	var water: int = table.number_of("water")
	var wet = Inventory.new(table)
	var skin: int = table.number_of("waterskin")
	var bowl: int = table.number_of("wooden_bowl")
	wet.add(skin, 1, 300)
	wet.add(bowl, 1, 300)
	check(wet.liquid_ml() == 600 and wet.count_fill(water) == 1 and wet.count_fill(water, true) == 0 and wet.count_of(water) == 0, "300 + 300 mL pool into one water ingredient; building costs and count_of ignore it")
	check(wet.add(table.number_of("sea_water"), 3) == 0 and wet.count_fill(water) == 1, "sea water adds nothing")
	var rows: Array = []
	check(not wet.remove_fill(water, 2, rows) and wet.liquid_ml() == 600 and rows.is_empty(), "too few: nothing changes")
	check(wet.remove_fill(water, 1, rows) and wet.liquid_ml() == 100 and wet.count_of(skin) == 1 and wet.count_of(bowl) == 1 and rows.size() == 1 and int(rows[0][1]["liquid_ml"]) == 500, "one unit takes 500 mL, the containers stay, and the row records the mL")
	wet.add(water, 1)
	rows.clear()
	check(wet.count_fill(water) == 1 and wet.remove_fill(water, 1, rows) and wet.liquid_ml() == 100 and wet.count_of(water) == 0, "a stack of water is used before the containers")
	check(wet.pour_liquid(5000) == 3300 and wet.liquid_ml() == 1800, "pouring back fills containers with room (1500 + 300 mL) and returns the rest")
	check(wet.drain_liquid(100, 1) and wet.wear[1] == 200 and wet.liquid_ml() == 1700 and not wet.drain_liquid(5000), "a named container is drained first, and more than it all holds is refused")

	print("inventory tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
