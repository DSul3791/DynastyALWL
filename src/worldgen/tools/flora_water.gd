extends SceneTree

# Water-edge check: how far from inland water (river, lake, marsh water cells) each wetland species stands, and whether any stands in or under water.
#   godot --headless --path . --script res://src/worldgen/tools/flora_water.gd -- [--stride=10]
# Distance bands: under 4 m, 4 to 16 m, 16 to 48 m, farther (probed on rings of 8 directions).

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const WATCH := ["reeds", "riverbraid", "stormreed", "watercress", "wild_mint", "willow", "alder", "cranberry", "wild_iris", "cattail"]


func _wet(data, x: float, z: float) -> bool:
	var k: int = data.nearest(x, z)
	return int(data.water_class[k]) > 1 and not is_nan(data.water_surface[k])


func _distance_band(data, x: float, z: float) -> int:
	for band in range(3):
		var r: float = [4.0, 16.0, 48.0][band]

		for step in range(1, 4):
			var rr: float = r * float(step) / 3.0

			for a in range(8):
				var ang: float = TAU * float(a) / 8.0

				if _wet(data, x + cos(ang) * rr, z + sin(ang) * rr):
					return band

	return 3


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var stride: int = 10

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--stride="):
			stride = int(argument.trim_prefix("--stride="))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var bands: Dictionary = {}
	var under: Dictionary = {}
	var total_wet_cells: int = 0

	for tz in range(3, 6):
		for tx in range(2, 5):
			var data = generator.get_tile(Vector2i(tx, tz))

			for cj in range(0, 60, stride):
				for ci in range(0, 60, stride):
					var origin: Vector2 = Vector2(data.x0 + float(ci) * 256.0, data.z0 + float(cj) * 256.0)
					var made: Dictionary = placer.chunk_items(placer.chunk_of(origin.x + 1.0, origin.y + 1.0))

					for n in range(made["ids"].size()):
						var name: String = str(placer.species_of(made["ids"][n])["name"])

						if not (name in WATCH):
							continue

						var p: Vector3 = made["positions"][n]

						if not bands.has(name):
							bands[name] = [0, 0, 0, 0]

						bands[name][_distance_band(data, p.x, p.z)] += 1

						if _wet(data, p.x, p.z):
							under[name] = int(under.get(name, 0)) + 1

	for name in bands:
		var b: Array = bands[name]
		print("%-12s n %5d  <4 m %5d  4-16 m %5d  16-48 m %5d  farther %5d  in water %d" % [name, b[0] + b[1] + b[2] + b[3], b[0], b[1], b[2], b[3], int(under.get(name, 0))])

	quit(0)
