extends RefCounted

# Swimming (River start thread, job 1 of the water refill, 2026-10-21). Pure rules shared by the
# client controller (which moves the player) and the server (which decides the exertion cost from
# where a player is, so a client cannot opt out of it). The player is a 1.8 m capsule whose
# origin is its centre; there is no real water volume in the physics, so the water is a surface
# level over the ground (WaterVolume) and swimming is a state the controller enters from it.

const WaterVolume := preload("res://src/shared/water_volume.gd")

const BODY_HEIGHT_M := 1.8
const SWIM_DEPTH_M := 1.3        # water this deep over the ground (as swim_sounds.gd SWIM_M): swimming, not wading
const FEET_UNDER_M := 0.6        # feet at least this far under the surface: in the water (standing on ice at the surface is not)
const HEAD_ABOVE_M := 0.35       # floating, the top of the head rides this far above the surface
const WALK_SPEED := 2.0          # m/s swimming
const FAST_SPEED := 3.0          # m/s swimming hard (Shift): costs more
const VERTICAL_SPEED := 2.2      # m/s up (Space) or down (Ctrl)
const VERTICAL_ACCEL := 6.0      # m/s2 the vertical speed follows its wish
const WADE_FROM_M := 0.3         # water this deep over the ground starts to slow a walker
const WADE_MIN := 0.55           # the share of walking pace left at SWIM_DEPTH_M
const CLIMB_REACH_M := 0.75      # how far ahead a bank or floe edge is looked for when climbing out
const CLIMB_MAX_M := 1.15        # a ledge up to this far above the water can be climbed onto
const CLIMB_SPEED := 5.0         # m/s upward in the pull-out


# Swimming: deep water over the ground and the feet well under the surface.
static func swimming(centre_y: float, surface: float, ground: float) -> bool:
	if is_nan(surface):
		return false

	var feet: float = centre_y - BODY_HEIGHT_M * 0.5
	return WaterVolume.depth(surface, ground) >= SWIM_DEPTH_M and feet < surface - FEET_UNDER_M


# Breath (Dave 2026-10-21): the air runs down only with the eyes under water. The eye sits this far
# above the capsule's centre, and the water must be this deep over the ground (so lying in a shallow
# ford does not count).
const EYE_ABOVE_CENTRE_M := 0.7
const HEAD_UNDER_DEPTH_M := 1.0


# Head under water: the eyes below the surface of water deep enough to dive in.
static func head_under(centre_y: float, surface: float, ground: float) -> bool:
	if is_nan(surface):
		return false

	return WaterVolume.depth(surface, ground) >= HEAD_UNDER_DEPTH_M and centre_y + EYE_ABOVE_CENTRE_M < surface


# How fast the air runs down against the one-per-second pace of ordinary swimming: slower resting
# or floating still, faster swimming hard. `speed` is the swimmer's speed in m/s.
static func breath_drain(speed: float, rest_speed: float, rest_mult: float, hard_speed: float, hard_mult: float) -> float:
	if speed <= rest_speed:
		return rest_mult

	if speed >= hard_speed:
		return hard_mult

	return 1.0


# Where the capsule's centre sits floating at the surface.
static func float_centre(surface: float) -> float:
	return surface + HEAD_ABOVE_M - BODY_HEIGHT_M * 0.5


# The share of walking pace left wading through water `depth` m deep (1 in a puddle).
static func wade_factor(depth: float) -> float:
	return lerpf(1.0, WADE_MIN, clampf((depth - WADE_FROM_M) / (SWIM_DEPTH_M - WADE_FROM_M), 0.0, 1.0))


# The vertical speed while swimming: buoyancy brings the body to float at the surface, Space
# swims up, Ctrl dives, and the speed eases there instead of jumping.
static func vertical_speed(centre_y: float, surface: float, current: float, up: bool, down: bool, delta: float) -> float:
	var wish: float = clampf((float_centre(surface) - centre_y) * 3.0, -VERTICAL_SPEED, VERTICAL_SPEED)

	if up:
		wish = VERTICAL_SPEED
	elif down:
		wish = -VERTICAL_SPEED

	return move_toward(current, wish, VERTICAL_ACCEL * delta)


# The most pace a swimmer has (fast = Shift held), m/s.
static func pace(fast: bool) -> float:
	return FAST_SPEED if fast else WALK_SPEED


# Effort (0..1+, the server's exertion scale where walking is 0.5) a swimmer puts in: steady
# strokes are well above resting, hard swimming more. Standing still in the water is treading
# water: still work.
static func effort(speed: float, treading: float = 0.55) -> float:
	return maxf(treading, 0.55 + 0.35 * clampf(speed / FAST_SPEED, 0.0, 1.0))
