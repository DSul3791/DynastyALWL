extends RefCounted

# Converts the clips of the old ragdoll rig (src/client/ragdoll_body.gd) to the generated skeleton of body_generator.gd, so no clip is authored twice
# (Sonny, plan 8 of CHARACTER_DESIGN_VISION.md Part 8). The old clips key rotations of 17 bones plus the hips position; the new skeleton has the same pose
# convention (rotation about local X, + swings forward, rest pose with the arms hanging) and humanoid names, so a conversion is a rename of the track paths and a
# change of the hips position to units of hips height (the skeleton's motion_scale puts it back to metres, see motion_proto.gd and Part 3.11.3, M8).

const OLD_HIPS_Y := 0.95            # the old rig's hips height: its hips position keys are in metres, around this value

const BONE_MAP := {
	"hips": "Hips", "spine": "Spine", "chest": "Chest", "neck": "Neck", "head": "Head",
	"arm_r": "RightUpperArm", "forearm_r": "RightLowerArm", "hand_r": "RightHand",
	"arm_l": "LeftUpperArm", "forearm_l": "LeftLowerArm", "hand_l": "LeftHand",
	"thigh_r": "RightUpperLeg", "shin_r": "RightLowerLeg", "foot_r": "RightFoot",
	"thigh_l": "LeftUpperLeg", "shin_l": "LeftLowerLeg", "foot_l": "LeftFoot",
}


# The new name of an old track path ("Skeleton3D:arm_r" becomes "Skeleton3D:RightUpperArm"), or "" when the bone has no counterpart.
static func new_path(old: NodePath) -> NodePath:
	var text: String = String(old)
	var colon: int = text.find(":")

	if colon < 0:
		return NodePath()

	var bone: String = text.substr(colon + 1)

	if not BONE_MAP.has(bone):
		return NodePath()

	return NodePath(text.substr(0, colon + 1) + String(BONE_MAP[bone]))


# One converted copy of an animation (rotation and position tracks of mapped bones only; other track types are not used by the old clips).
static func convert_clip(old: Animation) -> Animation:
	var out: Animation = Animation.new()
	out.length = old.length
	out.loop_mode = old.loop_mode
	out.step = old.step

	for t in range(old.get_track_count()):
		var path: NodePath = new_path(old.track_get_path(t))

		if path.is_empty():
			continue

		var type: int = old.track_get_type(t)

		if type != Animation.TYPE_ROTATION_3D and type != Animation.TYPE_POSITION_3D:
			continue

		var nt: int = out.add_track(type)
		out.track_set_path(nt, path)
		out.track_set_interpolation_type(nt, old.track_get_interpolation_type(t))
		out.track_set_interpolation_loop_wrap(nt, old.track_get_interpolation_loop_wrap(t))

		for k in range(old.track_get_key_count(t)):
			var time: float = old.track_get_key_time(t, k)

			if type == Animation.TYPE_ROTATION_3D:
				out.rotation_track_insert_key(nt, time, old.track_get_key_value(t, k) as Quaternion)
			else:
				out.position_track_insert_key(nt, time, (old.track_get_key_value(t, k) as Vector3) / OLD_HIPS_Y)

	return out


# Every clip of an old-rig AnimationPlayer as a library for the new skeleton.
static func convert_library(player: AnimationPlayer) -> AnimationLibrary:
	var lib: AnimationLibrary = AnimationLibrary.new()

	for clip in player.get_animation_list():
		lib.add_animation(clip, convert_clip(player.get_animation(clip)))

	return lib
