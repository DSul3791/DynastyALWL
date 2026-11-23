extends RefCounted

# Stepping over low obstacles (logs, stones, stumps) while walking, jogging or running. data/movement.json step_up_m is the limit.


const MIN_PROBE_M := 0.12   # the least distance ahead that is probed
const MIN_LIFT_M := 0.005   # a lip lower than this is ridden over by the capsule itself
const NEAR_M := 0.15        # the landing is looked for this far on (a stair's tread)...
const AHEAD_M := 0.25       # ...then this far, when the near look found none: the capsule's centre that far past where it stands at a ledge's
							# face, so its 0.35 m round foot rests on the top (robots 23 Nov 2026: the near look landed on the corner, too steep to stand on)
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

	# Where the body stands now: a landing's contact no higher than `step` above it (a ledge's top edge, not the round foot's touch on a taller
	# ledge's corner: the hop's level hold would creep up a 0.6 m ledge on it).
	var below: KinematicCollision3D = KinematicCollision3D.new()
	var ground_y: float = below.get_position().y if body.test_move(origin, Vector3(0.0, -0.2, 0.0), below) else NAN

	# The full step first, then lower lifts (robots 23 Nov 2026: a doorway stands on a foundation's edge, its lintel 2 m over the top; a walker on
	# the ground below, lifted the full 0.5 m, met the lintel as it moved in, so the 0.3 m step up into the doorway stood).
	for raise in [step, step * 0.7, step * 0.45]:
		if body.test_move(origin, Vector3(0.0, raise, 0.0)):
			continue   # no room above for this lift

		for look in [NEAR_M, AHEAD_M]:   # just past the edge first (a stair's tread), then further on (a ledge: the near look lands on its corner)
			var lift: float = _landing(body, origin, motion.normalized() * maxf(motion.length(), look), raise, step, ground_y)

			if lift > 0.0:
				body.global_position.y += lift + 0.01
				return lift + 0.01

	return 0.0


# The way ahead free once raised by `raise` (a little further than this frame, so a step is not started against a wall), then the raised body moved
# `ahead` and swept down: where it lands is the top of the step, its contact no more than `step` over `ground_y` (where it stands; NAN: not
# known). The height to lift, or 0.
static func _landing(body: CharacterBody3D, origin: Transform3D, ahead: Vector3, raise: float, step: float, ground_y: float) -> float:
	var raised: Transform3D = origin
	raised.origin.y += raise

	if body.test_move(raised, ahead):
		return 0.0

	raised.origin += ahead
	var result: KinematicCollision3D = KinematicCollision3D.new()

	if not body.test_move(raised, Vector3(0.0, -raise - 0.05, 0.0), result) or result.get_normal().y < 0.7:
		return 0.0

	if not is_nan(ground_y) and result.get_position().y - ground_y > step:
		return 0.0   # the touch is higher than a step over where it stands

	var lift: float = raise + result.get_travel().y
	return lift if lift > MIN_LIFT_M and lift <= raise else 0.0


# The level hold after a hop (terrain_client._step_up): the metres still to go once this frame moved the body on from `from`; 0 when it stands
# on the step's top (the hold is over) or something on the step held it (no headway: it falls as ever).
static func hover_left(body: CharacterBody3D, from: Vector3, hover_m: float) -> float:
	var over: float = Vector2(body.global_position.x - from.x, body.global_position.z - from.z).length()
	return 0.0 if body.is_on_floor() or over < 0.0005 else hover_m - over
