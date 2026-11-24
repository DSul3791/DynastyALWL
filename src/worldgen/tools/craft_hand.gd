extends RefCounted

# For tests and probes that queue crafts by hand (protocol 126, Dave 17 Nov 2026: a tool a recipe keeps must be in your hand): the hand slot a
# player would hold for this craft, as ACT_CRAFT_QUEUE's `at` (at.x = pack slot + 1, 0 for empty hands). It picks the first hotbar slot that holds
# a hand tool of the recipe, or of a recipe that makes one of its needs (a Wooden block sawn on the way). Vector3.ZERO when none is there, so a
# test that leaves the tool out still sees the refusal.
#   items.action(1, Net.ACT_CRAFT_QUEUE, number, 0, 1, CraftHand.at(items, 1, number))

const CraftStock := preload("res://src/shared/craft_stock.gd")


static func at(items, peer: int, recipe_number: int) -> Vector3:
	var inv = items.inventory_of(peer)
	var recipe: Dictionary = items.recipes.recipe(recipe_number)

	if inv == null or recipe.is_empty():
		return Vector3.ZERO

	var wanted: Array = [recipe]

	for need in recipe.get("needs", []):
		for maker in items.recipes.makers_of(int(need[0])):
			wanted.append(items.recipes.recipe(int(maker)))

	for r in wanted:
		if CraftStock.hand_tools(r, items.table).is_empty():
			continue

		for slot in range(inv.slot_count):
			if inv.on_hotbar(slot) and CraftStock.slot_holds_tool(r, items.table, inv, slot):
				return Vector3(float(slot + 1), 0.0, 0.0)

	if not CraftStock.has_tool(recipe, items.table, inv):
		print("CraftHand: no %s in the pack for %s: the craft will be refused" % [CraftStock.hand_words(recipe, items.table), str(recipe.get("id", ""))])   # a test that meant to craft shows why it did not

	return Vector3.ZERO
