extends SceneTree

# Craft menu search with a long list and awkward typing (Moderator 1 Nov 2026): a list fifty times the real one filters fast enough to type into, a pasted tab or
# new line separates words like a space, a very long or odd entry shows nothing and breaks nothing.
#   godot --headless --path . --script res://src/worldgen/tools/test_craft_search_long.gd

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

	var big: Array = []

	for n in range(50):
		big.append_array(all)

	var t0: int = Time.get_ticks_usec()
	var hits: int = big.filter(func(r): return RecipeFilter.shown(r, "", "hide bark", table)).size()
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	print("craft search: %d recipes filtered in %.1f ms (%d shown)" % [big.size(), ms, hits])
	check(ms < 1000.0, "a list fifty times the real one filters in under a second (%.0f ms)" % ms)
	check(hits == 50 * all.filter(func(r): return RecipeFilter.shown(r, "", "hide bark", table)).size(), "the long list gives the same share")

	# Whitespace other than a space (pasted text): same as spaces.
	var axe: Dictionary = recipes.recipe(2)
	var make_word: String = table.name_of(int(axe["number"])).to_lower()
	var second_word: String = "axe"   # the two words come from the name, so both match
	check(RecipeFilter.shown(axe, "", make_word + "\t" + second_word, table), "a tab between words is a separator")
	check(RecipeFilter.shown(axe, "", make_word + "\n" + second_word, table), "a new line between words is a separator")
	check(RecipeFilter.shown(axe, "", "\t " + make_word + " \n", table), "tabs and new lines around the entry are trimmed")

	# Odd entries: long, many words, symbols, non-Latin. None shown, none crash.
	check(not RecipeFilter.shown(axe, "", "x".repeat(5000), table), "a 5000-letter entry shows nothing")
	check(not RecipeFilter.shown(axe, "", " ".join(PackedStringArray(["zzq"]).duplicate()).repeat(1) + " " + "zzq ".repeat(300), table), "three hundred words that match nothing show nothing")
	check(not RecipeFilter.shown(axe, "", "[(*\\", table) and not RecipeFilter.shown(axe, "", "日本語", table), "symbols and non-Latin text just match nothing")
	check(RecipeFilter.shown({}, "", "", table), "a recipe row with no fields still shows for an empty box")
	check(not RecipeFilter.shown({}, "", "axe", table), "and not for a word")

	print("test_craft_search_long: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
