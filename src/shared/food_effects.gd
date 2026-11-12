extends RefCounted

# Temporary food effects (data/items/food_effects.json; master DYNASTY_MASTER_ITEMS.md s3.16 [D16, D17]; Mission 001 phase 7).
# Shared so the server (the rules) and the client (the HUD lines and the replace question) read the same table.
# A character's effects are {group: {"id": item id, "t": tier, "until": game seconds}}; at most cfg.slots groups are live.

const PATH := "res://data/items/food_effects.json"
const DECLINE := 9   # ACT_EAT b: the player declined the question, eat for calories only


static func load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# {group, tier, hearty?, xp?} of a food, {} when it has no effect (raw ingredients, salt, doughs).
static func profile(item_id: String, cfg: Dictionary) -> Dictionary:
	return cfg.get("foods", {}).get(item_id, {})


# 1-based position of a group in cfg.order (the wire value), 0 when unknown.
static func group_index(group: String, cfg: Dictionary) -> int:
	return (cfg.get("order", []) as Array).find(group) + 1


static func group_at(index: int, cfg: Dictionary) -> String:
	var order: Array = cfg.get("order", [])
	return str(order[index - 1]) if index >= 1 and index <= order.size() else ""


static func group_name(group: String, cfg: Dictionary) -> String:
	return str(cfg.get("groups", {}).get(group, {}).get("name", group))


# The tier row (a Beverage has only two tiers: a higher tier reads the last one).
static func tier_row(group: String, tier: int, cfg: Dictionary) -> Dictionary:
	var tiers: Array = cfg.get("groups", {}).get(group, {}).get("tiers", [])
	return tiers[clampi(tier, 1, tiers.size()) - 1] if not tiers.is_empty() else {}


static func live(effects: Dictionary, now_s: float) -> Dictionary:
	var out: Dictionary = {}

	for group in effects:
		if typeof(effects[group]) == TYPE_DICTIONARY and float(effects[group].get("until", 0.0)) > now_s:
			out[group] = effects[group]

	return out


# The XP change food gives now: the single best bonus minus the dessert penalty (s3.16 combination rules). `skills_only`:
# skill practice, where only an all-skill bonus (a balanced board) counts; otherwise the Fitness tick, where a Main meal's
# Fitness bonus counts too. Overlapping bonuses never multiply.
static func xp_bonus(effects: Dictionary, now_s: float, cfg: Dictionary, skills_only: bool) -> float:
	var best: float = 0.0
	var penalty: float = 0.0
	var on: Dictionary = live(effects, now_s)

	for group in on:
		var row: Dictionary = tier_row(str(group), int(on[group].get("t", 1)), cfg)
		penalty -= minf(float(row.get("xp", 0.0)), 0.0)

		if str(profile(str(on[group].get("id", "")), cfg).get("xp", "")) == "all":
			best = maxf(best, float(row.get("all_xp", 0.0)))
		elif not skills_only:
			best = maxf(best, float(row.get("fitness_xp", 0.0)))

	return best - penalty


# Fitness XP is food only, capped at caps.fitness.
static func fitness_mult(effects: Dictionary, now_s: float, cfg: Dictionary) -> float:
	return 1.0 + minf(xp_bonus(effects, now_s, cfg, false), float(cfg.get("caps", {}).get("fitness", 0.2)))


# Skill XP adds the Rested bonus (comfort.json skill_gain_mult), capped at caps.skill.
static func skill_mult(effects: Dictionary, now_s: float, cfg: Dictionary, rested_mult: float) -> float:
	return 1.0 + minf(xp_bonus(effects, now_s, cfg, true) + rested_mult - 1.0, float(cfg.get("caps", {}).get("skill", 0.25)))


# The strongest food value of a multiplier (regen_mult, exhaustion_mult, hunger_thirst_mult), 1.0 when none: the one farthest
# from 1. A hearty Main meal counts its hearty_regen as a regen_mult.
static func strongest(effects: Dictionary, now_s: float, cfg: Dictionary, field: String) -> float:
	var best: float = 1.0
	var on: Dictionary = live(effects, now_s)

	for group in on:
		var row: Dictionary = tier_row(str(group), int(on[group].get("t", 1)), cfg)
		var value: float = float(row.get(field, 1.0))

		if field == "regen_mult" and bool(profile(str(on[group].get("id", "")), cfg).get("hearty", false)):
			value = float(row.get("hearty_regen", 1.0))

		if absf(value - 1.0) > absf(best - 1.0):
			best = value

	return best


# What eating `item_id` does to the slots, given the player's answer `choice` (0 none yet, a group index to replace, DECLINE):
# {} touches no slot; {"ask": [group indexes]} must ask first; {"group": g, "fresh": the slot was empty or had run out, "drop": a group to clear}.
static func plan(effects: Dictionary, now_s: float, item_id: String, choice: int, cfg: Dictionary) -> Dictionary:
	var prof: Dictionary = profile(item_id, cfg)

	if prof.is_empty() or choice == DECLINE:
		return {}

	var group: String = str(prof["group"])
	var on: Dictionary = live(effects, now_s)

	if on.has(group):
		if int(prof["tier"]) < int(on[group].get("t", 1)) and choice != group_index(group, cfg):
			return {"ask": [group_index(group, cfg)]}   # a weaker food would replace a stronger effect

		return {"group": group, "fresh": false, "drop": ""}

	if on.size() < int(cfg.get("slots", 3)):
		return {"group": group, "fresh": true, "drop": ""}

	var drop: String = group_at(choice, cfg)

	if on.has(drop):
		return {"group": group, "fresh": true, "drop": drop}

	var groups: Array = []

	for g in cfg.get("order", []):
		if on.has(g):
			groups.append(group_index(str(g), cfg))

	return {"ask": groups}


# Fills the planned slot (replacing, never stacking) and drops run-out or replaced entries.
static func apply(effects: Dictionary, now_s: float, item_id: String, step: Dictionary, cfg: Dictionary) -> void:
	var on: Dictionary = live(effects, now_s)

	for group in effects.keys():
		if not on.has(group) or group == str(step.get("drop", "")):
			effects.erase(group)

	var prof: Dictionary = profile(item_id, cfg)
	var group: String = str(step["group"])
	effects[group] = {"id": item_id, "t": int(prof["tier"]), "until": now_s + float(tier_row(group, int(prof["tier"]), cfg).get("h", 1.0)) * 3600.0}


# One line for the HUD and the tooltip: what the effect does, e.g. "Fitness XP +15 %".
static func describe(group: String, tier: int, item_id: String, cfg: Dictionary) -> String:
	var row: Dictionary = tier_row(group, tier, cfg)
	var prof: Dictionary = profile(item_id, cfg)
	var parts: PackedStringArray = PackedStringArray()

	if str(prof.get("xp", "")) == "all" and row.has("all_xp"):
		parts.append("all XP +%d %%" % int(round(float(row["all_xp"]) * 100.0)))
	elif row.has("fitness_xp"):
		parts.append("Fitness XP +%d %%" % int(round(float(row["fitness_xp"]) * 100.0)))

	if bool(prof.get("hearty", false)) and row.has("hearty_regen"):
		parts.append("health regeneration +%d %%" % int(round((float(row["hearty_regen"]) - 1.0) * 100.0)))

	if row.has("regen_mult"):
		parts.append("health regeneration +%d %%" % int(round((float(row["regen_mult"]) - 1.0) * 100.0)))

	if row.has("exhaustion_mult"):
		parts.append("energy drain -%d %%" % int(round((1.0 - float(row["exhaustion_mult"])) * 100.0)))

	if row.has("hunger_thirst_mult"):
		parts.append("hunger and thirst -%d %%" % int(round((1.0 - float(row["hunger_thirst_mult"])) * 100.0)))

	if row.has("xp"):
		parts.append("XP %d %%" % int(round(float(row["xp"]) * 100.0)))

	return ", ".join(parts)
