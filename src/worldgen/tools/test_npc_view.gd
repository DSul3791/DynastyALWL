extends SceneTree

# The client draws the NPCs the server lists (Mandy, 2026-10-21, after "No NPC drawn (roster 2, drawn 0)"): the roster and rows of
# the two spawn NPCs must give two drawn bodies next to spawn, in every state, and survive running frames. Fails if the roster has
# NPCs but none is drawn.
#   godot --headless --path . --script res://src/worldgen/tools/test_npc_view.gd

const NpcViewScript := preload("res://src/client/npc_view.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var view: Node3D = NpcViewScript.new()
	get_root().add_child(view)
	var text: String = FileAccess.get_file_as_string("res://data/npcs/npcs.json")
	var data: Variant = JSON.parse_string(text)
	var list: Array = data["npcs"] if data is Dictionary and data.has("npcs") else (data if data is Array else [])
	check(list.size() >= 2, "data/npcs/npcs.json lists at least two NPCs (%d)" % list.size())
	var roster: Array = []
	var rows: Array = []
	var spawn: Vector3 = Vector3(53301.0, 29.9, 68427.0)
	var n: int = 0

	for entry in list:
		roster.append([str(entry.get("id", "npc%d" % n)), str(entry.get("name", "?")), str(entry.get("role", "")), str(entry.get("outfit", ""))])
		rows.append([str(entry.get("id", "npc%d" % n)), spawn + Vector3(3.0 * float(n), 0.0, 4.0), 0.0, n % 4])
		n += 1

	view.on_roster(roster)
	view.on_rows(rows)
	check(view.roster.size() == roster.size(), "roster kept (%d of %d)" % [view.roster.size(), roster.size()])
	check(view.drawn_count() == mini(rows.size(), view.MAX_DRAWN), "every listed NPC drawn: %d of %d" % [view.drawn_count(), rows.size()])
	var near: Dictionary = view.nearest(spawn, 20.0)
	check(not near.is_empty(), "an NPC is within 20 m of spawn")

	# Rows with no roster entry yet (the packet order is not guaranteed) must still draw, and a resend must not duplicate.
	view.on_rows(rows)
	check(view.drawn_count() == mini(rows.size(), view.MAX_DRAWN), "a resend keeps the same bodies: %d" % view.drawn_count())

	for state in range(4):
		var again: Array = []

		for row in rows:
			again.append([row[0], row[1], row[2], state])

		view.on_rows(again)

		for i in range(5):
			await process_frame

		check(view.drawn_count() > 0, "drawn after frames in state %d" % state)

	var fresh: Node3D = NpcViewScript.new()
	get_root().add_child(fresh)
	fresh.on_rows(rows)
	check(fresh.drawn_count() == mini(rows.size(), fresh.MAX_DRAWN), "rows before the roster still draw: %d" % fresh.drawn_count())

	print("test_npc_view: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
