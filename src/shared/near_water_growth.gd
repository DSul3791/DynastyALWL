extends RefCounted

# Lush growth by water (Dave 9 Nov 2026): plants "grow 100% thicker, and grass grows taller right at the water and its growth deminishes as it
# gets further from the water until it gets to normal growth at 6 meters away". One curve for everything that grows: the client grass
# (grass_view.gd) and the flora placer read the same share W, 1 at the water's edge falling straight to 0 at REACH_M.

const REACH_M := 6.0          # normal growth from this far from the water's edge
const ROOTS_M := 1.0          # ground up to this high over the water is fully watered
const DRY_M := 3.0            # and from this high it is not (a high bank or a cliff over a river)


# W = clamp(1 - d / 6 m, 0, 1), times how well the water reaches the roots when the height over the water is known (above_m; NAN: not known,
# taken as reached). NAN or INF distance (no water near): 0.
static func growth_near_water(distance_m: float, above_m: float = NAN) -> float:
	if is_nan(distance_m) or is_inf(distance_m):
		return 0.0

	var share: float = clampf(1.0 - distance_m / REACH_M, 0.0, 1.0)

	if is_nan(above_m):
		return share

	return share * (1.0 - clampf((above_m - ROOTS_M) / (DRY_M - ROOTS_M), 0.0, 1.0))
