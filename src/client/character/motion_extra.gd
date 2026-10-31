extends RefCounted

# More clips for the generated body (Sonny, plan 19 of CHARACTER_DESIGN_VISION.md Part 8): jump, fall, land, crouch_walk, walk_back, strafe_left, strafe_right.
# Authored in code with the same conventions as motion_proto.gd and clip_converter.gd: rotations about local X (+ swings forward, -Z), Z for sideways swings (+Z moves
# a limb toward +X, the body's right), hips position in units of the body's hips height (Skeleton3D.motion_scale turns it into metres). The numbers are first guesses
# to be tuned by eye; the shapes (anticipation, hold, follow-through) follow the stop-motion research in Part 3.
# Not yet played by the game: avatar_driver.gd `choose_clip_moving` picks them from the velocity and the airborne state, and terrain_client.gd does not call it yet.

const Proto := preload("res://src/client/character/motion_proto.gd")

const NAMES := ["jump", "fall", "land", "crouch_walk", "walk_back", "strafe_left", "strafe_right", "chop", "pick_overhead"]
# Tool work (plan 23, 31 Oct 2026): the axe is a wide, side-on, two-handed chop; the pick axe an overhead arc. The impact times are the ones the first-person swing and the hit
# use (held_item.gd HIT_AT = CHOP_IMPACT_S / CHOP_LENGTH), and the blow is sent at that moment, so the damage tick lands on the impact frame of the animation.
const CHOP_LENGTH := 0.95
const CHOP_IMPACT_S := 0.5
const PICK_LENGTH := 1.0
const PICK_IMPACT_S := 0.52
const JUMP_LENGTH := 0.55
const LAND_LENGTH := 0.4


# Squat, spring up with the arms swinging forward and up, tuck the knees at the top. t in seconds (0 to JUMP_LENGTH); the stretch at take-off is the squash and
# stretch the research asks for.
static func _jump(t: float) -> Dictionary:
	var u: float = t / JUMP_LENGTH
	var squat: float = smoothstep(0.0, 0.25, u) * (1.0 - smoothstep(0.25, 0.4, u))       # 0 to 1 and back
	var spring: float = smoothstep(0.25, 0.5, u)
	var tuck: float = smoothstep(0.55, 1.0, u)
	var knee: float = 1.2 * squat + 0.5 * tuck
	var thigh: float = 0.7 * squat + 0.35 * tuck
	var arm: float = -0.6 * squat + 2.3 * spring
	var foot: float = 0.25 * squat - 0.5 * spring * (1.0 - tuck)
	return {
		"LeftUpperLeg": Vector3(thigh, 0.0, -0.05), "RightUpperLeg": Vector3(thigh, 0.0, 0.05),
		"LeftLowerLeg": Vector3(-knee, 0.0, 0.0), "RightLowerLeg": Vector3(-knee, 0.0, 0.0),
		"LeftFoot": Vector3(foot, 0.0, 0.0), "RightFoot": Vector3(foot, 0.0, 0.0),
		"LeftUpperArm": Vector3(arm, 0.0, -0.15), "RightUpperArm": Vector3(arm, 0.0, 0.15),
		"LeftLowerArm": Vector3(0.2 + 0.2 * squat, 0.0, 0.0), "RightLowerArm": Vector3(0.2 + 0.2 * squat, 0.0, 0.0),
		"Spine": Vector3(0.25 * squat - 0.1 * spring, 0.0, 0.0), "Chest": Vector3(0.1 * squat - 0.08 * spring, 0.0, 0.0), "Head": Vector3(-0.1 * squat, 0.0, 0.0),
		"hips_bob": -0.2 * squat + 0.04 * spring,
	}


# Falling: legs apart and loose, knees slightly bent, arms out to the sides and flapping a little. p is the cycle position (0 to 1).
static func _fall(p: float) -> Dictionary:
	var f: float = sin(TAU * p)
	return {
		"LeftUpperLeg": Vector3(0.3 + 0.1 * f, 0.0, -0.18), "RightUpperLeg": Vector3(0.15 - 0.1 * f, 0.0, 0.18),
		"LeftLowerLeg": Vector3(-0.6 - 0.15 * f, 0.0, 0.0), "RightLowerLeg": Vector3(-0.45 + 0.15 * f, 0.0, 0.0),
		"LeftFoot": Vector3(0.3, 0.0, 0.0), "RightFoot": Vector3(0.3, 0.0, 0.0),
		"LeftUpperArm": Vector3(0.3 * f, 0.0, -1.2 - 0.2 * f), "RightUpperArm": Vector3(-0.3 * f, 0.0, 1.2 + 0.2 * f),
		"LeftLowerArm": Vector3(0.3, 0.0, 0.0), "RightLowerArm": Vector3(0.3, 0.0, 0.0),
		"Spine": Vector3(0.08, 0.0, 0.0), "Head": Vector3(-0.12, 0.0, 0.0),
		"hips_bob": 0.0,
	}


# Landing: drop into a deep squat on both feet (the impact), hold it for a beat, rise to the rest pose. t in seconds (0 to LAND_LENGTH).
static func _land(t: float) -> Dictionary:
	var u: float = t / LAND_LENGTH
	var down: float = smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.45, 1.0, u))
	return {
		"LeftUpperLeg": Vector3(0.95 * down, 0.0, -0.06 * down), "RightUpperLeg": Vector3(0.95 * down, 0.0, 0.06 * down),
		"LeftLowerLeg": Vector3(-1.5 * down, 0.0, 0.0), "RightLowerLeg": Vector3(-1.5 * down, 0.0, 0.0),
		"LeftFoot": Vector3(0.35 * down, 0.0, 0.0), "RightFoot": Vector3(0.35 * down, 0.0, 0.0),
		"LeftUpperArm": Vector3(0.7 * down, 0.0, -0.5 * down - 0.07), "RightUpperArm": Vector3(0.7 * down, 0.0, 0.5 * down + 0.07),
		"LeftLowerArm": Vector3(0.3 * down + 0.12, 0.0, 0.0), "RightLowerArm": Vector3(0.3 * down + 0.12, 0.0, 0.0),
		"Spine": Vector3(0.35 * down, 0.0, 0.0), "Chest": Vector3(0.15 * down, 0.0, 0.0), "Head": Vector3(-0.2 * down, 0.0, 0.0),
		"hips_bob": -0.27 * down,
	}


# Walking while crouched: low hips, bent legs, a small stride, the body leaning forward, arms ready.
static func _crouch_walk(p: float) -> Dictionary:
	var s: float = sin(TAU * p)
	var c: float = cos(TAU * p)
	var swing_l: float = maxf(c, 0.0)
	var swing_r: float = maxf(-c, 0.0)
	return {
		"LeftUpperLeg": Vector3(0.95 + 0.3 * s, 0.0, -0.05), "RightUpperLeg": Vector3(0.95 - 0.3 * s, 0.0, 0.05),
		"LeftLowerLeg": Vector3(-1.45 - 0.35 * swing_l, 0.0, 0.0), "RightLowerLeg": Vector3(-1.45 - 0.35 * swing_r, 0.0, 0.0),
		"LeftFoot": Vector3(0.45 + 0.1 * swing_l, 0.0, 0.0), "RightFoot": Vector3(0.45 + 0.1 * swing_r, 0.0, 0.0),
		"LeftUpperArm": Vector3(0.4 - 0.2 * s, 0.0, -0.1), "RightUpperArm": Vector3(0.4 + 0.2 * s, 0.0, 0.1),
		"LeftLowerArm": Vector3(0.8, 0.0, 0.0), "RightLowerArm": Vector3(0.8, 0.0, 0.0),
		"Spine": Vector3(0.45, 0.06 * s, 0.0), "Chest": Vector3(0.1, -0.04 * s, 0.0), "Head": Vector3(-0.4, 0.0, 0.0),
		"Hips": Vector3(0.0, -0.06 * s, 0.0),
		"hips_bob": -0.24 + 0.015 * cos(2.0 * TAU * p),
	}


# Walking backwards: the walk run in reverse with a smaller stride and the head turned a little to look where the body goes.
static func _walk_back(p: float) -> Dictionary:
	var pose: Dictionary = Proto._walk(1.0 - p, 0.8)
	pose["Head"] = Vector3(0.0, 0.12 * sin(TAU * p), 0.0)
	return pose


# Side stepping to the body's right (side +1) or left (side -1): the legs sweep sideways in turn with the knees lifting, the arms swing a little the other way.
static func _strafe(p: float, side: float) -> Dictionary:
	var s: float = sin(TAU * p)
	var c: float = cos(TAU * p)
	var lift_l: float = maxf(c, 0.0)
	var lift_r: float = maxf(-c, 0.0)
	return {
		"LeftUpperLeg": Vector3(0.12 * lift_l, 0.0, side * (0.22 - 0.22 * s)), "RightUpperLeg": Vector3(0.12 * lift_r, 0.0, side * (0.22 + 0.22 * s)),
		"LeftLowerLeg": Vector3(-(0.25 + 0.6 * lift_l), 0.0, 0.0), "RightLowerLeg": Vector3(-(0.25 + 0.6 * lift_r), 0.0, 0.0),
		"LeftFoot": Vector3(0.15 * lift_l, 0.0, 0.0), "RightFoot": Vector3(0.15 * lift_r, 0.0, 0.0),
		"LeftUpperArm": Vector3(0.0, 0.0, -0.1 - 0.1 * s * side), "RightUpperArm": Vector3(0.0, 0.0, 0.1 - 0.1 * s * side),
		"LeftLowerArm": Vector3(0.3, 0.0, 0.0), "RightLowerArm": Vector3(0.3, 0.0, 0.0),
		"Spine": Vector3(-0.02, 0.0, -0.04 * s * side), "Hips": Vector3(0.0, 0.0, 0.03 * s * side),
		"hips_bob": 0.018 * cos(2.0 * TAU * p),
	}


# A value at time t from keys [[time, value], ...], eased in and out between neighbouring keys (the slow wind-up and recovery, the fast stroke).
static func track(t: float, keys: Array) -> float:
	if t <= float(keys[0][0]):
		return float(keys[0][1])

	for i in range(1, keys.size()):
		if t <= float(keys[i][0]):
			var a: float = float(keys[i - 1][0])
			var b: float = float(keys[i][0])
			return lerpf(float(keys[i - 1][1]), float(keys[i][1]), smoothstep(0.0, 1.0, (t - a) / maxf(b - a, 0.0001)))

	return float(keys[keys.size() - 1][1])


# Chopping wood with an axe, right-handed, two hands on the haft, side-on to the tree: stand with the feet apart (left foot forward), wind up with the axe back over the RIGHT shoulder
# (the torso turns right, the arms go up and out), hold a beat, then a wide diagonal stroke across the body from the upper right to the lower left with the hips and torso turning into it
# (the body weight drops onto the front foot), the impact at CHOP_IMPACT_S, a follow-through past the target, a slow recovery and a short pause in the ready pose.
# Left = -X, so a positive Y turn is to the left; positive Z on an arm moves it toward the body's right. First guesses, tuned by eye on pictures (art/character_proto/chop).
static func _chop(t: float) -> Dictionary:
	var spine_y: float = track(t, [[0.0, 0.0], [0.30, -0.6], [0.37, -0.6], [0.50, 0.5], [0.60, 0.65], [0.80, 0.12], [0.95, 0.0]])
	var lean: float = track(t, [[0.0, 0.0], [0.30, -0.15], [0.37, -0.18], [0.50, 0.32], [0.60, 0.42], [0.80, 0.12], [0.95, 0.0]])
	var bob: float = track(t, [[0.0, -0.05], [0.30, -0.03], [0.37, -0.03], [0.50, -0.12], [0.60, -0.11], [0.80, -0.07], [0.95, -0.05]])
	return {
		"RightUpperArm": Vector3(track(t, [[0.0, 0.9], [0.30, 2.5], [0.37, 2.6], [0.50, 0.75], [0.60, 0.55], [0.80, 0.9], [0.95, 0.9]]), 0.0, track(t, [[0.0, 0.25], [0.30, 0.95], [0.37, 1.0], [0.50, -0.3], [0.60, -0.45], [0.80, 0.1], [0.95, 0.25]])),
		"RightLowerArm": Vector3(track(t, [[0.0, 1.3], [0.30, 1.75], [0.37, 1.75], [0.50, 0.3], [0.60, 0.35], [0.80, 1.2], [0.95, 1.3]]), 0.0, 0.0),
		"LeftUpperArm": Vector3(track(t, [[0.0, 0.9], [0.30, 2.2], [0.37, 2.25], [0.50, 0.7], [0.60, 0.5], [0.80, 0.9], [0.95, 0.9]]), 0.0, track(t, [[0.0, -0.1], [0.30, 0.3], [0.37, 0.35], [0.50, -0.2], [0.60, -0.3], [0.80, -0.1], [0.95, -0.1]])),
		"LeftLowerArm": Vector3(track(t, [[0.0, 1.3], [0.30, 1.6], [0.37, 1.6], [0.50, 0.4], [0.60, 0.45], [0.80, 1.2], [0.95, 1.3]]), 0.0, 0.0),
		"LeftHand": Vector3(track(t, [[0.0, 0.0], [0.30, 0.3], [0.50, 0.7], [0.95, 0.0]]), 0.0, 0.0), "RightHand": Vector3(track(t, [[0.0, 0.0], [0.30, 0.5], [0.50, 0.9], [0.95, 0.0]]), 0.0, 0.0),
		"Spine": Vector3(lean * 0.6, spine_y * 0.6, 0.0), "Chest": Vector3(lean * 0.4, spine_y * 0.5, 0.0), "Hips": Vector3(0.0, spine_y * 0.25, 0.0),
		"Head": Vector3(track(t, [[0.0, 0.0], [0.30, 0.1], [0.50, -0.15], [0.95, 0.0]]), -spine_y * 0.3, 0.0),
		"LeftUpperLeg": Vector3(track(t, [[0.0, 0.15], [0.37, 0.15], [0.50, 0.4], [0.80, 0.25], [0.95, 0.15]]), 0.0, -0.12), "RightUpperLeg": Vector3(track(t, [[0.0, -0.1], [0.50, 0.0], [0.95, -0.1]]), 0.0, 0.12),
		"LeftLowerLeg": Vector3(track(t, [[0.0, -0.3], [0.37, -0.3], [0.50, -0.7], [0.80, -0.45], [0.95, -0.3]]), 0.0, 0.0), "RightLowerLeg": Vector3(track(t, [[0.0, -0.3], [0.50, -0.55], [0.95, -0.3]]), 0.0, 0.0),
		"LeftFoot": Vector3(0.1, 0.0, 0.0), "RightFoot": Vector3(0.1, 0.0, 0.0),
		"hips_bob": bob,
	}


# Pick axe: an overhead arc. Both hands high over the head, the torso leaning back, then straight down in front with the body dropping into it, impact at PICK_IMPACT_S.
static func _pick_overhead(t: float) -> Dictionary:
	var lean: float = track(t, [[0.0, 0.0], [0.38, -0.3], [0.45, -0.3], [0.52, 0.6], [0.66, 0.65], [0.88, 0.15], [1.0, 0.0]])
	return {
		"RightUpperArm": Vector3(track(t, [[0.0, 0.9], [0.38, 3.0], [0.45, 3.05], [0.52, 1.0], [0.66, 0.8], [0.88, 0.9], [1.0, 0.9]]), 0.0, 0.1), "LeftUpperArm": Vector3(track(t, [[0.0, 0.9], [0.38, 3.0], [0.45, 3.05], [0.52, 1.0], [0.66, 0.8], [0.88, 0.9], [1.0, 0.9]]), 0.0, -0.1),
		"RightLowerArm": Vector3(track(t, [[0.0, 1.3], [0.38, 0.5], [0.45, 0.5], [0.52, 0.3], [0.66, 0.4], [0.88, 1.2], [1.0, 1.3]]), 0.0, 0.0), "LeftLowerArm": Vector3(track(t, [[0.0, 1.3], [0.38, 0.5], [0.45, 0.5], [0.52, 0.3], [0.66, 0.4], [0.88, 1.2], [1.0, 1.3]]), 0.0, 0.0),
		"Spine": Vector3(lean * 0.6, 0.0, 0.0), "Chest": Vector3(lean * 0.4, 0.0, 0.0), "Head": Vector3(track(t, [[0.0, 0.0], [0.45, 0.2], [0.52, -0.25], [1.0, 0.0]]), 0.0, 0.0),
		"LeftUpperLeg": Vector3(track(t, [[0.0, 0.3], [0.45, 0.25], [0.52, 0.55], [0.88, 0.4], [1.0, 0.3]]), 0.0, -0.1), "RightUpperLeg": Vector3(track(t, [[0.0, 0.3], [0.45, 0.25], [0.52, 0.55], [0.88, 0.4], [1.0, 0.3]]), 0.0, 0.1),
		"LeftLowerLeg": Vector3(track(t, [[0.0, -0.5], [0.52, -0.9], [1.0, -0.5]]), 0.0, 0.0), "RightLowerLeg": Vector3(track(t, [[0.0, -0.5], [0.52, -0.9], [1.0, -0.5]]), 0.0, 0.0),
		"hips_bob": track(t, [[0.0, -0.05], [0.45, -0.03], [0.52, -0.16], [0.66, -0.14], [0.88, -0.07], [1.0, -0.05]]),
	}


# The nine clips as an AnimationLibrary for a skeleton. They use the same bone names as the converted library, so a body can add them to its own.
static func library(skeleton: Skeleton3D) -> AnimationLibrary:
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.add_animation("jump", Proto._clip(skeleton, JUMP_LENGTH, 14, false, func(t: float) -> Dictionary: return _jump(t), false, true))
	lib.add_animation("fall", Proto._clip(skeleton, 0.7, 12, true, func(t: float) -> Dictionary: return _fall(t / 0.7), false, true))
	lib.add_animation("land", Proto._clip(skeleton, LAND_LENGTH, 12, false, func(t: float) -> Dictionary: return _land(t), false, true))
	lib.add_animation("crouch_walk", Proto._clip(skeleton, 1.1, 16, true, func(t: float) -> Dictionary: return _crouch_walk(t / 1.1), false, true))
	lib.add_animation("walk_back", Proto._clip(skeleton, 1.2, 16, true, func(t: float) -> Dictionary: return _walk_back(t / 1.2), false, true))
	lib.add_animation("strafe_left", Proto._clip(skeleton, 0.9, 16, true, func(t: float) -> Dictionary: return _strafe(t / 0.9, -1.0), false, true))
	lib.add_animation("strafe_right", Proto._clip(skeleton, 0.9, 16, true, func(t: float) -> Dictionary: return _strafe(t / 0.9, 1.0), false, true))
	lib.add_animation("chop", Proto._clip(skeleton, CHOP_LENGTH, 38, false, func(t: float) -> Dictionary: return _chop(t), false, true, true))
	lib.add_animation("pick_overhead", Proto._clip(skeleton, PICK_LENGTH, 40, false, func(t: float) -> Dictionary: return _pick_overhead(t), false, true, true))
	return lib
