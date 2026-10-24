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
	var lake_min_depth: float = float(rules.get("lake_min_depth_m", 0.5))
	var lake_min_catchment: float = float(rules.get("lake_min_catchment_km2", 0.05))
	var origin := Vector2i(water._origin_sx, water._origin_sz)
	var routing: PackedFloat32Array = _routing_heights(land, sea, samples, float(rules.get("routing_noise_m", 0.25)), int(rules.get("seed", 17)), origin)
	fill.build(routing, sea, samples, lake_min_depth)
	var runoff: PackedFloat32Array = PackedFloat32Array()
	runoff.resize(total)
	var unit: float = cell_m * cell_m * 1.0e-6   # discharge reads as catchment km2 until climate scales it

	for index in range(total):
		runoff[index] = 0.0 if sea[index] == 1 else unit

	var flow = FlowScript.new()
	flow.build(fill, runoff)
	var seeded_km2: float = _seed_frame_edge(water, fill, runoff, land, sea, samples, cell_m, unit, rules)

	if seeded_km2 > 0.0:
		flow.build(fill, runoff)
	var channels = ChannelsScript.new()
	channels.build(land, fill, flow, samples, cell_m, float(rules.get("river_start_km2", 0.5)), rules, int(rules.get("seed", 17)), Vector2i(water._origin_sx, water._origin_sz))
	_probe(water, fill, flow, channels, land, samples, cell_m, unit)
	water.heights = channels.bed
	water.flow = flow.discharge.duplicate()

	for index in range(total):
		water.flow[index] /= unit   # the tile stores drained cells, as encode_flow and the settler expect
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

		var outlet: int = int(lake["outlet"])
		var catchment: float = flow.discharge[outlet] if outlet >= 0 else 0.0

		# Dave 2026-10-23: any hollow that collects enough water holds it; only hollows with no catchment are filled in.
		if catchment >= lake_min_catchment:
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
		elif fill.filled[index] - routing[index] >= lake_min_depth:
			water.heights[index] += fill.filled[index] - routing[index]
			water.filled_cells += 1

	water._ocean = sea
	return {"ms": Time.get_ticks_msec() - begun, "lakes": fill.lakes.size(), "river_cells": water.river_cells}


# Flat ground drains in straight lines unless the routing surface wiggles a little: the ground plus a smooth noise of
# +-`amplitude_m` over about 100 m. Only the routing sees it; the ground itself is untouched.
static func _routing_heights(land: PackedFloat32Array, sea: PackedByteArray, samples: int, amplitude_m: float, seed_value: int, origin: Vector2i) -> PackedFloat32Array:
	var routed: PackedFloat32Array = land.duplicate()

	if amplitude_m <= 0.0:
		return routed

	# Knots are hashed from their WORLD position, so two tiles that share an edge draw the same noise along it.
	const CELL := 12

	for row in range(samples):
		var wz: int = origin.y + row
		var kz: int = floori(float(wz) / float(CELL))
		var tz: float = float(wz - kz * CELL) / float(CELL)

		for column in range(samples):
			var index: int = row * samples + column

			if sea[index] == 1:
				continue

			var wx: int = origin.x + column
			var kx: int = floori(float(wx) / float(CELL))
			var tx: float = float(wx - kx * CELL) / float(CELL)
			var top: float = lerpf(_knot(kx, kz, seed_value), _knot(kx + 1, kz, seed_value), tx)
			var bottom: float = lerpf(_knot(kx, kz + 1, seed_value), _knot(kx + 1, kz + 1, seed_value), tx)
			routed[index] += amplitude_m * lerpf(top, bottom, tz)

	return routed


static func _knot(kx: int, kz: int, seed_value: int) -> float:
	var x: int = (kx * 73856093) ^ (kz * 83492791) ^ (seed_value * 19349663)
	x = (x ^ (x >> 13)) * 1274126177
	return float((x ^ (x >> 16)) & 0xFFFF) / 65535.0 * 2.0 - 1.0


# A frame only holds the catchment inside it, so a river that comes in from beyond the frame edge loses its upstream
# and its channel can stop short of the tile seam while the neighbour (whose frame holds the river) carries on. The world
# river network knows every catchment, so each place it flows into this frame adds its catchment to the lowest dry
# ground at that spot on the frame edge. It depends only on world coordinates and the network, so tiles agree.
# Returns the catchment added (km2).
static func _seed_frame_edge(water, fill, runoff: PackedFloat32Array, land: PackedFloat32Array, sea: PackedByteArray, samples: int, cell_m: float, unit: float, rules: Dictionary) -> float:
	var network = water.world_network

	if network == null or not bool(rules.get("edge_inflow", true)):
		return 0.0

	var scale: float = float(rules.get("edge_inflow_scale", 1.0))
	var depth: int = int(rules.get("edge_inflow_depth_cells", 3))
	var reach: int = int(rules.get("edge_inflow_reach_cells", 12))
	var origin: Vector2 = Vector2(float(water._origin_sx), float(water._origin_sz)) * cell_m
	var rect: Rect2 = Rect2(origin, Vector2(float(samples), float(samples)) * cell_m)
	var added: float = 0.0

	for entry in network.inflows_into(rect):
		var from_m: Vector2 = entry["from"]
		var to_m: Vector2 = entry["to"]
		var at: Vector2 = to_m

		for step in range(51):
			var probe: Vector2 = from_m.lerp(to_m, float(step) / 50.0)

			if rect.has_point(probe):
				at = probe
				break

		var column: int = clampi(int(floor((at.x - origin.x) / cell_m)), 0, samples - 1)
		var row: int = clampi(int(floor((at.y - origin.y) / cell_m)), 0, samples - 1)
		var best: int = -1
		var best_height: float = INF

		for dz in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var c: int = column + dx
				var r: int = row + dz

				if c < 0 or r < 0 or c >= samples or r >= samples:
					continue

				if mini(mini(c, r), mini(samples - 1 - c, samples - 1 - r)) > depth:
					continue

				var index: int = r * samples + c

				if sea[index] == 1 or fill.lake_id[index] != 0:
					continue

				if land[index] < best_height:
					best_height = land[index]
					best = index

		if best >= 0:
			var amount: float = float(entry["km2"]) * scale
			runoff[best] += amount
			added += amount

	return added


# Debug only: DRAINAGE_PROBE="x_m,z_m" (world metres) prints the cells round that spot, for finding why two tiles disagree.
static func _probe(water, fill, flow, channels, land: PackedFloat32Array, samples: int, cell_m: float, unit: float) -> void:
	if not OS.has_environment("DRAINAGE_PROBE"):
		return

	var parts: PackedStringArray = OS.get_environment("DRAINAGE_PROBE").split(",")
	var column: int = int(floor(float(parts[0]) / cell_m)) - water._origin_sx
	var row: int = int(floor(float(parts[1]) / cell_m)) - water._origin_sz

	if column < 8 or row < 8 or column >= samples - 8 or row >= samples - 8:
		return

	print("PROBE frame origin ", water._origin_sx, ",", water._origin_sz, " cell ", column, ",", row)

	for r in range(row - 8, row + 9):
		var line: String = "PROBE r%+d" % (r - row)

		for c in range(column - 8, column + 9):
			var index: int = r * samples + c
			var k: float = flow.discharge[index] / unit
			var arrow: String = "."
			var next: int = fill.receiver[index]

			if next >= 0:
				var dx: int = next % samples - c
				@warning_ignore("integer_division")
				var dz: int = next / samples - r
				arrow = "E" if dx > 0 and dz == 0 else ("W" if dx < 0 and dz == 0 else ("S" if dz > 0 and dx == 0 else ("N" if dz < 0 and dx == 0 else "d")))

			line += " %5.0f%s%s%s" % [k, arrow, "L" if fill.lake_id[index] != 0 else "-", "c" if not is_nan(channels.surface[index]) else "-"]

		print(line)

	var heights_line: String = "PROBE heights land/bed centre row:"

	for c in range(column - 8, column + 9):
		var index: int = row * samples + c
		heights_line += " %.1f/%.1f" % [land[index], channels.bed[index]]

	print(heights_line)
