extends RefCounted

# More clips for the generated body (Sonny, plan 19 of CHARACTER_DESIGN_VISION.md Part 8): jump, fall, land, crouch_walk, walk_back, strafe_left, strafe_right.
# Authored in code with the same conventions as motion_proto.gd and clip_converter.gd: rotations about local X (+ swings forward, -Z), Z for sideways swings (+Z moves
# a limb toward +X, the body's right), hips position in units of the body's hips height (Skeleton3D.motion_scale turns it into metres). The numbers are first guesses
# to be tuned by eye; the shapes (anticipation, hold, follow-through) follow the stop-motion research in Part 3.
# Not yet played by the game: avatar_driver.gd `choose_clip_moving` picks them from the velocity and the airborne state, and terrain_client.gd does not call it yet.

const Proto := preload("res://src/client/character/motion_proto.gd")

const NAMES := ["jump", "fall", "land", "crouch_walk", "walk_back", "strafe_left", "strafe_right"]
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


# The seven clips as an AnimationLibrary for a skeleton. They use the same bone names as the converted library, so a body can add them to its own.
static func library(skeleton: Skeleton3D) -> AnimationLibrary:
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.add_animation("jump", Proto._clip(skeleton, JUMP_LENGTH, 14, false, func(t: float) -> Dictionary: return _jump(t), false, true))
	lib.add_animation("fall", Proto._clip(skeleton, 0.7, 12, true, func(t: float) -> Dictionary: return _fall(t / 0.7), false, true))
	lib.add_animation("land", Proto._clip(skeleton, LAND_LENGTH, 12, false, func(t: float) -> Dictionary: return _land(t), false, true))
	lib.add_animation("crouch_walk", Proto._clip(skeleton, 1.1, 16, true, func(t: float) -> Dictionary: return _crouch_walk(t / 1.1), false, true))
	lib.add_animation("walk_back", Proto._clip(skeleton, 1.2, 16, true, func(t: float) -> Dictionary: return _walk_back(t / 1.2), false, true))
	lib.add_animation("strafe_left", Proto._clip(skeleton, 0.9, 16, true, func(t: float) -> Dictionary: return _strafe(t / 0.9, -1.0), false, true))
	lib.add_animation("strafe_right", Proto._clip(skeleton, 0.9, 16, true, func(t: float) -> Dictionary: return _strafe(t / 0.9, 1.0), false, true))
	return lib
