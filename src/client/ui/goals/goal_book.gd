extends RefCounted

# The player's goals as the server sends them (protocol 119; docs/design/PLAYER_JOURNAL_GOALS_UI.md): the whole list in its authored order at the join
# (goals), then each new completion (goal_done). The Journal, the upper-right Goals box and the Goal Achieved placard read this; nothing here decides
# a goal or pays anything (the server does both). A rejoin sends the list again with its done flags, which is silent: only goal_done announces.

signal changed                                   # the list or a done flag changed: redraw
signal achieved(row: Dictionary, copper: int)    # a goal this character has just completed (once): the placard

var rows: Array = []                             # {id, title, howto, copper, item, item_n, after: PackedStringArray, done}, in the authored order
var _by_id: Dictionary = {}                      # id -> row


# The goals message: the whole list, replacing what was known.
func on_goals(list: Array) -> void:
	rows = []
	_by_id = {}

	for r in list:
		if typeof(r) != TYPE_ARRAY or (r as Array).size() < 8:
			continue

		var row: Dictionary = {"id": str(r[0]), "title": str(r[1]), "howto": str(r[2]), "copper": int(r[3]), "item": str(r[4]), "item_n": int(r[5]),
			"after": PackedStringArray(r[6]), "done": bool(r[7])}
		rows.append(row)
		_by_id[row["id"]] = row

	changed.emit()


# The goal_done message: marks the goal done and announces it once. A repeat of a goal already done here is ignored (no second placard).
func on_done(id: String, copper: int) -> void:
	var row: Dictionary = _by_id.get(id, {})

	if row.is_empty():
		row = {"id": id, "title": id, "howto": "", "copper": copper, "item": "", "item_n": 0, "after": PackedStringArray(), "done": false}   # not in the list yet: still announce it

	if bool(row["done"]):
		return

	row["done"] = true
	changed.emit()
	achieved.emit(row, copper)


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
