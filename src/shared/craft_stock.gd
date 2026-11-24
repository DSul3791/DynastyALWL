extends RefCounted
# What a craft may draw on (docs/design/INVENTORY_CRAFTING_REPORT.md step 2, Dave "yes to all", 8 Nov 2026): the pack, loose stacks lying within
# LOOSE_STOCK_M of the player, and the player's own storage containers within CRAFT_REACH_M that are not ticked "keep out". Never a stranger's
# chest, and never a fire's store (fires are fuel, not storage). Blueprint sites use the same containers and the same distance.
# The server (server_items.gd, "Crafting stock") and the client's recipe list both read these numbers; the decisions are in
# docs/design/OVERNIGHT_DECISIONS_8NOV.md.

const CRAFT_REACH_M := 12.0     # one distance for crafting and blueprint sites (the sites' old 30 m is gone)
const LOOSE_STOCK_M := 12.0     # loose stacks on the ground this close count as stock (Dave 10 Nov 2026: "or they are within 12m of you"; was 3 m)


# A tool a recipe keeps counts anywhere in the pack or on the hotbar (Dave 24 Nov 2026, replacing his 17 and 18 Nov in-hand rulings: "we should
# remove that requirement if you have a knife in you inventory or on your hotbar it should count"). A kept item that is a tool (items.json kind
# "tool"), or a group of tools (any knife, any saw), crafts while one of them, unbroken, is in the pack. The names below still say "hand" (hand_tools,
# hand_keep) for the kept tool the recipe works with.
# A kept Stone is a material that cannot be taken in hand: it still counts from the pack as before (TREE_WOOD_TOOLS_DESIGN.md W-32). No recipe keeps
# cookware (Dave 17 Nov 2026: "we use cooking stations"; docs/design/COOKING_STATIONS.md).


# The kept item numbers of `recipe` (numbers, as RecipeTable gives them) that need to be in hand; [] when none.
# A recipe that keeps two tools names the one for the hand with "hand_keep" (its index in keeps): the Wooden bowl and Serving platter keep a knife
# in the pack and need their chisel in hand (Dave 18 Nov 2026: "The required chisel must be equipped in the player's hand").
static func hand_tools(recipe: Dictionary, table) -> PackedInt32Array:
	var out: PackedInt32Array = PackedInt32Array()
	var keeps: Array = recipe.get("keeps", [])

	if int(recipe.get("hand_keep", -1)) >= 0 and int(recipe["hand_keep"]) < keeps.size():
		keeps = [keeps[int(recipe["hand_keep"])]]

	for keep in keeps:
		var number: int = int(keep[0])
		var members: PackedInt32Array = table.group_members(number)

		if members.is_empty():
			members = PackedInt32Array([number])

		for member in members:   # a group lists its own id first (the plain "knife", a material), then its tools
			var entry: Dictionary = table.entry(table.id_of(member))

			if str(entry.get("kind", "")) == "tool":
				out.append(number)
				break

	return out


# Whether the pack holds, unbroken, what the recipe works with (one of its hand tools), anywhere in it or on the hotbar. Any recipe with no hand
# tool: true.
static func has_tool(recipe: Dictionary, table, inv) -> bool:
	if hand_tools(recipe, table).is_empty():
		return true

	if inv == null:
		return false

	for slot in range(inv.slot_count):
		if slot_holds_tool(recipe, table, inv, slot):
			return true

	return false


# Whether pack slot `slot` holds one of the recipe's hand tools, not broken (a recipe that keeps two would need only one of them; none does today).
static func slot_holds_tool(recipe: Dictionary, table, inv, slot: int) -> bool:
	if inv == null or slot < 0 or slot >= inv.slot_count or inv.numbers[slot] == 0:
		return false

	var most: int = inv.max_durability(slot)

	if most > 0 and inv.wear[slot] >= most:
		return false

	for tool in hand_tools(recipe, table):
		if inv.fills_of(tool).has(inv.numbers[slot]):
			return true

	return false


# The words for the tool: "any knife", "bone sewing needle" (the first hand tool's cost name, in a sentence); "" when none.
static func hand_words(recipe: Dictionary, table) -> String:
	var tools: PackedInt32Array = hand_tools(recipe, table)
	return table.cost_sentence(tools[0]) if not tools.is_empty() else ""


# Whether a container's owner lets this player's crafting use it. Households come later: today a player's own containers only.
static func owner_ok(owner_key: String, player_key: String) -> bool:
	return owner_key != "" and owner_key == player_key


# A storage container counts for a craft when the player owns it, it is not ticked "keep out" and it stands within CRAFT_REACH_M (building with a
# better hammer passes a longer reach_m, master s2.1).
static func box_counts(owner_key: String, keep_out: bool, player_key: String, distance_m: float, reach_m: float = CRAFT_REACH_M) -> bool:
	return not keep_out and owner_ok(owner_key, player_key) and distance_m <= reach_m


# Splits `want` across sources in the order given (the pack, then the ground, then the containers nearest first): how many each one gives.
# `have` is what each source holds, in the same order. The sum is less than `want` only when the sources together hold less.
static func take_plan(want: int, have: Array) -> Array:
	var out: Array = []
	var left: int = maxi(want, 0)

	for held in have:
		var take: int = mini(left, maxi(int(held), 0))
		out.append(take)
		left -= take

	return out
