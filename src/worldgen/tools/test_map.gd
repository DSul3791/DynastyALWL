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
const TrailCodec := preload("res://src/shared/trail_codec.gd")
const Net := preload("res://src/stream/terrain_net.gd")

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
	check(MapScript.water_kind(1) == Codec.WATER_SEA and MapScript.water_kind(2) == Codec.WATER_INLAND and MapScript.water_kind(9) == Codec.WATER_NONE and MapScript.water_kind(0) == Codec.WATER_NONE, "water classes map to sea, inland water and dry ground")

	# 1. A new character: nothing is known, nothing is sent, the sketch is blank paper.
	keys[1] = "map-key-0001"
	keys[2] = "map-key-0002"
	check(sent_cells(m, 1).is_empty(), "a new character is sent no map at all")
	var fresh = KnowledgeScript.new()
	check(fresh.is_empty(), "the client starts with a blank map")
	var blank: Dictionary = Sketch.render_block(fresh, Vector2i(0, 0))
	check(blank["strokes"].is_empty() and blank["wash"].get_used_rect().size == Vector2i.ZERO, "a blank map draws no marks")

	# Trap marks (protocol 150): the client keeps the set the server sent, drops rows it has no mark for, and says when it changed.
	var told: Array = [0]
	fresh.traps_changed.connect(func() -> void: told[0] += 1)
	fresh.set_traps([[10.5, -4.0, "snare_trap"], [3, 4, "bird_trap_set"], [1.0, 2.0, "wall"], "junk", [1.0]])
	check(fresh.traps.size() == 2 and fresh.traps[0][0] == Vector2(10.5, -4.0) and str(fresh.traps[1][1]) == "bird_trap_set" and told[0] == 1, "the Map keeps a snare and a Bird trap mark and drops bad rows (%s)" % str(fresh.traps))
	fresh.set_traps([])
	check(fresh.traps.is_empty() and told[0] == 2 and fresh.is_empty(), "an empty set clears the marks and reveals no ground")

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

	# 8b. A save re-encodes only changed blocks (audit 18 Nov 2026 finding 11): cells added to a block after one save must reach the next.
	m2.note_position(7, Vector3(-1007.0, 10.0, 2004.0))   # the first report only sets the start
	m2.note_position(7, Vector3(-1000.0, 10.0, 2009.0))   # one surveyed step: the record is dirty, so this save encodes and keeps each block's text
	m2.save()
	check(not bool(m2._records["map-key-0001"].get("dirty", true)), "the primed save ran")
	var sizes: Dictionary = {}

	for blk in m2.blocks_of("map-key-0001"):
		sizes[blk] = m2.blocks_of("map-key-0001")[blk].size()

	for step in range(1, 7):
		m2.note_position(7, Vector3(-1000.0 + 7.0 * float(step), 10.0, 2009.0 + 5.0 * float(step)))

	var grown: Vector2i = Vector2i(999999, 999999)

	for blk in m2.blocks_of("map-key-0001"):
		if sizes.has(blk) and m2.blocks_of("map-key-0001")[blk].size() > int(sizes[blk]):
			grown = blk

	check(grown != Vector2i(999999, 999999), "walking on adds cells to a block that was already saved")
	var grown_size: int = m2.blocks_of("map-key-0001").get(grown, {}).size()
	m2.save()
	var m3 = make(dir)
	keys[8] = "map-key-0001"
	sent_cells(m3, 8)
	check(m3.blocks_of("map-key-0001").get(grown, {}).size() == grown_size, "the later cells of an already-saved block come back after a reload (%d of %d)" % [m3.blocks_of("map-key-0001").get(grown, {}).size(), grown_size])
	m3.forget_peer(8)
	keys.erase(8)

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
	var a: Dictionary = Sketch.render_block(k1, Vector2i(0, 0))
	var none: Dictionary = Sketch.render_block(k1, Vector2i(0, 1))
	check(not a["strokes"].is_empty() and none["strokes"].is_empty() and none["wash"].get_used_rect().size == Vector2i.ZERO and a["wash"].get_used_rect().size != Vector2i.ZERO, "known ground gets ink and a wash, unknown ground none")
	var size: int = per * Sketch.PX
	# A lake shore running across the edge between two blocks: the line each block draws ends where its neighbour's starts.
	var k_seam = KnowledgeScript.new()

	for bx in 2:
		var seam_cells: Dictionary = {}

		for idx in per * per:
			var gx: int = bx * per + idx % per
			var gz: int = floori(float(idx) / float(per))
			seam_cells[idx] = [60, 5.0, Codec.WATER_INLAND if absi(gx - gz - 8) < 5 else Codec.WATER_NONE, 0]

		k_seam.set_block(Vector2i(bx, 0), seam_cells)

	var left: Array = edge_points(Sketch.render_block(k_seam, Vector2i(0, 0)), float(size))
	var right: Array = edge_points(Sketch.render_block(k_seam, Vector2i(1, 0)), float(size))
	var unmatched: int = 0

	for p in left:
		var hit: bool = false

		for o in right:
			hit = hit or (p as Vector2).distance_to(o) < 0.01

		unmatched += 0 if hit else 1

	check(left.size() >= 2 and left.size() == right.size() and unmatched == 0, "a shore crossing a block edge meets its neighbour's line there (%d ends left, %d right, %d unmatched)" % [left.size(), right.size(), unmatched])
	var batches: Array = Sketch.render_block(k_seam, Vector2i(0, 0))["batches"]
	check(batches.size() > 0 and batches.size() < 30, "a block's ink goes to the page in a few batches (%d)" % batches.size())
	var k_rough = KnowledgeScript.new()
	var k_fine = KnowledgeScript.new()
	var hills_r: Dictionary = {}
	var hills_f: Dictionary = {}

	for idx in per * per:
		var hx: float = 40.0 * sin(float(idx % per) * 0.3) + 30.0 * cos(floor(float(idx) / float(per)) * 0.25)
		hills_r[idx] = [1, round(hx / 10.0) * 10.0, Codec.WATER_INLAND if hx < -40.0 else 0, 0]
		hills_f[idx] = [100, round(hx), Codec.WATER_INLAND if hx < -40.0 else 0, 0]

	k_rough.set_block(Vector2i(0, 0), hills_r)
	k_fine.set_block(Vector2i(0, 0), hills_f)
	var r_ink: Array = ink_of(Sketch.render_block(k_rough, Vector2i(0, 0)))
	var f_ink: Array = ink_of(Sketch.render_block(k_fine, Vector2i(0, 0)))
	check(r_ink[0] > 0.0 and f_ink[1] > r_ink[1] * 1.15, "the same ground is inked lighter at Mapping 1 than at 100 (mean ink %.2f vs %.2f)" % [r_ink[1], f_ink[1]])
	sketch_feature_checks(per)

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
	trails_checks()
	landmark_checks()
	print("map: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# Landmarks (Dave 23 Nov 2026 play test, protocol 166): what is seen near goes on the map in surveyed cells only, one mark a kind within merge_m,
# gone when it is gone (but a good fishing spot stays), names grow with what is seen, paths and rivers, the save keeps them and an old save
# loads, and the world items a person would mark come from server_items.
func landmark_checks() -> void:
	var dir: String = "user://test_map_marks"
	DirAccess.make_dir_recursive_absolute(dir + "/maps")

	for file in DirAccess.get_files_at(dir + "/maps"):
		DirAccess.remove_absolute(dir + "/maps/" + file)

	var world: Array = [[["campfire", 1010.0, 1000.0, ""], ["bog_iron", 1030.0, 1005.0, "Bog iron"], ["bog_iron", 1040.0, 1010.0, "Bog iron"],
		["fruit:apple", 1000.0, 1020.0, "Apple trees"], ["path", 1000.0, 1000.0, ""], ["path", 1016.0, 1000.0, ""], ["road", 1032.0, 1000.0, ""],
		["cave", 3000.0, 3000.0, "Cave"]]]
	var m = make(dir)
	keys[70] = "map-key-marks"
	m.landmarks_near = func(_p, _r): return world[0]

	for k in 4:
		m.note_position(70, Vector3(990.0 + float(k) * 8.0, 10.0, 1000.0))

	var rows: Array = all_marks(m, "map-key-marks")
	var kinds: Array = rows.map(func(r): return str(r[0]))
	check(kinds.count("campfire") == 1 and kinds.count("bog_iron") == 1 and kinds.count("fruit:apple") == 1 and not kinds.has("cave"), "what is seen near goes on the map once a kind within merge_m, nothing far off (%s)" % str(kinds))
	var rec: Dictionary = m._record("map-key-marks")
	var path_cells: int = 0

	for block in rec["blocks"]:
		path_cells += rec["blocks"][block].get("paths", {}).size()

	check(path_cells == 3, "the path and road cells are kept (%d)" % path_cells)
	# One thing in one place is its own mark: two campfires 10 m apart are two, two bog iron patches 10 m apart are one field.
	var pair_world: Array = [["campfire", 1010.0, 1000.0, ""], ["campfire", 1020.0, 1000.0, ""], ["bog_iron", 1030.0, 1005.0, "Bog iron"], ["bog_iron", 1040.0, 1005.0, "Bog iron"]]
	var pair_m = make("")
	keys[72] = "map-key-pair"
	pair_m.landmarks_near = func(_p, _r): return pair_world

	for k in 4:
		pair_m.note_position(72, Vector3(990.0 + float(k) * 8.0, 10.0, 1000.0))

	var pair_kinds: Array = all_marks(pair_m, "map-key-pair").map(func(r): return str(r[0]))
	check(pair_kinds.count("campfire") == 2 and pair_kinds.count("bog_iron") == 1, "two fires side by side are two marks, a bog iron field is one (%s)" % str(pair_kinds))
	check(MapScript._label_rank("Olive grove") > MapScript._label_rank("Olive trees") and MapScript._label_rank("Apple orchard") > MapScript._label_rank("Apple trees") and MapScript._label_rank("Olive trees") > MapScript._label_rank("Olive tree"), "a grove ranks with an orchard over trees, and trees over one tree")
	world[0] = [["bog_iron", 1030.0, 1005.0, "Bog iron"], ["fruit:apple", 1001.0, 1021.0, "Apple orchard"], ["path", 1000.0, 1000.0, ""]]
	m.note_catch(70, Vector3(1020.0, 10.0, 1000.0))
	m.note_catch(70, Vector3(1022.0, 10.0, 1002.0))
	check(not all_marks(m, "map-key-marks").map(func(r): return str(r[0])).has("fishing"), "two catches are not yet a good fishing spot")
	m.note_catch(70, Vector3(1023.0, 10.0, 1001.0))
	m.note_position(70, Vector3(1030.0, 10.0, 1000.0))
	rows = all_marks(m, "map-key-marks")
	kinds = rows.map(func(r): return str(r[0]))
	var labels: Array = rows.map(func(r): return str(r[3]))
	check(not kinds.has("campfire") and kinds.has("bog_iron") and labels.has("Apple orchard") and not labels.has("Apple trees") and kinds.has("fishing"), "a campfire gone leaves the map, the trees grow into an orchard, three catches mark good fishing (%s)" % str(labels))
	world[0] = []
	m.note_position(70, Vector3(1040.0, 10.0, 1000.0))
	kinds = all_marks(m, "map-key-marks").map(func(r): return str(r[0]))
	check(kinds == ["fishing"], "nothing seen any more: only the good fishing spot stays (%s)" % str(kinds))
	world[0] = null
	m.look_now(70, Vector3(1040.0, 10.0, 1000.0))
	check(all_marks(m, "map-key-marks").size() == 1, "ground not loaded changes nothing")
	world[0] = [["ore_rock:copper", 1041.0, 1001.0, "Copper"], ["path", 1040.0, 1000.0, ""]]
	m.look_now(70, Vector3(1040.0, 10.0, 1000.0))
	check(all_marks(m, "map-key-marks").map(func(r): return str(r[0])).has("ore_rock:copper"), "a blow on a rock marks it at once")
	var sent: Array = []

	for _pass in 50:
		clock_ms += 10000
		var batch: Array = m.updates_for(70, clock_ms)

		if batch.is_empty():
			break

		sent.append_array(batch)

	var sent_marks: int = 0

	for u in sent:
		sent_marks += (u[3] as Array).size()

	check(not sent.is_empty() and (sent[0] as Array).size() == 5 and sent_marks == 2, "each block goes with its marks and path cells (%d marks)" % sent_marks)
	m.save()
	var again = make(dir)
	check(all_marks(again, "map-key-marks").size() == 2 and again._record("map-key-marks").has("fish"), "marks and catches survive a save and reload")
	# A save from before (no marks, paths or fish) still loads.
	var old_path: String = again._path_of("map-key-old")
	var old_cells: Dictionary = {0: [20, 5.0, 1, 0], 1: [20, 6.0, 0, 2]}
	var f: FileAccess = FileAccess.open(old_path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "tally": 3, "blocks": {"0,0": Marshalls.raw_to_base64(Codec.encode(old_cells))}, "trails": {}}))
	f.close()
	var old: Dictionary = again._record("map-key-old")
	check(old["blocks"].size() == 1 and old["blocks"][Vector2i(0, 0)]["cells"].size() == 2 and all_marks(again, "map-key-old").is_empty(), "a map saved before landmarks loads with its cells and no marks")
	var marks_rec: Dictionary = again._record("map-key-marks")
	check(marks_rec["blocks"].values().all(func(b): return bool(b.get("water_ok", false))) and not bool(old["blocks"][Vector2i(0, 0)].get("water_ok", false)), "blocks mapped now load with their water checked; a map saved before 166 loads with it not checked")
	old["blocks"][Vector2i(0, 0)]["water_seen"] = {0: true}
	old["dirty"] = true
	again.save()
	var third = make(dir)
	var old_again: Dictionary = third._record("map-key-old")["blocks"][Vector2i(0, 0)]
	check(not bool(old_again.get("water_ok", false)) and old_again.get("water_seen", {}).has(0) and not old_again.get("water_seen", {}).has(1), "the old cells already looked at for their water are saved (%s)" % str(old_again.get("water_seen", {})))
	# A known cell of a map saved before protocol 166 has its water put right once on a revisit at the same skill (a river the old map called
	# a lake), with no redraw counted; ground mapped now is never looked at again for its water.
	var river_m = make("")
	keys[71] = "map-key-river"
	var wet: Array = [Codec.WATER_INLAND]
	var water_looks: Array = [0]
	river_m.observe = func(_x, _z):
		water_looks[0] += 1
		return [5.0, wet[0]]

	for k in 3:
		river_m.note_position(71, Vector3(float(k) * 8.0, 10.0, 0.0))

	water_looks[0] = 0
	river_m.note_position(71, Vector3(24.0, 10.0, 0.0))
	var fresh_looks: int = water_looks[0]
	water_looks[0] = 0
	river_m.note_position(71, Vector3(32.0, 10.0, 0.0))
	river_m.note_position(71, Vector3(24.0, 10.0, 0.0))
	check(water_looks[0] <= fresh_looks + 2, "known ground mapped now costs no water look on a revisit (%d looks, %d for the first new step)" % [water_looks[0], fresh_looks])
	var river_block: Dictionary = river_m._record("map-key-river")["blocks"][Vector2i(0, 0)]
	river_block.erase("water_ok")   # as a block loaded from a map saved before 166
	wet[0] = Codec.WATER_RIVER
	goaled.clear()
	river_m.note_position(71, Vector3(32.0, 10.0, 0.0))
	river_m.note_position(71, Vector3(24.0, 10.0, 0.0))
	var first_cell: Array = river_block.get("cells", {}).get(0, [])
	check(not first_cell.is_empty() and int(first_cell[2]) == Codec.WATER_RIVER and not goaled.any(func(g): return str(g[1]) == "map_redrawn"), "an old map's known cell has its water put right on a revisit, without a redraw (%s)" % str(first_cell))
	water_looks[0] = 0
	river_m.note_position(71, Vector3(32.0, 10.0, 0.0))
	river_m.note_position(71, Vector3(24.0, 10.0, 0.0))
	check(water_looks[0] == 0, "an old cell is looked at for its water only once (%d looks)" % water_looks[0])
	check(MapScript.water_kind(3) == Codec.WATER_RIVER and MapScript.water_kind(8) == Codec.WATER_MARSH and MapScript.water_kind(2) == Codec.WATER_INLAND and MapScript.water_kind(9) == Codec.WATER_NONE, "rivers and wetlands get their own water kinds")
	check(Codec.decode(Codec.encode({5: [10, 1.0, Codec.WATER_MARSH, 0]}))[5][2] == Codec.WATER_MARSH, "the codec carries river and marsh")
	# The world items a person marks (server_items.map_marks_near): a campfire, a rock started and not finished, a path and a road.
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	var idir: String = "user://test_map_items_marks"
	DirAccess.make_dir_recursive_absolute(idir)
	items.setup(ItemTableScript.load_default(), idir)
	items._items.clear()
	items._items[1] = {"number": 1, "count": 1, "pos": Vector3(5.0, 0.0, 0.0), "left": 1.0e9, "fire": {"state": 9, "burn_left": 0.0}}
	items._items[2] = {"number": 1, "count": 1, "pos": Vector3(8.0, 0.0, 0.0), "left": 1.0e9, "fire": {"state": 8, "burn_left": 0.0, "camp": "x", "marks": true}}
	items._items[3] = {"number": 1, "count": 40, "pos": Vector3(10.0, 0.0, 3.0), "left": 1.0e9, "boulder": {"radius": 1.0, "total": 60, "ore": "copper"}}
	items._items[4] = {"number": 1, "count": 60, "pos": Vector3(12.0, 0.0, 3.0), "left": 1.0e9, "boulder": {"radius": 1.0, "total": 60, "ore": "tin"}}
	items._items[5] = {"number": 1, "count": 30, "pos": Vector3(14.0, 0.0, 3.0), "left": 1.0e9, "boulder": {"radius": 1.0, "total": 60}}
	items._items[6] = {"number": 1, "count": 1, "pos": Vector3(3.0, 0.0, 9.0), "left": 1.0e9, "struct": {"kind": "path_patch"}}
	items._items[7] = {"number": 1, "count": 1, "pos": Vector3(3.0, 0.0, 12.0), "left": 1.0e9, "struct": {"kind": "path_patch", "road": true}}
	items._items[8] = {"number": 1, "count": 1, "pos": Vector3(500.0, 0.0, 0.0), "left": 1.0e9, "fire": {"state": 9, "burn_left": 0.0}}
	var near: Array = items.map_marks_near(Vector3.ZERO, 60.0).map(func(r): return "%s %s" % [r[0], r[3]])
	near.sort()
	check(near == [" ".join(["campfire", ""]), "ore_rock:copper Copper", "path ", "road "], "a campfire, a copper rock started, a path and a road; not a bandit sign, a whole rock, a plain rock or far off (%s)" % str(near))
	# A blow the rock never took (out of reach, or inside the blow cooldown) makes no look: the rock's id comes from the client.
	var looks: Array = []
	items.map_look = func(peer, at): looks.append([peer, at])
	items._hit(9, null, 3, Vector2i(Net.HIT_BOULDER, 1), 0)
	items._peer_pos[9] = Vector3(10.0, 0.0, 2.0)
	items._last_hit[9] = Time.get_ticks_msec()
	items._hit(9, null, 3, Vector2i(Net.HIT_BOULDER, 1), 0)
	items._hit(9, null, 5, Vector2i(Net.HIT_BOULDER, 1), 0)
	check(looks.is_empty(), "a refused blow on a rock (no position, inside the cooldown) looks at nothing (%d)" % looks.size())


# Every mark a character's map holds.
func all_marks(m, key: String) -> Array:
	var out: Array = []
	var rec: Dictionary = m._record(key)

	for block in rec.get("blocks", {}):
		out.append_array(rec["blocks"][block].get("marks", {}).values())

	return out


# The ends of a sketch's strokes lying on the line x = `edge` (world sketch pixels).
func edge_points(drawn: Dictionary, edge: float) -> Array:
	var out: Array = []

	for st in drawn["strokes"]:
		var pts: PackedVector2Array = st[0]

		for p in [pts[0], pts[pts.size() - 1]]:
			if absf(p.x - edge) < 0.001:
				out.append(p)

	return out


func longest(strokes: Array) -> float:
	var best: float = 0.0

	for st in strokes:
		var pts: PackedVector2Array = st[0]
		var length: float = 0.0

		for i in range(1, pts.size()):
			length += pts[i].distance_to(pts[i - 1])

		best = maxf(best, length)

	return best


# [total length times ink, mean ink] of a sketch's strokes.
func ink_of(drawn: Dictionary) -> Array:
	var total: float = 0.0
	var length: float = 0.0

	for st in drawn["strokes"]:
		var pts: PackedVector2Array = st[0]

		for i in range(1, pts.size()):
			var d: float = pts[i].distance_to(pts[i - 1])
			total += d * float(st[2])
			length += d

	return [total, total / maxf(length, 0.001)]


# Rivers, paths, marsh and woods each put their own ink on the page, only on known ground.
func sketch_feature_checks(per: int) -> void:
	var base: Dictionary = {}

	for idx in per * per:
		base[idx] = [60, 5.0, Codec.WATER_NONE, 0]

	var plain = KnowledgeScript.new()
	plain.set_block(Vector2i(0, 0), base.duplicate(true))
	var bare: int = Sketch.render_block(plain, Vector2i(0, 0))["strokes"].size()
	var river: Dictionary = base.duplicate(true)

	for z in per:
		river[10 + z * per] = [60, 5.0, Codec.WATER_RIVER, 0]

	var k_river = KnowledgeScript.new()
	k_river.set_block(Vector2i(0, 0), river)
	var r_strokes: Array = Sketch.render_block(k_river, Vector2i(0, 0))["strokes"]
	check(longest(r_strokes) > float((per - 3) * Sketch.PX), "a narrow river is one long pen line through its cells (%.0f px)" % longest(r_strokes))
	var k_path = KnowledgeScript.new()
	var paths: PackedInt32Array = PackedInt32Array()

	for x in 12:
		paths.append((5 * per + x) * 4 + 1)
		paths.append((20 * per + x) * 4 + 2)

	k_path.receive(0, 0, Codec.encode(base), [], paths)
	check(k_path.path_at(Vector2i(3, 5)) == 1 and k_path.path_at(Vector2i(3, 20)) == 2 and k_path.path_at(Vector2i(3, 6)) == 0, "the client keeps path and road cells")
	var p_drawn: Array = Sketch.render_block(k_path, Vector2i(0, 0))["strokes"]
	check(p_drawn.size() >= bare + 4 and longest(p_drawn) > 9.0 * Sketch.PX, "a road is one line and a path is broken into dashes (%d strokes over %d, longest %.0f px)" % [p_drawn.size(), bare, longest(p_drawn)])
	var marsh: Dictionary = base.duplicate(true)
	var woods: Dictionary = base.duplicate(true)

	for idx in per * per:
		marsh[idx] = [60, 5.0, Codec.WATER_MARSH, 0]
		woods[idx] = [60, 5.0, Codec.WATER_NONE, 3]

	var k_marsh = KnowledgeScript.new()
	k_marsh.set_block(Vector2i(0, 0), marsh)
	var k_woods = KnowledgeScript.new()
	k_woods.set_block(Vector2i(0, 0), woods)
	var tufts: int = Sketch.render_block(k_marsh, Vector2i(0, 0))["strokes"].size()
	var tree_marks: int = Sketch.render_block(k_woods, Vector2i(0, 0))["strokes"].size()
	check(tufts > per * per and tree_marks > per * per * 0.7 and tree_marks < per * per * 1.4, "marsh gets reed tufts and thick woods a tree mark in about half the cells (%d, %d strokes)" % [tufts, tree_marks])
	k_path.receive(0, 0, PackedByteArray(), [["campfire", 1.0, 1.0, ""]], paths)
	check(k_path.is_empty() and k_path.marks.is_empty() and k_path.path_at(Vector2i(3, 5)) == 0, "a block taken away takes its marks and paths with it")


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


# Game trails on the Map (protocol 152, Dave 23 Nov 2026: "auto added to the map once you get to a certain skill level"): the server keeps
# the routes of each trail block the character was near in its map record, sends them once, and keeps them over a restart; the client
# draws only the steps inside surveyed cells, from the Tracking level in data/map.json.
func trails_checks() -> void:
	var dir: String = "user://test_map_trails"
	DirAccess.make_dir_recursive_absolute(dir.path_join("maps"))

	for file in DirAccess.get_files_at(dir.path_join("maps")):
		DirAccess.remove_absolute(dir.path_join("maps").path_join(file))

	keys[71] = "trail-key-71"
	var m = make(dir)
	var routes: PackedByteArray = TrailCodec.encode_routes([[0, PackedVector2Array([Vector2(10.0, 10.0), Vector2(22.0, 10.0), Vector2(34.0, 12.0), Vector2(300.0, 300.0)])]], Vector2i(0, 0), TrailCodec.ROUTE_BLOCK_M)
	m.note_trails(71, Vector2i(0, 0), PackedByteArray())
	var none: Array = m.trail_updates_for(71)
	check(none.is_empty(), "no routes worked out, nothing kept (%s)" % str(none).left(200))
	m.note_trails(71, Vector2i(0, 0), routes)
	var first: Array = m.trail_updates_for(71)
	check(first.size() == 1 and first[0][2] == routes and m.trail_updates_for(71).is_empty(), "a trail block the character was near is sent once")
	m.note_trails(71, Vector2i(0, 0), routes)
	check(m.trail_updates_for(71).is_empty(), "the same routes again send nothing")
	m.note_trails(71, Vector2i(0, 0), TrailCodec.ROUTES_SAME)
	check(m.trail_updates_for(71).is_empty(), "routes marked unchanged (protocol 158) send nothing")
	m.save()
	m.forget_peer(71)
	var again = make(dir)
	var back: Array = again.trail_updates_for(71)
	check(back.size() == 1 and back[0][2] == routes, "after a restart the character's trails come back with its map")
	again.forget_peer(71)
	check(again.trail_updates_for(71).size() == 1, "a connection that comes back is sent them again")

	var k = KnowledgeScript.new()
	var told: Array = [0]
	k.trails_changed.connect(func() -> void: told[0] += 1)
	k.set_trails(0, 0, routes)
	check(k.trails.has(Vector2i(0, 0)) and told[0] == 1 and k.surveyed_trail_steps().is_empty(), "the client keeps them; with nothing surveyed none is drawn")
	k.set_block(Vector2i(0, 0), {0: [1, 10.0, 0, 0], 1: [1, 10.0, 0, 0], 2: [1, 10.0, 0, 0]})
	var steps: Array = k.surveyed_trail_steps()
	check(steps.size() == 2, "only the steps whose middle lies in a surveyed cell are drawn (%d)" % steps.size())
	check(k.surveyed_trail_steps(Rect2(5000.0, 5000.0, 100.0, 100.0)).is_empty() and k.surveyed_trail_steps(Rect2(0.0, 0.0, 50.0, 50.0)).size() == 2, "a page over other ground reads no trail block")
	k.set_block(Vector2i(0, 0), {0: [1, 10.0, 0, 0]})
	check(k.surveyed_trail_steps().is_empty(), "a changed map block is read again: its cell under the trail gone, so is the line (%d)" % k.surveyed_trail_steps().size())
	check(k.trails_tracking == int((JSON.parse_string(FileAccess.get_file_as_string("res://data/map.json")) as Dictionary)["trails_tracking"]), "the Tracking level comes from data/map.json")
	var page: String = FileAccess.get_file_as_string("res://src/client/map_page.gd")
	check(page.contains("float(tracking.call()) >= float(knowledge.trails_tracking)") and FileAccess.get_file_as_string("res://src/client/ui/goals/journal_view.gd").contains("skill_level_of(\"tracking\")"), "the page draws them only at that Tracking level, read from the character")
