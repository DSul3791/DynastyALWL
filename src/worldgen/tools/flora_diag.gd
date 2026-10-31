extends SceneTree

# Why a species is thin: samples points of one biome on the centre tiles and counts which ground check stops each species.
#   godot --headless --path . --script res://src/worldgen/tools/flora_diag.gd -- --biome=temperate_forest --species=beech,oak,maple

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var biome: String = "temperate_forest"
	var names: PackedStringArray = ["beech", "oak", "maple"]

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--biome="):
			biome = argument.trim_prefix("--biome=")
		elif argument.begins_with("--species="):
			names = argument.trim_prefix("--species=").split(",")

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var biome_id: int = -1

	for entry in tables.get_entries("biomes"):
		if str(entry["name"]) == biome:
			biome_id = int(entry["id"])

	var stats: Dictionary = {}
	var soils: Dictionary = {}
	var moist: Dictionary = {}
	var samples: int = 0
	var slopes: Array = []
	var alts: Dictionary = {}

	for tz in range(3, 6):
		for tx in range(2, 5):
			var data = generator.get_tile(Vector2i(tx, tz))

			for j in range(0, 768, 3):
				for i in range(0, 768, 3):
					var x: float = data.x0 + 100.0 + float(i) * 20.0
					var z: float = data.z0 + 100.0 + float(j) * 20.0

					if x >= data.x0 + generator.tile_size_m - 50.0 or z >= data.z0 + generator.tile_size_m - 50.0:
						continue

					var k: int = data.nearest(x, z)

					if int(data.biome[k]) != biome_id:
						continue

					samples += 1
					soils[int(data.soil[k])] = int(soils.get(int(data.soil[k]), 0)) + 1
					var mb: int = int(data.moisture[k]) / 20 * 20
					moist[mb] = int(moist.get(mb, 0)) + 1
					var slope: float = placer._slope_at(data, x, z)
					slopes.append(slope)
					var ab: int = int(generator.surface_height(x, z) / 100.0) * 100
					alts[ab] = int(alts.get(ab, 0)) + 1

					for name in names:
						var item: Dictionary = {}

						for sp in placer.species:
							if sp["name"] == name:
								item = sp

						if not stats.has(name):
							stats[name] = {"moisture": 0, "water": 0, "slope": 0, "altitude": 0, "ok": 0, "soil_sum": 0.0}

						var s: Dictionary = stats[name]
						var wet: int = data.moisture[k]

						if wet < item["moisture_min"] or wet > item["moisture_max"]:
							s["moisture"] += 1
						elif slope > item["max_slope"] and not item["ledge"]:
							s["slope"] += 1
						elif is_nan(placer._ground_ok(item, data, k, x, z)):
							s["water"] += 1
						else:
							s["ok"] += 1

						s["soil_sum"] += placer._soil_growth[data.soil[k]]

	slopes.sort()
	print("biome %s samples %d" % [biome, samples])
	print("altitude (100 m bins) ", alts)
	print("soils ", soils)
	print("moisture (20-wide bins) ", moist)
	print("slope median %.3f p90 %.3f" % [slopes[slopes.size() / 2], slopes[int(slopes.size() * 0.9)]])
	print("soil growth by id ", placer._soil_growth.slice(0, 10))
	print(stats)
	quit(0)
