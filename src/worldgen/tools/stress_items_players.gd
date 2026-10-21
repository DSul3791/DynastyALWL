extends SceneTree

# Items multi-player stress (Items job 64): 20 simulated players walk about for 10 game minutes of server time
# (24:1 clock, so this is the real 25 s the server would run), each with a crafting queue, fires, chests and food.
# Prints "stress20:" lines: server tick ms (average, 99th percentile, worst), messages per second by kind, save ms,
# memory growth, and the scaling run (5, 10, 20, 40 players). Not a pass/fail test; it fails only on a script error
# or a tick over 50 ms.
#   godot --headless --path . --script res://src/worldgen/tools/stress_items_players.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const TICK_S := 0.05            # the server scene's 20 Hz
const SPAN_S := 25.0            # real seconds simulated
const SPREAD_M := 400.0         # players start inside a square this wide

var counts: Dictionary = {}
var failures: int = 0


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, b): count("full", b.size())
	items.send_slots = func(_p, b): count("slots", b.size())
	items.send_world_items = func(_p, a, r): count("world_items", 40 * a.size() + 4 * r.size())
	items.send_craft_queue = func(_p, _e, _l): count("craft_queue", 24)
	items.send_vitals = func(_p, _h, _he, _w): count("vitals", 8)
	items.send_strain = func(_p, _s, _st, _f, _sn): count("strain", 8)
	items.send_notice = func(_p, t): count("notice", t.length())
	items.send_chest = func(_p, _i, b): count("chest", b.size())
	items.send_reject = func(_p, _r): count("reject", 4)
	items.ground_height = func(x, z): return 10.0 + sin(x * 0.01) * 3.0
	items.cover_at = func(p): return 1.0 if int(p.x / 30.0) % 3 == 0 else 0.0
	items.rock_at = func(_x, _z): return false
	items.game_seconds = func(): return float(Time.get_ticks_msec()) / 1000.0 * 24.0
	items.rain_now = func(): return 0.0
	items.setup(ItemTableScript.load_default(), dir)
	return items


func count(kind: String, bytes: int) -> void:
	var row: Array = counts.get(kind, [0, 0])
	row[0] += 1
	row[1] += bytes
	counts[kind] = row


func run(players: int, label: String) -> void:
	counts = {}
	var dir: String = "user://stress_players_%d" % players
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 11
	var pos: Array = []
	var memory0: int = OS.get_static_memory_usage()

	for p in range(1, players + 1):
		items.peer_connected_hello(p, "stresskey%05d" % p)
		pos.append(Vector3(rng.randf() * SPREAD_M, 10.0, rng.randf() * SPREAD_M))
		items.report_position(p, pos[p - 1])

		for id in ["stick", "stone", "plant_fibre", "chest_kit", "campfire_kit", "roast_forage"]:
			items.action(p, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, 30 if id != "chest_kit" and id != "campfire_kit" else 2, Vector3.ZERO)

	var ticks: Array = []
	var steps: int = int(SPAN_S / TICK_S)

	for step in range(steps):
		var t0: int = Time.get_ticks_usec()

		if step % 5 == 0:
			for p in range(1, players + 1):
				pos[p - 1] += Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0))
				items.report_position(p, pos[p - 1])

		if step % 40 == 0:
			for p in range(1, players + 1):
				var kind: int = rng.randi_range(0, 4)

				if kind == 0:
					items._last_queue_act.clear()
					items.action(p, Net.ACT_CRAFT_QUEUE, 1, 0, 4, Vector3.ZERO)
				elif kind == 1:
					items.action(p, Net.ACT_PLACE, items.inventory_of(p).numbers.find(items.table.number_of("campfire_kit")), 0, 0, pos[p - 1] + Vector3(2.0, 0.0, 0.0))
				elif kind == 2:
					items.action(p, Net.ACT_PLACE, items.inventory_of(p).numbers.find(items.table.number_of("chest_kit")), 0, 0, pos[p - 1] + Vector3(-2.0, 0.0, 0.0))
				elif kind == 3:
					items.action(p, Net.ACT_EAT, items.inventory_of(p).numbers.find(items.table.number_of("roast_forage")), 0, 0, Vector3.ZERO)
				else:
					items.action(p, Net.ACT_DROP, 0, 0, 1, pos[p - 1])

		items.tick(TICK_S)

		if step % int(10.0 / TICK_S) == 0:
			items._dirty = true

		ticks.append(float(Time.get_ticks_usec() - t0) / 1000.0)

	var save0: int = Time.get_ticks_usec()
	items._dirty = true
	items.save()
	var save_ms: float = float(Time.get_ticks_usec() - save0) / 1000.0
	ticks.sort()
	var total: float = 0.0

	for t in ticks:
		total += float(t)

	var worst: float = float(ticks[ticks.size() - 1])
	print("stress20: %s: %d players, %d world records after %.0f s: tick avg %.2f ms, p99 %.2f ms, worst %.2f ms; save %.1f ms; memory +%.1f MB" % [label, players, items.world_item_count(), SPAN_S, total / float(ticks.size()), float(ticks[int(ticks.size() * 0.99)]), worst, save_ms, float(OS.get_static_memory_usage() - memory0) / 1048576.0])
	var rows: Array = []

	for kind in counts:
		rows.append("%s %.1f/s %.1f KB/s" % [kind, float(counts[kind][0]) / SPAN_S, float(counts[kind][1]) / SPAN_S / 1024.0])

	rows.sort()
	print("stress20: %s: messages per second (all players together): %s" % [label, "; ".join(rows)])

	if worst > 50.0:
		failures += 1
		print("FAIL %s: a tick took %.1f ms" % [label, worst])


func _init() -> void:
	for n in [5, 10, 20, 40]:
		run(n, "scaling")

	print("stress20: %d failures" % failures)
	quit(1 if failures > 0 else 0)
