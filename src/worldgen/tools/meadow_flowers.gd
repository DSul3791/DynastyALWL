extends SceneTree

# Meadow flower spread (MikeW, 2 Nov 2026): do meadow flowers stand in the open middle of a meadow or only at the forest edge?
# Finds the most meadow-rich chunk on tile 3,4, places a 5x5 chunk block around it, and compares, on meadow ground, the distance
# from each flower to the nearest tree with the same distance for an even 8 m grid of meadow ground points.
#   godot --headless --path . --script res://src/worldgen/tools/meadow_flowers.gd [-- --tile=3,4]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")

const FLOWERS := ["dandelion", "yarrow", "chamomile", "st_johns_wort", "wild_carrot"]
const BANDS := [10.0, 20.0, 40.0, 80.0]
const CELL := 20.0


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var tile: Vector2i = Vector2i(3, 4)

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var p: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(p[0]), int(p[1]))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or not errors.is_empty():
		print("load errors %s" % str(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var meadow: int = -1

	for entry in tables.get_entries("biomes"):
		if str(entry["name"]) == "temperate_grassland":
			meadow = int(entry["id"])

	var data = generator.get_tile(tile)
	var best: Vector2 = Vector2.ZERO
	var best_n: int = -1

	for cz in range(0, 60, 3):
		for cx in range(0, 60, 3):
			var origin: Vector2 = Vector2(data.x0 + float(cx) * 256.0, data.z0 + float(cz) * 256.0)
			var n: int = 0

			for z in range(8, 256, 32):
				for x in range(8, 256, 32):
					if int(data.biome[data.nearest(origin.x + x, origin.y + z)]) == meadow:
						n += 1

			if n > best_n:
				best_n = n
				best = origin + Vector2(128.0, 128.0)

	print("most meadow chunk centre (%.0f, %.0f): %d of 64 samples meadow" % [best.x, best.y, best_n])
	var centre_chunk: Vector2i = placer.chunk_of(best.x, best.y)
	var trees: Dictionary = {}   # Vector2i cell -> Array of Vector2
	var flowers: Dictionary = {}  # name -> Array of Vector2
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)

	for cj in range(-2, 3):
		for ci in range(-2, 3):
			var made: Dictionary = placer.chunk_items(Vector2i(centre_chunk.x + ci, centre_chunk.y + cj))

			for n in range(made["ids"].size()):
				var p3: Vector3 = made["positions"][n]
				var p: Vector2 = Vector2(p3.x, p3.z)
				lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.y))
				hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.y))
				var sp: Dictionary = placer.species_of(made["ids"][n])

				if int(sp["kind"]) == PlacerScript.KIND_TREE:
					var cell: Vector2i = Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))

					if not trees.has(cell):
						trees[cell] = []

					(trees[cell] as Array).append(p)
				elif FLOWERS.has(str(sp["name"])):
					if not flowers.has(sp["name"]):
						flowers[sp["name"]] = []

					(flowers[sp["name"]] as Array).append(p)

	# Keep 100 m off the block's edge so a tree outside the block cannot be missed.
	var inner_lo: Vector2 = lo + Vector2(100.0, 100.0)
	var inner_hi: Vector2 = hi - Vector2(100.0, 100.0)
	var ground: Array = []

	for z in range(int(inner_lo.y), int(inner_hi.y), 8):
		for x in range(int(inner_lo.x), int(inner_hi.x), 8):
			if int(data.biome[data.nearest(float(x), float(z))]) == meadow:
				ground.append(_nearest(trees, Vector2(x, z)))

	print("meadow ground points %d" % ground.size())
	_print_row("meadow ground", ground)
	var all: Array = []

	for name in FLOWERS:
		var d: Array = []

		for p in flowers.get(name, []):
			if p.x > inner_lo.x and p.x < inner_hi.x and p.y > inner_lo.y and p.y < inner_hi.y and int(data.biome[data.nearest(p.x, p.y)]) == meadow:
				d.append(_nearest(trees, p))

		all.append_array(d)
		_print_row(name, d)

	_print_row("all flowers", all)
	quit(0)


func _nearest(trees: Dictionary, p: Vector2) -> float:
	var c: Vector2i = Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))
	var best: float = 100.0

	for r in range(0, 6):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dz)) != r:
					continue

				for t in trees.get(c + Vector2i(dx, dz), []):
					best = minf(best, p.distance_to(t))

		if best <= float(r) * CELL:
			break

	return best


func _print_row(label: String, d: Array) -> void:
	if d.is_empty():
		print("%-14s none" % label)
		return

	d.sort()
	var parts: Array = []

	for band in BANDS:
		var n: int = 0

		for v in d:
			if v >= band:
				n += 1

		parts.append("%d%% >=%dm" % [roundi(100.0 * n / d.size()), int(band)])

	print("%-14s n=%5d  median %5.1f m  %s" % [label, d.size(), d[d.size() / 2], "  ".join(parts)])
