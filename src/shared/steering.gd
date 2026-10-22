extends RefCounted

# The one walk module for everything that moves on its own on the server: NPCs now, animals next (Steve's rule, 2026-10-21).
# A creature walks toward a target on the ground, turning aside from what blocks it or is too steep, and keeps its heading
# toward the target when it can, so it sidesteps a tree or a pond instead of turning its back on the goal.
# Pure functions: the caller owns the creature's position and passes in how to read the ground.

const TURNS := [0.0, 0.5236, -0.5236, 1.0472, -1.0472, 1.5708, -1.5708]   # radians off the direct line, tried in this order
const MAX_SLOPE := 0.9                  # rise over run a walker will climb


# One step of at most speed x dt metres from pos toward target. `ground` is Callable(x, z) -> height, `blocked` is
# Callable(x, z) -> bool (water, a wall, anything the walker may not enter; may be invalid). Returns
# {"pos": Vector3 (y on the ground), "heading": radians of travel in x/z, "moved": bool, "arrived": bool}.
static func step(pos: Vector3, target: Vector3, speed: float, dt: float, ground: Callable, blocked: Callable, arrive_m: float = 0.4, heading: float = 0.0) -> Dictionary:
	var to_x: float = target.x - pos.x
	var to_z: float = target.z - pos.z
	var dist: float = sqrt(to_x * to_x + to_z * to_z)

	if dist <= arrive_m:
		return {"pos": pos, "heading": heading, "moved": false, "arrived": true}

	var reach: float = minf(speed * dt, dist)
	var direct: float = atan2(to_z, to_x)

	for turn in TURNS:
		var angle: float = direct + float(turn)
		var nx: float = pos.x + cos(angle) * reach
		var nz: float = pos.z + sin(angle) * reach

		if blocked.is_valid() and bool(blocked.call(nx, nz)):
			continue

		var ny: float = float(ground.call(nx, nz)) if ground.is_valid() else pos.y

		if is_nan(ny) or absf(ny - pos.y) > MAX_SLOPE * reach + 0.05:
			continue

		return {"pos": Vector3(nx, ny, nz), "heading": angle, "moved": true, "arrived": false}

	return {"pos": pos, "heading": heading, "moved": false, "arrived": false}
