extends RefCounted

# Auto-make the missing part (Dave 25 Oct): pick the stone axe with no twine but with the fibre for it, and the craft queue makes the twine first.
# Shared by the server (which plans and queues) and the client (which shows "Makes 5 twine first" in the menu). Pure: it only reads.
#
# A plan is a list of steps in the order they run, each {"recipe", "count", "take", "deferred"}:
#   take      [[item, n per craft]] ingredients the pack holds now (the server removes them when it queues)
#   deferred  [[item, n per craft]] ingredients an earlier step makes (the server removes them when the step starts)
# Limits (Tyler): a recipe may not repeat along one chain, depth 4, 50 crafts in all, only consumed ingredients are made (never a kept tool,
# never something from a station you are away from), and when more than one known recipe makes a missing part nothing is guessed.

const MAX_DEPTH := 4
const MAX_CRAFTS := 50


# ctx: {"have": Callable(item number) -> count in the pack, "station_ok": Callable(recipe dict) -> bool, "free": bool (admin crafts any)}
# Returns {"ok", "steps", "msg", "ambiguous" (item number or 0), "made" ([[item, count]] the plan makes ahead of the target)}
static func plan(recipes, table, recipe_number: int, times: int, ctx: Dictionary) -> Dictionary:
	var state: Dictionary = {"reserved": {}, "steps": [], "crafts": 0, "msg": "", "ambiguous": 0, "made": {}}
	var ok: bool = _make(recipes, table, recipe_number, times, ctx, state, [], 0)
	var made: Array = []

	for item in state["made"]:
		made.append([int(item), int(state["made"][item])])

	return {"ok": ok, "steps": state["steps"] if ok else [], "msg": "" if ok else str(state["msg"]), "ambiguous": int(state["ambiguous"]), "made": made if ok else []}


static func _free(ctx: Dictionary, state: Dictionary, item: int) -> int:
	return int((ctx["have"] as Callable).call(item)) - int(state["reserved"].get(item, 0))


static func _make(recipes, table, number: int, times: int, ctx: Dictionary, state: Dictionary, path: Array, depth: int) -> bool:
	var r: Dictionary = recipes.recipe(number)

	if r.is_empty():
		state["msg"] = "That cannot be made"
		return false

	if path.has(number) or depth > MAX_DEPTH:
		state["msg"] = "%s cannot be made: the steps go round in a circle or are too long" % str(r["name"])
		return false

	if int(state["crafts"]) + times > MAX_CRAFTS:
		state["msg"] = "That is too many to queue at once"
		return false

	# Kept tools are never made for you.
	for keep in r["keeps"]:
		if _free(ctx, state, keep[0]) < keep[1]:
			state["msg"] = "You need a %s to make that" % table.name_of(keep[0]).to_lower()
			return false

	var take: Array = []
	var deferred: Array = []

	for need in r["needs"]:
		var total: int = int(need[1]) * times
		var free_now: int = _free(ctx, state, need[0])

		if free_now >= total:
			state["reserved"][need[0]] = int(state["reserved"].get(need[0], 0)) + total
			take.append([need[0], int(need[1])])
			continue

		# Short of this part: make the rest from what the pack holds. Held parts stay reserved for this craft.
		var short: int = total - maxi(free_now, 0)
		var makers: Array = _makers(recipes, need[0], ctx)

		if makers.is_empty():
			state["msg"] = "You do not have what that needs"
			return false

		state["reserved"][need[0]] = int(state["reserved"].get(need[0], 0)) + maxi(free_now, 0)
		var per_craft: int = 1
		var crafts: int = 0
		var winners: Array = []   # [maker number, state after planning it]
		var last_msg: String = "You do not have what that needs"

		for maker_number in makers:
			var maker: Dictionary = recipes.recipe(int(maker_number))
			var trial: Dictionary = state.duplicate(true)
			per_craft = maxi(int(maker["gives"][1]), 1)
			crafts = int(ceil(float(short) / float(per_craft)))

			if not ctx["free"] and not (ctx["station_ok"] as Callable).call(maker):
				last_msg = "%s needs a %s nearby" % [str(maker["name"]), str(maker.get("station", "bench")).replace("_", " ")]
				continue

			if _make(recipes, table, int(maker["number"]), crafts, ctx, trial, path + [number], depth + 1):
				winners.append([int(maker_number), trial, crafts, per_craft])
			else:
				last_msg = str(trial["msg"])

		# Only the ways the pack can really afford count. One way: use it. Several: the player chooses, nothing is guessed.
		if winners.is_empty():
			state["msg"] = last_msg
			return false

		if winners.size() > 1:
			state["ambiguous"] = need[0]
			state["msg"] = "Choose how to make %s" % table.name_of(need[0]).to_lower()
			return false

		for key in ["reserved", "steps", "crafts", "made"]:
			state[key] = winners[0][1][key]

		crafts = int(winners[0][2])
		per_craft = int(winners[0][3])

		state["made"][need[0]] = int(state["made"].get(need[0], 0)) + crafts * per_craft
		state["reserved"][need[0]] = int(state["reserved"].get(need[0], 0)) + short   # the made parts are spoken for; any surplus stays in the pack
		deferred.append([need[0], int(need[1])])

	state["crafts"] = int(state["crafts"]) + times
	state["steps"].append({"recipe": number, "count": times, "take": take, "deferred": deferred})
	return true


# Known recipes that make an item. More than one means the player has to say which.
static func _makers(recipes, item: int, ctx: Dictionary) -> Array:
	var out: Array = []

	for number in recipes.numbers():
		var r: Dictionary = recipes.recipe(number)

		if int(r["gives"][0]) == item and (bool(r["known"]) or bool(ctx["free"]) or (ctx.has("known") and bool((ctx["known"] as Callable).call(r)))):
			out.append(number)

	return out
