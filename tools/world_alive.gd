extends SceneTree

# World-alive metrics (Tyler, 31 Oct 2026): how full and living is the island, per biome, on the real baked tiles. Prints a table and compares each figure with
# TARGETS.md (min / max per biome and metric, with the source of the number), then appends one block to WORLD_ALIVE_LOG.md so the numbers can be followed run by run.
#   godot --headless --path . --script res://tools/world_alive.gd [-- --tiles=2,3:4,5 --samples=10 --log=WORLD_ALIVE_LOG.md --targets=TARGETS.md --no-log]
# What it measures (all on the nine centre tiles by default, tiles that are not baked are skipped):
#   flora per hectare, by layer, from the real flora placer (src/worldgen/runtime/flora_placer.gd) run on SAMPLES chunks of 256 m per biome (a chunk counts for the
#   biome that fills at least 60 percent of it). Layers: trees, shrubs (not berry), berry bushes, tall grass and reeds, ferns, and every other plant.
#   water: ocean, lake and river share of all cells, and river length (river cells x cell size / assumed mean width, 16 m: an estimate, the tile has no centre line).
#   animals: NOMINAL per km2 = the server's target_per_player of the species over the 0.196 km2 round each player keeps filled, times the share of the biome's
#   sampled spots the species can stand on (slope, not at the water's edge). It is the stocking the game aims at, not a count of animals living in the world:
#   animals are made near players on demand (server_animals.gd _top_up), so a census does not exist to measure.
# Exit code 0 always (it reports, it does not gate); the lines "target LOW" and "target HIGH" show what is out of range.

const GeneratorScript := preload("res://src/worldgen/runtime/terrain_generator.gd")
const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const TileHeightScript := preload("res://src/worldgen/tile/tile_height.gd")
const TableSetScript := preload("res://src/worldgen/tables/table_set.gd")
const FloraPlacerScript := preload("res://src/worldgen/runtime/flora_placer.gd")

const BERRY := ["bramble", "raspberry", "blueberry", "lingonberry", "cranberry", "cloudberry", "wild_strawberry", "crowberry", "elder", "sea_buckthorn", "sunberry", "sleetberry"]
const TALL := ["tall_grass", "thatch_grass", "reeds", "cotton_grass"]
const FERN := ["fern", "hushfern", "whisperfern"]
const LAYERS := ["trees", "shrubs", "berry", "tallgrass", "ferns", "other_plants"]
const RIVER_WIDTH_M := 16.0
const NEAR_KM2 := 0.19635   # the round of 250 m a player keeps stocked

var samples_per_biome: int = 10
var tile_from: Vector2i = Vector2i(2, 3)
var tile_to: Vector2i = Vector2i(4, 5)
var log_path: String = "WORLD_ALIVE_LOG.md"
var targets_path: String = "TARGETS.md"
var write_log: bool = true


func _layer(species: Dictionary) -> String:
	var name: String = str(species["name"])
	var kind: int = int(species["kind"])

	if kind == FloraPlacerScript.KIND_TREE:
		return "trees"

	if name in BERRY:
		return "berry"

	if name in TALL:
		return "tallgrass"

	if name in FERN:
		return "ferns"

	return "shrubs" if kind == FloraPlacerScript.KIND_SHRUB else "other_plants"


func _args() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--samples="):
			samples_per_biome = int(a.trim_prefix("--samples="))
		elif a.begins_with("--tiles="):
			var parts: PackedStringArray = a.trim_prefix("--tiles=").split(":")
			var from_parts: PackedStringArray = parts[0].split(",")
			var to_parts: PackedStringArray = parts[1].split(",") if parts.size() > 1 else from_parts
			tile_from = Vector2i(int(from_parts[0]), int(from_parts[1]))
			tile_to = Vector2i(int(to_parts[0]), int(to_parts[1]))
		elif a.begins_with("--log="):
			log_path = a.trim_prefix("--log=")
		elif a.begins_with("--targets="):
			targets_path = a.trim_prefix("--targets=")
		elif a == "--no-log":
			write_log = false


# TARGETS.md rows: | biome | metric | min | max | source |   (biome * = whole island; max may be - for none)
func _load_targets() -> Array:
	var rows: Array = []
	var path: String = ProjectSettings.globalize_path("res://" + targets_path)

	if not FileAccess.file_exists(path):
		return rows

	for line in FileAccess.get_file_as_string(path).split("\n"):
		var cells: PackedStringArray = line.strip_edges().split("|")

		if cells.size() < 6 or not line.strip_edges().begins_with("|"):
			continue

		var biome: String = cells[1].strip_edges()
		var metric: String = cells[2].strip_edges()

		if metric == "metric" or biome.begins_with("-") or biome == "biome":
			continue

		var low: String = cells[3].strip_edges()
		var high: String = cells[4].strip_edges()
		rows.append({"biome": biome, "metric": metric, "min": float(low) if low.is_valid_float() else NAN, "max": float(high) if high.is_valid_float() else NAN})

	return rows


func _judge(targets: Array, biome: String, metric: String, value: float) -> String:
	for t in targets:
		if t["biome"] == biome and t["metric"] == metric:
			if not is_nan(t["min"]) and value < t["min"]:
				return "LOW (target %s to %s)" % [str(t["min"]), "-" if is_nan(t["max"]) else str(t["max"])]

			if not is_nan(t["max"]) and value > t["max"]:
				return "HIGH (target %s to %s)" % ["-" if is_nan(t["min"]) else str(t["min"]), str(t["max"])]

			return "ok"

	return ""


func _init() -> void:
	_args()
	var begun: int = Time.get_ticks_msec()
	var errors: Array = []
	var world: String = "res://worlds/base_world"
	var settings = WorldSettingsScript.load_from_file(world + "/world.json", errors)
	var rules: Dictionary = TileHeightScript.load_rules(world + "/plan/tile_rules.json", errors)
	var tables = TableSetScript.new()
	errors.append_array(tables.load_directory())
	var generator = GeneratorScript.new()
	generator.setup(settings, rules, tables, world + "/tiles")
	var placer = FloraPlacerScript.new()
	placer.setup(generator, tables, rules)
	var biome_names: Dictionary = {}

	for entry in tables.get_entries("biomes"):
		biome_names[int(entry["id"])] = str(entry["name"])

	var animal_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/animals/animals.json"))
	var species: Dictionary = animal_cfg.get("species", {})
	var chunk_m: float = placer.chunk_m
	var ha: float = chunk_m * chunk_m / 10000.0
	var by_biome: Dictionary = {}   # biome name -> Array of {tile, chunk, centre}
	var cells: int = 0
	var counts: Dictionary = {1: 0, 2: 0, 3: 0}
	var land_cells: int = 0
	var cell_area_km2: float = 0.0
	var tiles_done: int = 0

	for tz in range(tile_from.y, tile_to.y + 1):
		for tx in range(tile_from.x, tile_to.x + 1):
			var data = generator.get_tile(Vector2i(tx, tz))

			if data.placeholder:
				print("tile %d,%d is not baked, skipped" % [tx, tz])
				continue

			tiles_done += 1
			cell_area_km2 = data.spacing_m * data.spacing_m / 1.0e6

			for k in range(data.samples * data.samples):
				cells += 1
				var wc: int = data.water_class[k]

				if counts.has(wc):
					counts[wc] += 1

				if data.heights[k] > 0.0:
					land_cells += 1

			var side_m: float = float(data.samples - 1) * data.spacing_m
			var steps: int = int(floor(side_m / chunk_m))

			for cz in range(steps):
				for cx in range(steps):
					var x: float = data.x0 + (float(cx) + 0.5) * chunk_m
					var z: float = data.z0 + (float(cz) + 0.5) * chunk_m
					var tally: Dictionary = {}

					for dz in [-0.35, 0.0, 0.35]:
						for dx in [-0.35, 0.0, 0.35]:
							var b: int = data.biome[data.nearest(x + dx * chunk_m, z + dz * chunk_m)]
							tally[b] = int(tally.get(b, 0)) + 1

					for b in tally:
						if int(tally[b]) >= 6 and biome_names.has(b) and str(biome_names[b]) != "ocean":
							var name: String = str(biome_names[b])

							if not by_biome.has(name):
								by_biome[name] = []

							by_biome[name].append(Vector2(x, z))

	if tiles_done == 0:
		print("world_alive: no baked tile in the range, nothing to measure")
		quit(0)
		return

	var targets: Array = _load_targets()
	var report: Array = []   # lines for the log: [biome, metric, value, verdict]
	var out_of_range: int = 0
	var checked: int = 0
	var names: Array = by_biome.keys()
	names.sort()
	print("world_alive: %d tiles, %d biomes with land, %d samples per biome, chunk %d m" % [tiles_done, names.size(), samples_per_biome, int(chunk_m)])
	var head: PackedStringArray = PackedStringArray()

	for l in LAYERS:
		head.append("%9s" % l)

	print("%-18s %6s | %s | animals per km2 (nominal)" % ["biome", "chunks", "  ".join(head)])

	for name in names:
		var spots: Array = by_biome[name]
		var take: int = mini(samples_per_biome, spots.size())
		var sums: Dictionary = {}

		for l in LAYERS:
			sums[l] = 0

		for n in range(take):
			var at: Vector2 = spots[int(floor(float(n) * float(spots.size()) / float(take)))]
			var found: Dictionary = placer.chunk_items(placer.chunk_of(at.x, at.y))

			for id in found["ids"]:
				var l: String = _layer(placer.species_of(id))
				sums[l] = int(sums[l]) + 1

		var per_ha: Dictionary = {}
		var line: PackedStringArray = PackedStringArray()

		for l in LAYERS:
			per_ha[l] = float(sums[l]) / (float(take) * ha)
			line.append("%9.1f" % per_ha[l])
			var verdict: String = _judge(targets, name, l + "_ha", per_ha[l])
			report.append([name, l + "_ha", per_ha[l], verdict])

			if verdict != "":
				checked += 1
				out_of_range += 0 if verdict == "ok" else 1

		# Nominal animals: target per player over the round, times the share of this biome's spots the species can stand on.
		var animal_parts: PackedStringArray = PackedStringArray()

		for sp in species:
			var def: Dictionary = species[sp]
			var target: float = float(def.get("target_per_player", 0))

			if target <= 0.0 or def.has("flock"):
				continue

			var hab: Dictionary = def.get("habitat", {})
			var run: float = float(hab.get("slope_run_m", 6.0))
			var ok: int = 0

			for n in range(take):
				var at2: Vector2 = spots[int(floor(float(n) * float(spots.size()) / float(take)))]
				var h: float = generator.surface_height(at2.x, at2.y)
				var steepest: float = 0.0

				for d in [Vector2(run, 0.0), Vector2(-run, 0.0), Vector2(0.0, run), Vector2(0.0, -run)]:
					steepest = maxf(steepest, absf(generator.surface_height(at2.x + d.x, at2.y + d.y) - h) / run)

				if steepest <= float(hab.get("slope_max", 0.6)) and h > 0.0:
					ok += 1

			var density: float = target / NEAR_KM2 * float(ok) / float(take)
			animal_parts.append("%s %.0f" % [sp, density])
			var verdict2: String = _judge(targets, name, sp + "_km2", density)
			report.append([name, sp + "_km2", density, verdict2])

			if verdict2 != "":
				checked += 1
				out_of_range += 0 if verdict2 == "ok" else 1

		print("%-18s %6d | %s | %s" % [name, spots.size(), "  ".join(line), ", ".join(animal_parts)])

		for r in report:
			if r[0] == name and (str(r[3]).begins_with("LOW") or str(r[3]).begins_with("HIGH")):
				print("    target %s %s = %.1f: %s" % [name, r[1], r[2], r[3]])

	var total: float = float(cells)
	var lake_pct: float = 100.0 * float(counts[2]) / total
	var river_pct: float = 100.0 * float(counts[3]) / total
	var ocean_pct: float = 100.0 * float(counts[1]) / total
	var fresh_land_pct: float = 100.0 * float(counts[2] + counts[3]) / maxf(float(land_cells), 1.0)
	var river_km: float = float(counts[3]) * cell_area_km2 * 1000.0 / RIVER_WIDTH_M
	print("water: ocean %.1f%%, lake %.2f%%, river %.2f%% of all cells; fresh water %.2f%% of land; river length about %.0f km (area / %.0f m width, estimate)" % [ocean_pct, lake_pct, river_pct, fresh_land_pct, river_km, RIVER_WIDTH_M])

	for pair in [["water_ocean_pct", ocean_pct], ["water_lake_pct", lake_pct], ["water_river_pct", river_pct], ["water_fresh_of_land_pct", fresh_land_pct], ["river_km", river_km]]:
		var verdict3: String = _judge(targets, "*", pair[0], pair[1])
		report.append(["*", pair[0], pair[1], verdict3])

		if verdict3 != "":
			checked += 1
			out_of_range += 0 if verdict3 == "ok" else 1

			if verdict3 != "ok":
				print("    target * %s = %.2f: %s" % [pair[0], pair[1], verdict3])

	var took: float = float(Time.get_ticks_msec() - begun) / 1000.0
	print("world_alive: %d of %d targeted figures out of range, %.0f s" % [out_of_range, checked, took])

	if write_log:
		_append_log(report, out_of_range, checked, tiles_done)

	quit(0)


func _append_log(report: Array, out_of_range: int, checked: int, tiles_done: int) -> void:
	var path: String = ProjectSettings.globalize_path("res://" + log_path)
	var text: String = FileAccess.get_file_as_string(path) if FileAccess.file_exists(path) else "# World-alive log\n\nOne block per run of `tools/world_alive.sh` (tools/world_alive.gd). Figures per hectare (flora) or per km2 (animals, nominal). Targets: TARGETS.md.\n"
	var stamp: String = Time.get_datetime_string_from_system(true).replace("T", " ")
	text += "\n### %s UTC, commit %s, %d tiles, %d of %d targeted figures out of range\n\n| biome | metric | value | target |\n|---|---|---|---|\n" % [stamp, str(OS.get_environment("WA_COMMIT")), tiles_done, out_of_range, checked]

	for r in report:
		text += "| %s | %s | %.2f | %s |\n" % [r[0], r[1], r[2], r[3]]

	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()
