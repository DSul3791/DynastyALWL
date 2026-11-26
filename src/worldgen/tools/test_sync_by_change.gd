extends SceneTree

# The full world sync by change (SERVER_SCALE.md item 4, server_items _sync_world_items). Each player is sent exactly what is within NEAR_M
# of them, as before, while a cell wholly near them that did not change is skipped whole. A seeded random world of records over hills,
# players walking and jumping about, records counted down, moved, taken and made, and a fresh start: after every sync each player's copy
# holds exactly the records within NEAR_M (worked out here the slow way), at their current counts. Then the cost at the rocks thread's
# size (15,000 records, 32 players): how many records a still world's sync looks at, against the nine NEAR_M cells each player looked at
# before. The rocks (scatter records) stay filed between syncs; one moved without _refile is found by the still check. Prints the times too
# (no limit on them: lanes differ).
#   godot --headless --path . --script res://src/worldgen/tools/test_sync_by_change.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0
var copies: Dictionary = {}   # peer -> {id: row} what that player's game holds
var bad_removes: int = 0
var sends: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func make(dir: String):
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(p, added, removed):
		sends += 1
		var copy: Dictionary = copies.get(p, {})
		copies[p] = copy

		for id in removed:
			if not copy.has(id):
				bad_removes += 1

			copy.erase(id)

		for row in added:
			copy[int(row[0])] = row
	items.setup(ItemTableScript.load_default(), dir)
	return items


func join(items, peer: int, at: Vector3) -> void:
	items._known[peer] = {}
	items._peer_pos[peer] = at
	copies[peer] = {}


# Every player's copy against the records within NEAR_M of them, worked out record by record.
func agrees(items, what: String) -> bool:
	var ok: bool = true

	for peer in items._known:
		var want: Dictionary = {}

		for id in items._items:
			if (items._items[id]["pos"] as Vector3).distance_to(items._peer_pos[peer]) <= items.NEAR_M:
				want[id] = true

		var copy: Dictionary = copies.get(peer, {})

		for id in want:
			if not copy.has(id):
				ok = false
				print("  %s: player %d lacks record %d" % [what, peer, id])
				break

			if absf((copy[id][3] as Vector3).y - (items._items[id]["pos"] as Vector3).y) > 0.06:
				ok = false
				print("  %s: player %d has record %d at height %.2f, it is %.2f" % [what, peer, id, (copy[id][3] as Vector3).y, (items._items[id]["pos"] as Vector3).y])
				break

			if int(copy[id][2]) != int(items._items[id]["count"]):
				ok = false
				print("  %s: player %d has record %d at count %d, it is %d" % [what, peer, id, int(copy[id][2]), int(items._items[id]["count"])])
				break

		if (items._known[peer] as Dictionary).size() != copy.size():
			ok = false
			print("  %s: player %d: the server thinks they hold %d records, they hold %d" % [what, peer, (items._known[peer] as Dictionary).size(), copy.size()])

		for id in copy:
			if not want.has(id):
				ok = false
				print("  %s: player %d still has record %d, %.1f m away" % [what, peer, id, (items._items[id]["pos"] as Vector3).distance_to(items._peer_pos[peer]) if items._items.has(id) else -1.0])
				break

	return ok


func ground_y(x: float, z: float) -> float:
	return 40.0 * sin(x / 90.0) * cos(z / 70.0) + 25.0   # hills: up to 80 m between records near one player


# `natural`: the loose stones are laid out from the seed too (a "scatter" key), as the rock fields lay theirs.
func scatter(items, rng: RandomNumberGenerator, n: int, size: float, stone: int, natural: bool = false) -> void:
	for i in n:
		var x: float = rng.randf_range(0.0, size)
		var z: float = rng.randf_range(0.0, size)

		if i % 4 == 0:   # a quarter rocks: the small world's 750 or so are all checked each sync (STILL_CHECK)
			items._items[items._next_id] = {"number": 0, "count": 4, "pos": Vector3(x, ground_y(x, z), z), "left": 1.0e9, "scatter": "rock", "boulder": {"r": 0.8}}
		else:
			items._items[items._next_id] = {"number": stone, "count": 1 + i % 5, "pos": Vector3(x, ground_y(x, z), z), "left": 1.0e9}

			if natural:
				items._items[items._next_id]["scatter"] = "stones"

		items._next_id += 1


func _initialize() -> void:
	var items = make("user://test_sync_by_change")
	var stone: int = items.table.number_of("stone")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1126
	var size: float = 600.0
	scatter(items, rng, 3000, size, stone)

	for peer in range(10, 16):
		join(items, peer, Vector3(rng.randf_range(0.0, size), 0.0, rng.randf_range(0.0, size)))
		items._peer_pos[peer].y = ground_y(items._peer_pos[peer].x, items._peer_pos[peer].z) + 1.7

	items._sync_world_items()
	check(agrees(items, "first sync"), "the first sync sends each player exactly what is within NEAR_M")
	var before: int = sends
	items._sync_world_items()
	check(sends == before and agrees(items, "still"), "nothing changed, nobody moved: nothing is sent (%d sends)" % (sends - before))
	check(str(items._sync_detail).contains("cells skipped") and not str(items._sync_detail).contains(" 0 cells skipped"), "a still world's sync skips cells whole (%s)" % items._sync_detail)
	var all_ok: bool = true

	for step in 60:
		for peer in items._known:
			var at: Vector3 = items._peer_pos[peer]

			if rng.randf() < 0.1:
				at = Vector3(rng.randf_range(0.0, size), 0.0, rng.randf_range(0.0, size))   # a jump: a respawn, a ride
			elif rng.randf() < 0.6:
				at += Vector3(rng.randf_range(-9.0, 9.0), 0.0, rng.randf_range(-9.0, 9.0))   # a second's run

			at.y = ground_y(at.x, at.z) + 1.7 + (30.0 if rng.randf() < 0.05 else 0.0)   # now and then up a cliff
			items._peer_pos[peer] = at

		var ids: Array = items._items.keys()

		for k in 25:
			var id: int = int(ids[rng.randi() % ids.size()])

			if not items._items.has(id):
				continue

			var roll: float = rng.randf()

			if roll < 0.4:
				items._items[id]["count"] = maxi(int(items._items[id]["count"]) - 1, 1) if int(items._items[id]["count"]) > 1 else 3   # a stone taken from a heap
			elif roll < 0.6:
				var p: Vector3 = items._items[id]["pos"]
				p += Vector3(rng.randf_range(-30.0, 30.0), 0.0, rng.randf_range(-30.0, 30.0))   # carried off
				p.y = ground_y(p.x, p.z)
				items._items[id]["pos"] = p

				if rng.randf() < 0.5:
					items._refile(id)   # as the server's own moves do; the other half are left for the still check to find
			elif roll < 0.8:
				items._items.erase(id)   # taken
			else:
				scatter(items, rng, 1, size, stone)   # dropped

		if step == 30:
			items._known[13] = {}   # a fresh start: the player's list begins again
			copies[13] = {}

		if step == 40:
			join(items, 99, items._peer_pos[11])   # someone joins where another stands

		if step == 45:
			items._known.erase(12)   # someone leaves
			items._peer_pos.erase(12)
			copies.erase(12)

		items._sync_world_items()

		if not agrees(items, "step %d" % step):
			all_ok = false
			break

	check(all_ok, "60 seconds of walking, jumping, counting down, carrying, taking and dropping: every copy right after every sync")
	check(bad_removes == 0, "nothing is taken away that a player was never sent (%d)" % bad_removes)
	check(not items._sync_seen.has(12), "a player who left is forgotten")
	var sig_wrong: int = 0
	var sig_seen: int = 0
	items._items[items._next_id] = {"number": stone, "count": 7, "pos": Vector3(10.0, -3.27, 10.0), "left": 1.0e9, "rot_y": 1.2, "girth": 0.3}   # below sea level, turned
	items._next_id += 1

	for id in items._items:
		var it: Dictionary = items._items[id]

		if not it.has("struct") and not it.has("fire") and not it.has("tree"):
			sig_seen += 1

			if items._plain_sig(it) != int(items._sync_record(int(id), it)[1]):
				sig_wrong += 1

	check(sig_seen > 1000 and sig_wrong == 0, "the loose and rock records' quick signature is _sync_record's, for all %d (%d differ)" % [sig_seen, sig_wrong])
	check(items._still_moved > 0, "still records moved without _refile are found by the check and filed where they are (%d)" % items._still_moved)
	var filed_ok: bool = true

	for id in items._items:
		if items._items[id].has("scatter") != items._still_at.has(id):
			filed_ok = false

	for id in items._still_at:
		if not items._items.has(id):
			filed_ok = false   # the small world's 1,000 or so still records are all checked each sync

	check(filed_ok, "every rock is filed as still, and nothing taken stays filed")

	# A road's quick sync: a record made between full syncs goes out at once, and the full sync after it sends nothing again.
	var here: Vector3 = items._peer_pos[10]
	var road: int = items._next_id
	items._items[road] = {"number": stone, "count": 2, "pos": here + Vector3(3.0, 0.0, 3.0), "left": 1.0e9}
	items._next_id += 1
	items._sync_world_items([road], [here])
	check((copies[10] as Dictionary).has(road), "a quick sync sends the new record to the player beside it")
	items._sync_world_items()
	check(agrees(items, "after the quick sync"), "the full sync after it agrees")
	items._items.erase(road)
	items._sync_world_items([road], [here])
	check(not (copies[10] as Dictionary).has(road), "a quick sync takes away a record gone from the world")
	items._sync_world_items()
	check(agrees(items, "after the quick removal") and bad_removes == 0, "and the full sync after that neither sends it nor takes it away twice (%d)" % bad_removes)

	# A quick sync of a record already sent, then the record back as it was before the next full sync: its cell is looked at again, not
	# skipped on its old sum (early review 26 Nov: the player would keep the quick sync's row).
	var heap: int = -1

	for id in items._items:
		if (items._items[id]["pos"] as Vector3).distance_to(here) < 40.0 and int(items._items[id]["number"]) == stone:
			heap = int(id)
			break

	check(heap >= 0, "a stone heap near player 10")

	if heap >= 0:
		var was: int = int(items._items[heap]["count"])
		items._items[heap]["count"] = was + 1
		items._sync_world_items([heap], [here])
		check(int(copies[10][heap][2]) == was + 1, "the quick sync sends the heap's new count")
		items._items[heap]["count"] = was
		items._sync_world_items()
		check(agrees(items, "after the revert") and int(copies[10][heap][2]) == was, "back as it was before the full sync: the full sync sends the old count again")

	# The cost at the rocks thread's size: 15,334 records over 928 ground cells (about 2 km square), 32 players.
	var big = make("user://test_sync_by_change_big")
	copies = {}
	scatter(big, rng, 13236, 2000.0, stone, true)   # the rocks thread's 8,771 rocks and 4,465 loose stones, near enough
	scatter(big, rng, 2098, 2000.0, stone)          # and the 2,098 other records

	for peer in range(100, 132):
		join(big, peer, Vector3(rng.randf_range(0.0, 2000.0), 0.0, rng.randf_range(0.0, 2000.0)))
		big._peer_pos[peer].y = ground_y(big._peer_pos[peer].x, big._peer_pos[peer].z) + 1.7

	var t0: int = Time.get_ticks_usec()
	big._sync_world_items()
	var first_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	check(agrees(big, "big first"), "the big world's first sync is right")
	check(big._still_at.size() >= 13236 and str(big._sync_detail).contains("%d still" % big._still_at.size()), "the big world's rocks are filed once and kept (%s)" % big._sync_detail)
	var old_looked: int = 0   # what the sync before this looked at: every record in the nine NEAR_M cells round each player

	for peer in big._known:
		var home: Vector2i = Vector2i(int(floor(big._peer_pos[peer].x / big.NEAR_M)), int(floor(big._peer_pos[peer].z / big.NEAR_M)))

		for dx in range(-1, 2):
			for dz in range(-1, 2):
				old_looked += (big._sync_grid.get(Vector2i(home.x + dx, home.y + dz), []) as Array).size()

	var times: Array = []

	for k in 5:
		for peer in big._known:
			big._peer_pos[peer] += Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0))   # walking

		t0 = Time.get_ticks_usec()
		big._sync_world_items()
		times.append(float(Time.get_ticks_usec() - t0) / 1000.0)

	var detail: String = str(big._sync_detail)
	var looked: int = int(detail.get_slice("(", 2).get_slice(" looked at", 0))
	check(agrees(big, "big walking"), "the big world agrees after five seconds of walking")
	check(looked * 3 < old_looked, "a walking world's sync looks at under a third of the records the old one did: %d of %d" % [looked, old_looked])
	times.sort()

	# At this size the still check takes about 14 syncs to go round. 50 rocks taken and 50 moved without _refile: a taken rock is never sent
	# again, and once the check has been round, every copy is right again.
	var rocks: Array = big._still_at.keys()
	var taken: Dictionary = {}

	for k in 50:
		taken[int(rocks[rocks.size() - 1 - k])] = true   # the last filed: the check may have just passed them, the worst case
		big._items.erase(int(rocks[rocks.size() - 1 - k]))

	for k in range(50, 100):
		var rock: int = int(rocks[rocks.size() - 1 - k])
		var p: Vector3 = big._items[rock]["pos"] + Vector3(35.0, 0.0, -35.0)
		p.y = ground_y(p.x, p.z)
		big._items[rock]["pos"] = p   # no _refile

	var resent: int = 0
	var rounds: int = 2 * int(ceil(float(big._still_at.size()) / float(big.STILL_CHECK))) + 1   # at worst a whole round, then the next

	for k in rounds:
		big._sync_world_items()

		for peer in copies:
			for id in taken:
				if (copies[peer] as Dictionary).has(id):
					resent += 1

	check(resent == 0, "a taken rock is never held by a player after the sync that follows (%d)" % resent)
	check(agrees(big, "big after the check went round"), "after %d syncs the still check has filed every moved rock where it is" % rounds)
	var stale: int = 0

	for id in big._still_at:
		if not big._items.has(id):
			stale += 1

	check(stale == 0, "and nothing taken is still filed (%d)" % stale)

	# A load or a reset files everything again: records put in with any ids (a load's own), then the next full sync.
	var old_id: int = int(rocks[rocks.size() - 1])   # an id taken above: a load can bring back any id below _next_id
	big._items[old_id] = {"number": stone, "count": 2, "pos": big._peer_pos[100] + Vector3(2.0, 0.0, 2.0), "left": 1.0e9, "scatter": "stones"}
	big._still_valid = false   # as _load_world_items and reset_world do
	big._sync_world_items()
	check(big._still_at.has(old_id) and agrees(big, "after a load"), "a record loaded under an old id is filed and sent after the load")
	var code: String = FileAccess.get_file_as_string("res://src/stream/server_items.gd")
	var hand: int = big._next_id + 500   # a record put in by hand, with no id from _next_id (test_far_smoke does this)
	big._items[hand] = {"number": stone, "count": 1, "pos": big._peer_pos[101] + Vector3(1.0, 0.0, 1.0), "left": 1.0e9}
	big._sync_world_items()
	check(big._rest.has(hand) and (copies[101] as Dictionary).has(hand), "a record put in by hand under any id is filed and sent at the next sync")
	check(code.contains("	_sync_grid = {}\n	_still_valid = false") and code.contains("_next_id = int(parsed.get(\"next_id\", 1))\n	_still_valid = false"), "reset_world and the world load both file everything again")
	print("sync by change: 15334 records, 32 players: first sync %.1f ms; walking %.1f ms median, %.1f worst; looked at %d records one by one (the old sync %d); %s" % [first_ms, times[2], times[4], looked, old_looked, detail])

	print("test_sync_by_change: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
