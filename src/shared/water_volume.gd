extends RefCounted

# One answer to "is this point in water, and how deep" for drawing, swimming and sound
# (owner, 2026-10-20: "think of water as 3D"). The water is a surface level over the ground
# (the client's water grid: `flora.water_surface_at`); the volume under a point is the
# water between the ground there and that level. A film of a few cm is wet ground, not a
# body of water: nothing is submerged in less than MIN_DEPTH_M.

const MIN_DEPTH_M := 0.4


# Water depth over the ground at a spot (0 when there is no water or no ground reading).
static func depth(surface: float, ground: float) -> float:
	if is_nan(surface):
		return 0.0

	return maxf(surface - ground, 0.0) if not is_nan(ground) else maxf(surface, 0.0)


# Whether a point at height y is inside the water volume: below the surface, with at least
# MIN_DEPTH_M of water over the ground there (an unknown ground counts as deep).
static func submerged(y: float, surface: float, ground: float, min_depth: float = MIN_DEPTH_M) -> bool:
	if is_nan(surface) or y >= surface:
		return false

	return is_nan(ground) or surface - ground >= min_depth


# How much of a body standing with its feet at feet_y and `height` tall is under water, 0 to 1.
static func immersion(feet_y: float, height: float, surface: float, ground: float) -> float:
	if is_nan(surface) or height <= 0.0 or depth(surface, ground) < MIN_DEPTH_M:
		return 0.0

	return clampf((surface - feet_y) / height, 0.0, 1.0)
