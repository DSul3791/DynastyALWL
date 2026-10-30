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

	for index in range(total):
		var h: float = heights[index]

		if h <= low_from or h >= high_to:
			continue

		var strength: float = smoothstep(low_from, low_to, h) * (1.0 - smoothstep(high_from, high_to, h))
		strength *= smoothstep(near_m, far_m, distance_m[index]) * texture[index]
		heights[index] = h + strength * bumps[index]


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
