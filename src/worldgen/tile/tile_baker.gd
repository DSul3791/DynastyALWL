class_name TileBaker
extends RefCounted

# The whole tile pipeline in one place (plan steps 7 to 12): height, erosion,
# water, climate, geology and sites for one tile. The tools use it to bake
# tiles, write tile files and check tile edges.
#
# Usage:
#   var baker = TileBaker.new()
#   baker.setup("res://worlds/base_world")      # loads rules, sketch, tables, world elevation
#   var result = baker.bake(Vector2i(3, 4))     # {"tile", "height", "erosion", "water", ...}

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const SketchScript := preload("res://src/worldgen/sketch/world_sketch.gd")
const ElevationScript := preload("res://src/worldgen/sketch/world_elevation.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TileErosionScript := preload("res://src/worldgen/tile/tile_erosion.gd")
const TileWaterScript := preload("res://src/worldgen/tile/tile_water.gd")
const TileClimateScript := preload("res://src/worldgen/tile/tile_climate.gd")
const TileGeologyScript := preload("res://src/worldgen/tile/tile_geology.gd")
const TileSitesScript := preload("res://src/worldgen/tile/tile_sites.gd")
const RiverNetworkScript := preload("res://src/worldgen/sketch/river_network.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")

var settings
var tile_rules: Dictionary = {}
var sketch: Dictionary = {}
var elevation
var tables
var world_dir: String = ""
var plan_cells: Dictionary = {}      # "x,z" -> cell of tile_plan.json
var world_air: Dictionary = {}       # wet-air field for the whole world
var river_network                    # the world's rivers (RiverNetwork)
var margin: int = 80                 # samples built beyond each tile edge, then cropped


# Loads everything a bake needs. Returns an empty string when it worked,
# otherwise the problem.
func setup(world_directory: String, elevation_cell_m: float = 0.0) -> String:
	world_dir = world_directory
	var errors: Array = []
	settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = SketchScript.load_rules(world_dir + "/plan/sketch_rules.json", errors)
	tile_rules = TileHeightScript.load_rules(world_dir + "/plan/tile_rules.json", errors)

	if settings == null or rules.is_empty() or tile_rules.is_empty():
		return "\n".join(errors)

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/world_sketch.json"))

	if typeof(parsed) != TYPE_DICTIONARY:
		return "world_sketch.json is missing or invalid (run build_sketch.gd first)"

	sketch = parsed
	elevation = ElevationScript.new()
	elevation.build(settings, rules, sketch, elevation_cell_m)
	margin = int(tile_rules["frame"]["margin_samples"])
	world_air = TileClimateScript.build_world_air(settings, tile_rules, elevation)
	river_network = RiverNetworkScript.new()
	river_network.build(elevation, float(tile_rules["water"]["river_start_km2"]))
	river_network.set_meander(tile_rules["water"].get("network_meander", []), SeedUtil.rng_for(settings.master_seed, "river_meander"))
	river_network.place_ponds(tile_rules["water"])
	tables = TableSetScript.new()
	var table_problems: Array = tables.load_directory()

	if not table_problems.is_empty():
		return "\n".join(table_problems)

	var plan: Variant = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/tile_plan.json"))

	if typeof(plan) == TYPE_DICTIONARY:
		for entry in plan["cells"]:
			plan_cells["%d,%d" % [int(entry["x"]), int(entry["z"])]] = entry

	return ""


# Drainage (in 8 m cells) at which a stream counts as a river.
func river_start_cells() -> float:
	var spacing: float = float(settings.map_spacing_m)
	return float(tile_rules["water"]["river_start_km2"]) * 1.0e6 / (spacing * spacing)


func plan_cell(tile: Vector2i) -> Dictionary:
	return plan_cells.get("%d,%d" % [tile.x, tile.y], {})


# Bay and beach details for the starter island on this tile, if any.
func starter_info(tile: Vector2i) -> Dictionary:
	for feature in sketch["features"]:
		for mount in feature.get("mounts", []):
			if str(mount["type"]) == "starter" and int(mount["starter"][0]) == tile.x and int(mount["starter"][1]) == tile.y \
					and mount.has("bay_center"):
				return {
					"bay_center": Vector2(float(mount["bay_center"][0]), float(mount["bay_center"][1])),
					"beach_dir": Vector2(float(mount["beach_dir"][0]), float(mount["beach_dir"][1])),
					"bay_radius_m": float(mount["bay_radius_m"]),
				}

	return {}


# One row at a time copy of the middle of a square map (core samples per
# side, `margin` samples in from each side of an `n` by `n` frame).
func crop(source: Variant, n: int, core: int) -> Variant:
	var out: Variant = source.slice(0, 0)

	for row in range(core):
		var start: int = (row + margin) * n + margin
		out.append_array(source.slice(start, start + core))

	return out


# Puts `core` back into the middle of `frame` (n by n).
func paste(frame: Variant, n: int, core: Variant, core_n: int) -> Variant:
	var out: Variant = frame.slice(0, margin * n)

	for row in range(core_n):
		var start: int = (row + margin) * n
		out.append_array(frame.slice(start, start + margin))
		out.append_array(core.slice(row * core_n, (row + 1) * core_n))
		out.append_array(frame.slice(start + margin + core_n, start + n))

	out.append_array(frame.slice((margin + core_n) * n, n * n))
	return out


# Runs every stage for one tile. `timings` in the result holds milliseconds
# per stage. Height, water and climate are built on a frame with a margin
# around the tile and cropped to the tile's own 1,921 by 1,921 samples; the
# margin is what lets two neighboring tiles agree along their shared edge.
func bake(tile: Vector2i) -> Dictionary:
	var timings: Dictionary = {}
	var tile_samples: int = int(settings.tile_size_m / settings.map_spacing_m)
	var core: int = tile_samples + 1
	var n: int = core + 2 * margin
	var origin_sx: int = tile.x * tile_samples - margin
	var origin_sz: int = tile.y * tile_samples - margin
	var clock: int = Time.get_ticks_msec()
	var frame_height = TileHeightScript.new()
	frame_height.setup(settings, elevation, tile_rules)
	var frame_rect: Rect2 = Rect2(
		Vector2(float(origin_sx), float(origin_sz)) * float(settings.map_spacing_m),
		Vector2(float(n - 1), float(n - 1)) * float(settings.map_spacing_m)
	)

	# Valleys reach this far from a river, so rivers just outside the frame shape it too.
	if tile_rules.has("valleys"):
		frame_height.valley_guides = river_network.guides_in(frame_rect.grow(float(tile_rules["valleys"]["half_width_max_m"])), 4.0)

	frame_height.build_frame(origin_sx, origin_sz, n)
	timings["height"] = Time.get_ticks_msec() - clock
	var raw_heights: PackedFloat32Array = crop(frame_height.heights, n, core)

	# Erosion works on the tile's own samples and changes nothing near its edge.
	clock = Time.get_ticks_msec()
	var core_height = TileHeightScript.new()
	core_height.samples = core
	core_height.spacing_m = frame_height.spacing_m
	core_height.heights = raw_heights
	var erosion = TileErosionScript.new()
	erosion.setup(settings, tile_rules)
	erosion.build(core_height)
	frame_height.heights = paste(frame_height.heights, n, erosion.heights, core)
	timings["erosion"] = Time.get_ticks_msec() - clock

	clock = Time.get_ticks_msec()
	var starter: Dictionary = starter_info(tile)
	var water = TileWaterScript.new()
	water.setup(settings, tile_rules)
	water.build(frame_height, starter, river_network.guides_in(frame_rect, 4.0), river_network.ponds_in(frame_rect, float(tile_rules["water"].get("head_pond_search_m", 2000.0)) + 700.0))
	timings["water"] = Time.get_ticks_msec() - clock

	clock = Time.get_ticks_msec()
	var climate = TileClimateScript.new()
	climate.setup(settings, tile_rules, tables)
	climate.use_world_air(world_air)
	climate.build(water.heights, water.water_class, origin_sx, origin_sz)
	timings["climate"] = Time.get_ticks_msec() - clock

	# Crop everything to the tile.
	var ghost_heights: PackedFloat32Array = water.heights
	var mouth: Vector2 = Vector2(NAN, NAN)

	if water.starter_path.size() > 0:
		var last: Vector2 = water.starter_path[water.starter_path.size() - 1]
		mouth = (Vector2(float(origin_sx), float(origin_sz)) + last) * float(settings.map_spacing_m)

	var shifted: PackedVector2Array = PackedVector2Array()

	for point in water.starter_path:
		shifted.append(point - Vector2(float(margin), float(margin)))

	water.starter_path = shifted
	water.heights = crop(water.heights, n, core)
	water.water_class = crop(water.water_class, n, core)
	water.water_surface = crop(water.water_surface, n, core)
	water.flow = crop(water.flow, n, core)
	water.samples = core
	climate.biome = crop(climate.biome, n, core)
	climate.soil = crop(climate.soil, n, core)
	climate.fertility = crop(climate.fertility, n, core)
	climate.moisture = crop(climate.moisture, n, core)
	climate.temperature_c = crop(climate.temperature_c, n, core)
	climate.samples = core
	var eroded_heights: PackedFloat32Array = erosion.heights.duplicate()
	var height = TileHeightScript.new()
	height.samples = core
	height.spacing_m = frame_height.spacing_m
	height.origin_sx = origin_sx + margin
	height.origin_sz = origin_sz + margin
	height.heights = water.heights

	clock = Time.get_ticks_msec()
	var geology = TileGeologyScript.new()
	geology.setup(settings, tile_rules, tables, elevation, sketch)
	geology.build(tile, water.heights, water.water_class, water.flow, climate.soil, {"heights": ghost_heights, "samples": n, "margin": margin})
	timings["geology"] = Time.get_ticks_msec() - clock

	clock = Time.get_ticks_msec()
	var sites = TileSitesScript.new()
	sites.setup(settings, tile_rules, tables)
	sites.build(tile, water.heights, water.water_class, climate.soil, geology, starter, mouth)
	timings["sites"] = Time.get_ticks_msec() - clock

	return {
		"tile": tile,
		"height": height,
		"raw_heights": raw_heights,
		"eroded_heights": eroded_heights,
		"erosion": erosion,
		"water": water,
		"climate": climate,
		"geology": geology,
		"sites": sites,
		"starter": starter,
		"timings": timings,
	}


# Bakes a tile and writes its file. Returns {"ok", "error", "path", "bytes", "timings"}.
func bake_to_file(tile: Vector2i, directory: String = "") -> Dictionary:
	const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
	var result: Dictionary = bake(tile)
	var packed: Dictionary = TileFileScript.pack_tile(
		settings, tile, plan_cell(tile), result["water"], result["climate"], result["geology"], result["sites"], river_start_cells()
	)
	var folder: String = directory if directory != "" else world_dir + "/tiles"
	var path: String = "%s/tile_%d_%d.tile" % [folder, tile.x, tile.y]
	var written: Dictionary = TileFileScript.write(path, packed)
	return {
		"ok": written["ok"], "error": written["error"], "path": path,
		"bytes": written["bytes"], "timings": result["timings"],
	}
