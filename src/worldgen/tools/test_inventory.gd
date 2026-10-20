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
	check(table.load_file(ItemTable.PATH), "table loads")
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
	check(recipes.craft(1, crafter) and recipes.craft(1, crafter), "twist cordage twice")
	check(crafter.count_of(table.number_of("cordage")) == 2 and crafter.count_of(table.number_of("plant_fibre")) == 1, "fibre used, cordage made")
	check(not recipes.craft(3, crafter), "spear needs sticks")
	crafter.add(table.number_of("stick"), 2)
	check(recipes.craft(3, crafter) and crafter.count_of(table.number_of("spear")) == 1, "spear made")
	check(crafter.count_of(table.number_of("stick")) == 0 and crafter.count_of(table.number_of("cordage")) == 1, "spear used 2 sticks and 1 cordage")
	crafter.add(table.number_of("stone"), 2)
	crafter.add(table.number_of("stick"), 1)
	check(recipes.craft(2, crafter) and crafter.count_of(table.number_of("stone_axe")) == 1, "stone axe made")
	var packed = Inventory.new(table)
	check(packed.add(table.number_of("spear"), 30) == 0, "fill every slot")
	packed.numbers[0] = 0
	packed.counts[0] = 0
	packed.add(table.number_of("plant_fibre"), 3)
	packed.numbers[1] = 0
	packed.counts[1] = 0
	check(recipes.can_make(1, packed) and recipes.craft(1, packed), "fibre slot is freed for the result")

	print("inventory tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
