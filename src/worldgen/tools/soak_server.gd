extends SceneTree

# Server soak (Radar, 2026-10-21): 20 simulated players walk about the starter tile for 60 s of server time at the scene's 20 Hz
# while every server system ticks together: items (fires, spoilage, warmth, vitals, crafting, trunks, carcasses), animals (rabbits
# and deer with senses, burrows, blood), NPCs, and the per-player sends (animal, NPC and blood rows). Prints per-system average and
# worst ms, the whole tick's average, p99 and worst, and names the worst offender. Fails only on a script error or a mean tick over
# 12 ms (a quarter of the 50 ms tick).
#   godot --headless --path . --script res://src/worldgen/tools/soak_server.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const AnimalsScript := preload("res://src/stream/server_animals.gd")
const NpcsScript := preload("res://src/stream/server_npcs.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const TICK_S := 0.05
const SPAN_S := 60.0
const PLAYERS := 20

var counts: Dictionary = {}
var failures: int = 0


func make(dir: String):
	var items = ItemsScript.new()
	items.send_full = func(_p, b): count("full", b.size())
	items.send_slots = func(_p, b): count("slots", b.size())
	items.send_world_items = func(_p, a, r): count("world_items", 40 * a.size() + 4 * r.size())
	items.send_craft_queue = func(_p, _e, _l): count("craft_queue", 24)
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): count("vitals", 8)
	items.send_strain = func(_p, _s, _st, _f, _sn): count("strain", 8)
	items.send_notice = func(_p, t): count("notice", t.length())
	items.send_chest = func(_p, _i, b): count("chest", b.size())
	items.send_reject = func(_p, _r): count("reject", 4)
	items.send_energy = func(_p, _e): count("energy", 4)
	items.send_warmth = func(_p, _w): count("warmth", 4)
	items.send_sick = func(_p, _h): count("sick", 4)
	items.send_skills = func(_p, _a, r): count("skills", 8 + 12 * r.size())
	items.send_worn = func(_p, n): count("worn", 4 * n.size())
	items.send_remains = func(_p, r): count("remains", 16 * r.size())
	items.send_died = func(_p, _c, _s): count("died", 16)
	items.weather_now = func(): return {"temp_c": 4.0, "wind": 0.4, "rain": 0.2, "snow": 0.0, "cloud": 0.6, "season": "autumn"}
	items.water_near = func(p, _r): return int(p.x / 40.0) % 2 == 0
	items.ice_cover_at = func(_p): return 0.0
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


func _init() -> void:
	var dir: String = "user://soak_server"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = make(dir)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var pos: Array = []
	var memory0: int = OS.get_static_memory_usage()

	for p in range(1, PLAYERS + 1):
		items.peer_connected_hello(p, "soakkey%05d" % p)
		pos.append(Vector3(53301.0 + rng.randf_range(-200.0, 200.0), 10.0, 68427.0 + rng.randf_range(-200.0, 200.0)))
		items.report_position(p, pos[p - 1])

		for id in ["stick", "stone", "plant_fibre", "chest_kit", "campfire_kit", "roast_forage", "fishing_rod", "workbench_kit", "grass_cloak", "spear", "twine", "wooden_spade"]:
			items.action(p, Net.ACT_ADMIN_GIVE, items.table.number_of(id), 0, 30 if not id.ends_with("_kit") and id not in ["fishing_rod", "grass_cloak", "spear", "wooden_spade"] else 2, Vector3.ZERO)

	var animals = AnimalsScript.new()
	animals.ground_height = items.ground_height
	animals.blocked = func(x, _z): return int(x / 80.0) % 7 == 0
	animals.player_positions = func(): return items.peer_positions()
	animals.player_stances = func(): return items.peer_stances()
	animals.wind = func(): return {"wind": 0.4, "wind_dir": 1.0}
	animals.canopy = func(p): return int(p.x / 30.0) % 3 == 0
	animals.setup()
	animals.died = func(sp, p, _peer): items.make_carcass(sp, p)
	animals.wolves.player_info = func(): return items.wolf_info()
	animals.wolves.fires = func(): return items._lit_fires()
	animals.wolves.hurt_player = func(peer, amount, lethal, cause): return items.hurt_player(peer, amount, lethal, cause)
	animals.wolves.notice = func(peer, text): items._say(peer, text)
	animals.cfg["wolves"]["natural"] = true
	animals.cfg["wolves"]["exclude"] = [0.0, 0.0, 0.0]
	animals.cfg["wolves"]["cell_m"] = 600.0   # dense: the worst case for the brain
	var npcs = NpcsScript.new()
	NpcsScript.test_hold_off = true
	npcs.hour_now = func(): return 9.0
	npcs.ground_height = items.ground_height
	npcs.player_positions = func(): return items.peer_positions()
	npcs.setup("")

	var names: Array = ["items", "animals", "npcs", "sends"]
	var sums: Dictionary = {}
	var worsts: Dictionary = {}

	for n in names:
		sums[n] = 0.0
		worsts[n] = 0.0

	var total: Array = []
	var spikes: Array = []

	for step in int(SPAN_S / TICK_S):
		if step % 5 == 0:
			for p in range(1, PLAYERS + 1):
				pos[p - 1] += Vector3(rng.randf_range(-4.0, 4.0), 0.0, rng.randf_range(-4.0, 4.0))
				items.report_position(p, pos[p - 1])

		if step % 40 == 0:
			for p in range(1, PLAYERS + 1):
				var kind: int = rng.randi_range(0, 9)

				if kind == 0:
					items._last_queue_act.clear()
					items.action(p, Net.ACT_CRAFT_QUEUE, 1, 0, 4, Vector3.ZERO)
				elif kind == 1:
					items.action(p, Net.ACT_PLACE, items.inventory_of(p).numbers.find(items.table.number_of("campfire_kit")), 0, 0, pos[p - 1] + Vector3(2.0, 0.0, 0.0))
				elif kind == 2:
					items.action(p, Net.ACT_PLACE, items.inventory_of(p).numbers.find(items.table.number_of("chest_kit")), 0, 0, pos[p - 1] + Vector3(-2.0, 0.0, 0.0))
				elif kind == 3:
					items.action(p, Net.ACT_EAT, items.inventory_of(p).numbers.find(items.table.number_of("roast_forage")), 0, 0, Vector3.ZERO)
				elif kind == 4:
					items.action(p, Net.ACT_DROP, 0, 0, 1, pos[p - 1])
				elif kind == 5:
					items.action(p, Net.ACT_WEAR, items.inventory_of(p).numbers.find(items.table.number_of("grass_cloak")), 0, 0, Vector3.ZERO)
				elif kind == 6 and not animals.animals.is_empty():
					var victim: int = animals.animals.keys()[rng.randi_range(0, animals.animals.size() - 1)]
					animals.damage(victim, 6.0, p)   # a hunt now and then: blood trails and carcasses

		var t_all: int = Time.get_ticks_usec()
		var t0: int = Time.get_ticks_usec()
		items.tick(TICK_S)
		var d_items: float = float(Time.get_ticks_usec() - t0) / 1000.0

		if d_items > 8.0:
			spikes.append("step %d %.1f ms" % [step, d_items])
		t0 = Time.get_ticks_usec()
		animals.tick(TICK_S)
		var d_animals: float = float(Time.get_ticks_usec() - t0) / 1000.0
		t0 = Time.get_ticks_usec()
		npcs.tick(TICK_S)
		var d_npcs: float = float(Time.get_ticks_usec() - t0) / 1000.0
		t0 = Time.get_ticks_usec()

		for n in range(step % 5, PLAYERS, 5):   # each player's rows about four times a second
			count("animals", var_to_bytes(animals.rows_near(pos[n])).size())
			count("npcs", var_to_bytes(npcs.rows_near(pos[n])).size())
			count("blood", var_to_bytes(animals.blood_near(pos[n])).size())

		var d_sends: float = float(Time.get_ticks_usec() - t0) / 1000.0
		total.append(float(Time.get_ticks_usec() - t_all) / 1000.0)

		for pair in [["items", d_items], ["animals", d_animals], ["npcs", d_npcs], ["sends", d_sends]]:
			sums[pair[0]] += pair[1]
			worsts[pair[0]] = maxf(worsts[pair[0]], pair[1])

	print("soak: items ticks over 8 ms: ", ", ".join(spikes.slice(0, 24)), " (", spikes.size(), " in all)")
	for fname in ["_rot", "_fires", "_vitals_tick", "_craft_tick", "_remains_tick", "_spoil_tick", "_fly", "_carcass_tick"]:
		if not items.has_method(fname):
			continue

		var t1: int = Time.get_ticks_usec()

		for n in 20:
			items.call(fname, 0.25)

		print("soak: profile %s: %.3f ms per call" % [fname, float(Time.get_ticks_usec() - t1) / 20000.0])

	for fname in ["_load_ratio", "warmth_target", "effort_of", "exertion_of", "_sleep_quality"]:
		var t4: int = Time.get_ticks_usec()

		for n in 10:
			for peer in items._peer_key:
				items.call(fname, peer)

		print("soak: profile %s: %.3f ms per pass over %d players" % [fname, float(Time.get_ticks_usec() - t4) / 10000.0, items._peer_key.size()])

	for fname in ["_warmth_tick", "_sick_tick", "_energy_tick", "_breath_tick", "_strain_tick", "_sync_vitals"]:
		var t3: int = Time.get_ticks_usec()

		for n in 10:
			for peer in items._peer_key:
				var v: Dictionary = items._vitals.get(items._peer_key[peer], {})

				if v.is_empty():
					continue

				if fname == "_warmth_tick" or fname == "_sick_tick" or fname == "_energy_tick":
					items.call(fname, peer, v, 0.25, 6.0)
				elif fname == "_breath_tick":
					items.call(fname, peer, v, 0.25)
				elif fname == "_strain_tick":
					items.call(fname, peer, 0.25)
				else:
					items.call(fname, peer, false)

		print("soak: profile %s: %.3f ms per pass over %d players" % [fname, float(Time.get_ticks_usec() - t3) / 10000.0, items._peer_key.size()])

	for fname in ["_save_trees", "_save_chests", "_save_vitals", "_save_characters", "_save_craft_queues"]:
		var t5: int = Time.get_ticks_usec()
		items.call(fname)
		print("soak: save %s: %.2f ms" % [fname, float(Time.get_ticks_usec() - t5) / 1000.0])

	items._async_writes = true
	for fname in ["_save_trees", "_save_chests", "_save_vitals", "_save_characters", "_save_craft_queues"]:
		var t7: int = Time.get_ticks_usec()
		items.call(fname)
		print("soak: serialise %s: %.2f ms" % [fname, float(Time.get_ticks_usec() - t7) / 1000.0])

	items._pending_writes.clear()
	items._async_writes = false
	var t6: int = Time.get_ticks_usec()
	items._dirty = true
	items.save()
	print("soak: whole save: %.2f ms" % [float(Time.get_ticks_usec() - t6) / 1000.0])
	var steps: int = total.size()
	var settled: Array = total.slice(steps / 2)
	settled.sort()
	var mean: float = 0.0

	for t in total:
		mean += t

	mean /= float(steps)
	var worst_name: String = "items"

	for n in names:
		print("soak: %-8s avg %.3f ms, worst %.2f ms" % [n, sums[n] / float(steps), worsts[n]])

		if sums[n] > sums[worst_name]:
			worst_name = n

	print("soak: %d players, %d animals, %d NPCs, %d world records after %.0f s: tick avg %.2f ms, p99 %.2f ms, worst %.2f ms; heaviest on average: %s; memory +%.1f MB" % [PLAYERS, animals.animals.size(), npcs.npcs.size(), items.world_item_count(), SPAN_S, mean, float(settled[int(settled.size() * 0.99)]), float(settled[settled.size() - 1]), worst_name, float(OS.get_static_memory_usage() - memory0) / 1048576.0])

	if mean > 12.0:
		failures += 1
		print("FAIL mean tick %.2f ms over 12 ms" % mean)

	print("soak: %d failures" % failures)
	quit(1 if failures > 0 else 0)
