extends RefCounted

# What E does on a tilled bed or garden plot (GOALS-REPAIR WP-R1B; FARMING_SPEC.md steps 3 to 5, 6 for the prompts). The client only asks: the server (server_items.gd sow,
# water_bed, harvest) checks reach, seed, season, bed state and water, and its refusal text reaches the player as a notice. This is the client's wording of the one request it will
# send, from the bed's world-row extras (crop id, stage 0 to 3; server_items.crop_row_extra) and data/items/crops.json. It is pure so test_farm_prompt.gd can hold it.

const STAGE_NAMES := ["seedling", "young", "growing", "ripe"]
const RIPE := 3


# The crop a seed item sows (crops.json "seed"), "" when the item is not a crop seed.
static func crop_of_seed(crops: Dictionary, seed_id: String) -> String:
	if seed_id == "":
		return ""

	for id in crops:
		if str(crops[id].get("seed", "")) == seed_id:
			return str(id)

	return ""


# The decision for one bed: {"act": "sow" | "harvest" | "water" | "none", "prompt": the E line, "b": the pack slot the request carries (the seed for a sow, the container for a water, else 0)}.
# inventory_view._bed_interaction sends ACT_SOW / ACT_HARVEST / ACT_WATER_BED with the bed id as `a` and this `b`; "none" sends nothing and shows the prompt as a notice.
# crop_id/stage: the bed's crop ("" for an empty bed); seed_slot/seed_name: the seed to sow (-1 and "" when none is held or carried);
# water_slot: the held container that holds water, the one E uses to drink and fill (-1 when none).
static func bed_action(crops: Dictionary, crop_id: String, stage: int, seed_slot: int, seed_name: String, water_slot: int) -> Dictionary:
	if crop_id == "":
		# PROVISIONAL (GOALS-REPAIR A-6): the seed is the one in hand, else the first in the pack (chosen by inventory_view._seed_slot).
		if seed_slot >= 0:
			return {"act": "sow", "prompt": "Press E to sow %s" % seed_name, "b": seed_slot}

		return {"act": "none", "prompt": "A tilled bed: carry seeds and press E to sow it", "b": 0}

	var def: Dictionary = crops.get(crop_id, {})
	var name: String = str(def.get("name", crop_id)).to_lower()

	if stage >= RIPE:
		var tool_class: String = str(def.get("tool_to_harvest", "hand"))
		return {"act": "harvest", "prompt": "Press E to harvest the %s%s" % [name, "" if tool_class == "hand" else " (a %s gives the full yield)" % tool_class], "b": 0}

	# PROVISIONAL (GOALS-REPAIR A-7): to water, hold a filled freshwater container and tap E on the growing crop; the server draws from that slot (REPAIR_DECISIONS.md section 4).
	if water_slot >= 0:
		return {"act": "water", "prompt": "Press E to water the %s (%s)" % [name, STAGE_NAMES[clampi(stage, 0, RIPE)]], "b": water_slot}

	return {"act": "none", "prompt": "%s, %s: hold a filled bucket or waterskin and press E to water it" % [name.capitalize(), STAGE_NAMES[clampi(stage, 0, RIPE)]], "b": 0}


# The hoe's Garden mode (Dave 14 Nov 2026: "gardening should also be another option on the right click of the Hoe ... make garden plots or plant seeds, plants, shrubs";
# master s2.1 "Create Garden Plot, Plant"). What the pack carries that the hoe can plant, one row per kind, in pack order: {"id", "kind": "seed" | "bush" | "tree"}.
# `ids`: the item id in each pack slot ("" for an empty slot). A bush is a dug-up shrub (`<species>_bush`, drops.json shrub_work dig_suffix); a tree seed is any item
# in `tree_seeds` (item id -> species, from drops.json trunk.felled_seeds: each tree's own "<Tree> seed" item). A crop seed is a crop seed first.
static func plantables(crops: Dictionary, ids: Array, bush_suffix: String = "_bush", tree_seeds: Dictionary = {}) -> Array:
	var rows: Array = []
	var seen: Dictionary = {}

	for id in ids:
		var item: String = str(id)

		if item == "" or seen.has(item):
			continue

		var kind: String = "seed" if crop_of_seed(crops, item) != "" else ("bush" if item.ends_with(bush_suffix) else ("tree" if tree_seeds.has(item) else ""))

		if kind != "":
			seen[item] = true
			rows.append({"id": item, "kind": kind})

	return rows


# One Garden-mode click: {"act": "sow" | "till" | "plant_bush" | "none", "say": the notice line ("" for none)}. `kind`: the picked plantable's kind ("" when nothing is
# picked or none is left in the pack); `bed`: a tilled bed or garden plot is under the crosshair; `bed_crop`: what grows on it ("" for empty). The server rules on the
# rest (reach, season, ground, spacing) and says why it refuses.
# PROVISIONAL (gardening, 14 Nov 2026): a seed clicked on open ground tills a bed there and then sows it.
static func garden_action(kind: String, bed: bool, bed_crop: String) -> Dictionary:
	if kind == "till":   # Till a garden: the preview shows the beds already there
		return {"act": "none", "say": "Already tilled"} if bed else {"act": "till", "say": ""}

	if kind == "":
		return {"act": "none", "say": "Nothing to plant: carry seeds, a dug-up bush or a tree's seed, then right click and pick it"}

	if kind == "bush" or kind == "tree":   # both go in open ground through the server's ACT_PLANT_BUSH; a tree seed starts as a sapling
		return {"act": "none", "say": "%s goes in open ground, not in a bed" % ("A bush" if kind == "bush" else "A tree")} if bed else {"act": "plant_bush", "say": ""}

	if not bed:
		return {"act": "till", "say": ""}   # the hoe tills the cell and sows it as soon as the bed is there (held_item._garden_step)

	if bed_crop != "":
		return {"act": "none", "say": "Something is already growing there"}

	return {"act": "sow", "say": ""}


# The hoe grid (Dave 14 Nov 2026): "green markers that show you the size of the garden on the ground and you can size it using the arrow keys plus the alt
# button ... turning the mouse wheel will cause the marked out area to rotate a little bit so you can line up your gardens"; planting uses "the same
# mechanism", with "the spacing ... adjusted according to the plant that you picked". One grid, width by length, turned by the wheel. PROVISIONAL limits.
const GRID_MAX_SIDE := 10      # PROVISIONAL: at most 10 by 10 points (a 10 m square garden of 1 m beds)
const GRID_TURN_DEG := 5       # PROVISIONAL: one wheel notch turns the grid this far
const SEED_SPACING_M := 1.0    # seeds go one to a tilled metre bed (the server's beds are 1 m)
const BUSH_SPACING_M := 2.0    # PROVISIONAL: bushes two metres apart (the server's own gap is PLANT_BUSH_GAP_M, 1 m)
const TREE_SPACING_M := 3.0    # PROVISIONAL: tree seeds three metres apart (the server's own gap is PLANT_TREE_GAP_M, 2 m)


# Dave 14 Nov 2026: an area with "a massive height variation" cannot be tilled ("it can turn the grid green or red"); "I think up or down 1 m should be the
# limit". The garden's surveyed points (its bed centres) must each be within GARDEN_LEVEL_LIMIT_M of their mean, the height it is levelled to.
const GARDEN_LEVEL_LIMIT_M := 1.0


# Whether a garden's surveyed heights are close enough to their mean to till (an empty list or an unloaded point, NAN, is not).
static func level_ok(heights: Array) -> bool:
	if heights.is_empty():
		return false

	var mean: float = 0.0

	for h in heights:
		if is_nan(float(h)):
			return false

		mean += float(h)

	mean /= float(heights.size())
	return heights.all(func(h): return absf(float(h) - mean) <= GARDEN_LEVEL_LIMIT_M)


# The grid spacing for a picked plant: its crops.json row's "spacing_m" when it has one, else by kind (seed, bush, tree; tilling is 1 m beds).
static func spacing_of(kind: String, crop_row: Dictionary = {}) -> float:
	if crop_row.has("spacing_m"):
		return float(crop_row["spacing_m"])

	return BUSH_SPACING_M if kind == "bush" else (TREE_SPACING_M if kind == "tree" else SEED_SPACING_M)


# The grid's points, `w` across (x) by `d` along (z) at `step` apart round `centre`, turned `yaw_deg` the way a structure's yaw turns it (Godot's
# rotation about y). The server works the same points from the same centre (server_items.till_garden).
static func grid_points(w: int, d: int, step: float, centre: Vector2, yaw_deg: int) -> Array:
	var points: Array = []
	var turn: float = -deg_to_rad(float(yaw_deg))

	for a in range(d):
		for c in range(w):
			points.append(centre + Vector2((float(c) - float(w - 1) * 0.5) * step, (float(a) - float(d - 1) * 0.5) * step).rotated(turn))

	return points


# Where the grid's centre goes for an aim: round the aim, moved so the point nearest the aim lands on `anchor` (a bed's centre, or a metre cell's centre
# for an unturned 1 m grid) when one is given (a Vector2), so a grid lines up with the beds already there.
static func grid_centre(w: int, d: int, step: float, aim: Vector2, yaw_deg: int, anchor: Variant = null) -> Vector2:
	if typeof(anchor) != TYPE_VECTOR2:
		return aim

	var nearest: Vector2 = aim
	var best: float = INF

	for p in grid_points(w, d, step, aim, yaw_deg):
		if p.distance_squared_to(aim) < best:
			best = p.distance_squared_to(aim)
			nearest = p

	return aim + (anchor as Vector2 - nearest)


# The grid's points nearest `aim` first (the pack's count runs out on the far ones).
static func nearest_first(points: Array, aim: Vector2) -> Array:
	var out: Array = points.duplicate()
	out.sort_custom(func(p, q): return p.distance_squared_to(aim) < q.distance_squared_to(aim))
	return out


# Whether a flat point lies on a bed or plot: its square footprint (half side `half`) turned `yaw_deg` round `centre`.
static func on_square(point: Vector2, centre: Vector2, half: float, yaw_deg: float) -> bool:
	var local: Vector2 = (point - centre).rotated(deg_to_rad(yaw_deg))
	return absf(local.x) <= half and absf(local.y) <= half


# One Garden click's plan from its grid's spots (nearest the aim first), as [[position, bed id (0 for none), that bed's crop]]: a bed or garden plot takes one
# point (its first: a 2 m plot holds several 1 m points but one crop), a point needs ground (y not NAN), and at most `have` points plant. A point farther than
# `reach` m flat from `feet` still plants: it waits in the queue until the player walks within reach ("far"). -> [{"act", "say", "pos", "bed", "ok", "far"}]; a
# point that will not plant has act "none" and says why.
static func garden_plan(kind: String, spots: Array, feet: Vector3, reach: float, have: int) -> Array:
	var used: Dictionary = {}
	var out: Array = []

	for spot in spots:
		var pos: Vector3 = spot[0]
		var bed: int = int(spot[1])

		if bed != 0:
			if used.has(bed):
				continue

			used[bed] = true

		var cell: Dictionary = garden_action(kind, bed != 0, str(spot[2]))
		cell["pos"] = pos
		cell["bed"] = bed
		cell["ok"] = str(cell["act"]) != "none" and not is_nan(pos.y)
		cell["far"] = Vector2(pos.x - feet.x, pos.z - feet.z).length() > reach

		if not bool(cell["ok"]) and str(cell["act"]) != "none":
			cell["say"] = "No ground to plant there"
			cell["act"] = "none"

		if bool(cell["ok"]):
			if have <= 0:
				break

			have -= 1

		out.append(cell)

	return out


const GARDEN_STEP_MSEC := 150         # between sows and plantings
const GARDEN_TILL_MSEC := 600         # between tills (the server paces hoe strokes at 500 ms)
const GARDEN_BED_WAIT_MSEC := 3000    # how long a sow waits for the bed its till asked for


# The next request of a Garden queue ([{"act": "till" | "sow" | "sow_at" | "plant_bush", "pos", "bed", "until"}]) at `now` msec: the first one in order that
# `near.call(position)` allows (within the player's reach; an invalid `near` allows all) and that can go. A "sow_at" waits for the bed its till asked for (from the
# moment that till goes, up to GARDEN_BED_WAIT_MSEC, then it is dropped); the ones behind it go first meanwhile. `bed_at.call(position)` -> [bed id or 0, its crop].
# -> {"send": the request to send now or {} (a "sow_at" goes out as a "sow" of its bed, or not at all if the bed has a crop), "next": msec the queue may move again}.
static func garden_step(queue: Array, now: int, bed_at: Callable, near: Callable = Callable()) -> Dictionary:
	for i in range(queue.size()):
		var item: Dictionary = queue[i]

		if near.is_valid() and not bool(near.call(item["pos"])):
			continue   # out of reach: it waits for the player to walk over

		match str(item["act"]):
			"till":
				queue.remove_at(i)

				for wait in queue:
					if str(wait["act"]) == "sow_at" and int(wait["until"]) == 0 and (wait["pos"] as Vector3).is_equal_approx(item["pos"]):
						wait["until"] = now + GARDEN_BED_WAIT_MSEC   # its own sow starts waiting for the bed
						break

				return {"send": item, "next": now + GARDEN_TILL_MSEC}
			"sow_at":
				var found: Array = bed_at.call(item["pos"])

				if int(found[0]) == 0 and (int(item["until"]) == 0 or now < int(item["until"])):
					continue   # its bed is not there yet

				queue.remove_at(i)

				if int(found[0]) == 0 or str(found[1]) != "":   # never came, or already sown
					return {"send": {}, "next": now + GARDEN_STEP_MSEC}

				return {"send": {"act": "sow", "bed": int(found[0]), "pos": item["pos"]}, "next": now + GARDEN_STEP_MSEC}

		queue.remove_at(i)
		return {"send": item, "next": now + GARDEN_STEP_MSEC}

	return {"send": {}, "next": now + GARDEN_STEP_MSEC}
