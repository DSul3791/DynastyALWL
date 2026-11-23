extends SceneTree

# Two players see the same world (coordinator, 23 Nov 2026): whatever one player does to the world, a second player beside them and a
# third who walks in later are sent the same rows (server_items.gd _sync_world_items). The world sync sends a record again only when its
# signature (_sync_record) moves, so a change the signature misses leaves the players who were there on the old row while a newcomer gets
# the new one. This test builds a small busy world (fires, chests, every placeable kit, crops, loose items, doors), lets game time pass,
# and after each step checks that the rows the watchers last got equal what a newcomer gets now.
#   godot --headless --path . --script res://src/worldgen/tools/test_same_world.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const GameClockScript := preload("res://src/shared/game_clock.gd")

const PER_PLAYER := ["site", "bellows"]   # row extras that are each player's own by design (their own list of what a site needs; who works the bellows)
const HERE := Vector3(0.0, 10.0, 0.0)

var failures: int = 0
var seen: Dictionary = {}        # peer -> {world id: the last row sent}
var clock: Array = [100.0 * 86400.0 + 8.0 * 3600.0]   # game_clock.gd START_SECONDS
var _newcomer: int = 100


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)
	else:
		print("ok   ", what)


func _init() -> void:
	# The server's clock follows real time, so a freeze does not leave it behind the clients' (which follow their own tick counter).
	var server_clock = GameClockScript.new()
	var start: float = server_clock.seconds
	server_clock.follow(5000000)
	server_clock.follow(5016000)     # a normal frame
	server_clock.follow(8016000)     # a 3 s freeze: Godot's delta for that frame would be about 0.13 s
	check(is_equal_approx(server_clock.seconds - start, 3.016 * GameClockScript.RATIO), "the server's game clock keeps real time through a 3 s freeze (%.2f game s, want %.2f)" % [server_clock.seconds - start, 3.016 * GameClockScript.RATIO])
	check(FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd").contains("game_clock.follow(Time.get_ticks_usec())"), "the server moves its clock by follow (real time), not by the frame's delta")
	var client_clock = GameClockScript.new()
	client_clock.sync(server_clock.seconds)
	check(is_equal_approx(client_clock.seconds, server_clock.seconds), "a client takes the server's clock at the welcome")

	var dir: String = "user://test_same_world"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(p, added, removed): _note(p, added, removed)
	items.setup(ItemTableScript.load_default(), dir)
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return clock[0]
	items.peer_connected_hello(1, "sameworld0001")
	items.peer_connected_hello(2, "sameworld0002")
	items.report_position(1, HERE)
	items.report_position(2, HERE)   # the three players stand together, so the edge of the sync reach (NEAR_M) is the same for all
	var t = items.table

	# Every kit that places on its own (as a free build), in a grid round the players.
	var kits: Array = []

	for kit_id in items._blueprint_of_kit:
		kits.append(str(kit_id))

	kits.sort()
	var spot: int = 0

	for kit_id in kits:
		var at: Vector3 = HERE + Vector3(-60.0 + float(spot % 20) * 6.0, 0.0, -60.0 + floor(float(spot) / 20.0) * 6.0)
		spot += 1
		items.report_position(1, at + Vector3(0.0, 0.0, 2.0))
		items.place_piece(1, kit_id, at)

	items.report_position(1, HERE)
	check(items.world_item_count() > 100, "the kits placed %d records from %d kits" % [items.world_item_count(), kits.size()])
	_settle(items)
	_compare(items, "the placed pieces")

	# A campfire laid, lit, fed; loose items dropped and some picked up.
	items.action(1, Net.ACT_ADMIN_GIVE, t.number_of("campfire_kit"), 0, 1, Vector3.ZERO)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(t.number_of("campfire_kit")), 0, 0, HERE + Vector3(3.0, 0.0, 3.0))
	var fire: int = _find(items, func(it): return it.has("fire") and (it["pos"] as Vector3).distance_to(HERE + Vector3(3.0, 0.0, 3.0)) < 0.5)
	check(fire > 0, "a campfire is laid")
	items.action(1, Net.ACT_ADMIN_GIVE, t.number_of("plant_fibre"), 0, 5, Vector3.ZERO)
	items.action(1, Net.ACT_ADMIN_GIVE, t.number_of("stick"), 0, 10, Vector3.ZERO)
	items.action(1, Net.ACT_LIGHT, fire, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_FUEL, fire, 0, 0, Vector3.ZERO)
	items.drop_in_world(t.number_of("stone"), 4, HERE + Vector3(1.0, 0.0, -1.0))
	items.drop_in_world(t.number_of("stick"), 3, HERE + Vector3(-1.0, 0.0, -1.0))
	_settle(items)
	_compare(items, "a fire lit and fed, loose items dropped")

	var stones: int = _find(items, func(it): return int(it["number"]) == t.number_of("stone") and not it.has("struct"))
	items.action(2, Net.ACT_PICKUP, stones, 0, 0, Vector3.ZERO)
	_settle(items)
	_compare(items, "the second player picks up the stones")

	# A chest's contents (a container's look follows its fill for stores and bins) and every station with a store.
	for id in items._items.keys():
		var it: Dictionary = items._items[id]

		if it.has("struct") and it["struct"].has("uid") and items._chests.has(int(it["struct"]["uid"])):
			items._chests[int(it["struct"]["uid"])].add(t.number_of("stone"), 5)

	_settle(items)
	_compare(items, "something put in every container")

	# Doors and sluices: E turns them into their other kind.
	for id in items._items.keys():
		var it: Dictionary = items._items[id]

		if it.has("struct") and str(items._structures.get(str(it["struct"]["kind"]), {}).get("use", "")) == "door":
			items.report_position(1, it["pos"] + Vector3(1.0, 0.0, 0.0))
			items.action(1, Net.ACT_USE_STRUCT, int(id), 0, 0, Vector3.ZERO)

	items.report_position(1, HERE)
	_settle(items)
	_compare(items, "the doors opened")

	# Game time passes: fires burn down to coals and ash, crops grow, rot and decay run.
	for step in range(12):
		clock[0] += 3600.0
		_settle(items, 3.0)

	_compare(items, "twelve game hours later")

	_check_taken()
	_check_taken_drawn()
	print("test_same_world: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _note(peer: int, added: Array, removed: PackedInt32Array) -> void:
	var mine: Dictionary = seen.get(peer, {})

	for row in added:
		mine[int(row[0])] = row

	for id in removed:
		mine.erase(int(id))

	seen[peer] = mine


func _settle(items, seconds: float = 1.2) -> void:
	var left: float = seconds

	while left > 0.0:
		items.tick(0.25)
		left -= 0.25


# A newcomer walks in now: what it gets must be what the two watchers hold.
func _compare(items, what: String) -> void:
	_newcomer += 1
	items.peer_connected_hello(_newcomer, "sameworld%04d" % _newcomer)
	items.report_position(_newcomer, HERE)
	_settle(items, 1.2)
	var fresh: Dictionary = seen.get(_newcomer, {})
	check(fresh.size() > 100, "%s: the newcomer is sent the world (%d rows)" % [what, fresh.size()])

	for watcher in [1, 2]:
		var old: Dictionary = seen.get(watcher, {})
		var diffs: Array = []

		for id in fresh:
			if not old.has(id):
				diffs.append("%d %s: missing %s" % [id, _name(items, id), str(items._items.get(id, {}))])
			elif _plain(old[id]) != _plain(fresh[id]):
				diffs.append("%d %s: %s, newcomer %s" % [id, _name(items, id), str(_plain(old[id])), str(_plain(fresh[id]))])

		for id in old:
			if not fresh.has(id) and items._items.has(id) and (items._items[id]["pos"] as Vector3).distance_to(HERE) < 100.0:
				diffs.append("%d %s: kept, the newcomer never got it" % [id, _name(items, id)])

		check(diffs.is_empty(), "%s: player %d holds what a newcomer gets (%d rows; %d differ%s)" % [what, watcher, fresh.size(), diffs.size(), (": " + "; ".join(PackedStringArray(diffs.slice(0, 6)))) if not diffs.is_empty() else ""])

	items.peer_left(_newcomer)
	seen.erase(_newcomer)


func _plain(row: Array) -> Array:
	var out: Array = row.duplicate(true)

	if out.size() > 5 and out[5] is Dictionary:
		var extra: Dictionary = out[5]

		for key in PER_PLAYER:
			extra.erase(key)

		if extra.has("age"):
			extra["age"] = int(float(extra["age"]))   # remains' age in whole units (the row itself rounds it)

	return out


func _name(items, id: int) -> String:
	var it: Dictionary = items._items.get(id, {})

	if it.is_empty():
		return "(gone)"

	return str(it["struct"]["kind"]) if it.has("struct") else items.table.id_of(int(it["number"]))


func _find(items, test: Callable) -> int:
	for id in items._items:
		if test.call(items._items[id]):
			return int(id)

	return 0


# Protocol 160: a dead branch, a tide-line node and a bird nest taken by one player are gone for the others and for a newcomer.
func _check_taken() -> void:
	var dir: String = "user://test_same_world_taken"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	var told: Array = []
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_taken = func(peer, kind, points, days): told.append([peer, kind, points, days])
	items.setup(ItemTableScript.load_default(), dir)
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return clock[0]
	items.gather_pace_ms = 0
	items.nests_near = func(at, reach): return [{"id": "n1", "kind": "songbird", "pos": Vector3(1.0, 10.0, 1.0)}] if Vector2(at.x - 1.0, at.z - 1.0).length() <= reach else []
	var stick: int = items.table.number_of("stick")
	items.peer_connected_hello(1, "takenworld001")
	items.peer_connected_hello(2, "takenworld002")
	items.report_position(1, HERE)
	items.report_position(2, HERE)
	told.clear()
	var branch: Vector3 = HERE + Vector3(0.8, 0.0, 0.4)
	items.action(1, Net.ACT_LITTER, 0, 0, 0, branch)
	check(items.inventory_of(1).count_of(stick) == 1, "the first player picks the dead branch: one stick")
	var to_two: Array = told.filter(func(t): return int(t[0]) == 2 and int(t[1]) == ItemsScript.TAKEN_BRANCH)
	check(to_two.size() == 1 and (to_two[0][2] as PackedVector3Array)[0].distance_to(branch) < 0.001, "the second player is told that branch is gone (its client hides it)")
	items.action(2, Net.ACT_LITTER, 0, 0, 0, branch + Vector3(0.1, 0.0, 0.0))
	check(items.inventory_of(2).count_of(stick) == 0, "the second player gets no stick for the same branch")
	items.action(2, Net.ACT_LITTER, 0, 0, 0, branch + Vector3(1.0, 0.0, 0.0))
	check(items.inventory_of(2).count_of(stick) == 1, "another branch a metre off is the second player's")
	told.clear()
	items.peer_connected_hello(3, "takenworld003")
	items.report_position(3, HERE)
	var to_three: Dictionary = {}

	for t in told:
		if int(t[0]) == 3:
			to_three[int(t[1])] = t[2]

	check(to_three.has(ItemsScript.TAKEN_BRANCH) and (to_three[ItemsScript.TAKEN_BRANCH] as PackedVector3Array).size() == 2, "a newcomer is told both taken branches as it walks in (%s)" % str(to_three.get(ItemsScript.TAKEN_BRANCH, [])))
	items._nest_taken["n1"] = items._game_day()
	items._nest_at["n1"] = Vector3(1.0, 10.0, 1.0)
	items._shore_taken["0,0"] = items._game_day()
	told.clear()
	items.report_position(3, HERE + Vector3(40.0, 0.0, 0.0))   # one square over: not yet
	check(told.is_empty(), "stepping into the next 32 m square sends nothing again (no resend at every line)")
	items.report_position(3, HERE + Vector3(70.0, 0.0, 0.0))   # two squares on
	to_three = {}

	for t in told:
		if int(t[0]) == 3:
			to_three[int(t[1])] = t[2]

	check(to_three.has(ItemsScript.TAKEN_NEST) and to_three.has(ItemsScript.TAKEN_SHORE), "walking into a new square tells the robbed nest and the used tide-line node round it (%s)" % str(to_three.keys()))
	told.clear()
	items.report_position(3, HERE + Vector3(71.0, 0.0, 0.0))
	check(told.is_empty(), "inside the same square nothing is sent again")
	clock[0] += 86400.0
	items.action(2, Net.ACT_LITTER, 0, 0, 0, branch)
	check(items.inventory_of(2).count_of(stick) == 2, "a game day later the branch has grown back")
	items.action(2, Net.ACT_LITTER, 0, 0, 0, Vector3(NAN, 10.0, 0.0))
	check(items.inventory_of(2).count_of(stick) == 2, "a pick at a made-up point gives nothing and is not kept")
	told.clear()
	items.reset_world()
	check(told.filter(func(t): return int(t[1]) == ItemsScript.TAKEN_CLEAR).size() == 3, "a world reset tells every player to forget what was taken")


# The client side of ground_taken: the grass view hides a taken branch (and again when its cell is rebuilt); a robbed nest shows empty until it refills.
func _check_taken_drawn() -> void:
	var grass = preload("res://src/client/grass_view.gd").new()
	var layer: int = grass.GRASS_LAYERS + 1
	var cell: Vector2i = Vector2i(2, 3)
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(32)

	for n in range(2):   # two branches 1.2 m long along x, at x 12.5 and 14.5 (cell 6 m), z 19
		var o: int = n * 16
		buffer[o] = 1.2
		buffer[o + 5] = 1.0
		buffer[o + 10] = 1.0
		buffer[o + 3] = 12.5 + 2.0 * float(n)
		buffer[o + 7] = 10.0
		buffer[o + 11] = 19.0

	grass.today = 400
	grass._cells[cell] = {"bufs": {layer: buffer.duplicate()}}
	grass.take_branch(Vector3(13.6, 10.0, 19.3), 400)   # another client's middle for the first branch, half a metre off: its nearest is hidden
	var after: PackedFloat32Array = grass._cells[cell]["bufs"][layer]
	check(absf(after[0]) < 0.001 and absf(after[16] - 1.2) < 0.001, "a branch another player took is hidden here (the nearest one), the one beside it stays")
	grass.take_branch(Vector3(13.1, 10.0, 19.0), 400)   # this client's own pick of that branch, echoed: already hidden, nothing more goes
	check(absf((grass._cells[cell]["bufs"][layer] as PackedFloat32Array)[16] - 1.2) < 0.001, "a point already done hides no second branch")
	grass._cells[cell] = {"bufs": {layer: buffer.duplicate()}}   # the cell built again with both
	grass._hide_taken(cell)
	after = grass._cells[cell]["bufs"][layer]
	check(absf(after[0]) < 0.001 and absf(after[16] - 1.2) < 0.001, "and it stays hidden when its cell is built again")
	grass.today = 401
	grass._cells[cell] = {"bufs": {layer: buffer.duplicate()}}
	grass._hide_taken(cell)
	check(absf((grass._cells[cell]["bufs"][layer] as PackedFloat32Array)[0] - 1.2) < 0.001, "the next game day it has grown back")
	grass.free()
	var nests = preload("res://src/client/nest_view.gd").new()
	nests._ready()
	nests.set_season("spring", 400)
	nests.robbed(Vector3(5.0, 10.0, 5.0), 400)
	check(nests.is_robbed(Vector3(5.1, 10.0, 5.0), "songbird") and not nests.is_robbed(Vector3(9.0, 10.0, 5.0), "songbird"), "a nest another player robbed shows empty")
	nests.set_season("spring", 400 + int(nests._refill["songbird"]))
	check(not nests.is_robbed(Vector3(5.1, 10.0, 5.0), "songbird"), "and full again after its refill days")
	nests.free()
