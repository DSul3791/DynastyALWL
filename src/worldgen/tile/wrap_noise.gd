class_name WrapNoise
extends RefCounted

# World-aligned noise that repeats exactly across the world wrap seam.
#
# A noise image for a block of samples is made as before, then the samples
# that lie in a band just before the seam (or past it) are replaced by a
# crossfade between the noise there and the noise one world width back:
#
#   value(u) = cos(t * 90 deg) * noise(u) + sin(t * 90 deg) * noise(u - period)
#
# where t rises from 0 to 1 across the band. At the seam t is 1, so the
# value equals noise at the start of the world. The cos and sin weights
# keep the strength of the noise the same across the band. The band is a
# few wavelengths wide, so only a narrow strip of a seam tile pays for it.

# Returns the bytes of a width by height block (one per sample, 127.5 = zero)
# whose first sample is world sample (origin_x, origin_z). `world_min_x` and
# `world_min_z` are the first world sample indices of the world, `period_x`
# and `period_z` its size in samples. `band` is the crossfade width in samples.
static func bytes(
		noise: FastNoiseLite, origin_x: int, origin_z: int, width: int, height: int,
		world_min_x: int, world_min_z: int, period_x: int, period_z: int, band: int
) -> PackedByteArray:
	noise.offset = Vector3(float(origin_x), float(origin_z), 0.0)
	var image: Image = noise.get_image(width, height, false, false, false)

	if image.get_format() != Image.FORMAT_L8:
		image.convert(Image.FORMAT_L8)

	var data: PackedByteArray = image.get_data()
	var x_end: int = world_min_x + period_x
	var z_end: int = world_min_z + period_z
	var first_x: int = origin_x
	var last_x: int = origin_x + width - 1
	var first_z: int = origin_z
	var last_z: int = origin_z + height - 1

	# Nothing to do when the block lies clear of the seams.
	if last_x < x_end - band and first_x >= world_min_x and last_z < z_end - band and first_z >= world_min_z:
		return data

	noise.offset = Vector3.ZERO

	for j in range(height):
		var z: int = origin_z + j
		var vz: int = world_min_z + posmod(z - world_min_z, period_z)
		var tz: float = clampf(float(vz - (z_end - band)) / float(band), 0.0, 1.0) if vz >= z_end - band else 0.0
		var z_special: bool = vz != z or vz >= z_end - band

		for i in range(width):
			var x: int = origin_x + i
			var ux: int = world_min_x + posmod(x - world_min_x, period_x)
			var in_band_x: bool = ux >= x_end - band

			if not (z_special or in_band_x or ux != x):
				continue

			var tx: float = clampf(float(ux - (x_end - band)) / float(band), 0.0, 1.0) if in_band_x else 0.0
			var total: float = 0.0

			# Four terms: shifted back by a world width in x and/or z.
			for a in range(2):
				var wx: float = cos(tx * PI * 0.5) if a == 0 else sin(tx * PI * 0.5)

				if wx < 0.00001:
					continue

				for b in range(2):
					var wz: float = cos(tz * PI * 0.5) if b == 0 else sin(tz * PI * 0.5)

					if wz < 0.00001:
						continue

					total += wx * wz * noise.get_noise_2d(float(ux - a * period_x), float(vz - b * period_z))

			data[j * width + i] = clampi(int(round((total * 0.5 + 0.5) * 255.0)), 0, 255)

	return data
