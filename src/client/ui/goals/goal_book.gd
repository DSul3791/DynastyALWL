extends RefCounted

# The player's goals as the server sends them (protocol 119; docs/design/PLAYER_JOURNAL_GOALS_UI.md): the whole list in its authored order at the join
# (goals), each new completion (goal_done) and the counts of goals with an amount as they move (goal_progress, protocol 122). The Journal, the upper-right Goals box and the Goal Achieved placard read this; nothing here decides
# a goal or pays anything (the server does both). A rejoin sends the list again with its done flags, which is silent: only goal_done announces.

signal changed                                   # the list or a done flag changed: redraw
signal achieved(row: Dictionary, copper: int)    # a goal this character has just completed (once): the placard

var rows: Array = []                             # {id, title, howto, copper, item, item_n, after: PackedStringArray, done, need, have}, in the authored order
var _by_id: Dictionary = {}                      # id -> row


# The goals message: the whole list, replacing what was known.
func on_goals(list: Array) -> void:
	rows = []
	_by_id = {}

	for r in list:
		if typeof(r) != TYPE_ARRAY or (r as Array).size() < 10:
			continue

		var entry: Dictionary = {"id": str(r[0]), "title": str(r[1]), "howto": str(r[2]), "copper": int(r[3]), "item": str(r[4]), "item_n": int(r[5]),
			"after": PackedStringArray(r[6]), "done": bool(r[7]), "need": int(r[8]), "have": int(r[9])}
		rows.append(entry)
		_by_id[entry["id"]] = entry

	changed.emit()


# The goal_done message: marks the goal done and announces it once. A repeat of a goal already done here is ignored (no second placard).
func on_done(id: String, copper: int) -> void:
	var entry: Dictionary = _by_id.get(id, {})

	if entry.is_empty():
		entry = {"id": id, "title": id, "howto": "", "copper": copper, "item": "", "item_n": 0, "after": PackedStringArray(), "done": false, "need": 1, "have": 0}   # not in the list yet: still announce it, once
		_by_id[id] = entry

	if bool(entry["done"]):
		return

	entry["done"] = true
	changed.emit()
	achieved.emit(entry, copper)


# The goal_progress message: goal id -> count so far. An id not in the list is ignored (the next list carries it).
func on_progress(changes: Dictionary) -> void:
	var moved: bool = false

	for id in changes:
		var entry: Dictionary = _by_id.get(str(id), {})

		if not entry.is_empty() and int(entry["have"]) != int(changes[id]):
			entry["have"] = int(changes[id])
			moved = true

	if moved:
		changed.emit()


# A goal's name as the HUD and Journal show it: with its count while it has an amount and is not done ("Gather plant fibre 3/12"; Dave 14 Nov 2026:
# "for everything except single items like "Make a stone axe""), the plain title otherwise.
static func label(entry: Dictionary) -> String:
	var title: String = str(entry.get("title", ""))
	var need: int = int(entry.get("need", 1))

	if need <= 1 or bool(entry.get("done", false)):
		return title

	return "%s %d/%d" % [title, mini(int(entry.get("have", 0)), need), need]


func row(id: String) -> Dictionary:
	return _by_id.get(id, {})


# The first `n` goals not done, in the authored order.
func unfinished(n: int) -> Array:
	var out: Array = []

	for r in rows:
		if out.size() >= n:
			break

		if not bool(r["done"]):
			out.append(r)

	return out


func done_count() -> int:
	return rows.filter(func(r): return bool(r["done"])).size()
