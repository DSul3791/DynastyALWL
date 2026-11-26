extends SceneTree

# The full world sync by change (SERVER_SCALE.md item 4, server_items _sync_world_items). Each player is sent exactly what is within NEAR_M
# of them, as before, while a cell wholly near them that did not change is skipped whole. A seeded random world of records over hills,
# players walking and jumping about, records counted down, moved, taken and made, and a fresh start: after every sync each player's copy
# holds exactly the records within NEAR_M (worked out here the slow way), at their current counts. Then the cost at the rocks thread's
# size (15,000 records, 32 players): how many records a still world's sync looks at, against the nine NEAR_M cells each player looked at
# before. Prints the times too (no limit on them: lanes differ).
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

			if int(copy[id][2]) != int(items._items[id]["count"]):
				ok = false
				print("  %s: player %d has record %d at count %d, it is %d" % [what, peer, id, int(copy[id][2]), int(items._items[id]["count"])])
				break

		for id in copy:
			if not want.has(id):
				ok = false
				print("  %s: player %d still has record %d, %.1f m away" % [what, peer, id, (items._items[id]["pos"] as Vector3).distance_to(items._peer_pos[peer]) if items._items.has(id) else -1.0])
				break

	return ok


func ground_y(x: float, z: float) -> float:
	return 40.0 * sin(x / 90.0) * cos(z / 70.0) + 25.0   # hills: up to 80 m between records near one player


func scatter(items, rng: RandomNumberGenerator, n: int, size: float, stone: int) -> void:
	for i in n:
		var x: float = rng.randf_range(0.0, size)
		var z: float = rng.randf_range(0.0, size)

		if i % 3 == 0:
			items._items[items._next_id] = {"number": 0, "count": 4, "pos": Vector3(x, ground_y(x, z), z), "left": 1.0e9, "scatter": "rock", "boulder": {"r": 0.8}}
		else:
			items._items[items._next_id] = {"number": stone, "count": 1 + i % 5, "pos": Vector3(x, ground_y(x, z), z), "left": 1.0e9}

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

	# The cost at the rocks thread's size: 15,334 records over 928 ground cells (about 2 km square), 32 players.
	var big = make("user://test_sync_by_change_big")
	copies = {}
	scatter(big, rng, 15334, 2000.0, stone)

	for peer in range(100, 132):
		join(big, peer, Vector3(rng.randf_range(0.0, 2000.0), 0.0, rng.randf_range(0.0, 2000.0)))
		big._peer_pos[peer].y = ground_y(big._peer_pos[peer].x, big._peer_pos[peer].z) + 1.7

	var t0: int = Time.get_ticks_usec()
	big._sync_world_items()
	var first_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	check(agrees(big, "big first"), "the big world's first sync is right")
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
	print("sync by change: 15334 records, 32 players: first sync %.1f ms; walking %.1f ms median, %.1f worst; looked at %d records one by one (the old sync %d); %s" % [first_ms, times[2], times[4], looked, old_looked, detail])

	print("test_sync_by_change: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
