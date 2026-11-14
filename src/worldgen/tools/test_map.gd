extends SceneTree

# The character-discovered charcoal Map (protocol 120, WP-MAP; docs/design/PLAYER_CARTOGRAPHY_MAP_DESIGN.md s4): a new character's map
# is blank; walking records only the ground near the path, per character, and it survives a quit and rejoin; Mapping practice comes
# only from new ground; a skill gain alone changes nothing, a revisit at the higher skill redraws; blocks meet without a seam; nothing
# about unsurveyed ground is ever sent; the survey and the sketch are timed. Also the mapping skill through the real skills system.
#   godot --headless --path . --script res://src/worldgen/tools/test_map.gd

const MapScript := preload("res://src/stream/server_map.gd")
const Codec := preload("res://src/shared/map_codec.gd")
const KnowledgeScript := preload("res://src/client/map_knowledge.gd")
const Sketch := preload("res://src/client/map_sketch.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

var failures: int = 0
var observed: Array = []      # every (x, z) the server looked at
var practised: Array = []     # peers practised
var goaled: Array = []        # [peer, goal event name] the map raised
var skill: Dictionary = {}    # peer -> Mapping level the fake skill system reports
var keys: Dictionary = {}     # peer -> key
var cave: bool = false
var walk_ms: int = 0      # the position clock: each report is 1 s after the last
var clock_ms: int = 0     # the send clock: each look at the sends is 10 s later (past resend_s)
var held: bool = false   # ground west of x = 0 "not made yet" while set


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


# A made-up world: a slope rising 1 m every 4 m east, a lake west of x = -200, trees every 10 m north of z = 300.
func ground(x: float, z: float) -> Array:
	observed.append(Vector2(x, z))

	if x > 5000.0 or (held and x < 0.0):
		return []   # "not loaded" (or its flora chunk not made yet)

	return [x * 0.25 + 3.7, Codec.WATER_INLAND if x < -200.0 else Codec.WATER_NONE]


func trees(point: Vector3, radius: float) -> Array:
	var out: Array = []

	for gx in range(int(floor((point.x - radius) / 10.0)), int(ceil((point.x + radius) / 10.0)) + 1):
		for gz in range(int(floor((point.z - radius) / 10.0)), int(ceil((point.z + radius) / 10.0)) + 1):
			if gz * 10 > 300:
				out.append(Vector3(gx * 10.0 + 1.0, 0.0, gz * 10.0 + 1.0))

	return out


func make(dir: String):
	var m = MapScript.new()
	m.key_of = func(peer): return keys.get(peer, "")
	m.skill_of = func(peer): return skill.get(peer, 1.0)
	m.practice = func(peer): practised.append(peer); return 1.0
	m.goal_event = func(peer, name): goaled.append([peer, name])
	m.observe = ground
	m.trees_near = trees
	m.in_cave = func(_p): return cave
	m.now_msec = func(): walk_ms += 1000; return walk_ms   # one second between reports
	m.setup(dir)
	return m


func sent_cells(m, peer: int) -> Dictionary:
	var out: Dictionary = {}

	for _pass in 50:
		clock_ms += 10000
		var batch: Array = m.updates_for(peer, clock_ms)

		if batch.is_empty():
			break

		for u in batch:
			out[Vector2i(int(u[0]), int(u[1]))] = Codec.decode(u[2])

	return out


func cell_centre(block: Vector2i, idx: int, cfg: Dictionary) -> Vector2:
	var per: int = int(cfg["block_cells"])
	var size: float = float(cfg["cell_m"])
	return Vector2((float(block.x * per + idx % per) + 0.5) * size, (float(block.y * per) + floor(float(idx) / float(per)) + 0.5) * size)


func _init() -> void:
	var dir: String = "user://test_map"
	DirAccess.make_dir_recursive_absolute(dir + "/maps")

	for file in DirAccess.get_files_at(dir + "/maps"):
		DirAccess.remove_absolute(dir + "/maps/" + file)

	var m = make(dir)
	var cfg: Dictionary = m.cfg
	check(float(cfg.get("cell_m", 0)) > 0.0 and int(cfg.get("block_cells", 0)) > 0, "data/map.json loads")
	var radius: float = float(cfg["survey_radius_m"])

	# Codec round trip.
	var sample: Dictionary = {0: [1, -12.0, 1, 0], 1023: [100, 2047.0, 2, 3], 37: [55, 3.0, 0, 2]}
	var back: Dictionary = Codec.decode(Codec.encode(sample))
	check(back.size() == 3 and int(back[1023][1]) == 2047 and int(back[0][1]) == -12 and int(back[37][0]) == 55 and int(back[1023][3]) == 3, "the codec keeps every field (%s)" % str(back))
	check(Codec.decode(PackedByteArray([1, 2, 3])).is_empty(), "a damaged block decodes to nothing")
	check(MapScript.water_kind(1) == Codec.WATER_SEA and MapScript.water_kind(3) == Codec.WATER_INLAND and MapScript.water_kind(8) == Codec.WATER_NONE and MapScript.water_kind(0) == Codec.WATER_NONE, "water classes map to sea, inland water and dry ground")

	# 1. A new character: nothing is known, nothing is sent, the sketch is blank paper.
	keys[1] = "map-key-0001"
	keys[2] = "map-key-0002"
	check(sent_cells(m, 1).is_empty(), "a new character is sent no map at all")
	var fresh = KnowledgeScript.new()
	check(fresh.is_empty(), "the client starts with a blank map")
	var blank: Image = Sketch.render_block(fresh, Vector2i(0, 0))
	check(blank.get_used_rect().size == Vector2i.ZERO, "a blank map draws no marks")

	# 2. Walking records the ground near the path, nothing else.
	var path: Array = []

	for k in 30:
		path.append(Vector3(100.0 + float(k) * 6.0, 10.0, 100.0))

	for p in path:
		m.note_position(1, p)

	var surveyed_at: Array = []   # positions that actually surveyed (every survey_step_m; the first report only sets the start)
	var last: Variant = path[0]

	for p in path:
		if Vector2(p.x, p.z).distance_to(Vector2(last.x, last.z)) >= float(cfg["survey_step_m"]):
			surveyed_at.append(p)
			last = p

	check(m.surveys == surveyed_at.size(), "a survey every survey_step_m walked (%d, expected %d)" % [m.surveys, surveyed_at.size()])
	var cells: Dictionary = sent_cells(m, 1)
	var count: int = 0
	var far: int = 0

	for block in cells:
		for idx in cells[block]:
			count += 1
			var centre: Vector2 = cell_centre(block, int(idx), cfg)
			var near: bool = false

			for p in surveyed_at:
				near = near or centre.distance_to(Vector2(p.x, p.z)) <= radius + 0.01

			if not near:
				far += 1

	check(count > 20 and far == 0, "only cells within the survey radius of the path are sent (%d cells, %d too far)" % [count, far])
	var outside: int = 0

	for o in observed:
		var near: bool = false

		for p in surveyed_at:
			near = near or o.distance_to(Vector2(p.x, p.z)) <= radius + 0.01

		if not near:
			outside += 1

	check(outside == 0, "the server never even looks at ground away from the path (%d looks outside)" % outside)
	check(sent_cells(m, 1).is_empty(), "nothing new is sent while nothing changed")
	var new_ground: int = goaled.count([1, "map_surveyed"])
	check(new_ground >= 1 and new_ground <= m.surveys and goaled.count([1, "map_redrawn"]) == 0 and goaled.size() == new_ground, "a survey of new ground raises one map_surveyed goal event at most, and nothing is redrawn (%d for %d surveys)" % [new_ground, m.surveys])

	# 3. Player-specific: the other character knows nothing of it.
	check(sent_cells(m, 2).is_empty() and m.blocks_of("map-key-0002").is_empty(), "another character's map stays blank")

	# 4. Practice only from new ground: once per cells_per_practice new cells, never for standing still or walking known ground.
	var per_practice: int = int(cfg["cells_per_practice"])
	check(practised.size() >= 1 and practised.size() <= int(floor(float(count) / float(per_practice))), "practice from new cells only (%d practices for %d cells)" % [practised.size(), count])
	var before: int = practised.size()
	var surveys_before: int = m.surveys

	for k in 200:
		m.note_position(1, Vector3(274.0, 10.0, 100.0 + float(k % 3) * 0.5))   # standing about at the end of the walk

	check(m.surveys == surveys_before and practised.size() == before, "standing still surveys nothing and practises nothing")

	for k in path.size() - 2:
		m.note_position(1, path[path.size() - 1 - k])   # back the way it came, not past the first survey point (x = 112)

	for p in path.slice(2):
		m.note_position(1, p)

	check(m.surveys > surveys_before and practised.size() == before, "walking back over known ground practises nothing (%d -> %d)" % [before, practised.size()])
	check(sent_cells(m, 1).is_empty(), "and changes nothing")

	# 5. A skill gain alone changes nothing; a revisit at the higher skill redraws, with finer heights; a small gain does not.
	var block0: Vector2i = Vector2i(0, 0)
	var known_q: Dictionary = {}

	for idx in m.blocks_of("map-key-0001")[block0]:
		known_q[idx] = int(m.blocks_of("map-key-0001")[block0][idx][0])

	skill[1] = 60.0
	sent_cells(m, 1)   # drain
	check(sent_cells(m, 1).is_empty(), "a skill gain alone sends nothing new")

	for idx in known_q:
		check(int(m.blocks_of("map-key-0001")[block0][idx][0]) == int(known_q[idx]), "a skill gain alone redraws no known cell")
		break

	var practices: int = practised.size()
	var goal_events: int = goaled.size()
	m._last_at.erase(1)   # start the walk afresh, so the revisit surveys from the same points as the first walk

	for p in path:
		m.note_position(1, p)

	var redrawn: Dictionary = sent_cells(m, 1)
	var at60: int = 0
	var at1: int = 0

	for idx in redrawn.get(block0, {}):
		if known_q.has(idx):
			if int(redrawn[block0][idx][0]) == 60:
				at60 += 1
			else:
				at1 += 1

	check(at60 > 20 and at1 == 0, "revisiting at Mapping 60 redraws the old cells at 60 (%d at 60, %d left)" % [at60, at1])
	check(practised.size() == practices, "a redraw practises nothing")
	var raised: Array = goaled.slice(goal_events)
	check(raised.count([1, "map_redrawn"]) >= 1 and raised.count([1, "map_surveyed"]) == 0, "a revisit at a higher skill raises map_redrawn, not map_surveyed (%s)" % str(raised))
	var rough: Array = m.cell_rows({0: [1, 17.0, 0, 3]})[0]
	var sharp: Array = m.cell_rows({0: [100, 17.0, 0, 3]})[0]
	check(absf(float(sharp[1]) - 17.0) < 0.01 and absf(float(rough[1]) - 17.0) > 2.0 and int(rough[3]) == 1 and int(sharp[3]) == 3, "Mapping 1 is sent coarse (%s), Mapping 100 exact (%s)" % [str(rough), str(sharp)])
	skill[1] = 61.0
	m._last_at.erase(1)

	for p in path:
		m.note_position(1, p)

	check(sent_cells(m, 1).is_empty(), "a gain under improve_min_levels does not redraw")

	# 6. Block boundary: a walk across x = 512 m fills both blocks, with matching neighbour indices.
	var edge: float = float(cfg["block_cells"]) * float(cfg["cell_m"])

	for k in 12:
		m.note_position(1, Vector3(edge - 40.0 + float(k) * 8.0, 10.0, 900.0))

	var b: Dictionary = m.blocks_of("map-key-0001")
	var per: int = int(cfg["block_cells"])
	var row_z: int = int(floor(900.0 / float(cfg["cell_m"]))) - per
	check(b.has(Vector2i(0, 1)) and b.has(Vector2i(1, 1)), "a walk over the block edge records both blocks")
	check(b.get(Vector2i(0, 1), {}).has((per - 1) + row_z * per) and b.get(Vector2i(1, 1), {}).has(0 + row_z * per), "the cells either side of the edge are both there")

	# 7. A jump (respawn, teleport, or a client claiming one) surveys nothing where it lands; walking on from there does.
	var s_jump: int = m.surveys
	m.note_position(1, Vector3(3000.0, 10.0, 3000.0))
	check(m.surveys == s_jump and not m.blocks_of("map-key-0001").has(Vector2i(5, 5)), "a jump surveys nothing where it lands")
	m.note_position(1, Vector3(3010.0, 10.0, 3000.0))
	check(m.surveys == s_jump + 1 and m.blocks_of("map-key-0001").has(Vector2i(5, 5)), "walking on from there surveys")

	# A dash nobody can walk (40 m/s claimed) surveys nothing either.
	var s_dash: int = m.surveys
	walk_ms -= 800   # the next report comes 0.2 s after this one
	m.note_position(1, Vector3(3018.0, 10.0, 3000.0))
	check(m.surveys == s_dash, "a claimed dash at 40 m/s surveys nothing")

	# A connection's first position only sets the start.
	m._last_at.erase(1)
	var s_first: int = m.surveys
	m.note_position(1, Vector3(-4000.0, 10.0, 4000.0))
	check(m.surveys == s_first, "the first position of a connection surveys nothing")

	# Caves: nothing to survey.
	m._last_at.erase(1)
	m.note_position(1, Vector3(-3010.0, -20.0, -3000.0))
	cave = true
	var s0: int = m.surveys
	m.note_position(1, Vector3(-3000.0, -20.0, -3000.0))
	check(m.surveys == s0 and not m.blocks_of("map-key-0001").has(Vector2i(-6, -6)), "no survey inside a cave")
	cave = false

	# Ground not loaded yet (or its trees not made yet): skipped, surveyed on a later step once it is.
	m._last_at.erase(1)
	m.note_position(1, Vector3(5490.0, 10.0, 0.0))
	var s_unloaded: int = m.surveys
	m.note_position(1, Vector3(5500.0, 10.0, 0.0))
	check(m.surveys == s_unloaded + 1 and not m.blocks_of("map-key-0001").has(Vector2i(10, 0)), "ground that is not loaded is not invented")
	m._last_at.erase(1)
	m.note_position(1, Vector3(-1000.0, 10.0, 1990.0))
	held = true
	m.note_position(1, Vector3(-1000.0, 10.0, 2000.0))
	var deferred: Vector2i = Vector2i(-2, 3)
	check(not m.blocks_of("map-key-0001").has(deferred), "a cell whose flora is not made yet is not recorded (no permanent false 'no trees')")
	held = false
	m.note_position(1, Vector3(-1000.0, 10.0, 2009.0))
	check(m.blocks_of("map-key-0001").has(deferred), "the next step records it once it is made")

	# 8. Quit and rejoin: saved per character, read back, sent again in full to the new connection.
	var total: int = 0

	for blk in m.blocks_of("map-key-0001"):
		total += m.blocks_of("map-key-0001")[blk].size()

	m.forget_peer(1)
	check(not m._records.has("map-key-0001"), "a character's record is unloaded when it leaves")
	var files: PackedStringArray = DirAccess.get_files_at(dir + "/maps")
	check(files.size() == 1 and not str(files[0]).contains("map-key"), "one file, not named by the secret key (%s)" % str(files))
	var m2 = make(dir)
	keys[7] = "map-key-0001"
	var again: Dictionary = sent_cells(m2, 7)
	var total2: int = 0

	for blk in again:
		total2 += again[blk].size()

	check(total2 == total and total > 0, "the map comes back after quit and rejoin (%d of %d cells)" % [total2, total])

	# 9. Deleting the character deletes its map.
	m2.forget_peer(7)
	m2.forget_key("map-key-0001")
	check(DirAccess.get_files_at(dir + "/maps").is_empty() and m2.blocks_of("map-key-0001").is_empty(), "a deleted character's map goes with it")

	# 10. The client store and the sketch: cells across blocks, marks only on known ground, no seam, rough vs accurate.
	var k1 = KnowledgeScript.new()
	var slope: Dictionary = {}

	for idx in per * per:
		var cx: int = idx % per
		slope[idx] = [50, float(cx) * 3.0, Codec.WATER_NONE, 1 if cx % 5 == 0 else 0]

	var slope2: Dictionary = {}

	for idx in per * per:
		slope2[idx] = [50, float(per + idx % per) * 3.0, Codec.WATER_INLAND if idx % per > 20 else Codec.WATER_NONE, 0]

	var changed: Array = []
	k1.block_changed.connect(func(blk): changed.append(blk))
	k1.receive(0, 0, Codec.encode(slope))
	k1.receive(1, 0, Codec.encode(slope2))
	check(changed.size() == 2 and k1.cell_at(Vector2i(per, 0)).size() == 4 and k1.cell_at(Vector2i(-1, 0)).is_empty(), "the client finds cells across blocks and nothing elsewhere")
	var a: Image = Sketch.render_block(k1, Vector2i(0, 0))
	var c: Image = Sketch.render_block(k1, Vector2i(1, 0))
	var none: Image = Sketch.render_block(k1, Vector2i(0, 1))
	check(a.get_used_rect().size != Vector2i.ZERO and none.get_used_rect().size == Vector2i.ZERO, "known ground gets marks, unknown ground none")
	var size: int = per * Sketch.PX
	var half: int = int(size / 2.0)
	var seam: Image = Sketch.render_rect(k1, Vector2i(half, 0), Vector2i(size, size))
	var mismatch: int = 0

	for y in size:
		for x in size:
			var whole: Color = seam.get_pixel(x, y)
			var part: Color = a.get_pixel(x + half, y) if x < half else c.get_pixel(x - half, y)

			if absf(whole.a - part.a) > 0.01:
				mismatch += 1

	check(mismatch == 0, "two blocks drawn apart match one drawing across their edge (%d pixels differ)" % mismatch)
	var k_rough = KnowledgeScript.new()
	var k_fine = KnowledgeScript.new()
	var hills_r: Dictionary = {}
	var hills_f: Dictionary = {}

	for idx in per * per:
		var hx: float = 20.0 * sin(float(idx % per) * 0.4) + 15.0 * cos(floor(float(idx) / float(per)) * 0.3)
		hills_r[idx] = [1, round(hx / 10.0) * 10.0, 0, 0]
		hills_f[idx] = [100, round(hx), 0, 0]

	k_rough.set_block(Vector2i(0, 0), hills_r)
	k_fine.set_block(Vector2i(0, 0), hills_f)
	var r_img: Image = Sketch.render_block(k_rough, Vector2i(0, 0))
	var f_img: Image = Sketch.render_block(k_fine, Vector2i(0, 0))
	var r_ink: float = 0.0
	var f_ink: float = 0.0
	var differ: int = 0

	for y in size:
		for x in size:
			r_ink += r_img.get_pixel(x, y).a
			f_ink += f_img.get_pixel(x, y).a

			if absf(r_img.get_pixel(x, y).a - f_img.get_pixel(x, y).a) > 0.05:
				differ += 1

	check(differ > int(size * size / 20.0) and f_ink > r_ink, "the same hills sketch rougher and lighter at Mapping 1 than at 100 (%d pixels differ, ink %.0f vs %.0f)" % [differ, r_ink, f_ink])

	# 11. The real skills system: "survey" practises Mapping.
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_skills = func(_p, _a, _r): pass
	items.game_seconds = func(): return 1000.0
	var idir: String = "user://test_map_items"
	DirAccess.make_dir_recursive_absolute(idir)
	items.setup(ItemTableScript.load_default(), idir)
	items.peer_connected_hello(1, "map-key-0009")
	check(absf(items.working_level(1, "mapping") - 1.0) < 0.001, "a new character's Mapping is 1")
	check(items.practice(1, "survey") > 0.0 and items._characters["map-key-0009"]["skills"].has("mapping"), "the survey action practises Mapping")
	# The goal events reach the real goal counters (event:map_surveyed), and Admin mode counts nothing (GA-54).
	var gm = make("")
	keys[1] = "map-key-0009"
	gm.goal_event = func(peer, name): items._goal_event(peer, name)

	for k in 6:
		gm.note_position(1, Vector3(-900.0 + float(k) * 9.0, 10.0, -900.0))

	var counts: Dictionary = items._goal_state_of(1).get("goal_counts", {})
	var surveyed: int = int(counts.get("event:map_surveyed", 0))
	check(surveyed == gm.surveys and surveyed > 0, "a survey of new ground counts once in the character's goal counters (%d for %d surveys)" % [surveyed, gm.surveys])
	items.admin_ok = func(_p): return true
	items.admin_mode_on = func(_p): return true

	for k in range(6, 12):
		gm.note_position(1, Vector3(-900.0 + float(k) * 9.0, 10.0, -900.0))

	check(int(items._goal_state_of(1)["goal_counts"].get("event:map_surveyed", 0)) == surveyed, "in Admin mode mapping counts toward no goal")
	items.admin_ok = Callable()
	items.admin_mode_on = Callable()
	var forgot: Array = []
	items.forgot_key = func(key): forgot.append(key)
	items.peer_connected_hello(2, "map-key-0010")
	items.peer_left(1)
	check(items.forget_key(2, "map-key-0009") and forgot == ["map-key-0009"], "deleting a character calls the map hook")

	# 12. Cost: a survey and one block's sketch.
	var big = make("")
	keys[50] = "map-key-bench"
	var started: int = Time.get_ticks_usec()

	for k in 500:
		big.note_position(50, Vector3(float(k) * 8.0 - 2000.0, 10.0, float(k % 40) * 8.0))

	var survey_us: float = float(Time.get_ticks_usec() - started) / float(maxi(big.surveys, 1))
	started = Time.get_ticks_usec()
	var bytes: int = 0

	for u in sent_cells_raw(big, 50):
		bytes += (u as PackedByteArray).size()

	var send_us: int = Time.get_ticks_usec() - started
	started = Time.get_ticks_usec()
	Sketch.render_block(k_fine, Vector2i(0, 0))
	var sketch_us: int = Time.get_ticks_usec() - started
	print("Map cost: %.0f us a survey (%d surveys), whole map send %d us %d bytes, one block sketch %d us" % [survey_us, big.surveys, send_us, bytes, sketch_us])
	check(survey_us < 20000.0, "a survey stays cheap (%.0f us)" % survey_us)
	check(sketch_us < 1500000, "a block sketch stays under 1.5 s even here (%d us; the page draws one block a frame at most)" % sketch_us)
	print("map: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func sent_cells_raw(m, peer: int) -> Array:
	var out: Array = []

	for _pass in 200:
		clock_ms += 10000
		var batch: Array = m.updates_for(peer, clock_ms)

		if batch.is_empty():
			break

		for u in batch:
			out.append(u[2])

	return out
