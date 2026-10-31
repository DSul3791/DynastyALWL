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

	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
