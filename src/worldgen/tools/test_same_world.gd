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
		var at: Vector3 = HERE + Vector3(-60.0 + float(spot % 20) * 6.0, 0.0, -60.0 + floorf(float(spot) / 20.0) * 6.0)
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
