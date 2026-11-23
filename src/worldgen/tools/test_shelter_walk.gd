extends SceneTree

# Shelter as a survival loop (coordinator, 23 Nov 2026): real server state and the real cover index, as the server scene wires them (a built
# roof reads 2.0). A Refined house on a 4 m foundation: walls alone keep no rain off; a 45 gable roof of four panels on the two long walls
# covers the whole floor, its open gable ends too (cover is straight down); a flat ceiling on the walls covers the room under it (it had no
# cover box, so rain fell through every ceiling: structures.json half_x, half_z, height and cover_below_m on each ceiling kind). Under a roof the wind drops to warmth.json covered_wind_share,
# so a cold windy night feels warmer inside than out.
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

	print("shelter walk: %d failures" % failures)
	items._finish_writer()
	quit(1 if failures > 0 else 0)
