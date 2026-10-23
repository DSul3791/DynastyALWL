class_name TileDrainage
extends RefCounted

# Option B wiring (tech/TERRAIN_B_DESIGN.md): fill TileWater's arrays from the land's own drainage instead of
# the world's drawn river guides. Switched by tile_rules.json water.drainage_mode (default off).
# Order: sea -> DrainageFill (lakes, outlets) -> DrainageFlow (runoff) -> DrainageChannels (valleys) -> classes.

const FillScript := preload("res://src/worldgen/tile/drainage_fill.gd")
const FlowScript := preload("res://src/worldgen/tile/drainage_flow.gd")
const ChannelsScript := preload("res://src/worldgen/tile/drainage_channels.gd")


# `water` is the TileWater being built (heights loaded, arrays sized). Returns a summary for the log.
static func apply(water, rules: Dictionary) -> Dictionary:
	var samples: int = water.samples
	var total: int = samples * samples
	var cell_m: float = water.spacing_m
	var sea: PackedByteArray = water._find_ocean()
	var land: PackedFloat32Array = water.heights.duplicate()
	var begun: int = Time.get_ticks_msec()
	var fill = FillScript.new()
	fill.build(land, sea, samples, 1.0)
	var lake_min_depth: float = float(rules.get("lake_min_depth_m", 3.0))
	var lake_min_cells: int = int(rules.get("lake_min_cells", 40))
	var runoff: PackedFloat32Array = PackedFloat32Array()
	runoff.resize(total)
	var unit: float = cell_m * cell_m * 1.0e-6   # discharge reads as catchment km2 until climate scales it

	for index in range(total):
		runoff[index] = 0.0 if sea[index] == 1 else unit

	var flow = FlowScript.new()
	flow.build(fill, runoff)
	var channels = ChannelsScript.new()
	channels.build(land, fill, flow, samples, cell_m, float(rules.get("river_start_km2", 0.5)), rules, int(rules.get("seed", 17)))
	water.heights = channels.bed
	water.flow = flow.discharge
	water.river_cells = 0
	water.filled_cells = 0
	water.lakes = []
	var min_water_m: float = float(rules.get("water_min_depth_m", 0.05))

	for index in range(total):
		if sea[index] == 1:
			water.water_class[index] = water.OCEAN
			water.water_surface[index] = 0.0
			continue

		var level: float = channels.surface[index]

		if not is_nan(level) and level - channels.bed[index] > min_water_m:
			water.water_class[index] = water.RIVER
			water.water_surface[index] = level
			water.river_cells += 1

	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(fill.lakes.size() + 1)

	for index in range(total):
		var id: int = fill.lake_id[index]

		if id > 0:
			counts[id] += 1

	var keep: PackedByteArray = PackedByteArray()
	keep.resize(fill.lakes.size() + 1)

	for lake_index in range(fill.lakes.size()):
		var lake: Dictionary = fill.lakes[lake_index]
		var count: int = counts[lake_index + 1]

		if float(lake["depth"]) >= lake_min_depth and count >= lake_min_cells:
			keep[lake_index + 1] = 1
			water.lakes.append({
				"cells": count, "area_m2": float(count) * cell_m * cell_m,
				"surface_m": lake["level"], "depth_m": lake["depth"], "members": PackedInt32Array(),
			})

	# Small hollows are filled in (as before); real lakes hold water at their level.
	for index in range(total):
		if sea[index] == 1 or water.water_class[index] == water.RIVER:
			continue

		var id: int = fill.lake_id[index]

		if id > 0 and keep[id] == 1:
			water.water_class[index] = water.LAKE
			water.water_surface[index] = fill.lakes[id - 1]["level"]
		elif fill.filled[index] > water.heights[index]:
			water.heights[index] = fill.filled[index]
			water.filled_cells += 1

	water._ocean = sea
	return {"ms": Time.get_ticks_msec() - begun, "lakes": fill.lakes.size(), "river_cells": water.river_cells}
