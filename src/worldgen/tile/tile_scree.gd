class_name TileScree
extends RefCounted

# Scree aprons (Tyler FINDINGS Report 9 B, owner Willy): at the foot of every steep face the loose rock
# that fell from it lies in a concave slope, steep (about 33 degrees) against the face and easing to
# about 15 degrees over 20 to 60 m, so the foot of a cliff is real ground and not a hard crease.
#
# Works on a square height map. For each foot cell (ground below a face steeper than cliff_deg) the face
# height is measured by walking up the steep cells, the apron gets share x face height (at most
# max_height_m) and a length that follows from the two angles; the ground around the foot is then raised
# to that profile where it is lower. Only fill is made (never a cut), no more than the apron's own height
# at any cell, and nothing under water. The result depends only on heights within reach of a cell, so
# two tiles that share an edge agree when their frames overlap.

var _rules: Dictionary = {}
var filled_cells: int = 0
var foot_cells: int = 0
var deepest_fill_m: float = 0.0


func setup(rules: Dictionary) -> void:
	_rules = rules


# Returns the new heights (same size). origin_sx/sz: world sample of cell (0, 0), so the fan tongues are the same in every tile.
func apply(heights: PackedFloat32Array, samples: int, spacing: float, origin_sx: int = 0, origin_sz: int = 0) -> PackedFloat32Array:
	filled_cells = 0
	foot_cells = 0
	deepest_fill_m = 0.0

	if _rules.is_empty():
		return heights

	var cliff_tan: float = tan(deg_to_rad(float(_rules["cliff_deg"])))
	var foot_tan: float = tan(deg_to_rad(float(_rules["foot_max_deg"])))
	var top_tan: float = tan(deg_to_rad(float(_rules["top_deg"])))
	var toe_tan: float = tan(deg_to_rad(float(_rules["toe_deg"])))
	var share: float = float(_rules["height_share"])
	var max_height: float = float(_rules["max_height_m"])
	var min_face: float = float(_rules["min_face_m"])
	var min_length: float = float(_rules["min_length_m"])
	var max_length: float = float(_rules["max_length_m"])
	var sea_m: float = float(_rules.get("min_land_m", 1.0))
	var tongue_m: float = float(_rules.get("tongue_m", 90.0))
	var tongue_min: float = float(_rules.get("tongue_min", 0.25))
	var total: int = samples * samples
	var slope: PackedFloat32Array = PackedFloat32Array()
	slope.resize(total)

	# Steepness (rise over run) by central differences.
	var inv: float = 1.0 / (2.0 * spacing)

	for j in range(1, samples - 1):
		for i in range(1, samples - 1):
			var index: int = j * samples + i
			var gx: float = (heights[index + 1] - heights[index - 1]) * inv
			var gz: float = (heights[index + samples] - heights[index - samples]) * inv
			slope[index] = sqrt(gx * gx + gz * gz)

	var out: PackedFloat32Array = heights.duplicate()
	var reach_cells: int = int(ceil(max_length / spacing))
	var offsets: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]
	var margin: int = reach_cells + 2

	for j in range(margin, samples - margin):
		for i in range(margin, samples - margin):
			var index: int = j * samples + i
			var base: float = heights[index]

			if base <= sea_m or slope[index] >= foot_tan:
				continue

			# A foot cell has a steeper cell, higher than it, right beside it.
			var start: int = -1
			var best: float = base + spacing * 0.5

			for o in offsets:
				var other: int = index + o.y * samples + o.x

				if slope[other] >= cliff_tan and heights[other] > best:
					best = heights[other]
					start = other

			if start < 0:
				continue

			# Walk up the face: always to the highest neighbour while the ground stays steep.
			var cell: int = start
			var top: float = heights[start]

			for step in range(14):
				var next: int = -1
				var next_h: float = top

				for o in offsets:
					var other: int = cell + o.y * samples + o.x

					if heights[other] > next_h:
						next_h = heights[other]
						next = other

				if next < 0:
					break

				cell = next
				top = next_h

				if slope[cell] < cliff_tan * 0.7:
					break

			var face: float = top - base

			if face < min_face:
				continue

			# Fan tongues (Tyler 16 D): the apron is thick below gullies and thin between them, by a world-fixed pattern.
			var wx: float = float(origin_sx + i) * spacing / tongue_m * TAU
			var wz: float = float(origin_sz + j) * spacing / tongue_m * TAU
			var pattern: float = 0.5 + 0.5 * sin(wx * 0.9 + wz * 0.4 + 1.3 * sin(wz * 0.55)) * sin(wz * 0.8 - wx * 0.35 + 2.1)
			var apron: float = minf(face * share, max_height) * (tongue_min + (1.0 - tongue_min) * smoothstep(0.2, 0.75, pattern))
			var length: float = apron / (0.5 * (top_tan + toe_tan))

			if length < min_length:
				continue

			length = minf(length, max_length)
			foot_cells += 1
			_stamp(out, heights, samples, spacing, i, j, base, apron, length, top_tan, toe_tan, sea_m)

	return out


# Raises the ground around foot (fi, fj) to base + g(d): the slope eases linearly from top_tan at the foot
# to toe_tan at the end of the apron, so the surface is concave.
func _stamp(out: PackedFloat32Array, heights: PackedFloat32Array, samples: int, spacing: float, fi: int, fj: int, base: float, apron: float, length: float, top_tan: float, toe_tan: float, sea_m: float) -> void:
	var reach: int = int(ceil(length / spacing))
	# The profile is scaled so its height at the foot is exactly `apron` for the (possibly shortened) length.
	var natural: float = length * 0.5 * (top_tan + toe_tan)
	var scale: float = apron / maxf(natural, 0.001)

	for dj in range(-reach, reach + 1):
		for di in range(-reach, reach + 1):
			var d: float = sqrt(float(di * di + dj * dj)) * spacing

			if d >= length:
				continue

			var index: int = (fj + dj) * samples + fi + di
			var ground: float = heights[index]

			if ground <= sea_m:
				continue

			var rise: float = (top_tan * (length - d) + (toe_tan - top_tan) * (length * length - d * d) / (2.0 * length)) * scale
			var target: float = base + rise
			var fill: float = target - ground

			if fill <= 0.0 or fill > apron:
				continue

			if target > out[index]:
				filled_cells += 1 if out[index] == ground else 0
				deepest_fill_m = maxf(deepest_fill_m, fill)
				out[index] = target
