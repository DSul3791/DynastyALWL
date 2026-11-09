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
const ErosionDeltaScript := preload("res://src/worldgen/tile/erosion_delta.gd")
const TileRollingScript := preload("res://src/worldgen/tile/tile_rolling.gd")
const TileScreeScript := preload("res://src/worldgen/tile/tile_scree.gd")
const TileRiverMendScript := preload("res://src/worldgen/tile/tile_river_mend.gd")
const TileRiverMouthScript := preload("res://src/worldgen/tile/tile_river_mouth.gd")
const TileWaterScript := preload("res://src/worldgen/tile/tile_water.gd")
const TileClimateScript := preload("res://src/worldgen/tile/tile_climate.gd")
const TileLandTypesScript := preload("res://src/worldgen/tile/tile_land_types.gd")
const TilePondLevelScript := preload("res://src/worldgen/tile/tile_pond_level.gd")
const TileValleyDrainScript := preload("res://src/worldgen/tile/tile_valley_drain.gd")
const TileGeologyScript := preload("res://src/worldgen/tile/tile_geology.gd")
const TileSitesScript := preload("res://src/worldgen/tile/tile_sites.gd")
const WaterRecordScript := preload("res://src/worldgen/record/water_record.gd")
const RiverNetworkScript := preload("res://src/worldgen/sketch/river_network.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")
const SetupCacheScript := preload("res://src/worldgen/tile/setup_cache.gd")

var settings
var tile_rules: Dictionary = {}
var sketch: Dictionary = {}
var elevation
var tables
var world_dir: String = ""
var plan_cells: Dictionary = {}      # "x,z" -> cell of tile_plan.json
var world_air: Dictionary = {}       # wet-air field for the whole world
var river_network                    # the world's rivers (RiverNetwork)
var erosion_delta                    # whole-island pre-carve (ErosionDelta), or null: then each tile erodes itself
var use_cache: bool = false         # bake_tiles.gd sets this (unless --no-cache): reuse the once-per-run setup (setup_cache.gd)
var margin: int = 80                 # samples built beyond each tile edge, then cropped
var record = null                    # the island water record (WaterRecord), when world_dir/record holds one; null: none
var _record_mutex: Mutex = Mutex.new()   # bake_tiles.gd bakes tiles on threads that share this baker; the record's cache is not shared safely


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
	river_network = RiverNetworkScript.new()
	margin = int(tile_rules["frame"]["margin_samples"])
	var cache_key: String = SetupCacheScript.key(world_dir, elevation_cell_m) if use_cache else ""
	var cache_path: String = SetupCacheScript.path_for(world_dir, cache_key) if use_cache else ""

	if use_cache and SetupCacheScript.load_into(cache_path, cache_key, elevation, river_network, world_air, sketch):
		elevation.settings = settings
		print("Setup restored from the cache %s" % cache_path.get_file())
	else:
		elevation.build(settings, rules, sketch, elevation_cell_m)
		world_air = TileClimateScript.build_world_air(settings, tile_rules, elevation)
		river_network.build(elevation, float(tile_rules["water"]["river_start_km2"]))
		river_network.set_meander(tile_rules["water"].get("network_meander", []), SeedUtil.rng_for(settings.master_seed, "river_meander"))
		river_network.place_ponds(tile_rules["water"], tile_rules.get("valleys", {}))

		if use_cache:
			SetupCacheScript.save(cache_path, cache_key, elevation, river_network, world_air, sketch)

	# BAKE: a pre-carved island (erosion_delta_v2.bin next to world.json) replaces the per-tile erosion below.
	erosion_delta = ErosionDeltaScript.new()

	if not erosion_delta.load_file(world_dir + "/erosion_delta_v2.bin"):
		erosion_delta = null
	else:
		erosion_delta.crowns = tile_rules.get("precarve", {}).get("summit_crowns", [])

	tables = TableSetScript.new()
	var table_problems: Array = tables.load_directory()

	if not table_problems.is_empty():
		return "\n".join(table_problems)

	# The island water record (watershed rebuild R6, docs/water/watershed_rebuild_design.md R6 item 5): where world_dir/record holds
	# one, every tile inside its window is baked from it, ground and water, and the passes below are not run there. Tiles outside the
	# window are baked by the passes. There is no setting: the record's window decides, and git is the way back (the tiles and the
	# water files are tracked). A record the reader refuses (incomplete, unknown version, bad field table) stops the setup.
	record = null

	if FileAccess.file_exists(world_dir + "/record/manifest.json"):
		record = WaterRecordScript.new()
		var refused: String = record.open(world_dir + "/record")

		if refused != "":
			return "water record: " + refused

		print("Water record %s: tiles %s are baked from it" % [str(record.manifest.get("record_sha", "?")).left(8), str(record.tile_rect)])

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
# landform_only (with raw_only): the macro landform for the watershed model, with no valley shaping, detail or strata
# (docs/water/watershed_rebuild_design.md, stage A1).
func bake(tile: Vector2i, raw_only: bool = false, landform_only: bool = false) -> Dictionary:
	var timings: Dictionary = {}
	var tile_samples: int = int(settings.tile_size_m / settings.map_spacing_m)
	var core: int = tile_samples + 1
	var n: int = core + 2 * margin
	var origin_sx: int = tile.x * tile_samples - margin
	var origin_sz: int = tile.y * tile_samples - margin

	# Export tools (raw_only) always read the world function: the watershed model is made from it.
	if record != null and not raw_only and record.has_tile(tile.x, tile.y):
		return _bake_from_record(tile, n, core, origin_sx, origin_sz, timings)

	var clock: int = Time.get_ticks_msec()
	var frame_height = TileHeightScript.new()
	frame_height.setup(settings, elevation, tile_rules)
	var frame_rect: Rect2 = Rect2(
		Vector2(float(origin_sx), float(origin_sz)) * float(settings.map_spacing_m),
		Vector2(float(n - 1), float(n - 1)) * float(settings.map_spacing_m)
	)

	# Valleys reach this far from a river, so rivers just outside the frame shape it too.
	# With a pre-carve, tile_rules precarve.valley_guides decides whether the old valley shaping stays (it must match
	# the heights the pre-carve was run on: tools/export_raw_heights.gd uses the same switch).
	var use_guides: bool = erosion_delta == null or bool(tile_rules.get("precarve", {}).get("valley_guides", true))

	if tile_rules.has("valleys") and use_guides and not landform_only:
		frame_height.valley_guides = river_network.guides_in(frame_rect.grow(float(tile_rules["valleys"]["half_width_max_m"])), 4.0)

	# The rock under the frame (positions only), so erosion and ledges follow the real layers.
	var frame_rock = TileGeologyScript.new()
	frame_rock.setup(settings, tile_rules, tables, elevation, sketch)
	frame_rock.prepare_frame(float(origin_sx) * float(settings.map_spacing_m), float(origin_sz) * float(settings.map_spacing_m), n)
	frame_height.rock = frame_rock
	frame_height.defer_strata = true
	frame_height.landform_only = landform_only and raw_only
	frame_height.build_frame(origin_sx, origin_sz, n)
	timings["height"] = Time.get_ticks_msec() - clock
	var raw_heights: PackedFloat32Array = crop(frame_height.heights, n, core)
	var raw_frame: PackedFloat32Array = frame_height.heights.duplicate()   # before erosion: the same world function in every frame

	# The 42 build is baked from the pre-carve file only: no file is an error, never a silent per-tile fallback.
	if erosion_delta == null and not raw_only:
		push_error("erosion_delta_v2.bin is missing next to world.json (terrain version 42 needs the pre-carve)")
		return {"error": "erosion_delta_v2.bin missing", "timings": timings}

	# Export tools want the ground as it stands before erosion (the input of the pre-carve) and nothing else.
	if raw_only:
		return {"raw_heights": raw_heights, "core": core, "timings": timings}

	# Erosion works on the tile's own samples and changes nothing near its edge.
	clock = Time.get_ticks_msec()
	var min_land: float = float(tile_rules["erosion"]["min_land_m"])
	var eroded: PackedFloat32Array   # the cropped heights after the pre-carve (the old per-tile erosion was removed 2026-10-29)

	# The pre-carve change, by world position, on the whole frame (margin included) and on the pre-erosion copy water
	# routes over, so frames agree along their edges and rivers see the carved valleys.
	var delta_field: PackedFloat64Array = erosion_delta.delta_field(frame_height.heights, n, frame_height.spacing_m, origin_sx, origin_sz)
	frame_height.heights = erosion_delta.apply_field(frame_height.heights, delta_field, n, frame_height.spacing_m, origin_sx, origin_sz, min_land)
	raw_frame = erosion_delta.apply_field(raw_frame, delta_field, n, frame_height.spacing_m, origin_sx, origin_sz, min_land)
	eroded = crop(frame_height.heights, n, core)

	timings["erosion"] = Time.get_ticks_msec() - clock
	clock = Time.get_ticks_msec()
	frame_height.add_strata()
	timings["ledges"] = Time.get_ticks_msec() - clock

	# Scree aprons at the foot of steep faces (Tyler 9 B), on the whole frame so tiles agree along their edge.
	clock = Time.get_ticks_msec()
	var scree = TileScreeScript.new()
	scree.setup(tile_rules.get("scree", {}))
	frame_height.heights = scree.apply(frame_height.heights, n, frame_height.spacing_m, origin_sx, origin_sz)
	eroded = crop(frame_height.heights, n, core)
	timings["scree"] = Time.get_ticks_msec() - clock

	clock = Time.get_ticks_msec()
	var starter: Dictionary = starter_info(tile)
	var water = TileWaterScript.new()
	water.setup(settings, tile_rules)
	water.world_network = river_network
	water.routing_raw = raw_frame

	var river_guides: Array = river_network.guides_in(frame_rect, 4.0)
	water.build(frame_height, starter, river_guides, river_network.ponds_in(frame_rect, float(tile_rules["water"].get("head_pond_search_m", 2000.0)) + 700.0))
	timings["water"] = Time.get_ticks_msec() - clock


	# Rolling swells and knolls on dry low land, added after the water so the rivers and ponds keep their shape.
	clock = Time.get_ticks_msec()

	if tile_rules.has("rolling"):
		var rolling_rules: Dictionary = tile_rules["rolling"].duplicate()
		TileRollingScript.apply(water.heights, water.water_class, n, frame_height.spacing_m, origin_sx, origin_sz, settings, rolling_rules, elevation)

	timings["rolling"] = Time.get_ticks_msec() - clock


	# Pond levels no higher than their spill, after the passes that shape the ground (tile_pond_level.gd); again below, after the mend and the mouths.
	clock = Time.get_ticks_msec()
	var pond_levels: Dictionary = TilePondLevelScript.clamp_to_spill(water.heights, water.water_class, water.water_surface, n)
	timings["pond_levels"] = Time.get_ticks_msec() - clock
	print("  pond levels (tile %s): %d water bodies, %d lowered to their spill, %d cells turned dry (%d ms)" % [str(tile), pond_levels["bodies"], pond_levels["lowered"], pond_levels["dried"], timings["pond_levels"]])
	# Rivers cut off by the lake cells that turned dry dig on through the ridge to lower water (Dave 4 Nov: "the river just runs out", tile_river_mend.gd).
	clock = Time.get_ticks_msec()
	# Corners first, so a brook joined up by them is a river piece the mend sees (the first PC bake of #450 left 1 or 2 short brooks per tile cut off,
	# grown past MIN_RIVER_CELLS by the corner cells after the mend had run).
	var corners: int = TileRiverMendScript.join_corners(water.heights, water.water_class, water.water_surface, n)
	var mend: Dictionary = TileRiverMendScript.mend(water.heights, water.water_class, water.water_surface, n, frame_height.spacing_m)
	print("  river mend (tile %s): %d rivers cut off, %d dug through, %d cells made river (%d ms)" % [str(tile), mend["pieces"], mend["mended"], mend["cells"], Time.get_ticks_msec() - clock])
	# Rivers widen into the sea and the sea comes up the mouth (the 20 Oct estuary rule; Dave 5 Nov: "the ocean should overlap into the mouth", tile_river_mouth.gd).
	clock = Time.get_ticks_msec()
	var mouth_cut: Dictionary = TileRiverMouthScript.carve(water.heights, water.water_class, water.water_surface, n, frame_height.spacing_m, tile_rules["water"])
	# Twice: one river's estuary can bring the sea next to another river that stopped short of it (Dave 6 Nov 2026, x 52798 z 68114: "the river bed doesnt
	# continue out into the ocean. there is grass and sand in the way"); the second pass gives that river its own estuary. A river carved in the first pass
	# is carved again from its lowered ground, which only lowers its banks a little more.
	var mouth_again: Dictionary = TileRiverMouthScript.carve(water.heights, water.water_class, water.water_surface, n, frame_height.spacing_m, tile_rules["water"])
	mouth_cut["cells"] += mouth_again["cells"]
	mouth_cut["sea"] += mouth_again["sea"]
	print("  river mouths (tile %s): %d river cells at the sea, %d cells carved, %d made sea (%d ms)" % [str(tile), mouth_cut["mouths"], mouth_cut["cells"], mouth_cut["sea"], Time.get_ticks_msec() - clock])
	# Every river through cells that share a side, so no grass grows across a brook on the diagonal (Dave 5 Nov, tile_river_mend.gd join_corners).
	# And again after the mend's and the mouths' cuts, until no river touches the next only at a corner.
	for pass_index in range(4):
		var joined: int = TileRiverMendScript.join_corners(water.heights, water.water_class, water.water_surface, n)
		corners += joined

		if joined == 0:
			break

	print("  river corners (tile %s): %d cells made river" % [str(tile), corners])

	# Pond levels again, after the mend's and the mouths' cuts (Sonny, 8 Nov 2026). Those passes run after the first clamp and can cut a pond's outlet
	# below its painted level: on the 84f0e2f5 bake, test_head_pond_fill spring 1889014 sat in a coastal pond painted at 6.0 m beside river ground at
	# 0.25 m, which the settle could never fill. A pond lowered here can leave a brook short of its water, so the mend and the corners run again, up to
	# three rounds, until no pond is lowered.
	clock = Time.get_ticks_msec()

	for round_index in range(3):
		var again: Dictionary = TilePondLevelScript.clamp_to_spill(water.heights, water.water_class, water.water_surface, n)
		print("  pond levels after the cuts, round %d (tile %s): %d lowered to their spill, %d cells turned dry" % [round_index + 1, str(tile), again["lowered"], again["dried"]])

		if again["lowered"] == 0:
			break

		corners += TileRiverMendScript.join_corners(water.heights, water.water_class, water.water_surface, n)
		var mend_again: Dictionary = TileRiverMendScript.mend(water.heights, water.water_class, water.water_surface, n, frame_height.spacing_m)
		print("  river mend again (tile %s): %d rivers cut off, %d dug through, %d cells made river" % [str(tile), mend_again["pieces"], mend_again["mended"], mend_again["cells"]])

		for pass_index in range(4):
			var joined_again: int = TileRiverMendScript.join_corners(water.heights, water.water_class, water.water_surface, n)
			corners += joined_again

			if joined_again == 0:
				break

	timings["pond_levels"] += Time.get_ticks_msec() - clock

	# The land beside a river slopes up from it, so nothing lies lower than the river and turns to wetland (Dave 6 Nov 2026, tile_valley_drain.gd).
	clock = Time.get_ticks_msec()
	var drained: Dictionary = TileValleyDrainScript.apply(water.heights, water.water_class, water.water_surface, n, frame_height.spacing_m, margin, tile_rules["water"].get("valley_drain", {}))
	print("  valley drain (tile %s): %d cells raised to drain to the river, up to %.1f m (%d ms)" % [str(tile), drained["raised"], drained["max_m"], Time.get_ticks_msec() - clock])
	# Last of the ground passes: no dry hollow is left for rain to pool in (tile_valley_drain.gd drain_hollows).
	clock = Time.get_ticks_msec()
	var hollows: Dictionary = TileValleyDrainScript.drain_hollows(water.heights, water.water_class, n, tile_rules["water"].get("valley_drain", {}))
	print("  dry hollows (tile %s): %d cells raised to their spill, up to %.1f m (%d ms)" % [str(tile), hollows["cells"], hollows["most_m"], Time.get_ticks_msec() - clock])

	var fresh_points: PackedVector2Array = PackedVector2Array()

	for guide in river_guides:
		fresh_points.append_array(guide["points"])

	return _finish(tile, water, Vector2i(origin_sx, origin_sz), frame_height.spacing_m, fresh_points, {"raw_heights": raw_heights, "eroded_heights": eroded}, timings)


# A tile inside the water record's window (R6): the ground, water level, water class, drainage and distance to fresh water all come from
# the record (record.py writes them on Dave's PC from the watershed chain), on the same frame as the passes use, so neighbouring tiles
# agree along their edges as before. Nothing is cut, raised or stamped here: the record's ground is the final ground (its own flood check
# found no closed cell outside a lake, or listed each one). Ledges, scree and rolling ground are not added, since they would change the
# ground the record's water was laid on. Climate, land types, geology and sites follow as for every tile.
func _bake_from_record(tile: Vector2i, n: int, core: int, origin_sx: int, origin_sz: int, timings: Dictionary) -> Dictionary:
	var clock: int = Time.get_ticks_msec()
	var spacing_m: float = float(settings.map_spacing_m)
	var total: int = n * n

	if record.samples != core:
		return {"error": "the water record has %d samples per tile edge, the game %d" % [record.samples, core], "timings": timings}

	var water = TileWaterScript.new()
	water.setup(settings, tile_rules)
	water.samples = n
	water.spacing_m = spacing_m
	_record_mutex.lock()
	var missing: String = ""

	for name in ["ground", "water_level", "water_class", "area_km2", "fresh_m"]:
		if missing == "" and record.raster(tile.x, tile.y, name).is_empty():
			missing = record.error_of

	if missing != "":
		_record_mutex.unlock()
		return {"error": "water record: " + missing, "timings": timings}

	water.heights = record.frame(tile, margin, "ground")
	var gaps: int = record.frame_gaps
	var level: PackedFloat32Array = record.frame(tile, margin, "water_level")
	var codes: PackedFloat32Array = record.frame(tile, margin, "water_class")   # already the game's table ids (water_record.gd code_map)
	var area_km2: PackedFloat32Array = record.frame(tile, margin, "area_km2")
	water.fresh_m = record.frame(tile, margin, "fresh_m")
	var rect: Rect2 = Rect2(Vector2(float(origin_sx), float(origin_sz)) * spacing_m, Vector2(float(n - 1), float(n - 1)) * spacing_m)
	var reaches: Array = record.reaches_in(rect)
	_record_mutex.unlock()

	water.water_class = PackedByteArray()
	water.water_class.resize(total)
	water.water_surface = PackedFloat32Array()
	water.water_surface.resize(total)
	water.flow = PackedFloat32Array()
	water.flow.resize(total)
	var cells_per_km2: float = 1.0e6 / (spacing_m * spacing_m)
	var unknown: int = 0

	for k in total:
		var id: int = int(codes[k])

		if id == 255:
			unknown += 1
			id = 0

		water.water_class[k] = id
		# A wet sample with no level of its own (a wetland: water at the ground) stands at its ground.
		water.water_surface[k] = level[k] if not is_nan(level[k]) else water.heights[k]
		water.flow[k] = area_km2[k] * cells_per_km2

	if unknown > 0:
		return {"error": "water record: %d samples of tile %s carry a water code the game's table lacks" % [unknown, str(tile)], "timings": timings}

	timings["record"] = Time.get_ticks_msec() - clock
	print("  water record (tile %s): ground and water from the record (%d frame samples beyond the window repeat its edge, %d ms)" % [str(tile), gaps, timings["record"]])

	# The climate's distance to fresh water: the lines of the record's rivers (reaches draining at least river_start_km2, as the world
	# river network's guides in the passes' bake) in world metres, the same in every frame that holds them.
	var fresh_points: PackedVector2Array = PackedVector2Array()
	var river_km2: float = float(tile_rules["water"]["river_start_km2"])

	for reach in reaches:
		if float(reach.get("area_km2", 0.0)) < river_km2:
			continue

		for point in reach.get("polyline", []):
			fresh_points.append(Vector2(float(point[0]), float(point[2])))

	var ground: PackedFloat32Array = crop(water.heights, n, core)
	return _finish(tile, water, Vector2i(origin_sx, origin_sz), spacing_m, fresh_points, {"raw_heights": ground, "eroded_heights": ground}, timings)


# Climate, land types, geology and sites on the finished ground and water, then everything cropped to the tile: the same for a tile
# baked by the passes above and one baked from the water record. fresh_points: river line points in world metres for the climate's
# distance to fresh water (the same in every frame that holds them). before: the tile's raw_heights and eroded_heights for the result.
func _finish(tile: Vector2i, water, origin: Vector2i, spacing_m: float, fresh_points: PackedVector2Array, before: Dictionary, timings: Dictionary) -> Dictionary:
	var n: int = water.samples
	var core: int = n - 2 * margin
	var origin_sx: int = origin.x
	var origin_sz: int = origin.y
	var starter: Dictionary = starter_info(tile)
	var clock: int = Time.get_ticks_msec()
	var climate = TileClimateScript.new()
	climate.setup(settings, tile_rules, tables)
	climate.use_world_air(world_air)
	climate.use_world_fresh_water(fresh_points)
	# Wetlands and dry-season beds (record classes, Stage E M1 step 2) are ground to the climate and the land types; their own biome and
	# soil are laid on after (water_record.gd). With the rules' classes 0 to 3 this is the same array, so a rules bake is unchanged.
	var land_class: PackedByteArray = WaterRecordScript.land_view(water.water_class, tables)
	climate.build(water.heights, land_class, origin_sx, origin_sz)
	timings["climate"] = Time.get_ticks_msec() - clock

	# Land types: shore marsh, treeline and the evergreen belt over the climate biomes (no tree stands at a lake any more).
	clock = Time.get_ticks_msec()
	var land_ids: Dictionary = {}

	for name in ["marsh", "alpine_meadow", "bare_rock", "mixed_forest", "boreal_forest", "temperate_grassland", "temperate_forest", "heath"]:
		land_ids[name] = tables.id_of("biomes", name)

	var land_counts: Dictionary = TileLandTypesScript.apply(climate.biome, water.heights, land_class, water.water_surface, n, spacing_m, tile_rules.get("land_types", {}), land_ids)
	var field_cells: int = TileLandTypesScript.farmland(climate.biome, climate.fertility, water.heights, land_class, n, spacing_m, origin_sx, origin_sz, tile_rules.get("land_types", {}), land_ids)
	var wet_land_cells: int = WaterRecordScript.apply_wet_land(water.water_class, climate.biome, climate.soil, tables)

	if wet_land_cells > 0:
		print("  wet land (tile %s): %d wetland and dry-bed cells given their own biome and soil" % [str(tile), wet_land_cells])
	timings["land_types"] = Time.get_ticks_msec() - clock
	print("  land types (tile %s): %d marsh/shore cells, %d alpine meadow, %d mixed-forest belt, %d boreal belt, %d field cells (%d ms)" % [str(tile), land_counts["marsh"], land_counts["alpine"], land_counts["belt"], land_counts["boreal"], field_cells, timings["land_types"]])

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
	# Where the sea is far enough for a spring cave, worked out on the whole frame before it is cropped (tile_sites.gd inland_mask).
	var inland: PackedByteArray = crop(TileSitesScript.inland_mask(water.water_class, n, spacing_m, float(tile_rules["sites"].get("spring_cave", {}).get("min_sea_m", 0.0))), n, core)
	# Distance to perennial fresh water, on the whole frame before it is cropped so the tile edges see the water beyond them (Stage E readers,
	# water_record.gd; animals' near_fresh_water_m habitats read it from the tile file's fresh_m section).
	# A tile from the record brings the record's own distance (it counts the springs that run in the dry season, record.py).
	water.fresh_m = crop(water.fresh_m if water.fresh_m.size() == n * n else WaterRecordScript.fresh_distance(water.water_class, n, spacing_m), n, core)
	water.water_class = crop(water.water_class, n, core)
	water.water_surface = crop(water.water_surface, n, core)
	water.flow = crop(water.flow, n, core)
	var cave_heads: PackedByteArray = crop(water.cave_heads, n, core) if water.cave_heads.size() == n * n else PackedByteArray()
	water.samples = core
	climate.biome = crop(climate.biome, n, core)
	climate.soil = crop(climate.soil, n, core)
	climate.fertility = crop(climate.fertility, n, core)
	climate.moisture = crop(climate.moisture, n, core)
	climate.temperature_c = crop(climate.temperature_c, n, core)
	climate.samples = core
	var eroded_heights: PackedFloat32Array = before["eroded_heights"].duplicate()
	var height = TileHeightScript.new()
	height.samples = core
	height.spacing_m = spacing_m
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
	sites.far_from_sea = inland
	sites.cave_heads = cave_heads
	sites.build(tile, water.heights, water.water_class, climate.soil, geology, starter, mouth, water.flow, water.water_surface)
	timings["sites"] = Time.get_ticks_msec() - clock

	return {
		"tile": tile,
		"height": height,
		"raw_heights": before["raw_heights"],
		"eroded_heights": eroded_heights,
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

	if result.has("error"):
		return {"ok": false, "error": str(result["error"]), "path": "", "bytes": 0, "timings": result.get("timings", {})}

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
