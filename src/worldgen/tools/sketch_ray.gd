extends SceneTree

# Prints sketch heights (160 m map) along rays from the spawn point, for the island-shape work.
#   godot --headless --path . --script res://src/worldgen/tools/sketch_ray.gd

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const SketchScript := preload("res://src/worldgen/sketch/world_sketch.gd")
const ElevationScript := preload("res://src/worldgen/sketch/world_elevation.gd")


func _init() -> void:
	var errors: Array = []
	var world_dir: String = "res://worlds/base_world"
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = SketchScript.load_rules(world_dir + "/plan/sketch_rules.json", errors)
	var sketch: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/world_sketch.json"))
	var elevation = ElevationScript.new()
	elevation.build(settings, rules, sketch, 0.0)
	var spawn := Vector2(53301.0, 68427.0)
	var peak := Vector2(54856.0, 71080.0)
	var direction: Vector2 = (peak - spawn).normalized()

	for bearing in [0.0, 1.57, -1.57]:
		var ray: Vector2 = direction.rotated(bearing)
		var line := "bearing %+.2f:" % bearing

		for dist in range(-1000, 6001, 500):
			var at: Vector2 = spawn + ray * float(dist)
			line += " %d:%d" % [dist, int(elevation.height_at_m(at.x, at.y))]

		print(line)

	quit()
