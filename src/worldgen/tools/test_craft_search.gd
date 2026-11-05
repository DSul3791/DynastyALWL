extends SceneTree

# Craft menu search (Dave 5 Nov 2026, by name only): a typed word matches the recipe's name or what it makes, never its ingredients or tools; any case, several words together,
# inside the chosen category tab; an empty box shows everything.
#   godot --headless --path . --script res://src/worldgen/tools/test_craft_search.gd

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

	check(all.filter(func(r): return RecipeFilter.shown(r, "", "", table)).size() == all.size(), "an empty box shows every recipe")
	check(all.filter(func(r): return RecipeFilter.shown(r, "", "   ", table)).size() == all.size(), "spaces alone show every recipe")

	# A name match only: "hide" lists what is called hide, not everything that needs a hide.
	var hide_n: int = table.number_of("hide")
	var with_hide: Array = all.filter(func(r): return r["needs"].any(func(n): return int(n[0]) == hide_n))
	var found: Array = all.filter(func(r): return RecipeFilter.shown(r, "", "hide", table))
	check(found.all(func(r): return (str(r["name"]) + " " + table.name_of(int(r["number"]))).to_lower().contains("hide")), "typing 'hide' lists only recipes with hide in their name (%d of %d need one)" % [with_hide.size(), found.size()])
	check(RecipeFilter.shown(recipes.recipe(1), "", "TWINE", table) and RecipeFilter.shown(recipes.recipe(1), "", "  twine ", table), "any case, spaces ignored")

	# The result item matches; an ingredient does not.
	var axe: Dictionary = recipes.recipe(2)
	check(RecipeFilter.shown(axe, "", table.name_of(int(axe["number"])).to_lower(), table), "it matches the item it makes")
	var first_need: String = table.id_of(int(axe["needs"][0][0])).replace("_", " ")
	check(not RecipeFilter.shown(axe, "", first_need, table) or (str(axe["name"]) + " " + table.name_of(int(axe["number"]))).to_lower().contains(first_need), "it does not match an ingredient by name (%s)" % first_need)

	# Several words must all match; a tab narrows first.
	check(not RecipeFilter.shown(axe, "", "axe zzzzqq", table), "a word that matches nothing hides it")
	check(RecipeFilter.shown(axe, str(axe["category"]), "axe", table) and not RecipeFilter.shown(axe, "Medicine" if str(axe["category"]) != "Medicine" else "Tools", "axe", table), "the search works inside the tab you are on")

	# Typing never loses a recipe the name search would show.
	var broke: int = 0

	for r in all:
		if RecipeFilter.shown(r, "", "tw") and not RecipeFilter.shown(r, "", "tw", table):
			broke += 1

	check(broke == 0, "the name match still works with the table")
	print("test_craft_search: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
