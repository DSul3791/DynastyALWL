extends SceneTree

# Things coming down on dug and filled ground (physical world audit round 7, 23 Nov 2026: what players change in the ground). A carcass, an
# arrow, a thrown stack, tree litter and a regrown sapling were put on the generated ground: over a dug pit they hung in the air, in a fill they
# lay buried, and in a dug tunnel or a cave they came out on the hill above. Now they come down on the ground as dug and filled (the server's
# edited_ground.height), and under it on the floor of the air they are in (floor_below). Flat ground at y 10; the edits kept here.
#   godot --headless --path . --script res://src/worldgen/tools/test_ground_landing.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const BowScript := preload("res://src/stream/server_bow.gd")
const DIR := "user://test_ground_landing"

const PIT := Vector3(100.0, 10.0, 100.0)
const MOUND := Vector3(120.0, 10.0, 100.0)
const TUNNEL := Vector3(140.0, 5.0, 100.0)

var edits: Array = []
var alarms: Array = []
var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func solid_at(p: Vector3) -> bool:
	var solid: bool = p.y < 10.0

	for op in edits:
		if p.distance_to(op[1]) <= float(op[2]):
			solid = int(op[0]) == 1

	return solid


# edited_ground.height: the top of the highest solid span.
func top_at(x: float, z: float) -> float:
	var y: float = 16.0

	while y > 0.0:
		if solid_at(Vector3(x, y, z)):
			return y + 0.05

		y -= 0.05

	return NAN


# terrain_generator.floor_below over this ground: down through the air to the first solid.
func floor_at(from: Vector3) -> float:
	var y: float = from.y + 0.05

	for step in 480:
		if solid_at(Vector3(from.x, y, from.z)):
			return y + 0.05

		y -= 0.05

	return NAN


func make_items():
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0   # the generated ground knows no digs or fills
	items.ground_now = func(x, z): return top_at(x, z)
	items.floor_below = func(p: Vector3): return floor_at(p)
	items.animal_alarm = func(at: Vector3, _r: float): alarms.append(at)
	items.setup(ItemTableScript.load_default(), DIR)
	return items


# A stone thrown from 3 m over `at`, straight down: where it comes down (the landing thud) and where the stack lies.
func throw_onto(items, at: Vector3) -> Array:
	alarms.clear()
	var before: int = items._next_id
	items._flights.append({"number": items.table.number_of("stone"), "wear": 0, "inst": {}, "peer": 1, "pos": at + Vector3(0.0, 3.0, 0.0), "vel": Vector3(0.0, -2.0, 0.0), "age": 0.0, "lag": []})

	for k in 200:
		if items._flights.is_empty():
			break

		items._fly(0.02)

	var lying: float = NAN

	for id in range(before, items._next_id):
		if items._items.has(id):
			lying = float((items._items[id]["pos"] as Vector3).y)

	return [float(alarms[0].y) if not alarms.is_empty() else NAN, lying]


# An arrow shot straight down from 3 m over `at`: where it comes down (the landing thud).
func shoot_onto(items, at: Vector3) -> float:
	alarms.clear()

	if items._bow == null:
		items._bow = BowScript.new()

	items._arrows.append({"peer": 1, "number": items.table.number_of("stone"), "inst": {}, "tip": "wood", "damage": 0.0, "fire": false, "pos": at + Vector3(0.0, 3.0, 0.0), "vel": Vector3(0.0, -20.0, 0.0), "flown": 0.0, "age": 0.0, "range": 100.0, "sticks": true, "lag": []})

	for k in 200:
		if items._arrows.is_empty():
			break

		items._fly(0.02)

	return float(alarms[0].y) if not alarms.is_empty() else NAN


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)

	for file in DirAccess.get_files_at(DIR):
		DirAccess.remove_absolute(DIR + "/" + file)

	# A pit four digs deep, a mound three fills high, a tunnel dug under the hill (the ground over it stays at 10).
	for k in 4:
		edits.append([0, PIT - Vector3(0.0, 0.25 * float(k + 1), 0.0), 0.9])

	for k in 3:
		edits.append([1, MOUND + Vector3(0.0, 0.3 * float(k), 0.0), 0.9])

	edits.append([0, TUNNEL, 1.5])
	var pit_floor: float = top_at(PIT.x, PIT.z)
	var mound_top: float = top_at(MOUND.x, MOUND.z)
	var tunnel_floor: float = floor_at(TUNNEL)
	check(pit_floor < 9.0 and mound_top > 10.9 and absf(top_at(TUNNEL.x, TUNNEL.z) - 10.0) <= 0.1 and tunnel_floor < 4.0, "the ground: pit floor %.2f, mound top %.2f, the hill over the tunnel 10, its floor %.2f" % [pit_floor, mound_top, tunnel_floor])

	var items = make_items()
	items.peer_connected_hello(1, "groundland0001")

	# A carcass: where the animal fell.
	for row in [["in the pit", PIT, pit_floor, pit_floor], ["on the mound", MOUND, mound_top, mound_top], ["in the tunnel", TUNNEL, tunnel_floor, tunnel_floor]]:
		var id: int = items.make_carcass("deer", Vector3(row[1].x, float(row[2]), row[1].z))
		var y: float = float((items._items[id]["pos"] as Vector3).y) if items._items.has(id) else NAN
		check(absf(y - float(row[3])) <= 0.1, "a deer killed %s lies on that ground: y %.2f, ground %.2f" % [row[0], y, float(row[3])])

	# A thrown stone: where it comes down and where it lies (in the tunnel let go 1 m over its floor).
	for row in [["into the pit", PIT, pit_floor], ["onto the mound", MOUND, mound_top]]:
		var got: Array = throw_onto(items, Vector3(row[1].x, float(row[2]), row[1].z))
		check(absf(float(got[0]) - float(row[2])) <= 0.15 and absf(float(got[1]) - float(row[2])) <= 0.15, "a stone thrown %s comes down on it (%.2f) and lies there (%.2f), ground %.2f" % [row[0], float(got[0]), float(got[1]), float(row[2])])

	var in_tunnel: Array = throw_onto(items, Vector3(TUNNEL.x, tunnel_floor - 2.0, TUNNEL.z))
	check(absf(float(in_tunnel[0]) - tunnel_floor) <= 0.15 and absf(float(in_tunnel[1]) - tunnel_floor) <= 0.15, "a stone dropped in the tunnel comes down on its floor (%.2f, lies %.2f), not on the hill over it, floor %.2f" % [float(in_tunnel[0]), float(in_tunnel[1]), tunnel_floor])

	# An arrow: where it comes down.
	for row in [["into the pit", PIT, pit_floor], ["onto the mound", MOUND, mound_top]]:
		var y: float = shoot_onto(items, Vector3(row[1].x, float(row[2]), row[1].z))
		check(absf(y - float(row[2])) <= 0.15, "an arrow shot %s comes down on it (%.2f), ground %.2f" % [row[0], y, float(row[2])])

	# Tree litter and a regrown plant use the same ground (the cut is in _seed_litter, _crown_litter and _maybe_sapling).
	check(absf(items._ground_under(Vector3(PIT.x, 10.5, PIT.z)) - pit_floor) <= 0.01 and absf(items._ground_under(Vector3(MOUND.x, 10.5, MOUND.z)) - mound_top) <= 0.01, "litter falling from 0.5 m over the old ground lands in the pit and on the mound")
	var src: String = FileAccess.get_file_as_string("res://src/stream/server_items.gd")
	var sapling: String = src.substr(src.find("func _maybe_sapling("), 2000)
	check(sapling.contains("ground_now.call(spot.x, spot.z)"), "a regrown sapling stands on the ground as dug and filled (_maybe_sapling)")
	var server: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	check(server.contains("items.ground_now = edited_ground.height"), "terrain_server gives the items the edited ground")

	print("test_ground_landing: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
