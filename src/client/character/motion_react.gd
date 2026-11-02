extends RefCounted

# Reaction clips for the generated body (Sonny, plan 21 of CHARACTER_DESIGN_VISION.md Part 8; the comic panic of Part 5.8): panic_run, panic_clutch, startle, glance.
# Same conventions as motion_extra.gd. They are stepped (held poses, INTERPOLATION_NEAREST, 24 poses a second) because the research on stop-motion comedy says held
# poses read as acting where smooth in-betweens read as a puppet. Every clip keys all bones, so playing one with AnimationPlayer.play leaves no limb frozen in an
# earlier pose. The numbers are first guesses to be tuned by eye.

const Proto := preload("res://src/client/character/motion_proto.gd")
const Extra := preload("res://src/client/character/motion_extra.gd")

const NAMES := ["panic_run", "panic_clutch", "startle", "glance"]
const PANIC_RUN_LENGTH := 0.5
const CLUTCH_LENGTH := 1.2
const STARTLE_LENGTH := 0.6
const GLANCE_LENGTH := 1.2
const STEP := 1.0 / 24.0        # a pose is held for this long


# Run away screaming: a fast run with both arms flung overhead and flapping in opposite directions, the head thrown back, the whole body bobbing.
static func _panic_run(p: float) -> Dictionary:
	var pose: Dictionary = Proto._walk(p, 1.7)
	var f: float = sin(TAU * 2.0 * p)
	pose["LeftUpperArm"] = Vector3(2.7 + 0.45 * f, 0.0, -0.35 - 0.35 * f)
	pose["RightUpperArm"] = Vector3(2.7 - 0.45 * f, 0.0, 0.35 + 0.35 * f)
	pose["LeftLowerArm"] = Vector3(0.3 + 0.6 * maxf(f, 0.0), 0.0, 0.0)
	pose["RightLowerArm"] = Vector3(0.3 + 0.6 * maxf(-f, 0.0), 0.0, 0.0)
	pose["LeftHand"] = Vector3(0.0, 0.0, 0.5 * f)
	pose["RightHand"] = Vector3(0.0, 0.0, 0.5 * f)
	pose["Head"] = Vector3(-0.35, 0.25 * f, 0.1 * f)
	pose["Chest"] = Vector3(-0.12, -0.1 * f, 0.0)
	pose["Spine"] = Vector3(-0.1, 0.1 * f, 0.0)
	pose["hips_bob"] = 0.045 * cos(2.0 * TAU * p)
	return pose


# Both hands clutch the head, the shoulders shake, the knees knock (the existing upper-body panic plus legs that tremble). t in seconds.
static func _panic_clutch(t: float) -> Dictionary:
	var pose: Dictionary = Proto._panic(t)
	var shake: float = sin(TAU * 6.0 * t)
	pose["LeftUpperLeg"] = Vector3(0.1, 0.0, -0.05 + 0.03 * shake)
	pose["RightUpperLeg"] = Vector3(0.1, 0.0, 0.05 - 0.03 * shake)
	pose["LeftLowerLeg"] = Vector3(-0.3 - 0.1 * shake, 0.0, 0.0)
	pose["RightLowerLeg"] = Vector3(-0.3 + 0.1 * shake, 0.0, 0.0)
	pose["hips_bob"] = -0.035 + 0.01 * shake
	return pose


# A startled hop: crouch a hair, jump a few centimetres with the arms flung up and the head back, land with the knees bent. t in seconds.
static func _startle(t: float) -> Dictionary:
	var u: float = t / STARTLE_LENGTH
	var jump: float = sin(PI * clampf((u - 0.1) / 0.5, 0.0, 1.0))
	var settle: float = smoothstep(0.6, 0.8, u) * (1.0 - smoothstep(0.8, 1.0, u))
	return {
		"LeftUpperArm": Vector3(2.0 * jump, 0.0, -0.9 * jump - 0.07), "RightUpperArm": Vector3(2.0 * jump, 0.0, 0.9 * jump + 0.07),
		"LeftLowerArm": Vector3(0.5 * jump + 0.12, 0.0, 0.0), "RightLowerArm": Vector3(0.5 * jump + 0.12, 0.0, 0.0),
		"LeftUpperLeg": Vector3(0.3 * jump + 0.5 * settle, 0.0, 0.0), "RightUpperLeg": Vector3(0.3 * jump + 0.5 * settle, 0.0, 0.0),
		"LeftLowerLeg": Vector3(-0.5 * jump - 0.8 * settle, 0.0, 0.0), "RightLowerLeg": Vector3(-0.5 * jump - 0.8 * settle, 0.0, 0.0),
		"Chest": Vector3(-0.2 * jump, 0.0, 0.0), "Head": Vector3(-0.3 * jump, 0.0, 0.0), "Spine": Vector3(0.0, 0.0, 0.0),
		"hips_bob": 0.07 * jump - 0.1 * settle,
	}


# A nervous glance: the shoulders rise, the head turns one way, holds, turns back the other way, holds, and comes to rest. t in seconds.
static func _glance(t: float) -> Dictionary:
	var u: float = t / GLANCE_LENGTH
	var look: float = 0.0

	if u < 0.15:
		look = smoothstep(0.0, 0.15, u)
	elif u < 0.45:
		look = 1.0
	elif u < 0.6:
		look = lerpf(1.0, -1.0, smoothstep(0.45, 0.6, u))
	elif u < 0.85:
		look = -1.0
	else:
		look = -1.0 * (1.0 - smoothstep(0.85, 1.0, u))

	var hunch: float = smoothstep(0.0, 0.15, u) * (1.0 - smoothstep(0.85, 1.0, u))
	return {
		"Head": Vector3(0.0, 0.9 * look, 0.0), "Neck": Vector3(0.0, 0.3 * look, 0.0), "Chest": Vector3(0.0, 0.25 * look, 0.0),
		"LeftShoulder": Vector3(0.0, 0.0, 0.2 * hunch), "RightShoulder": Vector3(0.0, 0.0, -0.2 * hunch),
		"LeftUpperArm": Vector3(0.1 * hunch, 0.0, -0.07), "RightUpperArm": Vector3(0.1 * hunch, 0.0, 0.07),
		"LeftLowerArm": Vector3(0.4 * hunch + 0.12, 0.0, 0.0), "RightLowerArm": Vector3(0.4 * hunch + 0.12, 0.0, 0.0),
		"hips_bob": -0.01 * hunch,
	}


# The four clips as an AnimationLibrary, all bones keyed, stepped on twos (24 poses a second).
static func library(skeleton: Skeleton3D) -> AnimationLibrary:
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.add_animation("panic_run", Proto._clip(skeleton, PANIC_RUN_LENGTH, 12, true, func(t: float) -> Dictionary: return _panic_run(t / PANIC_RUN_LENGTH), true, true, true))
	lib.add_animation("panic_clutch", Proto._clip(skeleton, CLUTCH_LENGTH, 29, true, func(t: float) -> Dictionary: return _panic_clutch(t), true, true, true))
	lib.add_animation("startle", Proto._clip(skeleton, STARTLE_LENGTH, 14, false, func(t: float) -> Dictionary: return _startle(t), true, true, true))
	lib.add_animation("glance", Proto._clip(skeleton, GLANCE_LENGTH, 29, false, func(t: float) -> Dictionary: return _glance(t), true, true, true))
	return lib
