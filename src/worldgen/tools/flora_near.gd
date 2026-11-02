extends SceneTree

# Walk-to-find check: the distance from a spot to the nearest plant of each wanted species, and counts within 100 m.
#   godot --headless --path . --script res://src/worldgen/tools/flora_near.gd -- --at=53301,68427 [--species=tall_grass,nettle,...] [--out=FILE]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")


func _init() -> void:
	var world: String = "res://worlds/base_world"
	var at: Vector2 = Vector2(53301.0, 68427.0)
	var wanted: PackedStringArray = ["tall_grass", "thatch_grass", "nettle", "raspberry", "bramble", "blueberry", "elder", "hazel", "wild_strawberry", "reeds", "flax", "juniper", "wild_rose", "blackthorn", "riverbraid"]

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--at="):
			var p: PackedStringArray = argument.trim_prefix("--at=").split(",")
			at = Vector2(float(p[0]), float(p[1]))
		elif argument.begins_with("--species="):
			wanted = argument.trim_prefix("--species=").split(",")

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)
	var best: Dictionary = {}
	var where: Dictionary = {}
	var within: Dictionary = {}
	var trees: int = 0

	for dz in range(-1, 2):
		for dx in range(-1, 2):
			var chunk: Vector2i = placer.chunk_of(at.x + float(dx) * 256.0, at.y + float(dz) * 256.0)
			var made: Dictionary = placer.chunk_items(chunk)

			for n in range(made["ids"].size()):
				var sp: Dictionary = placer.species_of(made["ids"][n])
				var p: Vector3 = made["positions"][n]
				var d: float = Vector2(p.x, p.z).distance_to(at)
				var name: String = sp["name"]

				if d < 100.0 and int(sp["kind"]) == PlacerScript.KIND_TREE:
					trees += 1

				if name in wanted:
					if d < float(best.get(name, INF)):
						where[name] = Vector2(p.x, p.z)

					best[name] = minf(float(best.get(name, INF)), d)

					if d < 100.0:
						within[name] = int(within.get(name, 0)) + 1

	print("from %s: trees within 100 m: %d" % [str(at), trees])

	for name in wanted:
		print("  %-16s nearest %6.1f m, within 100 m: %d at %s" % [name, float(best.get(name, INF)), int(within.get(name, 0)), str(where.get(name, Vector2.ZERO))])

	quit(0)
