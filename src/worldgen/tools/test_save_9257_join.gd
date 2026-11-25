extends SceneTree

# Wednesday's update from the players' side (coordinator, 23 Nov 2026): a character saved by build 9257 (the live server's world,
# save_fixtures/build_9257) joins today's server at its saved spot with its own pack and worn pieces on the first try, again the same after
# a rejoin, and two of them on at once see each other (server_players rows). test_save_9257 checks the store reads the same; this checks
# the join.
#   godot --headless --path . --script res://src/worldgen/tools/test_save_9257_join.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const PlayersScript := preload("res://src/stream/server_players.gd")

const FIXTURE := "res://src/worldgen/tools/save_fixtures/build_9257"
const DIR := "user://test_save_9257_join"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _copy_fixture() -> void:
	for sub in ["", "/" + ItemsScript.AREA_DIR]:
		DirAccess.make_dir_recursive_absolute(DIR + sub)

		for file in DirAccess.get_files_at(DIR + sub):
			DirAccess.remove_absolute(DIR + sub + "/" + file)

	for sub in ["", "/world_items"]:
		for file in DirAccess.get_files_at(FIXTURE + sub):
			if file.ends_with(".json") and file != "expected_snapshot.json":
				var to: String = DIR + ("/" + ItemsScript.AREA_DIR if sub != "" else "") + "/" + file
				var f: FileAccess = FileAccess.open(to, FileAccess.WRITE)
				f.store_string(FileAccess.get_file_as_string(FIXTURE + sub + "/" + file))
				f.close()


func _slots(table, inv) -> Array:
	var out: Array = []

	if inv == null:
		return out

	for s in inv.slot_count:
		if inv.numbers[s] != 0:
			out.append("%s x%d w%d" % [table.id_of(inv.numbers[s]) if table.id_of(inv.numbers[s]) != "" else "#%d" % inv.numbers[s], inv.counts[s], inv.wear[s]])

	out.sort()
	return out


func _init() -> void:
	_copy_fixture()
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE + "/expected_snapshot.json"))
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 6.0
	items.setup(ItemTableScript.load_default(), DIR)
	var table = items.table
	# fixture9257a01 is the big hand-made character (107 stacks, worn pieces) but was never on a 9257 server, so it has no saved spot and
	# starts as a new character would; loadbot_bot1 was really played on 9257 and left with a saved spot (characters.json "last").
	var stored: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE + "/characters.json"))["players"]
	var keys: Array = ["fixture9257a01", "loadbot_bot1"]
	var peer: int = 700

	# First join, then a rejoin on a new connection: the saved spot and the same pack both times.
	for key in keys:
		var saved_9257: Array = (stored[key] as Dictionary).get("last", {}).get("pos", [])
		var saved: Array = saved_9257 if saved_9257.size() == 3 else (expected["characters"][key] as Dictionary).get("last", [])
		var pack_then: Array = (expected["packs"] as Dictionary).get(key, [])

		for attempt in ["first join", "rejoin"]:
			peer += 1
			items.peer_connected_hello(peer, key)
			var start: Array = items.start_position_for(peer)
			var at: Vector3 = Vector3(float(start[0]), float(start[1]), float(start[2])) if start.size() == 3 else Vector3.INF
			var spot: Vector3 = Vector3(float(saved[0]), float(saved[1]), float(saved[2])) if saved.size() == 3 else Vector3.ZERO
			if attempt == "first join" and saved_9257.size() != 3:
				check(start.is_empty(), "%s, first join: no saved spot in the 9257 store, so it starts as a new character (%s)" % [key, str(start)])
			else:
				check(saved.size() == 3 and at.distance_to(spot) < 8.0, "%s, %s: starts at its saved spot (%s, saved %s)" % [key, attempt, str(at), str(spot)])

			items.report_position(peer, at if at.is_finite() else Vector3(58167.0, 6.0, 71364.0))
			items.tick(0.25)
			var pack_now: Array = _slots(table, items.inventory_of(peer))
			check(pack_now == pack_then, "%s, %s: its pack is the one it had (%d stacks, %d then)" % [key, attempt, pack_now.size(), pack_then.size()])

			var worn_now: Array = []

			for w in (items._characters[key] as Dictionary).get("worn", []):
				if int(w[0]) != 0:
					var inst: Variant = w[3] if w.size() > 3 else {}
					worn_now.append("%s w%d %s" % [table.id_of(int(w[0])), int(w[2]), str([str(inst["bag"]).length()] if inst is Dictionary and inst.has("bag") else [])])

			var worn_then: Array = (expected["worn"] as Dictionary).get(key, [])
			check(worn_now == worn_then, "%s, %s: still wears what it wore (%s)" % [key, attempt, ", ".join(worn_now) if not worn_now.is_empty() else "nothing"])

			if attempt == "first join":
				items.peer_left(peer)

	# The two on at once (the last two connections above): each is in the other's players rows.
	var players = PlayersScript.new()
	var clock: Array = [1000]
	var sent: Array = []
	players.items = items
	players.now_ms = func() -> int: return int(clock[0])
	players.send_rows = func(to, ids, _positions, _yaws, _states, _held, _times, _left, _more, _cast): sent.append([to, ids])
	players.send_flight = func(_p, _n, _f, _v, _b): pass
	players.send_look = func(_to, _about, _n, _b, _c, _w): pass
	var a: int = peer - 2
	var b: int = peer
	players.set_look(a, "Ann", "body_1", "")
	players.set_look(b, "Bob", "body_2", "")

	for i in range(5):
		clock[0] += 200
		players.note_report(a, 0.0)
		players.note_report(b, 0.0)
		players.tick(0.2)

	var a_sees_b: bool = sent.any(func(r): return int(r[0]) == a and (r[1] as PackedInt32Array).has(b))
	var b_sees_a: bool = sent.any(func(r): return int(r[0]) == b and (r[1] as PackedInt32Array).has(a))
	check(a_sees_b and b_sees_a, "two 9257 characters on at once see each other (A sees B %s, B sees A %s)" % [str(a_sees_b), str(b_sees_a)])
	print("test_save_9257_join: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
