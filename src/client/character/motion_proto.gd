extends RefCounted

# PROTOTYPE (Sonny, 2026-10-30), plan 2 in CHARACTER_DESIGN_VISION.md Part 8: clips and an AnimationTree for the generated skeleton of
# body_generator.gd. It answers four questions before anything is built for real:
#   1. Can an AnimationTree drive a Skeleton3D and AnimationPlayer that were both built in code?
#   2. Does a filtered one-shot play an upper-body clip while the legs keep walking?
#   3. Do held (stepped) poses work with INTERPOLATION_NEAREST?
#   4. Do rotation-only clips plus a hips position scaled by Skeleton3D.motion_scale fit bodies with different bone lengths?
# Rotations are about local X (+ swings an arm or leg forward, -Z), as in ragdoll_body.gd; "Left" is -X.

const Generator := preload("res://src/client/character/body_generator.gd")

const UPPER_BODY := ["Spine", "Chest", "Neck", "Head", "LeftShoulder", "LeftUpperArm", "LeftLowerArm", "LeftHand",
	"RightShoulder", "RightUpperArm", "RightLowerArm", "RightHand"]
const HIPS_REF := 1.0               # hips position keys are stored in units of the body's own hips height (see Skeleton3D.motion_scale)
const PANIC_STEP := 1.0 / 12.0      # panic poses are held for this long (on twos at 24 poses a second)


# Pose functions return {bone name: Vector3 euler radians} plus "hips_bob" (metres, relative).
static func _walk(p: float, k: float) -> Dictionary:
	var s: float = sin(TAU * p)
	var c: float = cos(TAU * p)
	var swing_l: float = maxf(c, 0.0)
	var swing_r: float = maxf(-c, 0.0)
	return {
		"LeftUpperLeg": Vector3(0.45 * k * s, 0.0, 0.0), "RightUpperLeg": Vector3(-0.45 * k * s, 0.0, 0.0),
		"LeftLowerLeg": Vector3(-(0.3 + 0.75 * k * swing_l), 0.0, 0.0), "RightLowerLeg": Vector3(-(0.3 + 0.75 * k * swing_r), 0.0, 0.0),
		"LeftFoot": Vector3(0.2 * swing_l, 0.0, 0.0), "RightFoot": Vector3(0.2 * swing_r, 0.0, 0.0),
		"LeftUpperArm": Vector3(-0.3 * k * s, 0.0, -0.06), "RightUpperArm": Vector3(0.3 * k * s, 0.0, 0.06),
		"LeftLowerArm": Vector3(0.4 * k, 0.0, 0.0), "RightLowerArm": Vector3(0.4 * k, 0.0, 0.0),
		"Hips": Vector3(0.0, -0.08 * k * s, 0.0), "Spine": Vector3(-0.03 * k, 0.08 * k * s, 0.0), "Chest": Vector3(0.0, -0.05 * k * s, 0.0),
		"hips_bob": 0.02 * k * cos(2.0 * TAU * p),
	}


static func _idle(p: float) -> Dictionary:
	var breath: float = sin(TAU * p)
	return {"Chest": Vector3(0.02 * breath, 0.0, 0.0), "LeftUpperArm": Vector3(0.0, 0.0, -0.07), "RightUpperArm": Vector3(0.0, 0.0, 0.07),
		"LeftLowerArm": Vector3(0.12, 0.0, 0.0), "RightLowerArm": Vector3(0.12, 0.0, 0.0), "hips_bob": 0.004 * breath}


# Comic panic, upper body only: both hands clutch the head, then the arms flail overhead, the shoulders shake. t in seconds.
static func _panic(t: float) -> Dictionary:
	var flail: float = sin(TAU * 2.5 * t)
	var clutch: float = smoothstep(0.0, 0.25, t)
	return {
		"LeftUpperArm": Vector3(lerpf(0.0, 2.6, clutch) + 0.5 * flail, 0.0, lerpf(-0.07, -0.5, clutch) - 0.4 * flail),
		"RightUpperArm": Vector3(lerpf(0.0, 2.6, clutch) - 0.5 * flail, 0.0, lerpf(0.07, 0.5, clutch) + 0.4 * flail),
		"LeftLowerArm": Vector3(lerpf(0.12, 1.9, clutch), 0.0, 0.0), "RightLowerArm": Vector3(lerpf(0.12, 1.9, clutch), 0.0, 0.0),
		"Chest": Vector3(-0.15 * clutch, 0.12 * flail, 0.0), "Head": Vector3(-0.25 * clutch, -0.2 * flail, 0.0),
		"LeftShoulder": Vector3(0.0, 0.0, 0.25 * clutch), "RightShoulder": Vector3(0.0, 0.0, -0.25 * clutch),
	}


# Builds an Animation: tracks only for the bones that appear in the pose function (and the hips position when `hips`), keyed `frames` times.
static func _clip(skeleton: Skeleton3D, length: float, frames: int, loop: bool, pose: Callable, stepped: bool, hips: bool, all_bones: bool = false) -> Animation:
	var anim: Animation = Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	var tracks: Dictionary = {}
	var sample: Dictionary = pose.call(0.0)

	for i in range(skeleton.get_bone_count()):
		var name: String = skeleton.get_bone_name(i)

		if all_bones or sample.has(name) or (name in UPPER_BODY and stepped):
			var tr: int = anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(tr, NodePath("Skeleton3D:" + name))

			if stepped:
				anim.track_set_interpolation_type(tr, Animation.INTERPOLATION_NEAREST)

			tracks[name] = tr

	var hips_track: int = -1

	if hips:
		hips_track = anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(hips_track, NodePath("Skeleton3D:Hips"))

	for k in range(frames + 1):
		var t: float = length * float(k) / float(frames)
		var values: Dictionary = pose.call(t)

		for name in tracks:
			var e: Vector3 = values.get(name, Vector3.ZERO)
			anim.rotation_track_insert_key(tracks[name], t, Quaternion.from_euler(e))

		if hips_track >= 0:
			anim.position_track_insert_key(hips_track, t, Vector3(0.0, HIPS_REF + float(values.get("hips_bob", 0.0)), 0.0))

	return anim


# Adds an AnimationPlayer (clips idle, walk, run, panic) and an AnimationTree to `rig` (the Node3D returned by Generator.make_node)
# and returns {player, tree}. The hips position keys are in units of hips height, so the skeleton's motion_scale is set from its rest.
static func attach(rig: Node3D, skeleton: Skeleton3D) -> Dictionary:
	skeleton.motion_scale = skeleton.get_bone_rest(skeleton.find_bone("Hips")).origin.y / HIPS_REF
	var player: AnimationPlayer = AnimationPlayer.new()
	player.name = "AnimationPlayer"
	rig.add_child(player)
	var lib: AnimationLibrary = AnimationLibrary.new()
	lib.add_animation("idle", _clip(skeleton, 3.0, 12, true, func(t: float) -> Dictionary: return _idle(t / 3.0), false, true))
	lib.add_animation("walk", _clip(skeleton, 1.0, 16, true, func(t: float) -> Dictionary: return _walk(t, 1.0), false, true))
	lib.add_animation("run", _clip(skeleton, 0.62, 16, true, func(t: float) -> Dictionary: return _walk(t / 0.62, 1.7), false, true))
	lib.add_animation("panic", _clip(skeleton, 1.2, 14, false, func(t: float) -> Dictionary: return _panic(t), true, false))
	player.add_animation_library("", lib)

	var tree: AnimationTree = AnimationTree.new()
	tree.name = "AnimationTree"
	rig.add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	var root: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var space: AnimationNodeBlendSpace1D = AnimationNodeBlendSpace1D.new()

	space.min_space = 0.0
	space.max_space = 4.0          # the default range is -1 to 1; points outside it are not used
	space.value_label = "m/s"

	for entry in [["idle", 0.0], ["walk", 1.4], ["run", 3.5]]:
		var node: AnimationNodeAnimation = AnimationNodeAnimation.new()
		node.animation = entry[0]
		space.add_blend_point(node, entry[1], -1, StringName(entry[0]))

	space.sync_mode = AnimationNodeBlendSpace1D.SYNC_MODE_CYCLIC_MUTABLE
	var panic: AnimationNodeAnimation = AnimationNodeAnimation.new()
	panic.animation = "panic"
	var shot: AnimationNodeOneShot = AnimationNodeOneShot.new()
	shot.filter_enabled = true

	for name in UPPER_BODY:
		shot.set_filter_path(NodePath("Skeleton3D:" + name), true)

	shot.fadein_time = 0.08
	shot.fadeout_time = 0.2
	root.add_node("Loco", space, Vector2(0.0, 0.0))
	root.add_node("Panic", panic, Vector2(0.0, 200.0))
	root.add_node("Shot", shot, Vector2(300.0, 100.0))
	root.connect_node("Shot", 0, "Loco")
	root.connect_node("Shot", 1, "Panic")
	root.connect_node("output", 0, "Shot")
	tree.tree_root = root
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	return {"player": player, "tree": tree}
