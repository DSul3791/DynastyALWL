extends SceneTree

# A player who drops off and rejoins in the middle of something (coordinator, 23 Nov 2026: connection robustness as bugs): nothing is lost or
# made twice, nothing stays stuck on the server, and a second connection of the same character takes over from the first. Server side only
# (server_items.gd); the robots' drops plan runs the same over a real lossy link.
#   godot --headless --path . --script res://src/worldgen/tools/test_rejoin_states.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const LinkBarsScript := preload("res://src/client/link_bars.gd")

const HERE := Vector3(0.0, 10.0, 0.0)
const KEY := "rejoinstate01"

var failures: int = 0
var clock: Array = [100.0 * 86400.0 + 8.0 * 3600.0]


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _count(inv, number: int) -> int:
	var n: int = 0

	if inv == null:
		return -1

	for slot in range(inv.slot_count):
		if inv.numbers[slot] == number:
			n += int(inv.counts[slot])

	return n


func _slot_of(inv, number: int) -> int:
	for slot in range(inv.slot_count):
		if inv.numbers[slot] == number:
			return slot

	return -1


func _world_count(items, number: int) -> int:
	var n: int = 0

	for id in items._items:
		if int(items._items[id].get("number", 0)) == number:
			n += int(items._items[id].get("count", 1))

	return n


func _init() -> void:
	var dir: String = "user://test_rejoin_states"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), dir)
	items.ground_height = func(_x, _z): return 10.0
	items.game_seconds = func(): return clock[0]
	var t = items.table
	var stone: int = t.number_of("stone")
	var oak: int = t.number_of("log_oak")

	# 1. The same character on a second connection before the first has timed out (a rejoin after a dropped line, or a second window).
	items.peer_connected_hello(1, KEY)
	items.report_position(1, HERE)
	items.give(1, stone, 5)
	items.give(1, oak, 1)
	var pack = items.inventory_of(1)
	check(_count(pack, stone) == 5 and _count(pack, oak) == 1, "the first connection has 5 stones and an oak log on the shoulder")
	var replaced: Array = items.peer_connected_hello(2, KEY)
	check(replaced == [1], "the second connection of the same character names the first, to be dropped")
	items.report_position(2, HERE + Vector3(3.0, 0.0, 0.0))
	var before_world: int = _world_count(items, stone)
	items.action(1, Net.ACT_DROP, _slot_of(items.inventory_of(2), stone), 0, 5, HERE)   # the stale line still sends a drop
	check(_count(items.inventory_of(2), stone) == 5 and _world_count(items, stone) == before_world, "the stale connection's drop does nothing: no stones lost, none made on the ground")
	check(items.inventory_of(1) == null, "the stale connection has no pack any more")
	items.peer_left(1)
	var last: Dictionary = items._characters[KEY].get("last", {})
	check(last.is_empty() or Vector3(float(last["pos"][0]), float(last["pos"][1]), float(last["pos"][2])).distance_to(HERE) > 1.0, "the stale connection leaving writes no old spot over the live one")
	check(_count(items.inventory_of(2), stone) == 5 and _count(items.inventory_of(2), oak) == 1, "the live connection still has the stones and the log")
	var server_code: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	check(server_code.contains("_drop_replaced(old_peer)") and server_code.contains("joined the server again from another game window") and server_code.contains("_on_peer_disconnected(old_peer)   # forgotten now") and server_code.contains("if not _peers.has(peer_id):\n\t\treturn   # forgotten already"), "the replaced connection is told why on its screen, then forgotten at once, not at its line's timeout (terrain_server.gd _drop_replaced)")

	# 2. Asleep when the line drops: back awake on rejoin, with the energy it had.
	items._stance[2] = 3
	items._sleep(2, 1)

	if not items.sleeping_of(2):
		items._asleep[2] = {"rested": 0.0}   # a rested character does not fall asleep on Z; asleep as after a long day
	var slept: bool = items.sleeping_of(2)
	var energy: float = items.energy_of(2)
	items.peer_left(2)
	items.peer_connected_hello(3, KEY)
	items.report_position(3, HERE)
	check(not items.sleeping_of(3), "asleep when the line dropped: not asleep on the new connection (was asleep: %s)" % str(slept))
	check(absf(items.energy_of(3) - energy) < 0.5, "and the energy is as it was (%.1f, was %.1f)" % [items.energy_of(3), energy])
	check(_count(items.inventory_of(3), oak) == 1, "the shoulder log comes back in the pack")

	# 3. A chest open, half way through putting stones in, when the line drops: every stone is in the pack or the chest, once.
	items.place_piece(3, "chest_kit", HERE + Vector3(2.0, 0.0, 0.0))
	var chest_id: int = -1

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct") and it["struct"].has("uid") and items._chests.has(int(it["struct"]["uid"])):
			chest_id = int(id)

	check(chest_id >= 0, "a chest stands by the player")

	if chest_id >= 0:
		var uid: int = int(items._items[chest_id]["struct"]["uid"])
		items.action(3, Net.ACT_CHEST_OPEN, chest_id, 0, 0, Vector3.ZERO)
		items.action(3, Net.ACT_CHEST_PUT, _slot_of(items.inventory_of(3), stone), chest_id, 2, Vector3.ZERO)
		var in_chest: int = _count(items._chests[uid], stone)
		check(in_chest == 2 and _count(items.inventory_of(3), stone) == 3, "2 stones went in the chest, 3 stay in the pack (%d, %d)" % [in_chest, _count(items.inventory_of(3), stone)])
		items.peer_left(3)
		check(not items._chest_viewer.has(3), "the chest is not left open for a gone connection")
		items.peer_connected_hello(4, KEY)
		items.report_position(4, HERE)
		check(_count(items.inventory_of(4), stone) + _count(items._chests[uid], stone) == 5, "after the rejoin every stone is in the pack or the chest, once")
		items.action(4, Net.ACT_CHEST_OPEN, chest_id, 0, 0, Vector3.ZERO)
		check(int(items._chest_viewer.get(4, 0)) == chest_id, "the new connection opens the same chest")
	else:
		items.peer_connected_hello(4, KEY)

	# 4. Swimming and passed out from cold when the line drops: nothing of either is kept for the new connection.
	items._swimming[4] = true
	items._cold_out[4] = 20.0
	items.peer_left(4)
	items.peer_connected_hello(5, KEY)
	check(not items._swimming.has(5) and not items._cold_out.has(5) and not items._swimming.has(4) and not items._cold_out.has(4), "swimming or passed out when the line dropped: nothing stuck for the old or the new connection")
	check(int(items.vitals_of(5).get("health", 100)) >= 1, "the character is alive on the new connection")

	# A craft queue across a rejoin: the robots' first_hours plan quits with 6 twine queued and checks fibre + 3 x twine after the rejoin.
	items.peer_left(5)

	# 5. A dropped line (coordinator, 23 Nov 2026): for ABSENT_MS the body stays and can be hurt; after that it is out of the world for every
	# attacker (animals and bandit fighters read peer_positions/peer_ids, wolves, big game and bandit fighters wolf_info, goblins _peer_pos,
	# bandit camps peer_positions) and cold, hunger and wet stop, until its next report puts it back.
	items.peer_connected_hello(6, KEY)
	items.report_position(6, HERE)
	items.give(6, stone, 1)
	var now: int = Time.get_ticks_msec()
	items._heard_ms[6] = now - 10000
	items._park_check_ms = 0
	items._park_quiet(now)
	check(not items.is_absent(6) and items.peer_ids().has(6) and items.wolf_info().size() == 1, "10 s quiet: the body is still in the world and can be hurt")
	var hp_near: float = float(items.vitals_of(6)["health"])
	items.hurt_player(6, 5.0, false, "wolves", 25.0, "", 0.0, HERE)
	check(float(items.vitals_of(6)["health"]) < hp_near, "a bite in those first seconds lands: pulling the cable is no escape")
	items._heard_ms[6] = now - ItemsScript.ABSENT_MS - 5000
	items._park_check_ms = now - 1500
	items._park_quiet(now)
	check(items.is_absent(6), "20 s quiet: the player is absent")
	check(not items.peer_ids().has(6) and items.peer_positions().is_empty(), "animals and bandit fighters find no body (peer_ids, peer_positions; bandit camps too)")
	check(items.wolf_info().is_empty(), "wolves, big game and bandit fighters find no body (wolf_info)")
	check(not items._peer_pos.has(6) and items.position_of(6) == null, "goblins find no body (tribes.players reads _peer_pos)")
	var hp6: float = float(items.vitals_of(6)["health"])
	items.hurt_player(6, 30.0, false, "wolves", 25.0, "", 0.0, HERE)
	items.hurt_player(6, 30.0, false, "bandit", 10.0, "", 0.0, HERE)
	check(float(items.vitals_of(6)["health"]) == hp6, "a wolf or bandit that still held it as its target hurts nothing (%.0f, was %.0f)" % [float(items.vitals_of(6)["health"]), hp6])
	var v6: Dictionary = items.vitals_of(6)
	v6["wet"] = 0.5
	var was: Array = [float(v6["fed"]), float(v6["wet"]), float(v6.get("warmth", 0.0)), float(v6.get("water", 0.0))]
	clock[0] += 6.0 * 3600.0
	items._vitals_tick(6.0 * 3600.0 / 72.0)
	var v6b: Dictionary = items.vitals_of(6)
	check([float(v6b["fed"]), float(v6b["wet"]), float(v6b.get("warmth", 0.0)), float(v6b.get("water", 0.0))] == was, "absent: no hunger, thirst, cold or drying (%s, was %s)" % [str([v6b["fed"], v6b["wet"], v6b.get("warmth", 0.0), v6b.get("water", 0.0)]), str(was)])
	items._heard_ms[6] = now - 5000
	items._park_check_ms = now - 5000
	items._park_quiet(now)
	check(items.is_absent(6), "a server that stalled itself parks nobody new and wakes nobody")
	items._park_check_ms = 0
	items.report_position(6, HERE + Vector3(1.0, 0.0, 0.0))
	check(not items.is_absent(6) and items.peer_ids().has(6) and items.wolf_info().size() == 1, "its next report puts the body back for everyone")
	items._vitals_tick(6.0 * 3600.0 / 72.0)
	check(float(items.vitals_of(6)["fed"]) < float(was[0]) or float(items.vitals_of(6)["wet"]) < float(was[1]), "and its vitals run again (control: the same tick does drain a present player)")
	items._heard_ms[6] = now - ItemsScript.ABSENT_MS - 5000
	items._park_check_ms = 0
	items._park_quiet(now)
	items.peer_left(6)
	var last6: Dictionary = items._characters[KEY].get("last", {})
	check(not last6.is_empty() and Vector3(float(last6["pos"][0]), float(last6["pos"][1]), float(last6["pos"][2])).distance_to(HERE + Vector3(1.0, 0.0, 0.0)) < 0.1, "a line that times out while absent still writes the spot it went quiet at")
	check(not items._parked.has(6) and not items._heard_ms.has(6), "and nothing is kept for the gone connection")
	check(server_code.contains("animals.player_positions = npcs.player_positions") and server_code.contains("npcs.player_positions = func(): return items.peer_positions()") and server_code.contains("animals.wolves.player_info = func(): return items.wolf_info()") and server_code.contains("animals.big_game.player_info = func(): return items.wolf_info()") and server_code.contains("bandits.camp_tick(delta, items.peer_positions())") and server_code.contains("for peer in items._peer_pos:\n\t\t\trows.append({\"peer\": peer"), "every attacker reads the players from the list an absent body leaves (terrain_server.gd wiring)")

	# A server that goes quiet (restarting, or a long spike): the player is told under the signal bars within SAY_SILENT_MSEC, not left
	# with a frozen world until the line times out (60 to 120 s); the words go when the server talks again.
	var bars = LinkBarsScript.new()
	root.add_child(bars)
	bars.setup(func(): return null)
	bars.pulse()
	bars._last_pulse_msec = Time.get_ticks_msec() - LinkBarsScript.SAY_SILENT_MSEC - 1000
	bars._next_check_msec = 0
	bars._process(0.0)
	check(bars._note != null and bars._note.visible and bars._note.text.contains("No word from the server") and bars._note.text.contains("restarting"), "a quiet server: a plain line under the bars (%s)" % (bars._note.text if bars._note != null else "none"))
	bars.pulse()
	bars._next_check_msec = 0
	bars._process(0.0)
	check(not bars._note.visible, "it goes when the server talks again")
	check(LinkBarsScript.silence_words(2000) == "", "a short gap says nothing")
	bars.queue_free()
	print("test_rejoin_states: ", "PASS" if failures == 0 else "%d failures" % failures)
	quit(1 if failures > 0 else 0)
