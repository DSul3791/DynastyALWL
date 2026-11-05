extends RefCounted

# Rolling ground for the low land: the swells and knolls a player walks over (about 30 m to 300 m across).
# Added AFTER the water is carved, and faded out near any water, so rivers, ponds and their banks keep the
# shape the drainage gave them (bumps made before the water step broke the river and pond tests: see
# GENERATOR_NOTES.md). Away from water the bumps are strongest; the beach stays calm; high ground is left to
# the normal detail noise. Everything is a function of world position (noise, island texture) plus the water
# cells of the frame, so tiles agree along shared edges.

const WrapNoiseScript := preload("res://src/worldgen/tile/wrap_noise.gd")
const SeedUtil := preload("res://src/worldgen/settings/worldgen_seed.gd")


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
		var raised: Dictionary = _drain_new_hollows(before, heights, water_class, samples)
		print("  rolling hills: %d cells raised so new hollows drain (most %.1f m)" % [int(raised["cells"]), float(raised["most_m"])])


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

		for index in range(out.size()):
			out[index] += amplitude * pow(float(data[index]) / 255.0, power)

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
