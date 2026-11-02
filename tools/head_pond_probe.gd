extends SceneTree

# Head pond probe (Sonny, 2 Nov 2026): for the springs test_head_pond_fill checks, prints where the water goes. Same setup as that test, run for SIM_SECONDS.
# For each tested spring: ground, baked pond level, pond volume, spring rate; after the run the depth at the spring cell, the deepest depth within 5 cells,
# and the water standing in the pond's cells (sum of depth x cell area) against what the spring delivered.
#   godot --headless --path . --script res://tools/head_pond_probe.gd -- [--tile=3,4] [--only=1900590,3082096,2681336]

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const WaterSettler := preload("res://src/water/water_settler.gd")

const SIM_SECONDS := 10800.0


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)
	var only: Array = []

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--only="):
			for part in argument.trim_prefix("--only=").split(","):
				only.append(int(part))

	var errors: Array = []
	var world: String = "res://worlds/base_world"
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var data = generator.get_tile(tile)

	if data.placeholder:
		push_error("no baked tile %s" % tile)
		quit(1)
		return

	var sim = WaterSettler.build(data, 10.0, generator, false)
	var side: int = data.samples
	print("springs placed: %d" % sim.springs.size())
	var cell_m2: float = data.spacing_m * data.spacing_m

	while sim.seconds < SIM_SECONDS:
		sim.step()

	for spring in sim.springs:
		var k: int = int(spring[0])

		if not only.is_empty() and not only.has(k):
			continue

		var surface: float = data.water_surface[k]
		var around_max: float = 0.0
		var around_at: int = k
		var column: int = k % side
		@warning_ignore("integer_division")
		var row: int = k / side

		for dj in range(-5, 6):
			for di in range(-5, 6):
				var c: int = column + di
				var r: int = row + dj

				if c < 0 or r < 0 or c >= side or r >= side:
					continue

				var q: int = r * side + c

				if sim.depth_at(q) > around_max:
					around_max = sim.depth_at(q)
					around_at = q

		# Water standing within 25 cells (200 m) of the spring, and the lowest ground there.
		var stored: float = 0.0
		var lowest: float = INF
		var lowest_at: int = k

		for dj in range(-25, 26):
			for di in range(-25, 26):
				var c2: int = column + di
				var r2: int = row + dj

				if c2 < 0 or r2 < 0 or c2 >= side or r2 >= side:
					continue

				var q2: int = r2 * side + c2
				stored += sim.depth_at(q2) * cell_m2

				if sim.ground[q2] < lowest:
					lowest = sim.ground[q2]
					lowest_at = q2

		print("spring %d (%.2f m3/s): ground %.2f, baked level %.2f, class %d; depth at spring %.2f m; deepest within 5 cells %.2f m at %d (ground %.2f); stored within 200 m %.0f m3 vs delivered %.0f m3; lowest ground within 200 m %.2f at %d (%d cells away)" % [
			k, float(spring[1]), data.heights[k], surface, data.water_class[k], sim.depth_at(k), around_max, around_at, sim.ground[around_at], stored, float(spring[1]) * SIM_SECONDS,
			lowest, lowest_at, int(Vector2(float(lowest_at % side - column), float(lowest_at / side - row)).length())])

	quit(0)
