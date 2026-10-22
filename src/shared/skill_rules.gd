extends RefCounted

# Skill maths (data/items/skills.json "system" and "skills"), pure functions shared by the server and its tests.
# A record is {"p": practice, "peak": best practice reached, "last": game seconds of the last decay step, "day": game day of the
# gain count, "dgain": practice gained that day}. Missing fields read as zero, so every older character is neutral.

const DAY_S := 86400.0


static func config() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/skills.json"))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


# The innate part: neutral_level plus attr_scale times the weighted attributes (each -10..10).
static func innate(cfg: Dictionary, skill: String, attrs: Dictionary) -> float:
	var def: Dictionary = cfg.get("skills", {}).get(skill, {})
	var system: Dictionary = cfg.get("system", {})

	if not def.has("attrs"):
		return 0.0

	var sum: float = 0.0

	for name in def["attrs"]:
		sum += float(def["attrs"][name]) * float(attrs.get(name, 0.0))

	return clampf(float(system.get("neutral_level", 10.0)) + float(system.get("attr_scale", 1.5)) * sum, 0.0, 60.0)


# This skill alone, 0..100: base + (100 - base)(1 - exp(-k practice)).
static func level(cfg: Dictionary, skill: String, attrs: Dictionary, record: Dictionary) -> float:
	var def: Dictionary = cfg.get("skills", {}).get(skill, {})

	if def.is_empty():
		return 0.0

	var base: float = innate(cfg, skill, attrs) + float(record.get("trained", 0.0))
	return clampf(base + (100.0 - base) * (1.0 - exp(-float(def.get("k", 0.02)) * float(record.get("p", 0.0)))), 0.0, 100.0)


# The working level: the skill plus its parent group's level at parent_weight.
static func working(cfg: Dictionary, skill: String, attrs: Dictionary, records: Dictionary) -> float:
	var def: Dictionary = cfg.get("skills", {}).get(skill, {})
	var own: float = level(cfg, skill, attrs, records.get(skill, {}))
	var parent: String = str(def.get("parent", ""))

	if parent != "":
		own += float(cfg.get("system", {}).get("parent_weight", 0.3)) * working(cfg, parent, attrs, records)

	return clampf(own, 0.0, 100.0)


# What a working level does to an action: 1.0 at the neutral level, up to max_factor at 100, never below min_factor.
static func factor(cfg: Dictionary, skill: String, working_level: float) -> float:
	var system: Dictionary = cfg.get("system", {})
	var top: float = float(cfg.get("skills", {}).get(skill, {}).get("max_factor", 1.0))
	var neutral: float = float(system.get("neutral_level", 10.0))
	return maxf(1.0 + (top - 1.0) * (working_level - neutral) / maxf(100.0 - neutral, 1.0), float(system.get("min_factor", 0.8)))


# Lazy decay up to game time `now_s`: after grace_days idle, practice halves every half_life_days, never below floor_share of the peak.
static func decay(cfg: Dictionary, record: Dictionary, now_s: float) -> void:
	var system: Dictionary = cfg.get("system", {})
	var last: float = float(record.get("last", now_s))
	var idle_days: float = (now_s - last) / DAY_S - float(system.get("grace_days", 7.0))

	if idle_days > 0.0 and float(record.get("p", 0.0)) > 0.0:
		var floor_p: float = float(system.get("floor_share", 0.2)) * float(record.get("peak", 0.0))
		record["p"] = maxf(floor_p, float(record["p"]) * pow(0.5, idle_days / maxf(float(system.get("half_life_days", 60.0)), 0.1)))
		# The decay clock starts again from where this step ended, so a second call does not decay twice.
		record["last"] = now_s - float(system.get("grace_days", 7.0)) * DAY_S
	elif not record.has("last"):
		record["last"] = now_s


# Practice from one verified success; returns the points added. Diminishing with level, nothing for trivial work, a soft cap
# per game day, and regain_mult times faster while below the peak (re-honing).
static func gain(cfg: Dictionary, skill: String, attrs: Dictionary, records: Dictionary, difficulty: float, now_s: float, share: float = 1.0) -> float:
	var system: Dictionary = cfg.get("system", {})
	var def: Dictionary = cfg.get("skills", {}).get(skill, {})

	if def.is_empty() or difficulty < float(system.get("trivial_below", 0.2)):
		return 0.0

	var record: Dictionary = records.get(skill, {})
	decay(cfg, record, now_s)
	var day: int = int(now_s / DAY_S)

	if int(record.get("day", -1)) != day:
		record["day"] = day
		record["dgain"] = 0.0

	var g: float = share * float(system.get("gain_per_success", 1.0)) * difficulty * (1.0 - level(cfg, skill, attrs, record) / 100.0)

	if float(record.get("p", 0.0)) < float(record.get("peak", 0.0)):
		g *= float(system.get("regain_mult", 3.0))

	g *= maxf(1.0 - float(record.get("dgain", 0.0)) / maxf(float(system.get("day_cap", 40.0)), 1.0), 0.0)
	record["p"] = float(record.get("p", 0.0)) + g
	record["peak"] = maxf(float(record.get("peak", 0.0)), float(record["p"]))
	record["dgain"] = float(record.get("dgain", 0.0)) + g
	record["last"] = now_s
	records[skill] = record
	return g


static func rusty(cfg: Dictionary, record: Dictionary) -> bool:
	return float(record.get("peak", 0.0)) > 1.0 and float(record.get("p", 0.0)) < float(cfg.get("system", {}).get("rusty_below", 0.7)) * float(record["peak"])
