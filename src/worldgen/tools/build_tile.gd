extends SceneTree

# Bakes one tile and writes reports and pictures of every stage. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/build_tile.gd -- --tile=3,4
#
# Options (after "--"):
#   --tile=X,Z   tile coordinate (default 3,4)
#   --cell=N     world elevation cell size in meters (default from sketch_rules.json)
#   --world=DIR  world folder (default res://worlds/base_world)
#   --write      also write the tile file (tiles/tile_X_Z.tile) and read it back to check it
#
# Needs plan/world_sketch.json. Writes plan/tile_X_Z_relief.png.

const TileBakerScript := preload("res://src/worldgen/tile/tile_baker.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const TilePreviewScript := preload("res://src/worldgen/tile/tile_preview.gd")


func _init() -> void:
	var tile: Vector2i = Vector2i(3, 4)
	var cell: float = 0.0
	var world_dir: String = "res://worlds/base_world"
	var write_file: bool = false

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--tile="):
			var parts: PackedStringArray = argument.trim_prefix("--tile=").split(",")
			tile = Vector2i(int(parts[0]), int(parts[1]))
		elif argument.begins_with("--cell="):
			cell = float(argument.trim_prefix("--cell="))
		elif argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument == "--write":
			write_file = true

	quit(_run(world_dir, tile, cell, write_file))


func _run(world_dir: String, tile: Vector2i, cell: float, write_file: bool = false) -> int:
	var total_started: int = Time.get_ticks_msec()
	var baker = TileBakerScript.new()
	var started: int = Time.get_ticks_msec()
	var problem: String = baker.setup(world_dir, cell)

	if problem != "":
		push_error(problem)
		return 1

	var settings = baker.settings
	var tables = baker.tables
	print("World elevation, wet-air field and tables ready in %d ms" % (Time.get_ticks_msec() - started))

	started = Time.get_ticks_msec()
	var result: Dictionary = baker.bake(tile)
	print("Tile %s baked in %d ms (margin %d samples): %s" % [str(tile), Time.get_ticks_msec() - started, baker.margin, str(result["timings"])])
	var height = result["height"]
	var water = result["water"]
	var climate = result["climate"]
	var geology = result["geology"]
	var sites = result["sites"]
	var base: String = "%s/plan/tile_%d_%d" % [world_dir, tile.x, tile.y]

	height.heights = result["raw_heights"]
	TilePreviewScript.render(settings, height, tile, true, null).save_png(base + "_relief.png")
	height.heights = result["eroded_heights"]
	TilePreviewScript.render(settings, height, tile, true, null).save_png(base + "_eroded.png")
	height.heights = water.heights
	print("Water: %d river cells, longest river %.0f m, %d lakes, %d pit cells filled" % [
		water.river_cells, water.longest_river_m, water.lakes.size(), water.filled_cells
	])
	print("Starter river path points: %d" % water.starter_path.size())

	for lake in water.lakes:
		print("  lake %.1f ha, surface %.1f m, depth %.1f m" % [
			float(lake["area_m2"]) / 10000.0, float(lake["surface_m"]), float(lake["depth_m"])
		])

	TilePreviewScript.render(settings, height, tile, true, water).save_png(base + "_water.png")
	print("Climate: fertile land (150+) %.1f km2" % climate.fertile_km2)
	var land_cells: int = 0

	for name in climate.biome_cells.keys():
		if name != "ocean":
			land_cells += int(climate.biome_cells[name])

	for name in climate.biome_cells.keys():
		if name != "ocean":
			print("  biome %-20s %6.1f km2 (%4.1f%%)" % [
				name, float(climate.biome_cells[name]) * 64.0 / 1.0e6,
				100.0 * float(climate.biome_cells[name]) / maxf(float(land_cells), 1.0)
			])

	for name in climate.soil_cells.keys():
		print("  soil  %-20s %6.1f km2" % [name, float(climate.soil_cells[name]) * 64.0 / 1.0e6])

	TilePreviewScript.render_biomes(height, climate, tables, water).save_png(base + "_biomes.png")
	print("Geology: %d provinces, %d features, %d ore bodies" % [geology.provinces.size(), geology.features.size(), geology.ore_bodies.size()])

	for entry in geology.provinces:
		var rocks: Array = []

		for layer in entry["layers"]:
			rocks.append("%s %.0f" % [layer["rock"], float(layer["thickness_m"])])

		print("  province %-10s %-9s datum %4.0f m: %s, base %s" % [
			entry["id"], entry["kind"], float(entry["datum_m"]), ", ".join(rocks), entry["base_rock"]
		])

	var type_counts: Dictionary = {}

	for feature in geology.features:
		var key: String = str(feature["type"]) + ("/" + str(feature["size"]) if feature.has("size") else "")
		type_counts[key] = int(type_counts.get(key, 0)) + 1

	print("  timings (ms): %s; gold or tin reaching the ground: %d" % [str(geology.timings), geology.placer_sources])
	print("  features: %s" % str(type_counts))
	var ore_counts: Dictionary = {}

	for ore in geology.ore_bodies:
		var key: String = "%s %s" % [ore["resource"], ore["shape"]]
		ore_counts[key] = int(ore_counts.get(key, 0)) + 1

	print("  ore bodies: %s" % str(ore_counts))
	print("  bedrock at surface (cells): %s" % str(geology.outcrop_cells))
	TilePreviewScript.render_geology(height, geology, tables).save_png(base + "_geology.png")

	var kinds: Dictionary = {}
	var total_length: float = 0.0
	var dens: Dictionary = {}
	var hazards: Dictionary = {}

	for cave in sites.caves:
		kinds[cave["cave_kind"]] = int(kinds.get(cave["cave_kind"], 0)) + 1
		total_length += float(cave["length_m"])

		for den in cave["dens"]:
			dens[den["tier"]] = int(dens.get(den["tier"], 0)) + 1

		for segment in cave["segments"]:
			if str(segment[2]) != "passage":
				hazards[segment[2]] = int(hazards.get(segment[2], 0)) + 1

		for chamber in cave["chambers"]:
			for feature in chamber["features"]:
				hazards[feature] = int(hazards.get(feature, 0)) + 1

	print("Sites: %d caves %s, %.1f km of passages, %d lair sites" % [sites.caves.size(), str(kinds), total_length / 1000.0, sites.lairs.size()])
	print("  hazards: %s; dens by tier: %s; ore steering: %s" % [str(hazards), str(dens), str(sites.ore_report)])

	for cave in sites.caves:
		if str(cave["cave_kind"]) != "rock_shelter":
			print("  %-9s %-10s %5.0f m long, %4.0f m deep, %d chambers, %d entrances, %d dens, exposes %s" % [
				cave["id"], cave["cave_kind"], float(cave["length_m"]), float(cave["depth_m"]), cave["chambers"].size(),
				cave["entrances"].size(), cave["dens"].size(), str(cave["exposes"])
			])

	print("  starter: %s; harbor: %s" % [str(sites.starter), str(sites.harbor)])
	TilePreviewScript.render_sites(height, sites).save_png(base + "_caves.png")

	if write_file:
		return _write_and_check(world_dir, tile, baker, result, total_started)

	return 0


# Writes the tile file, reads every section back and reports time and size.
func _write_and_check(world_dir: String, tile: Vector2i, baker, result: Dictionary, total_started: int) -> int:
	var started: int = Time.get_ticks_msec()
	var packed: Dictionary = TileFileScript.pack_tile(
		baker.settings, tile, baker.plan_cell(tile), result["water"], result["climate"], result["geology"], result["sites"], baker.river_start_cells()
	)
	var packed_ms: int = Time.get_ticks_msec() - started
	var path: String = "%s/tiles/tile_%d_%d.tile" % [world_dir, tile.x, tile.y]
	started = Time.get_ticks_msec()
	var written: Dictionary = TileFileScript.write(path, packed)

	if not written["ok"]:
		push_error("Tile file not written: %s" % written["error"])
		return 1

	var write_ms: int = Time.get_ticks_msec() - started
	print("Tile file: packed in %d ms, compressed and written in %d ms, %.2f MB" % [packed_ms, write_ms, float(written["bytes"]) / 1048576.0])

	for section in written["sections"]:
		print("  %-16s %9d -> %9d bytes" % [section["name"], int(section["raw"]), int(section["stored"])])

	started = Time.get_ticks_msec()
	var head: Dictionary = TileFileScript.read_header(path)

	if not head["ok"]:
		push_error("Tile file header does not read back: %s" % head["error"])
		return 1

	for entry in head["table"]:
		var read: Dictionary = TileFileScript.read_section(path, head["table"], str(entry["name"]))

		if not read["ok"]:
			push_error("Tile file read-back failed: %s" % read["error"])
			return 1

	print("Read back and checked all %d sections in %d ms" % [head["table"].size(), Time.get_ticks_msec() - started])
	print("Whole tile, generation plus file: %.1f s" % (float(Time.get_ticks_msec() - total_started) / 1000.0))
	return 0
