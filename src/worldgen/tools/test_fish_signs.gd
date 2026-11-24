extends SceneTree

# Fish you can see (src/server/server_fish_signs.gd and src/client/fish_signs_view.gd, protocol 169; Dave 24 Nov 2026: "are fish pools
# actually a thing in the rivers yet because I have never seen any"), on the made-up map of test_fish_schools.gd: jumps happen near the
# schools a player stands by, inside a school, on the water, at most one per 3 s a player, never far from water or on ice, fewer in a storm
# and at night; shadows list only shallow schools within 40 m and are resent only on change; the client draws a pooled splash and the
# shadows, hidden at night, in rain and at Low; the wire is declared and wired at both ends. Prints the server cost of a pass.
#   godot --headless --path . --script res://src/worldgen/tools/test_fish_signs.gd      Prints "Test done: N pass, N fail".

const FishWater := preload("res://src/server/server_fish_water.gd")
const Fish := preload("res://src/server/server_fish.gd")
const Signs := preload("res://src/server/server_fish_signs.gd")
const View := preload("res://src/client/fish_signs_view.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const HeldItem := preload("res://src/client/held_item.gd")

var passes: int = 0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


# Same map as test_fish_water.gd: sea x < 0, brook x 100..108, river x 300..324, lake x 1000..1800, z 0..800.
static func probe(x: float, z: float) -> Array:
	if x < 0.0:
		return [0.0, -(-x / 15.0), 1]

	if x >= 100.0 and x < 108.0 and z >= 0.0 and z < 800.0:
		return [10.4, 10.0, 3]

	if x >= 300.0 and x < 324.0 and z >= 0.0 and z < 800.0:
		return [12.5, 10.0, 3]

	if x >= 1000.0 and x < 1800.0 and z >= 0.0 and z < 800.0:
		return [20.0, 17.0, 2]

	return [NAN, 12.0 + x * 0.001, 0]


# The few ServerItems calls the signs make.
class FakeItems extends RefCounted:
	var water_kind_at: Callable
	var positions: Dictionary = {}
	var fish = null
	var game_s: float = 40.0 * 86400.0 + 7.0 * 3600.0   # dawn
	var weather: Dictionary = {"rain": 0.0, "storm": 0.0, "temp_c": 14.0}
	var ice: bool = false

	func peer_ids() -> Array:
		return positions.keys()

	func position_of(peer: int) -> Variant:
		return positions.get(peer, null)

	func _fish_schools():
		return fish

	func _now_game_s() -> float:
		return game_s

	func _season_of(_pos: Vector3) -> String:
		return "summer"

	func fish_stock(_cell: Vector2i) -> int:
		return 12

	func _weather_here(_pos: Vector3) -> Dictionary:
		return weather

	func _on_ice(_pos: Vector3) -> bool:
		return ice


func _init() -> void:
	var water = FishWater.new(func(x: float, z: float) -> Array: return probe(x, z))
	var items: FakeItems = FakeItems.new()
	items.water_kind_at = func(x: float, z: float) -> Dictionary: return water.water_kind_at(x, z, 0)
	items.fish = Fish.new(items.water_kind_at, func(_s: String) -> bool: return true)
	var signs = Signs.new()
	signs.seed_rng(7)
	signs.items = items
	signs.surface_at = func(x: float, z: float) -> float: return float(probe(x, z)[0])
	var clock: Array = [0]
	signs.now_ms = func() -> int: return int(clock[0])
	var jumps: Array = []      # [peer, at, kind, ms]
	var shadows: Dictionary = {}   # peer -> [rows ...]
	signs.send_jump = func(peer: int, at: Vector3, kind: int, _seed: int) -> void: jumps.append([peer, at, kind, int(clock[0]), items.game_s])
	signs.send_shadows = func(peer: int, rows: PackedFloat32Array) -> void:
		if not shadows.has(peer):
			shadows[peer] = []

		(shadows[peer] as Array).append(rows)

	# Two players by brook schools (x 100..108; each 6 m from a school's middle), one far out on dry land (x 700: 376 m from the river), one by
	# the river (deep: 2.5 m).
	var brook: Array = []

	for cz in 7:
		for s in items.fish.schools(Vector2i(0, cz), 40, "summer", 12, items.game_s):
			if (s["centre"] as Vector2).x >= 100.0 and (s["centre"] as Vector2).x < 108.0:
				brook.append(s["centre"])

	check(brook.size() >= 2, "the brook holds at least two schools today (%d)" % brook.size())

	if brook.size() < 2:
		brook = [Vector2(104.0, 300.0), Vector2(104.0, 420.0)]

	var at1: Vector2 = brook[0]
	var at2: Vector2 = brook[brook.size() - 1]
	items.positions = {1: Vector3(at1.x + 6.0, 11.0, at1.y), 2: Vector3(at2.x - 6.0, 11.0, at2.y), 3: Vector3(700.0, 12.0, 400.0), 4: Vector3(330.0, 11.0, 400.0)}
	var worst_usec: int = 0

	for k in 600:
		clock[0] = k * 1000
		items.game_s += 24.0   # game time runs 24 times real time: the schools drift
		signs.tick()
		worst_usec = maxi(worst_usec, signs.last_tick_usec)

	var by_peer: Dictionary = {}
	var gap_ok: bool = true
	var last: Dictionary = {}
	var on_water: bool = true
	var in_school: bool = true

	for j in jumps:
		var peer: int = int(j[0])
		by_peer[peer] = int(by_peer.get(peer, 0)) + 1
		gap_ok = gap_ok and int(j[3]) - int(last.get(peer, -100000)) >= 3000
		last[peer] = int(j[3])
		var at: Vector3 = j[1]
		on_water = on_water and not is_nan(float(probe(at.x, at.z)[0])) and absf(at.y - float(probe(at.x, at.z)[0])) < 0.01
		var near_school: bool = false
		var cell: Vector2i = Vector2i(int(floor(at.x / 128.0)), int(floor(at.z / 128.0)))

		for s in items.fish.schools(cell, 40, "summer", 12, float(j[4])):
			near_school = near_school or (s["centre"] as Vector2).distance_to(Vector2(at.x, at.z)) <= float(s["radius"]) + 0.01

		in_school = in_school and near_school
		check(Vector2(at.x, at.z).distance_to(Vector2(items.positions[peer].x, items.positions[peer].z)) <= 100.0 + 0.01, "a jump is sent only within 100 m of the player (peer %d)" % peer)

	print("fish signs: jumps by player in 10 minutes %s, worst pass %d us for 4 players" % [str(by_peer), worst_usec])
	check(int(by_peer.get(1, 0)) >= 10 and int(by_peer.get(2, 0)) >= 10, "players by a brook see jumps: %s in 10 minutes (plan: one every 10 to 30 s near a big school)" % str(by_peer))
	check(int(by_peer.get(1, 0)) <= 200, "one player is sent at most one jump per 3 s (%d in 600 s)" % int(by_peer.get(1, 0)))
	check(not by_peer.has(3), "a player 376 m from any water sees no jump")
	check(gap_ok, "no player gets two jumps within 3 s")
	check(on_water, "every jump is on the water, at its surface")
	check(in_school, "every jump is inside a school")
	check(worst_usec < 20000, "a pass for 4 players takes under 20 ms even with the first school lookups (%d us)" % worst_usec)

	# Shadows: the brook players get shallow schools within 40 m; the dry and the deep-river players get none; resent only on change.
	var brook_rows: PackedFloat32Array = PackedFloat32Array()   # the fullest list it was sent (a drifting school's middle can sit on the bank, which has no surface to draw on)

	for rows in shadows.get(1, []):
		if (rows as PackedFloat32Array).size() > brook_rows.size():
			brook_rows = rows

	var near_ok: bool = brook_rows.size() > 0 and brook_rows.size() % 5 == 0
	@warning_ignore("integer_division")
	for s in brook_rows.size() / 5:
		near_ok = near_ok and Vector2(brook_rows[s * 5], brook_rows[s * 5 + 2]).distance_to(Vector2(at1.x + 6.0, at1.y)) <= 40.0 + brook_rows[s * 5 + 3] + 0.5

	check(near_ok, "a player by the brook is sent the schools within 40 m (%d values)" % brook_rows.size())
	check(((shadows.get(3, [PackedFloat32Array()]) as Array).back() as PackedFloat32Array).is_empty(), "a player far from water is sent no shadows")
	check(((shadows.get(4, [PackedFloat32Array()]) as Array).back() as PackedFloat32Array).is_empty(), "the river's 2.5 m of water hides its fish (no shadows deeper than 2 m)")
	check((shadows.get(1, []) as Array).size() >= 2 and (shadows.get(1, []) as Array).size() <= 60, "shadows are resent only when they change: %d sends in 10 minutes of drift, not one every 2 s (300)" % (shadows.get(1, []) as Array).size())

	# A tile not in memory: its cells are skipped and asked for, never read on the spot.
	var asked: Array = []
	signs.ready_at = func(x: float, z: float) -> bool:
		asked.append(Vector2(x, z))
		return false
	var sent_before: int = jumps.size()

	for k in range(600, 630):
		clock[0] = k * 1000
		signs.tick()

	check(jumps.size() == sent_before and not asked.is_empty(), "with the tiles not in memory there are no jumps and the tiles are asked for (%d asks)" % asked.size())
	signs.ready_at = Callable()

	# Rates: a storm and the night make fewer jumps, dawn more than midday; ice none.
	var calm: float = signs.jump_chance(12, 7.0, {"rain": 0.0})
	check(signs.jump_chance(12, 7.0, {"storm": 0.8}) < calm and signs.jump_chance(12, 12.0, {}) < calm and signs.jump_chance(12, 23.0, {}) < calm, "storm, midday and night make fewer jumps than a calm dawn")
	check(signs.jump_chance(3, 7.0, {}) < calm, "a small school jumps less than a big one")
	items.ice = true
	var before: int = jumps.size()

	for k in range(630, 700):
		clock[0] = k * 1000
		signs.tick()

	check(jumps.size() == before, "frozen water makes no jumps")
	items.ice = false

	# Many players: the cost of one pass (each its own place along the brook and the lake).
	var many: Dictionary = {}

	for p in 20:
		many[100 + p] = Vector3(104.0 if p % 2 == 0 else 1100.0 + float(p) * 20.0, 11.0, 40.0 * float(p))

	items.positions = many
	var total_usec: int = 0

	for k in range(700, 760):
		clock[0] = k * 1000
		signs.tick()
		total_usec += signs.last_tick_usec

	print("fish signs: 20 players, average pass %d us (once a second)" % int(total_usec / 60.0))
	check(total_usec / 60.0 < 5000.0, "20 players cost under 5 ms a second on average (%d us)" % int(total_usec / 60.0))

	# The client view: a jump draws a pooled splash with rings and a fish, then clears; the pool stays within its cap; shadows drawn by day,
	# hidden at night, in rain and at Low.
	var view = View.new()
	var now: Array = [12.0, 0.0]
	view.conditions = func() -> Array: return now
	get_root().add_child(view)
	view.setup(2)
	view.jump(Vector3(104.0, 10.4, 300.0), 2 * 4 + 1, 42)
	var splash: Node3D = view.get_node("FishSplash0")
	check(view.jumps_seen == 1 and splash.visible, "a jump shows a splash")
	view._process(0.3)
	var rings_up: int = 0

	for child in splash.get_children():
		if child is MeshInstance3D and child.visible:
			rings_up += 1

	check(rings_up >= 2, "the splash has its ring and the fish in the air at 0.3 s (%d meshes shown)" % rings_up)
	view._process(3.5)
	check(not splash.visible, "the splash clears after about 3 s")

	for k in 12:
		view.jump(Vector3(104.0 + float(k), 10.4, 300.0), 0, k)

	var nodes: int = 0

	for child in view.get_children():
		if child.name.begins_with("FishSplash"):
			nodes += 1

	check(nodes <= 8, "at most 8 splashes at once at High (%d)" % nodes)
	view.set_shadows(PackedFloat32Array([104.0, 10.4, 300.0, 5.0, 2.0, 104.0, 10.4, 330.0, 4.0, 0.0]))
	view._process(0.1)
	check(view.shadows_drawn == 5 + 3, "two schools draw 5 + 3 dark fish by day (%d)" % view.shadows_drawn)
	now[0] = 23.0
	view._process(0.1)
	check(view.shadows_drawn == 0, "no shadows at night")
	now[0] = 12.0
	now[1] = 0.6
	view._process(0.1)
	check(view.shadows_drawn == 0, "no shadows in rain")
	now[1] = 0.0
	view.set_quality(0)
	view._process(0.1)
	check(view.shadows_drawn == 0, "no shadows at Low")
	view.queue_free()

	# The wire: declared, sent by the server, received by the client.
	var net_text: String = FileAccess.get_file_as_string("res://src/stream/terrain_net.gd")
	var server_text: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	var client_text: String = FileAccess.get_file_as_string("res://scenes/terrain_client/terrain_client.gd")
	check(net_text.contains("func fish_jump(at: Vector3, kind: int, seed_value: int)") and net_text.contains("func fish_shadows(rows: PackedFloat32Array)"), "terrain_net declares fish_jump and fish_shadows")
	check(server_text.contains("net.fish_jump.rpc_id(") and server_text.contains("net.fish_shadows.rpc_id(") and server_text.contains("fish_signs.tick()"), "the server sends both and ticks the signs")
	check(client_text.contains("net.fish_jump_received.connect") and client_text.contains("net.fish_shadows_received.connect"), "the client receives both")

	_spear_and_net()
	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)


# Spear and net on a school (24 Nov 2026, Dave: "I dont actually see any fish or signs of fish" and "will we also be able to thow the net at the
# school of fish"): a spear jab with no school near says so plainly and points at the signs, on a miss and when moving; at a school a moving
# player is still told to stand still; a jab into a school takes that school's fish. The net lands where the look meets the water, 2 to 7 m out.
func _spear_and_net() -> void:
	var dir: String = "user://test_fish_signs"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var said: Array = []
	var water = FishWater.new(func(x: float, z: float) -> Array: return probe(x, z))
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_notice = func(_p, text): said.append(text)
	items.game_seconds = func(): return 40.0 * 86400.0 + 8.0 * 3600.0
	items.ground_height = func(_x, _z): return 10.0
	items.water_near = func(_p, _r): return true
	items.water_depth_at = func(_p): return 0.4
	items.water_kind_at = func(x: float, z: float) -> Dictionary: return water.water_kind_at(x, z, 0)
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "fishsigns-key-0001")
	var cfg: Dictionary = items._fishing_data()
	var schools = items._fish_schools()
	var day: int = 40
	var centres: Array = []   # [centre, radius, species] of the brook's schools

	for cz in 7:
		for s in schools.schools(Vector2i(0, cz), day, items._season_of(Vector3(104.0, 10.0, 64.0 + 128.0 * cz)), 12, items._now_game_s()):
			if (s["centre"] as Vector2).x >= 100.0 and (s["centre"] as Vector2).x < 108.0:
				centres.append([s["centre"], float(s["radius"]), str(s["species"])])

	check(not centres.is_empty(), "the brook has schools to spear (%d)" % centres.size())

	if centres.is_empty():
		return

	var lone_z: float = -1.0   # a stretch of brook with no school within 2 radii + 3 m

	for k in 160:
		var z: float = 5.0 + float(k) * 5.0
		var clear: bool = true

		for c in centres:
			clear = clear and (c[0] as Vector2).distance_to(Vector2(104.0, z)) > float(c[1]) * 2.0 + 3.0

		for cz in range(-1, 8):
			for cx in range(-1, 2):
				for s in schools.schools(Vector2i(cx, cz), day, "summer", 12, items._now_game_s()):
					clear = clear and (s["centre"] as Vector2).distance_to(Vector2(104.0, z)) > float(s["radius"]) * 2.0 + 3.0

		if clear:
			lone_z = z
			break

	var inv = items.inventory_of(1)
	var spear: int = items.table.number_of("fishing_spear")
	items.action(1, Net.ACT_ADMIN_GIVE, spear, 0, 1, Vector3.ZERO)
	var slot: int = inv.numbers.find(spear)
	check(slot >= 0, "the player holds a Fishing spear")
	var no_fish: String = str(cfg["spear"]["say_no_fish"])

	if lone_z >= 0.0:
		items.report_position(1, Vector3(102.5, 10.0, lone_z))
		items._moving[1] = 0.0
		said.clear()

		for n in 6:
			items._last_fish.clear()
			items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3(104.0, 10.0, lone_z))

		check(said.has(no_fish) and not said.has(str(cfg["spear"]["say_miss"])), "a jab with no school near says there are no fish here, not just \"You miss\" (%s)" % str(said))
		items._moving[1] = 1.0
		items.report_position(1, Vector3(102.5, 10.0, lone_z), Vector3(1.2, 0.0, 0.0))
		said.clear()
		items._last_fish.clear()
		items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3(104.0, 10.0, lone_z))
		check(said == [no_fish], "walking with no school near, it still says there are no fish here, not \"stand still\" (%s)" % str(said))
	else:
		check(false, "found a stretch of brook with no school near")

	var c: Vector2 = centres[0][0]
	items.report_position(1, Vector3(c.x - 1.5, 10.0, c.y), Vector3(1.2, 0.0, 0.0))
	items._moving[1] = 1.0
	said.clear()
	items._last_fish.clear()
	items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3(c.x, 10.0, c.y))
	check(said == [str(cfg["spear"]["say_move"])], "walking at a school, it says stand still (%s)" % str(said))
	items.report_position(1, Vector3(c.x - 1.5, 10.0, c.y), Vector3.ZERO)
	items._moving[1] = 0.0
	var wear0: int = inv.wear[slot]
	said.clear()
	var got: Dictionary = {}
	var fish_ids: Array = []

	for water_kind in cfg.get("species", {}):
		for row in cfg["species"][water_kind]:
			fish_ids.append(str(row[0]))

	for sp in ["trout", "perch", "salmon", "pike", "carp", "minnow", "herring", "cod"]:
		fish_ids.append(sp)

	# Lane B 24 Nov 2026 ("trout 8, perch 1"): the perch was a stray caught by the jabs above with no school near (the odds there are
	# unchanged), counted with these. Only what these jabs land is counted. And each catch takes one fish off the cell's stock, a school's size
	# being its share of it, so the cell is put back to full before every jab: every jab here is into the same school.
	var had: Dictionary = {}   # what the pack held before: the jabs with no school near above can land a stray fish of the water

	for f in fish_ids:
		if items.table.number_of(f) > 0:
			had[f] = inv.count_of(items.table.number_of(f))

	var cell: Vector2i = items._fish_cell(Vector3(c.x, 10.0, c.y))
	var full: Array = [items.fish_stock(cell), items._unix()]

	for n in 40:
		items._fish_stock["%d,%d" % [cell.x, cell.y]] = full.duplicate()
		items._last_fish.clear()
		items._moving[1] = 0.0
		items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3(c.x, 10.0, c.y))

	for f in fish_ids:
		if items.table.number_of(f) > 0 and inv.count_of(items.table.number_of(f)) > int(had.get(f, 0)):
			got[f] = inv.count_of(items.table.number_of(f)) - int(had.get(f, 0))

	check(inv.wear[slot] > wear0 and not said.has(str(cfg["spear"]["say_move"])), "a player standing still jabs")
	check(not said.has(no_fish), "jabs into a school never say there are no fish")
	check(got.size() == 1 and got.has(centres[0][2]), "a jab into a school takes that school's fish (%s, school of %s)" % [str(got), centres[0][2]])

	# Fished out: with no fish left the school is gone and a jab there says so.
	items._fish_stock["%d,%d" % [cell.x, cell.y]] = [0, items._unix()]
	items._last_fish.clear()
	said.clear()
	items.action(1, Net.ACT_FISH, slot, 0, 0, Vector3(c.x, 10.0, c.y))
	var out_said: Array = said.duplicate()
	said.clear()
	check(out_said == [no_fish], "a school fished out is gone, and a jab there says there are no fish (%s)" % str(out_said))

	# The net lands where the look meets the water: looking down steeply near, gently far, level at 6 m.
	var eye: Vector3 = Vector3(0.0, 11.6, 0.0)
	var near_land: Vector3 = HeldItem.net_landing(eye, Vector3(0.0, -0.8, -0.6).normalized())
	var mid_land: Vector3 = HeldItem.net_landing(eye, Vector3(0.0, -0.32, -1.0).normalized())
	var far_land: Vector3 = HeldItem.net_landing(eye, Vector3(0.0, -0.1, -1.0).normalized())
	var level: Vector3 = HeldItem.net_landing(eye, Vector3(0.0, 0.2, -1.0).normalized())
	check(absf(near_land.z + 2.0) < 0.01 and absf(near_land.y - 10.0) < 0.01, "looking steeply down, the net lands 2 m out (%s)" % str(near_land))
	check(absf(mid_land.z + 5.0) < 0.05, "looking a little down, it lands where the look meets the water, 5 m out (%s)" % str(mid_land))
	check(absf(far_land.z + 7.0) < 0.01 and absf(level.z + 6.0) < 0.01, "looking nearly level it lands at most 7 m out, and looking up 6 m as before (%s, %s)" % [str(far_land), str(level)])
