extends SceneTree

# Every ore body of the resources asked for, across the whole world, where the bake puts them (Sonny, 10 Nov 2026; Dave: "is iron
# accessible anywhere else"). A tile bake takes its ore bodies from the geology's seeded province cells (TileGeology._cell). This tool
# makes every cell of the world the same way, with no tile baked, and prints each body nearest first: its tile, its ground, its top
# and its depth. It reads only and writes nothing. River placers are left out, because a tile bake finds them from its own rivers.
#
# The ground is the baked tile's where tiles/tile_X_Z.tile exists. Elsewhere it is the world map's height before erosion. A bake wears
# that ground down, so there a body lies nearer the surface than printed, or the ground has worn past it. "land" means some ground within
# the outcrop reach stands above the sea. The reach is the body's largest radius plus boulders.json ore.reach_m, as TileTerrainData.ore_at
# reaches. The "bake check" line compares the list with the ore bodies in the baked tiles, so it shows whether the rules have moved since
# that bake.
#   godot --headless --path . --script res://src/worldgen/tools/ore_world.gd -- [--ores=iron] [--at=53296,68080] [--top=200]
#        [--world=res://worlds/base_world]

const TileBakerScript := preload("res://src/worldgen/tile/tile_baker.gd")
const TileGeologyScript := preload("res://src/worldgen/tile/tile_geology.gd")
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")

const SAMPLE_M := 16.0   # the land test's grid inside the reach


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var at: Vector2 = Vector2(53296.0, 68080.0)   # the temporary spawn
	var wanted: Dictionary = {"iron": true}
	var top: int = 200

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			world = argument.trim_prefix("--world=")
		elif argument.begins_with("--at="):
			var p: PackedStringArray = argument.trim_prefix("--at=").split(",")
			at = Vector2(float(p[0]), float(p[1]))
		elif argument.begins_with("--ores="):
			wanted = {}

			for name in argument.trim_prefix("--ores=").split(","):
				wanted[name] = true
		elif argument.begins_with("--top="):
			top = int(argument.trim_prefix("--top="))

	quit(_run(world, at, wanted, top))


func _run(world: String, at: Vector2, wanted: Dictionary, top: int) -> int:
	var started: int = Time.get_ticks_msec()
	var baker = TileBakerScript.new()
	var problem: String = baker.setup(world, 0.0, [Vector2i(3, 4)])   # a record tile: no rule rivers are built where the record has it

	if problem != "":
		print("ore_world: cannot start: %s" % problem)
		return 1

	var settings = baker.settings
	var tile_m: float = float(settings.tile_size_m)
	var period: Vector2 = Vector2(float(settings.tiles_x), float(settings.tiles_z)) * tile_m
	var sea: float = float(settings.sea_level_m)
	var boulders: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/boulders.json"))
	var reach_m: float = float(boulders["ore"].get("reach_m", 40.0)) if typeof(boulders) == TYPE_DICTIONARY else 40.0
	var geology = TileGeologyScript.new()
	geology.setup(settings, baker.tile_rules, baker.tables, baker.elevation, baker.sketch)
	var generator = GeneratorScript.new()
	generator.setup(settings, baker.tile_rules, baker.tables, world + "/tiles")
	var baked: Dictionary = _baked_tiles(world + "/tiles")
	var per_tile: int = int(baker.tile_rules["geology"]["province_cells_per_tile"])
	var first: int = settings.min_tile * per_tile
	var bodies: Dictionary = {}   # id: ore body
	var skipped: Dictionary = {}   # layers and scatters by resource: they cover a whole province, so they have no one place

	for cz in range(first, first + settings.tiles_z * per_tile):
		for cx in range(first, first + settings.tiles_x * per_tile):
			for ore in geology._cell(cx, cz)["ores"]:
				var resource: String = str(ore["resource"])

				if not wanted.has(resource):
					continue

				if str(ore["shape"]) in ["layer", "scatter"]:
					skipped[resource] = int(skipped.get(resource, 0)) + 1
				else:
					bodies[str(ore["id"])] = ore

	var ground = func(x: float, z: float) -> float:
		var coord: Vector2i = Vector2i(int(floor(x / tile_m)), int(floor(z / tile_m)))

		if baked.has(coord):
			return float(generator.surface_height(x, z))

		return float(baker.elevation.height_at_m(x, z))

	var rows: Array = []
	var land_count: int = 0
	var surface_count: int = 0

	for id in bodies:
		var row: Dictionary = _row(bodies[id], ground, reach_m, sea)
		var offset: Vector2 = row["centre"] - at
		offset = Vector2(fposmod(offset.x + 0.5 * period.x, period.x) - 0.5 * period.x, fposmod(offset.y + 0.5 * period.y, period.y) - 0.5 * period.y)
		row["dist"] = offset.length()
		row["tile"] = Vector2i(int(floor(row["centre"].x / tile_m)), int(floor(row["centre"].y / tile_m)))
		row["baked"] = baked.has(row["tile"])
		rows.append(row)

		if bool(row["land"]):
			land_count += 1

			if float(row["depth"]) <= 0.0:
				surface_count += 1

	rows.sort_custom(func(a, b): return float(a["dist"]) < float(b["dist"]))
	print("ore_world: %s: %d bodies in the world, %d with land within reach (%d of those at or above the ground there), from %d cells (%.1f s)" % [
		",".join(PackedStringArray(wanted.keys())), rows.size(), land_count, surface_count, settings.tiles_x * settings.tiles_z * per_tile * per_tile,
		float(Time.get_ticks_msec() - started) / 1000.0])

	if not skipped.is_empty():
		print("  not listed: %s layer or scatter bodies (a whole province each)" % str(skipped))

	print(_bake_check(generator, baked, bodies, wanted))
	var tiles: Dictionary = {}

	for row in rows:
		if bool(row["land"]):
			var key: String = "%d,%d" % [row["tile"].x, row["tile"].y]
			tiles[key] = int(tiles.get(key, 0)) + 1

	print("  on land, by tile: %s" % str(tiles))
	print("  id            shape  tile     centre (x, z)          from here  ground   top     depth   land  grade  tonnes")

	for n in range(mini(rows.size(), top)):
		var r: Dictionary = rows[n]
		print("  %-13s %-6s %-8s (%8.0f, %8.0f)  %6.1f km  %6.0f %s %6.0f  %6.0f   %-5s %.2f   %d" % [str(r["id"]), str(r["shape"]),
			"%d,%d" % [r["tile"].x, r["tile"].y], r["centre"].x, r["centre"].y, float(r["dist"]) / 1000.0, float(r["ground"]),
			"b" if bool(r["baked"]) else "m", float(r["top"]), float(r["depth"]), "yes" if bool(r["land"]) else "no", float(r["grade"]), int(r["tonnes"])])

	print("  ground: b = the baked tile's, m = the world map's before erosion. depth = ground minus the body's top at its centre (0 or less: at or above the ground).")
	return 0


# {"id", "shape", "centre", "ground", "top", "depth", "land", "grade", "tonnes"} for one compact body.
func _row(ore: Dictionary, ground: Callable, reach_m: float, sea: float) -> Dictionary:
	var shape: String = str(ore["shape"])
	var spots: Array = []   # [centre, radius] discs of the outcrop reach
	var centre: Vector2 = _centre_of(ore)
	var top_y: float = float(ore.get("top_y", 0.0))

	match shape:
		"lens":
			top_y = float(ore["center"][1]) + 0.5 * float(ore["thickness_m"])
			spots.append([centre, maxf(float(ore["radius_a_m"]), float(ore["radius_b_m"])) + reach_m])
		"halo":
			spots.append([centre, maxf(float(ore["radius_a_m"]), float(ore["radius_b_m"])) + reach_m])
		"pipe":
			spots.append([centre, float(ore["radius_m"]) + reach_m])
		_:   # a vein: its trace
			var a: Vector2 = Vector2(float(ore["points"][0][0]), float(ore["points"][0][1]))
			var b: Vector2 = Vector2(float(ore["points"][ore["points"].size() - 1][0]), float(ore["points"][ore["points"].size() - 1][1]))
			var steps: int = maxi(int(ceil(a.distance_to(b) / SAMPLE_M)), 1)

			for k in range(steps + 1):
				spots.append([a.lerp(b, float(k) / float(steps)), 0.5 * float(ore.get("width_m", 1.0)) + reach_m])

	var land: bool = false

	for spot in spots:
		var middle: Vector2 = spot[0]
		var radius: float = spot[1]
		var cells: int = int(ceil(radius / SAMPLE_M))

		for j in range(-cells, cells + 1):
			for i in range(-cells, cells + 1):
				var p: Vector2 = middle + Vector2(i, j) * SAMPLE_M

				if p.distance_to(middle) <= radius and float(ground.call(p.x, p.y)) > sea:
					land = true
					break

			if land:
				break

		if land:
			break

	var height: float = float(ground.call(centre.x, centre.y))
	return {"id": str(ore["id"]), "shape": shape, "centre": centre, "ground": height, "top": top_y, "depth": height - top_y, "land": land,
		"grade": float(ore.get("grade", 0.0)), "tonnes": int(ore.get("tonnes", 0))}


# A body's middle on the map: a lens's centre is [x, y, z], a halo's or a pipe's [x, z], a vein's the middle of its trace.
func _centre_of(ore: Dictionary) -> Vector2:
	if ore.has("center"):
		var c: Array = ore["center"]
		return Vector2(float(c[0]), float(c[c.size() - 1]))

	var points: Array = ore["points"]
	return 0.5 * (Vector2(float(points[0][0]), float(points[0][1])) + Vector2(float(points[points.size() - 1][0]), float(points[points.size() - 1][1])))


# Whether the bodies the baked tiles hold (TileTerrainData.ores) are the ones the cells make now, with the same centre.
func _bake_check(generator, baked: Dictionary, bodies: Dictionary, wanted: Dictionary) -> String:
	var held: int = 0
	var same: int = 0
	var differ: Array = []

	for coord in baked:
		for entry in generator.get_tile(coord).ores:
			var shape: String = str(entry["shape"])

			if not wanted.has(str(entry["resource"])) or shape in ["layer", "scatter", "placer"]:
				continue

			held += 1
			var id: String = str(entry["id"])

			if bodies.has(id) and _centre_of(bodies[id]).distance_to(_centre_of(entry)) < 0.5:
				same += 1
			elif not differ.has(id):
				differ.append(id)

	if differ.is_empty():
		return "bake check: the %d tile copies of these bodies in the %d baked tiles match the world list (ids and centres)" % [held, baked.size()]

	return "bake check: WARNING: %d of %d tile copies differ from the world list (the rules moved since that bake?): %s" % [held - same, held, ", ".join(differ)]


# The tiles with a baked file: {Vector2i: true}.
func _baked_tiles(folder: String) -> Dictionary:
	var out: Dictionary = {}

	for name in DirAccess.get_files_at(folder):
		if name.begins_with("tile_") and name.ends_with(".tile"):
			var parts: PackedStringArray = name.trim_prefix("tile_").trim_suffix(".tile").split("_")

			if parts.size() == 2:
				out[Vector2i(int(parts[0]), int(parts[1]))] = true

	return out
