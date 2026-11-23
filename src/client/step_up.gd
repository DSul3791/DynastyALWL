extends RefCounted

# Stepping over low obstacles (logs, stones, stumps) while walking, jogging or running. data/movement.json step_up_m is the limit.


const MIN_PROBE_M := 0.12   # the least distance ahead that is probed
const MIN_LIFT_M := 0.005   # a lip lower than this is ridden over by the capsule itself
const NEAR_M := 0.15        # the landing is looked for this far on (a stair's tread)...
const AHEAD_M := 0.25       # ...then this far, when the near look found none: the capsule's centre that far past where it stands at a ledge's
							# face, so its 0.35 m round foot rests on the top (robots 23 Nov 2026: the near look landed on the corner, too steep to stand on)
const RAISES := [1.0, 0.7, 0.45]   # the lifts tried, as shares of the step: the full one, then lower under something overhead
const LOOKS := [NEAR_M, AHEAD_M]
const HOVER_MIN_LIFT_M := 0.1   # a smaller hop (a slope's bump, a lip the capsule rides) is not held level: gravity and the floor snap take it
const HOVER_M := 0.25       # after a hop the body is held level (no falling) while it moves this far onto the step (terrain_client._step_hover_m)


# Raises the body onto a step in front of it when its next move (`motion`, horizontal) would hit something no higher than
# `step` and there is room above and ahead. Returns the height gained, 0 when nothing was done.
static func try(body: CharacterBody3D, motion: Vector3, step: float) -> float:
	if motion.length_squared() < 0.000001:
		return 0.0

	# BUG-016/017: a crouching or walking player moves only 1 to 2 cm a frame, so a probe of one frame's motion sees nothing until the capsule is
	# already jammed against a lip. Look at least MIN_PROBE_M ahead, whatever the pace, so the hop starts at every pace.
	if motion.length() < MIN_PROBE_M:
		motion = motion.normalized() * MIN_PROBE_M

	var origin: Transform3D = body.global_transform

	# Nothing ahead at this height: nothing to step over.
	if not body.test_move(origin, motion):
		return 0.0

	# The full step first, then lower lifts (robots 23 Nov 2026: a doorway stands on a foundation's edge, its lintel 2 m over the top; a walker on
	# the ground below, lifted the full 0.5 m, met the lintel as it moved in, so the 0.3 m step up into the doorway stood).
	for share in RAISES:
		var raise: float = step * float(share)

		if body.test_move(origin, Vector3(0.0, raise, 0.0)):
			continue   # no room above for this lift

		for look in LOOKS:   # just past the edge first (a stair's tread), then further on (a ledge: the near look lands on its corner)
			var landed: Vector2 = _landing(body, origin, motion.normalized() * maxf(motion.length(), float(look)), raise)
			var lift: float = landed.x

			# Its contact no higher than `step` over where the body stands (a ledge's top edge, not the round foot's touch on a taller ledge's
			# corner: the hop's level hold would creep up a 0.6 m ledge on it); asked only once a landing is found.
			if lift > 0.0 and landed.y - _ground_y(body, origin) > step + 0.01:
				lift = 0.0

			if lift > 0.0:
				body.global_position.y += lift + 0.01
				return lift + 0.01

	return 0.0


# The way ahead free once raised by `raise` (a little further than this frame, so a step is not started against a wall), then the raised body moved
# `ahead` and swept down: where it lands is the top of the step. The height to lift and the contact's height, or (0, 0).
static func _landing(body: CharacterBody3D, origin: Transform3D, ahead: Vector3, raise: float) -> Vector2:
	var raised: Transform3D = origin
	raised.origin.y += raise

	if body.test_move(raised, ahead):
		return Vector2.ZERO

	raised.origin += ahead
	var result: KinematicCollision3D = KinematicCollision3D.new()

	if not body.test_move(raised, Vector3(0.0, -raise - 0.05, 0.0), result) or result.get_normal().y < 0.7:
		return Vector2.ZERO

	var lift: float = raise + result.get_travel().y
	return Vector2(lift, result.get_position().y) if lift > MIN_LIFT_M and lift <= raise else Vector2.ZERO


# The height of the ground the body stands on (its floor contact under `origin`), or -INF when none is found (then no hop: nothing to measure from).
static func _ground_y(body: CharacterBody3D, origin: Transform3D) -> float:
	var below: KinematicCollision3D = KinematicCollision3D.new()
	return below.get_position().y if body.test_move(origin, Vector3(0.0, -0.2, 0.0), below) else -INF


# The level hold after a hop (terrain_client._step_up): the metres still to go once this frame moved the body on from `from`; 0 when it stands
# on the step's top (the hold is over) or something on the step held it (no headway: it falls as ever).
static func hover_left(body: CharacterBody3D, from: Vector3, hover_m: float) -> float:
	var over: float = Vector2(body.global_position.x - from.x, body.global_position.z - from.z).length()
	return 0.0 if body.is_on_floor() or over < 0.0005 else hover_m - over
