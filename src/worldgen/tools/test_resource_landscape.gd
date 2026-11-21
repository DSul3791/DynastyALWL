extends SceneTree

# The island resource landscape (docs/handoff/RESOURCE_DISTRIBUTION_ARCHITECTURE.md, Dave 21 Nov 2026; docs/design/RESOURCE_DISTRIBUTION.md):
# src/stream/resource_context.gd on a made-up island, and the server's scatter reading it (server_items.gd _lay_out_sources, ore rocks,
# boulders), and the client's rock shapes. No tiles: the island is built from arrays.
#   godot --headless --path . --script res://src/worldgen/tools/test_resource_landscape.gd

const ContextScript := preload("res://src/stream/resource_context.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const OreRockLook := preload("res://src/client/ore_rock_look.gd")

const N := 161            # cells a side (64 m): about 10 km
const CELL := 64.0
const CENTRE := Vector2(5120.0, 5120.0)
const RADIUS := 4300.0    # the shore
const PEAK := 700.0
const SEED := 574716103

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


# A round island with eight valleys running out from a peak: ground falls from PEAK at the centre to 0 at the shore, the valleys cut 60 m.
static func ground(x: float, z: float) -> float:
	var d: Vector2 = Vector2(x, z) - CENTRE
	var r: float = d.length()

	if r >= RADIUS:
		return -20.0

	var share: float = 1.0 - r / RADIUS
	return PEAK * share * share + 2.0 - 60.0 * share * pow(absf(sin(d.angle() * 4.0)), 0.3) * (1.0 - share) + 1.0


func island(cfg: Dictionary, spawn: Vector3) -> RefCounted:
	var heights: PackedFloat32Array = PackedFloat32Array()
	var classes: PackedByteArray = PackedByteArray()
	heights.resize(N * N)
	classes.resize(N * N)

	for j in range(N):
		for i in range(N):
			var h: float = ground(float(i) * CELL, float(j) * CELL)
			heights[j * N + i] = h if h > 0.0 else NAN
			classes[j * N + i] = 0 if h > 0.0 else 1

	var context: RefCounted = ContextScript.new()
	context.build(heights, classes, N, N, Vector2.ZERO, CELL, SEED, cfg, spawn)
	return context


func _init() -> void:
	var all_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/boulders.json"))
	var cfg: Dictionary = all_cfg.get("distribution", {})
	check(not cfg.is_empty() and float(cfg["cover"]["iron"]) > float(cfg["cover"]["copper"]) and float(cfg["cover"]["copper"]) > float(cfg["cover"]["tin"]) and float(cfg["cover"]["tin"]) > 0.2, "boulders.json ships the landscape: iron covers most, copper less, tin less again but a good share")
	var spawn: Vector3 = Vector3(CENTRE.x + RADIUS - 40.0, 2.0, CENTRE.y)
	var context: RefCounted = island(cfg, spawn)
	check(bool(context.call("ready")), "the landscape builds from a height grid")

	# 1. Journey: the shore is 0-ish, the heart of the island near 1, and it rises inland along every way in.
	var shore_j: float = float(context.call("journey_at", spawn.x, spawn.z))
	var heart_j: float = float(context.call("journey_at", CENTRE.x, CENTRE.y))
	var mid_j: float = float(context.call("journey_at", CENTRE.x + RADIUS * 0.5, CENTRE.y))
	check(shore_j < 0.2 and heart_j > 0.8 and mid_j > shore_j and mid_j < heart_j, "journey runs from the shore (%.2f) through the middle (%.2f) to the heart (%.2f)" % [shore_j, mid_j, heart_j])

	# 2. The paint: shares of the land, nested without being rings, earlier metals inside later ones.
	var land: int = 0
	var cover: Array = [0, 0, 0]
	var tin_with_iron: int = 0
	var tin_with_copper: int = 0
	var field: PackedFloat32Array = context.get("field")
	var isl: PackedInt32Array = context.get("island")
	var journey: PackedFloat32Array = context.get("journey")
	var tin_journeys: PackedFloat32Array = PackedFloat32Array()

	for k in range(N * N):
		if isl[k] == 0:
			continue

		land += 1

		for m in 3:
			cover[m] += 1 if field[k * 3 + m] >= 0.5 else 0

		if field[k * 3 + 2] >= 0.5:
			tin_with_iron += 1 if field[k * 3] >= 0.5 else 0
			tin_with_copper += 1 if field[k * 3 + 1] >= 0.5 else 0

			if field[k * 3 + 2] < 0.9:
				tin_journeys.append(journey[k])   # the tin area's edge

	var shares: Array = [float(cover[0]) / float(land), float(cover[1]) / float(land), float(cover[2]) / float(land)]
	print("land %d cells; iron %.2f, copper %.2f, tin %.2f of it; tin with iron %d, with copper %d of %d" % [land, shares[0], shares[1], shares[2], tin_with_iron, tin_with_copper, cover[2]])
	check(float(shares[0]) > float(shares[1]) and float(shares[1]) > float(shares[2]) and float(shares[2]) > 0.25, "iron covers the most, then copper, then tin (a substantial interior area)")
	check(float(tin_with_iron) > 0.9 * float(cover[2]) and float(tin_with_copper) > 0.6 * float(cover[2]), "inside the tin area, iron is nearly everywhere and copper mostly too")
	var lo_j: float = 1.0
	var hi_j: float = 0.0

	for j in tin_journeys:
		lo_j = minf(lo_j, j)
		hi_j = maxf(hi_j, j)

	check(tin_journeys.size() > 10 and hi_j - lo_j > 0.15, "the tin area's edge wanders in and out (journey %.2f..%.2f along it): not a ring" % [lo_j, hi_j])
	check(float(context.call("field_at", 2, spawn.x, spawn.z)) < 0.5, "no tin area on the shore")

	# 3. Sources: each metal has some; the same every build; the near lookup finds them.
	var deposits: Array = context.get("deposits")
	var per: Dictionary = {"iron": 0, "copper": 0, "tin": 0}

	for d in deposits:
		per[str(d["metal"])] += 1

	print("sources: %s; %s" % [str(per), "; ".join(context.get("report"))])
	check(int(per["iron"]) > 0 and int(per["copper"]) > 0 and int(per["tin"]) > 0, "sources of iron, copper and tin")
	var again: RefCounted = island(cfg, spawn)
	check(str(again.get("deposits")) == str(deposits) and again.get("field") == field and again.get("clue") == context.get("clue"), "the same island gives the same areas, sources and clues every time")

	var first: Dictionary = deposits[0]
	var near: PackedInt32Array = context.call("deposits_near", float(first["x"]), float(first["z"]), 1.0)
	check(near.size() >= 1 and int(near[0]) == 0, "deposits_near finds a source at its own place")

	# 4. River clues: 1 at a source, fading down its own drainage, nothing upstream of it.
	var clue: PackedFloat32Array = context.get("clue")
	var receiver: PackedInt32Array = context.get("receiver")
	var tin: Dictionary = {}

	for d in deposits:
		if str(d["metal"]) == "tin":
			tin = d
			break

	var c: int = int(context.call("cell_at", float(tin["x"]), float(tin["z"])))
	var at_source: float = clue[c * 3 + 2]
	var down: int = c
	var below: float = at_source

	for step in 6:
		if receiver[down] < 0:
			break

		down = receiver[down]
		below = clue[down * 3 + 2]

	check(is_equal_approx(at_source, 1.0) and below < at_source and below >= 0.0, "a tin clue is 1 at its source and fades downstream (%.2f six cells down)" % below)
	var upstream_clean: bool = true
	var nx: int = int(context.get("nx"))

	for k in range(N * N):
		if receiver[k] == c and clue[k * 3 + 2] >= 0.999:
			upstream_clean = false   # a cell above the source with the source's own full clue would mean the clue ran uphill

	check(upstream_clean and nx == N, "no clue runs uphill from a source")

	# 5. The starting island: a route budget too small for any drawn tin source makes an assured one within it.
	var tight: Dictionary = cfg.duplicate(true)
	tight["route_budget_m"] = {"iron": 100000.0, "copper": 100000.0, "tin": 2500.0}
	tight["deposit_chance"] = {"iron": 0.1, "copper": 0.22, "tin": 0.0}
	var assured: RefCounted = island(tight, spawn)
	var assured_tin: Array = (assured.get("deposits") as Array).filter(func(d): return str(d["metal"]) == "tin")
	check(assured_tin.size() == 1 and bool(assured_tin[0]["assured"]) and Vector2(float(assured_tin[0]["x"]) - spawn.x, float(assured_tin[0]["z"]) - spawn.z).length() < 2500.0, "with no tin drawn, an assured tin source is placed within reach of spawn (%s)" % str(assured_tin))

	# 6. The server lays a source out: outcrops and fragments in the right cells, the same every time, angular, its own ore.
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.ground_height = func(x, z): return maxf(ground(x, z), 0.5)
	items.setup(ItemTableScript.load_default(), "user://test_resource_landscape")
	items.resource_context = context
	var cell: Vector2i = Vector2i(floori(float(tin["x"]) / 32.0), floori(float(tin["z"]) / 32.0))
	var laid: Array = []

	for dz in range(-5, 6):
		for dx in range(-5, 6):
			items._lay_out_sources(cell + Vector2i(dx, dz), 32.0, items._cell_reads(cell + Vector2i(dx, dz), 32.0))

	var keys: Dictionary = {}
	var keys_unique: bool = true
	var in_cell: bool = true
	var outcrops: int = 0
	var angular: bool = true

	for id in items._items:
		var it: Dictionary = items._items[id]
		var key: int = int(it["scatter"])
		keys_unique = keys_unique and not keys.has(key)
		keys[key] = true
		var own: Vector2i = Vector2i(floori(it["pos"].x / 32.0), floori(it["pos"].z / 32.0))
		in_cell = in_cell and ((key >> 28) & 0xfffff) == (own.x & 0xfffff) and ((key >> 8) & 0xfffff) == (own.y & 0xfffff)

		if it.has("boulder") and int((it["boulder"] as Dictionary).get("source", 0)) == int(tin["id"]) and Vector2(it["pos"].x - float(tin["x"]), it["pos"].z - float(tin["z"])).length() <= float(tin["radius"]) + 0.5:
			outcrops += 1
			angular = angular and float(it["boulder"]["ang"]) >= 0.7 and str(it["boulder"]["ore"]) == "tin" and float(it["boulder"]["grade"]) > 0.3

	var first_lay: String = str(items._items.values().map(func(it): return [it["scatter"], it["pos"]]))
	items._items.clear()

	for dz in range(-5, 6):
		for dx in range(-5, 6):
			items._lay_out_sources(cell + Vector2i(dx, dz), 32.0, items._cell_reads(cell + Vector2i(dx, dz), 32.0))

	check(outcrops >= 2 and angular, "a tin source shows %d angular, rich tin outcrops at its place" % outcrops)
	check(keys_unique and in_cell, "every source rock has its own key, in the cell that holds it")
	check(str(items._items.values().map(func(it): return [it["scatter"], it["pos"]])) == first_lay, "the same rocks in the same places every time")

	# 7. Copper and tin rocks keep their inland identity: none on dry shore land far from any source or clue.
	items._items.clear()
	items.water_near = func(_pos, _reach): return false
	items.water_depth_at = func(_pos): return 0.0
	var shore_tin: int = 0

	for row in range(-20, 20):
		for col in range(-6, 0):
			var shore_cell: Vector2i = Vector2i(floori((CENTRE.x + RADIUS) / 32.0) + col, floori(CENTRE.y / 32.0) + row)
			items._lay_out_ore_rocks(shore_cell, 32.0, "tin")

	for id in items._items:
		var it: Dictionary = items._items[id]
		var number_tin: bool = int(it["number"]) == items.table.number_of("tin_ore")
		var spot_area: float = float(context.call("field_at", 2, it["pos"].x, it["pos"].z))
		shore_tin += 1 if (number_tin or str((it.get("boulder", {}) as Dictionary).get("ore", "")) == "tin") and spot_area < 0.05 else 0

	check(shore_tin == 0, "no tin rocks on the dry shore outside the tin area (%d)" % shore_tin)

	# 8. Rock shapes: round, broken, jagged; a row without a shape keeps the photos' shape exactly.
	check(OreRockLook.shape_of(-1.0) == 1 and OreRockLook.shape_of(0.1) == 0 and OreRockLook.shape_of(0.5) == 1 and OreRockLook.shape_of(0.9) == 2, "shapes by how worn a rock is")
	var legacy: ArrayMesh = OreRockLook.make_mesh(101)
	var middle: ArrayMesh = OreRockLook.mesh_for(0.0)
	check(legacy.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] == middle.surface_get_arrays(0)[Mesh.ARRAY_VERTEX], "an ore rock without a shape is the same mesh as before")
	var jagged: ArrayMesh = OreRockLook.mesh_for(0.0, 0.95)
	var rounded: ArrayMesh = OreRockLook.mesh_for(0.0, 0.05)
	check(jagged != middle and rounded != middle and jagged.get_aabb().size.x > 0.4 and rounded.get_aabb().size.x > 0.4, "jagged and rounded rocks are their own meshes, about rock sized")

	print("resource landscape: %d failures" % failures)
	quit(1 if failures > 0 else 0)
