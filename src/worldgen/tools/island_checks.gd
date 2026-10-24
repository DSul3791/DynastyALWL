extends SceneTree

# Island checks: numbers first, then a picture (Sal, 24 Oct, BP-T52 plan
# tech/ACTION_PLANS/Sal_island_checks.md). Prints one line per check,
#
#   CHECK name | measured | limit | PASS/FAIL/INFO
#
# and exits 1 when any line says FAIL. Read-only: it never writes a tile.
#
#   godot --headless --path . --script res://src/worldgen/tools/island_checks.gd
#
# Options (after "--"):
#   --world=DIR    world folder (default res://worlds/base_world)
#   --dir=DIR      folder holding the tile files (default <world>/tiles)
#   --island=ID    only this island of plan/island_list.json
#   --all          every island of at least min_area_km2, not only those listed in the limits file
#   --sketch-only  skip the tile checks
#   --tiles-only   skip the sketch (island shape) checks
#   --picture=DIR  write DIR/island_<id>_bearings.png: the six bearing sections in one labelled row (sketch checks); with tiles baked also island_<id>_bearings_tile.png from the 8 m maps, plus the summit plateau width
#   --bakelog=FILE the bake log; its line "gullies: N, dead ends: M" feeds the dead-end gully row
#   --spawn-search=M list pads within M metres of the spawn that pass the spawn gate (nearest first)
#   --probe=X,Z    print painted class, settled class and settled depth for the 32 m cells from X,Z 1.5 km toward +z
#   --gullies=TEXT the same line pasted directly
#   --fine         walking routes on the 8 m maps instead of the 32 m maps (about 10 minutes; run in the background)
#
# Limits live in <world>/plan/island_checks.json (null = report only).
# Island shape checks run on the 160 m sketch elevation, so they work before
# a bake; the spawn, river and seam checks read the baked tiles.

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const SketchScript := preload("res://src/worldgen/sketch/world_sketch.gd")
const ElevationScript := preload("res://src/worldgen/sketch/world_elevation.gd")
const CensusScript := preload("res://src/worldgen/sketch/island_census.gd")
const TileFileScript := preload("res://src/worldgen/tile/tile_file.gd")
const WaterStoreScript := preload("res://src/water/water_store.gd")
const EdgeCompareScript := preload("res://src/worldgen/tile/edge_compare.gd")

const RAY_STEP_M := 40.0
const RAY_MAX_M := 20000.0
const BEARINGS_DEG := [0, 60, 120, 180, 240, 300]
const CLASS_NAMES := ["beach", "prairie", "foothill", "mountain", "canyon"]
const PEAK_SEARCH_CELLS := 3
const PEAK_FLOOD_LIMIT := 40000
const RING_CELLS := 6
const MATCH_RADIUS_M := 3000.0   # island_list.json is derived data; after a sketch change the peak may have moved

var _failures: int = 0
var _checks: int = 0
var _elevation
var _limits: Dictionary = {}
var _fine: bool = false
var _gully_line: String = ""
var _probe: Vector2 = Vector2(-1.0, -1.0)
var _spawn_search_m: float = 0.0
var _rules: Dictionary = {}
var _sketch: Dictionary = {}
var _features: Dictionary = {}   # island id -> feature name of island_list.json
var _picture_dir: String = ""


func _init() -> void:
	quit(_run())


func _run() -> int:
	var world_dir: String = "res://worlds/base_world"
	var directory: String = ""
	var only_island: int = -1
	var all_islands: bool = false
	var do_sketch: bool = true
	var do_tiles: bool = true

	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--world="):
			world_dir = argument.trim_prefix("--world=")
		elif argument.begins_with("--dir="):
			directory = argument.trim_prefix("--dir=")
		elif argument.begins_with("--island="):
			only_island = int(argument.trim_prefix("--island="))
		elif argument == "--all":
			all_islands = true
		elif argument.begins_with("--picture="):
			_picture_dir = argument.trim_prefix("--picture=")
		elif argument == "--fine":
			_fine = true
		elif argument.begins_with("--bakelog="):
			_gully_line = _find_gully_line(FileAccess.get_file_as_string(argument.trim_prefix("--bakelog=")))
		elif argument.begins_with("--spawn-search="):
			_spawn_search_m = float(argument.trim_prefix("--spawn-search="))
		elif argument.begins_with("--probe="):
			var parts: PackedStringArray = argument.trim_prefix("--probe=").split(",")
			_probe = Vector2(float(parts[0]), float(parts[1]))
		elif argument.begins_with("--gullies="):
			_gully_line = argument.trim_prefix("--gullies=")
		elif argument == "--sketch-only":
			do_tiles = false
		elif argument == "--tiles-only":
			do_sketch = false

	if directory == "":
		directory = world_dir + "/tiles"

	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/island_checks.json"))

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("cannot read %s/plan/island_checks.json" % world_dir)
		return 1

	_limits = parsed
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)

	if settings == null:
		push_error("\n".join(errors))
		return 1

	if do_sketch:
		_island_checks(settings, world_dir, only_island, all_islands)

	if do_tiles:
		_tile_checks(settings, world_dir, directory)

	print("")
	print("%d checks, %d FAIL" % [_checks, _failures])
	return 1 if _failures > 0 else 0


func _quot(a: int, b: int) -> int:
	return floori(float(a) / float(b))


# ---------------------------------------------------------------- output

func _row(name: String, measured: String, limit: String, verdict: String) -> void:
	_checks += 1

	if verdict == "FAIL":
		_failures += 1

	print("CHECK %s | %s | %s | %s" % [name, measured, limit, verdict])


# Compares value with a [min, max] pair (null = no bound on that side).
func _range_row(name: String, value: float, bounds: Array, measured: String) -> void:
	var low: Variant = bounds[0] if bounds.size() > 0 else null
	var high: Variant = bounds[1] if bounds.size() > 1 else null

	if low == null and high == null:
		_row(name, measured, "none set", "INFO")
		return

	var ok: bool = (low == null or value >= float(low)) and (high == null or value <= float(high))
	_row(name, measured, "%s to %s" % [str(low) if low != null else "-", str(high) if high != null else "-"], "PASS" if ok else "FAIL")


# Upper or lower bound with one number (null = report only).
func _bound_row(name: String, value: float, bound: Variant, is_max: bool, measured: String) -> void:
	if bound == null:
		_row(name, measured, "none set", "INFO")
		return

	var ok: bool = value <= float(bound) if is_max else value >= float(bound)
	_row(name, measured, "%s %s" % ["max" if is_max else "min", str(bound)], "PASS" if ok else "FAIL")


func _config_for(island_id: int, auto_type: String = "") -> Dictionary:
	var config: Dictionary = (_limits["defaults"] as Dictionary).duplicate(true)
	var override: Dictionary = (_limits.get("islands", {}) as Dictionary).get(str(island_id), {})
	var type_rows: Dictionary = _limits.get("types", {})

	if not override.has("type") and auto_type != "":
		override = override.duplicate()
		override["type"] = auto_type

	# An island row may name a type; the type's row (island_checks.json "types") applies first, the island's own keys on top.
	if override.has("type") and type_rows.has(str(override["type"])):
		var merged: Dictionary = (type_rows[str(override["type"])] as Dictionary).duplicate(true)
		merged.merge(override, true)
		override = merged

	for key in override.keys():
		if typeof(config.get(key)) == TYPE_DICTIONARY and typeof(override[key]) == TYPE_DICTIONARY:
			config[key].merge(override[key], true)
		else:
			config[key] = override[key]

	return config


# ---------------------------------------------------------------- island shape (sketch)

func _island_checks(settings, world_dir: String, only_island: int, all_islands: bool) -> void:
	var errors: Array = []
	var rules: Dictionary = SketchScript.load_rules(world_dir + "/plan/sketch_rules.json", errors)

	if rules.is_empty():
		push_error("\n".join(errors))
		_row("sketch rules", "cannot read", "-", "FAIL")
		return

	_rules = rules
	var existing: Dictionary = {}
	var sketch_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/world_sketch.json"))

	if typeof(sketch_parsed) == TYPE_DICTIONARY:
		existing = sketch_parsed

	var sketch_maker = SketchScript.new()
	sketch_maker.setup(settings, rules)
	var sketch: Dictionary = sketch_maker.generate(existing)
	_elevation = ElevationScript.new()
	_elevation.build(settings, rules, sketch, 0.0)
	_sketch = sketch
	var census: Dictionary = CensusScript.count(_elevation)
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/island_list.json"))

	if typeof(listed) != TYPE_DICTIONARY:
		_row("island list", "cannot read plan/island_list.json", "-", "FAIL")
		return

	# island_list.json ids to census numbers, by the peak cell.
	var wanted: Dictionary = {}
	var min_area: float = float((_limits["defaults"] as Dictionary)["min_area_km2"])

	for entry in listed["islands"]:
		var island_id: int = int(entry["id"])

		if only_island >= 0 and island_id != only_island:
			continue

		var named: bool = (_limits.get("islands", {}) as Dictionary).has(str(island_id))

		if only_island < 0 and not named and not (all_islands and float(entry["area_km2"]) >= min_area):
			continue

		var number: int = _census_number(census, float(entry["peak_x_m"]), float(entry["peak_z_m"]))

		if number < 0:
			_row("island %d found in the sketch" % island_id, "no island with that peak", "-", "FAIL")
			continue

		wanted[number] = island_id
		_features[island_id] = str(entry.get("feature", ""))

	var cells_of: Dictionary = {}

	for number in wanted.keys():
		cells_of[number] = PackedInt32Array()

	var label: PackedInt32Array = census["label"]

	for index in range(label.size()):
		var number: int = label[index]

		if number >= 0 and cells_of.has(number):
			cells_of[number].append(index)

	for number in wanted.keys():
		_check_island(int(wanted[number]), int(number), census, cells_of[number])


# The island type the generator gave the starter island whose mount is nearest to this peak (same pick as
# WorldElevation._island_config: starter_types by tile, else a weighted hash of the mount position). "" when no starter mount is near.
func _starter_mount(peak: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = 6000.0

	for feature in _sketch.get("features", []):
		for mount in feature.get("mounts", []):
			if str(mount["type"]) != "starter":
				continue

			var distance: float = Vector2(float(mount["x"]), float(mount["z"])).distance_to(peak)

			if distance < best_distance:
				best_distance = distance
				best = mount

	return best


func _auto_type(peak: Vector2) -> String:
	var types: Dictionary = _rules.get("island_types", {})
	var best: Dictionary = _starter_mount(peak)

	if best.is_empty() or types.is_empty():
		return ""

	var key: String = "%d,%d" % [int(best["starter"][0]), int(best["starter"][1])] if best.has("starter") else ""
	var chosen: String = str((_rules.get("starter_types", {}) as Dictionary).get(key, ""))

	if chosen != "" and types.has(chosen):
		return chosen

	var total: float = 0.0

	for type_name in types:
		total += float(types[type_name].get("weight", 1.0))

	var hash_value: int = (int(best["x"]) * 73856093) ^ (int(best["z"]) * 19349663)
	var roll: float = float(absi(hash_value) % 10007) / 10007.0 * total

	for type_name in types:
		roll -= float(types[type_name].get("weight", 1.0))

		if roll <= 0.0:
			return str(type_name)

	return str(types.keys()[0])


func _census_number(census: Dictionary, x_m: float, z_m: float) -> int:
	var best: int = -1
	var best_distance: float = MATCH_RADIUS_M
	var islands: Array = census["islands"]

	for number in range(islands.size()):
		var peak_index: int = int(islands[number]["peak_index"])
		var position: Vector2 = _elevation.cell_center_m(peak_index % _elevation.size_x, peak_index / _elevation.size_x)
		var distance: float = position.distance_to(Vector2(x_m, z_m))

		if distance < best_distance:
			best_distance = distance
			best = number

	return best


func _check_island(island_id: int, number: int, census: Dictionary, cells: PackedInt32Array) -> void:
	var peak_cell: int = int(census["islands"][number]["peak_index"])
	var auto_type: String = _auto_type(_elevation.cell_center_m(peak_cell % _elevation.size_x, _quot(peak_cell, _elevation.size_x)))

	# Shelf islands without a starter mount are the generator's "shelf_hills" type (Sonny, 24 Oct).
	if auto_type == "" and str(_features.get(island_id, "")).begins_with("shelf") and (_limits.get("types", {}) as Dictionary).has("shelf_hills"):
		auto_type = "shelf_hills"

	var config: Dictionary = _config_for(island_id, auto_type)
	var title: String = "island %d" % island_id

	if config.has("name"):
		title += " (%s)" % str(config["name"])

	var island: Dictionary = census["islands"][number]
	var peak_index: int = int(island["peak_index"])
	var peak_m: Vector2 = _elevation.cell_center_m(peak_index % _elevation.size_x, peak_index / _elevation.size_x)
	print("")
	print("== %s: %.1f km2, peak %.0f m at %d, %d" % [title, float(island["area_km2"]), float(island["peak_m"]), int(peak_m.x), int(peak_m.y)])
	var heights: PackedFloat32Array = _elevation.heights

	# Relief: spread between the 2nd and 98th percentile of land height.
	var land: PackedFloat32Array = PackedFloat32Array()

	for index in cells:
		land.append(heights[index])

	land.sort()
	var low: float = land[int(float(land.size()) * 0.02)]
	var high: float = land[mini(land.size() - 1, int(float(land.size()) * 0.98))]
	_range_row("%s relief range" % title, high - low, config["relief_range_m"], "%.0f m (p2 %.0f, p98 %.0f, peak %.0f)" % [high - low, low, high, float(island["peak_m"])])

	# Peaks.
	var peaks: Array = _find_peaks(cells, number, census["label"], float(island["peak_m"]), config)
	_range_row("%s peak count" % title, float(peaks.size()), config["peak_count"], "%d" % peaks.size())
	_layout_check(title, peaks, peak_m, config)
	_crater_check(title, peak_m, config)

	# Slopes and sectors, around the main peak.
	var sectors: int = int(config["sector_count"])
	var climb: float = float(config["climb_limit_deg"])
	var steep: int = 0
	var sector_total: PackedInt32Array = PackedInt32Array()
	var sector_ok: PackedInt32Array = PackedInt32Array()
	sector_total.resize(sectors)
	sector_ok.resize(sectors)
	var class_counts: Dictionary = {}

	for class_name_ in CLASS_NAMES:
		class_counts[class_name_] = 0

	for index in cells:
		var column: int = index % _elevation.size_x
		var row: int = index / _elevation.size_x
		var slope: float = _slope_deg(column, row)
		var position: Vector2 = _elevation.cell_center_m(column, row)
		var angle: float = fposmod(rad_to_deg(atan2(position.x - peak_m.x, -(position.y - peak_m.y))), 360.0)
		var sector: int = mini(sectors - 1, int(angle / (360.0 / float(sectors))))
		sector_total[sector] += 1

		if slope > climb:
			steep += 1
		else:
			sector_ok[sector] += 1

		var picked: String = _terrain_class(column, row, slope, config["classes"], float(config["beach_top_m"]))
		class_counts[picked] = int(class_counts[picked]) + 1

	var steep_share: float = float(steep) / float(cells.size())
	_bound_row("%s steep share (over %.0f deg)" % [title, climb], steep_share, config["steep_share_max"], true, "%.1f%% of land at 160 m cells" % (steep_share * 100.0))
	var worst_share: float = 2.0
	var worst_sector: int = -1

	for sector in range(sectors):
		if sector_total[sector] < 3:
			continue

		var share: float = float(sector_ok[sector]) / float(sector_total[sector])

		if share < worst_share:
			worst_share = share
			worst_sector = sector

	_bound_row("%s walkable share, worst sector" % title, worst_share, config["walkable_min_share_per_sector"], false,
		"%.0f%% walkable in sector %d (of %d, from %d deg)" % [worst_share * 100.0, worst_sector, sectors, int(float(worst_sector) * 360.0 / float(sectors))])

	# Terrain mix.
	var mix: PackedStringArray = PackedStringArray()

	for class_name_ in CLASS_NAMES:
		var share: float = float(class_counts[class_name_]) / float(cells.size())
		mix.append("%s %.0f%%" % [class_name_, share * 100.0])
		var bounds: Variant = (config["class_share"] as Dictionary).get(class_name_)

		if bounds != null:
			_range_row("%s share of %s" % [title, class_name_], share, bounds, "%.1f%%" % (share * 100.0))

	_row("%s terrain mix" % title, ", ".join(mix), "report", "INFO")
	_flat_share_check(title, cells, config)
	_farmland_check(title, cells, config)
	_range_row("%s summit height" % title, float(island["peak_m"]), config["summit_range_m"], "%.0f m%s" % [float(island["peak_m"]), (" (type %s)" % str(config["type"])) if config.has("type") else ""])

	if config["band_table_check"]:
		_band_checks(title, land, float(island["peak_m"]), config)

	# Rays from the main peak to the coast: profile, slope, beach.
	var bearings: Array = []

	for bearing in BEARINGS_DEG:
		bearings.append({"label": "%d deg" % bearing, "deg": float(bearing)})

	if peaks.size() > 1:
		var second: Vector2 = peaks[1]
		bearings.append({"label": "axis to 2nd peak", "deg": fposmod(rad_to_deg(atan2(second.x - peak_m.x, -(second.y - peak_m.y))), 360.0)})

	var distances: Array = config["profile_distances_m"]
	var targets: Variant = config["profile_targets_m"]
	var beach_widths: Array = []
	var ray_slope_worst: float = 0.0
	var drawn: Array = []

	for bearing in bearings:
		var ray: Dictionary = _ray(peak_m, float(bearing["deg"]), distances, float(config["beach_top_m"]))
		drawn.append({"deg": float(bearing["deg"]), "ray": ray})
		ray_slope_worst = maxf(ray_slope_worst, float(ray["max_slope_deg"]))

		if ray["coast_m"] < 0.0:
			_row("%s ray %s" % [title, bearing["label"]], "no coast within %.0f km" % (RAY_MAX_M / 1000.0), "-", "INFO")
			continue

		if float(ray["beach_m"]) >= 0.0:
			beach_widths.append(float(ray["beach_m"]))

		var parts: PackedStringArray = PackedStringArray()
		var limit_parts: PackedStringArray = PackedStringArray()
		var ok: bool = true
		var limited: bool = false

		for distance in distances:
			var value: Variant = ray["heights"][int(distance)]
			parts.append("%.1fkm %s" % [float(distance) / 1000.0, "short" if value == null else "%.0f m" % float(value)])

			if targets != null and (targets as Dictionary).has(str(int(distance))):
				var band: Array = targets[str(int(distance))]
				limit_parts.append("%.1fkm %d-%d" % [float(distance) / 1000.0, int(band[0]), int(band[1])])
				limited = true

				if value != null and (float(value) < float(band[0]) or float(value) > float(band[1])):
					ok = false

		parts.append("coast %.1f km" % (float(ray["coast_m"]) / 1000.0))
		parts.append("max slope %.0f deg" % float(ray["max_slope_deg"]))
		_row("%s ray %s" % [title, bearing["label"]], ", ".join(parts), ", ".join(limit_parts) if limited else "none set", ("PASS" if ok else "FAIL") if limited else "INFO")

	if _picture_dir != "":
		_draw_sections(island_id, drawn, float(island["peak_m"]), title)

	_bound_row("%s steepest ray slope" % title, ray_slope_worst, config["ray_slope_max_deg"], true, "%.0f deg" % ray_slope_worst)

	if beach_widths.is_empty():
		_row("%s beach width" % title, "no ray reaches %.0f m" % float(config["beach_top_m"]), "-", "INFO")
	else:
		var total: float = 0.0

		for width in beach_widths:
			total += float(width)

		var mean: float = total / float(beach_widths.size())
		_range_row("%s beach width (coast to %.0f m)" % [title, float(config["beach_top_m"])], mean, config["beach_width_m"], "mean %.0f m over %d rays" % [mean, beach_widths.size()])

	_island_route_check(title, cells, config)


# ---------------------------------------------------------------- height bands (Sonny, Dave 24 Oct)

# Land share in the beach and flat band: cells at or under flat_slope_deg.
func _flat_share_check(title: String, cells: PackedInt32Array, config: Dictionary) -> void:
	var flat_deg: float = float(config["flat_slope_deg"])
	var flat: int = 0

	for index in cells:
		if _slope_deg(index % _elevation.size_x, index / _elevation.size_x) <= flat_deg:
			flat += 1

	var share: float = float(flat) / float(cells.size())
	_bound_row("%s flat share (slope under %.0f deg)" % [title, flat_deg], share, config["flat_share_min"], false, "%.1f%% of land" % (share * 100.0))


# Rolling farmland (Dave 24 Oct): land from the beach top up to farm_top_m.
# Share farmable (slope at or under farm_slope_deg) and share rolling (over
# flat_slope_deg, so valleys are real); null limits report only.
func _farmland_check(title: String, cells: PackedInt32Array, config: Dictionary) -> void:
	var farm_deg: float = float(config["farm_slope_deg"])
	var flat_deg: float = float(config["flat_slope_deg"])
	var top_m: float = float(config["farm_top_m"])
	var low_m: float = float(config["beach_top_m"])
	var zone: int = 0
	var farmable: int = 0
	var rolling: int = 0
	var rocky: int = 0

	for index in cells:
		var column: int = index % _elevation.size_x
		var row: int = _quot(index, _elevation.size_x)
		var h: float = _cell_h(column, row)

		if h <= low_m or h > top_m:
			continue

		var slope: float = _slope_deg(column, row)

		# Cliff and canyon-apron cells are not farmland: leave them out of the zone (counted below).
		if bool(config["farm_skip_rocky"]) and _terrain_class(column, row, slope, config["classes"], low_m) in ["canyon", "mountain"]:
			rocky += 1
			continue

		zone += 1

		if slope <= farm_deg:
			farmable += 1

			if slope > flat_deg:
				rolling += 1

	if zone == 0:
		_row("%s farmland" % title, "no land between %.0f and %.0f m" % [low_m, top_m], "-", "INFO")
		return

	var farm_share: float = float(farmable) / float(zone)
	var rolling_share: float = float(rolling) / float(zone)
	_bound_row("%s farmable share (slope at or under %.0f deg, %.0f-%.0f m)" % [title, farm_deg, low_m, top_m], farm_share, config["farm_share_min"], false, "%.1f%% of %d cells (%d rocky cells left out)" % [farm_share * 100.0, zone, rocky])
	_bound_row("%s rolling share (farmable but over %.0f deg)" % [title, flat_deg], rolling_share, config["rolling_share_min"], false, "%.1f%% of %d cells" % [rolling_share * 100.0, zone])
	_bound_row("%s rolling share, too hilly for farmland" % title, rolling_share, config["rolling_share_max"], true, "%.1f%% (English look 35-55%%)" % (rolling_share * 100.0))


# The island's land, ranked by height, against starter_islands.height_bands of
# sketch_rules.json: at each band share the measured height divided by the
# island's own peak must match the band fraction, and the peak must sit in summit_m.
# `land` is the sorted land heights.
func _band_checks(title: String, land: PackedFloat32Array, peak_m: float, config: Dictionary) -> void:
	var starter: Dictionary = _rules.get("starter_islands", {})
	var type_rules: Dictionary = (_rules.get("island_types", {}) as Dictionary).get(str(config.get("type", "")), {})
	var bands: Array = type_rules.get("height_bands", starter.get("height_bands", []))

	if bands.is_empty():
		_row("%s height bands" % title, "no height_bands in sketch_rules.json", "-", "INFO")
		return

	var tolerance_m: float = float(config["band_tolerance_m"])
	var tolerance_frac: float = float(config["band_tolerance_frac"])

	for i in range(1, bands.size() - 1):
		var share: float = float(bands[i][0])
		var expected: float = peak_m * float(bands[i][1])
		var measured: float = land[mini(land.size() - 1, int(share * float(land.size())))]
		var allowed: float = maxf(tolerance_m, expected * tolerance_frac)
		_row("%s band at %.0f%% of land" % [title, share * 100.0], "%.0f m (expected %.0f m of peak %.0f)" % [measured, expected, peak_m], "within %.0f m" % allowed, "PASS" if absf(measured - expected) <= allowed else "FAIL")


# ---------------------------------------------------------------- picture

const GLYPHS := {
	"0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
	"4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001001001",
	"8": "111101111101111", "9": "111101111001111", "k": "101101110101101", "m": "101111111101101",
	"-": "000000111000000", "+": "000010111010000",
}
const PANEL_W := 420
const PANEL_H := 320
const MARGIN := 48
const SECTION_FLAT := Color(0.40, 0.65, 0.30)
const SECTION_EASY := Color(0.85, 0.62, 0.20)
const SECTION_HARD := Color(0.80, 0.22, 0.18)


# One row of sections, one panel per bearing: the coast at the left, the peak at the right (the profile
# read back from the peak outward), every panel on the same scales. Fill colour is the local slope:
# green under the easy limit (25 deg), orange up to the hard limit (45 deg), red above it.
func _draw_sections(island_id: int, drawn: Array, peak_m: float, title: String, step_m: float = RAY_STEP_M, suffix: String = "") -> void:
	var limit_m: float = 1000.0
	var tallest: float = ceil(peak_m / 100.0) * 100.0

	for entry in drawn:
		limit_m = maxf(limit_m, ceil(float(entry["ray"]["coast_m"]) / 1000.0) * 1000.0)

	var panels: int = drawn.size()
	var image: Image = Image.create(MARGIN + panels * (PANEL_W + MARGIN), PANEL_H + 2 * MARGIN, false, Image.FORMAT_RGB8)
	image.fill(Color(0.96, 0.96, 0.94))
	var ink: Color = Color(0.12, 0.12, 0.12)
	var grid: Color = Color(0.80, 0.80, 0.78)
	var easy: float = tan(deg_to_rad(float((_limits["tiles"] as Dictionary)["route_easy_deg"])))
	var hard: float = tan(deg_to_rad(float((_limits["tiles"] as Dictionary)["route_hard_deg"])))

	for panel in range(panels):
		var left: int = MARGIN + panel * (PANEL_W + MARGIN)
		var top: int = MARGIN
		image.fill_rect(Rect2i(left, top, PANEL_W, PANEL_H), Color(1, 1, 1))

		# Grid: a line every 1 km across, every 200 m up.
		for km in range(int(limit_m / 1000.0) + 1):
			var gx: int = left + int(float(km) * 1000.0 / limit_m * float(PANEL_W - 1))
			image.fill_rect(Rect2i(gx, top, 1, PANEL_H), grid)
			_text(image, gx - 3, top + PANEL_H + 6, "%d" % km, ink, 2)

		for step in range(int(tallest / 200.0) + 1):
			var gy: int = top + PANEL_H - 1 - int(float(step) * 200.0 / tallest * float(PANEL_H - 1))
			image.fill_rect(Rect2i(left, gy, PANEL_W, 1), grid)

			if panel == 0:
				_text(image, 2, gy - 4, "%d" % (step * 200), ink, 2)

		# Section: the coast at x = 0, inland to the right.
		var ray: Dictionary = drawn[panel]["ray"]
		var samples: PackedFloat32Array = ray["samples"]
		var coast: float = float(ray["coast_m"])

		if coast > 0.0:
			var count: int = samples.size()

			for x in range(PANEL_W):
				var inland: float = float(x) / float(PANEL_W - 1) * limit_m
				var at: float = (coast - inland) / step_m

				if at < 0.0:
					break

				var index: int = clampi(int(round(at)), 0, count - 1)
				var h: float = maxf(samples[index], 0.0)
				var neighbor: float = samples[clampi(index + 1, 0, count - 1)]
				var local: float = absf(neighbor - samples[index]) / step_m
				var color: Color = SECTION_FLAT if local <= easy else (SECTION_EASY if local <= hard else SECTION_HARD)
				var column_top: int = top + PANEL_H - 1 - int(h / tallest * float(PANEL_H - 1))
				image.fill_rect(Rect2i(left + x, column_top, 1, top + PANEL_H - column_top), color)

		# Label: the bearing, large, over the panel.
		_text(image, left + 6, top + 6, "%d" % int(round(float(drawn[panel]["deg"]))), ink, 4)

	var unit_y: int = PANEL_H + MARGIN + 18
	_text(image, MARGIN, unit_y, "%d" % island_id, ink, 3)
	_text(image, MARGIN + 60, unit_y, "%dm" % int(tallest), ink, 3)
	_text(image, MARGIN + 200, unit_y, "%dkm" % int(limit_m / 1000.0), ink, 3)
	var path: String = "%s/island_%d_bearings%s.png" % [_picture_dir, island_id, suffix]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_picture_dir) if _picture_dir.begins_with("res://") else _picture_dir)
	var saved: int = image.save_png(path)
	_row("%s picture" % title, path if saved == OK else "cannot save %s" % path, "6 bearing sections, grid 1 km x 200 m, colour = slope", "PASS" if saved == OK else "FAIL")


func _text(image: Image, x: int, y: int, text: String, color: Color, scale: int) -> void:
	var cursor: int = x

	for character in text:
		var glyph: String = GLYPHS.get(character, "")

		if glyph != "":
			for bit in range(15):
				if glyph[bit] == "1":
					image.fill_rect(Rect2i(cursor + (bit % 3) * scale, y + _quot(bit, 3) * scale, scale, scale), color)

		cursor += 4 * scale


# The real summit of each listed island on the baked 8 m maps: plateau width, and the six sections when --picture is given.
func _tile_summits(world_dir: String, fine: Dictionary) -> void:
	var listed: Variant = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/island_list.json"))

	if typeof(listed) != TYPE_DICTIONARY:
		return

	var tile_limits: Dictionary = _limits["tiles"]
	var spacing: float = fine["spacing"]
	var width: int = fine["width"]
	var rows: int = fine["rows"]
	var heights: PackedFloat32Array = fine["heights"]
	var waters: PackedByteArray = fine["water"]

	for entry in listed["islands"]:
		var island_id: int = int(entry["id"])

		if not (_limits.get("islands", {}) as Dictionary).has(str(island_id)):
			continue

		var config: Dictionary = _config_for(island_id)
		var title: String = "island %d tile" % island_id
		var around_i: int = int(round((float(entry["peak_x_m"]) - float(fine["origin_x"])) / spacing))
		var around_j: int = int(round((float(entry["peak_z_m"]) - float(fine["origin_z"])) / spacing))
		var reach: int = int(round(float(tile_limits["summit_search_m"]) / spacing))
		var best: float = -INF
		var best_index: int = -1

		for dj in range(-reach, reach + 1):
			for di in range(-reach, reach + 1):
				var i: int = around_i + di
				var j: int = around_j + dj

				if i < 0 or j < 0 or i >= width or j >= rows or waters[j * width + i] == 255:
					continue

				if heights[j * width + i] > best:
					best = heights[j * width + i]
					best_index = j * width + i

		if best_index < 0:
			_row("%s summit" % title, "island %d is not in the baked tiles" % island_id, "-", "INFO")
			continue

		var peak_xz: Vector2 = Vector2(float(fine["origin_x"]) + float(best_index % width) * spacing, float(fine["origin_z"]) + float(_quot(best_index, width)) * spacing)

		for band in config["summit_plateaus"]:
			var plateau: Dictionary = _plateau(fine, best_index, float(band["within_m"]))
			_bound_row("%s summit plateau (within %.0f m of the top)" % [title, float(band["within_m"])], float(plateau["across_m"]), band["max_m"], true,
				"top %.0f m at x %d z %d, flat area %.0f m across (%d cells)" % [best, int(peak_xz.x), int(peak_xz.y), float(plateau["across_m"]), int(plateau["cells"])])

		_slope_rows(title, fine, best_index, config)

		if _picture_dir == "":
			continue

		var drawn: Array = []

		for bearing in BEARINGS_DEG:
			drawn.append({"deg": float(bearing), "ray": _ray_fine(fine, peak_xz, float(bearing))})

		_draw_sections(island_id, drawn, best, title, spacing, "_tile")


# Slope classes and canyon share on the 8 m maps in a window of slope_window_m round the summit:
# land at or under the easy limit, up to the hard limit, steeper; and the share of land lying at least
# canyon_min_depth_m below the mean of 8 points 60 m away (gorge floors).
func _slope_rows(title: String, fine: Dictionary, top_index: int, config: Dictionary) -> void:
	var tile_limits: Dictionary = _limits["tiles"]
	var width: int = fine["width"]
	var rows: int = fine["rows"]
	var spacing: float = fine["spacing"]
	var heights: PackedFloat32Array = fine["heights"]
	var waters: PackedByteArray = fine["water"]
	var reach: int = int(float(tile_limits["slope_window_m"]) / spacing)
	var ring: int = int(round(60.0 / spacing))
	var easy_tan: float = tan(deg_to_rad(float(tile_limits["route_easy_deg"])))
	var hard_tan: float = tan(deg_to_rad(float(tile_limits["route_hard_deg"])))
	var depth: float = float(tile_limits["canyon_min_depth_m"])
	var ci: int = top_index % width
	var cj: int = _quot(top_index, width)
	var land: int = 0
	var easy: int = 0
	var hard: int = 0
	var canyon: int = 0

	for j in range(maxi(ring + 1, cj - reach), mini(rows - ring - 2, cj + reach)):
		for i in range(maxi(ring + 1, ci - reach), mini(width - ring - 2, ci + reach)):
			var index: int = j * width + i

			if heights[index] <= 0.0 or waters[index] == 255 or waters[index] == 1:
				continue

			land += 1
			var dx: float = absf(heights[index + 1] - heights[index - 1]) / (2.0 * spacing)
			var dz: float = absf(heights[index + width] - heights[index - width]) / (2.0 * spacing)
			var slope: float = sqrt(dx * dx + dz * dz)

			if slope <= easy_tan:
				easy += 1
			elif slope <= hard_tan:
				hard += 1

			var around: float = heights[index - ring] + heights[index + ring] + heights[index - ring * width] + heights[index + ring * width]
			around += heights[index - ring - ring * width] + heights[index + ring - ring * width] + heights[index - ring + ring * width] + heights[index + ring + ring * width]

			if around / 8.0 - heights[index] >= depth:
				canyon += 1

	if land == 0:
		return

	if _picture_dir != "":
		_draw_slope_map(title, fine, ci, cj, reach, easy_tan, hard_tan)

	var land_f: float = float(land)
	var steep: float = 1.0 - float(easy + hard) / land_f
	_row("%s slope classes (8 m maps, %.0f km window)" % [title, float(tile_limits["slope_window_m"]) / 1000.0], "easy %.0f%%, hard %.0f%%, over %.0f deg %.1f%%" % [float(easy) / land_f * 100.0, float(hard) / land_f * 100.0, float(tile_limits["route_hard_deg"]), steep * 100.0], "report", "INFO")
	_range_row("%s canyon share (floor %.0f m under the 60 m ring)" % [title, depth], float(canyon) / land_f, config["canyon_share"], "%.1f%% of land" % (float(canyon) / land_f * 100.0))


# Top-down map of the window (every 2nd sample): green easy, orange hard, red steeper, blue water, dark sea;
# a grid line every 1 km, numbered in km from the window's west and north edge.
func _draw_slope_map(title: String, fine: Dictionary, ci: int, cj: int, reach: int, easy_tan: float, hard_tan: float) -> void:
	var width: int = fine["width"]
	var rows: int = fine["rows"]
	var heights: PackedFloat32Array = fine["heights"]
	var waters: PackedByteArray = fine["water"]
	var spacing: float = fine["spacing"]
	var stride: int = 2
	var left: int = maxi(1, ci - reach)
	var top: int = maxi(1, cj - reach)
	var size_x: int = _quot(mini(width - 2, ci + reach) - left, stride)
	var size_z: int = _quot(mini(rows - 2, cj + reach) - top, stride)
	var margin: int = 20
	var image: Image = Image.create(size_x + margin, size_z + margin, false, Image.FORMAT_RGB8)
	image.fill(Color(0.96, 0.96, 0.94))
	var every: int = int(1000.0 / (spacing * float(stride)))

	for z in range(size_z):
		for x in range(size_x):
			var i: int = left + x * stride
			var j: int = top + z * stride
			var index: int = j * width + i
			var color: Color = Color(0.10, 0.18, 0.30)

			if waters[index] == 255:
				color = Color(0.7, 0.7, 0.7)
			elif heights[index] > 0.0 and waters[index] != 1:
				var dx: float = absf(heights[index + 1] - heights[index - 1]) / (2.0 * spacing)
				var dz: float = absf(heights[index + width] - heights[index - width]) / (2.0 * spacing)
				var slope: float = sqrt(dx * dx + dz * dz)
				color = SECTION_FLAT if slope <= easy_tan else (SECTION_EASY if slope <= hard_tan else SECTION_HARD)

				if waters[index] >= 2:
					color = Color(0.15, 0.40, 0.85)

			if x % every == 0 or z % every == 0:
				color = color.lerp(Color(1, 1, 1), 0.35)

			image.set_pixel(x + margin, z + margin, color)

	for k in range(_quot(size_x, every) + 1):
		_text(image, margin + k * every, 2, "%d" % k, Color(0.1, 0.1, 0.1), 2)

	for k in range(_quot(size_z, every) + 1):
		_text(image, 2, margin + k * every, "%d" % k, Color(0.1, 0.1, 0.1), 2)

	var path: String = "%s/%s_slopemap.png" % [_picture_dir, title.replace(" ", "_")]
	_row("%s slope map" % title, path if image.save_png(path) == OK else "cannot save", "green easy, orange hard, red steeper, blue water, 1 km grid", "INFO")


# The connected ground within `within_m` of the top: its widest side in metres, and its cell count.
func _plateau(fine: Dictionary, top_index: int, within_m: float) -> Dictionary:
	var width: int = fine["width"]
	var rows: int = fine["rows"]
	var heights: PackedFloat32Array = fine["heights"]
	var floor_m: float = heights[top_index] - within_m
	var window: Dictionary = {top_index: true}
	var stack: PackedInt32Array = PackedInt32Array([top_index])
	var low_i: int = top_index % width
	var high_i: int = low_i
	var low_j: int = _quot(top_index, width)
	var high_j: int = low_j

	while not stack.is_empty() and window.size() < 400000:
		var index: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var ci: int = index % width
		var cj: int = _quot(index, width)

		for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var ni: int = ci + offset.x
			var nj: int = cj + offset.y

			if ni < 0 or nj < 0 or ni >= width or nj >= rows:
				continue

			var other: int = nj * width + ni

			if window.has(other) or heights[other] < floor_m:
				continue

			window[other] = true
			stack.append(other)
			low_i = mini(low_i, ni)
			high_i = maxi(high_i, ni)
			low_j = mini(low_j, nj)
			high_j = maxi(high_j, nj)

	return {"across_m": float(maxi(high_i - low_i, high_j - low_j) + 1) * float(fine["spacing"]), "cells": window.size()}


# Walks from the summit outward over the 8 m heights until the sea or the edge of the baked area.
func _ray_fine(fine: Dictionary, origin: Vector2, bearing_deg: float) -> Dictionary:
	var spacing: float = fine["spacing"]
	var direction: Vector2 = Vector2(sin(deg_to_rad(bearing_deg)), -cos(deg_to_rad(bearing_deg)))
	var samples: PackedFloat32Array = PackedFloat32Array()
	var distance: float = 0.0
	var coast_m: float = -1.0

	while distance <= RAY_MAX_M:
		var point: Vector2 = origin + direction * distance
		var column: int = int(floor((point.x - float(fine["origin_x"])) / spacing))
		var row: int = int(floor((point.y - float(fine["origin_z"])) / spacing))

		if column < 0 or row < 0 or column >= int(fine["width"]) or row >= int(fine["rows"]) or fine["water"][row * int(fine["width"]) + column] == 255:
			coast_m = distance
			break

		var h: float = fine["heights"][row * int(fine["width"]) + column]
		samples.append(h)

		if h <= 0.0 and distance > 0.0:
			coast_m = distance
			break

		distance += spacing

	return {"coast_m": coast_m, "samples": samples}


# ---------------------------------------------------------------- sketch helpers

func _h(x_m: float, z_m: float) -> float:
	var fx: float = (x_m - _elevation.origin_x) / _elevation.cell_m - 0.5
	var fz: float = (z_m - _elevation.origin_z) / _elevation.cell_m - 0.5
	var c0: int = int(floor(fx))
	var r0: int = int(floor(fz))
	var tx: float = fx - float(c0)
	var tz: float = fz - float(r0)
	var heights: PackedFloat32Array = _elevation.heights
	var top: float = lerpf(heights[_elevation.index_of(c0, r0)], heights[_elevation.index_of(c0 + 1, r0)], tx)
	var bottom: float = lerpf(heights[_elevation.index_of(c0, r0 + 1)], heights[_elevation.index_of(c0 + 1, r0 + 1)], tx)
	return lerpf(top, bottom, tz)


func _cell_h(column: int, row: int) -> float:
	return _elevation.heights[_elevation.index_of(column, row)]


func _slope_deg(column: int, row: int) -> float:
	var dx: float = (_cell_h(column + 1, row) - _cell_h(column - 1, row)) / (2.0 * _elevation.cell_m)
	var dz: float = (_cell_h(column, row + 1) - _cell_h(column, row - 1)) / (2.0 * _elevation.cell_m)
	return rad_to_deg(atan(sqrt(dx * dx + dz * dz)))


func _terrain_class(column: int, row: int, slope: float, classes: Dictionary, beach_top_m: float) -> String:
	var h: float = _cell_h(column, row)

	if h <= beach_top_m and slope <= float(classes["beach_max_slope_deg"]) and _near_sea(column, row):
		return "beach"

	var ring: float = 0.0

	for step in range(8):
		var angle: float = float(step) * TAU / 8.0
		ring += _cell_h(column + int(round(cos(angle) * RING_CELLS)), row + int(round(sin(angle) * RING_CELLS)))

	if ring / 8.0 - h >= float(classes["canyon_depth_m"]):
		return "canyon"

	if h >= float(classes["mountain_min_h_m"]) or slope >= float(classes["mountain_min_slope_deg"]):
		return "mountain"

	if slope <= float(classes["prairie_max_slope_deg"]) and h <= float(classes["prairie_max_h_m"]):
		return "prairie"

	return "foothill"


func _near_sea(column: int, row: int) -> bool:
	for reach in [2, 3]:
		for step in range(8):
			var angle: float = float(step) * TAU / 8.0

			if _cell_h(column + int(round(cos(angle) * reach)), row + int(round(sin(angle) * reach))) <= 0.0:
				return true

	return false


# Volcano type: a crater of island_types.<type>.crater (radius_m, depth_m, breach_bearing_deg, breach_width_m)
# round the island's mount centre. Depth = the mean rim height (8 points on the rim radius) minus the lowest
# ground inside 0.8 of the radius; the breach = the lowest rim point must lie near the breach bearing and be
# clearly below the rest of the rim.
func _crater_check(title: String, top_peak: Vector2, config: Dictionary) -> void:
	var type_rules: Dictionary = (_rules.get("island_types", {}) as Dictionary).get(str(config.get("type", "")), {})

	if not type_rules.has("crater"):
		return

	var crater: Dictionary = type_rules["crater"]
	var radius: float = float(crater["radius_m"])
	var center: Vector2 = top_peak
	var best_depth: float = -INF
	var mount: Dictionary = _starter_mount(top_peak)
	var known: bool = mount.has("crater_at")

	# When the sketch records where the crater was cut (mount "crater_at": [x, z]) that is the centre.
	if known:
		center = Vector2(float(mount["crater_at"][0]), float(mount["crater_at"][1]))

	# The crater is cut into the island's highest point: search round it for the centre of the bowl, the spot
	# that the ring at 0.6 of the radius stands highest over.
	for dz in range(-16, 17):
		for dx in range(-16, 17):
			if known:
				break

			var candidate: Vector2 = top_peak + Vector2(float(dx), float(dz)) * (radius / 8.0)
			var ring_total: float = 0.0

			for step in range(8):
				var angle: float = float(step) * TAU / 8.0
				ring_total += _h(candidate.x + cos(angle) * radius * 0.6, candidate.y + sin(angle) * radius * 0.6)

			var candidate_depth: float = ring_total / 8.0 - _h(candidate.x, candidate.y)

			if candidate_depth > best_depth:
				best_depth = candidate_depth
				center = candidate

	var floor_m: float = INF
	var rim_total: float = 0.0
	var points: int = 24

	for step in range(points):
		var bearing: float = float(step) * 360.0 / float(points)
		var direction: Vector2 = Vector2(sin(deg_to_rad(bearing)), -cos(deg_to_rad(bearing)))
		var h: float = _h(center.x + direction.x * radius, center.y + direction.y * radius)
		rim_total += h

		for fraction in [0.0, 0.4, 0.8]:
			floor_m = minf(floor_m, _h(center.x + direction.x * radius * fraction, center.y + direction.y * radius * fraction))

	var rim_mean: float = rim_total / float(points)
	var depth: float = rim_mean - floor_m
	var wanted: float = float(crater["depth_m"])
	var tolerance: float = float(config["crater_depth_tolerance"])
	_row("%s crater depth (rim %.0f m radius)" % [title, radius], "%.0f m (rim mean %.0f m, floor %.0f m)" % [depth, rim_mean, floor_m], "%.0f m +- %.0f%%" % [wanted, tolerance * 100.0], "PASS" if absf(depth - wanted) <= wanted * tolerance else "FAIL")

	# Breach (Sonny): a notch from 0.6 to 1.8 crater radii out along the compass bearing (0 = north, 90 = east, direction
	# (sin b, -cos b)). The wall is the highest ground along that stretch; at the designed bearing it must be a small share
	# of the mean wall over the floor. The lowest wall of all bearings is shown too.
	var wall_total: float = 0.0
	var wall_low: float = INF
	var wall_bearing: float = 0.0

	for step in range(points):
		var bearing: float = float(step) * 360.0 / float(points)
		var wall: float = _wall(center, radius, bearing)
		wall_total += wall

		if wall < wall_low:
			wall_low = wall
			wall_bearing = bearing

	var wall_mean: float = wall_total / float(points)
	var designed: float = float(crater["breach_bearing_deg"])
	var designed_share: float = (_wall(center, radius, designed) - floor_m) / maxf(wall_mean - floor_m, 1.0)
	var lowest_share: float = (wall_low - floor_m) / maxf(wall_mean - floor_m, 1.0)
	var along: PackedStringArray = PackedStringArray()

	for offset in [-40.0, -20.0, 0.0, 20.0, 40.0]:
		var direction: Vector2 = Vector2(sin(deg_to_rad(designed + offset)), -cos(deg_to_rad(designed + offset)))
		var values: PackedStringArray = PackedStringArray()

		for fraction in [0.0, 0.6, 1.0, 1.4, 1.8]:
			values.append("%.0f" % _h(center.x + direction.x * radius * fraction, center.y + direction.y * radius * fraction))

		along.append("%+.0f deg: %s" % [offset, " ".join(values)])

	_row("%s crater profile (heights at 0, 0.6, 1.0, 1.4, 1.8 radii; centre %d, %d)" % [title, int(center.x), int(center.y)], "; ".join(along), "report", "INFO")
	_row("%s crater breach at %.0f deg" % [title, designed], "wall %.0f%% of the mean wall over the floor (lowest wall of all: %.0f deg, %.0f%%)" % [designed_share * 100.0, wall_bearing, lowest_share * 100.0], "under %.0f%%" % (float(config["crater_breach_max_wall_share"]) * 100.0),
		"PASS" if designed_share <= float(config["crater_breach_max_wall_share"]) else "FAIL")


# Highest ground between 0.6 and 1.8 crater radii out from the centre along a compass bearing.
func _wall(center: Vector2, radius: float, bearing_deg: float) -> float:
	var direction: Vector2 = Vector2(sin(deg_to_rad(bearing_deg)), -cos(deg_to_rad(bearing_deg)))
	var wall: float = -INF

	for fraction in [0.6, 0.8, 1.0, 1.2, 1.4, 1.6, 1.8]:
		wall = maxf(wall, _h(center.x + direction.x * radius * fraction, center.y + direction.y * radius * fraction))

	return wall


# Peak layout of a typed island (island_types.<type>.layout rows [along, across, radius, height] in units of the
# island's half axes): every layout peak needs a detected peak within layout_match_distance of it (same units),
# and its height as a share of the highest peak within layout_match_height of the row's height.
func _layout_check(title: String, peaks: Array, top_peak: Vector2, config: Dictionary) -> void:
	var type_rules: Dictionary = (_rules.get("island_types", {}) as Dictionary).get(str(config.get("type", "")), {})

	if not type_rules.has("layout") or peaks.is_empty():
		return

	var mount: Dictionary = _starter_mount(top_peak)

	if mount.is_empty():
		return

	var rotation: float = deg_to_rad(float(mount["rot"]))
	var tolerance: float = float(config["layout_match_distance"])
	var height_tolerance: float = float(config["layout_match_height"])
	var top_h: float = _h(peaks[0].x, peaks[0].y)
	var number: int = 0

	for row in type_rules["layout"]:
		number += 1
		var best_distance: float = INF
		var best_height: float = 0.0
		var best_at: Vector2 = Vector2.ZERO

		for peak in peaks:
			var dx: float = peak.x - float(mount["x"])
			var dz: float = peak.y - float(mount["z"])
			var along: float = (dx * cos(rotation) + dz * sin(rotation)) / float(mount["a"])
			var across: float = (-dx * sin(rotation) + dz * cos(rotation)) / float(mount["b"])
			var distance: float = Vector2(along - float(row[0]), across - float(row[1])).length()

			if distance < best_distance:
				best_distance = distance
				best_height = _h(peak.x, peak.y) / top_h
				best_at = Vector2(along, across)

		var expected: float = float(row[3])
		var ok: bool = best_distance <= tolerance and absf(best_height - expected) <= height_tolerance
		_row("%s layout peak %d (along %.2f, across %.2f)" % [title, number, float(row[0]), float(row[1])],
			"nearest peak at along %.2f across %.2f (%.2f away), %.0f%% of the top" % [best_at.x, best_at.y, best_distance, best_height * 100.0],
			"within %.2f, height %.0f%% +- %.0f%%" % [tolerance, expected * 100.0, height_tolerance * 100.0], "PASS" if ok else "FAIL")


# Separate peaks: local maxima that stand at least peak_prominence_m above
# the pass to any higher ground. Returns positions in metres, highest first.
func _find_peaks(cells: PackedInt32Array, number: int, label: PackedInt32Array, island_peak_m: float, config: Dictionary) -> Array:
	var floor_m: float = island_peak_m * float(config["peak_min_fraction"])
	var prominence: float = float(config["peak_prominence_m"])
	var candidates: Array = []

	for index in cells:
		var h: float = _elevation.heights[index]

		if h < floor_m:
			continue

		var column: int = index % _elevation.size_x
		var row: int = index / _elevation.size_x
		var is_top: bool = true

		for dz in range(-PEAK_SEARCH_CELLS, PEAK_SEARCH_CELLS + 1):
			for dx in range(-PEAK_SEARCH_CELLS, PEAK_SEARCH_CELLS + 1):
				var other: int = _elevation.index_of(column + dx, row + dz)
				var other_h: float = _elevation.heights[other]

				if other_h > h or (other_h == h and other < index):
					is_top = false
					break

			if not is_top:
				break

		if is_top:
			candidates.append(index)

	candidates.sort_custom(func(a: int, b: int) -> bool: return _elevation.heights[a] > _elevation.heights[b])
	var peaks: Array = []

	for candidate in candidates:
		if _is_prominent(candidate, number, label, prominence):
			var position: Vector2 = _elevation.cell_center_m(candidate % _elevation.size_x, candidate / _elevation.size_x)
			peaks.append(position)

	return peaks


# Flood down from the candidate over ground within `prominence` of its
# height. Reaching higher ground means it is only a shoulder.
func _is_prominent(candidate: int, number: int, label: PackedInt32Array, prominence: float) -> bool:
	var h: float = _elevation.heights[candidate]
	var seen: Dictionary = {candidate: true}
	var stack: PackedInt32Array = PackedInt32Array([candidate])

	while not stack.is_empty():
		var index: int = stack[stack.size() - 1]
		stack.remove_at(stack.size() - 1)
		var column: int = index % _elevation.size_x
		var row: int = index / _elevation.size_x

		for neighbor in [
			_elevation.index_of(column + 1, row), _elevation.index_of(column - 1, row),
			_elevation.index_of(column, row + 1), _elevation.index_of(column, row - 1),
		]:
			if seen.has(neighbor) or label[neighbor] != number:
				continue

			var other_h: float = _elevation.heights[neighbor]

			if other_h > h or (other_h == h and neighbor < candidate):
				return false

			if other_h > h - prominence:
				seen[neighbor] = true
				stack.append(neighbor)

				if seen.size() > PEAK_FLOOD_LIMIT:
					return false

	return true


# Walks from the peak outward to the sea, then reads the heights back at the
# given distances inland of the coast.
func _ray(origin: Vector2, bearing_deg: float, distances: Array, beach_top_m: float) -> Dictionary:
	var direction: Vector2 = Vector2(sin(deg_to_rad(bearing_deg)), -cos(deg_to_rad(bearing_deg)))
	var samples: PackedFloat32Array = PackedFloat32Array()
	var coast_m: float = -1.0
	var distance: float = 0.0
	var max_slope: float = 0.0

	while distance <= RAY_MAX_M:
		var point: Vector2 = origin + direction * distance
		var h: float = _h(point.x, point.y)

		if samples.size() > 0:
			max_slope = maxf(max_slope, rad_to_deg(atan(absf(h - samples[samples.size() - 1]) / RAY_STEP_M)))

		samples.append(h)

		if h <= 0.0 and distance > 0.0:
			coast_m = distance
			break

		distance += RAY_STEP_M

	var result: Dictionary = {"coast_m": coast_m, "heights": {}, "max_slope_deg": max_slope, "beach_m": -1.0, "samples": samples}

	if coast_m < 0.0:
		return result

	for inland in distances:
		var back: float = coast_m - float(inland)

		if back < 0.0:
			result["heights"][int(inland)] = null
		else:
			var point: Vector2 = origin + direction * back
			result["heights"][int(inland)] = _h(point.x, point.y)

	var inland_m: float = 0.0

	while inland_m <= coast_m:
		var point: Vector2 = origin + direction * (coast_m - inland_m)

		if _h(point.x, point.y) >= beach_top_m:
			result["beach_m"] = inland_m
			break

		inland_m += RAY_STEP_M

	return result


# ---------------------------------------------------------------- tiles (baked files, read-only)

# "gullies: N, dead ends: M" from the bake log (Sonny): dead-end gullies as a
# share of all gullies, and per km2 of baked tiles.
func _find_gully_line(text: String) -> String:
	var gullies: int = 0
	var dead: int = 0
	var found: bool = false

	# One line per tile in the bake log: add them all up.
	for line in text.split("\n"):
		if line.contains("gullies:") and line.contains("dead ends:"):
			var numbers: PackedStringArray = PackedStringArray()
			var digits: String = ""

			for letter in line + " ":
				if letter >= "0" and letter <= "9":
					digits += letter
				elif digits != "":
					numbers.append(digits)
					digits = ""

			if numbers.size() >= 2:
				gullies += int(numbers[0])
				dead += int(numbers[1])
				found = true

	return "gullies: %d, dead ends: %d" % [gullies, dead] if found else ""


func _gully_checks(area_km2: float, tile_limits: Dictionary) -> void:
	if _gully_line == "":
		_row("dead-end gullies", "no gully line (pass --bakelog=FILE or --gullies=\"gullies: N, dead ends: M\")", "-", "INFO")
		return

	var numbers: PackedStringArray = PackedStringArray()
	var digits: String = ""

	for letter in _gully_line + " ":
		if letter >= "0" and letter <= "9":
			digits += letter
		elif digits != "":
			numbers.append(digits)
			digits = ""

	if numbers.size() < 2:
		_row("dead-end gullies", "cannot read: %s" % _gully_line, "-", "INFO")
		return

	var gullies: int = int(numbers[0])
	var dead: int = int(numbers[1])
	var share: float = float(dead) / float(maxi(gullies, 1))
	_bound_row("dead-end gullies share (sink, not lake or sea, within 3 km)", share, tile_limits["gully_dead_end_max_share"], true, "%d of %d gullies, %.4f per km2" % [dead, gullies, float(dead) / maxf(area_km2, 0.001)])


func _tile_checks(settings, world_dir: String, directory: String) -> void:
	var tile_limits: Dictionary = _limits["tiles"]
	var tiles: Array = []

	for file_name in DirAccess.get_files_at(directory):
		if file_name.begins_with("tile_") and file_name.ends_with(".tile"):
			var parts: PackedStringArray = file_name.trim_prefix("tile_").trim_suffix(".tile").split("_")
			tiles.append(Vector2i(int(parts[0]), int(parts[1])))

	print("")
	print("== baked tiles: %d in %s" % [tiles.size(), directory])

	if tiles.is_empty():
		_row("baked tiles", "none found", "-", "INFO")
		return

	_seam_checks(settings, directory, tiles)
	_gully_checks(float(tiles.size()) * pow(float(settings.tile_size_m) / 1000.0, 2.0), tile_limits)
	_spawn_check(settings, world_dir, directory, tile_limits)
	var stitched: Dictionary = _stitch(tiles, directory)

	if not stitched["ok"]:
		return

	stitched["origin_x"] = float(stitched["min_x"] * settings.tile_size_m)
	stitched["origin_z"] = float(stitched["min_z"] * settings.tile_size_m)
	var settled: Dictionary = _settled_grid(stitched, tiles, directory.get_base_dir() + "/water", tile_limits)

	if settled.is_empty():
		_river_checks(stitched, tile_limits, stitched["water"], PackedByteArray(), "painted rivers, 32 m map, no settled water files", true)
	else:
		_river_checks(stitched, tile_limits, settled["grid"], settled["film"], "settled water, wet over %.2f m, film over %.3f m, 32 m map" % [float(tile_limits["river_wet_depth_m"]), float(tile_limits["river_film_depth_m"])], true)
		_river_checks(stitched, tile_limits, stitched["water"], PackedByteArray(), "painted rivers, 32 m map", false)

	if _probe.x >= 0.0:
		_probe_column(stitched, settled, tiles, directory.get_base_dir() + "/water")

	var fine: Dictionary = {}

	fine = _stitch(tiles, directory, true)

	if not fine["ok"]:
		return

	fine["origin_x"] = float(fine["min_x"] * settings.tile_size_m)
	fine["origin_z"] = float(fine["min_z"] * settings.tile_size_m)

	if _fine:
		stitched = fine

	_tile_farmland(stitched)
	_route_checks(stitched, tile_limits, _spawn_of(world_dir))

	_tile_summits(world_dir, fine)


# Farmable and rolling share per landmass on the baked 32 m maps (same zone and slopes as the sketch row).
# Reports only; landmasses with fewer than farm_min_cells zone cells are skipped.
func _tile_farmland(stitched: Dictionary) -> void:
	var defaults: Dictionary = _limits["defaults"]
	var farm_deg: float = float(defaults["farm_slope_deg"])
	var flat_deg: float = float(defaults["flat_slope_deg"])
	var low_m: float = float(defaults["beach_top_m"])
	var top_m: float = float(defaults["farm_top_m"])
	var width: int = stitched["width"]
	var rows: int = stitched["rows"]
	var spacing: float = stitched["spacing"]
	var heights: PackedFloat32Array = stitched["heights"]
	var landmass: PackedInt32Array = _label_landmasses(stitched)
	var zone: Dictionary = {}
	var farmable: Dictionary = {}
	var rolling: Dictionary = {}
	var origin: Dictionary = {}
	# Dave 24 Oct: farmland is not only floors and plains. It runs up to the foot of the evergreen belt (the softwood belt is
	# thickest at ground slope 0.30, about 17 deg) as long as the player can walk up it (easy route limit, route_easy_deg).
	var belt_deg: float = float(defaults.get("farm_belt_deg", 16.7))
	var walk_deg: float = float((_limits["tiles"] as Dictionary)["route_easy_deg"])
	var land_cells: Dictionary = {}
	var belt_cells: Dictionary = {}
	var belt_walk_cells: Dictionary = {}

	for j in range(1, rows - 1):
		for i in range(1, width - 1):
			var index: int = j * width + i
			var id: int = landmass[index]
			var h: float = heights[index]

			if id >= 0 and h > low_m and _dry(stitched["water"][index], h):
				var bdx: float = (heights[index + 1] - heights[index - 1]) / (2.0 * spacing)
				var bdz: float = (heights[index + width] - heights[index - width]) / (2.0 * spacing)
				var bslope: float = rad_to_deg(atan(sqrt(bdx * bdx + bdz * bdz)))
				land_cells[id] = int(land_cells.get(id, 0)) + 1

				if bslope <= belt_deg:
					belt_cells[id] = int(belt_cells.get(id, 0)) + 1

					if bslope <= walk_deg:
						belt_walk_cells[id] = int(belt_walk_cells.get(id, 0)) + 1

			if id < 0 or h <= low_m or h > top_m or not _dry(stitched["water"][index], h):
				continue

			var dx: float = (heights[index + 1] - heights[index - 1]) / (2.0 * spacing)
			var dz: float = (heights[index + width] - heights[index - width]) / (2.0 * spacing)
			var slope: float = rad_to_deg(atan(sqrt(dx * dx + dz * dz)))
			zone[id] = int(zone.get(id, 0)) + 1
			origin[id] = Vector2(float(stitched["origin_x"]) + float(i) * spacing, float(stitched["origin_z"]) + float(j) * spacing) if not origin.has(id) else origin[id]

			if slope <= farm_deg:
				farmable[id] = int(farmable.get(id, 0)) + 1

				if slope > flat_deg:
					rolling[id] = int(rolling.get(id, 0)) + 1

	for id in zone.keys():
		if int(zone[id]) < 300:
			continue

		var farm_share: float = float(int(farmable.get(id, 0))) / float(zone[id])
		var rolling_share: float = float(int(rolling.get(id, 0))) / float(zone[id])
		var belt_share: float = float(int(belt_cells.get(id, 0))) / float(maxi(int(land_cells.get(id, 1)), 1))
		var belt_walk: float = float(int(belt_walk_cells.get(id, 0))) / float(maxi(int(belt_cells.get(id, 0)), 1))
		_row("tile landmass near x %d z %d farmland up to the evergreen belt (slope at or under %.1f deg, walkable up to %.0f deg)" % [int((origin[id] as Vector2).x), int((origin[id] as Vector2).y), belt_deg, walk_deg], "%.1f%% of land is farmable, %.1f km2, %.0f%% of it walkable" % [belt_share * 100.0, float(int(belt_cells.get(id, 0))) * spacing * spacing / 1.0e6, belt_walk * 100.0], "report", "INFO")
		_row("tile landmass near x %d z %d farmland (%.0f-%.0f m, slope at or under %.0f deg)" % [int((origin[id] as Vector2).x), int((origin[id] as Vector2).y), low_m, top_m, farm_deg], "%.1f%% farmable, %.1f%% rolling, %d cells of 32 m" % [farm_share * 100.0, rolling_share * 100.0, int(zone[id])], "report", "INFO")


# Debug print for one river spot: the column of 32 m cells from _probe toward +z.
func _probe_column(stitched: Dictionary, settled: Dictionary, tiles: Array, water_dir: String) -> void:
	var width: int = stitched["width"]
	var spacing: float = stitched["spacing"]
	var heights: PackedFloat32Array = stitched["heights"]
	var painted: PackedByteArray = stitched["water"]
	var column: int = int(round((_probe.x - float(stitched["origin_x"])) / spacing))
	var row: int = int(round((_probe.y - float(stitched["origin_z"])) / spacing))
	var depths: Dictionary = {}

	for tile in tiles:
		var header: Dictionary = TileFileScript.read_header("%s/tile_%d_%d.tile" % [water_dir.get_base_dir() + "/tiles", tile.x, tile.y])
		var side: int = int(header["header"]["samples"]) if header["ok"] else 0
		depths[tile] = [side, WaterStoreScript.load_depth("%s/tile_%d_%d.water" % [water_dir, tile.x, tile.y], side) if side > 0 else PackedFloat32Array()]

	print("== probe near x %d z %d (cell %d,%d): z, ground m, painted class, settled class, film, max settled depth m in the 32 m cell" % [int(_probe.x), int(_probe.y), column, row])

	for step in range(48):
		var j: int = row + step
		var index: int = j * width + column
		var best: float = 0.0
		var per_tile: int = _quot(int((depths.values()[0] as Array)[0]) - 1, 4)
		var tile_x: int = int(stitched["min_x"]) + _quot(column, per_tile)
		var tile_z: int = int(stitched["min_z"]) + _quot(j, per_tile)
		var entry: Array = depths.get(Vector2i(tile_x, tile_z), [0, PackedFloat32Array()])
		var side: int = entry[0]
		var depth: PackedFloat32Array = entry[1]

		if side > 0 and not depth.is_empty():
			var local_i: int = (column - (tile_x - int(stitched["min_x"])) * per_tile) * 4
			var local_j: int = (j - (tile_z - int(stitched["min_z"])) * per_tile) * 4

			for dj in range(4):
				for di in range(4):
					var k: int = (local_j + dj) * side + local_i + di

					if k >= 0 and k < depth.size():
						best = maxf(best, depth[k])

		var settled_class: int = (settled["grid"] as PackedByteArray)[index] if not settled.is_empty() else -1
		var film_flag: int = (settled["film"] as PackedByteArray)[index] if not settled.is_empty() else -1
		print("  z %d | ground %.1f | painted %d | settled %d | film %d | depth %.3f" % [int(float(stitched["origin_z"]) + float(j) * spacing), heights[index], painted[index], settled_class, film_flag, best])


func _seam_checks(settings, directory: String, tiles: Array) -> void:
	for tile in tiles:
		for direction in ["east", "south"]:
			var neighbor: Vector2i = settings.wrap_tile(tile.x + (1 if direction == "east" else 0), tile.y + (1 if direction == "south" else 0))
			var path_a: String = "%s/tile_%d_%d.tile" % [directory, tile.x, tile.y]
			var path_b: String = "%s/tile_%d_%d.tile" % [directory, neighbor.x, neighbor.y]
			var name: String = "seam (%d,%d) %s to (%d,%d)" % [tile.x, tile.y, direction, neighbor.x, neighbor.y]

			if not FileAccess.file_exists(path_b):
				# The neighbor is not baked: skipped here, as in edge_match.gd, unless the plan says it is open sea.
				var report_sea: Dictionary = EdgeCompareScript.compare(path_a, "", direction)
				var sea_ok: bool = int(report_sea["failures"]) == 0
				_row(name, "neighbor not baked; %s" % (report_sea["lines"][0] if report_sea["lines"].size() > 0 else ""), "ocean edge", "PASS" if sea_ok else "INFO")
				continue

			var report: Dictionary = EdgeCompareScript.compare(path_a, path_b, direction)
			var failed: int = int(report["failures"])
			_row(name, "%d hard failures" % failed, "0", "FAIL" if failed > 0 else "PASS")

			if failed > 0:
				for line in report["lines"]:
					print("   " + str(line))


func _spawn_of(world_dir: String) -> Vector2:
	var rules: Variant = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/tile_rules.json"))

	if typeof(rules) == TYPE_DICTIONARY and (rules as Dictionary).has("spawn_pad"):
		return Vector2(float(rules["spawn_pad"]["x"]), float(rules["spawn_pad"]["z"]))

	return Vector2.ZERO


func _spawn_check(settings, world_dir: String, directory: String, tile_limits: Dictionary) -> void:
	var rules: Variant = JSON.parse_string(FileAccess.get_file_as_string(world_dir + "/plan/tile_rules.json"))

	if typeof(rules) != TYPE_DICTIONARY or not (rules as Dictionary).has("spawn_pad"):
		_row("spawn gate", "no spawn_pad in tile_rules.json", "-", "INFO")
		return

	var pad: Dictionary = rules["spawn_pad"]
	var spawn: Vector2 = Vector2(float(pad["x"]), float(pad["z"]))
	var tile: Vector2i = Vector2i(int(floor(spawn.x / float(settings.tile_size_m))), int(floor(spawn.y / float(settings.tile_size_m))))
	var path: String = "%s/tile_%d_%d.tile" % [directory, tile.x, tile.y]
	var title: String = "spawn (%d, %d) tile (%d,%d)" % [int(spawn.x), int(spawn.y), tile.x, tile.y]

	if not FileAccess.file_exists(path):
		_row(title, "tile not baked", "-", "INFO")
		return

	var header: Dictionary = TileFileScript.read_header(path)
	var height_section: Dictionary = TileFileScript.read_section(path, header["table"], "height")
	var water_section: Dictionary = TileFileScript.read_section(path, header["table"], "water_class")

	if not height_section["ok"] or not water_section["ok"]:
		_row(title, "cannot read height or water", "-", "FAIL")
		return

	var heights: PackedFloat32Array = TileFileScript.decode_height(height_section["raw"])
	var water: PackedByteArray = water_section["raw"]
	var n: int = int(header["header"]["samples"])
	var spacing: float = float(header["header"]["map_spacing_m"])
	var ring: float = float(tile_limits["spawn_ring_m"])
	var origin: Vector2 = Vector2(float(tile.x * settings.tile_size_m), float(tile.y * settings.tile_size_m))
	var center_i: int = int(round((spawn.x - origin.x) / spacing))
	var center_j: int = int(round((spawn.y - origin.y) / spacing))
	var reach: int = int(ceil(ring / spacing))
	var low: float = INF
	var high: float = -INF
	var steepest: float = 0.0
	var wet: int = 0
	var count: int = 0

	for dj in range(-reach, reach + 1):
		for di in range(-reach, reach + 1):
			if Vector2(di, dj).length() * spacing > ring:
				continue

			var i: int = center_i + di
			var j: int = center_j + dj

			if i < 0 or j < 0 or i + 1 >= n or j + 1 >= n:
				continue

			var h: float = heights[j * n + i]
			low = minf(low, h)
			high = maxf(high, h)
			count += 1

			if water[j * n + i] != 0:
				wet += 1

			steepest = maxf(steepest, rad_to_deg(atan(absf(heights[j * n + i + 1] - h) / spacing)))
			steepest = maxf(steepest, rad_to_deg(atan(absf(heights[(j + 1) * n + i] - h) / spacing)))

	_bound_row(title + " max slope in %.0f m" % ring, steepest, tile_limits["spawn_max_slope_deg"], true, "%.1f deg over %d samples (8 m map)" % [steepest, count])
	_bound_row(title + " height range", high - low, tile_limits["spawn_range_m"], true, "%.2f m (%.2f to %.2f)" % [high - low, low, high])
	_bound_row(title + " water samples", float(wet), tile_limits["spawn_max_water_cells"], true, "%d" % wet)

	if _spawn_search_m > 0.0:
		_spawn_candidates(heights, water, n, spacing, origin, spawn, ring, tile_limits)


# Pads near the spawn that pass the same gate (slope, range, no water, above the beach top), nearest first, at least 300 m apart.
func _spawn_candidates(heights: PackedFloat32Array, water: PackedByteArray, n: int, spacing: float, origin: Vector2, spawn: Vector2, ring: float, tile_limits: Dictionary) -> void:
	var reach: int = int(ceil(ring / spacing))
	var step: int = maxi(int(round(32.0 / spacing)), 1)
	var found: Array = []
	var span: int = int(ceil(_spawn_search_m / spacing))
	var center_i: int = int(round((spawn.x - origin.x) / spacing))
	var center_j: int = int(round((spawn.y - origin.y) / spacing))

	for cj in range(center_j - span, center_j + span + 1, step):
		for ci in range(center_i - span, center_i + span + 1, step):
			var offset: Vector2 = Vector2(float(ci - center_i), float(cj - center_j)) * spacing

			if offset.length() > _spawn_search_m or ci - reach < 0 or cj - reach < 0 or ci + reach + 1 >= n or cj + reach + 1 >= n:
				continue

			var low: float = INF
			var high: float = -INF
			var steepest: float = 0.0
			var wet: int = 0

			for dj in range(-reach, reach + 1):
				for di in range(-reach, reach + 1):
					if Vector2(di, dj).length() * spacing > ring:
						continue

					var k: int = (cj + dj) * n + ci + di
					low = minf(low, heights[k])
					high = maxf(high, heights[k])
					wet += 1 if water[k] != 0 else 0
					steepest = maxf(steepest, rad_to_deg(atan(absf(heights[k + 1] - heights[k]) / spacing)))
					steepest = maxf(steepest, rad_to_deg(atan(absf(heights[k + n] - heights[k]) / spacing)))

			if steepest <= float(tile_limits["spawn_max_slope_deg"]) and high - low <= float(tile_limits["spawn_range_m"]) and wet <= int(tile_limits["spawn_max_water_cells"]) and low >= 10.0:
				found.append({"d": offset.length(), "x": spawn.x + offset.x, "z": spawn.y + offset.y, "slope": steepest, "h": low})

	found.sort_custom(func(a, b): return a["d"] < b["d"])
	var picked: Array = []

	for candidate in found:
		var apart: bool = true

		for other in picked:
			if Vector2(candidate["x"] - other["x"], candidate["z"] - other["z"]).length() < 300.0:
				apart = false

		if apart:
			picked.append(candidate)

		if picked.size() >= 5:
			break

	_row("spawn candidates within %.0f m (%d pads pass)" % [_spawn_search_m, found.size()], "; ".join(picked.map(func(c): return "x %d z %d (%.0f m away, %.1f deg, %.0f m high)" % [int(c["x"]), int(c["z"]), c["d"], c["slope"], c["h"]])) if not picked.is_empty() else "none", "-", "INFO")


# The 32 m maps of all baked tiles side by side. Cells outside the baked area are 255 in `water`.
func _stitch(tiles: Array, directory: String, fine: bool = false) -> Dictionary:
	var min_x: int = 1 << 30
	var min_z: int = 1 << 30
	var max_x: int = -(1 << 30)
	var max_z: int = -(1 << 30)

	for tile in tiles:
		min_x = mini(min_x, tile.x)
		min_z = mini(min_z, tile.y)
		max_x = maxi(max_x, tile.x)
		max_z = maxi(max_z, tile.y)

	var result: Dictionary = {"ok": false, "min_x": min_x, "min_z": min_z, "width": 0, "rows": 0, "spacing": 32.0, "water": PackedByteArray(), "heights": PackedFloat32Array()}
	var side: int = 0
	var step: int = 0

	for tile in tiles:
		var path: String = "%s/tile_%d_%d.tile" % [directory, tile.x, tile.y]
		var header: Dictionary = TileFileScript.read_header(path)
		var water_section: Dictionary = TileFileScript.read_section(path, header["table"], "water_class" if fine else "low_water_class")
		var height_section: Dictionary = TileFileScript.read_section(path, header["table"], "height" if fine else "low_height")

		if not water_section["ok"] or not height_section["ok"]:
			_row("tile (%d,%d) low-res maps" % [tile.x, tile.y], str(water_section["error"]) + str(height_section["error"]), "-", "FAIL")
			return result

		if side == 0:
			side = int(header["header"]["samples" if fine else "low_res_samples"])
			step = side - 1
			result["spacing"] = float(header["header"]["map_spacing_m" if fine else "low_res_spacing_m"])
			result["width"] = (max_x - min_x + 1) * step + 1
			result["rows"] = (max_z - min_z + 1) * step + 1
			result["water"].resize(int(result["width"]) * int(result["rows"]))
			result["water"].fill(255)
			result["heights"].resize(int(result["width"]) * int(result["rows"]))
			result["heights"].fill(NAN)

		var raw: PackedByteArray = water_section["raw"]
		var low_heights: PackedFloat32Array = TileFileScript.decode_height(height_section["raw"])
		var base_x: int = (tile.x - min_x) * step
		var base_z: int = (tile.y - min_z) * step
		var width: int = result["width"]

		for j in range(side):
			for i in range(side):
				result["water"][(base_z + j) * width + base_x + i] = raw[j * side + i]
				result["heights"][(base_z + j) * width + base_x + i] = low_heights[j * side + i]

	result["ok"] = true
	return result


# Rivers must reach the ocean (or run off the edge of the baked area).
func _river_checks(stitched: Dictionary, tile_limits: Dictionary, grid: PackedByteArray, film: PackedByteArray, tag: String, gate: bool) -> void:
	var map_heights: PackedFloat32Array = stitched["heights"]
	var width: int = stitched["width"]
	var rows: int = stitched["rows"]
	var spacing: float = stitched["spacing"]
	var origin_x: float = float(stitched["origin_x"])
	var origin_z: float = float(stitched["origin_z"])
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(grid.size())
	var bodies: int = 0
	var ending_inland: int = 0
	var natural_ends: int = 0
	var heads: int = 0
	var stopped: int = 0
	var min_cells: int = int(tile_limits["river_min_cells"])
	var gap_cells: int = int(ceil(float(tile_limits["river_gap_m"]) / spacing))

	# Label connected water (lake 2, river 3, marsh 4), bridging small gaps, and see where each body ends.
	for start in range(grid.size()):
		if seen[start] != 0 or grid[start] < 2 or grid[start] > 4:
			continue

		var stack: PackedInt32Array = PackedInt32Array([start])
		seen[start] = 1
		var river_cells: int = 0
		var painted_cells: int = 0
		var reaches: bool = false
		var lowest: float = INF
		var lowest_index: int = start

		while not stack.is_empty():
			var index: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)

			if grid[index] == 3:
				river_cells += 1

			if (stitched["water"] as PackedByteArray)[index] == 3:
				painted_cells += 1

			if map_heights[index] < lowest:
				lowest = map_heights[index]
				lowest_index = index

			var ci: int = index % width
			var cj: int = _quot(index, width)

			for dj in range(-gap_cells, gap_cells + 1):
				for di in range(-gap_cells, gap_cells + 1):
					if di == 0 and dj == 0:
						continue

					var ni: int = ci + di
					var nj: int = cj + dj

					if ni < 0 or nj < 0 or ni >= width or nj >= rows:
						reaches = true
						continue

					var value: int = grid[nj * width + ni]

					if value == 1 or value == 255:
						reaches = true
					elif value >= 2 and value <= 4 and seen[nj * width + ni] == 0:
						seen[nj * width + ni] = 1
						stack.append(nj * width + ni)

		if river_cells < min_cells:
			continue

		bodies += 1

		if not reaches:
			stopped += 1
			var look: Dictionary = _descent(grid, film, map_heights, width, rows, lowest_index, spacing, float(tile_limits["river_natural_look_m"]))
			# Natural ends (Sonny's rule): the last cell is a lake, or the ground falls less than river_natural_drop_m over
			# the next river_natural_look_m (a head hollow or basin), the ground continues with water or a thin film on the way,
			# or it falls steeply (every one of the first 4 cells below the end drops more than river_steep_drop_m per 8 m: a fall where the water leaves as a film).
			# A settled-only body (no painted river cell in it) has no catchment above the river start size: a head or pit, not a river end (Steve, 24 Oct).
			if painted_cells == 0:
				heads += 1

			var natural: bool = painted_cells == 0 or grid[lowest_index] == 2 or float(look["drop_m"]) < float(tile_limits["river_natural_drop_m"]) or int(look["wet"]) > 0 or float(look["first_drop_m"]) > float(tile_limits["river_steep_drop_m"]) * spacing / 8.0
			var real_end: bool = not natural

			if real_end:
				ending_inland += 1
			else:
				natural_ends += 1

			_row("river ends %s (%s) near x %d z %d" % ["inland" if real_end else "naturally", tag, int(origin_x + float(lowest_index % width) * spacing), int(origin_z + float(_quot(lowest_index, width)) * spacing)],
				"%d river samples, lowest water at %.1f m; %s; drop %.1f m over %.0f m" % [river_cells, lowest, look["text"], float(look["drop_m"]), float(tile_limits["river_natural_look_m"])], "reaches sea", ("FAIL" if gate else "INFO") if real_end else "INFO")

	_row("rivers reach the sea (%s)" % tag, "%d river bodies, %d do not touch the sea (old count), %d of those end naturally (lake, head hollow, or water continues; %d settled-only heads with no painted river), %d end inland" % [bodies, stopped, natural_ends, heads, ending_inland], "0 inland within %.0f m gaps" % float(tile_limits["river_gap_m"]), ("FAIL" if gate else "INFO") if ending_inland > 0 else "PASS")


# The settled water (tile_X_Z.water, the server's saved simulation) on the 32 m map: ocean from the painted
# map, 3 where any 8 m cell of the block is wet over river_wet_depth_m, 0 elsewhere. A tile without a water
# file keeps its painted classes. Returns an empty array when no tile has a water file.
func _settled_grid(stitched: Dictionary, tiles: Array, water_dir: String, tile_limits: Dictionary) -> Dictionary:
	var wet_m: float = float(tile_limits["river_wet_depth_m"])
	var width: int = stitched["width"]
	var painted: PackedByteArray = stitched["water"]
	var grid: PackedByteArray = painted.duplicate()
	var film: PackedByteArray = PackedByteArray()
	film.resize(grid.size())
	var film_m: float = float(tile_limits["river_film_depth_m"])
	var found: int = 0

	for tile in tiles:
		var file_path: String = "%s/tile_%d_%d.water" % [water_dir, tile.x, tile.y]
		var header: Dictionary = TileFileScript.read_header("%s/tile_%d_%d.tile" % [water_dir.get_base_dir() + "/tiles", tile.x, tile.y])
		var side: int = int(header["header"]["samples"]) if header["ok"] else 0
		var depth: PackedFloat32Array = WaterStoreScript.load_depth(file_path, side) if side > 0 else PackedFloat32Array()

		if depth.is_empty():
			continue

		found += 1
		var step: int = _quot(side - 1, 4)
		var base_x: int = (tile.x - int(stitched["min_x"])) * step
		var base_z: int = (tile.y - int(stitched["min_z"])) * step

		# Clear this tile's painted rivers and lakes (the ocean stays), then mark the wet blocks.
		for j in range(step + 1):
			for i in range(step + 1):
				var cell: int = (base_z + j) * width + base_x + i

				if grid[cell] >= 2 and grid[cell] <= 4:
					grid[cell] = 0

		for k in range(depth.size()):
			if depth[k] > film_m:
				var cell: int = (base_z + _quot(_quot(k, side), 4)) * width + base_x + _quot(k % side, 4)
				film[cell] = 1

				if depth[k] > wet_m and grid[cell] == 0:
					grid[cell] = 3

	return {"grid": grid, "film": film} if found > 0 else {}


# From the lowest water cell of a river that stops inland, follow the steepest descent over the ground
# (8-neighbour, 32 m cells): does the land keep falling to the sea (the river should have continued) or
# does it end in a pit (a closed basin, so the terrain traps the water)?
# Returns {"text", "drop_m" (fall over the next look_m), "wet" (wet cells on that stretch), "sea" (reaches the sea)}.
func _descent(grid: PackedByteArray, film: PackedByteArray, map_heights: PackedFloat32Array, width: int, rows: int, start: int, spacing: float, look_m: float) -> Dictionary:
	var index: int = start
	var travelled: float = 0.0
	var water_cells: int = 0
	var look_drop: float = -1.0
	var look_wet: int = 0
	var start_h: float = map_heights[start]
	var first_drop: float = INF

	for step in range(2000):
		var ci: int = index % width
		var cj: int = _quot(index, width)
		var h: float = map_heights[index]

		if look_drop < 0.0 and travelled >= look_m:
			look_drop = start_h - h
			look_wet = water_cells

		if h <= 0.0 or grid[index] == 1:
			return {"text": "ground keeps falling to the sea after %.1f km (%d wet cells on the way): the river should continue" % [travelled / 1000.0, water_cells],
				"drop_m": start_h - h if look_drop < 0.0 else look_drop, "wet": water_cells if look_drop < 0.0 else look_wet, "sea": true, "first_drop_m": first_drop if first_drop != INF else 0.0}

		var best: int = -1
		var best_h: float = h

		for dj in range(-1, 2):
			for di in range(-1, 2):
				var ni: int = ci + di
				var nj: int = cj + dj

				if (di == 0 and dj == 0) or ni < 0 or nj < 0 or ni >= width or nj >= rows or grid[nj * width + ni] == 255:
					continue

				var other_h: float = map_heights[nj * width + ni]

				if other_h < best_h:
					best_h = other_h
					best = nj * width + ni

		if best < 0:
			return {"text": "ground stops falling at %.1f m after %.1f km: a closed basin (pit)" % [h, travelled / 1000.0],
				"drop_m": start_h - h if look_drop < 0.0 else look_drop, "wet": water_cells if look_drop < 0.0 else look_wet, "sea": false, "first_drop_m": first_drop if first_drop != INF else 0.0}

		if step < 4:
			first_drop = minf(first_drop, h - best_h)

		travelled += spacing * (1.414 if best % width != ci and _quot(best, width) != cj else 1.0)
		index = best

		if (grid[index] >= 2 and grid[index] <= 4) or (not film.is_empty() and film[index] == 1):
			water_cells += 1

	return {"text": "no end found in 2000 steps", "drop_m": 0.0, "wet": 0, "sea": false, "first_drop_m": 0.0}


# Walking routes on the baked tiles (Sonny's rule, Dave 24 Oct): 8-neighbour steps
# over dry land, an easy class up to route_easy_deg (passes, valley floors, fords)
# and a hard class up to route_hard_deg (goat trails, scree). Rivers count as
# crossable. Each landmass (land joined ignoring slope) should be ONE hard region;
# smaller cut-off regions (plateaus, summits) are listed, and flagged only when
# they hold more than isolated_flag_share of that landmass. Every dry cell should
# be within easy_reach_m of an easy route (a big easy region) or a coast.
func _route_checks(stitched: Dictionary, tile_limits: Dictionary, spawn: Vector2) -> void:
	var width: int = stitched["width"]
	var rows: int = stitched["rows"]
	var spacing: float = stitched["spacing"]
	var origin_x: float = float(stitched["origin_x"])
	var origin_z: float = float(stitched["origin_z"])
	var cell_km2: float = spacing * spacing / 1000000.0
	var min_km2: float = float(tile_limits["route_min_region_km2"])
	var flag_share: float = float(tile_limits["isolated_flag_share"])
	var landmass: PackedInt32Array = _label_landmasses(stitched)
	var hard: Dictionary = _label_regions(stitched, tan(deg_to_rad(float(tile_limits["route_hard_deg"]))))
	var easy: Dictionary = _label_regions(stitched, tan(deg_to_rad(float(tile_limits["route_easy_deg"]))))
	var heights: PackedFloat32Array = stitched["heights"]

	# Land per landmass, and the hard regions in each.
	var land_cells: Dictionary = {}

	for index in range(landmass.size()):
		if landmass[index] >= 0 and _dry(stitched["water"][index], heights[index]):
			land_cells[landmass[index]] = int(land_cells.get(landmass[index], 0)) + 1

	var by_landmass: Dictionary = {}

	for region in hard["regions"]:
		var key: int = landmass[int(region["start"])]

		if not by_landmass.has(key):
			by_landmass[key] = []

		by_landmass[key].append(region)

	var spawn_i: int = int(round((spawn.x - origin_x) / spacing))
	var spawn_j: int = int(round((spawn.y - origin_z) / spacing))
	var spawn_mass: int = landmass[spawn_j * width + spawn_i] if spawn_i >= 0 and spawn_j >= 0 and spawn_i < width and spawn_j < rows else -1
	var spawn_region: int = hard["label"][spawn_j * width + spawn_i] if spawn_mass >= 0 else -1
	var flagged: int = 0
	var listed: int = 0

	for key in by_landmass.keys():
		var regions: Array = by_landmass[key]
		regions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["cells"] > b["cells"])
		var total_land: int = int(land_cells.get(key, 0))
		var mass_km2: float = float(total_land) * cell_km2

		if mass_km2 < min_km2:
			continue

		var main: Dictionary = regions[0]
		var open_note: String = " (touches the unbaked edge, partly unknown)" if main["open_edge"] else ""
		var title: String = "landmass near x %d z %d" % [int(origin_x + float(main["sum_i"]) / float(main["cells"]) * spacing), int(origin_z + float(main["sum_j"]) / float(main["cells"]) * spacing)]
		_row("%s hard routes" % title, "%.1f km2 land, main region %.0f%%, %d hard regions%s" % [mass_km2, float(main["cells"]) / float(total_land) * 100.0, regions.size(), open_note], "1 region (isolated over %.0f%% flagged)" % (flag_share * 100.0), "INFO")

		for index in range(1, regions.size()):
			var region: Dictionary = regions[index]
			var area: float = float(region["cells"]) * cell_km2

			if area < min_km2 or region["open_edge"]:
				continue

			listed += 1
			var share: float = float(region["cells"]) / float(total_land)
			var is_flag: bool = share > flag_share

			if is_flag:
				flagged += 1

			_row("isolated region near x %d z %d" % [int(origin_x + float(region["sum_i"]) / float(region["cells"]) * spacing), int(origin_z + float(region["sum_j"]) / float(region["cells"]) * spacing)],
				"%.2f km2 (%.1f%% of its landmass), height %.0f to %.0f m" % [area, share * 100.0, region["min_h"], region["max_h"]],
				"under %.0f%% of landmass" % (flag_share * 100.0), "FAIL" if is_flag else "INFO")

	if spawn_region < 0:
		_row("spawn on a hard route", "the spawn cell is not walkable land", "walkable", "FAIL")
	else:
		var spawn_mass_regions: Array = by_landmass.get(spawn_mass, [])
		var is_main: bool = false

		if not spawn_mass_regions.is_empty():
			is_main = int(spawn_mass_regions[0]["id"]) == spawn_region

		_row("spawn in the main region of its landmass", "main region" if is_main else "a cut-off region (%d hard regions on this landmass)" % spawn_mass_regions.size(), "main region", "PASS" if is_main else "FAIL")

	_row("isolated regions (hard class, %d m map)" % int(spacing), "%d listed, %d flagged" % [listed, flagged], "0 flagged", "FAIL" if flagged > 0 else "PASS")

	# Easy routes: big easy regions, and the share of dry land farther than easy_reach_m from one or a coast.
	var easy_min_cells: int = int(ceil(float(tile_limits["route_easy_min_km2"]) / cell_km2))
	var big_easy: Dictionary = {}

	for region in easy["regions"]:
		if int(region["cells"]) >= easy_min_cells:
			big_easy[int(region["id"])] = true

	var reach_cells: int = int(ceil(float(tile_limits["easy_reach_m"]) / spacing))
	var distance: PackedInt32Array = PackedInt32Array()
	distance.resize(width * rows)
	distance.fill(-1)
	var frontier: PackedInt32Array = PackedInt32Array()
	var waters: PackedByteArray = stitched["water"]

	for index in range(distance.size()):
		if not _dry(waters[index], heights[index]):
			continue

		var is_source: bool = big_easy.has(int(easy["label"][index]))

		if not is_source:
			var ci: int = index % width
			var cj: int = _quot(index, width)

			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni: int = ci + offset.x
				var nj: int = cj + offset.y

				if ni >= 0 and nj >= 0 and ni < width and nj < rows and waters[nj * width + ni] == 1:
					is_source = true
					break

		if is_source:
			distance[index] = 0
			frontier.append(index)

	for step in range(reach_cells):
		var next: PackedInt32Array = PackedInt32Array()

		for index in frontier:
			var ci: int = index % width
			var cj: int = _quot(index, width)

			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni: int = ci + offset.x
				var nj: int = cj + offset.y

				if ni < 0 or nj < 0 or ni >= width or nj >= rows:
					continue

				var other: int = nj * width + ni

				if distance[other] == -1 and waters[other] != 255 and heights[other] > 0.0:
					distance[other] = step + 1
					next.append(other)

		frontier = next

	var dry_total: int = 0
	var uncovered: int = 0

	for index in range(distance.size()):
		if _dry(waters[index], heights[index]) and landmass[index] >= 0:
			dry_total += 1

			if distance[index] == -1:
				uncovered += 1

	var uncovered_share: float = float(uncovered) / float(maxi(1, dry_total))
	_bound_row("dry land farther than %.0f m from an easy route or coast" % float(tile_limits["easy_reach_m"]), uncovered_share, tile_limits["easy_uncovered_max_share"], true,
		"%.1f%% (%.1f km2 of %.1f km2); %d easy regions over %.1f km2" % [uncovered_share * 100.0, float(uncovered) * cell_km2, float(dry_total) * cell_km2, big_easy.size(), float(tile_limits["route_easy_min_km2"])])


func _dry(water_class: int, h: float) -> bool:
	return water_class != 1 and water_class != 2 and water_class != 255 and h > 0.0


# Land (above the sea, not ocean class) joined by 4-neighbour steps, ignoring slope.
func _label_landmasses(stitched: Dictionary) -> PackedInt32Array:
	var width: int = stitched["width"]
	var rows: int = stitched["rows"]
	var waters: PackedByteArray = stitched["water"]
	var heights: PackedFloat32Array = stitched["heights"]
	var label: PackedInt32Array = PackedInt32Array()
	label.resize(width * rows)
	label.fill(-1)
	var count: int = 0

	for start in range(label.size()):
		if label[start] != -1 or waters[start] == 255 or waters[start] == 1 or heights[start] <= 0.0:
			continue

		var stack: PackedInt32Array = PackedInt32Array([start])
		label[start] = count

		while not stack.is_empty():
			var index: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			var ci: int = index % width
			var cj: int = _quot(index, width)

			for offset in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni: int = ci + offset.x
				var nj: int = cj + offset.y

				if ni < 0 or nj < 0 or ni >= width or nj >= rows:
					continue

				var other: int = nj * width + ni

				if label[other] == -1 and waters[other] != 255 and waters[other] != 1 and heights[other] > 0.0:
					label[other] = count
					stack.append(other)

		count += 1

	return label


# Regions of dry cells joined by 8-neighbour steps whose slope stays under the limit (a tangent).
# Returns {"label": PackedInt32Array (region id per cell, -1 none),
#          "regions": [{id, cells, start, open_edge, sum_i, sum_j, min_h, max_h}]}
func _label_regions(stitched: Dictionary, max_tan: float) -> Dictionary:
	var width: int = stitched["width"]
	var rows: int = stitched["rows"]
	var spacing: float = stitched["spacing"]
	var waters: PackedByteArray = stitched["water"]
	var heights: PackedFloat32Array = stitched["heights"]
	var label: PackedInt32Array = PackedInt32Array()
	label.resize(width * rows)
	label.fill(-1)
	var regions: Array = []
	var offsets: Array = []
	var diagonal: float = spacing * 1.41421356

	for dj in range(-1, 2):
		for di in range(-1, 2):
			if di != 0 or dj != 0:
				offsets.append([di, dj, diagonal if di != 0 and dj != 0 else spacing])

	for start in range(label.size()):
		if label[start] != -1 or not _dry(waters[start], heights[start]):
			continue

		var id: int = regions.size()
		var stack: PackedInt32Array = PackedInt32Array([start])
		label[start] = id
		var cells: int = 0
		var open_edge: bool = false
		var sum_i: float = 0.0
		var sum_j: float = 0.0
		var min_h: float = INF
		var max_h: float = -INF

		while not stack.is_empty():
			var index: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			cells += 1
			var ci: int = index % width
			var cj: int = _quot(index, width)
			var h: float = heights[index]
			sum_i += float(ci)
			sum_j += float(cj)
			min_h = minf(min_h, h)
			max_h = maxf(max_h, h)

			for offset in offsets:
				var ni: int = ci + int(offset[0])
				var nj: int = cj + int(offset[1])

				if ni < 0 or nj < 0 or ni >= width or nj >= rows:
					open_edge = true
					continue

				var other: int = nj * width + ni

				if waters[other] == 255:
					open_edge = true
					continue

				if label[other] != -1 or not _dry(waters[other], heights[other]):
					continue

				if absf(heights[other] - h) > max_tan * float(offset[2]):
					continue

				label[other] = id
				stack.append(other)

		regions.append({"id": id, "cells": cells, "start": start, "open_edge": open_edge, "sum_i": sum_i, "sum_j": sum_j, "min_h": min_h, "max_h": max_h})

	return {"label": label, "regions": regions}


# Same test on the 160 m sketch of one island: walkable cells (slope under the
# hard limit) should form one main region; cut-off regions are listed (size,
# height, place) and flagged only above isolated_flag_share of the island's land.
func _island_route_check(title: String, cells: PackedInt32Array, config: Dictionary) -> void:
	var hard: float = float(config["route_hard_deg"])
	var flag_share: float = float(config["isolated_flag_share"])
	var cell_km2: float = pow(_elevation.cell_m / 1000.0, 2.0)
	var min_cells: int = int(ceil(float(config["unreachable_min_km2"]) / cell_km2))
	var walkable: Dictionary = {}

	for index in cells:
		if _slope_deg(index % _elevation.size_x, index / _elevation.size_x) <= hard:
			walkable[index] = true

	var seen: Dictionary = {}
	var regions: Array = []

	for start in walkable.keys():
		if seen.has(start):
			continue

		var stack: PackedInt32Array = PackedInt32Array([start])
		seen[start] = true
		var members: int = 0
		var max_h: float = -INF

		while not stack.is_empty():
			var index: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			members += 1
			max_h = maxf(max_h, _elevation.heights[index])
			var column: int = index % _elevation.size_x
			var row: int = index / _elevation.size_x

			for neighbor in [
				_elevation.index_of(column + 1, row), _elevation.index_of(column - 1, row),
				_elevation.index_of(column, row + 1), _elevation.index_of(column, row - 1),
			]:
				if walkable.has(neighbor) and not seen.has(neighbor):
					seen[neighbor] = true
					stack.append(neighbor)

		regions.append({"cells": members, "start": start, "max_h": max_h})

	regions.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["cells"] > b["cells"])
	var flagged: int = 0
	var listed: int = 0

	for region_index in range(1, regions.size()):
		var members: int = int(regions[region_index]["cells"])

		if members < min_cells:
			continue

		listed += 1
		var share: float = float(members) / float(cells.size())
		var start: int = int(regions[region_index]["start"])
		var position: Vector2 = _elevation.cell_center_m(start % _elevation.size_x, start / _elevation.size_x)
		var is_flag: bool = share > flag_share
		flagged += 1 if is_flag else 0
		_row("%s cut-off region near x %d z %d" % [title, int(position.x), int(position.y)], "%.1f km2 (%.1f%% of land), up to %.0f m" % [float(members) * cell_km2, share * 100.0, float(regions[region_index]["max_h"])], "under %.0f%% of land" % (flag_share * 100.0), "FAIL" if is_flag else "INFO")

	var main_share: float = float(regions[0]["cells"]) / float(cells.size()) if not regions.is_empty() else 0.0
	_row("%s walkable routes (160 m cells, up to %.0f deg)" % [title, hard], "main region %.0f%% of land, %d cut-off regions listed, %d flagged" % [main_share * 100.0, listed, flagged], "0 flagged", "FAIL" if flagged > 0 else "PASS")
