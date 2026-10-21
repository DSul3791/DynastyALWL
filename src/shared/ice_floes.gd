extends RefCounted

# Ocean ice (River start thread, tech/ICE_DESIGN.md part 2, approved by Technical direction): drifting-free
# floes, deterministic from the world seed, so no state and no traffic. The sea is split into square
# cells of CELL_M; each cell may hold one floe, placed at a jittered spot inside it. How many cells
# hold one and how big they are follows the ice cover (src/shared/ice.gd): scattered chunks when
# the sea is just starting to freeze, a nearly solid pack when it is hard frozen, shrinking and
# vanishing again as it melts. Between floes is open water.

const CELL_M := 48.0
const MIN_COVER := 0.15          # below this the sea is open
const TOP_M := 0.4               # a floe's top above the sea
const THICK_M := 1.2             # a floe's thickness (it floats with TOP_M above the water)


static func _hash(seed_value: int, x: int, z: int, salt: int) -> float:
	var h: int = (seed_value * 73856093) ^ (x * 19349663) ^ (z * 83492791) ^ (salt * 2654435761)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0xFFFF) / 65535.0


# The floe in cell (cx, cz) at this ice cover: {"pos": Vector2 (world x, z), "radius": float,
# "turn": float (radians)}, or {} when the cell is open water.
static func floe_in_cell(seed_value: int, cx: int, cz: int, cover: float) -> Dictionary:
	if cover < MIN_COVER:
		return {}

	# The share of cells holding a floe rises from a few to almost all with the cover.
	var share: float = clampf(0.15 + 0.8 * cover, 0.0, 0.95)

	if _hash(seed_value, cx, cz, 1) > share:
		return {}

	var margin: float = CELL_M * 0.2
	var pos: Vector2 = Vector2((float(cx) + 0.5) * CELL_M, (float(cz) + 0.5) * CELL_M) + Vector2(_hash(seed_value, cx, cz, 2) - 0.5, _hash(seed_value, cx, cz, 3) - 0.5) * (CELL_M - 2.0 * margin)
	# Bigger and rounder as the cover grows, with some variety (6 m to 0.5 cell).
	var radius: float = lerpf(6.0, CELL_M * 0.5, clampf(cover, 0.0, 1.0)) * (0.6 + 0.4 * _hash(seed_value, cx, cz, 4))
	return {"pos": pos, "radius": radius, "turn": _hash(seed_value, cx, cz, 5) * TAU}


# Every floe within `range_m` of (x, z): [[cx, cz, floe], ...].
static func floes_near(seed_value: int, x: float, z: float, range_m: float, cover: float) -> Array:
	var list: Array = []

	if cover < MIN_COVER:
		return list

	var low_x: int = int(floor((x - range_m) / CELL_M))
	var high_x: int = int(floor((x + range_m) / CELL_M))
	var low_z: int = int(floor((z - range_m) / CELL_M))
	var high_z: int = int(floor((z + range_m) / CELL_M))

	for cz in range(low_z, high_z + 1):
		for cx in range(low_x, high_x + 1):
			var floe: Dictionary = floe_in_cell(seed_value, cx, cz, cover)

			if not floe.is_empty():
				list.append([cx, cz, floe])

	return list
