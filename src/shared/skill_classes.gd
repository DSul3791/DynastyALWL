extends RefCounted

# Skill classes, shared by the server (skill_web.gd validate, tests) and the client (the Journal's Skills page). No other dependency, so the
# client pack carries it without the server's skill rules.

# The class a skill value is in (Dave 23 Nov 2026): Basic 1-24, Advanced 25-49, Expert 50-74, Master 75-100 (skills.json system "classes").
# Use rises inside a class; a trainer opens the next and jumps the skill to its start (skill_web.gd train(), SKILL_TRAINING.md). Reads the whole value, as the level is shown.
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
