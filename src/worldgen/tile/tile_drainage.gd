class_name TileDrainage
extends RefCounted

# Option B wiring (tech/TERRAIN_B_DESIGN.md): fill TileWater's arrays from the land's own drainage instead of
# the world's drawn river guides. Switched by tile_rules.json water.drainage_mode (default off).
# Order: sea -> DrainageFill (lakes, outlets) -> DrainageFlow (runoff) -> DrainageChannels (valleys) -> classes.

const FillScript := preload("res://src/worldgen/tile/drainage_fill.gd")
const FlowScript := preload("res://src/worldgen/tile/drainage_flow.gd")
const ChannelsScript := preload("res://src/worldgen/tile/drainage_channels.gd")
const NaturalScript := preload("res://src/worldgen/tile/drainage_natural.gd")


# `water` is the TileWater being built (heights loaded, arrays sized). Returns a summary for the log.
static func apply(water, rules: Dictionary) -> Dictionary:
	var samples: int = water.samples
	var total: int = samples * samples
	var cell_m: float = water.spacing_m
	var sea: PackedByteArray = water._find_ocean()
	var land: PackedFloat32Array = water.heights.duplicate()
	var begun: int = Time.get_ticks_msec()
	var clock: int = begun
	var fill = FillScript.new()
	var lake_min_depth: float = float(rules.get("lake_min_depth_m", 0.5))
	var lake_min_catchment: float = float(rules.get("lake_min_catchment_km2", 0.05))
	var origin := Vector2i(water._origin_sx, water._origin_sz)
	# Water is routed over the ground as it was before erosion: erosion only runs inside each tile, so beyond 640 m from a seam
	# the two tiles' eroded ground differs and so would their lakes and divides. The raw ground is the same in every frame.
	var route_over: PackedFloat32Array = land

	if bool(rules.get("route_over_raw", true)) and water.routing_raw.size() == land.size():
		route_over = water.routing_raw

	var routing: PackedFloat32Array = _routing_heights(route_over, sea, samples, float(rules.get("routing_noise_m", 0.25)), int(rules.get("seed", 17)), origin)
	_lap("routing noise", clock)
	clock = Time.get_ticks_msec()
	fill.build(routing, sea, samples, lake_min_depth)
	_lap("fill", clock)
	clock = Time.get_ticks_msec()
	var runoff: PackedFloat32Array = PackedFloat32Array()
	runoff.resize(total)
	var unit: float = cell_m * cell_m * 1.0e-6   # discharge reads as catchment km2 until climate scales it

	for index in range(total):
		runoff[index] = 0.0 if sea[index] == 1 else unit

	var flow = FlowScript.new()
	flow.build(fill, runoff)
	var seeded_km2: float = _seed_frame_edge(water, fill, runoff, land, sea, samples, cell_m, rules)

	if seeded_km2 > 0.0:
		flow.build(fill, runoff)
	_lap("flow + edge seed", clock)
	clock = Time.get_ticks_msec()
	var channels

	if bool(rules.get("natural", {}).get("enabled", false)):
		# Natural rivers: the rivers are the drainage's own lines, bent and carved by flow (drainage_natural.gd); no ponds, craters or rule-made lakes.
		channels = NaturalScript.new()
		channels.build(land, fill, flow, samples, cell_m, float(rules.get("river_start_km2", 0.5)), sea, rules, int(rules.get("seed", 17)), Vector2i(water._origin_sx, water._origin_sz))
		print("  natural rivers: %d reaches, %d bent, longest %.0f m, mean sinuosity %.3f" % [
			channels.reaches_made, channels.reaches_bent, channels.longest_reach_m, channels.sinuosity_sum / maxf(float(channels.sinuosity_count), 1.0)
		])
		_lap("natural rivers", clock)
		clock = Time.get_ticks_msec()
	else:
		channels = ChannelsScript.new()
		channels.build(land, fill, flow, samples, cell_m, float(rules.get("river_start_km2", 0.5)), rules, int(rules.get("seed", 17)), Vector2i(water._origin_sx, water._origin_sz))
		_lap("channels", clock)
		clock = Time.get_ticks_msec()
		_probe(water, fill, flow, channels, land, samples, cell_m, unit)
		_breach_outlets(water, fill, flow, channels, land, sea, samples, lake_min_catchment, rules)
		_lap("probe + breach", clock)

	water.heights = channels.bed
	water.flow = flow.discharge.duplicate()

	for index in range(total):
		water.flow[index] /= unit   # the tile stores drained cells, as encode_flow and the settler expect
	water.river_cells = 0
	water.filled_cells = 0
	water.lakes = []
	var min_water_m: float = float(rules.get("water_min_depth_m", 0.05))
	var basin_lake_cells: int = 0

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

			# Water standing in a carved pond or lake bowl, deeper than lake_min_depth_m, is a lake, not a river.
			if channels.basin_mask[index] == 1 and level - channels.bed[index] >= float(rules.get("lake_min_depth_m", 0.5)):
				water.water_class[index] = water.LAKE
				basin_lake_cells += 1

	print("  basin water: %d cells tagged lake (%.1f ha)" % [basin_lake_cells, basin_lake_cells * cell_m * cell_m / 10000.0])

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


# Timing line for the bake log (measured stage seconds, tech/GENERATOR_SPEEDUP_REVIEW_25OCT.md).
static func _lap(stage: String, since_ms: int) -> void:
	print("  drain timing: %s %d ms" % [stage, Time.get_ticks_msec() - since_ms])


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
static func _seed_frame_edge(water, fill, runoff: PackedFloat32Array, land: PackedFloat32Array, sea: PackedByteArray, samples: int, cell_m: float, rules: Dictionary) -> float:
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

	# Walk upstream along the biggest donor and print every 10th cell (world metres, discharge in cells), so two tiles can be
	# compared to find where their catchments first differ.
	var at: int = row * samples + column

	# Start from the biggest stream cell in the window (the probe spot itself is often just bank).
	for r in range(row - 8, row + 9):
		for c in range(column - 8, column + 9):
			if flow.discharge[r * samples + c] > flow.discharge[at]:
				at = r * samples + c

	@warning_ignore("integer_division")
	print("PROBE up start world %d,%d Q %.0f" % [(at % samples + water._origin_sx) * int(cell_m), (at / samples + water._origin_sz) * int(cell_m), flow.discharge[at] / unit])
	var received: PackedInt32Array = PackedInt32Array()
	received.resize(samples * samples)
	received.fill(-1)

	for cell in range(samples * samples):
		var down: int = fill.receiver[cell]

		if down >= 0 and (received[down] < 0 or flow.discharge[cell] > flow.discharge[received[down]]):
			received[down] = cell

	for step in range(600):
		if received[at] < 0:
			break

		at = received[at]

		if step % 10 == 0:
			@warning_ignore("integer_division")
			print("PROBE up %d world %d,%d Q %.0f%s" % [step, (at % samples + water._origin_sx) * int(cell_m), (at / samples + water._origin_sz) * int(cell_m), flow.discharge[at] / unit, " L" if fill.lake_id[at] != 0 else ""])

	# And downstream from the same start cell to the sea, every 10th cell: world metres, discharge, channel/lake flags, ground, bed.
	var down_at: int = row * samples + column

	for r in range(row - 8, row + 9):
		for c in range(column - 8, column + 9):
			if flow.discharge[r * samples + c] > flow.discharge[down_at]:
				down_at = r * samples + c

	for step in range(900):
		var next_cell: int = fill.receiver[down_at]

		if step % 10 == 0 or next_cell < 0:
			@warning_ignore("integer_division")
			print("PROBE down %d world %d,%d Q %.0f%s%s land %.1f bed %.1f%s" % [step, (down_at % samples + water._origin_sx) * int(cell_m), (down_at / samples + water._origin_sz) * int(cell_m), flow.discharge[down_at] / unit, " c" if not is_nan(channels.surface[down_at]) else "", " L" if fill.lake_id[down_at] != 0 else "", land[down_at], channels.bed[down_at], " END" if next_cell < 0 else ""])

		if next_cell < 0:
			break

		down_at = next_cell

	var heights_line: String = "PROBE heights land/bed centre row:"

	for c in range(column - 8, column + 9):
		var index: int = row * samples + c
		heights_line += " %.1f/%.1f" % [land[index], channels.bed[index]]

	print(heights_line)


# Every lake that holds water leaves by a channel. The lake's level and outlet come from the routing ground, which can differ
# from the real ground (erosion, scree, ledges), so the outlet path may cross a crest higher than the water. Walk the outlet
# path downstream and cut a channel whose bed falls from just under the lake level at `breach_fall_per_cell` until the real
# ground is below it, three cells wide. Water then has a way out and the painted outlet is a river, not a dry ridge.
static func _breach_outlets(water, fill, flow, channels, land: PackedFloat32Array, sea: PackedByteArray, samples: int, lake_min_catchment: float, rules: Dictionary) -> void:
	var drop: float = float(rules.get("breach_drop_m", 0.3))
	var fall: float = float(rules.get("breach_fall_per_cell", 0.04))
	var depth_m: float = float(rules.get("breach_water_m", 0.5))
	var longest: int = int(rules.get("breach_max_cells", 80))

	if fall < 0.0 or longest <= 0:
		return

	var breached: int = 0
	var cells_cut: int = 0
	var deepest_cut: float = 0.0
	var verbose: bool = OS.has_environment("DRAINAGE_BREACH_LOG")

	for lake in fill.lakes:
		var at: int = int(lake["outlet"])

		if at < 0 or flow.discharge[at] < lake_min_catchment:
			continue

		var level: float = float(lake["level"])
		var first: int = at
		var cut: Dictionary = _cut_outlet_path(at, level, fill, channels, land, sea, samples, drop, fall, depth_m, longest, 0.0, float(rules.get("breach_max_cut_m", 20.0)))
		var lowered: float = float(cut["lowered"])
		var length: int = int(cut["length"])
		cells_cut += int(cut["cells"])

		breached += 1
		deepest_cut = maxf(deepest_cut, lowered)

		if verbose:
			@warning_ignore("integer_division")
			print("  breach: lake level %.1f m, outlet world %d,%d, %d cells, deepest cut %.1f m" % [level, (first % samples + water._origin_sx) * 8, (first / samples + water._origin_sz) * 8, length, lowered])

	print("  breach: %d lakes, %d cells cut, deepest cut %.1f m" % [breached, cells_cut, deepest_cut])

	# Hollows in the real ground that the routing never saw as lakes (erosion and valley carving made them): a river-fed pit
	# with no lower side. Dave: ponds are never placed, so cut a way out along the routing path, below the pit floor.
	var pits: int = 0
	var pit_cells: int = 0
	var pit_cut: float = 0.0
	var pit_min_rim: float = float(rules.get("pit_min_rim_m", 2.0))
	var pit_max_cut: float = float(rules.get("pit_max_cut_m", 8.0))
	var pits_skipped: int = 0
	var pits_kept: int = 0
	var pit_keep_rim: float = float(rules.get("pit_keep_rim_m", 1.5))
	var kept: PackedByteArray = PackedByteArray()
	kept.resize(samples * samples)

	# The wide ring first: a hollow 96 m across with a rim of pit_keep_rim_m or more is a real basin (Dave 24 Oct: lakes and
	# ponds should be sizable). It stays, with its outlet cut at the lip (rim - 0.3 m) so it spills over a notch. Smaller pits drain.
	for ring: int in [6, 3]:
		for row in range(ring, samples - ring):
			for column in range(ring, samples - ring):
				var index: int = row * samples + column

				if sea[index] == 1 or fill.lake_id[index] > 0 or flow.discharge[index] < lake_min_catchment or channels.basin_mask[index] == 1 or kept[index] == 1:
					continue

				var floor_m: float = channels.bed[index]

				# Underwater hollows (sea floor, ocean basins) are not pits to drain.
				if floor_m < 1.0 or land[index] < 1.0:
					continue
				var rim: float = INF
				var is_pit: bool = true

				for dz in range(-ring, ring + 1, ring):
					for dc in range(-ring, ring + 1, ring):
						if dz == 0 and dc == 0:
							continue

						var around: int = (row + dz) * samples + column + dc
						rim = minf(rim, channels.bed[around])

						if sea[around] == 1 or channels.bed[around] < floor_m + 0.02:
							is_pit = false

				if not is_pit or rim - floor_m < pit_min_rim:
					continue

				var keep: bool = ring == 6 and rim - floor_m >= pit_keep_rim
				var pit_cut_result: Dictionary = _cut_outlet_path(index, rim - 1.0 if keep else floor_m, fill, channels, land, sea, samples, drop, fall, depth_m, longest, pit_max_cut, pit_max_cut)
				if pit_cut_result.has("skipped"):
					pits_skipped += 1
					continue

				if keep:
					pits_kept += 1

					for kz in range(maxi(row - 8, 0), mini(row + 9, samples)):
						for kc in range(maxi(column - 8, 0), mini(column + 9, samples)):
							kept[kz * samples + kc] = 1
				else:
					pits += 1

				pit_cells += int(pit_cut_result["cells"])
				pit_cut = maxf(pit_cut, float(pit_cut_result["lowered"]))

				if verbose:
					print("  pit: floor %.1f m rim %.1f m at world %d,%d, %d cells, deepest cut %.1f m" % [floor_m, rim, (column + water._origin_sx) * 8, (row + water._origin_sz) * 8, int(pit_cut_result["cells"]), float(pit_cut_result["lowered"])])

	print("  pits: %d drained, %d kept as basins (outlet cut at the lip), %d left (cut too deep), %d cells cut, deepest cut %.1f m" % [pits, pits_kept, pits_skipped, pit_cells, pit_cut])


# Walks the routing receivers downstream from `at` and cuts a three-cell-wide channel whose bed starts just under `level`
# and falls `fall` per cell until the real ground is lower than the channel or the sea is reached.
static func _cut_outlet_path(at: int, level: float, fill, channels, land: PackedFloat32Array, sea: PackedByteArray, samples: int, drop: float, fall: float, depth_m: float, longest: int, skip_over_m: float = -1.0, max_cut_m: float = -1.0) -> Dictionary:
	# A path that would need a cut deeper than skip_over_m is left alone (no gorge across a mountain for a small pit).
	if skip_over_m > 0.0:
		var probe_at: int = at
		var needed: float = 0.0

		for step in range(longest):
			if sea[probe_at] == 1:
				break

			var probe_target: float = level - drop - fall * float(step)

			if land[probe_at] < probe_target - 0.5 and step > 0:
				break

			needed = maxf(needed, channels.bed[probe_at] - probe_target)
			var probe_next: int = fill.receiver[probe_at]

			if probe_next < 0:
				break

			probe_at = probe_next

		if needed > skip_over_m:
			return {"lowered": 0.0, "length": 0, "cells": 0, "skipped": true}

	var lowered: float = 0.0
	var length: int = 0
	var cells_cut: int = 0

	for step in range(longest):
		if sea[at] == 1:
			break

		var target: float = level - drop - fall * float(step)

		if land[at] < target - 0.5 and step > 0:
			break

		@warning_ignore("integer_division")
		var row: int = at / samples
		var column: int = at % samples

		for dz in range(-1, 2):
			for dc in range(-1, 2):
				var r: int = row + dz
				var c: int = column + dc

				if r < 0 or c < 0 or r >= samples or c >= samples:
					continue

				var neighbor: int = r * samples + c
				var wanted: float = target + (0.0 if dz == 0 and dc == 0 else 0.4)

				# Hard cap: no single cell is ever lowered by more than max_cut_m.
				if max_cut_m > 0.0:
					wanted = maxf(wanted, channels.bed[neighbor] - max_cut_m)

				if channels.bed[neighbor] > wanted:
					lowered = maxf(lowered, channels.bed[neighbor] - wanted)
					channels.bed[neighbor] = wanted
					cells_cut += 1

				var surface: float = wanted + depth_m

				if is_nan(channels.surface[neighbor]) or channels.surface[neighbor] < surface:
					channels.surface[neighbor] = surface

		length += 1
		var next: int = fill.receiver[at]

		if next < 0:
			break

		at = next

	return {"lowered": lowered, "length": length, "cells": cells_cut}
