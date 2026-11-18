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


# The hoe grid (Dave 14 Nov 2026): "green markers that show you the size of the garden on the ground and you can size it using the arrow keys plus the alt
# button ... turning the mouse wheel will cause the marked out area to rotate a little bit so you can line up your gardens"; planting uses "the same
# mechanism", with "the spacing ... adjusted according to the plant that you picked". One grid, width by length, turned by the wheel. PROVISIONAL limits.
const GRID_MAX_SIDE := 10      # PROVISIONAL: at most 10 by 10 points (a 10 m square garden of 1 m beds)
const GRID_TURN_DEG := 5       # PROVISIONAL: one wheel notch turns the grid this far
const SEED_SPACING_M := 1.0    # seeds go one to a tilled metre bed (the server's beds are 1 m)
const BUSH_SPACING_M := 2.0    # PROVISIONAL: bushes two metres apart (the server's own gap is PLANT_BUSH_GAP_M, 1 m)
const TREE_SPACING_M := 3.0    # PROVISIONAL: tree seeds three metres apart (the server's own gap is PLANT_TREE_GAP_M, 2 m)


# How many square metres a side a bed or plot holds, one crop each (Dave 14 Nov 2026: Small 1, Medium 4, Large 9): its smaller footprint side in whole
# metres, at least 1 (a tilled bed, a pot and a planter hold one).
static func bed_side(def: Dictionary) -> int:
	return maxi(1, floori(minf(float(def.get("footprint_x", 1.0)), float(def.get("footprint_z", def.get("footprint_x", 1.0)))) + 0.01))


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


# Whether a flat point lies on a bed or plot: its square footprint (half side `half`) turned `yaw_deg` round `centre`.
static func on_square(point: Vector2, centre: Vector2, half: float, yaw_deg: float) -> bool:
	var local: Vector2 = (point - centre).rotated(deg_to_rad(yaw_deg))
	return absf(local.x) <= half and absf(local.y) <= half
