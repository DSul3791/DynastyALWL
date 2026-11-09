extends SceneTree

# Finds a flat dry spot near the spawn for the starter orchard: for centres 40 to 150 m from the spawn point it counts how many places of a 4 x 3 tree grid (7 m by 8 m) pass the
# ground checks of apple_early, and prints the best centres as offsets from the spawn (flora_placer.gd ORCHARD_OFFSET).
#   godot --headless --path . --script res://src/worldgen/tools/orchard_site.gd

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const SpawnPointScript := preload("res://src/shared/spawn_point.gd")


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var item: Dictionary = {}

	for sp in placer.species:
		if sp["name"] == "apple_early":
			item = sp

	var spawn: Vector2 = SpawnPointScript.OVERRIDE
	var data = generator.get_tile(generator.tile_of(spawn.x, spawn.y))
	var results: Array = []

	for oz in range(-150, 151, 10):
		for ox in range(-150, 151, 10):
			var d: float = Vector2(ox, oz).length()

			if d < 45.0 or d > 150.0:
				continue

			var ok: int = 0

			for row in range(3):
				for col in range(4):
					var x: float = spawn.x + ox + (float(col) - 1.5) * 7.0
					var z: float = spawn.y + oz + (float(row) - 1.0) * 8.0
					var k: int = data.nearest(x, z)
					ok += 1 if placer.orchard_ground_ok(item, data, k, x, z) else 0

			results.append([ok, -d, ox, oz])

	results.sort_custom(func(a, b): return a[0] > b[0] or (a[0] == b[0] and a[1] > b[1]))
	print("best orchard centres (ok of 12, offset x, z from the spawn):")

	for r in results.slice(0, 8):
		print("  %d of 12 at offset (%d, %d), %.0f m" % [r[0], r[2], r[3], -r[1]])

	quit(0)
