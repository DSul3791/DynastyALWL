extends RefCounted

# Stepping over low obstacles (logs, stones, stumps) while walking, jogging or running. data/movement.json step_up_m is the limit.


# Raises the body onto a step in front of it when its next move (`motion`, horizontal) would hit something no higher than
# `step` and there is room above and ahead. Returns the height gained, 0 when nothing was done.
static func try(body: CharacterBody3D, motion: Vector3, step: float) -> float:
	if motion.length_squared() < 0.000001:
		return 0.0

	var origin: Transform3D = body.global_transform

	# Nothing ahead at this height: nothing to step over.
	if not body.test_move(origin, motion):
		return 0.0

	# Room above, and the way ahead free once raised (a little further than this frame, so a step is not started against a wall).
	var raised: Transform3D = origin
	raised.origin.y += step

	if body.test_move(origin, Vector3(0.0, step, 0.0)) or body.test_move(raised, motion.normalized() * maxf(motion.length(), 0.15)):
		return 0.0

	# Move the raised body ahead and sweep it down: where it lands is the top of the step.
	var ahead: Transform3D = raised
	ahead.origin += motion.normalized() * maxf(motion.length(), 0.15)
	var result: KinematicCollision3D = KinematicCollision3D.new()

	if not body.test_move(ahead, Vector3(0.0, -step - 0.05, 0.0), result) or result.get_normal().y < 0.7:
		return 0.0

	var lift: float = step + result.get_travel().y

	if lift <= 0.02 or lift > step:
		return 0.0

	body.global_position.y += lift + 0.01
	return lift + 0.01
