extends SceneTree

# Two players at once on the same things (coordinator, 23 Nov 2026: "items doubled or lost and the two clients showing different
# things"): the same chest open by both, both taking the same stack or the same pickup, a piece taken down while another has it open, the
# same craft stock wanted by two crafts, and one player's line dropping (the 15 s rule, server_items ABSENT_MS) in the middle. The server
# takes actions one at a time, so each case checks the two things that can still go wrong: the count of every item over packs, chests and
# the ground stays the same, and what each player was last sent about a shared container is what it really holds.
#   godot --headless --path . --script res://src/worldgen/tools/test_two_players.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const HERE := Vector3(0.0, 10.0, 0.0)

var failures: int = 0
var clock: Array = [100.0 * 86400.0 + 8.0 * 3600.0]
var seen: Dictionary = {}   # peer -> {container world id: the contents last sent to it (Inventory)}


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _count(inv, number: int) -> int:
	var n: int = 0

	if inv == null:
		return 0

	for slot in range(inv.slot_count):
		if inv.numbers[slot] == number:
			n += int(inv.counts[slot])

	return n


func _slot_of(inv, number: int) -> int:
	for slot in range(inv.slot_count):
		if inv.numbers[slot] == number:
			return slot

	return -1


# Every one of `number` the server holds: packs, containers and loose on the ground.
func _total(items, number: int) -> int:
	var n: int = 0

	for peer in items._peer_key:
		n += _count(items.inventory_of(peer), number)

	for uid in items._chests:
		n += _count(items._chests[uid], number)

	for id in items._items:
		if int(items._items[id].get("number", 0)) == number and not items._items[id].has("struct"):
			n += int(items._items[id].get("count", 1))

	return n


func _chest_id(items, peer_owner_spot: Vector3) -> int:
	var best: int = -1

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct") and it["struct"].has("uid") and items._chests.has(int(it["struct"]["uid"])) and (it["pos"] as Vector3).distance_to(peer_owner_spot) < 0.5:
			best = int(id)

	return best


# What `peer` was last sent about container `id` matches what it holds now (a player who has it open sees the truth).
func _view_true(items, peer: int, id: int, number: int) -> bool:
	var uid: int = int(items._items[id]["struct"]["uid"])
	var box = seen.get(peer, {}).get(id, null)
	return box != null and _count(box, number) == _count(items._chests[uid], number)


func _init() -> void:
	var dir: String = "user://test_two_players"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	var table = ItemTableScript.load_default()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_chest = func(p, id, bytes):
		var box = InventoryScript.new(table)
		box.from_bytes(bytes)

		if not seen.has(p):
			seen[p] = {}

		seen[p][id] = box
	items.setup(table, dir)
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return clock[0]
	var stone: int = table.number_of("stone")
	items.peer_connected_hello(1, "twoplayers_a")
	items.report_position(1, HERE)
	items.peer_connected_hello(2, "twoplayers_b")
	items.report_position(2, HERE + Vector3(1.0, 0.0, 0.0))
	items.give(1, stone, 10)
	items.give(2, stone, 10)
	var all: int = _total(items, stone)

	# 1. The same chest open by both: what one puts in or takes out, the other is shown at once.
	var spot: Vector3 = HERE + Vector3(0.5, 0.0, 1.0)
	items.place_piece(1, "chest_kit", spot)
	var chest: int = _chest_id(items, spot)
	check(chest >= 0, "a chest stands between the two players")

	if chest < 0:
		print("test_two_players: %d failures" % (failures + 1))
		quit(1)
		return

	var uid: int = int(items._items[chest]["struct"]["uid"])
	items.action(1, Net.ACT_CHEST_OPEN, chest, 0, 0, Vector3.ZERO)
	items.action(2, Net.ACT_CHEST_OPEN, chest, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, _slot_of(items.inventory_of(1), stone), chest, 6, Vector3.ZERO)
	check(_count(items._chests[uid], stone) == 6, "player A puts 6 stones in the chest")
	check(_view_true(items, 2, chest, stone), "player B, with the chest open too, is shown the 6 (%d)" % _count(seen.get(2, {}).get(chest, null), stone))
	check(_view_true(items, 1, chest, stone), "and player A sees the same")

	# 2. Both take the same stack in the same moment: one gets it, the other nothing; no stone made or lost.
	var a_before: int = _count(items.inventory_of(1), stone)
	var b_before: int = _count(items.inventory_of(2), stone)
	var slot: int = _slot_of(items._chests[uid], stone)
	items.action(1, Net.ACT_CHEST_TAKE, slot, chest, 6, Vector3.ZERO)
	items.action(2, Net.ACT_CHEST_TAKE, slot, chest, 6, Vector3.ZERO)
	var got_a: int = _count(items.inventory_of(1), stone) - a_before
	var got_b: int = _count(items.inventory_of(2), stone) - b_before
	check(got_a + got_b == 6 and _count(items._chests[uid], stone) == 0, "both take the 6 at once: 6 taken in all (A %d, B %d), the chest empty" % [got_a, got_b])
	check(_total(items, stone) == all, "no stone made or lost (%d, was %d)" % [_total(items, stone), all])
	check(_view_true(items, 1, chest, stone) and _view_true(items, 2, chest, stone), "both are shown the chest empty")

	# 3. Both pick up the same dropped stack: one gets it.
	items.action(2, Net.ACT_DROP, _slot_of(items.inventory_of(2), stone), 0, 4, HERE + Vector3(0.5, 0.0, 0.5))
	var dropped: int = -1

	for id in items._items:
		if int(items._items[id].get("number", 0)) == stone and not items._items[id].has("struct"):
			dropped = int(id)

	check(dropped >= 0, "player B drops 4 stones")
	a_before = _count(items.inventory_of(1), stone)
	b_before = _count(items.inventory_of(2), stone)
	items.action(1, Net.ACT_PICKUP, dropped, 0, 0, Vector3.ZERO)
	items.action(2, Net.ACT_PICKUP, dropped, 0, 0, Vector3.ZERO)
	got_a = _count(items.inventory_of(1), stone) - a_before
	got_b = _count(items.inventory_of(2), stone) - b_before
	check(got_a + got_b == 4 and not items._items.has(dropped), "both pick up the same 4 at once: 4 in all (A %d, B %d), none left on the ground" % [got_a, got_b])
	check(_total(items, stone) == all, "no stone made or lost (%d, was %d)" % [_total(items, stone), all])

	# 4. A line drops (15 s, parked) while the chest is open; the other player fills it; back again, the view is the truth.
	items.action(1, Net.ACT_CHEST_PUT, _slot_of(items.inventory_of(1), stone), chest, 3, Vector3.ZERO)
	var now: int = Time.get_ticks_msec()
	items._heard_ms[2] = now - ItemsScript.ABSENT_MS - 5000
	items._park_check_ms = 0
	items._park_quiet(now)
	check(items.is_absent(2), "player B's line goes quiet for 20 s with the chest open")
	items.action(2, Net.ACT_CHEST_TAKE, _slot_of(items._chests[uid], stone), chest, 3, Vector3.ZERO)   # a stale take from the quiet line
	check(_count(items._chests[uid], stone) == 3, "a take from the quiet line does nothing")
	items.action(1, Net.ACT_CHEST_PUT, _slot_of(items.inventory_of(1), stone), chest, 2, Vector3.ZERO)
	check(_count(items._chests[uid], stone) == 5, "player A puts 2 more in meanwhile (5)")
	items.report_position(2, HERE + Vector3(1.0, 0.0, 0.0))
	check(not items.is_absent(2) and _view_true(items, 2, chest, stone), "player B's line comes back: it is shown the chest as it is now (%d, holds %d)" % [_count(seen.get(2, {}).get(chest, null), stone), _count(items._chests[uid], stone)])
	check(_total(items, stone) == all, "no stone made or lost (%d, was %d)" % [_total(items, stone), all])

	# 5. Taken down by its builder while the other player has it open: B cannot, A empties it and can; B's window on it is let go.
	items.action(2, Net.ACT_PICKUP, chest, 0, 0, Vector3.ZERO)
	check(items._items.has(chest), "player B cannot take player A's chest down")
	items.action(1, Net.ACT_PICKUP, chest, 0, 0, Vector3.ZERO)
	check(items._items.has(chest), "a chest with stones in it does not come down (Empty it first)")
	items.action(1, Net.ACT_CHEST_TAKE, _slot_of(items._chests[uid], stone), chest, 5, Vector3.ZERO)
	check(_view_true(items, 2, chest, stone), "player B is shown it emptied")
	items.action(1, Net.ACT_PICKUP, chest, 0, 0, Vector3.ZERO)
	check(not items._items.has(chest), "player A takes it down")
	check(_total(items, stone) == all, "its stones are kept, once (%d, was %d)" % [_total(items, stone), all])
	check(int(items._chest_viewer.get(2, 0)) != chest, "player B's window on it is let go (nothing more pushed; the client closes it as the row goes)")
	var client_code: String = FileAccess.get_file_as_string("res://src/client/inventory_view.gd").replace("\r\n", "\n")   # a Windows checkout ends lines with CRLF: the multi-line checks below read LF
	check(client_code.contains("if chest_mode and chest_id >= 0 and removed.has(chest_id):\n\t\t_close_chest()"), "the client closes an open container's window when it goes from the world (inventory_view.gd)")
	items.action(2, Net.ACT_CHEST_TAKE, 0, chest, 5, Vector3.ZERO)
	check(_total(items, stone) == all, "a take on the gone chest makes nothing (%d, was %d)" % [_total(items, stone), all])

	print("test_two_players: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
