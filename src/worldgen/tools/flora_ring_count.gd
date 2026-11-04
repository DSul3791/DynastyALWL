extends SceneTree
# How many trees, shrubs and small plants stand in each distance ring around a spot (draw-cost estimate for distance thinning).
#   godot --headless --path . --script res://src/worldgen/tools/flora_ring_count.gd
const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")

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
	var at: Vector2 = Vector2(53301.0, 68427.0)
	var c: Vector2i = placer.chunk_of(at.x, at.y)
	var view := {PlacerScript.KIND_TREE: 450.0, PlacerScript.KIND_SHRUB: 45.0, PlacerScript.KIND_PLANT: 60.0}
	var inner := {}
	var outer := {}
	for cj in range(-2, 3):
		for ci in range(-2, 3):
			var made: Dictionary = placer.chunk_items(Vector2i(c.x + ci, c.y + cj))
			for n in range(made["ids"].size()):
				var p: Vector3 = made["positions"][n]
				var k: int = int(placer.species_of(made["ids"][n])["kind"])
				if not view.has(k):
					continue
				var d: float = Vector2(p.x - at.x, p.z - at.y).length()
				if d <= 0.5 * view[k]:
					inner[k] = int(inner.get(k, 0)) + 1
				elif d <= view[k]:
					outer[k] = int(outer.get(k, 0)) + 1
	for k in view:
		var i: int = int(inner.get(k, 0))
		var o: int = int(outer.get(k, 0))
		print("kind %d (view %d m): inner half %d, outer half %d, total %d; at the curve the outer half draws about %d" % [k, int(view[k]), i, o, i + o, int(o * 0.6)])
	quit(0)
