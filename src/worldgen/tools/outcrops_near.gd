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
#        [--world=res://worlds/base_world]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")

const STORE := "user://outcrops_near"


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var at: Vector2 = Vector2(53296.0, 68080.0)   # the temporary spawn
	var radius: float = 400.0
	var wanted: Dictionary = {}
	var top: int = 20

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
	var bare: Dictionary = _boulders(generator, settings, at, radius, 0.0)
	var covered: Dictionary = _boulders(generator, settings, at, radius, 1.0)
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
		print("  %-9s at (%.1f, %.1f, %.1f)  %4.0f m  radius %.2f m%s" % [str(r["ore"]), p.x, p.y, p.z, float(r["dist"]), float(r["radius"]), "  (cave floor)" if bool(r["cave"]) else ""])

	quit(0)


# {scatter key: {"pos", "ore", "radius", "dist", "cave"}} for every boulder ServerItems lays out in the 32 m cells within radius of `at`,
# with the flora cover read as `cover` everywhere.
func _boulders(generator, settings, at: Vector2, radius: float, cover: float) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(STORE)
	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(ItemTableScript.load_default(), STORE)
	items._boulder_left = {}   # an untouched world: every boulder whole
	items._taken = {}
	items.world_seed = int(settings.master_seed)
	items.respawn_point = Vector3(at.x, float(generator.surface_height(at.x, at.y)), at.y)
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
				"cave": (int(it["scatter"]) & ItemsScript.CAVE_KEY) != 0}

	return out
