extends SceneTree

# Shelter as a survival loop (coordinator, 23 Nov 2026): real server state and the real cover index, as the server scene wires them (a built
# roof reads 2.0). A Refined house on a 4 m foundation: walls alone keep no rain off; a 45 gable roof of four panels on the two long walls
# covers the whole floor, its open gable ends too (cover is straight down); a flat ceiling on the walls covers the room under it (it had no
# cover box, so rain fell through every ceiling: structures.json half_x, half_z, height and cover_below_m on each ceiling kind). Under a roof the wind drops to warmth.json covered_wind_share,
# so a cold windy night feels warmer inside than out. Two builders (coordinator ruling, 23 Nov 2026): anyone may build on a foundation, and its
# owner may take down what another player built there; what it gives back lies on that floor for its builder, never in the owner's pack.
#   godot --headless --path . --script res://src/worldgen/tools/test_shelter_walk.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const CoverScript := preload("res://src/shared/cover.gd")
const DIR := "user://test_shelter_walk"
const GROUND := 10.0

var failures: int = 0
var index
var said: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func count(items, kind: String) -> int:
	var n: int = 0

	for id in items._items:
		if str(items._items[id].get("struct", {}).get("kind", "")) == kind:
			n += 1

	return n


func covered(items, at: Vector3) -> bool:
	return float(items.cover_at.call(at)) > 0.5


# Places a piece as a player standing beside it (on the ground below it) would.
func put(items, kit: String, at: Vector3, yaw: int, lift: int = 0) -> void:
	items.report_position(1, Vector3(at.x + 1.0, GROUND, at.z + 1.0))
	items.place_piece(1, kit, at, yaw, lift)


# A 4 m Refined foundation at (x, z) with its eight walls; the floor's top is GROUND + 0.3.
func house(items, x: float, z: float) -> void:
	items.report_position(1, Vector3(x, GROUND, z + 6.0))
	put(items, "wood_foundation_kit", Vector3(x, GROUND, z), 0)

	for a in [[-1, -2, 0], [1, -2, 0], [-1, 2, 0], [1, 2, 0], [-2, -1, 90], [-2, 1, 90], [2, -1, 90], [2, 1, 90]]:
		put(items, "wall_section_kit", Vector3(x + float(a[0]), GROUND + 0.3, z + float(a[1])), int(a[2]))


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	index = CoverScript.Index.new()
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.ground_height = func(_x, _z): return GROUND
	items.roof_add = func(roof): return index.add_roof(roof)
	items.roof_remove = func(key): index.remove_roof(key)
	items.cover_at = func(p): return 2.0 if index.roofed(p) else 0.0   # terrain_server _cover_at: a built roof reads 2.0
	items.weather_now = func(): return {"temp_c": 2.0, "wind": 1.0, "rain": 0.0, "snow": 0.0}
	items.setup(ItemTableScript.load_default(), DIR)
	items.admin_mode_on = func(_p): return false
	items.peer_connected_hello(1, "shelterwalk01")
	var floor_y: float = GROUND + 0.3
	var feet: float = floor_y + 0.05
	var eye: float = floor_y + 1.6

	# Walls alone.
	house(items, 100.0, 100.0)
	check(count(items, "wood_foundation") == 1 and count(items, "wall_section") == 8, "a foundation and its eight walls stand (%s)" % str(said.slice(-2)))
	check(not covered(items, Vector3(100.0, feet, 100.0)), "walls alone keep no rain off: the sky is open above")

	# A 45 gable on the two long walls (z -2 and +2), two panels a side rising to the ridge in the middle.
	for x in [-1.0, 1.0]:
		put(items, "roof_section_kit", Vector3(100.0 + x, floor_y + 2.4, 100.0 - 1.9), 180, 0)
		put(items, "roof_section_kit", Vector3(100.0 + x, floor_y + 2.4, 100.0 + 1.9), 0, 0)

	check(count(items, "roof_section") == 4, "four panels make the gable (%d; %s)" % [count(items, "roof_section"), str(said.slice(-2))])
	var dry: Array = []


	for px in [-1.8, -1.0, 0.0, 1.0, 1.8]:
		for pz in [-1.8, -1.0, 0.0, 1.0, 1.8]:
			for py in [feet, eye]:
				if not covered(items, Vector3(100.0 + px, py, 100.0 + pz)):
					dry.append("%.1f,%.1f,%.1f" % [px, py - floor_y, pz])

	check(dry.is_empty(), "under the gable the whole floor is covered, by the open gable ends too, at the feet and the eye (open at %s)" % str(dry))
	check(not covered(items, Vector3(100.0, feet, 103.5)) and not covered(items, Vector3(100.0, floor_y + 4.5, 100.0)), "outside the walls, and on top of the roof, it is open")

	# Out in the wind and under the roof, the same cold night.
	items.report_position(1, Vector3(100.0, feet, 110.0))
	var open_t: float = items.warmth_target(1)
	items.report_position(1, Vector3(100.0, feet, 100.0))
	var roof_t: float = items.warmth_target(1)
	check(roof_t > open_t + 1.0, "on a 2 C windy night the body heads for more warmth under the roof (%.1f) than out in the open (%.1f)" % [roof_t, open_t])

	# A flat ceiling on the walls: the room under it is covered.
	house(items, 120.0, 100.0)

	for c in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		put(items, "floor_section_kit", Vector3(120.0 + float(c[0]), floor_y + 2.4, 100.0 + float(c[1])), 0)

	check(count(items, "floor_section") == 4, "a ceiling of four cells lies on the walls (%d; %s)" % [count(items, "floor_section"), str(said.slice(-2))])
	var ceiling_y: float = -1.0

	for id in items._items:
		if str(items._items[id].get("struct", {}).get("kind", "")) == "floor_section":
			ceiling_y = float(items._items[id]["pos"].y)

	var open: Array = []

	for px in [-1.8, 0.0, 1.8]:
		for pz in [-1.8, 0.0, 1.8]:
			if not covered(items, Vector3(120.0 + px, feet, 100.0 + pz)) or not covered(items, Vector3(120.0 + px, eye, 100.0 + pz)):
				open.append("%.1f,%.1f" % [px, pz])

	check(open.is_empty(), "under a flat ceiling the room is covered (ceiling at %.2f m above the floor; open at %s)" % [ceiling_y - floor_y, str(open)])
	check(not covered(items, Vector3(120.0, ceiling_y + 0.2, 100.0)), "standing on the ceiling (the upper storey's floor) is open to the sky")

	_two_builders(items)
	print("shelter walk: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)


func pieces_at(items, kind: String, near: Vector3) -> Array:
	var out: Array = []

	for id in items._items:
		if str(items._items[id].get("struct", {}).get("kind", "")) == kind and Vector2(items._items[id]["pos"].x - near.x, items._items[id]["pos"].z - near.z).length() < 3.5:
			out.append(id)

	return out


func ground_count(items, number: int, near: Vector3) -> int:
	var n: int = 0

	for id in items._items:
		if int(items._items[id].get("number", 0)) == number and not items._items[id].has("struct") and (items._items[id]["pos"] as Vector3).distance_to(near) < 3.5:
			n += int(items._items[id]["count"])

	return n


func pack_total(inv) -> int:
	var n: int = 0

	for s in inv.slot_count:
		n += inv.counts[s]

	return n


func _two_builders(items) -> void:
	items.peer_connected_hello(2, "shelterwalk02")
	var base := Vector3(160.0, GROUND, 100.0)
	put(items, "wood_foundation_kit", base, 0)   # player 1's foundation
	var floor_y: float = GROUND + 0.3
	items.report_position(2, base + Vector3(1.0, 0.3, 1.0))
	items.place_piece(2, "wall_section_kit", Vector3(base.x - 1.0, floor_y, base.z - 2.0), 0)
	items.place_piece(2, "wall_section_kit", Vector3(base.x + 1.0, floor_y, base.z - 2.0), 0)
	var walls: Array = pieces_at(items, "wall_section", base)
	check(walls.size() == 2 and walls.all(func(w): return str(items._items[w]["struct"]["owner"]) == "shelterwalk02"), "player 2 builds two walls on player 1's foundation; they are player 2's (%s)" % str(said.slice(-1)))
	items.report_position(2, base + Vector3(1.0, 0.3, -1.0))
	items.place_piece(2, "roof_section_kit", Vector3(base.x - 1.0, floor_y + 2.4, base.z - 1.9), 180, 0)
	var panels: Array = pieces_at(items, "roof_section", base)
	check(panels.size() == 1, "and a roof panel on one of them")

	# Player 1 takes down what rests on top first, then the wall; it all lies on their floor for player 2.
	items.report_position(1, base + Vector3(0.0, 0.3, -1.0))
	var pack_before: int = pack_total(items.inventory_of(1))
	var lumber: int = items.table.number_of("lumber")
	var ground_before: int = ground_count(items, lumber, base)
	var under: int = 0

	for w in walls:
		if absf(float(items._items[w]["pos"].x) - (base.x - 1.0)) < 0.1:
			under = w

	items._take_down(1, items.inventory_of(1), under)
	check(items._items.has(under) and str(said[-1]).contains("stands on it"), "player 1 cannot take the wall out from under the panel (%s)" % str(said[-1]))
	items.report_position(1, Vector3(base.x - 1.0, floor_y, base.z - 1.0))   # right under the panel: its middle is 3.4 m above the floor (reach 3.5 m)
	items._take_down(1, items.inventory_of(1), panels[0])
	items._take_down(1, items.inventory_of(1), under)
	check(not items._items.has(panels[0]) and not items._items.has(under), "the foundation's owner takes the panel down, then the wall (%s)" % str(said[-1]))
	var given: int = 0

	for id in items._items:
		if not items._items[id].has("struct") and (items._items[id]["pos"] as Vector3).distance_to(Vector3(base.x - 1.0, floor_y, base.z - 1.5)) < 3.0:
			given += int(items._items[id]["count"])

	check(pack_total(items.inventory_of(1)) == pack_before and given > 0 and ground_count(items, lumber, base) >= ground_before, "nothing went into player 1's pack; what they were built from lies on the floor for player 2 (%d pieces)" % given)
	var lying_y: Array = []

	for id in items._items:
		if not items._items[id].has("struct") and (items._items[id]["pos"] as Vector3).distance_to(Vector3(base.x - 1.0, floor_y, base.z - 1.5)) < 3.0:
			lying_y.append(snappedf(float(items._items[id]["pos"].y), 0.01))

	check(lying_y.all(func(y): return absf(float(y) - floor_y) < 0.2), "on the floor, not in the air where the panel was (%s)" % str(lying_y))

	# Player 2 still takes their own wall down; on player 2's own foundation player 1 takes nothing.
	var other: int = walls[1] if walls[0] == under else walls[0]
	var two_before: int = pack_total(items.inventory_of(2))
	items.report_position(2, base + Vector3(1.0, 0.3, -1.0))
	items._take_down(2, items.inventory_of(2), other)
	check(not items._items.has(other) and pack_total(items.inventory_of(2)) > two_before, "player 2 takes their own wall down into their pack")
	var mine := Vector3(180.0, GROUND, 100.0)
	items.report_position(2, mine + Vector3(1.0, 0.0, 3.0))
	items.place_piece(2, "wood_foundation_kit", mine, 0)
	items.report_position(2, mine + Vector3(1.0, 0.3, 1.0))
	items.place_piece(2, "wall_section_kit", Vector3(mine.x - 1.0, floor_y, mine.z - 2.0), 0)
	var theirs: Array = pieces_at(items, "wall_section", mine)
	items.report_position(1, mine + Vector3(0.0, 0.3, -1.0))

	if not theirs.is_empty():
		items._take_down(1, items.inventory_of(1), theirs[0])

	check(theirs.size() == 1 and items._items.has(theirs[0]) and str(said[-1]) == "Only the one who built it can take it down.", "on player 2's own foundation, player 1 cannot take player 2's wall down (%s)" % str(said[-1]))

	# A blueprint site player 2 put on player 1's foundation, with lumber in it: taken down by player 1, the lumber lies on the floor.
	items.report_position(2, base + Vector3(1.0, 0.3, 1.0))
	items.place_piece(2, "wall_section_kit", Vector3(base.x + 1.0, floor_y, base.z + 2.0), 0)
	var site: int = 0

	for id in pieces_at(items, "wall_section", base):
		if absf(float(items._items[id]["pos"].z) - (base.z + 2.0)) < 0.1:
			site = id

	if site != 0:
		items._items[site]["struct"]["site"] = {"have": {"lumber": 8}}   # as a site part filled by player 2's hammer

	var lumber_floor: int = ground_count(items, lumber, base)
	var pack_now: int = pack_total(items.inventory_of(1))
	items.report_position(1, base + Vector3(1.0, 0.3, 1.0))
	items._take_down(1, items.inventory_of(1), site)
	check(site != 0 and not items._items.has(site) and pack_total(items.inventory_of(1)) == pack_now and ground_count(items, lumber, base) == lumber_floor + 8, "player 2's blueprint site on player 1's foundation: its 8 lumber lie on the floor, not in player 1's pack")
	var waits: bool = true

	for id in items._items:
		if not items._items[id].has("struct") and int(items._items[id].get("number", 0)) == lumber and (items._items[id]["pos"] as Vector3).distance_to(base) < 3.5:
			waits = waits and float(items._items[id]["left"]) > 1.0e8

	check(waits, "and what is left for the builder never despawns while they are away")

	# Beside the foundation on the ground, and on a neighbour's foundation that abuts it: not player 1's to take down.
	items.report_position(2, base + Vector3(-4.0, 0.0, 0.0))
	items.place_piece(2, "wall_section_kit", Vector3(base.x - 2.6, GROUND, base.z - 3.0), 90)
	var beside: Array = []

	for id in pieces_at(items, "wall_section", base + Vector3(-2.6, 0.0, -2.0)):
		if absf(float(items._items[id]["pos"].y) - GROUND) < 0.05:
			beside.append(id)

	check(beside.size() == 1 and not items._may_take_down(1, items._items[beside[0]]), "a wall player 2 built on the ground just beside player 1's foundation is not player 1's to take down")
	items.peer_connected_hello(3, "shelterwalk03")
	var next := base + Vector3(0.0, 0.0, -4.0)
	items.report_position(3, next + Vector3(1.0, 0.0, -3.0))
	items.place_piece(3, "wood_foundation_kit", next, 0)
	items.report_position(2, next + Vector3(1.0, 0.3, -1.0))
	items.place_piece(2, "wall_section_kit", Vector3(next.x + 1.0, floor_y, next.z - 2.0), 0)   # the far edge of player 3's foundation
	var far_wall: Array = pieces_at(items, "wall_section", next + Vector3(1.0, 0.0, -2.0)).filter(func(w): return absf(float(items._items[w]["pos"].z) - (next.z - 2.0)) < 0.1)
	var shared: Array = pieces_at(items, "wall_section", base + Vector3(0.0, 0.0, -2.0)).filter(func(w): return absf(float(items._items[w]["pos"].z) - (base.z - 2.0)) < 0.1 and absf(float(items._items[w]["pos"].x) - (base.x + 1.0)) < 0.1)

	if shared.is_empty():
		items.report_position(2, base + Vector3(1.0, 0.3, -1.0))
		items.place_piece(2, "wall_section_kit", Vector3(base.x + 1.0, floor_y, base.z - 2.0), 0)
		shared = pieces_at(items, "wall_section", base + Vector3(0.0, 0.0, -2.0)).filter(func(w): return absf(float(items._items[w]["pos"].z) - (base.z - 2.0)) < 0.1 and absf(float(items._items[w]["pos"].x) - (base.x + 1.0)) < 0.1)

	check(far_wall.size() == 1 and not items._may_take_down(1, items._items[far_wall[0]]) and items._may_take_down(3, items._items[far_wall[0]]), "on the neighbour's foundation that abuts it, only the neighbour may take player 2's wall down")
	check(shared.size() == 1 and items._may_take_down(1, items._items[shared[0]]) and items._may_take_down(3, items._items[shared[0]]), "a wall on the edge the two foundations share may be taken down by either owner")

