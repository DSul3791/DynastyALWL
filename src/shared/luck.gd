extends RefCounted

# Luck (job 77, Dave 2026-10-21): a whole number, -MAX to +MAX, fixed when the character is made, that nudges every
# server roll the character takes part in (loot, finds, yields, chance, later fate). 0 is neutral. The nudge is small
# and tuned in data/items/luck.json. Every server roll goes through here or is marked `# luck-exempt: <reason>`
# (python3 tools/check_luck.py fails on a raw random call that is neither).

const PATH := "res://data/items/luck.json"
const MAX := 10


static func load_config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# A draw u in [0,1) pulled toward 0 when lucky and toward 1 when unlucky (so "u under p" succeeds more often).
static func low(u: float, luck: int, strength: float) -> float:
	return pow(clampf(u, 0.0, 1.0), exp(float(clampi(luck, -MAX, MAX)) * strength))


# The same draw pulled the other way: lucky gives higher values.
static func high(u: float, luck: int, strength: float) -> float:
	return pow(clampf(u, 0.0, 1.0), exp(-float(clampi(luck, -MAX, MAX)) * strength))


# True with probability p, raised or lowered by luck (0 and 1 stay 0 and 1).
static func chance(u: float, p: float, luck: int, strength: float) -> bool:
	return low(u, luck, strength) < p


# A whole number from lo to hi, the top end more likely when lucky.
static func amount(u: float, lo: int, hi: int, luck: int, strength: float) -> int:
	return clampi(lo + int(floor(high(u, luck, strength) * float(hi - lo + 1))), lo, hi)
