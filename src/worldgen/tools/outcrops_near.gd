extends SceneTree

# The outcrop boulders near a spot, as the game lays them out (Sonny, 10 Nov 2026; ground_resources.md 1c): every 32 m scatter cell within the
# radius is laid out by ServerItems._lay_out_cell itself, with the ground, water, ore, rock and cave answers wired exactly as terrain_server.gd
# wires them, and each boulder that is an outcrop (boulders.json ore: tin, copper, coal, iron, salt, or limestone from the bedrock) is printed
# nearest first: ore, position, distance, radius. It reads only (the items store is a scratch folder under user://).
#
# The places match the game only while a boulder's place does not depend on the flora cover: the cells' stick spots read cover_at, and
# before Steve's own-stream fix the boulders shared that random stream. So the tool lays the area out twice, with the cover read as bare
# and as covered, and says "exact" when both give the same boulders, or warns when they differ.
#   godot --headless --path . --script res://src/worldgen/tools/outcrops_near.gd -- [--at=53296,68080] [--radius=400] [--ores=tin,copper] [--top=20]
#        [--world=res://worlds/base_world] [--fields]
# --fields: also the rocky ground's rocks (boulders.json rock_fields, FIELD_KEY): how many of each kind, the best cells of each kind to picture
# with the rocks counted round each camera (rocks_count lines: within 60 m, all and of 1 m radius or more) and look_rig lines, and how rocky
# each kind of ground is over the area (rocks_check lines).

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const CellReadsScript := preload("res://src/stream/cell_reads.gd")
const ContextScript := preload("res://src/stream/resource_context.gd")
const SpawnPointScript := preload("res://src/shared/spawn_point.gd")

const STORE := "user://outcrops_near"


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var at: Vector2 = Vector2(53296.0, 68080.0)   # the temporary spawn
	var radius: float = 400.0
	var wanted: Dictionary = {}
	var top: int = 20
	var fields: bool = false

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			world = argument.trim_prefix("--world=")
		elif argument.begins_with("--at="):
			var p: PackedStringArray = argument.trim_prefix("--at=").split(",")
			at = Vector2(float(p[0]), float(p[1]))
		elif argument.begins_with("--radius="):
			radius = float(argument.trim_prefix("--radius="))
		elif argument.begins_with("--ores="):
			for name in argument.trim_prefix("--ores=").split(","):
				wanted[name] = true
		elif argument.begins_with("--top="):
			top = int(argument.trim_prefix("--top="))
		elif argument == "--fields":
			fields = true

	_tag = "%d" % int(at.x)
	_at = at
	_radius = radius

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if not errors.is_empty():
		print("outcrops_near: cannot start: %s" % str(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var started: int = Time.get_ticks_msec()
	var context: RefCounted = _landscape(world, settings)
	var bare: Dictionary = _boulders(generator, settings, at, radius, 0.0, context)
	var covered: Dictionary = _boulders(generator, settings, at, radius, 1.0, context)
	var exact: bool = bare.keys() == covered.keys()

	for key in bare:
		exact = exact and covered.has(key) and (bare[key]["pos"] as Vector3).distance_to(covered[key]["pos"]) < 0.01 and str(bare[key]["ore"]) == str(covered[key]["ore"])

	var rows: Array = []
	var counts: Dictionary = {}

	for key in bare:
		var row: Dictionary = bare[key]
		var ore: String = str(row["ore"])

		if ore == "" or (not wanted.is_empty() and not wanted.has(ore)):
			continue

		counts[ore] = int(counts.get(ore, 0)) + 1
		rows.append(row)

	rows.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))
	print("outcrops_near: %d boulders within %.0f m of (%.0f, %.0f), %d outcrops %s (%.1f s)" % [bare.size(), radius, at.x, at.y, rows.size(), str(counts),
		float(Time.get_ticks_msec() - started) / 1000.0])
	print("layout: %s" % ("exact: the same boulders with the flora cover read bare and covered" if exact else
		"WARNING: the boulders move with the flora cover (this build lacks the boulders' own random stream): the game's places may differ"))

	for n in range(mini(rows.size(), top)):
		var r: Dictionary = rows[n]
		var p: Vector3 = r["pos"]
		print("  %-9s at (%.1f, %.1f, %.1f)  %4.0f m  radius %.2f m%s%s" % [str(r["ore"]), p.x, p.y, p.z, float(r["dist"]), float(r["radius"]), "  (cave floor)" if bool(r["cave"]) else "",
			"  (%s)" % str(r["from"]) if str(r["from"]) != "" else ""])

	if fields:
		_print_fields(bare, top)

	quit(0)


var _tag: String = ""      # the --at spot's x, in the picture names
var _last_items = null   # the last _boulders layout's ServerItems, wired to the world: its ground and water answer the camera spots
var _at: Vector2 = Vector2.ZERO
var _radius: float = 0.0

const COUNT_REACH_M := 60.0   # the coordinator's measure (26 Nov 2026): rocks within 60 m of a camera on rocky ground
const COUNT_BIG_M := 1.0      # of them, those of 1 m radius or more
const TARGET_ALL := 40        # the target for high ground and cliff feet: 40 rocks in all, 8 big ones
const TARGET_BIG := 8
const EDGE_M := 80.0          # cameras and samples this far inside the laid area, so the 60 m counts see every rock round them


# The rocky ground's rocks among `laid` (scatter key -> row), counted by kind: by the key's slot (0..95 a mountain cluster, 96..119 water, 127
# a lone giant), a mountain rock as a crag when it leans with a steep face, else as high ground at or over the 620 m treeline, else a cliff
# foot or hilltop. For each kind its best cells to picture, each with a camera 15 m from the cell's biggest rock on open ground, at eye height
# and facing it, the counts round that camera (rocks within 60 m: all, of 1 m radius or more, cluster cores) and ready look_rig lines. Then
# how rocky each kind of ground is over the whole area (rocks_check lines): its cells, the share with a rock of its own, and round every
# third cell's middle the median counts within 60 m and the share that meets the target.
func _print_fields(laid: Dictionary, top: int) -> void:
	var kinds: Dictionary = {"high ground": 0, "crag": 0, "cliff foot or hilltop": 0, "water": 0, "lone giant": 0}
	var by_cell: Dictionary = {}   # kind -> {cell: [rocks, biggest radius, the biggest rock's spot]}
	var index: Dictionary = {}     # 32 m cell -> [[x, z, radius, a cluster core], ...] of every boulder on the surface (older ones too)

	for kind in kinds:
		by_cell[kind] = {}

	for key in laid:
		var row: Dictionary = laid[key]

		if bool(row["cave"]):
			continue

		var p: Vector3 = row["pos"]
		var cell: Vector2i = Vector2i(int(floor(p.x / 32.0)), int(floor(p.z / 32.0)))
		var slot: int = int(key) & 0xff
		var field: bool = (int(key) & ItemsScript.FIELD_KEY) != 0
		var core: bool = field and slot < ItemsScript.FIELD_WATER_FIRST and slot % ItemsScript.FIELD_CLUSTER_SLOTS == 0

		if not index.has(cell):
			index[cell] = []

		(index[cell] as Array).append([p.x, p.z, float(row["radius"]), core])

		if not field:
			continue

		var kind: String = "lone giant" if slot == ItemsScript.FIELD_ERRATIC_SLOT else ("water" if slot >= ItemsScript.FIELD_WATER_FIRST else ("crag" if bool(row["tilt"]) else ("high ground" if p.y >= 620.0 else "cliff foot or hilltop")))
		kinds[kind] = int(kinds[kind]) + 1
		var cells: Dictionary = by_cell[kind]

		if not cells.has(cell):
			cells[cell] = [0, 0.0, p]

		cells[cell][0] = int(cells[cell][0]) + 1

		if float(row["radius"]) > float(cells[cell][1]):
			cells[cell][1] = float(row["radius"])
			cells[cell][2] = p

	print("rock fields: %s" % str(kinds))

	for kind in kinds:
		var cells: Dictionary = by_cell[kind]
		var order: Array = cells.keys()
		order.sort_custom(func(a, b): return int(cells[a][0]) > int(cells[b][0]))
		var picks: Array = []   # [meets the target, all, big, cores, cell, camera]

		for c in order.slice(0, 60):   # the 60 rockiest cells: a camera for each, the best by the counts round it
			var rock: Vector3 = cells[c][2]

			if Vector2(rock.x, rock.z).distance_to(_at) > _radius - EDGE_M:
				continue

			var cam: Array = _camera_at(rock, float(cells[c][1]), 15.0, index)

			if cam.is_empty():
				continue

			var counts: Array = _count_round(index, cam[0], cam[1])
			picks.append([int(counts[0]) >= TARGET_ALL and int(counts[1]) >= TARGET_BIG, counts[0], counts[1], counts[2], c, cam, counts])

		picks.sort_custom(func(a, b): return (bool(a[0]) and not bool(b[0])) or (bool(a[0]) == bool(b[0]) and int(a[1]) > int(b[1])))
		print("rock fields: %s, %d cells; the best to picture (a camera 15 m from the cell's biggest rock, on open ground):" % [kind, cells.size()])

		for n in range(mini(picks.size(), mini(top, 3))):
			var pick: Array = picks[n]
			var c: Vector2i = pick[4]
			var name: String = "rocks_%s_%s_%d" % [_tag, kind.split(" ")[0], n + 1]   # the spot's x in the name: two runs never share a picture name
			print("  rocks_count %s: within %.0f m of the camera %d rocks, %d of %.0f m radius or more, %d cluster cores (target %d and %d: %s); the cell's %d rocks, biggest radius %.2f m" % [name, COUNT_REACH_M,
				int(pick[1]), int(pick[2]), COUNT_BIG_M, int(pick[3]), TARGET_ALL, TARGET_BIG, "met" if bool(pick[0]) else "NOT met", int(cells[c][0]), float(cells[c][1])])
			var sizes: Array = pick[6]
			print("    sizes %s: %d rocks 2 m across or more, %d of 3.5 m or more, the largest %.1f m across; height to width about %.2f above the ground (rocky-ground mesh 0.6 to 0.78 as tall as wide, drawn %.1f x taller, a fifth set in; more on a slope)" % [name,
				int(sizes[3]), int(sizes[4]), float(sizes[5]), 0.69 * 1.4 * 0.8, 1.4])
			print("    %s" % str((pick[5] as Array)[2]).replace("NAME", name))
			var wide: Array = _camera_at(cells[c][2], float(cells[c][1]), 45.0, index, 6.0)   # 45 m off and 6 m up
			print("    %s" % (str(wide[2]).replace("NAME", name + "_wide") if not wide.is_empty() else "(no wide camera)"))

	_print_coverage(index)


# How rocky each kind of ground is over the laid area (rocks_check lines). Every cell middle EDGE_M inside the area is classed: above the
# treeline (620 m), bare rock below it (the ground's own material, as the client draws it), or a cliff foot below it (gentle, under ground
# that rises 15 m within 24 m). For each class: its cells, the share with a rock in the cell, and round every third cell's middle the median
# rocks within 60 m (all and big) and the share meeting the target.
func _print_coverage(index: Dictionary) -> void:
	var ground: Callable = _last_items.ground_height
	var classes: Dictionary = {"above the treeline": [], "bare rock below the treeline": [], "cliff foot below the treeline": []}
	var lo: Vector2i = Vector2i(int(floor((_at.x - _radius) / 32.0)), int(floor((_at.y - _radius) / 32.0)))
	var hi: Vector2i = Vector2i(int(floor((_at.x + _radius) / 32.0)), int(floor((_at.y + _radius) / 32.0)))

	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var mid: Vector2 = (Vector2(cx, cz) + Vector2(0.5, 0.5)) * 32.0

			if mid.distance_to(_at) > _radius - EDGE_M:
				continue

			var h: float = float(ground.call(mid.x, mid.y))

			if is_nan(h) or h < 1.0 or bool(_last_items.water_near.call(Vector3(mid.x, h, mid.y), 0.0)):
				continue

			var kind: String = ""

			if h >= 620.0:
				kind = "above the treeline"
			elif bool(_last_items.rock_at.call(mid.x, mid.y)):
				kind = "bare rock below the treeline"
			else:
				var fall: float = Vector2(float(ground.call(mid.x + 1.0, mid.y)) - float(ground.call(mid.x - 1.0, mid.y)), float(ground.call(mid.x, mid.y + 1.0)) - float(ground.call(mid.x, mid.y - 1.0))).length() * 0.5
				var rise: float = 0.0

				for d in [Vector2(24.0, 0.0), Vector2(-24.0, 0.0), Vector2(0.0, 24.0), Vector2(0.0, -24.0)]:
					rise = maxf(rise, float(ground.call(mid.x + d.x, mid.y + d.y)) - h)

				kind = "cliff foot below the treeline" if fall < 0.6 and rise >= 15.0 else ""

			if kind != "":
				(classes[kind] as Array).append(Vector2i(cx, cz))

	for kind in classes:
		var cells: Array = classes[kind]
		var with_rock: int = 0
		var all_n: Array = []
		var big_n: Array = []
		var met: int = 0

		for n in range(cells.size()):
			var c: Vector2i = cells[n]
			with_rock += 1 if index.has(c) else 0

			if n % 3 == 0:
				var counts: Array = _count_round(index, (float(c.x) + 0.5) * 32.0, (float(c.y) + 0.5) * 32.0)
				all_n.append(int(counts[0]))
				big_n.append(int(counts[1]))
				met += 1 if int(counts[0]) >= TARGET_ALL and int(counts[1]) >= TARGET_BIG else 0

		all_n.sort()
		big_n.sort()
		var sampled: int = all_n.size()
		print("rocks_check %s: %d cells, %.0f%% with a rock of their own; round every third cell's middle the median is %d rocks within %.0f m, %d of 1 m or more; %.0f%% meet the target (%d and %d)" % [kind, cells.size(),
			100.0 * float(with_rock) / float(maxi(cells.size(), 1)), int(all_n[sampled >> 1]) if sampled > 0 else 0, COUNT_REACH_M, int(big_n[sampled >> 1]) if sampled > 0 else 0,
			100.0 * float(met) / float(maxi(sampled, 1)), TARGET_ALL, TARGET_BIG])


# [all, big, cores]: the surface boulders within COUNT_REACH_M of (x, z): all of them, those of COUNT_BIG_M radius or more, the cluster cores.
func _count_round(index: Dictionary, x: float, z: float) -> Array:
	var all_n: int = 0
	var big_n: int = 0
	var cores: int = 0
	var across_2: int = 0     # 2 m across or more
	var across_35: int = 0    # 3.5 m across or more
	var largest: float = 0.0  # across, m
	var c: Vector2i = Vector2i(int(floor(x / 32.0)), int(floor(z / 32.0)))

	for dx in range(-2, 3):
		for dz in range(-2, 3):
			for rock in index.get(c + Vector2i(dx, dz), []):
				if Vector2(float(rock[0]) - x, float(rock[1]) - z).length() <= COUNT_REACH_M:
					all_n += 1
					big_n += 1 if float(rock[2]) >= COUNT_BIG_M else 0
					cores += 1 if bool(rock[3]) else 0
					across_2 += 1 if float(rock[2]) >= 1.0 else 0
					across_35 += 1 if float(rock[2]) >= 1.75 else 0
					largest = maxf(largest, float(rock[2]) * 2.0)

	return [all_n, big_n, cores, across_2, across_35, largest]


# [x, z, a look_rig line named NAME] for a camera `dist` m from `rock` (of `radius`), `agl` m above open ground, facing the rock: of eight
# directions the dry ones on open ground (above the treeline or on the ground's own bare rock: no tree stands there) and clear of every rock
# by a metre, lowest ground first (it looks up the slope at the rock). Empty when none.
func _camera_at(rock: Vector3, radius: float, dist: float, index: Dictionary, agl: float = 1.7) -> Array:
	var ground: Callable = _last_items.ground_height
	var spots: Array = []

	for k in range(8):
		var angle: float = TAU * float(k) / 8.0
		var at: Vector2 = Vector2(rock.x, rock.z) + Vector2(cos(angle), sin(angle)) * dist
		var h: float = float(ground.call(at.x, at.y))

		if is_nan(h) or h < 1.0 or bool(_last_items.water_near.call(Vector3(at.x, h, at.y), 4.0)):
			continue

		if h < 620.0 and not bool(_last_items.rock_at.call(at.x, at.y)):
			continue   # below the treeline only on bare rock: a camera on grass may stand in a tree

		var clear: bool = true

		for rk in index.get(Vector2i(int(floor(at.x / 32.0)), int(floor(at.y / 32.0))), []):
			clear = clear and Vector2(float(rk[0]) - at.x, float(rk[1]) - at.y).length() > float(rk[2]) + 1.0

		if clear:
			spots.append([h, at])

	if spots.is_empty():
		return []

	spots.sort_custom(func(a, b): return float(a[0]) < float(b[0]))
	var h_cam: float = float(spots[0][0])
	var cam: Vector2 = spots[0][1]
	var look: Vector2 = Vector2(rock.x, rock.z) - cam
	var yaw: float = rad_to_deg(atan2(-look.x, -look.y))   # look_rig --yaw: 0 faces north (-Z), 90 west
	var pitch: float = rad_to_deg(atan2(rock.y + radius * 0.5 - (h_cam + agl), look.length()))
	return [cam.x, cam.y, "tools/look_rig.sh --at %.0f,%.0f --agl %.1f --yaw %.0f --pitch %.0f --hour 12 --weather clear --name NAME" % [cam.x, cam.y, agl, yaw, pitch]]


# The island resource landscape as the server builds it at start (server_items.start_resources, here on this thread; no known dangers, so
# only an assured source's place can differ from the game's): its sources and coal seams lay their own outcrops. Null when it cannot build.
func _landscape(world: String, settings) -> RefCounted:
	var all_cfg: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/boulders.json"))

	if typeof(all_cfg) != TYPE_DICTIONARY or not (all_cfg as Dictionary).has("distribution"):
		return null

	var spawn2: Vector2 = SpawnPointScript.use_world(world)
	var context: RefCounted = ContextScript.new()
	var supply: Dictionary = ContextScript.supply_inputs(all_cfg as Dictionary)
	context.set("first_bronze", supply["first_bronze"])
	context.set("ore_per_m3", float(supply["ore_per_m3"]))
	context.set("ore_cost", supply["ore_cost"])
	context.call("load_tiles", world + "/tiles", float(settings.tile_size_m), int(settings.master_seed), (all_cfg as Dictionary)["distribution"], Vector3(spawn2.x, 0.0, spawn2.y))
	print("outcrops_near: resource landscape %s" % ("built" if bool(context.call("ready")) else "NOT built: no sources or seams below"))
	return context if bool(context.call("ready")) else null


# {scatter key: {"pos", "ore", "radius", "dist", "cave", "from"}} for every boulder ServerItems lays out in the 32 m cells within radius of `at`,
# with the flora cover read as `cover` everywhere. "from": "source" or "seam" for the resource landscape's outcrops.
func _boulders(generator, settings, at: Vector2, radius: float, cover: float, context: RefCounted) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(STORE)
	var items = ItemsScript.new()
	_last_items = items
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), STORE)
	items._boulder_left = {}   # an untouched world: every boulder whole
	items._taken = {}
	items.world_seed = int(settings.master_seed)
	items.respawn_point = Vector3(at.x, float(generator.surface_height(at.x, at.y)), at.y)
	items.resource_context = context
	# As terrain_server.gd wires them.
	items.ground_height = func(x, z): return generator.surface_height(x, z)
	items.cover_at = func(_point): return cover
	items.rock_at = func(x, z):
		var rock_tile = generator.get_tile(generator.tile_of(x, z))

		if rock_tile.placeholder:
			return false

		return generator._surface_material(rock_tile, x, z, float(generator.surface_height(x, z))) >= Layout.MATERIAL_ROCK
	items.ore_near = func(pos, reach, names, depth_m):
		return generator.get_tile(generator.tile_of(pos.x, pos.z)).ore_at(pos, reach, names, depth_m)
	items.rock_near = func(pos):
		return generator.get_tile(generator.tile_of(pos.x, pos.z)).bedrock_name_at(pos)
	items.water_near = func(pos, reach):
		var tile_data = generator.get_tile(generator.tile_of(pos.x, pos.z))

		if tile_data.placeholder:
			return false

		if not tile_data.cave_streams.is_empty() and tile_data.near_cave_water(pos, reach):
			return true

		for offset in [Vector2.ZERO, Vector2(reach, 0.0), Vector2(-reach, 0.0), Vector2(0.0, reach), Vector2(0.0, -reach)]:
			var k: int = tile_data.nearest(pos.x + offset.x, pos.z + offset.y)
			var sim: PackedFloat32Array = tile_data.sim_snapshot()

			if not sim.is_empty():
				if not is_nan(sim[k]):
					return true
			elif tile_data.water_class[k] > 1 and not is_nan(tile_data.water_surface[k]):
				return true

		return false
	items.cell_reads = func(x: float, z: float) -> Dictionary: return CellReadsScript.bound(generator, null, x, z)   # as the server: one tile look a cell (no running water here)
	items.cave_scatter = func(scatter_cell: Vector2i, size_m: float) -> PackedFloat32Array:
		var centre: Vector2 = (Vector2(scatter_cell) + Vector2(0.5, 0.5)) * size_m
		var cave_tile = generator.get_tile(generator.tile_of(centre.x, centre.y))
		var spots: PackedFloat32Array = PackedFloat32Array()

		if cave_tile == null or cave_tile.placeholder:
			return spots

		for n in cave_tile.cave_scatter_in(scatter_cell, size_m):
			spots.append_array(cave_tile.cave_scatter.slice(n * 5, n * 5 + 5))

		return spots
	var cfg: Dictionary = items._drops.get("ground_scatter", {})
	var cell_m: float = float(cfg.get("cell_m", 32.0))
	var lo: Vector2i = Vector2i(int(floor((at.x - radius) / cell_m)), int(floor((at.y - radius) / cell_m)))
	var hi: Vector2i = Vector2i(int(floor((at.x + radius) / cell_m)), int(floor((at.y + radius) / cell_m)))

	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var middle: Vector2 = (Vector2(cx, cz) + Vector2(0.5, 0.5)) * cell_m

			if middle.distance_to(at) <= radius + cell_m:
				items._lay_out_cell(Vector2i(cx, cz), cell_m, cfg)

	var out: Dictionary = {}

	for id in items._items:
		var it: Dictionary = items._items[id]

		if not it.has("boulder"):
			continue

		var pos: Vector3 = it["pos"]
		var dist: float = Vector2(pos.x, pos.z).distance_to(at)

		if dist <= radius:
			out[int(it["scatter"])] = {"pos": pos, "ore": str(it["boulder"].get("ore", "")), "radius": float(it["boulder"]["radius"]), "dist": dist,
				"cave": (int(it["scatter"]) & ItemsScript.CAVE_KEY) != 0, "tilt": (it["boulder"] as Dictionary).has("tilt"),
				"from": "source" if (it["boulder"] as Dictionary).has("source") else ("seam" if (it["boulder"] as Dictionary).has("seam") else "")}

	return out
