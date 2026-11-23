extends RefCounted

# The Journal's Skills page (Dave 23 Nov 2026): every skill in a table, Name, Skill level and Class (Basic, Advanced, Expert or Master), in
# alphabetical order at first, sorted by any column by clicking its heading (again: the other way). The rows come from the server's skills
# message (inventory_view.gd skill_rows, server_items.gd _send_skills) and skills.json; the class from SkillClasses.class_of. Who teaches a skill is
# read from the shipped dialogue (a can_train condition), for the "needs training to go further (ask Hob)" note here and on the character screen.

const SkillClasses := preload("res://src/shared/skill_classes.gd")
const NAME := "name"
const LEVEL := "level"
const CLASS := "class"

static var _teachers: Dictionary = {}             # skill id -> NPC names whose dialogue offers a lesson in it
static var _lessons: Dictionary = {}              # skill id -> lesson lines "Hob: up to level 40, 3 stone"


# One entry per skill to list: practised or open skills, and locked ones with what they wait for. A planned skill (skills.json "placeholder",
# nothing practises it yet) is left out while its first need is unmet and it has no row, as on the character screen.
# Each: id, name, level (the effective value shown, 0 when locked), cap, class ("" when locked), locked ("" or the need, "Fighting 15"),
# planned, wall (at the top of its class: needs training to go further), trained, rusty, today, day_left, to_next (percent to the next level).
static func rows(cfg: Dictionary, skill_rows: Array) -> Array:
	var defs: Dictionary = cfg.get("skills", {})
	var ids: Array = defs.keys()
	var by_id: Dictionary = {}

	for row in skill_rows:
		var index: int = int(row[0])

		if index >= 0 and index < ids.size():
			by_id[str(ids[index])] = row

	var out: Array = []

	for id in ids:
		var def: Dictionary = defs[id]
		var row: Array = by_id.get(str(id), [])
		var locked: String = unmet_need(def, by_id, defs)
		var planned: bool = bool(def.get("placeholder", false))

		if locked != "" and row.is_empty() and planned:
			continue

		var level: int = int(row[6]) if row.size() > 6 else (int(row[1]) if row.size() > 1 else 1)
		var cap: int = int(row[3]) if row.size() > 3 else 25
		out.append({
			"id": str(id),
			"name": str(def.get("name", id)),
			"level": level if locked == "" else 0,
			"cap": cap,
			"class": SkillClasses.class_of(cfg, float(level)) if locked == "" else "",
			"locked": locked,
			"planned": planned,
			"wall": locked == "" and level >= cap - 1 and cap < int(cfg.get("system", {}).get("max_value", 100)),
			"trained": int(row[4]) if row.size() > 4 else 0,
			"rusty": row.size() > 2 and int(row[2]) == 1,
			"today": row.size() > 5 and int(row[5]) == 1,
			"day_left": int(row[8]) if row.size() > 8 else -1,
			"to_next": int(row[7]) if row.size() > 7 else -1,
		})

	return sorted(cfg, out, NAME, false)


# A sorted copy: by name, level or class (Basic first), the other way when `descending`. Equal rows keep alphabetical order either way.
static func sorted(cfg: Dictionary, list: Array, column: String, descending: bool) -> Array:
	var out: Array = list.duplicate()
	var key: Callable = func(entry: Dictionary) -> Variant:
		if column == LEVEL:
			return int(entry["level"])

		if column == CLASS:
			return SkillClasses.class_rank(cfg, str(entry["class"]))

		return str(entry["name"]).to_lower()

	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ka: Variant = key.call(a)
		var kb: Variant = key.call(b)

		if ka != kb:
			return (ka > kb) if descending else (ka < kb)

		return str(a["name"]).to_lower() < str(b["name"]).to_lower())
	return out


# The first unmet unlock need of a skill as "Swordplay 15" ("" when open), from the values the server sent.
static func unmet_need(def: Dictionary, by_id: Dictionary, defs: Dictionary) -> String:
	for need in def.get("needs", []):
		var row: Array = by_id.get(str(need["skill"]), [])
		var have: int = int(row[6]) if row.size() > 6 else 1

		if have < int(need["value"]):
			return "%s %d" % [str(defs.get(str(need["skill"]), {}).get("name", need["skill"])), int(need["value"])]

	return ""


# The NPCs who teach a skill: any dialogue node with a can_train condition on it, found once in the shipped dialogue files.
static func teachers_of(skill: String) -> Array:
	if _teachers.is_empty():
		_teachers["_"] = []
		var names: Dictionary = {}
		var roster: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/npcs.json"))

		if typeof(roster) == TYPE_DICTIONARY:
			for npc in roster.get("npcs", []):
				names[str(npc.get("id", ""))] = str(npc.get("name", npc.get("id", "")))

		for file in DirAccess.get_files_at("res://data/npcs/dialogue"):
			var tree: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/npcs/dialogue/" + file)) if file.ends_with(".json") else null

			if typeof(tree) != TYPE_DICTIONARY:
				continue

			for node in tree.get("nodes", {}).values():
				for choice in node.get("choices", []):
					var cond: Dictionary = choice.get("if", {})

					if cond.has("can_train"):
						var taught: String = str(cond["can_train"][0])

						if not _teachers.has(taught):
							_teachers[taught] = []

						var who: String = str(names.get(str(tree.get("npc", "")), tree.get("npc", "")))

						if not _teachers[taught].has(who):
							_teachers[taught].append(who)

						var can: Array = cond["can_train"]
						var price: String = "%d %s" % [int(can[3]), str(can[2]).replace("_", " ")] if can.size() > 3 and int(can[3]) > 0 else "free"
						var lesson: String = "%s: up to level %d, %s" % [who, int(can[1]), price]

						if not _lessons.has(taught):
							_lessons[taught] = []

						if not _lessons[taught].has(lesson):
							_lessons[taught].append(lesson)

	return _teachers.get(skill, [])


# Lesson lines for a skill ("Hob: up to level 40, 3 stone"); empty when nobody teaches it.
static func lessons_of(skill: String) -> Array:
	teachers_of(skill)
	return _lessons.get(skill, [])


# The class rows for the page's key: "Basic  1 to 24: rises by use", then each later class and the training it needs.
static func class_lines(cfg: Dictionary) -> PackedStringArray:
	var classes: Array = cfg.get("system", {}).get("classes", [])
	var top: int = int(cfg.get("system", {}).get("max_value", 100))
	var out: PackedStringArray = PackedStringArray()

	for i in classes.size():
		var last: int = int(classes[i + 1]["from"]) - 1 if i + 1 < classes.size() else top
		var how: String = "rises by use" if i == 0 else "a trainer opens it"
		out.append("%s  %d to %d: %s" % [str(classes[i]["name"]), int(classes[i]["from"]), last, how])

	return out
