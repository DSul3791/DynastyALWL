extends SceneTree

# Where the flowers stand (docs/TODO.md flora line, FLORA_NEXT_TASKS.md 10: "flowers only at the forest edge, not the open meadow"): on the real
# placer, round a point (default the starter town centre), the flowers (flora.json model "wildflower" or "flower") per hectare by distance from
# the nearest tree: 0-5, 5-15, 15-30, 30-60 and over 60 m. The ground area of each band is measured on a 2 m grid over the same chunks, so the
# numbers are densities, not counts. Also prints the flowers per hectare of each species in the open (over 30 m from a tree) and near trees.
# A measurement for the meadow flowers design; it changes nothing. Trees load one chunk wider than the counted square. Near the town the placer clears trees round NPC markers, so also try a point away from it.
#   godot --headless --path . --script res://src/worldgen/tools/flower_edge_count.gd -- [--at=58160,71360] [--chunks=1]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")

const BANDS := [5.0, 15.0, 30.0, 60.0, INF]
const CELL_M := 12.0   # tree lookup cells
const GRID_M := 2.0    # area sampling step


func _band(d: float) -> int:
	for b in BANDS.size():
		if d < float(BANDS[b]):
			return b

	return BANDS.size() - 1


func _nearest_tree(trees: Dictionary, x: float, z: float) -> float:
	var ci: int = floori(x / CELL_M)
	var cj: int = floori(z / CELL_M)
	var best: float = INF

	for ring in range(0, 7):   # up to 84 m out, then "over 60"
		for dj in range(-ring, ring + 1):
			for di in range(-ring, ring + 1):
				if maxi(absi(di), absi(dj)) != ring:
					continue

				for t in trees.get(Vector2i(ci + di, cj + dj), []):
					best = minf(best, Vector2(x, z).distance_to(t))

		if best < float(ring) * CELL_M:
			break

	return best


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var at: Vector2 = Vector2(58160.0, 71360.0)
	var span: int = 1

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--at="):
			var p: PackedStringArray = argument.trim_prefix("--at=").split(",")
			at = Vector2(float(p[0]), float(p[1]))
		elif argument.begins_with("--chunks="):
			span = maxi(int(argument.trim_prefix("--chunks=")), 0)

	var flowers: Dictionary = {}

	for entry in (JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json")) as Dictionary)["entries"]:
		if str(entry.get("model", "")) in ["wildflower", "flower"] and not bool(entry.get("retired", false)):
			flowers[str(entry["name"])] = true

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var centre: Vector2i = placer.chunk_of(at.x, at.y)
	var trees: Dictionary = {}     # Vector2i cell -> Array of Vector2 feet
	var found: Array = []          # [Vector2, species name]
	var lo: Vector2 = Vector2(INF, INF)
	var hi: Vector2 = Vector2(-INF, -INF)

	# Trees load one chunk wider than the counted square, so ground and
	# flowers near its edge still see the trees just outside it.
	for cj in range(centre.y - span - 1, centre.y + span + 2):
		for ci in range(centre.x - span - 1, centre.x + span + 2):
			var made: Dictionary = placer.chunk_items(Vector2i(ci, cj))
			var inner: bool = absi(ci - centre.x) <= span and absi(cj - centre.y) <= span

			if inner:
				lo = Vector2(minf(lo.x, float(ci) * placer.chunk_m), minf(lo.y, float(cj) * placer.chunk_m))
				hi = Vector2(maxf(hi.x, float(ci + 1) * placer.chunk_m), maxf(hi.y, float(cj + 1) * placer.chunk_m))

			for n in range(made["ids"].size()):
				var row: Dictionary = placer.species_of(made["ids"][n])
				var p: Vector3 = made["positions"][n]

				if row.is_empty():
					continue

				if int(row["kind"]) == PlacerScript.KIND_TREE:
					var cell: Vector2i = Vector2i(floori(p.x / CELL_M), floori(p.z / CELL_M))

					if not trees.has(cell):
						trees[cell] = []

					trees[cell].append(Vector2(p.x, p.z))
				elif inner and flowers.has(str(row["name"])):
					found.append([Vector2(p.x, p.z), str(row["name"])])

	var area: PackedFloat64Array = PackedFloat64Array()
	area.resize(BANDS.size())
	var z: float = lo.y + GRID_M * 0.5

	while z < hi.y:
		var x: float = lo.x + GRID_M * 0.5

		while x < hi.x:
			area[_band(_nearest_tree(trees, x, z))] += GRID_M * GRID_M
			x += GRID_M

		z += GRID_M

	var per_band: PackedInt32Array = PackedInt32Array()
	per_band.resize(BANDS.size())
	var open_species: Dictionary = {}
	var near_species: Dictionary = {}
	var open_area: float = area[3] + area[4] + 0.0
	var near_area: float = area[0] + area[1] + 0.0

	for f in found:
		var b: int = _band(_nearest_tree(trees, f[0].x, f[0].y))
		per_band[b] += 1

		if b >= 3:
			open_species[f[1]] = int(open_species.get(f[1], 0)) + 1
		elif b <= 1:
			near_species[f[1]] = int(near_species.get(f[1], 0)) + 1

	print("flower_edge_count: round %s, %d chunks a side, %d flowers of %d species, trees in %d cells" % [str(at), span * 2 + 1, found.size(), flowers.size(), trees.size()])
	var names: Array = ["0-5 m", "5-15 m", "15-30 m", "30-60 m", "over 60 m"]

	for b in BANDS.size():
		print("flower_edge_count: from a tree %-9s ground %7.2f ha, flowers %6d, %8.1f per ha" % [names[b], area[b] / 10000.0, per_band[b], float(per_band[b]) / maxf(area[b] / 10000.0, 0.0001)])

	for name in flowers:
		if open_species.has(name) or near_species.has(name):
			print("flower_edge_count:   %-18s per ha in the open (30 m+) %7.1f, near trees (under 15 m) %7.1f" % [name, float(open_species.get(name, 0)) / maxf(open_area / 10000.0, 0.0001), float(near_species.get(name, 0)) / maxf(near_area / 10000.0, 0.0001)])

	quit(0)
