extends RefCounted

# Where a felled trunk comes to rest (Kathleen, Dave's tree-fall job). The trunk hinges at the stump and its axis is one straight line from the hinge,
# so on any ground it rests on the highest point it meets: the pose is the lowest pitch (radians above the horizontal, negative = running downhill)
# at which the trunk, thinning from its butt radius to 55 percent at the top, stays on or above the ground sampled along it. It never sinks into a rising
# slope, and it follows a falling one. `choose` tries the fall away from the player first, then swings it up to 80 degrees either side, and takes the first
# direction that does not have to climb steeply; with none, the gentlest one.

const MAX_RISE := 0.45                                   # radians (26 degrees): a trunk climbing more than this tries another direction
const MAX_DOWN := 1.0                                    # radians: a trunk is never laid steeper than this downhill (the far end then hangs a little over a dip)
const STEP_M := 0.75                                     # ground sample spacing along the trunk
const SWINGS := [0.0, 0.35, -0.35, 0.7, -0.7, 1.05, -1.05, 1.4, -1.4]   # radians off the away direction, nearest first


# The resting pitch for a trunk hinged at `base` (the foot of the stump on the ground) falling along `yaw` (0 = +Z, as the trunk record), or 0 when the ground is unknown.
static func pitch_for(base: Vector3, yaw: float, length: float, radius: float, ground: Callable) -> float:
	var dir: Vector2 = Vector2(sin(yaw), cos(yaw))
	var pitch: float = 0.0

	for pass_no in 2:   # the second pass samples the horizontal reach the first pose leaves
		var reach: float = length * cos(pitch) if pass_no > 0 else length
		var best: float = -INF
		var steps: int = maxi(1, int(ceil(reach / STEP_M)))

		for k in range(1, steps + 1):
			var d: float = minf(float(k) * STEP_M, reach)
			var g: float = float(ground.call(base.x + dir.x * d, base.z + dir.y * d))

			if is_nan(g):
				continue

			var r: float = radius * (1.0 - 0.45 * d / maxf(length, 0.5))
			best = maxf(best, atan2((g + r) - (base.y + radius), d))

		pitch = clampf(best if best > -INF else 0.0, -MAX_DOWN, 1.3)

		if pitch > MAX_RISE:   # too steep a climb to refine: the caller tries another direction (a refined, nearly upright reach would skip the rising ground that made it steep)
			return pitch

	return pitch


# {"yaw": the fall direction, "pitch": the resting pitch} for a tree of this length and butt radius at `base`; `away` is the horizontal direction from the player to the tree.
static func choose(base: Vector3, away: Vector2, length: float, radius: float, ground: Callable) -> Dictionary:
	var yaw0: float = atan2(away.x, away.y) if away.length() > 0.01 else 0.0
	var best_yaw: float = yaw0
	var best_pitch: float = INF

	for swing in SWINGS:
		var yaw: float = yaw0 + float(swing)
		var pitch: float = pitch_for(base, yaw, length, radius, ground)

		if pitch <= MAX_RISE:
			return {"yaw": yaw, "pitch": pitch}

		if pitch < best_pitch:
			best_pitch = pitch
			best_yaw = yaw

	return {"yaw": best_yaw, "pitch": best_pitch}
