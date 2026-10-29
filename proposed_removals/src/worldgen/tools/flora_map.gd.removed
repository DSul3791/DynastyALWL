extends SceneTree

# Draws the runtime flora around a point as a top-down picture (plan step
# 15), over shaded ground, with each species as a colored dot sized by its
# crown. Also prints counts per species and the placer's speed.
#
#   godot --headless --path . --script res://src/worldgen/tools/flora_map.gd -- --tile=3,4 [--size=1024] [--at=X,Z]
#
# Writes worlds/base_world/plan/tile_X_Z_flora.png. Default center: the
# tile's starter spawn point, else its middle. 1 pixel = 1 m.

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const PlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")

const WORLD_DIR := "res://worlds/base_world"


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)
	var size: int = 1024
	var at: Variant = null

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--size="):
			size = int(argument.trim_prefix("--size="))
		elif argument.begins_with("--at="):
			var parts: PackedStringArray = argument.trim_prefix("--at=").split(",")
			at = Vector2(float(parts[0]), float(parts[1]))

	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(WORLD_DIR + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(WORLD_DIR + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())

	if settings == null or not errors.is_empty():
		push_error("\n".join(errors))
		quit(1)
		return

	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, WORLD_DIR + "/tiles")
	var placer = PlacerScript.new()
	placer.setup(generator, tables, rules)

	if at == null:
		at = Vector2((float(tile.x) + 0.5) * settings.tile_size_m, (float(tile.y) + 0.5) * settings.tile_size_m)
		var path: String = "%s/tiles/tile_%d_%d.tile" % [WORLD_DIR, tile.x, tile.y]
		var head: Dictionary = TileFileScript.read_header(path)

		if head["ok"]:
			var starter: Dictionary = TileFileScript.read_list(path, head["table"], "starter")

			if starter["ok"] and typeof(starter["value"]) == TYPE_DICTIONARY and starter["value"].has("spawn_point"):
				at = Vector2(float(starter["value"]["spawn_point"][0]), float(starter["value"]["spawn_point"][2]))

	var corner: Vector2 = at - Vector2(size, size) * 0.5
	var image: Image = Image.create(size, size, false, Image.FORMAT_RGB8)

	# Ground: hillshade, sea blue, wet ground darker.
	for y in range(size):
		for x in range(size):
			var wx: float = corner.x + float(x) + 0.5
			var wz: float = corner.y + float(y) + 0.5
			var h: float = generator.surface_height(wx, wz)

			if h < 0.0:
				image.set_pixel(x, y, Color(0.16, 0.30, 0.45).lerp(Color(0.05, 0.12, 0.25), clampf(-h / 40.0, 0.0, 1.0)))
				continue

			var dx: float = generator.surface_height(wx + 1.0, wz) - h
			var dz: float = generator.surface_height(wx, wz + 1.0) - h
			var shade: float = clampf(0.75 - 0.9 * dx - 0.6 * dz, 0.35, 1.0)
			image.set_pixel(x, y, Color(0.80, 0.76, 0.62) * shade)

	var counts: Dictionary = {}
	var started: int = Time.get_ticks_usec()
	var chunks: int = 0
	var first: Vector2i = placer.chunk_of(corner.x, corner.y)
	var last: Vector2i = placer.chunk_of(corner.x + float(size) - 1.0, corner.y + float(size) - 1.0)
	var drawn: Array = [[], [], []]      # plants first, then shrubs, then trees on top

	for cz in range(first.y, last.y + 1):
		for cx in range(first.x, last.x + 1):
			var items: Dictionary = placer.chunk_items(Vector2i(cx, cz))
			chunks += 1

			for n in range(items["ids"].size()):
				var item: Dictionary = placer.species_of(items["ids"][n])
				var p: Vector3 = items["positions"][n]
				counts[item["name"]] = int(counts.get(item["name"], 0)) + 1
				drawn[2 - int(item["kind"])].append([p, item, float(items["heights"][n])])

	var elapsed: float = float(Time.get_ticks_usec() - started) / 1000.0

	for layer in drawn:
		for entry in layer:
			var item: Dictionary = entry[1]
			var scale: float = entry[2] / maxf(0.5 * (float(item["height_min"]) + float(item["height_max"])), 0.01)
			var radius: float = maxf(float(item["crown"]) * scale * (1.0 if item["kind"] == 0 else 0.6), 0.6)
			var c: Array = item["color"]
			var color: Color = Color(float(c[0]), float(c[1]), float(c[2]))
			var cx: float = entry[0].x - corner.x
			var cy: float = entry[0].z - corner.y

			for oy in range(int(floor(-radius)), int(ceil(radius)) + 1):
				for ox in range(int(floor(-radius)), int(ceil(radius)) + 1):
					var px: int = int(cx) + ox
					var py: int = int(cy) + oy

					if px < 0 or py < 0 or px >= size or py >= size or float(ox * ox + oy * oy) > radius * radius:
						continue

					# Darker toward the crown's edge so trees read as round.
					var edge: float = sqrt(float(ox * ox + oy * oy)) / maxf(radius, 0.01)
					image.set_pixel(px, py, color * (1.05 - 0.35 * edge))

	var out: String = "%s/plan/tile_%d_%d_flora.png" % [WORLD_DIR, tile.x, tile.y]
	image.save_png(out)
	var names: Array = counts.keys()
	names.sort_custom(func(a, b): return counts[a] > counts[b])
	print("Flora around %s, %d m square: %d chunks in %.0f ms (%.1f ms each)" % [str(at), size, chunks, elapsed, elapsed / float(chunks)])

	for name in names:
		print("  %-16s %6d  (%.0f per hectare of the picture)" % [name, counts[name], float(counts[name]) / (float(size * size) / 10000.0)])

	print("Wrote %s" % out)
	quit(0)
