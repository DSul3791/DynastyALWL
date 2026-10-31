extends SceneTree

# Flora density fixes (Dave 2026-10-30): tall grass stands clearly above the ground grass and grows in patches; the gather chain
# knows it; small shrubs never block the player and big ones do; hardwoods and shrubs reach the baked forest ground.
#   godot --headless --path . --script res://src/worldgen/tools/test_flora_density.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const GrassViewScript := preload("res://src/client/grass_view.gd")

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	_check(settings != null and errors.is_empty(), "world, rules and tables load")
	var tall: Dictionary = {}

	for entry in tables.get_entries("flora"):
		if entry["name"] == "tall_grass":
			tall = entry

	# Heights: the ground blades (grass_view layers, the tallest grass layer) against the plant.
	var ground: float = 0.0

	for layer in GrassViewScript.LAYERS:
		if not bool(layer.get("reed", false)) and str(layer["texture"]).begins_with("grass"):
			ground = maxf(ground, float(layer["height"]))

	var plant_min: float = float(tall["height_m"][0])
	print("ground grass tallest layer %.2f m, tall_grass plant %.2f to %.2f m" % [ground, plant_min, float(tall["height_m"][1])])
	_check(ground > 0.0 and plant_min >= 1.25 * ground, "tall_grass plant is at least 1.25 times the ground grass (%.2f vs %.2f m)" % [plant_min, ground])
	_check(tall.has("patch") and float(tall["patch"]["every_m"]) <= 40.0 and int(tall["patch"]["count"][1]) >= 12, "tall_grass grows in dense patches")

	# Gather chain: a flora entry with the plant_fibre and thatch yields.
	var drops: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
	var rows: Array = drops["by_species"].get("tall_grass", [])
	var items: Array = []

	for row in rows:
		items.append(str(row[0]))

	_check(items.has("plant_fibre") and items.has("thatch"), "tall_grass gives plant_fibre and thatch %s" % str(items))
	_check(tall["yields"].has("thatch") and tall["season"].has("summer"), "tall_grass is gatherable in summer")

	# Shrub colliders: small ones step-over, big ones block, plants and grass never.
	var K = PlacerScript
	_check(K.collider_radius(K.KIND_SHRUB, 0.02, 1.0, 0.5) == 0.0, "a 0.5 m shrub has no collider")
	_check(K.collider_radius(K.KIND_SHRUB, 0.02, 1.0, 0.8) == 0.0, "a 0.8 m shrub is walked over or through")
	var big: float = K.collider_radius(K.KIND_SHRUB, 0.02, 2.0, 2.4)
	_check(big >= 0.22 and big <= 0.5, "a 2.4 m bush has a stem collider %.2f m, not the leaf spread" % big)
	_check(K.collider_radius(K.KIND_PLANT, 0.0, 1.0, 1.8) == 0.0, "a 1.8 m tall grass plant has no collider")
	_check(K.collider_radius(K.KIND_TREE, 0.4, 1.0, 20.0) > 0.3, "a tree keeps its trunk collider")
	var step: float = float(JSON.parse_string(FileAccess.get_file_as_string("res://data/movement.json"))["step_up_m"])
	_check(K.SHRUB_BLOCK_HEIGHT_M >= step + 0.3, "shrubs block only above the step-up height plus a margin (%.2f vs %.2f m)" % [K.SHRUB_BLOCK_HEIGHT_M, step])

	# Fallen-log colliders: short logs are walk-through, long ones get a capsule of the model's radius that a 0.5 m step-up can only clear when low.
	_check(K.log_collider(3.9, 0.5) == Vector2.ZERO, "a 3.9 m log has no collider")
	var long_log: Vector2 = K.log_collider(5.0, 0.5)
	_check(long_log.x >= 0.14 and long_log.x <= 0.45 and is_equal_approx(long_log.y, 5.0), "a 5 m log gets a capsule %.2f m radius, %.1f m long" % [long_log.x, long_log.y])
	_check(K.log_collider(4.0, 0.5).x * 2.0 >= step, "the shortest collidable log's top (%.2f m) is at or above the step-up height (%.2f m); shorter logs have no collider and are walked over" % [K.log_collider(4.0, 0.5).x * 2.0, step])
	var log_names: Dictionary = {}

	for entry in tables.get_entries("flora"):
		if entry["name"] in ["fallen_log", "hollow_log", "old_stump"]:
			log_names[entry["name"]] = entry

	_check(log_names.size() == 3 and str(log_names["fallen_log"]["model"]) == "fallen_log" and float(log_names["fallen_log"]["height_m"][1]) >= 4.0, "fallen_log, hollow_log and old_stump are flora rows and logs reach 4 m")

	# Cover feels real: under a big crown the grass thins from the drip line and the litter deepens (grass_view.gd constants).
	_check(GrassViewScript.CROWN_GRASS_TO > GrassViewScript.CROWN_GRASS_FROM and GrassViewScript.CROWN_GRASS_TO <= 0.3, "grass thins to almost nothing within a third of the crown radius (%.2f to %.2f)" % [GrassViewScript.CROWN_GRASS_FROM, GrassViewScript.CROWN_GRASS_TO])
	_check(GrassViewScript.CROWN_LITTER_TO > GrassViewScript.CROWN_LITTER_FROM and GrassViewScript.LITTER_DEEP_LEAVES > 1.0, "leaf litter deepens under a crown (x%.1f leaves at full depth)" % GrassViewScript.LITTER_DEEP_LEAVES)

	# Season data for the grass (data/look/seasons.json, read by GrassView.set_season): every season has a tint and a blade share, winter thinner and browner than summer.
	var seasons: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/look/seasons.json"))
	var grass_rows: Dictionary = (seasons["ground"]["grass"] as Dictionary) if typeof(seasons) == TYPE_DICTIONARY else {}
	var rows_ok: bool = grass_rows.size() == 4

	for name in ["spring", "summer", "autumn", "winter"]:
		rows_ok = rows_ok and grass_rows.has(name) and (grass_rows[name]["tint_rgb"] as Array).size() == 3 and float(grass_rows[name]["blades"]) > 0.0 and float(grass_rows[name]["blades"]) <= 1.0

	_check(rows_ok, "seasons.json has a grass tint and blade share for every season")
	_check(rows_ok and float(grass_rows["winter"]["blades"]) < float(grass_rows["summer"]["blades"]) and float(grass_rows["winter"]["tint_rgb"][2]) < float(grass_rows["summer"]["tint_rgb"][2]), "winter grass is thinner and browner than summer grass")

	# In-season rule (Dave 2026-10-31): a herb, flower or mushroom out of season is not drawn and cannot be targeted; woody plants and berry bushes stay drawn but offer nothing.
	var GatherRulesScript = load("res://src/shared/gather_rules.gd")
	var flora_rows: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/tables/flora.json"))["entries"]
	var drops_json: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
	var disagree: Array = []
	var hidden_start: Array = []
	var visible_start: int = 0
	var always: Callable = func(_t): return true
	var berry_names: Dictionary = drops_json.get("berry_yield", {})

	for row in flora_rows:
		if row.get("retired", false):
			continue

		for season_name in ["spring", "summer", "autumn", "winter"]:
			var hidden: bool = GatherRulesScript.hidden_out_of_season(row, season_name, berry_names.has(str(row["name"])))
			var verdict: Dictionary = GatherRulesScript.check(row, str(row["kind"]), drops_json, season_name, always, always)

			# hidden implies not targetable; a plant whose season excludes the day never offers a pick
			if hidden and bool(verdict["ok"]):
				disagree.append("%s %s hidden but pickable" % [row["name"], season_name])

			if not GatherRulesScript.in_season(row, season_name) and bool(verdict["ok"]) and str(row["kind"]) != "tree":
				disagree.append("%s %s out of season but pickable" % [row["name"], season_name])

			if season_name == "spring":
				if hidden:
					hidden_start.append(str(row["name"]))
				elif str(row["kind"]) == "plant":
					visible_start += 1

	print("in spring (the world starts in spring, day 30) hidden herbs/flowers/mushrooms: %d %s; visible plants %d" % [hidden_start.size(), str(hidden_start), visible_start])
	_check(disagree.is_empty(), "the season filter and the gather rule agree for every species and season %s" % str(disagree.slice(0, 6)))
	var yarrow: Dictionary = {}

	for row in flora_rows:
		if row["name"] == "yarrow":
			yarrow = row

	_check(not yarrow.is_empty() and GatherRulesScript.hidden_out_of_season(yarrow, "winter", false) == not GatherRulesScript.in_season(yarrow, "winter") and not GatherRulesScript.hidden_out_of_season(yarrow, "summer", false), "yarrow is hidden exactly when its season excludes the day")

	if settings == null or not errors.is_empty():
		quit(1)
		return

	# Placement on the baked ground: tall grass patches in a meadow, hardwoods and berry bushes in the forest.
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var biome_ids: Dictionary = {}

	for entry in tables.get_entries("biomes"):
		biome_ids[str(entry["name"])] = int(entry["id"])

	var counts: Dictionary = {}
	var area: Dictionary = {}
	var data = generator.get_tile(Vector2i(3, 4))

	for cz in range(0, 60, 7):
		for cx in range(0, 60, 7):
			var origin: Vector2 = Vector2(data.x0 + float(cx) * 256.0, data.z0 + float(cz) * 256.0)
			var made: Dictionary = placer.chunk_items(placer.chunk_of(origin.x + 1.0, origin.y + 1.0))

			for z in range(8, 256, 16):
				for x in range(8, 256, 16):
					var b: int = int(data.biome[data.nearest(origin.x + x, origin.y + z)])
					area[b] = float(area.get(b, 0.0)) + 256.0 / 1.0e6

			for n in range(made["ids"].size()):
				var p: Vector3 = made["positions"][n]
				var b: int = int(data.biome[data.nearest(p.x, p.z)])
				var name: String = str(placer.species_of(made["ids"][n])["name"])
				var key: String = "%d/%s" % [b, name]
				counts[key] = int(counts.get(key, 0)) + 1

	var forest: int = biome_ids["temperate_forest"]
	var km2: float = float(area.get(forest, 0.0))
	print("temperate forest sampled %.2f km2" % km2)
	_check(km2 > 0.3, "the sample covers temperate forest")

	if km2 > 0.3:
		var hardwood: int = int(counts.get("%d/beech" % forest, 0)) + int(counts.get("%d/oak" % forest, 0)) + int(counts.get("%d/maple" % forest, 0))
		var berries: int = 0

		for name in ["raspberry", "bramble", "blueberry", "elder", "wild_strawberry"]:
			berries += int(counts.get("%d/%s" % [forest, name], 0))

		_check(float(hardwood) / km2 >= 1500.0, "forest has hardwoods (%.0f per km2)" % (float(hardwood) / km2))
		_check(float(berries) / km2 >= 2500.0, "forest has berry bushes (%.0f per km2)" % (float(berries) / km2))
		_check(float(counts.get("%d/nettle" % forest, 0)) / km2 >= 1000.0, "forest has nettle patches")
		_check(float(counts.get("%d/hazel" % forest, 0)) / km2 >= 1000.0, "forest has a hazel shrub layer")

	var meadow: int = biome_ids["temperate_grassland"]
	var meadow_km2: float = float(area.get(meadow, 0.0))

	if meadow_km2 > 0.05:
		_check(float(counts.get("%d/tall_grass" % meadow, 0)) / meadow_km2 >= 3000.0, "meadows have tall grass (%.0f per km2)" % (float(counts.get("%d/tall_grass" % meadow, 0)) / meadow_km2))

	# Thickets (Dave 2026-10-31): shrubs and berry bushes grow in clumps that read as one big bush: nearly all shrubs of the patch species belong to a clump of 4 or more
	# (a clump = same-species shrubs chained within CLUMP_LINK_M of each other, across chunk borders too).
	var points: Array = []   # [x, z, species id]
	var origin_chunk: Vector2i = placer.chunk_of(53301.0, 68427.0)

	for cj in range(-2, 3):
		for ci in range(-2, 3):
			var made: Dictionary = placer.chunk_items(Vector2i(origin_chunk.x + ci, origin_chunk.y + cj))

			for n in range(made["ids"].size()):
				var sp: Dictionary = placer.species_of(made["ids"][n])

				if int(sp["kind"]) == PlacerScript.KIND_SHRUB and not sp.has("stand") and sp.has("patch"):
					points.append([(made["positions"][n] as Vector3).x, (made["positions"][n] as Vector3).z, int(sp["id"])])

	var link: float = 2.6
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(points.size())
	var grid: Dictionary = {}

	for n in range(points.size()):
		parent[n] = n
		var cell: Vector3i = Vector3i(int(floor(points[n][0] / link)), int(floor(points[n][1] / link)), points[n][2])

		if not grid.has(cell):
			grid[cell] = []

		(grid[cell] as Array).append(n)

	for cell in grid:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var other: Vector3i = Vector3i(cell.x + dx, cell.y + dz, cell.z)

				if not grid.has(other):
					continue

				for a in grid[cell]:
					for b in grid[other]:
						if a < b and Vector2(points[a][0] - points[b][0], points[a][1] - points[b][1]).length() <= link:
							var ra: int = a

							while parent[ra] != ra:
								ra = parent[ra]

							var rb: int = b

							while parent[rb] != rb:
								rb = parent[rb]

							if ra != rb:
								parent[maxi(ra, rb)] = mini(ra, rb)

	var sizes: Dictionary = {}
	var species_of_root: Dictionary = {}
	var single_species: Dictionary = {}

	for n in range(points.size()):
		var root_n: int = n

		while parent[root_n] != root_n:
			root_n = parent[root_n]

		sizes[root_n] = int(sizes.get(root_n, 0)) + 1
		species_of_root[root_n] = points[n][2]

	var clumped: int = 0
	var singles: int = 0
	var histogram: Dictionary = {}

	for root_n in sizes:
		var size: int = int(sizes[root_n])
		var bucket: int = mini(size, 12)
		histogram[bucket] = int(histogram.get(bucket, 0)) + 1
		clumped += size if size >= 4 else 0
		singles += 1 if size == 1 else 0

		if size == 1:
			single_species[int(species_of_root.get(root_n, -1))] = int(single_species.get(int(species_of_root.get(root_n, -1)), 0)) + 1

	var single_names: Dictionary = {}

	for sid in single_species:
		single_names[str(placer.species_by_id(int(sid)).get("name", sid))] = single_species[sid]

	print("singles by species ", single_names)
	print("thicket histogram (clump size, 12 = 12 or more: clumps) %s; %d shrubs in %d clumps" % [str(histogram), points.size(), sizes.size()])
	_check(points.size() > 100 and float(clumped) / float(points.size()) >= 0.88, "about 90 percent (at least 88) of the shrubs stand in clumps of 4 or more (%.0f percent of %d)" % [100.0 * float(clumped) / float(maxi(points.size(), 1)), points.size()])
	_check(float(singles) / float(maxi(points.size(), 1)) <= 0.05, "isolated single shrubs are at most 5 percent (%.1f percent)" % (100.0 * float(singles) / float(maxi(points.size(), 1))))
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
