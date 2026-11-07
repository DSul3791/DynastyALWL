extends RefCounted

# Rolling ground for the low land: the swells and knolls a player walks over (about 30 m to 300 m across).
# Since 7 Nov 2026 (P1) added BEFORE the water, faded out near the sea and near the land's own valley lines
# (valley_lines), so the rivers routed afterwards keep the low line of their valleys. Before P1 the bumps came
# after the water and faded near it (see GENERATOR_NOTES.md). Away from water the bumps are strongest; the beach stays calm; high ground is left to
# the normal detail noise. Everything is a function of world position (noise, island texture) plus the water
# cells of the frame, so tiles agree along shared edges.

const WrapNoiseScript := preload("res://src/worldgen/tile/wrap_noise.gd")
const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")
const FillScript := preload("res://src/worldgen/tile/drainage_fill.gd")
const FlowScript := preload("res://src/worldgen/tile/drainage_flow.gd")


static func apply(
	heights: PackedFloat32Array, water_class: PackedByteArray, samples: int, spacing_m: float,
	origin_sx: int, origin_sz: int, settings, rules: Dictionary, elevation
) -> void:
	var total: int = samples * samples
	var bumps: PackedFloat32Array = PackedFloat32Array()
	bumps.resize(total)
	var tile_samples_w: int = int(settings.tile_size_m / settings.map_spacing_m)
	var octave_index: int = 0

	for octave in rules["octaves"]:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = SeedUtil.purpose_seed(settings.master_seed, "tile_rolling", octave_index)
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		noise.frequency = spacing_m / float(octave["wavelength_m"])
		var data: PackedByteArray = WrapNoiseScript.bytes(
			noise, origin_sx, origin_sz, samples, samples, settings.min_tile * tile_samples_w, settings.min_tile * tile_samples_w,
			settings.tiles_x * tile_samples_w, settings.tiles_z * tile_samples_w, int(ceil(4.0 * float(octave["wavelength_m"]) / spacing_m))
		)
		var amplitude: float = float(octave["amplitude_m"])

		for index in range(total):
			bumps[index] += amplitude * (float(data[index]) / 127.5 - 1.0)

		octave_index += 1

	var distance_m: PackedFloat32Array = _distance_to_water(water_class, samples, spacing_m)
	var texture: PackedFloat32Array = _island_texture(elevation, samples, spacing_m, origin_sx, origin_sz)
	var low_from: float = float(rules["low_from_m"])
	var low_to: float = float(rules["low_to_m"])
	var high_from: float = float(rules["fade_from_m"])
	var high_to: float = float(rules["fade_to_m"])
	var near_m: float = float(rules["near_water_m"])
	var far_m: float = float(rules["far_water_m"])

	var hills: PackedFloat32Array = _hills(samples, spacing_m, origin_sx, origin_sz, settings, rules.get("hills", {}))
	var hill_rules: Dictionary = rules.get("hills", {})
	var hill_near: float = float(hill_rules.get("near_water_m", near_m))
	var hill_far: float = float(hill_rules.get("far_water_m", far_m))
	var hill_texture_min: float = float(hill_rules.get("texture_min", 0.0))
	# Dave 4 Nov 2026 ("it's ok if the hills run right into the foothills, we just need variety"): the hills have their own height fade, higher than the swells'.
	var hill_high_from: float = float(hill_rules.get("fade_from_m", high_from))
	var hill_high_to: float = float(hill_rules.get("fade_to_m", high_to))
	var top: float = maxf(high_to, hill_high_to) if not hills.is_empty() else high_to
	var pad: Dictionary = rules.get("_spawn_pad", {})
	var before: PackedFloat32Array = heights.duplicate() if not hills.is_empty() else PackedFloat32Array()

	for index in range(total):
		var h: float = heights[index]

		if h <= low_from or h >= top:
			continue

		var low_share: float = smoothstep(low_from, low_to, h)
		var height_share: float = low_share * (1.0 - smoothstep(high_from, high_to, h))
		var strength: float = height_share * smoothstep(near_m, far_m, distance_m[index]) * texture[index]
		var lift: float = strength * bumps[index]

		if not hills.is_empty():
			var hill_share: float = low_share * (1.0 - smoothstep(hill_high_from, hill_high_to, h)) * smoothstep(hill_near, hill_far, distance_m[index]) * maxf(texture[index], hill_texture_min)

			if not pad.is_empty():
				var x: float = float(origin_sx + index % samples) * spacing_m
				var z: float = float(origin_sz + index / samples) * spacing_m
				var r: float = Vector2(x - float(pad["x"]), z - float(pad["z"])).length()
				hill_share *= smoothstep(float(pad["flat_radius_m"]), float(pad["flat_radius_m"]) + float(pad["blend_m"]) * 3.0, r)

			lift += hill_share * hills[index]

		heights[index] = h + lift

	if not hills.is_empty() and bool(hill_rules.get("drain", true)):
		if str(hill_rules.get("drain_mode", "fill")) == "breach":
			var cut: Dictionary = _breach_new_hollows(before, heights, water_class, samples, float(hill_rules.get("max_breach_m", 4.0)))
			print("  rolling hills (breach): %d hollows breached, %d cells cut (most %.1f m), %d cells raised (most %.1f m), %d kept as natural hollow" % [
				int(cut["breached"]), int(cut["cut_cells"]), float(cut["most_cut_m"]), int(cut["raised_cells"]), float(cut["most_raised_m"]), int(cut["natural"])
			])
		else:
			var raised: Dictionary = _drain_new_hollows(before, heights, water_class, samples)
			print("  rolling hills: %d cells raised so new hollows drain (most %.1f m)" % [int(raised["cells"]), float(raised["most_m"])])


# The land's own valley lines, found BEFORE any water is placed (docs/water/terrain_water_pipeline.md, stage A2). The bumps and hills fade near these
# instead of near the rivers, so a hill never stands across a valley floor and dams it. Without this, the hills made after P1 moved them before the
# water dammed the valleys into closed basins up to 16 m deep that drain_hollows then filled flat (Dino's P1 bake, 7 Nov 2026: dry hollow cells on
# tile 3,4 went from 17,076 to 59,757). A cell is a valley line when the ground's own drainage (the same fill and flow the water step uses) gathers at
# least catchment_km2 there, or when it lies in a natural hollow the fill found. Sea cells are 1, valley cells 2, others 0.
static func valley_lines(heights: PackedFloat32Array, sea: PackedByteArray, samples: int, spacing_m: float, catchment_km2: float) -> PackedByteArray:
	var total: int = samples * samples
	var fill = FillScript.new()
	fill.build(heights, sea, samples, 0.5)
	var unit: float = spacing_m * spacing_m * 1.0e-6
	var runoff: PackedFloat32Array = PackedFloat32Array()
	runoff.resize(total)

	for index in range(total):
		runoff[index] = 0.0 if sea[index] == 1 else unit

	var flow = FlowScript.new()
	flow.build(fill, runoff)
	var lines: PackedByteArray = sea.duplicate()

	for index in range(total):
		if lines[index] == 0 and (flow.discharge[index] >= catchment_km2 or fill.lake_id[index] != 0):
			lines[index] = 2

	# The way out of every natural hollow, down to the sea or the frame edge, whatever its catchment: a hill on that path would raise the hollow's spill
	# and deepen it (Dino's tile 3,4 census, 7 Nov 2026). Lines with the catchment are already complete downstream, so a walk stops at one.
	for lake in fill.lakes:
		var k: int = int(lake.get("outlet", -1))

		while k >= 0 and lines[k] == 0:
			lines[k] = 2
			k = fill.receiver[k]

	return lines


# Dave 4 Nov 2026 ("valleys and hills and rolling hills along the plains on the islands; the terrain is way too flat"): broad hills, 0 to amplitude_m
# high per octave (never below the ground, so the rivers' valleys stay the low ground). Empty when no octaves.
static func _hills(samples: int, spacing_m: float, origin_sx: int, origin_sz: int, settings, rules: Dictionary) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()

	if rules.get("octaves", []).is_empty():
		return out

	out.resize(samples * samples)
	var tile_samples_w: int = int(settings.tile_size_m / settings.map_spacing_m)
	var power: float = float(rules.get("power", 1.0))
	var octave_index: int = 0

	for octave in rules["octaves"]:
		var noise: FastNoiseLite = FastNoiseLite.new()
		noise.seed = SeedUtil.purpose_seed(settings.master_seed, "tile_hills", octave_index)
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.fractal_type = FastNoiseLite.FRACTAL_NONE
		noise.frequency = spacing_m / float(octave["wavelength_m"])
		var data: PackedByteArray = WrapNoiseScript.bytes(
			noise, origin_sx, origin_sz, samples, samples, settings.min_tile * tile_samples_w, settings.min_tile * tile_samples_w,
			settings.tiles_x * tile_samples_w, settings.tiles_z * tile_samples_w, int(ceil(4.0 * float(octave["wavelength_m"]) / spacing_m))
		)
		var amplitude: float = float(octave["amplitude_m"])
		# An octave may shape its own tops: a high power leaves most of the ground low and lifts only scattered steep hills (Dave 5 Nov 2026).
		var shape: float = float(octave.get("power", power))

		for index in range(out.size()):
			out[index] += amplitude * pow(float(data[index]) / 255.0, shape)

		octave_index += 1

	return out


# The hills must not leave closed hollows the ground did not have (each would fill as a pond): priority flood of the ground before and after, and every
# dry cell whose hollow is deeper now than before is raised to its spill (a flat vale floor between the hills). Outlets: wet cells, the sea, the frame edge.
static func _drain_new_hollows(before: PackedFloat32Array, heights: PackedFloat32Array, water_class: PackedByteArray, samples: int) -> Dictionary:
	var filled_before: PackedFloat32Array = _flood(before, water_class, samples, 0.0)
	var filled_after: PackedFloat32Array = _flood(heights, water_class, samples, 0.0)
	var cells: int = 0
	var most: float = 0.0

	for index in range(heights.size()):
		var deeper: float = (filled_after[index] - heights[index]) - maxf(filled_before[index] - before[index], 0.0)

		if deeper > 0.001:
			heights[index] += deeper
			cells += 1
			most = maxf(most, deeper)

	return {"cells": cells, "most_m": most}


# The hills drain by construction (Sonny 7 Nov 2026; Dino's tile 3,4 census: the hills made 6x the hollow volume of the ground before them, up to
# 23.6 m deep, and filling those to their spill left flat vale floors up to 16 m thick). A hollow the hills made is breached, as a river cuts a gap
# through ground that rises across it: a priority flood (Barnes et al. 2014) from the sea and the frame edge, and where it steps down into a hollow
# the path it came by (the lowest way out) is cut so it falls all the way out (Lindsay 2016, "Efficient hybrid breaching-filling sink removal").
# No cut is deeper than max_breach_m; a hollow deeper than that has its floor raised by the rest (hybrid). A hollow the ground had before the hills
# (a natural basin, possibly a lake with a river out) keeps its old depth and is left to the water step. Outlets: the sea (class 1), ground at or
# below 0, the frame edge; valley lines (class 2) are not outlets here.
static func _breach_new_hollows(before: PackedFloat32Array, heights: PackedFloat32Array, water_class: PackedByteArray, samples: int, max_breach_m: float) -> Dictionary:
	const BUCKET_M := 0.02
	const GRADE_M := 0.002   # fall per cell along a cut, so the cut drains
	var total: int = samples * samples
	var sea: PackedByteArray = PackedByteArray()
	sea.resize(total)

	for index in range(total):
		sea[index] = 1 if water_class[index] == 1 else 0

	var filled_before: PackedFloat32Array = _flood(before, sea, samples, 0.0)
	var made: PackedFloat32Array = heights.duplicate()   # the ground as the hills made it: no cell is cut more than max_breach_m below this in all
	var level: PackedFloat32Array = heights.duplicate()
	var parent: PackedInt32Array = PackedInt32Array()
	parent.resize(total)
	parent.fill(-1)
	var done: PackedByteArray = PackedByteArray()
	done.resize(total)
	var result: Dictionary = {"breached": 0, "cut_cells": 0, "most_cut_m": 0.0, "raised_cells": 0, "most_raised_m": 0.0, "natural": 0}
	var low: float = INF
	var high: float = -INF

	for index in range(total):
		low = minf(low, heights[index])
		high = maxf(high, heights[index])

	var count: int = int(ceil((high - low) / BUCKET_M)) + 2
	var buckets: Array = []
	buckets.resize(count)

	for b in range(count):
		buckets[b] = PackedInt32Array()

	for index in range(total):
		var i: int = index % samples
		var j: int = index / samples

		if sea[index] != 0 or heights[index] <= 0.0 or i == 0 or j == 0 or i == samples - 1 or j == samples - 1:
			done[index] = 1
			buckets[maxi(int((heights[index] - low) / BUCKET_M), 0)].append(index)

	var b: int = 0

	while b < count:
		var bucket: PackedInt32Array = buckets[b]

		if bucket.is_empty():
			b += 1
			continue

		var c: int = bucket[bucket.size() - 1]
		bucket.resize(bucket.size() - 1)
		buckets[b] = bucket
		var i: int = c % samples

		for nb in [c - 1 if i > 0 else -1, c + 1 if i < samples - 1 else -1, c - samples, c + samples]:
			if nb < 0 or nb >= total or done[nb] != 0:
				continue

			var here: float = level[c]   # a cut for one neighbour lowers c for the next
			done[nb] = 1
			parent[nb] = c

			if heights[nb] < here:
				var natural_m: float = filled_before[nb] - before[nb]

				if natural_m > 0.001 or level[c] > heights[c] + 0.001:
					# A natural hollow (or ground draining into one): it keeps its old depth at most, and the water step decides on it.
					var floor_m: float = here - natural_m

					if heights[nb] < floor_m:
						result["most_raised_m"] = maxf(result["most_raised_m"], floor_m - heights[nb])
						result["raised_cells"] += 1
						heights[nb] = floor_m

					if natural_m > 0.001:
						result["natural"] += 1
				else:
					# A hollow the hills made: cut the way out from here, raising the floor only by what a cut deeper than max_breach_m would need.
					var target: float = heights[nb]
					var deepest: float = _cut_depth(heights, made, parent, c, target, GRADE_M)

					if deepest > max_breach_m:
						var lift: float = deepest - max_breach_m
						target += lift
						result["most_raised_m"] = maxf(result["most_raised_m"], lift)
						result["raised_cells"] += 1
						heights[nb] = target

					var k: int = c
					var allowed: float = target

					while k >= 0:
						allowed -= GRADE_M

						if heights[k] <= allowed:
							break

						result["most_cut_m"] = maxf(result["most_cut_m"], made[k] - allowed)
						result["cut_cells"] += 1
						heights[k] = allowed
						level[k] = allowed
						k = parent[k]

					result["breached"] += 1

			var lvl: float = maxf(heights[nb], here) if level[c] > heights[c] + 0.001 or filled_before[nb] - before[nb] > 0.001 else heights[nb]
			level[nb] = lvl
			var bucket_index: int = clampi(int((lvl - low) / BUCKET_M), 0, count - 1)
			buckets[bucket_index].append(nb)
			b = mini(b, bucket_index)

	return result


# How deep below the ground the hills made (`made`) the cut out of a hollow would leave the path, counting earlier cuts on it: walk the flood's
# path out from `from` until the ground falls below the cut's line.
static func _cut_depth(heights: PackedFloat32Array, made: PackedFloat32Array, parent: PackedInt32Array, from: int, target: float, grade_m: float) -> float:
	var k: int = from
	var allowed: float = target
	var deepest: float = 0.0

	while k >= 0:
		allowed -= grade_m

		if heights[k] <= allowed:
			break

		deepest = maxf(deepest, made[k] - allowed)
		k = parent[k]

	return deepest


# Priority flood (Barnes et al. 2014, a bucket queue at 2 cm): the lowest level each cell can drain at, rising `step` per cell over flats and hollows.
static func _flood(heights: PackedFloat32Array, water_class: PackedByteArray, samples: int, step: float) -> PackedFloat32Array:
	const BUCKET_M := 0.02
	var total: int = samples * samples
	var level: PackedFloat32Array = heights.duplicate()
	var done: PackedByteArray = PackedByteArray()
	done.resize(total)
	var low: float = INF
	var high: float = -INF

	for index in range(total):
		low = minf(low, heights[index])
		high = maxf(high, heights[index])

	high += step * float(samples) * 0.1 + 50.0
	var count: int = int(ceil((high - low) / BUCKET_M)) + 2
	var buckets: Array = []
	buckets.resize(count)

	for b in range(count):
		buckets[b] = PackedInt32Array()

	for index in range(total):
		var i: int = index % samples
		var j: int = index / samples

		if water_class[index] != 0 or heights[index] <= 0.0 or i == 0 or j == 0 or i == samples - 1 or j == samples - 1:
			done[index] = 1
			buckets[int((heights[index] - low) / BUCKET_M)].append(index)

	var b: int = 0

	while b < count:
		var bucket: PackedInt32Array = buckets[b]

		if bucket.is_empty():
			b += 1
			continue

		var index: int = bucket[bucket.size() - 1]
		bucket.resize(bucket.size() - 1)
		buckets[b] = bucket
		var here: float = level[index]
		var i: int = index % samples

		for n in [index - 1 if i > 0 else -1, index + 1 if i < samples - 1 else -1, index - samples, index + samples]:
			if n < 0 or n >= total or done[n] != 0:
				continue

			done[n] = 1
			var lvl: float = maxf(heights[n], here + step)
			level[n] = lvl
			var nb: int = mini(int((lvl - low) / BUCKET_M), count - 1)
			buckets[nb].append(n)
			b = mini(b, nb)

	return level


# Distance in meters from every sample to the nearest wet cell (two-pass 3-4 chamfer).
static func _distance_to_water(water_class: PackedByteArray, samples: int, spacing_m: float) -> PackedFloat32Array:
	var far: int = 1 << 20
	var steps: PackedInt32Array = PackedInt32Array()
	steps.resize(samples * samples)

	for index in range(steps.size()):
		steps[index] = 0 if water_class[index] != 0 else far

	for row in range(samples):
		for col in range(samples):
			var index: int = row * samples + col
			var best: int = steps[index]

			if col > 0:
				best = mini(best, steps[index - 1] + 3)

			if row > 0:
				best = mini(best, steps[index - samples] + 3)

				if col > 0:
					best = mini(best, steps[index - samples - 1] + 4)

				if col < samples - 1:
					best = mini(best, steps[index - samples + 1] + 4)

			steps[index] = best

	for row in range(samples - 1, -1, -1):
		for col in range(samples - 1, -1, -1):
			var index: int = row * samples + col
			var best: int = steps[index]

			if col < samples - 1:
				best = mini(best, steps[index + 1] + 3)

			if row < samples - 1:
				best = mini(best, steps[index + samples] + 3)

				if col < samples - 1:
					best = mini(best, steps[index + samples + 1] + 4)

				if col > 0:
					best = mini(best, steps[index + samples - 1] + 4)

			steps[index] = best

	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(steps.size())

	for index in range(steps.size()):
		out[index] = float(steps[index]) * spacing_m / 3.0

	return out


# The island texture factor (WorldElevation.texture) for every sample, blended between the 160 m cells.
static func _island_texture(elevation, samples: int, spacing_m: float, origin_sx: int, origin_sz: int) -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(samples * samples)
	var cell: float = elevation.cell_m
	var x0: float = float(origin_sx) * spacing_m
	var z0: float = float(origin_sz) * spacing_m
	var column_cell: PackedInt32Array = PackedInt32Array()
	var column_frac: PackedFloat32Array = PackedFloat32Array()
	column_cell.resize(samples)
	column_frac.resize(samples)

	for i in range(samples):
		var u: float = (x0 + float(i) * spacing_m - elevation.origin_x) / cell - 0.5
		column_cell[i] = int(floor(u))
		column_frac[i] = u - floor(u)

	for j in range(samples):
		var v: float = (z0 + float(j) * spacing_m - elevation.origin_z) / cell - 0.5
		var row: int = int(floor(v))
		var fv: float = v - floor(v)

		for i in range(samples):
			var c: int = column_cell[i]
			var fu: float = column_frac[i]
			var top: float = lerpf(elevation.texture[elevation.index_of(c, row)], elevation.texture[elevation.index_of(c + 1, row)], fu)
			var bottom: float = lerpf(elevation.texture[elevation.index_of(c, row + 1)], elevation.texture[elevation.index_of(c + 1, row + 1)], fu)
			out[j * samples + i] = lerpf(top, bottom, fv)

	return out
