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
# master s2.1 "Create Garden Plot, Plant"). What the pack carries that the hoe can plant, one row per kind, in pack order: {"id", "kind": "seed" | "bush"}.
# `ids`: the item id in each pack slot ("" for an empty slot). A bush is a dug-up shrub (`<species>_bush`, drops.json shrub_work dig_suffix); trees have no item yet.
static func plantables(crops: Dictionary, ids: Array, bush_suffix: String = "_bush") -> Array:
	var rows: Array = []
	var seen: Dictionary = {}

	for id in ids:
		var item: String = str(id)

		if item == "" or seen.has(item):
			continue

		var kind: String = "seed" if crop_of_seed(crops, item) != "" else ("bush" if item.ends_with(bush_suffix) else "")

		if kind != "":
			seen[item] = true
			rows.append({"id": item, "kind": kind})

	return rows


# One Garden-mode click: {"act": "sow" | "till" | "plant_bush" | "none", "say": the notice line ("" for none)}. `kind`: the picked plantable's kind ("" when nothing is
# picked or none is left in the pack); `bed`: a tilled bed or garden plot is under the crosshair; `bed_crop`: what grows on it ("" for empty). The server rules on the
# rest (reach, season, ground, spacing) and says why it refuses.
# PROVISIONAL (gardening, 14 Nov 2026): a seed clicked on open ground tills a bed there and then sows it.
static func garden_action(kind: String, name: String, bed: bool, bed_crop: String) -> Dictionary:
	if kind == "":
		return {"act": "none", "say": "Nothing to plant: carry seeds or a dug-up bush, then right click and pick it"}

	if kind == "bush":
		return {"act": "none", "say": "A bush goes in open ground, not in a bed"} if bed else {"act": "plant_bush", "say": ""}

	if not bed:
		return {"act": "till", "say": ""}   # the hoe tills the cell and sows it as soon as the bed is there (held_item._garden_step)

	if bed_crop != "":
		return {"act": "none", "say": "Something is already growing there"}

	return {"act": "sow", "say": ""}


# Planting in rows and grids (Dave 14 Nov 2026, the "plant easily" feel): the mouse wheel in Garden mode steps through these. PROVISIONAL sizes.
const GARDEN_GRIDS := [{"name": "one", "w": 1, "d": 1}, {"name": "a row of 5", "w": 1, "d": 5}, {"name": "3 by 3", "w": 3, "d": 3}, {"name": "5 by 5", "w": 5, "d": 5}]
const SEED_SPACING_M := 1.0   # seeds go one to a tilled metre (the server tills 1 m cells, floor + 0.5)
const BUSH_SPACING_M := 2.0   # PROVISIONAL: bushes two metres apart (the server's own gap is PLANT_BUSH_GAP_M, 1 m)


# The flat spots one Garden click works, nearest the aim first: seeds on the 1 m cell centres round the aimed cell, bushes BUSH_SPACING_M apart round the aim.
# A row runs along the axis the player faces most (`facing`: a flat direction). `grid`: an index of GARDEN_GRIDS.
static func garden_cells(grid: int, kind: String, aim: Vector3, facing: Vector3) -> Array:
	var size: Dictionary = GARDEN_GRIDS[clampi(grid, 0, GARDEN_GRIDS.size() - 1)]
	var step: float = BUSH_SPACING_M if kind == "bush" else SEED_SPACING_M
	var centre: Vector2 = Vector2(aim.x, aim.z) if kind == "bush" else Vector2(floor(aim.x) + 0.5, floor(aim.z) + 0.5)
	var along_x: bool = absf(facing.x) > absf(facing.z)
	var across: int = int(size["w"])
	var ahead: int = int(size["d"])
	var cells: Array = []

	for a in range(ahead):
		for c in range(across):
			var forward: float = (float(a) - float(ahead - 1) * 0.5) * step
			var side: float = (float(c) - float(across - 1) * 0.5) * step
			cells.append(centre + (Vector2(forward, side) if along_x else Vector2(side, forward)))

	cells.sort_custom(func(p, q): return p.distance_squared_to(centre) < q.distance_squared_to(centre))
	return cells
