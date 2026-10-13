extends SceneTree

# Estimates how much land is fit for bases and towns, from the world
# elevation map. Run with:
#
#   godot --headless --path . --script res://src/worldgen/tools/analyze_land.gd
#
# Writes <world>/plan/buildable_land.png and buildable_summary.txt.
#
# The elevation map is coarse (160 m cells), so it smooths away small
# bumps and cliffs. Real tiles will be rougher, so treat these numbers
# as an upper estimate.

const WorldSettingsScript := preload("res://src/worldgen/settings/world_settings.gd")
const SketchScript := preload("res://src/worldgen/sketch/world_sketch.gd")
const ElevationScript := preload("res://src/worldgen/sketch/world_elevation.gd")
const CensusScript := preload("res://src/worldgen/sketch/island_census.gd")
const ReliefScript := preload("res://src/worldgen/sketch/relief_preview.gd")

# Slope limits (rise over run). 0.08 is about 4.5 degrees, 0.18 about 10.
const TOWN_SLOPE := 0.08
const BASE_SLOPE := 0.18
const MAX_BUILD_HEIGHT := 800.0
const TOWN_MIN_KM2 := 2.0          # flat, connected ground for a town core
const BASE_MIN_KM2 := 0.1          # room for a homestead or base
const COAST_REACH_CELLS := 6       # about 1 km: town ground near the sea


func _init() -> void:
	quit(_run("res://worlds/base_world"))


func _run(world_dir: String) -> int:
	var errors: Array = []
	var settings = WorldSettingsScript.load_from_file(world_dir + "/world.json", errors)
	var rules: Dictionary = SketchScript.load_rules(world_dir + "/plan/sketch_rules.json", errors)
	var sketch: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(world_dir + "/plan/world_sketch.json")
	)

	if settings == null or rules.is_empty() or typeof(sketch) != TYPE_DICTIONARY:
		push_error("Could not load the world: %s" % str(errors))
		return 1

	var elevation = ElevationScript.new()
	elevation.build(settings, rules, sketch)
	var census: Dictionary = CensusScript.count(elevation)
	var islands: Array = census["islands"]
	var label: PackedInt32Array = census["label"]
	var cell: float = elevation.cell_m
	var cell_km2: float = pow(cell / 1000.0, 2.0)
	var count: int = elevation.heights.size()

	# 0 = sea, 1 = too steep, high, hot or lava, 2 = base ground, 3 = town ground
	var grade: PackedByteArray = PackedByteArray()
	grade.resize(count)

	for index in range(count):
		var h: float = elevation.heights[index]

		if h <= 0.0:
			grade[index] = 0
			continue

		var column: int = index % elevation.size_x
		var row: int = index / elevation.size_x
		var dx: float = (
			elevation.heights[elevation.index_of(column + 1, row)]
			- elevation.heights[elevation.index_of(column - 1, row)]
		) / (2.0 * cell)
		var dz: float = (
			elevation.heights[elevation.index_of(column, row + 1)]
			- elevation.heights[elevation.index_of(column, row - 1)]
		) / (2.0 * cell)
		var slope: float = sqrt(dx * dx + dz * dz)

		if elevation.special[index] != 0 or h > MAX_BUILD_HEIGHT:
			grade[index] = 1
		elif slope <= TOWN_SLOPE:
			grade[index] = 3
		elif slope <= BASE_SLOPE:
			grade[index] = 2
		else:
			grade[index] = 1

	# Flat patches: connected town-grade ground, and connected buildable ground.
	var town_patches: Dictionary = _patches(elevation, grade, 3)
	var base_patches: Dictionary = _patches(elevation, grade, 2)

	# Per island: largest town patch (near the coast) and total buildable land.
	var per_island: Array = []

	for island in islands:
		per_island.append({
			"town_km2": 0.0, "base_km2": 0.0, "build_km2": 0.0, "coastal_town": false,
		})

	for patch in town_patches["patches"]:
		var number: int = label[int(patch["first"])]
		var area: float = float(patch["cells"]) * cell_km2

		if area >= TOWN_MIN_KM2 and bool(patch["coastal"]):
			per_island[number]["coastal_town"] = true

		per_island[number]["town_km2"] = maxf(float(per_island[number]["town_km2"]), area)

	for patch in base_patches["patches"]:
		var number: int = label[int(patch["first"])]
		var area: float = float(patch["cells"]) * cell_km2
		per_island[number]["base_km2"] = maxf(float(per_island[number]["base_km2"]), area)
		per_island[number]["build_km2"] = float(per_island[number]["build_km2"]) + area

	# Summaries by danger tier and climate zone.
	var lines: PackedStringArray = PackedStringArray()
	var totals: Dictionary = {"land": 0.0, "build": 0.0, "town_islands": 0, "base_islands": 0}
	var by_tier: Dictionary = {}
	var by_zone: Dictionary = {}

	for number in range(islands.size()):
		var island: Dictionary = islands[number]
		var info: Dictionary = per_island[number]
		var peak_index: int = int(island["peak_index"])
		var position: Vector2 = elevation.cell_center_m(
			peak_index % elevation.size_x, peak_index / elevation.size_x
		)
		var tier: String = settings.danger_tier(settings.danger_at(position.x, position.y))
		var tile_z: int = int(floor(position.y / float(settings.tile_size_m)))
		var zone: String = settings.get_zone_id_for_row(tile_z)
		var town_ok: bool = bool(info["coastal_town"])
		var base_ok: bool = float(info["base_km2"]) >= BASE_MIN_KM2

		totals["land"] = float(totals["land"]) + float(island["area_km2"])
		totals["build"] = float(totals["build"]) + float(info["build_km2"])
		totals["town_islands"] = int(totals["town_islands"]) + (1 if town_ok else 0)
		totals["base_islands"] = int(totals["base_islands"]) + (1 if base_ok else 0)

		for pair in [[by_tier, tier], [by_zone, zone]]:
			var table: Dictionary = pair[0]
			var key: String = pair[1]

			if not table.has(key):
				table[key] = {"islands": 0, "land": 0.0, "build": 0.0, "town": 0, "base": 0}

			table[key]["islands"] = int(table[key]["islands"]) + 1
			table[key]["land"] = float(table[key]["land"]) + float(island["area_km2"])
			table[key]["build"] = float(table[key]["build"]) + float(info["build_km2"])
			table[key]["town"] = int(table[key]["town"]) + (1 if town_ok else 0)
			table[key]["base"] = int(table[key]["base"]) + (1 if base_ok else 0)

	lines.append("BUILDABLE LAND (from the 160 m world map; an upper estimate)")
	lines.append(
		"Town ground: slope under %.0f%%, below %d m, flat patch of %.0f km2 or more within about 1 km of the sea."
		% [TOWN_SLOPE * 100.0, int(MAX_BUILD_HEIGHT), TOWN_MIN_KM2]
	)
	lines.append(
		"Base ground: slope under %.0f%%, below %d m, patch of %.1f km2 or more."
		% [BASE_SLOPE * 100.0, int(MAX_BUILD_HEIGHT), BASE_MIN_KM2]
	)
	lines.append("")
	lines.append("Islands: %d   land: %.0f km2   buildable: %.0f km2 (%.0f%% of land)" % [
		islands.size(), float(totals["land"]), float(totals["build"]),
		float(totals["build"]) / maxf(float(totals["land"]), 1.0) * 100.0
	])
	lines.append("Islands with room for a town: %d" % int(totals["town_islands"]))
	lines.append("Islands with room for a base: %d" % int(totals["base_islands"]))
	lines.append("")

	for pair in [["DANGER TIER", by_tier, ["easy", "moderate", "medium", "hard", "deadly"]],
			["CLIMATE ZONE", by_zone, settings.get_zone_ids()]]:
		lines.append("BY %s" % pair[0])
		lines.append("%-18s %8s %9s %10s %7s %7s" % ["", "islands", "land km2", "build km2", "towns", "bases"])

		for key in pair[2]:
			var row: Dictionary = pair[1].get(key, {"islands": 0, "land": 0.0, "build": 0.0, "town": 0, "base": 0})
			lines.append("%-18s %8d %9.0f %10.0f %7d %7d" % [
				key, int(row["islands"]), float(row["land"]), float(row["build"]),
				int(row["town"]), int(row["base"])
			])

		lines.append("")

	lines.append("LARGEST TOWN SITES (biggest flat coastal patch per island)")
	var ranked: Array = []

	for number in range(islands.size()):
		if bool(per_island[number]["coastal_town"]):
			ranked.append(number)

	ranked.sort_custom(func(a: int, b: int) -> bool:
		return float(per_island[a]["town_km2"]) > float(per_island[b]["town_km2"])
	)

	for position_index in range(mini(15, ranked.size())):
		var number: int = ranked[position_index]
		var peak_index: int = int(islands[number]["peak_index"])
		var position: Vector2 = elevation.cell_center_m(
			peak_index % elevation.size_x, peak_index / elevation.size_x
		)
		var tile: Vector2i = Vector2i(
			int(floor(position.x / float(settings.tile_size_m))),
			int(floor(position.y / float(settings.tile_size_m)))
		)
		lines.append("  tile (%3d,%3d)  island %6.1f km2  flat town ground %5.1f km2  buildable %5.1f km2  %s" % [
			tile.x, tile.y, float(islands[number]["area_km2"]),
			float(per_island[number]["town_km2"]), float(per_island[number]["build_km2"]),
			settings.danger_tier(settings.danger_at(position.x, position.y))
		])

	var text: String = "\n".join(lines) + "\n"
	var file: FileAccess = FileAccess.open(world_dir + "/plan/buildable_summary.txt", FileAccess.WRITE)
	file.store_string(text)
	file.close()
	print(text)

	_save_overlay(settings, elevation, grade, town_patches, world_dir + "/plan/buildable_land.png")
	return 0


# Connected patches of cells with grade >= minimum_grade.
func _patches(elevation, grade: PackedByteArray, minimum_grade: int) -> Dictionary:
	var count: int = grade.size()
	var seen: PackedByteArray = PackedByteArray()
	seen.resize(count)
	var patch_of: PackedInt32Array = PackedInt32Array()
	patch_of.resize(count)
	patch_of.fill(-1)
	var patches: Array = []
	var stack: PackedInt32Array = PackedInt32Array()

	for start in range(count):
		if seen[start] == 1 or grade[start] < minimum_grade:
			continue

		var cells: int = 0
		var coastal: bool = false
		var number: int = patches.size()
		seen[start] = 1
		stack.append(start)

		while not stack.is_empty():
			var index: int = stack[stack.size() - 1]
			stack.remove_at(stack.size() - 1)
			cells += 1
			patch_of[index] = number
			var column: int = index % elevation.size_x
			var row: int = index / elevation.size_x

			if not coastal:
				for step in [COAST_REACH_CELLS, -COAST_REACH_CELLS]:
					if (
						elevation.heights[elevation.index_of(column + step, row)] <= 0.0
						or elevation.heights[elevation.index_of(column, row + step)] <= 0.0
					):
						coastal = true

			for neighbor in [
				elevation.index_of(column + 1, row), elevation.index_of(column - 1, row),
				elevation.index_of(column, row + 1), elevation.index_of(column, row - 1),
			]:
				if seen[neighbor] == 0 and grade[neighbor] >= minimum_grade:
					seen[neighbor] = 1
					stack.append(neighbor)

		patches.append({"first": start, "cells": cells, "coastal": coastal})

	return {"patches": patches, "patch_of": patch_of}


# The relief map with buildable ground painted over the land:
# bright green = town ground in a patch big enough for a town,
# pale green = other flat ground, yellow = base ground, land left as
# relief = too steep, too high or lava.
func _save_overlay(settings, elevation, grade: PackedByteArray, town_patches: Dictionary, path: String) -> void:
	var image: Image = ReliefScript.render(settings, elevation, true)
	var patch_of: PackedInt32Array = town_patches["patch_of"]
	var patches: Array = town_patches["patches"]
	var cell_km2: float = pow(elevation.cell_m / 1000.0, 2.0)

	for index in range(grade.size()):
		var column: int = index % elevation.size_x
		var row: int = index / elevation.size_x
		var current: Color = image.get_pixel(column, row)

		if grade[index] == 3:
			var patch: int = patch_of[index]
			var big: bool = (
				patch >= 0
				and float(patches[patch]["cells"]) * cell_km2 >= TOWN_MIN_KM2
				and bool(patches[patch]["coastal"])
			)
			image.set_pixel(column, row, current.lerp(
				Color(0.1, 0.95, 0.2) if big else Color(0.65, 0.9, 0.55), 0.75
			))
		elif grade[index] == 2:
			image.set_pixel(column, row, current.lerp(Color(1.0, 0.85, 0.2), 0.7))

	image.save_png(path)
