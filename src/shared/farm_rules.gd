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


# {"act": "sow" | "harvest" | "water" | "none", "prompt": the E line}.
# crop_id/stage: the bed's crop ("" for an empty bed); seed_name: the sentence name of the seed to sow ("" when none is held or carried);
# water_in_hand: a held container with water in it (the same one E uses to drink and fill).
static func bed_action(crops: Dictionary, crop_id: String, stage: int, seed_name: String, water_in_hand: bool) -> Dictionary:
	if crop_id == "":
		if seed_name != "":
			return {"act": "sow", "prompt": "Press E to sow %s" % seed_name}

		return {"act": "none", "prompt": "A tilled bed: carry seeds and press E to sow it"}

	var def: Dictionary = crops.get(crop_id, {})
	var name: String = str(def.get("name", crop_id)).to_lower()

	if stage >= RIPE:
		var tool_class: String = str(def.get("tool_to_harvest", "hand"))
		return {"act": "harvest", "prompt": "Press E to harvest the %s%s" % [name, "" if tool_class == "hand" else " (a %s gives the full yield)" % tool_class]}

	if water_in_hand:
		return {"act": "water", "prompt": "Press E to water the %s (%s)" % [name, STAGE_NAMES[clampi(stage, 0, RIPE)]]}

	return {"act": "none", "prompt": "%s, %s: hold a filled bucket or waterskin and press E to water it" % [name.capitalize(), STAGE_NAMES[clampi(stage, 0, RIPE)]]}
