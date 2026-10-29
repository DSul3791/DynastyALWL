extends SceneTree

# Craft menu categories and search (Dave 25 Oct): every recipe has one of the category tabs, search filters by name as you type,
# a tab shows only its recipes, All shows every recipe, and no recipe number or name changed.
#   godot --headless --path . --script res://src/worldgen/tools/test_craft_menu.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const RecipeFilter := preload("res://src/client/recipe_filter.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var table = ItemTableScript.load_default()
	var recipes = load("res://src/shared/recipe_table.gd").load_default(table)
	var all: Array = []

	for number in recipes.numbers():
		all.append(recipes.recipe(number))

	check(all.size() >= 100, "the recipe list is whole (%d recipes)" % all.size())
	var unsorted: int = all.filter(func(r): return not RecipeFilter.CATEGORIES.has(str(r["category"]))).size()
	check(unsorted == 0, "every recipe has a category tab (%d without)" % unsorted)
	check(all.filter(func(r): return RecipeFilter.shown(r, "", "")).size() == all.size(), "All with no text shows every recipe")

	var tw: Array = all.filter(func(r): return RecipeFilter.shown(r, "", "tw"))
	check(tw.any(func(r): return str(r["name"]) == "Twine"), "typing 'tw' shows Twine")
	check(tw.all(func(r): return str(r["name"]).to_lower().contains("tw")), "typing 'tw' shows only names with tw")
	check(RecipeFilter.shown(recipes.recipe(1), "", "  TWINE "), "search ignores case and spaces")
	check(not RecipeFilter.shown(recipes.recipe(1), "", "axe"), "typing 'axe' hides Twine")
	check(RecipeFilter.shown(recipes.recipe(2), "Tools", "axe") and not RecipeFilter.shown(recipes.recipe(2), "Weapons", "axe"), "a tab and a search work together")

	for category in RecipeFilter.CATEGORIES:
		var inside: Array = all.filter(func(r): return RecipeFilter.shown(r, category, ""))
		check(not inside.is_empty(), "the %s tab is not empty" % category)
		check(inside.all(func(r): return str(r["category"]) == category), "the %s tab shows only %s" % [category, category])

	check(str(recipes.recipe(2)["category"]) == "Tools" and str(recipes.recipe(1)["category"]) == "Materials" and str(recipes.recipe(165)["category"]) == "Fire and cooking", "axe is Tools, twine Materials, campfire pot Fire and cooking")
	check(recipes.recipe(165)["name"] == "Campfire pot" and recipes.recipe(1)["id"] == "twine" and recipes.recipe(170)["id"] == "wooden_bow" and recipes.recipe(178).is_empty(), "no recipe number or name moved")
	print("craft menu tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
