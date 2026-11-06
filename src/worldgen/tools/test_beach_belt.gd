extends SceneTree

# Palm belt and open sand (Dave 2026-11-02): no grass on open sand beyond BEACH_GRASS_M of the dirt, and within BELT_M of the sand on the dirt side only
# the species with a "belt" row (coconut palms, ferns) stand.
#   godot --headless --path . --script res://src/worldgen/tools/test_beach_belt.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const SpawnPointScript := preload("res://src/shared/spawn_point.gd")

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
	var belt_names: Array = []

	for entry in tables.get_entries("flora"):
		if entry.has("belt"):
			belt_names.append(str(entry["name"]))

	_check(belt_names.has("coconut_palm") and belt_names.has("fern"), "coconut_palm and fern have a belt row %s" % str(belt_names))
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var at: Vector2 = SpawnPointScript.OVERRIDE
	var bad_grass: int = 0
	var bad_belt: int = 0
	var belt_palms: int = 0
	var checked: int = 0
	var edge_cache: Dictionary = {}

	for dz in range(-3, 4):
		for dx in range(-3, 4):
			var chunk: Vector2i = placer.chunk_of(at.x + float(dx) * 256.0, at.y + float(dz) * 256.0)
			var made: Dictionary = placer.chunk_items(chunk)
			var data = generator.get_tile(generator.tile_of(at.x + float(dx) * 256.0, at.y + float(dz) * 256.0))

			if data.placeholder:
				continue

			for n in range(made["ids"].size()):
				var sp: Dictionary = placer.species_of(made["ids"][n])
				var p: Vector3 = made["positions"][n]
				var edge: float = placer._edge_m(data, p.x, p.z, edge_cache)
				checked += 1

				if edge < 0.0 and str(sp["shape"]) == "grass" and edge < -PlacerScript.BEACH_GRASS_M:
					bad_grass += 1
					print("  grass on open sand: %s at x %.1f z %.1f, edge %.0f m, chunk %s" % [str(sp["name"]), p.x, p.z, edge, str(chunk)])

				if edge > 0.0 and edge <= PlacerScript.BELT_M and float(sp["belt"]) <= 0.0:
					bad_belt += 1

					if bad_belt <= 10:
						print("  not a belt species in the belt: %s at x %.1f z %.1f, edge %.0f m" % [str(sp["name"]), p.x, p.z, edge])

				if edge > 0.0 and edge <= PlacerScript.BELT_M and str(sp["name"]) == "coconut_palm":
					belt_palms += 1

	print("checked %d items, %d palms in the belt" % [checked, belt_palms])
	_check(bad_grass == 0, "no grass on open sand (%d found)" % bad_grass)
	_check(bad_belt == 0, "only belt species within the belt (%d others)" % bad_belt)
	print("Test done: %d fail" % failures)
	quit(1 if failures > 0 else 0)
