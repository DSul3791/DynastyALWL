extends RefCounted

# The data side of a player character (Sonny, plan 22 of CHARACTER_DESIGN_VISION.md Part 8, rules 5.7 and 5.8, drafts of Part 9): a record with a name, an ancestry, the body
# share code, a background, seven attribute values by points or by roll, and a greatest fear; the two ways to get the values; the text form for saving; and the checks a
# server would run. NOTHING here is connected to the game, the network or an account. Every number marked "draft" is a placeholder for Dave and the skills designers.
# The same seed always gives the same roll, so a server can recompute a rolled record instead of trusting it (5.8.3).

const Generator := preload("res://src/client/character/body_generator.gd")

const ATTRIBUTES := ["luck", "fitness", "strength", "dexterity", "memory", "wisdom", "courage"]     # Part 9.1: Courage is the proposed new one
const ATTR_MIN := -10
const ATTR_MAX := 10
const FEAR_COUNT := 35          # the draft list of 5.8.8
const NAME_MAX := 24

# Point buy (draft): everything starts at 0; the first three steps up cost 1 each, the next three cost 2 each (so +6 costs 9); going down to -3 gives 1 point back per step.
const POOL := 14
const BUY_MAX := 6
const BUY_MIN := -3
const STEP_COSTS := [1, 1, 1, 2, 2, 2]

# Roll (draft): each attribute is 2 + (2d4 - 5), so -1 to 5 with a mean of 2; seven of them average 14, the same as the pool's expected total. The total must lie between
# ROLL_FLOOR and ROLL_CEILING (a roll outside is thrown again); a player may re-roll MAX_REROLLS times and keeps the last result.
const ROLL_MEAN := 2
const ROLL_FLOOR := 8
const ROLL_CEILING := 20
const MAX_REROLLS := 3

# Part 9.2, the twelve draft backgrounds: id -> attribute nudges added after the base values (clamped to the range).
const BACKGROUNDS := {
	"woodcutters_helper": {"strength": 1}, "river_fisher": {"wisdom": 1}, "hedge_herbalist": {"memory": 1}, "quarry_apprentice": {"strength": 1, "fitness": 1},
	"hunters_kin": {"dexterity": 1}, "travelling_peddler": {"memory": 1}, "hermits_student": {"wisdom": 2}, "shepherd": {"fitness": 1},
	"ferry_hand": {"fitness": 1}, "cooks_helper": {"dexterity": 1}, "tower_watch": {"wisdom": 1}, "wandering_tinkerer": {"dexterity": 1, "luck": 1},
}


static func blank() -> Dictionary:
	var base: Dictionary = {}

	for a in ATTRIBUTES:
		base[a] = 0

	return {"name": "", "ancestry": "", "genome_code": "", "background": "", "fear": 1, "method": "points", "roll_seed": 0, "rerolls": 0, "base": base}


# What the next step up costs from a value, or -1 when it is at the cap.
static func step_cost(value: int) -> int:
	if value >= BUY_MAX:
		return -1

	return 1 if value < 0 else int(STEP_COSTS[value])


# The points a set of base values spends (negative values give points back).
static func points_spent(base: Dictionary) -> int:
	var total: int = 0

	for a in ATTRIBUTES:
		var v: int = int(base.get(a, 0))

		if v > 0:
			for i in range(v):
				total += int(STEP_COSTS[mini(i, STEP_COSTS.size() - 1)])      # steps past the cap cost the last price
		else:
			total += v           # each step below zero refunds one point

	return total


# One roll from a seed: {"base": {...}, "tries": n}. The seed makes it repeatable; a roll whose total falls outside the floor and ceiling is thrown again from the same stream.
static func roll(seed_value: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value

	for tries in range(1, 1000):
		var base: Dictionary = {}
		var total: int = 0

		for a in ATTRIBUTES:
			var v: int = ROLL_MEAN + (rng.randi_range(1, 4) + rng.randi_range(1, 4) - 5)
			base[a] = v
			total += v

		if total >= ROLL_FLOOR and total <= ROLL_CEILING:
			return {"base": base, "tries": tries}

	return {"base": blank()["base"], "tries": 1000}


# The record's attributes for play: base values plus the background's nudges, kept inside the range.
static func final_attributes(rec: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	var nudges: Dictionary = BACKGROUNDS.get(str(rec.get("background", "")), {})

	for a in ATTRIBUTES:
		out[a] = clampi(int((rec["base"] as Dictionary).get(a, 0)) + int(nudges.get(a, 0)), ATTR_MIN, ATTR_MAX)

	return out


# A fresh rolled record: the roll for `seed_value` with `rerolls` extra throws (each re-roll takes the next seed).
static func with_roll(rec: Dictionary, seed_value: int, rerolls: int) -> Dictionary:
	var out: Dictionary = rec.duplicate(true)
	out["method"] = "roll"
	out["roll_seed"] = seed_value
	out["rerolls"] = clampi(rerolls, 0, MAX_REROLLS)
	out["base"] = roll(seed_value + int(out["rerolls"]))["base"]
	return out


# What a server would check. Returns a list of plain sentences; empty means the record is acceptable. `ancestries` is the list of ancestry ids the game offers.
static func validate(rec: Dictionary, ancestries: Array) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()
	var name: String = str(rec.get("name", ""))

	if name.strip_edges().is_empty() or name.length() > NAME_MAX:
		errors.append("the name must be 1 to %d characters" % NAME_MAX)

	if name != name.strip_edges() or name.contains("\n") or name.contains("\t"):
		errors.append("the name has stray spaces or control characters")

	if not ancestries.has(str(rec.get("ancestry", ""))):
		errors.append("unknown ancestry")

	if not BACKGROUNDS.has(str(rec.get("background", ""))):
		errors.append("unknown background")

	var fear: int = int(rec.get("fear", 0))

	if fear < 1 or fear > FEAR_COUNT:
		errors.append("unknown fear")

	if Generator.decode(str(rec.get("genome_code", ""))).is_empty():
		errors.append("the body code is not valid")

	var base: Variant = rec.get("base", null)

	if typeof(base) != TYPE_DICTIONARY:
		errors.append("the attributes are missing")
		return errors

	for a in ATTRIBUTES:
		if not (base as Dictionary).has(a):
			errors.append("attribute %s is missing" % a)

	if not errors.is_empty():
		return errors

	var method: String = str(rec.get("method", ""))

	if method == "points":
		for a in ATTRIBUTES:
			var v: int = int(base[a])

			if v < BUY_MIN or v > BUY_MAX:
				errors.append("%s is outside %d to %d" % [a, BUY_MIN, BUY_MAX])

		if points_spent(base) > POOL:
			errors.append("more than %d points spent (%d)" % [POOL, points_spent(base)])
	elif method == "roll":
		var rerolls: int = int(rec.get("rerolls", 0))

		if rerolls < 0 or rerolls > MAX_REROLLS:
			errors.append("too many re-rolls")
		else:
			var again: Dictionary = roll(int(rec.get("roll_seed", 0)) + rerolls)["base"]

			for a in ATTRIBUTES:
				if int(again[a]) != int(base[a]):
					errors.append("the rolled values do not match the roll seed")
					break
	else:
		errors.append("unknown method")

	return errors


static func to_text(rec: Dictionary) -> String:
	return JSON.stringify(rec)


# Reads a record back; {} when the text is not a record. Numbers come back as whole numbers.
static func from_text(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)

	if typeof(parsed) != TYPE_DICTIONARY:
		return {}

	var rec: Dictionary = parsed
	var base: Variant = rec.get("base", null)

	if typeof(base) != TYPE_DICTIONARY:
		return {}

	for a in (base as Dictionary).keys():
		base[a] = int(base[a])

	for key in ["fear", "roll_seed", "rerolls"]:
		rec[key] = int(rec.get(key, 0))

	return rec
