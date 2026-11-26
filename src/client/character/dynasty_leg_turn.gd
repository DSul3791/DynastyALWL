extends SkeletonModifier3D

# The legs turn toward the way the body moves (foot slide, 26 Nov 2026, Dave's basics: smooth movement, no sliding). Dave's body has a forward gait and four
# crouched walks but no sideways or diagonal walk standing up, so walking sideways at 3.2 m/s the forward clip's feet slid 62 cm along the ground at every step
# and 43 cm on a diagonal; crouch-walking on a diagonal 24 cm (measured offline from the glb, /mnt/project-files/foot-slide/). After the clip is drawn the hips
# turn about the vertical by the angle between the clip's own direction and the travel (avatar_driver.gd leg_turn, at most 80 degrees standing and 60
# crouched) and the three spine bones turn back by a third each, so the chest, the head, the arms and whatever is held still face where the player looks.
# Offline the slide falls to 12-18 cm sideways (the turn stops at 80 degrees) and 9-12 cm on a diagonal, about the clip's own heel roll walking forward
# (8-10 cm); crouched 3-6 cm. The turn eases in and out (TURN_RAD_S), so the hips never snap. Drawing only: every client works it out from the body's own
# velocity (avatar_driver.gd clip_for sets the meta `leg_local` on the body, for the local player and for each other player alike).
# Made by dynasty_body.gd under the skeleton after the Proportions and Breath modifiers; `player` is the body's AnimationPlayer, `body` the body node.

const AvatarDriverScript := preload("res://src/client/character/avatar_driver.gd")

const P := "mixamorig_"
const SPINE := ["Spine", "Spine1", "Spine2"]
const TURN_RAD_S := 5.0                 # how fast the legs swing to a new angle (80 degrees in about 0.3 s)

var player: AnimationPlayer
var body: Node3D
var angle: float = 0.0                  # radians, + to the body's left: where the legs point now
var _hips: int = -2
var _spine: Array = []


# The eased angle after one frame toward `target`.
static func step_angle(now: float, target: float, delta: float) -> float:
	return move_toward(now, target, TURN_RAD_S * delta)


func _process_modification_with_delta(delta: float) -> void:
	var s: Skeleton3D = get_skeleton()

	if s == null or body == null or not is_instance_valid(body):
		return

	# The clip it holds: `assigned_animation`, which a paused player keeps (current_animation is empty while paused, so a still of a paused pose got no turn;
	# Lane A pr1961 stills, 26 Nov 2026). Playing, the two are the same.
	var clip: String = String(player.assigned_animation) if player != null else ""
	var local: Vector2 = body.get_meta("leg_local", Vector2.ZERO)
	var target: float = AvatarDriverScript.leg_turn(clip, local, bool(body.get_meta("backward", false)))
	angle = step_angle(angle, target, delta)

	if absf(angle) < 0.001:
		return

	if _hips == -2:
		_hips = s.find_bone(P + "Hips")

		for bone in SPINE:
			_spine.append(s.find_bone(P + bone))

	if _hips < 0 or _spine.has(-1):
		return

	# Skeleton space is up +Y, front +Z, left +X (dynasty_body.gd), so a turn by + angle about +Y swings the front toward the left. Each bone's parent frame after
	# its parent turned is worked out here (head_look.gd does the same) rather than read back from the skeleton straight after a pose write.
	var turn: Quaternion = Quaternion(Vector3.UP, angle)
	var back: Quaternion = Quaternion(Vector3.UP, -angle / float(SPINE.size()))
	var parent: Quaternion = _global_rot(s, s.get_bone_parent(_hips))
	var before: Quaternion = parent * s.get_bone_pose_rotation(_hips)
	_turn_bone(s, _hips, turn, parent)
	parent = turn * before

	for i in _spine:
		before = parent * s.get_bone_pose_rotation(i)
		_turn_bone(s, i, back, parent)
		parent = back * before


static func _global_rot(s: Skeleton3D, bone: int) -> Quaternion:
	return s.get_bone_global_pose(bone).basis.get_rotation_quaternion() if bone >= 0 else Quaternion.IDENTITY


# Turns `bone` by `q` (skeleton frame) about its own joint; its pose is in its parent's frame, whose rotation in the skeleton is `parent`.
static func _turn_bone(s: Skeleton3D, bone: int, q: Quaternion, parent: Quaternion) -> void:
	s.set_bone_pose_rotation(bone, (parent.inverse() * q * parent * s.get_bone_pose_rotation(bone)).normalized())
