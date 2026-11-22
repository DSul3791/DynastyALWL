extends SceneTree

# A character starts where they left (Dave 15 Nov 2026: "when a character quits a game their location should be saved and thats where they should start
# the next time they log in"): every way of leaving, across a server restart, with no time limit; a new character has no spot (world spawn); the spot is
# made safe when something was built over it; the reports a joining client still sends from the world spawn never overwrite it. docs/design/RESUME_SPOT.md.
#   godot --headless --path . --script res://src/worldgen/tools/test_resume_spot.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

const KEY := "resume-key-000001"
const SPOT := Vector3(300.0, 10.9, 300.0)

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, _t): pass
	items.setup(ItemTableScript.load_default(), dir)
	return items


# Saves, lets the background writer finish, and loads the store into a new server, as a restart does.
func restart(items, dir: String):
	items._dirty = true
	items.save()
	items._finish_writer()
	return make(dir)


func start_of(items, peer: int) -> Array:
	items.peer_connected_hello(peer, KEY)
	return items.start_position_for(peer)


func near(got: Array, want: Vector3, what: String) -> void:
	check(got.size() == 3 and Vector3(float(got[0]), float(got[1]), float(got[2])).distance_to(want) < 0.01, "%s (%s, want %s)" % [what, str(got), str(want)])


func add_struct(items, id: int, kind: String, pos: Vector3) -> void:
	items._items[id] = {"number": items.table.number_of(str(items._structures[kind]["item"])), "count": 1, "pos": pos, "left": 1.0e9, "struct": {"kind": kind, "yaw": 0.0, "uid": id}}
	items._grid_add(id, items._items[id])


func _init() -> void:
	var dir: String = "user://test_resume_spot"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)

	# A brand new character has no spot: the world spawn.
	check(start_of(items, 1).is_empty(), "a new character starts at the world spawn")

	# A dropped line (no logout), a day later and after a server restart: back at the spot.
	items.report_position(1, SPOT)
	items.peer_left(1)
	check(str(items._characters[KEY]["last"].get("left", "")) == "disconnect", "leaving without logout is a disconnect")
	check(items._event_save, "a disconnect brings the save forward (D-TODO-2)")
	items._characters[KEY]["last"]["t"] = int(Time.get_unix_time_from_system()) - 86400
	items = restart(items, dir)
	near(start_of(items, 2), SPOT, "a disconnect a day ago resumes at the spot after a restart (no 2-minute grace)")

	# The join gate: the client still reports from the world spawn before it moves; leaving then keeps the saved spot.
	items.report_position(2, Vector3(0.0, 30.0, 0.0))
	items.peer_left(2)
	near(items._characters[KEY]["last"]["pos"], SPOT, "reports from the world spawn before the client moved do not overwrite the spot")

	# A deliberate quit at a new spot, through a restart.
	var quit_at: Vector3 = SPOT + Vector3(40.0, 0.0, 0.0)
	near(start_of(items, 3), SPOT, "the spot again on the next join")
	items.report_position(3, SPOT + Vector3(1.0, 0.0, 0.0))   # the client is at the resume spot: the gate opens
	items.report_position(3, quit_at)
	items.note_logout(3)
	items._finish_writer()
	var on_disk: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "/characters.json"))
	check(on_disk is Dictionary and str(on_disk["players"][KEY]["last"]["left"]) == "deliberate" and absf(float(on_disk["players"][KEY]["last"]["pos"][0]) - quit_at.x) < 0.01, "Quit game writes the spot to disk at once, before the line closes")
	items.peer_left(3)
	check(str(items._characters[KEY]["last"].get("left", "")) == "deliberate", "Quit game is a deliberate logout")
	check(not items._event_save, "a deliberate logout saved at once: leaving asks for no second save")
	items = restart(items, dir)
	near(start_of(items, 4), quit_at, "a deliberate quit resumes where they quit after a restart")

	# The server closes with the player still in: the spot is where they stand now, not the last periodic note.
	items.report_position(4, quit_at + Vector3(0.5, 0.0, 0.0))
	var walked: Vector3 = quit_at + Vector3(5.0, 0.0, 0.0)
	items.report_position(4, walked)
	items.note_spots_on_close()
	items = restart(items, dir)
	near(start_of(items, 5), walked, "a server stop saves where the player stood")

	# Built over while away: a foundation lifts them onto its top; a wall moves them out of it.
	var base_kind: String = "foundation_section"
	var base_y: float = walked.y - 0.9
	add_struct(items, 9001, base_kind, Vector3(walked.x, base_y, walked.z))
	var top: float = base_y + float(items._structures[base_kind].get("top_m", 0.3))
	near(items.start_position_for(5), Vector3(walked.x, top + 0.9, walked.z), "a foundation laid over the spot: on its top")
	items._items.erase(9001)
	add_struct(items, 9002, "wall_section", walked)
	var out: Array = items.start_position_for(5)
	check(out.size() == 3 and not items.structure_blocks(float(out[0]), float(out[2]), items.RESUME_CLEAR_M), "a wall built over the spot: the start is clear of it (%s)" % str(out))
	check(out.size() == 3 and Vector2(float(out[0]) - walked.x, float(out[2]) - walked.z).length() <= items.RESUME_SEARCH_M, "and close by")
	check(not items.structure_blocks(walked.x + 0.8, walked.z + 0.6, items.RESUME_CLEAR_M), "standing against a wall is not inside it")
	items._items.erase(9002)

	# A rejoin before the old connection timed out: the stale one leaving later never writes its old spot over the live one's.
	items.peer_left(5)   # the earlier connection leaves first
	var s7: Array = start_of(items, 7)
	var base7: Vector3 = Vector3(float(s7[0]), float(s7[1]), float(s7[2]))
	items.report_position(7, base7 + Vector3(0.5, 0.0, 0.0))
	items.report_position(7, base7 + Vector3(10.0, 0.0, 0.0))   # where the old connection was last heard from
	var s8: Array = start_of(items, 8)   # the same character back on a new connection
	items.report_position(8, Vector3(float(s8[0]), float(s8[1]), float(s8[2])) + Vector3(0.5, 0.0, 0.0))
	items.report_position(8, base7 + Vector3(20.0, 0.0, 0.0))
	items.peer_left(7)   # the old connection times out now
	var after_stale: Array = items._characters[KEY].get("last", {}).get("pos", [])
	check(after_stale.size() != 3 or absf(float(after_stale[0]) - (base7.x + 10.0)) > 0.01, "a stale connection leaving does not save its old spot (%s)" % str(after_stale))
	items.peer_left(8)
	near(items._characters[KEY]["last"]["pos"], base7 + Vector3(20.0, 0.0, 0.0), "the live connection leaving saves where it is")

	# A malformed saved spot is not a spot.
	check(items._clean_last({"pos": [1.0, NAN, 2.0]}).is_empty() and items._clean_last({"pos": ["a", 1, 2]}).is_empty() and items._clean_last([]).is_empty(), "a broken saved spot is dropped at load")
	check(items._clean_rests([[1, 2, 3, "fire"], [1, 2, "x", "fire"], [1, 2, 3, "bad"]]).size() == 1, "rest points are read back, broken ones dropped")

	items._finish_writer()   # the background save thread must finish before quit
	print("resume spot tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)
