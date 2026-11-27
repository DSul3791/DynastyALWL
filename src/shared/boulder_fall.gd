extends RefCounted

# A boulder dug under drops into the hole (boulders step 2, PLAN_big_boulders.md; Dave 27 Nov 2026: "if you dig out under them they should fall
# on your head or in the hole"). Rocks are laid where they have long since settled ("we should be placing them wherever the should have already
# settled after millions of years"), so nothing moves until the ground under one is dug. The server moves the rock by rule (straight down, no
# physics bodies) and judges once who it lands on; the client plays the drop over fall_s. Both read these.

const GRAVITY := 9.8
const HARM_DROP_M := 0.5     # a rock that settles less than this hurts nobody (a few spades under its middle; PROVISIONAL BF-1)
const GLANCE_M := 0.3        # a body whose middle is this far past the rock's edge is struck by its side as it comes down (PROVISIONAL BF-2)
const GLANCE_HP := 10.0      # what a glancing blow leaves (Dave: "leave them with low health"; PROVISIONAL BF-3)
const GLANCE_FAINT_M := 1.0  # a glancing blow from a drop this far or more knocks them out (Dave: "maybe instantly knock them out"; PROVISIONAL BF-4)
const GLANCE_ANIMAL_SHARE := 0.8   # the share of an animal's health a glancing blow takes (PROVISIONAL BF-5)
const UNDER_DEPTH_M := 2.5   # a body this far below the rock's new spot is not under it (one down a tunnel below)
const NONE := 0
const GLANCED := 1
const CRUSHED := 2


# Seconds a rock takes to fall `drop` metres from rest.
static func fall_s(drop: float) -> float:
	return maxf(sqrt(2.0 * maxf(drop, 0.0) / GRAVITY), 0.1)


# What a rock of radius `r` (now) that falls from `from` to `to` does to a body standing at `at` (feet): CRUSHED when its middle is under the rock's
# footprint (Dave: "it can kill anything and anyone it hits if they are directly under it"), GLANCED when the rock's side strikes it as it comes
# down ("if they just get hit and thrown by a glancing blow it should leave them with low health"), else NONE. A body standing on the rock (its
# feet at or over the rock's top) rides it down unhurt.
static func hit(r: float, from: Vector3, to: Vector3, top_share: float, at: Vector3) -> int:
	if from.y - to.y < HARM_DROP_M or r <= 0.0:
		return NONE

	if at.y >= from.y + top_share * r - 0.1 or at.y < to.y - UNDER_DEPTH_M:
		return NONE   # on top of it, or far below

	var d: float = Vector2(at.x - from.x, at.z - from.z).length()

	if d < r:
		return CRUSHED

	return GLANCED if d < r + GLANCE_M else NONE
