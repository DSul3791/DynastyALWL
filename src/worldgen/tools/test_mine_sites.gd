extends SceneTree

# Abandoned mines (Dave 19 Nov 2026: "abandoned mines that already have bracing", sized from how medieval mines were built; provisional CD-5, CD-6
# in docs/design/CAVE_DENS_AND_MINES.md): where a tile's mines go, their shape (an adit rising 1 in 100 to an ore body, drifts, stopes, a large
# mine's air shaft), their timbers and what they left behind. A made-up tile with one hill, no world.
#   godot --headless --path . --script res://src/worldgen/tools/test_mine_sites.gd

const TileTerrainData := preload("res://src/worldgen/runtime/tile_terrain_data.gd")
const MineSites := preload("res://src/worldgen/runtime/mine_sites.gd")
const ItemTable := preload("res://src/shared/item_table.gd")

const HILL := Vector2(1000.0, 1000.0)
const PEAK := 200.0
const FALL := 0.4    # the hill drops 0.4 m per m (22 degrees), down to 5 m
const NONE := Vector2(INF, INF)

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A 2 km tile (257 samples 8 m apart), dry, with a cone-shaped hill in its middle.
func hill_tile():
	var data = TileTerrainData.new()
	data.tile = Vector2i(0, 0)
	data.samples = 257
	data.spacing_m = 8.0
	data.x0 = 0.0
	data.z0 = 0.0
	data.flora_seed = 1234
	data.heights.resize(data.samples * data.samples)
	data.water_class.resize(data.samples * data.samples)
	data.water_class.fill(0)

	for j in data.samples:
		for i in data.samples:
			data.heights[j * data.samples + i] = maxf(PEAK - FALL * Vector2(i * 8.0, j * 8.0).distance_to(HILL), 5.0)

	return data


# An ore lens with its middle at (at, y).
func ore(id: String, at: Vector2, y: float, resource: String = "copper") -> Dictionary:
	return {"id": id, "resource": resource, "shape": "lens", "center": [at.x, y, at.y], "thickness_m": 20.0, "radius_a_m": 30.0, "angle": 0.3}


func rows_of(list: Array, kind: float) -> Array:
	return list.filter(func(r): return is_equal_approx(float(r[3]), kind))


func flat(node: Array) -> Vector2:
	return Vector2(float(node[0]), float(node[2]))


func floor_of(node: Array) -> float:
	return float(node[1]) - 0.5 * float(node[4])


# The least rock over any passage or room roof past the open cut (the shaft and its hollow left out: they climb to the surface on purpose).
func roof_left(data, mine: Dictionary, cut: float) -> float:
	var least: float = INF
	var shaft_nodes: Array = []

	for s in mine["segments"]:
		if str(s[2]) == "shaft":
			shaft_nodes.append(int(s[1]))
			shaft_nodes.append(int(s[1]) + 1)

	for n in range(1, (mine["nodes"] as Array).size()):
		var node: Array = mine["nodes"][n]

		if shaft_nodes.has(n) or flat(node).distance_to(flat(mine["mouth"])) < cut + 1.0:
			continue

		least = minf(least, data.height_at(float(node[0]), float(node[2])) - (float(node[1]) + 0.5 * float(node[4])))

	return least


func _init() -> void:
	var data = hill_tile()

	# Where: a body under the hill gets a mine; a second one 100 m off does not (400 m apart); one under flat ground has no hillside for a mouth.
	var bodies: Array = [ore("a", HILL + Vector2(60.0, 0.0), PEAK - 40.0), ore("b", HILL + Vector2(-40.0, 0.0), PEAK - 30.0), ore("flat", Vector2(1700.0, 300.0), 3.0)]
	var mines: Array = MineSites.plan(data, bodies, [], NONE)
	check(mines.size() == 1, "one mine: two bodies 100 m apart share one, flat ground has none (%d)" % mines.size())
	check(str(MineSites.plan(data, bodies, [], NONE)) == str(mines), "the same tile gives the same mines")
	check(MineSites.plan(data, [ore("tin", HILL, PEAK - 20.0, "tin")], [], NONE).size() == 1, "a tin body is mined too")
	check(MineSites.plan(data, [ore("salt", HILL, PEAK - 20.0, "salt")], [], NONE).is_empty(), "a body that is not copper, tin or iron is not")
	# Caves: on this hill every mouth that meets the body lies within 60 m of the peak, so a cave mouth there takes the mine away; one 300 m off does not.
	var alone: Array = MineSites.plan(data, [ore("c", HILL, PEAK - 20.0)], [], NONE)
	check(alone.size() == 1, "a body under the peak gets a mine")
	check(MineSites.plan(data, [ore("c", HILL, PEAK - 20.0)], [HILL], NONE).is_empty(), "no mine mouth within 150 m of a cave mouth")
	check(str(MineSites.plan(data, [ore("c", HILL, PEAK - 20.0)], [HILL + Vector2(0.0, 300.0)], NONE)) == str(alone), "a cave mouth 300 m off changes nothing")

	# A halo (a ring of ore round a stock, its centre baked as [x, z]): the adit drives for a point 0.6 of the way out on the ring.
	var halo: Dictionary = {"id": "halo", "resource": "copper", "shape": "halo", "center": [HILL.x, HILL.y], "radius_a_m": 100.0, "radius_b_m": 80.0, "angle": 0.5, "top_y": PEAK - 20.0, "thickness_m": 10.0}
	var ring: Array = MineSites.plan(data, [halo], [], NONE)
	check(ring.size() == 1, "a copper halo gets a mine")

	if ring.size() == 1:
		var halo_end: Array = ring[0]["nodes"][int(ring[0]["adit_end"])]
		check(absf(MineSites.target(halo).distance_to(HILL) - 60.0) < 0.01 and flat(halo_end).distance_to(MineSites.target(halo)) < 40.0, "its adit ends at the ring (%s)" % str(halo_end))
		check(floor_of(halo_end) >= PEAK - 40.5 and floor_of(halo_end) + MineSites.ADIT_H <= PEAK - 19.0, "inside the halo's depth (floor %.1f)" % floor_of(halo_end))
	check(MineSites.plan(data, [ore("c", HILL, PEAK - 20.0)], [], HILL + Vector2(150.0, 0.0)).is_empty(), "no mine mouth within 400 m of the start area")
	check(MineSites.camp_points().any(func(c): return (c as Vector2).is_equal_approx(Vector2(58264.0, 72084.0))), "the Ragtooth camp's mouth is kept clear like a cave mouth")
	check(MineSites.plan(data, [ore("edge", Vector2(150.0, 1000.0), 3.0)], [], NONE).is_empty(), "no mine within 300 m of the tile edge")

	if mines.is_empty():
		print("test_mine_sites: FAIL (%d failures)" % failures)
		quit(1)
		return

	var mine: Dictionary = mines[0]
	var nodes: Array = mine["nodes"]
	check(str(mine["cave_kind"]) == "mine" and str(mine["id"]) == "0,0#mine0" and mine["entrances"] == [0], "a mine in the caves' form (%s)" % str(mine["id"]))

	# The adit: from outside the mouth in to the ore, rising 1 in 100, 1.8 m by 2.4 m; the mouth just under the hillside; one straight piece
	# from outside to the end of the open cut, so the cut is cleared like any cave entrance.
	var mouth: Array = mine["mouth"]
	var ground: float = data.height_at(float(mouth[0]), float(mouth[2]))
	check(absf(float(mouth[1]) - (ground - 0.4)) < 0.05, "the mouth's floor is just under the hillside (%.2f, ground %.2f)" % [float(mouth[1]), ground])
	var end: Array = nodes[int(mine["adit_end"])]
	var length: float = flat(end).distance_to(flat(mouth))
	check(absf(floor_of(end) - float(mouth[1]) - MineSites.RISE * length) < 0.02, "the adit rises 1 in 100 (%.2f m over %.1f m)" % [floor_of(end) - float(mouth[1]), length])
	var cut: float = flat(nodes[1]).distance_to(flat(mouth))
	check(cut >= MineSites.OPEN_CUT_M - 0.01 and cut <= MineSites.OPEN_CUT_MAX_M + 0.01 and mine["segments"][0] == [0, 1, "passage"], "the open cut is %.1f m, one piece from outside" % cut)
	var climbing: bool = true

	for n in range(2, int(mine["adit_end"]) + 1):
		climbing = climbing and floor_of(nodes[n]) > floor_of(nodes[n - 1])

	check(climbing, "every step of the adit climbs, so water runs out of the mouth")
	var body: Dictionary = bodies.filter(func(b): return str(b["id"]) == str(mine["ore"]))[0]
	var band: Vector2 = MineSites.span(body)
	var centre: Vector2 = Vector2(float(body["center"][0]), float(body["center"][2]))
	check(flat(end).distance_to(centre) < 40.0 and floor_of(end) >= band.x - 0.5 and floor_of(end) + MineSites.ADIT_H <= band.y + 1.0, "the adit ends in the ore body (%s)" % str(end))
	check(flat(nodes[0]).distance_to(HILL) > flat(mouth).distance_to(HILL), "the first node lies outside the mouth, downhill")
	check(nodes.all(func(n): return float(n[3]) >= MineSites.ADIT_W and float(n[4]) >= MineSites.ADIT_H - 0.01), "every passage is at least 1.8 m by 2.4 m (the 1 m voxels never close it)")
	check(roof_left(data, mine, cut) >= MineSites.COVER_M - 0.3, "past the open cut the hill stands 2 m over every roof, drifts and stopes too (%.2f m)" % roof_left(data, mine, cut))

	# Timbers: sets across the adit from the mouth in, every 2.7 m, turned the way it runs; props in the stopes. Looks only (cave_bones rows).
	var timbers: Array = mine["timbers"]
	var sets: Array = rows_of(timbers, MineSites.TIMBER_SET) + rows_of(timbers, MineSites.TIMBER_FALLEN)
	var rule: Dictionary = MineSites.SIZES[str(mine["size"])]
	check(sets.size() == int(float(rule["timbered"]) / MineSites.SET_EVERY_M) + 1, "%d timber sets through the mouth of a %s mine" % [sets.size(), str(mine["size"])])
	check(flat(sets[0]).distance_to(flat(mouth)) < 1.0, "the first set stands at the mouth")
	var run: Vector2 = (flat(end) - flat(mouth)).normalized()
	check(absf(angle_difference(float(sets[0][4]), atan2(run.x, run.y))) < 0.2, "a set is turned the way the adit runs")
	var stopes: int = (mine["chambers"] as Array).filter(func(c): return c["features"].has("stope")).size()
	var propped: int = (mine["chambers"] as Array).filter(func(c): return c["features"].has("stope") and float(c["height_m"]) >= MineSites.PROP_ROOM_M).size()
	check(stopes >= 1 and rows_of(timbers, MineSites.TIMBER_POST).size() == 2 * propped, "%d stopes, two props in each of the %d tall enough" % [stopes, propped])
	check((mine["chambers"] as Array).all(func(c): return float(c["height_m"]) >= MineSites.ADIT_H and float(c["height_m"]) <= 3.8), "a stope is 2.4 to 3.8 m tall, as the rock over it allows")
	check(timbers.all(func(t): return (t as Array).size() == 5), "timber rows are x, y, z, kind, yaw")

	# Left behind: a worn pick at the far end, pieces of the body's ore in the stopes, a spoil heap of stones and boulders outside.
	var extra: Array = mine["extra"]
	var left: Array = rows_of(extra, 2.0).map(func(r): return MineSites.LEFTOVERS[int(r[4])])
	check(left.has("copper_pickaxe"), "an old pick is left behind (%s)" % str(left))
	check(left.has("copper_ore") and not left.has("tin_ore") and not left.has("iron_ore"), "the ore pieces are the body's copper ore")
	var spoil: Array = rows_of(extra, 0.0) + rows_of(extra, 1.0)
	check(spoil.size() >= 15, "a spoil heap of %d stones and boulders" % spoil.size())
	check(rows_of(extra, 0.0).all(func(r): return (flat(r) - flat(mouth)).dot(run) < -0.9), "the spoil stones lie at least 1 m outside the mouth")
	var table = ItemTable.load_default()
	check(MineSites.LEFTOVERS.all(func(id): return table.number_of(id) > 0), "every leftover is in the catalog")

	# A large mine (its adit laid by hand): two drifts, 3 or 4 stopes, an air shaft up from the first drift, fallen in 3 m under the hill.
	var out: Vector2 = Vector2(1.0, 0.0)
	var far_mouth: Vector2 = HILL + out * 230.0
	var big: Dictionary = MineSites.build(data, ore("big", HILL + out * 20.0, PEAK - 8.0), {"mouth": far_mouth, "dir": -out, "length": 210.0, "floor": data.height_at(far_mouth.x, far_mouth.y) - 0.4, "cut": 12.0}, 1)
	check(str(big["size"]) == "large" and str(big["id"]) == "0,0#mine1", "a 210 m adit is a large mine")
	check(roof_left(data, big, 12.0) >= MineSites.COVER_M - 0.3, "a large mine's rooms all stay 2 m under the hill (%.2f m)" % roof_left(data, big, 12.0))
	var shaft: Array = (big["segments"] as Array).filter(func(s): return str(s[2]) == "shaft")
	check(shaft.size() == 1, "a large mine has an air shaft")

	if shaft.size() == 1:
		var top: Array = big["nodes"][int(shaft[0][1])]
		check(absf(float(top[1]) - (data.height_at(float(top[0]), float(top[2])) - 3.0)) < 0.05, "the shaft stops 3 m under the hill (fallen in)")

	check((big["chambers"] as Array).filter(func(c): return c["features"].has("shaft_hollow")).size() == 1, "a hollow on the hill marks the shaft")
	check((big["chambers"] as Array).filter(func(c): return c["features"].has("stope")).size() >= 3, "a large mine has 3 or 4 stopes")
	var small_mouth: Vector2 = HILL + out * 60.0
	var small: Dictionary = MineSites.build(data, ore("small", HILL + out * 20.0, PEAK - 24.0), {"mouth": small_mouth, "dir": -out, "length": 40.0, "floor": data.height_at(small_mouth.x, small_mouth.y) - 0.4, "cut": 12.0}, 2)
	check(str(small["size"]) == "small" and (small["segments"] as Array).all(func(s): return str(s[2]) != "shaft"), "a small mine has no shaft")

	# Loading: timbers go to cave_bones (kinds 6 to 8), leftovers and spoil to the cave scatter; a mine holds no goblins or animals.
	data._load_caves([mine, big])
	var bone_kinds: Array = []

	for n in range(0, data.cave_bones.size(), 5):
		bone_kinds.append(int(data.cave_bones[n + 3]))

	var any_props: bool = (mine["chambers"] + big["chambers"]).any(func(c): return float(c["height_m"]) >= MineSites.PROP_ROOM_M)
	check(bone_kinds.has(6) and bone_kinds.has(7) == any_props and bone_kinds.all(func(k): return k >= 6 and k <= 8), "a mine's dressing is its timbers only (%s)" % str(bone_kinds))
	check(data.goblin_dens.is_empty() and data.animal_den_mouths.is_empty(), "no goblins or animals in a mine")
	check(data.cave_mouths.size() == 2, "both mouths count as cave mouths (shelter, cave air)")
	data.build_cave_scatter()
	var scatter_left: int = 0

	for n in range(0, data.cave_scatter.size(), 5):
		scatter_left += 1 if int(data.cave_scatter[n + 3]) == 2 else 0

	check(scatter_left == rows_of(mine["extra"], 2.0).size() + rows_of(big["extra"], 2.0).size(), "the leftovers are in the cave scatter (%d)" % scatter_left)

	print("test_mine_sites: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
