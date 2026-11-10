extends SceneTree

# At a station the pack sorts what it can use to the top with a golden line (Dave 10 Nov 2026: "it should work with every station of any type. only
# the stuff you can use in it go to the top with the yellow outline"). The set comes from the data: a fire's fuel and the food it cooks, a structure's
# own fuel, and every ingredient of a recipe made at a station here (src/client/ui/inventory/station_use.gd).
#   godot --headless --path . --script res://src/worldgen/tools/test_station_use.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const StationUse := preload("res://src/client/ui/inventory/station_use.gd")
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var table = ItemTableScript.load_default()
	var recipes = load("res://src/shared/recipe_table.gd").load_default(table)
	var cooking: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/cooking.json"))
	var n: Callable = func(id: String) -> int: return table.number_of(id)

	check(StationUse.usable([], false, [], recipes, table, cooking).is_empty(), "away from every station: nothing is lifted")

	var fire: Dictionary = StationUse.usable(["campfire"], true, [], recipes, table, cooking)
	check(fire.get(n.call("stick"), -1) == StationUse.FUEL and fire.get(n.call("log"), -1) == StationUse.FUEL, "a fire: sticks and logs are its fuel")
	check(fire.get(n.call("firewood"), -1) == StationUse.FUEL, "and firewood")
	check(fire.get(n.call("raw_meat"), -1) == StationUse.INPUT, "raw meat is food it cooks")
	check(not fire.has(n.call("stone")) and not fire.has(n.call("hide")) and not fire.has(n.call("iron_ore")), "stone, hide and iron ore are not lifted at a fire")

	var bench: Dictionary = StationUse.usable(["workbench"], false, [], recipes, table, cooking)
	check(bench.get(n.call("stone"), -1) == StationUse.INPUT and bench.get(n.call("hide"), -1) == StationUse.INPUT, "a workbench: the ingredients of its recipes")
	check(bench.get(n.call("stick"), -1) == StationUse.INPUT, "a stick is an ingredient there, not fuel")
	check(not bench.has(n.call("raw_meat")), "raw meat is not lifted at a workbench")
	check(not bench.values().has(StationUse.FUEL), "a workbench burns nothing")

	var hearth: Dictionary = StationUse.usable(["clay_hearth", "campfire"], false, [], recipes, table, cooking)
	check(hearth.get(n.call("beet"), -1) == StationUse.INPUT and hearth.get(n.call("raw_meat"), -1) == StationUse.INPUT, "a clay hearth: its own recipes and the campfire's it stands in for")

	var forge: Dictionary = StationUse.usable(["forge"], false, [], recipes, table, cooking)
	check(forge.get(n.call("copper_ore"), -1) == StationUse.INPUT and not forge.has(n.call("iron_ore")), "a stone forge takes copper ore, not iron ore")
	var brick: Dictionary = StationUse.usable(["brick_forge", "forge"], false, [], recipes, table, cooking)
	check(brick.get(n.call("iron_ore"), -1) == StationUse.INPUT and brick.get(n.call("copper_ore"), -1) == StationUse.INPUT, "a brick forge takes iron ore, and copper for the bronze work it also does")

	var torch: Dictionary = StationUse.usable([], false, ["stick"], recipes, table, cooking)
	check(torch.size() == 1 and torch.get(n.call("stick"), -1) == StationUse.FUEL, "a wall torch: only its own fuel")
	check(StationUse.usable(["campfire"], true, [], recipes, table, cooking) == fire, "asked again: the same set")

	check(StationUse.cookable("raw_meat", cooking) and not StationUse.cookable(str(cooking.get("gives", "")), cooking) and not StationUse.cookable("", cooking), "cookable follows the server's rule")

	# Every lifted item is a real item, and every recipe made at a station has all its ingredients lifted there.
	var all_real: bool = true

	for number in fire.keys() + bench.keys() + forge.keys() + brick.keys():
		all_real = all_real and table.id_of(int(number)) != ""

	check(all_real, "every lifted number is a real item")

	var cfg: Dictionary = ItemSlot.glow_cfg()
	check(str(cfg.get("colour", "")).begins_with("#") and float(cfg.get("line_px", 0.0)) > 0.0 and float(cfg.get("glow_px", 0.0)) > 0.0, "data/ui/station_highlight.json: colour, line and glow")
	var slot = ItemSlot.new()
	slot.set_station_glow(true)
	check(slot.station_glow, "a slot takes the golden line")
	slot.set_station_glow(false)
	check(not slot.station_glow, "and drops it")
	slot.free()

	print("test_station_use: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
