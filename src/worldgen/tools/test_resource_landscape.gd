extends SceneTree

# The island resource landscape (docs/handoff/RESOURCE_DISTRIBUTION_ARCHITECTURE.md, Dave 21 Nov 2026; docs/design/RESOURCE_DISTRIBUTION.md):
# src/stream/resource_context.gd on a made-up island, and the server's scatter reading it (server_items.gd _lay_out_sources, ore rocks,
# boulders), and the client's rock shapes; stage 2: coal districts and seams (outcrops, digging coal), gold and silver veins, pockets a dig opens (saved, broken
# for their find) and the five new finds. No tiles: the island is built from arrays.
#   godot --headless --path . --script res://src/worldgen/tools/test_resource_landscape.gd

const ContextScript := preload("res://src/stream/resource_context.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const OreRockLook := preload("res://src/client/ore_rock_look.gd")
const Net := preload("res://src/stream/terrain_net.gd")

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


# The island; with a lake (water class 2) of 250 m round `lake` when one is given; `supply` (first_bronze, ore_per_m3) turns the quantity check on.
func island(cfg: Dictionary, spawn: Vector3, lake: Vector2 = Vector2.INF, supply: Dictionary = {}) -> RefCounted:
	var heights: PackedFloat32Array = PackedFloat32Array()
	var classes: PackedByteArray = PackedByteArray()
	heights.resize(N * N)
	classes.resize(N * N)

	for j in range(N):
		for i in range(N):
			var h: float = ground(float(i) * CELL, float(j) * CELL)
			heights[j * N + i] = h if h > 0.0 else NAN
			classes[j * N + i] = 0 if h > 0.0 else 1

			if h > 0.0 and lake != Vector2.INF and Vector2(float(i) * CELL, float(j) * CELL).distance_to(lake) < 250.0:
				classes[j * N + i] = 2

	var context: RefCounted = ContextScript.new()

	for key in supply:
		context.set(key, supply[key])

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
	# The rich layer (Dave 27 Nov 2026, the layered cake, BugsList 186): richest at the mountain's foot, less on the mountain, least by the shore;
	# iron's area reaches the shore.
	var shore_r: float = float(context.call("rich_at", spawn.x, spawn.z))
	var heart_r: float = float(context.call("rich_at", CENTRE.x, CENTRE.y))
	var mid_r: float = float(context.call("rich_at", CENTRE.x + RADIUS * 0.5, CENTRE.y))
	check(mid_r > heart_r + 0.05 and mid_r > shore_r + 0.3 and heart_r > 0.6, "the richest ground is at the mountain's foot (%.2f), then the mountain (%.2f, still good), least by the shore (%.2f)" % [mid_r, heart_r, shore_r])
	var shore_iron: float = float(context.call("field_at", 0, CENTRE.x + RADIUS * 0.9, CENTRE.y))
	check(shore_iron >= 0.45, "iron's area reaches the shore (%.2f near it)" % shore_iron)

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

	# 5b. Known dangers (hostile camps, bandit camps) keep the starting-island routes out of their ground.
	var safe_cost: PackedFloat32Array = context.call("_route_costs", int(context.call("cell_at", spawn.x - 64.0, spawn.z)), int(isl[int(context.call("cell_at", spawn.x - 64.0, spawn.z))]))
	var risky: RefCounted = ContextScript.new()
	var camp: Vector2 = Vector2(CENTRE.x + RADIUS * 0.5, CENTRE.y)
	risky.set("dangers", [[camp.x, camp.y, 300.0]])
	risky.build(context.get("height").duplicate(), context.get("water").duplicate(), N, N, Vector2.ZERO, CELL, SEED, cfg, spawn)
	var risky_cost: PackedFloat32Array = risky.call("_route_costs", int(context.call("cell_at", spawn.x - 64.0, spawn.z)), int(isl[int(context.call("cell_at", spawn.x - 64.0, spawn.z))]))
	var camp_cell: int = int(context.call("cell_at", camp.x, camp.y))
	check(safe_cost[camp_cell] < INF and risky_cost[camp_cell] == INF and str(risky.get("report")).contains("known dangers"), "a route never crosses a known danger's ground (%.0f m without it)" % safe_cost[camp_cell])

	# 5c. Enough copper and tin for the first bronze (handoff 13, bronze progression): the need is read from the live recipes, blueprints and
	# smelter; sources within the budgets short of it get assured ones beside them.
	var supply: Dictionary = ContextScript.supply_inputs(all_cfg)
	var first_need: Dictionary = supply["first_bronze"]
	var recipes_live: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/recipes.json")) as Dictionary)["recipes"]
	var direct: int = 0

	for piece in cfg["first_bronze"]["tools"]:
		for need in recipes_live[piece]["needs"]:
			direct += int(need[1]) if str(need[0]) == "bronze_ingot" else 0

	var per_player: Dictionary = first_need.get("per_player", {})
	check(direct > 0 and int(first_need.get("ingots", 0)) > direct and int(per_player.get("copper", 0)) == ceili(float(first_need["ingots"]) / 2.0) and int(per_player.get("tin", 0)) == int(per_player["copper"]) and int(first_need["tin"]) == int(per_player["tin"]) * int(first_need["players"]) and float(supply["ore_per_m3"]) > 1000.0 and int(supply["ore_cost"]["tin"]) >= 1, "the first bronze ore comes from the live tools, stations and bronze job: %d ingots, %s a player, %d players" % [int(first_need.get("ingots", 0)), str(per_player), int(first_need.get("players", 0))])
	var fed: RefCounted = island(cfg, spawn, Vector2.INF, supply)
	var fed_report: String = "\n".join(fed.get("report"))
	check(fed_report.contains("tin within") and fed_report.contains("copper within") and not fed_report.contains("SHORT"), "the shipped island holds the first bronze copper and tin for a full server within the budgets")
	var hungry_supply: Dictionary = supply.duplicate(true)
	hungry_supply["first_bronze"]["tin"] = 1000000000
	var hungry: RefCounted = island(cfg, spawn, Vector2.INF, hungry_supply)
	var count_tin: Callable = func(ctx: RefCounted, only_assured: bool) -> int:
		return (ctx.get("deposits") as Array).filter(func(d): return str(d["metal"]) == "tin" and (bool(d["assured"]) or not only_assured)).size()
	var hungry_report: String = "\n".join(hungry.get("report"))
	var lean: Dictionary = cfg.duplicate(true)
	lean["known_sources"] = {"iron": 1, "copper": 1, "tin": 1}
	var base: RefCounted = island(lean, spawn)   # no quantity check, one source of each wanted: only the nearest-source assurance
	check(int(count_tin.call(hungry, true)) - int(count_tin.call(base, true)) == 3 and int(count_tin.call(hungry, false)) == int(count_tin.call(base, false)) + 3 and hungry_report.contains("tin within") and hungry_report.contains("SHORT") and (hungry.get("deposits") as Array).filter(func(d): return str(d["metal"]) == "copper").size() == (fed.get("deposits") as Array).filter(func(d): return str(d["metal"]) == "copper").size(), "short of tin, the island gets at most three assured tin sources and says SHORT; copper untouched")
	var tin_held: Callable = func(ctx: RefCounted) -> float:
		var total: float = 0.0
		for d in ctx.get("deposits"):
			total += float(ctx.call("source_ore", d)) if str(d["metal"]) == "tin" else 0.0
		return total
	check(float(tin_held.call(hungry)) > float(tin_held.call(fed)), "each assured tin source adds its ore")
	var curious: Dictionary = cfg.duplicate(true)
	curious["known_sources"] = {"iron": 50, "copper": 1, "tin": 1}
	var known: RefCounted = island(curious, spawn, Vector2.INF, supply)
	var iron_assured: Callable = func(ctx: RefCounted) -> int:
		return (ctx.get("deposits") as Array).filter(func(d): return str(d["metal"]) == "iron" and bool(d["assured"])).size()
	check(int(iron_assured.call(known)) == int(iron_assured.call(base)) + 3 and "\n".join(known.get("report")).contains("(50 wanted)"), "wanting more known iron sources than drawn adds up to three assured ones (several iron locations known before iron smelting)")

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

	for dz in range(-5, 6):
		for dx in range(-5, 6):
			items._lay_out_sources(cell + Vector2i(dx, dz), 32.0, items._cell_reads(cell + Vector2i(dx, dz), 32.0))

	var keys: Dictionary = {}
	var keys_unique: bool = true
	var in_cell: bool = true
	var outcrops: int = 0
	var angular: bool = true
	var tin_size: float = float(tin["size"])
	var outcrop_at: Array = []   # where the server puts the source's outcrops (server_items._lay_out_sources), so its fragments are not counted as outcrops

	for k in range(int(round(lerpf(float(cfg.get("source_outcrops_min", 2)), float(cfg.get("source_outcrops_max", 8)), tin_size)))):
		outcrop_at.append(Vector2(float(tin["x"]), float(tin["z"])) + Vector2(sqrt(ContextScript.unit(int(tin["id"]), k, 1)) * float(tin["radius"]), 0.0).rotated(ContextScript.unit(int(tin["id"]), k, 2) * TAU))

	for id in items._items:
		var it: Dictionary = items._items[id]
		var key: int = int(it["scatter"])
		keys_unique = keys_unique and not keys.has(key)
		keys[key] = true
		var own: Vector2i = Vector2i(floori(it["pos"].x / 32.0), floori(it["pos"].z / 32.0))
		in_cell = in_cell and ((key >> 28) & 0xfffff) == (own.x & 0xfffff) and ((key >> 8) & 0xfffff) == (own.y & 0xfffff)

		if it.has("boulder") and int((it["boulder"] as Dictionary).get("source", 0)) == int(tin["id"]) and outcrop_at.any(func(at: Vector2) -> bool: return at.distance_to(Vector2(it["pos"].x, it["pos"].z)) < 0.01):
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

	# 6b. The look lines (Lane A's pictures): each metal's nearest sources by route, the nearest tin's biggest outcrop where the server lays one.
	var looks: Array = Array(context.get("report")).filter(func(line: String) -> bool: return line.begins_with("resources: look "))
	var tin_look: Array = looks.filter(func(line: String) -> bool: return line.begins_with("resources: look tin source at "))
	var look_ok: bool = looks.any(func(line: String) -> bool: return line.begins_with("resources: look iron source at ")) and looks.any(func(line: String) -> bool: return line.begins_with("resources: look copper source at ")) and not tin_look.is_empty()

	if look_ok:
		var line0: String = str(tin_look[0])
		var at_parts: PackedStringArray = line0.trim_prefix("resources: look tin source at ").split(" (")[0].split(", ")
		var big_parts: PackedStringArray = line0.split("biggest outcrop at ")[1].split(" (")[0].split(", ")
		var look_centre: Vector2 = Vector2(float(at_parts[0]), float(at_parts[1]))
		var biggest: Vector2 = Vector2(float(big_parts[0]), float(big_parts[1]))
		var look_src: Array = (context.get("deposits") as Array).filter(func(d: Dictionary) -> bool: return str(d["metal"]) == "tin" and look_centre.distance_to(Vector2(float(d["x"]), float(d["z"]))) < 0.1)
		look_ok = look_src.size() == 1

		if look_ok:
			var look_cell: Vector2i = Vector2i(floori(float(look_src[0]["x"]) / 32.0), floori(float(look_src[0]["z"]) / 32.0))
			items._items.clear()

			for dz in range(-2, 3):
				for dx in range(-2, 3):
					items._lay_out_sources(look_cell + Vector2i(dx, dz), 32.0, items._cell_reads(look_cell + Vector2i(dx, dz), 32.0))

			look_ok = items._items.values().any(func(it: Dictionary) -> bool: return it.has("boulder") and int((it["boulder"] as Dictionary).get("source", 0)) == int(look_src[0]["id"]) and biggest.distance_to(Vector2(it["pos"].x, it["pos"].z)) < 0.1)

	check(look_ok, "the log names where to look: the nearest iron, copper and tin sources, and the nearest tin's biggest outcrop is a rock the server lays there (%d look lines)" % looks.size())

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

	_stage_two(all_cfg, cfg, spawn, context)
	print("resource landscape: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# A server on the made-up island with a character "resource01" at `at` holding `tool_id` ("" none); `context` is its landscape.
func server(dir_name: String, context: RefCounted, at: Vector3, tool_id: String, clear: bool = true):
	var dir: String = "user://" + dir_name
	DirAccess.make_dir_recursive_absolute(dir)

	if clear:
		for file in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_reject = func(_p, _r): pass
	items.ground_height = func(x, z): return maxf(ground(x, z), 0.5)
	items.setup(ItemTableScript.load_default(), dir)
	items.resource_context = context
	items._boulder_cfg["luck_extra"] = 0.0
	items._boulder_cfg["flint"] = {}
	items.peer_connected_hello(1, "resource01")
	items.report_position(1, at)
	items.vitals_of(1)["weight"] = 5000.0
	items._characters["resource01"]["luck"] = 50
	items._fate_rng.seed = 1518

	if tool_id != "":
		items.action(1, Net.ACT_ADMIN_GIVE, items.table.number_of(tool_id), 0, 1, Vector3.ZERO)

	return items


func _stage_two(all_cfg: Dictionary, cfg: Dictionary, spawn: Vector3, plain: RefCounted) -> void:
	# 9. The five new finds (coordinator D-ORE-1): items 1518..1522, sell value only, and every pocket find names a real item.
	var table = ItemTableScript.load_default()
	var numbers: Array = []

	for id in ["gold_nugget", "silver_ore", "amethyst", "garnet", "agate"]:
		numbers.append(int(table.entry(id).get("number", 0)))

	check(numbers == [1518, 1519, 1520, 1521, 1522], "Gold nugget, Silver ore, Amethyst, Garnet and Agate are items 1518..1522 (%s)" % str(numbers))
	var finds: Dictionary = all_cfg["ore"].get("finds", {})
	var finds_real: bool = not finds.is_empty()

	for row in cfg.get("pockets", []):
		finds_real = finds_real and table.has_id(str(finds.get(str(row["find"]), "")))

	check(finds_real and float(table.entry("gold_nugget").get("value", 0)) > float(table.entry("silver_ore").get("value", 0)), "every pocket's find is a real item; gold is worth more than silver")
	check(not (all_cfg["ore"]["items"] as Dictionary).has("gold") and not (all_cfg["ore"]["items"] as Dictionary).has("amethyst"), "the finds are not outcrop ores: the geology's gold and gem bodies do not turn boulders into them")

	# 10. Coal: none without water near; with a lake on the slope, the hillside beside it is coal country and the far side is not.
	check((plain.get("seams") as Array).is_empty(), "no water near, no coal seams")
	var wet_cfg: Dictionary = cfg.duplicate(true)
	wet_cfg["coal"]["noise_cut"] = -1.0   # every slope near water is a district here, so the places can be checked
	wet_cfg["coal"]["seam_chance"] = 1.0
	var lake: Vector2 = CENTRE + Vector2(0.0, 2000.0)
	var wet: RefCounted = island(wet_cfg, spawn, lake)
	var near_best: float = 0.0
	var far_best: float = 0.0
	var in_lake: float = 0.0

	for a in range(0, 360, 15):
		for r in [300.0, 400.0, 500.0]:
			var off: Vector2 = Vector2(r, 0.0).rotated(deg_to_rad(float(a)))
			near_best = maxf(near_best, float(wet.call("coal_at", lake.x + off.x, lake.y + off.y)))
			far_best = maxf(far_best, float(wet.call("coal_at", CENTRE.x + off.x, CENTRE.y - 2000.0 + off.y)))

		in_lake = maxf(in_lake, float(wet.call("coal_at", lake.x + 60.0 * cos(deg_to_rad(float(a))), lake.y + 60.0 * sin(deg_to_rad(float(a))))))

	check(near_best > 0.2 and far_best == 0.0, "coal on the hillside by the lake (%.2f), none on the same slope far from water (%.2f)" % [near_best, far_best])
	check(in_lake < 0.05, "no coal in the lake itself (%.2f)" % in_lake)
	var seams: Array = wet.get("seams")
	var seams_ok: bool = not seams.is_empty()

	for s in seams:
		var to_peak: Vector2 = (CENTRE - Vector2(float(s["x"]), float(s["z"]))).normalized()
		seams_ok = seams_ok and float(wet.call("coal_at", float(s["x"]), float(s["z"]))) >= float(wet_cfg["coal"]["seam_min"]) and (s["up"] as Vector2).dot(to_peak) > 0.5 and absf((s["along"] as Vector2).dot(s["up"])) < 0.001

	check(seams_ok, "%d seams, each in coal country, running along the slope with its way in pointing up the hill" % seams.size())

	if seams.is_empty():
		print("resource landscape: no seam to lay out; the server coal and pocket checks were not run")
		failures += 1
		return

	var wet_again: RefCounted = island(wet_cfg, spawn, lake)
	check(str(wet_again.get("seams")) == str(seams), "the same seams every build")

	# 10b. The fuels fit the smelting (handoff 13: the charcoal and coal routes fit the bellows smelting): the coal the seams and coal rocks give
	# and Charcoal are both smelter fuel and both go into the Primitive and Improved smelters; the Improved smelter has the bellows the iron
	# jobs need; a Primitive kiln (charcoal from logs) and the Primitive smelter take no metal. The charcoal route through the real server
	# runs in test_bronze_path and test_iron_saw_route; a smelter's coal hopper in test_smelters.
	var structures: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))
	var blueprints: Dictionary = (JSON.parse_string(FileAccess.get_file_as_string("res://data/items/blueprints.json")) as Dictionary)["blueprints"]
	var smelt: Dictionary = structures["smelting"]
	var coal_item: String = str(all_cfg["ore"]["items"]["coal"])
	var fuels: Array = smelt.get("fuel", [])
	var takes_fuel: Callable = func(kind: String) -> bool:
		var takes: Array = structures["structures"][kind].get("takes", [])
		return takes.has(coal_item) and takes.has("charcoal")
	var improved: Dictionary = structures["structures"]["improved_smelter"]["smelt"]
	var no_metal: Callable = func(row: String) -> bool:
		for need in blueprints[row]["cost"]:
			if str(need[0]).ends_with("_ingot") or str(need[0]).ends_with("_nails") or str(need[0]).ends_with("_hinges"):
				return false
		return true
	check(fuels.has(coal_item) and fuels.has("charcoal") and takes_fuel.call("smelter") and takes_fuel.call("improved_smelter"), "seam coal (%s) and Charcoal are smelter fuel and both smelters take them" % coal_item)
	check(bool(improved.get("bellows", false)) and (improved["jobs"] as Array).has("iron") and (improved["jobs"] as Array).has("bog_iron") and bool(smelt["jobs"]["iron"].get("bellows", false)) and bool(smelt["jobs"]["bog_iron"].get("bellows", false)), "the iron jobs want bellows and the Improved smelter has them")
	check(no_metal.call("kiln") and no_metal.call("smelter") and int(structures["kilns"]["yield"].get("log", 0)) > 0, "a Primitive kiln (%d Charcoal a log) and the Primitive smelter take no metal: charcoal never waits on coal" % int(structures["kilns"]["yield"].get("log", 0)))

	# 11. The server: dark coal outcrops where the ground meets the seam, and a shovel in the seam's band digs coal.
	var seam: Dictionary = seams[0]
	var s_at: Vector2 = Vector2(float(seam["x"]), float(seam["z"]))
	var notices: Array = []
	var coal_server = server("test_resource_coal", wet, Vector3(s_at.x, ground(s_at.x, s_at.y) + 1.0, s_at.y), "")
	coal_server.send_notice = func(_p, line): notices.append(line)
	var home: Vector2i = Vector2i(floori(s_at.x / 32.0), floori(s_at.y / 32.0))
	var y: float = coal_server._seam_height(seam)
	coal_server._items.clear()

	for dz in range(-6, 7):
		for dx in range(-6, 7):
			coal_server._lay_out_seams(home + Vector2i(dx, dz), 32.0, coal_server._cell_reads(home + Vector2i(dx, dz), 32.0))

	var outcrops: int = 0
	var on_layer: bool = true
	var slots_ok: bool = true
	var seen: Dictionary = {}

	for id in coal_server._items:
		var it: Dictionary = coal_server._items[id]
		var item_key: int = int(it["scatter"])
		slots_ok = slots_ok and (item_key & 0xff) >= coal_server.SEAM_SLOT_FIRST and not seen.has(item_key)
		seen[item_key] = true

		if it.has("boulder") and int((it["boulder"] as Dictionary).get("seam", 0)) == int(seam["id"]):
			outcrops += 1
			on_layer = on_layer and str(it["boulder"]["ore"]) == "coal" and absf(float(it["pos"].y) - y) < 1.0

	check(outcrops >= 2 and on_layer, "seam %d (at %.1f m) shows %d coal outcrops along the line where the ground meets it" % [int(seam["id"]), y, outcrops])
	check(slots_ok, "seam rocks and loose coal have keys of their own (slots %d..)" % coal_server.SEAM_SLOT_FIRST)
	var coal_n: int = coal_server.table.number_of("coal")
	var in_band: Vector3 = Vector3(s_at.x, y + coal_server.DIG_DEPTH_M, s_at.y) + Vector3((seam["up"] as Vector2).x, 0.0, (seam["up"] as Vector2).y) * 20.0
	check(not coal_server._seam_at(in_band - Vector3(0.0, coal_server.DIG_DEPTH_M, 0.0)).is_empty() and coal_server._seam_at(in_band + Vector3(0.0, 5.0, 0.0)).is_empty(), "20 m into the hill the seam's band holds coal; 5 m above it does not")
	coal_server._dig_seam_coal(1, in_band, 1, 1)
	coal_server._dig_seam_coal(1, in_band, 1, 1)
	var got: int = coal_server.inventory_of(1).count_of(coal_n)
	coal_server._dig_seam_coal(1, in_band + Vector3(0.0, 5.0, 0.0), 1, 1)
	check(got >= 2 and coal_server.inventory_of(1).count_of(coal_n) == got and notices.count(str(wet_cfg["coal"]["first_find"])) == 1, "digging in the seam gives coal (%d from two digs), above it none; the first find is said once" % got)

	var seam_id: int = int(seam["id"])
	coal_server._seam_left[seam_id] = 1   # nearly dug out: a seam is a bounded body (handoff 14)
	coal_server._dig_seam_coal(1, in_band, 1, 1)
	var last: int = coal_server.inventory_of(1).count_of(coal_n) - got
	coal_server._dig_seam_coal(1, in_band, 1, 1)
	check(last == 1 and coal_server.inventory_of(1).count_of(coal_n) == got + 1 and int(coal_server._seam_left[seam_id]) == 0, "a seam gives no more than is left in it, then none")
	coal_server._dirty = true
	coal_server.save()
	var coal_again = server("test_resource_coal", wet, Vector3(s_at.x, ground(s_at.x, s_at.y) + 1.0, s_at.y), "", false)
	check(int(coal_again._seam_left.get(seam_id, -1)) == 0, "what is left in a dug seam is saved with the world")

	# 11b. Host rock (handoff: sedimentary host rock where the world supports it): the same seam in granite has no outcrops and no coal; in
	# shale it is there; unknown rock does not stop it.
	var host_counts: Dictionary = {}

	for rock in ["granite", "shale", ""]:
		var hosted = server("test_resource_host", wet, Vector3(s_at.x, ground(s_at.x, s_at.y) + 1.0, s_at.y), "")
		var rock_name: String = rock
		hosted.rock_near = func(_pos): return rock_name
		hosted._items.clear()

		for dz in range(-6, 7):
			for dx in range(-6, 7):
				hosted._lay_out_seams(home + Vector2i(dx, dz), 32.0, hosted._cell_reads(home + Vector2i(dx, dz), 32.0))

		var shown: int = 0

		for id in hosted._items:
			if hosted._items[id].has("boulder") and int((hosted._items[id]["boulder"] as Dictionary).get("seam", 0)) == seam_id:
				shown += 1

		host_counts[rock] = [shown, hosted._seam_at(in_band - Vector3(0.0, hosted.DIG_DEPTH_M, 0.0)).is_empty()]

	check(int(host_counts["granite"][0]) == 0 and bool(host_counts["granite"][1]) and int(host_counts["shale"][0]) == outcrops and not bool(host_counts["shale"][1]) and int(host_counts[""][0]) == outcrops, "a seam in granite has no outcrops and no coal; in shale and in unknown rock it is all there (%s)" % str(host_counts))

	# 12. Pockets: most sources have none; with every chance at 1 each table row shows, by its own rules, the same every build.
	var real_pockets: int = (plain.get("pockets") as Array).filter(func(p: Dictionary) -> bool: return not p.has("vein")).size()
	check(real_pockets < (plain.get("deposits") as Array).size(), "most sources have no pocket (%d pockets, %d sources)" % [real_pockets, (plain.get("deposits") as Array).size()])
	var rich_cfg: Dictionary = cfg.duplicate(true)

	for row in rich_cfg["pockets"]:
		row["chance"] = 1.0

	var rich: RefCounted = island(rich_cfg, spawn)
	var pockets: Array = rich.get("pockets")
	var by_source: Dictionary = {}

	for d in rich.get("deposits"):
		by_source[int(d["id"])] = d

	var kinds: Dictionary = {}
	var placed_ok: bool = not pockets.is_empty()

	for p in pockets:
		if p.has("vein"):
			continue   # veins: check 14

		kinds[str(p["find"])] = true
		var src: Dictionary = by_source[int(p["source"])]
		var gap: float = Vector2(float(p["x"]) - float(src["x"]), float(p["z"]) - float(src["z"])).length()
		var src_j: float = float(rich.call("journey_at", float(src["x"]), float(src["z"])))

		if str(p["find"]) == "garnet":
			placed_ok = placed_ok and src_j >= 0.7   # journey_min 0.75 at the source's cell (the bilinear read is a touch lower)

		if str(p["find"]) == "silver":
			placed_ok = placed_ok and str(src["metal"]) == "copper"

		if gap > float(src["radius"]) * 1.2 + 1.0:
			placed_ok = placed_ok and str(p["find"]) == "gold"   # only the placer gold lies away from its source, down its river gravels

		placed_ok = placed_ok and (rich.call("pocket", int(p["id"])) as Dictionary) == p

	check(placed_ok and kinds.size() >= 4, "pockets of %s, each by its source's metal and how far inland, gold also down the gravels" % str(kinds.keys()))
	check(str(island(rich_cfg, spawn).get("pockets")) == str(pockets), "the same pockets every build")

	# 13. A dig that reaches a pocket opens it: its rock lies in the hole, is saved with the world, and breaks into its find.
	var pocket: Dictionary = pockets[0]
	var p_at: Vector2 = Vector2(float(pocket["x"]), float(pocket["z"]))
	var surface: float = maxf(ground(p_at.x, p_at.y), 0.5)
	var said: Array = []
	var dig = server("test_resource_pocket", rich, Vector3(p_at.x + 0.6, surface, p_at.y), "stone_hammer")
	dig.send_notice = func(_p, line): said.append(line)
	dig._open_pockets(1, Vector3(p_at.x, surface + 2.0, p_at.y), dig.DIG_RADIUS_M)
	check(dig._pockets_open.is_empty(), "a scrape above the ground does not reach the pocket %.1f m down" % float(pocket["depth"]))
	var hole: Vector3 = Vector3(p_at.x + 0.3, surface - float(pocket["depth"]) + 1.0, p_at.y)
	dig._open_pockets(1, hole, dig.DIG_RADIUS_M)
	var key: int = dig.POCKET_KEY | int(pocket["id"])
	check(dig._pockets_open.has(int(pocket["id"])) and said.size() == 1, "a dig down to it opens the pocket and says what is there: %s" % str(said))
	dig._dirty = true
	dig.save()
	var again = server("test_resource_pocket", rich, Vector3(p_at.x + 0.6, surface, p_at.y), "", false)
	again._items.clear()
	again._boulder_cfg["distribution"]["pocket_rock"]["grade"][str(pocket["find"])] = 1.0   # every piece its find, so the count is sure (set before the rock is laid)
	var cell: Vector2i = Vector2i(floori(hole.x / 32.0), floori(hole.z / 32.0))
	again._lay_out_pockets(cell, 32.0)
	var rock_id: int = -1

	for id in again._items:
		if int(again._items[id].get("scatter", -1)) == key:
			rock_id = id

	check(rock_id >= 0 and str(again._items[rock_id]["boulder"]["ore"]) == str(pocket["find"]) and (again._items[rock_id]["pos"] as Vector3).distance_to(hole) < 0.01, "after a restart the opened pocket's rock lies in the hole")
	var find_item: int = again.table.number_of(str(finds[str(pocket["find"])]))
	again.action(1, Net.ACT_ADMIN_GIVE, again.table.number_of("stone_hammer"), 0, 1, Vector3.ZERO)
	var hammer_slot: int = 0

	for s in range(again.inventory_of(1).slot_count):
		if str(again.table.entry(again.table.id_of(again.inventory_of(1).numbers[s])).get("tool_class", "")) == "hammer":
			hammer_slot = s + 1

	again.report_position(1, again._items[rock_id]["pos"] + Vector3(0.6, 0.0, 0.0))

	for k in range(60):
		again._last_hit.clear()
		again.action(1, Net.ACT_HIT, rock_id, Net.HIT_BOULDER, hammer_slot, Vector3.ZERO)

	var found: int = again.inventory_of(1).count_of(find_item)
	check(found >= 1 and not again._items.has(rock_id), "the pocket rock breaks into %d %s and is gone" % [found, again.table.name_of(find_item)])
	again._dirty = true
	again.save()
	var third = server("test_resource_pocket", rich, Vector3(p_at.x + 0.6, surface, p_at.y), "", false)
	third._items.clear()
	third._lay_out_pockets(cell, 32.0)
	check(third._pockets_open.has(int(pocket["id"])) and third._items.is_empty(), "an emptied pocket stays empty after a restart")

	# 14. Gold and silver veins (R-RES-PRECIOUS): only from iron and tin sources far enough in, starts gap_m apart, outcrops on the ground
	# first then ever deeper along it, gems only under buried pockets; an outcrop lies as a rock with no dig.
	var vein_cfg: Dictionary = cfg.duplicate(true)
	vein_cfg["veins"]["chance"] = 1.0
	vein_cfg["veins"]["gem_per_m"] = 0.2
	vein_cfg["veins"]["gap_m"] = 400.0
	var veined: RefCounted = island(vein_cfg, spawn)
	var vein_rows: Array = (veined.get("pockets") as Array).filter(func(p: Dictionary) -> bool: return p.has("vein"))
	var sources: Dictionary = {}

	for d in veined.get("deposits"):
		sources[int(d["id"])] = d

	var veins: Dictionary = {}
	var vein_ok: bool = not vein_rows.is_empty()
	var gems: int = 0

	for p in vein_rows:
		var src: Dictionary = sources[int(p["source"])]
		vein_ok = vein_ok and ["iron", "tin"].has(str(src["metal"])) and float(veined.call("journey_at", float(src["x"]), float(src["z"]))) >= 0.45

		if ["gold", "silver"].has(str(p["find"])):
			var line: Array = veins.get(int(p["vein"]), [])
			line.append(p)
			veins[int(p["vein"])] = line
		else:
			gems += 1
			vein_ok = vein_ok and float(p["depth"]) > float(vein_cfg["veins"]["depth_m"][0]) and not p.has("show")

	var heads: Array = []

	for v in veins:
		var line: Array = veins[v]
		var shown_n: int = int(vein_cfg["veins"]["outcrop_points"])
		var first: Dictionary = line[0]
		vein_ok = vein_ok and line.size() > shown_n + 1 and bool(first.get("show", false)) and float(first["depth"]) == 0.0 and not (line[shown_n] as Dictionary).has("show")
		vein_ok = vein_ok and float((line[line.size() - 1] as Dictionary)["depth"]) > float((line[shown_n] as Dictionary)["depth"])
		var src: Dictionary = sources[int(first["source"])]

		for h in heads:
			vein_ok = vein_ok and Vector2(float(src["x"]), float(src["z"])).distance_to(h) >= 400.0

		heads.append(Vector2(float(src["x"]), float(src["z"])))

	check(vein_ok and veins.size() >= 1 and gems >= 1, "%d veins from deep iron and tin sources, far apart, outcrops first then deeper, %d gems below" % [veins.size(), gems])
	check(str(island(vein_cfg, spawn).get("pockets")) == str(veined.get("pockets")), "the same veins every build")
	if veins.is_empty():
		print("resource landscape: no vein on the test island; the outcrop check was not run")
		failures += 1
		return

	var outcrop: Dictionary = (veins[veins.keys()[0]] as Array)[0]
	var o_cell: Vector2i = Vector2i(floori(float(outcrop["x"]) / 32.0), floori(float(outcrop["z"]) / 32.0))
	var shows = server("test_resource_vein", veined, Vector3(float(outcrop["x"]) + 1.0, ground(float(outcrop["x"]), float(outcrop["z"])), float(outcrop["z"])), "")
	shows._items.clear()
	shows._lay_out_pockets(o_cell, 32.0, {"ground": func(x: float, z: float) -> float: return maxf(ground(x, z), 0.5)})
	var o_rock: Dictionary = {}

	for id in shows._items:
		if int(shows._items[id].get("scatter", -1)) == shows.POCKET_KEY | int(outcrop["id"]):
			o_rock = shows._items[id]["boulder"]

	check(not o_rock.is_empty() and str(o_rock["ore"]) == str(outcrop["find"]) and float(o_rock["radius"]) >= 0.5, "a vein's outcrop lies on the ground as a %s rock with no dig (%s)" % [str(outcrop["find"]), str(o_rock)])
