extends RefCounted

# The skills web (Dave 2026-10-21; items/SKILLS_WEB_DESIGN.md; data/items/skills.json version 2). Pure functions shared by the
# server and its tests. A record is {"p": practice units, "t": training level 0..4, "peak", "last", "day", "dgain", "tlast"};
# a missing field reads as zero, so every skill of every character starts at value 1.

const Old := preload("res://src/shared/skill_rules.gd")   # decay and rusty are unchanged
const Attributes := preload("res://src/shared/attributes.gd")
const DAY_S := 86400.0

static var _graph_cache: Dictionary = {}


static func config() -> Dictionary:
	return Old.config()


# --- The graph ---

# {"depth": {id: int}, "order": [ids parents-first], "children": {id: [ids]}}: computed once per config, nothing per tick.
# A cycle or a missing parent leaves "error" set (the validator reports it).
static func graph(cfg: Dictionary) -> Dictionary:
	var key: int = cfg.hash()

	if _graph_cache.has(key):
		return _graph_cache[key]

	var skills: Dictionary = cfg.get("skills", {})
	var depth: Dictionary = {}
	var order: Array = []
	var children: Dictionary = {}
	var error: String = ""
	var pending: Array = skills.keys()
	var guard: int = 0

	while not pending.is_empty() and guard < 10000:
		guard += 1
		var next: Array = []

		for id in pending:
			var ready: bool = true
			var d: int = 0

			for parent in skills[id].get("parents", {}):
				if not skills.has(parent):
					error = "%s has unknown parent %s" % [id, parent]
					ready = false
				elif not depth.has(parent):
					ready = false
				else:
					d = maxi(d, int(depth[parent]) + 1)

			if ready:
				depth[id] = d
				order.append(id)

				for parent in skills[id].get("parents", {}):
					if not children.has(parent):
						children[parent] = []

					children[parent].append(id)
			else:
				next.append(id)

		if next.size() == pending.size():
			if error == "":
				error = "cycle among %s" % str(next)

			break

		pending = next

	var result: Dictionary = {"depth": depth, "order": order, "children": children, "error": error}
	_graph_cache[key] = result
	return result


static func ancestors(cfg: Dictionary, skill: String) -> Array:
	var out: Array = []
	var todo: Array = [skill]

	while not todo.is_empty():
		var id: String = todo.pop_back()

		for parent in cfg.get("skills", {}).get(id, {}).get("parents", {}):
			if not out.has(parent):
				out.append(parent)
				todo.append(parent)

	return out


# --- Practice units and values ---

static func _mult(cfg: Dictionary, skill: String) -> float:
	return pow(float(cfg["system"].get("generation_mult", 1.5)), float(graph(cfg)["depth"].get(skill, 0)))


# The raw value (a float, 1..max_value) from a record's practice units.
static func raw_value(cfg: Dictionary, skill: String, record: Dictionary) -> float:
	var system: Dictionary = cfg["system"]
	var g: float = float(system.get("growth", 1.045))
	var adj: float = maxf(float(record.get("p", 0.0)), 0.0) / _mult(cfg, skill)
	return clampf(1.0 + log(1.0 + adj * (g - 1.0) / float(system.get("base_cost", 40.0))) / log(g), 1.0, float(system.get("max_value", 100)))


# The practice units a value needs (the inverse).
static func units_for(cfg: Dictionary, skill: String, value: float) -> float:
	var system: Dictionary = cfg["system"]
	var g: float = float(system.get("growth", 1.045))
	return float(system.get("base_cost", 40.0)) * (pow(g, value - 1.0) - 1.0) / (g - 1.0) * _mult(cfg, skill)


static func cap_of(cfg: Dictionary, skill: String, records: Dictionary) -> int:
	var system: Dictionary = cfg["system"]
	var level: int = int(records.get(skill, {}).get("t", 0))

	for a in ancestors(cfg, skill):
		level = maxi(level, int(records.get(a, {}).get("t", 0)))

	return mini(int(system.get("step", 25)) * (1 + level), int(system.get("max_value", 100)))


# The floor training gives: cap + floor_over_cap of the highest training level in the skill's family (itself and ancestors).
static func floor_of(cfg: Dictionary, skill: String, records: Dictionary) -> float:
	var system: Dictionary = cfg["system"]
	var level: int = int(records.get(skill, {}).get("t", 0))

	for a in ancestors(cfg, skill):
		level = maxi(level, int(records.get(a, {}).get("t", 0)))

	return float(int(system.get("step", 25)) * level + int(system.get("floor_over_cap", 5))) if level > 0 else 1.0


# What the skill reads as: its own value or the family floor, whichever is higher.
static func effective(cfg: Dictionary, skill: String, records: Dictionary) -> float:
	return minf(maxf(raw_value(cfg, skill, records.get(skill, {})), floor_of(cfg, skill, records)), float(cfg["system"].get("max_value", 100)))


# The class a skill value is in (Dave 23 Nov 2026): Basic 1-24, Advanced 25-49, Expert 50-74, Master 75-100 (skills.json system "classes").
# Use rises inside a class; a trainer opens the next and jumps the skill to its start (train(), SKILL_TRAINING.md). Reads the whole value, as the level is shown.
static func class_of(cfg: Dictionary, value: float) -> String:
	var found: String = ""

	for entry in cfg.get("system", {}).get("classes", []):
		if floorf(value) >= float(entry.get("from", 1)):   # no slack: use creeps to 24.99999 and shows 24, still Basic
			found = str(entry.get("name", ""))

	return found


# Where a class sits in the order (0 for Basic), -1 for a name that is not a class: for sorting by class.
static func class_rank(cfg: Dictionary, name: String) -> int:
	var classes: Array = cfg.get("system", {}).get("classes", [])

	for i in classes.size():
		if str(classes[i].get("name", "")) == name:
			return i

	return -1


static func unlocked(cfg: Dictionary, skill: String, records: Dictionary) -> bool:
	for need in cfg.get("skills", {}).get(skill, {}).get("needs", []):
		if effective(cfg, str(need["skill"]), records) < float(need["value"]):
			return false

	return true


# The weighted trait points of a skill: attributes are 0 to 100 (Dave 19 Nov 2026) and each counts as Attributes.offset, -10 at 0, 0 at 50 (an average
# character), +10 at 100, so trait_speed and trait_effect stay per 5 points. A missing attribute is average.
static func trait_points(cfg: Dictionary, skill: String, attrs: Dictionary) -> float:
	var sum: float = 0.0

	for name in cfg.get("skills", {}).get(skill, {}).get("traits", {}):
		sum += float(cfg["skills"][skill]["traits"][name]) * Attributes.offset(float(attrs.get(name, Attributes.NEUTRAL)))

	return sum


# The working value: the effective value plus parent_bonus x the weighted parents' working values above 1.
static func working(cfg: Dictionary, skill: String, records: Dictionary) -> float:
	var def: Dictionary = cfg.get("skills", {}).get(skill, {})

	if def.is_empty():
		return 1.0

	var own: float = effective(cfg, skill, records)
	var bonus: float = 0.0

	for parent in def.get("parents", {}):
		bonus += float(def["parents"][parent]) * (working(cfg, str(parent), records) - 1.0)

	return clampf(own + float(cfg["system"].get("parent_bonus", 0.2)) * bonus, 1.0, float(cfg["system"].get("max_value", 100)))


# What a working value does to an action: exactly 1.0 for an average new character, up to max_factor at 100, the trait
# effect on top (about +/-20 percent at the extremes), never below min_factor.
static func factor(cfg: Dictionary, skill: String, working_value: float, attrs: Dictionary) -> float:
	var system: Dictionary = cfg["system"]
	var top: float = float(cfg.get("skills", {}).get(skill, {}).get("max_factor", 1.0))
	var f: float = 1.0 + (top - 1.0) * (working_value - 1.0) / maxf(float(system.get("max_value", 100)) - 1.0, 1.0)
	f *= 1.0 + float(system.get("trait_effect", 0.02)) * trait_points(cfg, skill, attrs)
	return maxf(f, float(system.get("min_factor", 0.8)))


# --- Gains ---

# Lift a skill below its family floor up to it, only when it is practised (no fan-out writes at training time).
static func _catch_up(cfg: Dictionary, skill: String, records: Dictionary, record: Dictionary) -> void:
	var floor_v: float = floor_of(cfg, skill, records)

	if raw_value(cfg, skill, record) < floor_v:
		record["p"] = units_for(cfg, skill, floor_v)
		record["peak"] = maxf(float(record.get("peak", 0.0)), float(record["p"]))


# Practice units for one verified success, added to the skill and (as a share) up the parents. Returns the units the skill got.
# Nothing for trivial work or a locked skill; slows to zero near the cap; a per-skill soft cap per game day; x regain below the peak.
static func gain(cfg: Dictionary, skill: String, attrs: Dictionary, records: Dictionary, difficulty: float, now_s: float, share: float = 1.0) -> float:
	var system: Dictionary = cfg["system"]
	var def: Dictionary = cfg.get("skills", {}).get(skill, {})

	if def.is_empty() or difficulty < float(system.get("trivial_below", 0.2)) or not unlocked(cfg, skill, records):
		return 0.0

	var record: Dictionary = records.get(skill, {})
	Old.decay(cfg, record, now_s)
	records[skill] = record
	_catch_up(cfg, skill, records, record)
	var day: int = int(now_s / DAY_S)

	if int(record.get("day", -1)) != day:
		record["day"] = day
		record["dgain"] = 0.0

	var cap: float = float(cap_of(cfg, skill, records))
	var v: float = raw_value(cfg, skill, record)
	# Use slows to nothing just under the cap (24, 49, 74: a trainer opens the next class). In the last class it slows to the top itself, so
	# Master reaches 100 by use (Dave 23 Nov 2026: every skill runs 1 to 100).
	var top: float = float(system.get("max_value", 100))
	var slow: float = clampf((cap + (1.0 if cap >= top else 0.0) - v) / float(system.get("slow_last", 6)), 0.0, 1.0) if v < top else 0.0
	var speed: float = (1.0 + float(system.get("trait_speed", 0.01)) * trait_points(cfg, skill, attrs)) * pow(float(system.get("train_speed", 1.2)), float(record.get("t", 0)))
	var g: float = share * float(system.get("gain_units", 7.0)) * difficulty * speed * slow

	if float(record.get("p", 0.0)) < float(record.get("peak", 0.0)):
		g *= float(system.get("regain_mult", 3.0))

	g *= maxf(1.0 - float(record.get("dgain", 0.0)) / maxf(float(system.get("day_cap_units", 300.0)), 1.0), 0.0)
	record["p"] = float(record.get("p", 0.0)) + g
	record["peak"] = maxf(float(record.get("peak", 0.0)), float(record["p"]))
	record["dgain"] = float(record.get("dgain", 0.0)) + g
	record["last"] = now_s
	return g


# One success at a skill: the skill gets specific_share, the rest goes up the parents split by their weights, and each further
# generation passes on feed_ratio of what it received. Returns the units the skill itself gained.
# The skill a success at `skill` trains now (Dave 23 Nov 2026: everyone starts at 1 in all skills and gains experience by doing): the skill
# itself once unlocked, else its nearest unlocked parent (the heaviest first), so the practice that will unlock it is not lost; "" when none.
static func trainable(cfg: Dictionary, skill: String, records: Dictionary, seen: Dictionary = {}) -> String:
	var skills: Dictionary = cfg.get("skills", {})

	if not skills.has(skill) or seen.has(skill):
		return ""   # seen: a looped graph (validate reports it) ends here

	seen[skill] = true

	if unlocked(cfg, skill, records):
		return skill

	var parents: Dictionary = skills[skill].get("parents", {})
	var order: Array = parents.keys()
	order.sort_custom(func(a: Variant, b: Variant) -> bool: return float(parents[a]) > float(parents[b]))

	for p in order:
		var got: String = trainable(cfg, str(p), records, seen)

		if got != "":
			return got

	return ""


static func practice(cfg: Dictionary, skill: String, attrs: Dictionary, records: Dictionary, difficulty: float, now_s: float) -> float:
	var system: Dictionary = cfg["system"]
	var share: float = float(system.get("specific_share", 0.8))
	var gained: float = gain(cfg, skill, attrs, records, difficulty, now_s, share)

	if gained > 0.0:
		_feed_up(cfg, skill, 1.0 - share, attrs, records, difficulty, now_s)

	return gained


static func _feed_up(cfg: Dictionary, skill: String, amount: float, attrs: Dictionary, records: Dictionary, difficulty: float, now_s: float) -> void:
	var parents: Dictionary = cfg["skills"][skill].get("parents", {})
	var total: float = 0.0

	for p in parents:
		total += float(parents[p])

	for p in parents:
		var part: float = amount * float(parents[p]) / maxf(total, 0.001)
		gain(cfg, str(p), attrs, records, difficulty, now_s, part)
		_feed_up(cfg, str(p), part * float(cfg["system"].get("feed_ratio", 0.4)), attrs, records, difficulty, now_s)


# --- Training (a teacher or trainer calls this later; step A only provides it) ---

# Why this skill cannot be trained to its next level now ("" when it can). `teacher` is the teacher's effective value, or -1
# when an admin or a test trains without one.
static func train_problem(cfg: Dictionary, skill: String, records: Dictionary, now_s: float, teacher_value: float = -1.0, teacher_level: int = 99) -> String:
	var system: Dictionary = cfg["system"]
	var record: Dictionary = records.get(skill, {})
	var level: int = int(record.get("t", 0)) + 1

	if not cfg.get("skills", {}).has(skill):
		return "unknown skill"

	# Three trainings reach the last band (caps 25, 50, 75, 100); a fourth would only jump the skill to the top.
	if level * int(system.get("step", 25)) >= int(system.get("max_value", 100)):
		return "already at the top"

	if not unlocked(cfg, skill, records):
		return "locked"

	# The value it reads as (a decayed or unpractised skill still reads its training floor), with a hair of slack for float round trips.
	if effective(cfg, skill, records) + 0.001 < float(cap_of(cfg, skill, records) - int(system.get("train_near_cap", 5))):
		return "not near the cap yet"

	if now_s - float(record.get("tlast", -1.0e12)) < float(system.get("train_cooldown_days", 3.0)) * DAY_S:
		return "trained too recently"

	if teacher_value >= 0.0:
		if teacher_value < float(level * int(system.get("step", 25)) + int(system.get("floor_over_cap", 5)) + int(system.get("teacher_margin", 10))):
			return "the teacher is not skilled enough"

		if teacher_level < level:
			return "the teacher is not trained that far"

	return ""


# Training level up: the cap rises one step, the skill jumps to cap + floor_over_cap, gains speed up. Returns "" or the reason.
static func train(cfg: Dictionary, skill: String, records: Dictionary, now_s: float, teacher_value: float = -1.0, teacher_level: int = 99) -> String:
	var problem: String = train_problem(cfg, skill, records, now_s, teacher_value, teacher_level)

	if problem != "":
		return problem

	var system: Dictionary = cfg["system"]
	var record: Dictionary = records.get(skill, {})
	record["t"] = int(record.get("t", 0)) + 1
	var jump: float = float(int(system.get("step", 25)) * int(record["t"]) + int(system.get("floor_over_cap", 5)))
	record["p"] = maxf(float(record.get("p", 0.0)), units_for(cfg, skill, minf(jump, float(system.get("max_value", 100)))))
	record["peak"] = maxf(float(record.get("peak", 0.0)), float(record["p"]))
	record["tlast"] = now_s
	record["last"] = now_s
	records[skill] = record
	return ""


# --- Build 9257 saves (training floors) ---

# A training before 23 Nov 2026 set the family floor floor_over_cap (then 5) over the band: 30, 55, 80. Dave's rule since (SKILL_TRAINING.md)
# puts it at the band floor: 25, 50, 75. A character trained under the old rule keeps what its skills read then: every skill whose family
# floor under the old number is above what it reads now has its practice lifted to that old floor, once, when the save is read. Returns how
# many records were lifted. A character never trained is not touched.
static func keep_old_floors(cfg: Dictionary, records: Dictionary, old_over: int) -> int:
	var system: Dictionary = cfg.get("system", {})
	var lifted: int = 0

	for skill in cfg.get("skills", {}):
		var level: int = int(records.get(skill, {}).get("t", 0)) if typeof(records.get(skill, {})) == TYPE_DICTIONARY else 0

		for a in ancestors(cfg, str(skill)):
			if typeof(records.get(a, {})) == TYPE_DICTIONARY:
				level = maxi(level, int(records.get(a, {}).get("t", 0)))

		if level <= 0:
			continue

		var old_floor: float = minf(float(int(system.get("step", 25)) * level + old_over), float(system.get("max_value", 100)))

		if effective(cfg, str(skill), records) >= old_floor - 0.0001:
			continue

		var record: Dictionary = records.get(skill, {}) if typeof(records.get(skill, {})) == TYPE_DICTIONARY else {}
		record["p"] = maxf(float(record.get("p", 0.0)), units_for(cfg, str(skill), old_floor))
		record["peak"] = maxf(float(record.get("peak", 0.0)), float(record["p"]))
		records[skill] = record
		lifted += 1

	return lifted


# --- Old saves (protocol 37) ---

# The new record for an old one {p, peak, trained}: the same fraction of the way to the untrained cap.
static func migrate_record(cfg: Dictionary, skill: String, old: Dictionary) -> Dictionary:
	var system: Dictionary = cfg["system"]
	var k: float = float(cfg.get("migration", {}).get("k", {}).get(skill, 0.02))
	var step: float = float(system.get("step", 25))
	var out: Dictionary = {}

	for field in ["p", "peak"]:
		var f: float = 1.0 - exp(-k * float(old.get(field, 0.0)))
		out[field] = units_for(cfg, skill, 1.0 + (step - 1.0) * f)

	if old.has("last"):
		out["last"] = old["last"]

	out["t"] = 0
	return out


# Every old record of a skills block converted; unknown skills are dropped. `report` gets one line per record for a dry run.
static func migrate_block(cfg: Dictionary, old_block: Dictionary, report: Array = []) -> Dictionary:
	var out: Dictionary = {}

	for skill in old_block:
		if not cfg.get("skills", {}).has(skill):
			report.append("%s: unknown skill dropped" % skill)
			continue

		out[skill] = migrate_record(cfg, str(skill), old_block[skill])
		report.append("%s: practice %.1f -> value %.1f" % [skill, float(old_block[skill].get("p", 0.0)), raw_value(cfg, str(skill), out[skill])])

	return out


# --- The validator (also used by validate_items) ---

# Problems with the graph data; empty when it is sound: acyclic, every skill reaches a trait, parents and needs exist, every
# unlock value is reachable (at most max_value) and does not need the skill itself.
static func validate(cfg: Dictionary) -> Array:
	var problems: Array = []
	var g: Dictionary = graph(cfg)
	var skills: Dictionary = cfg.get("skills", {})
	var traits: Array = cfg.get("traits", [])
	var max_value: float = float(cfg.get("system", {}).get("max_value", 100))

	if g["error"] != "":
		problems.append(g["error"])

	for id in skills:
		var def: Dictionary = skills[id]

		if def.get("traits", {}).is_empty() and not ancestors_have_traits(cfg, id):
			problems.append("%s reaches no trait" % id)

		for name in def.get("traits", {}):
			if not traits.has(name):
				problems.append("%s names unknown trait %s" % [id, name])

		for need in def.get("needs", []):
			if not skills.has(str(need.get("skill", ""))):
				problems.append("%s needs unknown skill %s" % [id, str(need.get("skill", ""))])
			elif str(need["skill"]) == id:
				problems.append("%s needs itself" % id)
			elif float(need.get("value", 0)) > max_value:
				problems.append("%s needs %s at %s, above the top" % [id, str(need["skill"]), str(need["value"])])

		if float(def.get("max_factor", 1.0)) < 1.0:
			problems.append("%s max_factor under 1" % id)

	# An unlock chain must not loop: follow needs and parents together.
	for id in skills:
		var seen: Dictionary = {}
		var todo: Array = [id]

		while not todo.is_empty():
			var cur: String = todo.pop_back()

			for need in skills.get(cur, {}).get("needs", []):
				var n: String = str(need.get("skill", ""))

				if n == id:
					problems.append("%s's unlock chain loops back to itself" % id)
				elif skills.has(n) and not seen.has(n):
					seen[n] = true
					todo.append(n)

	# The classes follow the training bands: one class per step, the first from 1, each next from step x its place, the last up to the top.
	var system: Dictionary = cfg.get("system", {})
	var classes: Array = system.get("classes", [])

	if classes.size() * int(system.get("step", 25)) != int(system.get("max_value", 100)):
		problems.append("%d classes do not cover 1 to %d in steps of %d" % [classes.size(), int(system.get("max_value", 100)), int(system.get("step", 25))])

	for i in classes.size():
		if int(classes[i].get("from", -1)) != (1 if i == 0 else i * int(system.get("step", 25))) or str(classes[i].get("name", "")) == "":
			problems.append("class %d (%s) does not start at %d" % [i, str(classes[i].get("name", "")), 1 if i == 0 else i * int(system.get("step", 25))])

	for action in cfg.get("actions", {}):
		if not skills.has(str(cfg["actions"][action].get("skill", ""))):
			problems.append("action %s names an unknown skill" % action)
		elif trainable(cfg, str(cfg["actions"][action]["skill"]), {}) == "":
			problems.append("action %s trains a locked skill with no unlocked parent" % action)

	return problems


static func ancestors_have_traits(cfg: Dictionary, skill: String) -> bool:
	for a in ancestors(cfg, skill):
		if not cfg["skills"][a].get("traits", {}).is_empty():
			return true

	return false
