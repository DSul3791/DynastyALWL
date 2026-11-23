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


# Flat at 10, and from x 200 a natural hillside rising 2 m a metre (no edits there).
func base_at(x: float) -> float:
	return 10.0 if x < 200.0 else 10.0 + (x - 200.0) * 2.0


func solid_at(p: Vector3) -> bool:
	var solid: bool = p.y < base_at(p.x)

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


# A height `y` in the tunnel is on its floor (the sphere's bottom, 3.5 in the middle, a little higher off it): not in the rock under it, not up
# in its roof, not on the hill over it at 10.
func in_tunnel(y: float, _at: Vector3) -> bool:
	return not is_nan(y) and y >= 3.4 and y <= 4.3


func make_items():
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(x, _z): return base_at(x)   # the generated ground knows no digs or fills
	items.ground_now = func(x, z): return top_at(x, z)
	items.floor_below = func(p: Vector3): return floor_at(p)
	items.animal_alarm = func(at: Vector3, _r: float): alarms.append(at)
	items.setup(ItemTableScript.load_default(), DIR)
	return items


# A stone thrown from `start` at `vel`: where it comes down (the landing thud) and where the stack lies. Server frames of 1/30 s.
func throw_from(items, start: Vector3, vel: Vector3) -> Array:
	alarms.clear()
	var stone: int = items.table.number_of("stone")

	for id in items._items.keys():   # the stones thrown before (a new one would join their heap)
		if int(items._items[id]["number"]) == stone and not items._items[id].has("struct"):
			items._items.erase(id)

	var before: int = items._next_id
	items._flights.append({"number": items.table.number_of("stone"), "wear": 0, "inst": {}, "peer": 1, "pos": start, "vel": vel, "age": 0.0, "lag": []})

	for k in 300:
		if items._flights.is_empty():
			break

		items._fly(1.0 / 30.0)

	var lying: float = NAN

	for id in range(before, items._next_id):
		if items._items.has(id):
			lying = float((items._items[id]["pos"] as Vector3).y)

	return [float(alarms[0].y) if not alarms.is_empty() else NAN, lying]


func throw_onto(items, at: Vector3) -> Array:
	return throw_from(items, at + Vector3(0.0, 3.0, 0.0), Vector3(0.0, -8.0, 0.0))


# An arrow shot from `start` at `vel` (the bow's own 0.05 s steps): where it comes down (the landing thud).
func shoot_from(items, start: Vector3, vel: Vector3) -> float:
	alarms.clear()

	if items._bow == null:
		items._bow = BowScript.new()

	items._arrows.append({"peer": 1, "number": items.table.number_of("stone"), "inst": {}, "tip": "wood", "damage": 0.0, "fire": false, "pos": start, "vel": vel, "flown": 0.0, "age": 0.0, "range": 100.0, "sticks": true, "lag": []})

	for k in 200:
		if items._arrows.is_empty():
			break

		items._fly(1.0 / 30.0)

	return float(alarms[0].y) if not alarms.is_empty() else NAN


func shoot_onto(items, at: Vector3) -> float:
	return shoot_from(items, at + Vector3(0.0, 3.0, 0.0), Vector3(0.0, -40.0, 0.0))


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
	for row in [["in the pit", PIT, pit_floor, pit_floor], ["on the mound", MOUND, mound_top, mound_top], ["in the tunnel", TUNNEL, tunnel_floor + 0.25, tunnel_floor]]:
		var id: int = items.make_carcass("deer", Vector3(row[1].x, float(row[2]), row[1].z))
		var y: float = float((items._items[id]["pos"] as Vector3).y) if items._items.has(id) else NAN
		check(absf(y - float(row[3])) <= 0.1, "a deer killed %s lies on that ground: y %.2f, ground %.2f" % [row[0], y, float(row[3])])

	# A thrown stone: where it comes down and where it lies (in the tunnel let go 1 m over its floor).
	for row in [["into the pit", PIT, pit_floor], ["onto the mound", MOUND, mound_top]]:
		var got: Array = throw_onto(items, Vector3(row[1].x, float(row[2]), row[1].z))
		check(absf(float(got[0]) - float(row[2])) <= 0.15 and absf(float(got[1]) - float(row[2])) <= 0.15, "a stone thrown %s comes down on it (%.2f) and lies there (%.2f), ground %.2f" % [row[0], float(got[0]), float(got[1]), float(row[2])])

	# In the tunnel (the hill over it at 10): a stone dropped from 1 m and one thrown hard down and along, at the server's frame step, come
	# down on its floor and not on the hill; so does one thrown into its wall.
	for row in [["dropped in the tunnel", Vector3(TUNNEL.x, tunnel_floor + 1.0, TUNNEL.z), Vector3.ZERO], ["thrown down along the tunnel", Vector3(TUNNEL.x - 0.8, tunnel_floor + 1.6, TUNNEL.z), Vector3(4.0, -9.0, 0.0)], ["thrown into the tunnel wall", Vector3(TUNNEL.x, tunnel_floor + 0.6, TUNNEL.z), Vector3(12.0, -1.0, 0.0)], ["thrown up into the tunnel roof", Vector3(TUNNEL.x, tunnel_floor + 1.0, TUNNEL.z), Vector3(0.5, 9.0, 0.0)]]:
		var got: Array = throw_from(items, row[1], row[2])
		check(in_tunnel(float(got[0]), row[1]) and in_tunnel(float(got[1]), row[1]), "a stone %s comes down in it (%.2f, lies %.2f), not in the rock or on the hill over it at 10, floor %.2f" % [row[0], float(got[0]), float(got[1]), tunnel_floor])

	# An arrow: where it comes down.
	for row in [["into the pit", PIT, pit_floor], ["onto the mound", MOUND, mound_top]]:
		var y: float = shoot_onto(items, Vector3(row[1].x, float(row[2]), row[1].z))
		check(absf(y - float(row[2])) <= 0.15, "an arrow shot %s comes down on it (%.2f), ground %.2f" % [row[0], y, float(row[2])])

	for row in [["along the tunnel", Vector3(TUNNEL.x - 1.2, tunnel_floor + 1.2, TUNNEL.z), Vector3(45.0, -6.0, 0.0)], ["up into the tunnel roof", Vector3(TUNNEL.x, tunnel_floor + 1.0, TUNNEL.z), Vector3(2.0, 40.0, 0.0)], ["down into the tunnel floor", Vector3(TUNNEL.x, tunnel_floor + 1.4, TUNNEL.z), Vector3(5.0, -40.0, 0.0)]]:
		var y: float = shoot_from(items, row[1], row[2])
		check(in_tunnel(y, row[1]) and y < tunnel_floor + 0.3, "an arrow shot %s comes down on its floor (%.2f), not in the rock or on the hill over it at 10, floor %.2f" % [row[0], y, tunnel_floor])

	# Into the tunnel's mouth from the open air: a ramp pit dug beside it (open to the sky, its floor at the tunnel's) and an arrow and a stone sent level
	# from there into the tunnel come down on the tunnel's floor, not on the hill over it.
	for k in 4:
		edits.append([0, TUNNEL - Vector3(3.0 + 1.4 * float(k), 0.0, 0.0), 1.5])

	for k in 4:
		edits.append([0, TUNNEL - Vector3(3.0 + 1.4 * float(k), -4.0, 0.0), 1.5])
		edits.append([0, TUNNEL - Vector3(3.0 + 1.4 * float(k), -1.5, 0.0), 1.5])

	var pit_open: bool = top_at(TUNNEL.x - 5.0, TUNNEL.z) < 5.0
	var mouth_arrow: float = shoot_from(items, Vector3(TUNNEL.x - 5.0, 4.6, TUNNEL.z), Vector3(40.0, -1.0, 0.0))
	var mouth_x: float = alarms[0].x if not alarms.is_empty() else NAN
	var mouth_stone: Array = throw_from(items, Vector3(TUNNEL.x - 5.0, 4.6, TUNNEL.z), Vector3(9.0, 0.0, 0.0))
	check(pit_open and in_tunnel(mouth_arrow, TUNNEL) and in_tunnel(float(mouth_stone[0]), TUNNEL) and in_tunnel(float(mouth_stone[1]), TUNNEL), "an arrow (%.2f at x %.1f) and a stone (%.2f, lies %.2f) sent from an open ramp pit into the tunnel's mouth come down in it, not on the hill over it" % [mouth_arrow, mouth_x, float(mouth_stone[0]), float(mouth_stone[1])])

	# A natural hillside, no edits: an arrow and a stone that strike its face land on the face where they struck (the open air is read from
	# their own column), not at its foot or in the air.
	var face: float = shoot_from(items, Vector3(195.0, 13.0, 100.0), Vector3(40.0, 0.0, 0.0))
	var hit_x: float = alarms[0].x if not alarms.is_empty() else NAN
	check(absf(face - base_at(hit_x)) <= 0.15 and hit_x > 201.0 and hit_x < 202.0, "an arrow shot level into a hillside lands on its face where it struck (x %.2f, y %.2f, the face there %.2f)" % [hit_x, face, base_at(hit_x)])
	var thud: Array = throw_from(items, Vector3(196.0, 13.0, 100.0), Vector3(10.0, 0.0, 0.0))
	check(absf(float(thud[0]) - 13.0) <= 1.0 and float(thud[0]) > 10.5, "a stone thrown into the hillside lands on its face (%.2f, lies %.2f), not at its foot (10)" % [float(thud[0]), float(thud[1])])

	# A felled tree's seeds land in its crown circle on the ground as dug and filled: a crown over the pit and over the mound.
	for row in [["pit", PIT, pit_floor], ["mound", MOUND, mound_top]]:
		var tree: Dictionary = {"species": "oak", "crown": [row[1].x, row[1].z, 0.4]}
		var litter: Array = items._seed_litter(7, tree, Vector3(row[1].x + 8.0, 10.0, row[1].z))
		var y: float = float((litter[0][2] as Vector3).y) if not litter.is_empty() else NAN
		check(not litter.is_empty() and absf(y - 0.1 - float(row[2])) <= 0.15, "a tree's seeds over the %s land on it (%.2f), ground %.2f" % [row[0], y, float(row[2])])

	# The generated ground where the server gives no edited ground (the tests that set only ground_height); NAN ground leaves a station spot as it was.
	var plain = ItemsScript.new()
	plain.ground_height = func(_x, _z): return 10.0
	check(is_equal_approx(plain._ground_under(Vector3(PIT.x, 12.0, PIT.z)), 10.0) and is_nan(ItemsScript.new()._ground_under(Vector3(PIT.x, 12.0, PIT.z))), "no edited ground: the generated one; none at all: NAN")
	var server: String = FileAccess.get_file_as_string("res://scenes/terrain_server/terrain_server.gd")
	check(server.contains("items.ground_now = edited_ground.height"), "terrain_server gives the items the edited ground")

	print("test_ground_landing: %s" % ("PASS" if failures == 0 else "%d FAIL" % failures))
	quit(1 if failures > 0 else 0)
