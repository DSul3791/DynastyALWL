extends SceneTree

# In-world fruit grove check (#807, wild fruit groves): lists every grove of the four summer fruit varieties on the baked tiles, as the
# flora placer grows them. A grove is stand trees (item number STAND_BASE and up) of one species joined when within 20 m of each other,
# kept at 4 trees or more, as in test_flora_density. For each grove it prints the centre (to walk to), the tree count, and the most trees
# within 25 m of one of them (the near_orchard hint needs 4). Then a line per species, and a last line "verdict: PASS" when every species
# has a grove that sets off the hint on these tiles. It reads only. A whole tile is 60 x 60 chunks, a few minutes a tile.
#   godot --headless --path . --script res://src/worldgen/tools/fruit_groves.gd -- [--tiles=3,4;4,5] [--world=res://worlds/base_world]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")

const SPECIES := ["apple_early", "apple_summer", "pear_summer", "sour_cherry"]
const JOIN_M := 20.0
const HINT_M := 25.0
const HINT_TREES := 4
const CHUNK_M := 256.0


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var tiles: Array = [Vector2i(3, 4)]

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			world = argument.trim_prefix("--world=")
		elif argument.begins_with("--tiles="):
			tiles = []

			for pair in argument.trim_prefix("--tiles=").split(";"):
				var p: PackedStringArray = pair.split(",")
				tiles.append(Vector2i(int(p[0]), int(p[1])))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if not errors.is_empty():
		print("fruit_groves: cannot start: %s" % str(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var trees: Dictionary = {}

	for kind_name in SPECIES:
		trees[kind_name] = []

	var started: int = Time.get_ticks_msec()

	for tile in tiles:
		var side: int = int(round(float(settings.tile_size_m) / CHUNK_M))
		var corner: Vector2i = placer.chunk_of(float(tile.x * settings.tile_size_m) + 1.0, float(tile.y * settings.tile_size_m) + 1.0)

		for cz in range(side):
			for cx in range(side):
				var held: Dictionary = placer.chunk_items(Vector2i(corner.x + cx, corner.y + cz), true)

				for n in range(held["ids"].size()):
					var kind_name: String = str(placer.species_of(held["ids"][n]).get("name", ""))

					if trees.has(kind_name) and (int(held["ids"][n]) & 0xffff) >= PlacerScript.STAND_BASE:
						trees[kind_name].append(Vector2((held["positions"][n] as Vector3).x, (held["positions"][n] as Vector3).z))

		print("tile %d,%d: %d chunks read (%d s so far)" % [tile.x, tile.y, side * side, floori(float(Time.get_ticks_msec() - started) / 1000.0)])

	var failures: int = 0

	for kind_name in SPECIES:
		var groves: Array = _groves(trees[kind_name])
		var hinting: int = 0

		for grove in groves:
			print("GROVE %s: x %.0f z %.0f  %d trees, %d within %.0f m of one" % [kind_name, grove[0].x, grove[0].y, grove[1], grove[2], HINT_M])

			if int(grove[2]) >= HINT_TREES:
				hinting += 1

		var ok: bool = hinting > 0
		print("SPECIES %s: %d stand trees, %d groves of 4 or more, %d set off the near_orchard hint | %s" % [kind_name, (trees[kind_name] as Array).size(), groves.size(), hinting, "ok" if ok else "FAIL"])

		if not ok:
			failures += 1

	print("verdict: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)


# [centre Vector2, trees, most within HINT_M of one tree] per group of 4 or more, joined at JOIN_M.
func _groves(points: Array) -> Array:
	var out: Array = []
	var left: Array = points.duplicate()

	while not left.is_empty():
		var group: Array = [left.pop_back()]
		var grew: bool = true

		while grew:
			grew = false

			for k in range(left.size() - 1, -1, -1):
				for g in group:
					if (left[k] as Vector2).distance_to(g) <= JOIN_M:
						group.append(left[k])
						left.remove_at(k)
						grew = true
						break

		if group.size() < 4:
			continue

		var centre: Vector2 = Vector2.ZERO
		var most: int = 0

		for g in group:
			centre += g
			var within: int = 0

			for other in group:
				if (other as Vector2).distance_to(g) <= HINT_M:
					within += 1

			most = maxi(most, within)

		out.append([centre / float(group.size()), group.size(), most])

	return out
