extends RefCounted
# What a craft may draw on (docs/design/INVENTORY_CRAFTING_REPORT.md step 2, Dave "yes to all", 8 Nov 2026): the pack, loose stacks lying within
# LOOSE_STOCK_M of the player, and the player's own storage containers within CRAFT_REACH_M that are not ticked "keep out". Never a stranger's
# chest, and never a fire's store (fires are fuel, not storage). Blueprint sites use the same containers and the same distance.
# The server (server_items.gd, "Crafting stock") and the client's recipe list both read these numbers; the decisions are in
# docs/design/OVERNIGHT_DECISIONS_8NOV.md.

const CRAFT_REACH_M := 12.0     # one distance for crafting and blueprint sites (the sites' old 30 m is gone)
const LOOSE_STOCK_M := 3.0      # loose stacks on the ground this close count as stock


# Whether a container's owner lets this player's crafting use it. Households come later: today a player's own containers only.
static func owner_ok(owner_key: String, player_key: String) -> bool:
	return owner_key != "" and owner_key == player_key


# A storage container counts for a craft when the player owns it, it is not ticked "keep out" and it stands within CRAFT_REACH_M.
static func box_counts(owner_key: String, keep_out: bool, player_key: String, distance_m: float) -> bool:
	return not keep_out and owner_ok(owner_key, player_key) and distance_m <= CRAFT_REACH_M


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
