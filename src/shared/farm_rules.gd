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
