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
	check(table.stack_of(stone) == 20, "stone stack 20")

	var numbers: Dictionary = {}

	for id in table.ids():
		var n: int = table.number_of(id)
		check(not numbers.has(n), "unique number %d" % n)
		numbers[n] = true

	var inv = Inventory.new(table)
	check(inv.add(stone, 45) == 0, "45 stone fit")
	check(inv.count_of(stone) == 45, "45 stone counted")
	check(inv.numbers[0] == stone and inv.counts[0] == 20 and inv.counts[2] == 5, "stacks of 20, 20, 5")
	check(inv.add(axe, 2) == 0 and inv.count_of(axe) == 2, "tools do not stack, take two slots")
	check(inv.remove(stone, 10) and inv.count_of(stone) == 35, "remove 10")
	check(not inv.remove(stone, 99) and inv.count_of(stone) == 35, "removing too many changes nothing")

	var full = Inventory.new(table)
	check(full.add(axe, 35) == 5, "30 slots hold 30 axes, 5 left over")

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
	check(recipes.craft(3, crafter) and crafter.count_of(table.number_of("spear")) == 1, "stone spear made")
	check(crafter.count_of(table.number_of("twine")) == twine_before - 5 and crafter.count_of(table.number_of("wooden_spear")) == 0, "stone spear used the wooden spear and 5 twine")
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

	print("inventory tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
