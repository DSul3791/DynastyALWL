extends RefCounted

# How much ground still holds a tree up (Items job 85, DIG_UNDER_TREES_DESIGN.md). The support is a disc under the trunk,
# `radius` wide and `depth` deep; the share of it not dug away is sampled on a grid. `ops` are ground edits, oldest first,
# as [kind, centre, radius] (kind 0 dig, 1 fill): a sample point is dug when the newest edit covering it is a dig.

const KIND_DIG := 0
const STEP_M := 0.35
const LAYERS := 4


static func solid_share(ops: Array, base: Vector3, radius: float, depth: float) -> float:
	var near: Array = []

	for op in ops:
		if Vector2(op[1].x - base.x, op[1].z - base.z).length() <= radius + float(op[2]) + 0.01 and absf(op[1].y - (base.y - depth * 0.5)) <= depth * 0.5 + float(op[2]):
			near.append(op)

	if near.is_empty():
		return 1.0

	var total: int = 0
	var solid: int = 0
	var steps: int = int(ceil(radius / STEP_M))

	for ix in range(-steps, steps + 1):
		for iz in range(-steps, steps + 1):
			var flat: Vector2 = Vector2(ix, iz) * STEP_M

			if flat.length() > radius:
				continue

			for layer in range(LAYERS):
				var p: Vector3 = Vector3(base.x + flat.x, base.y - depth * (float(layer) + 0.5) / float(LAYERS), base.z + flat.y)
				var dug: bool = false

				for op in near:
					if p.distance_to(op[1]) <= float(op[2]):
						dug = int(op[0]) == KIND_DIG

				total += 1
				solid += 0 if dug else 1

	return float(solid) / float(maxi(total, 1))
