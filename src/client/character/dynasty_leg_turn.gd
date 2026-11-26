extends SkeletonModifier3D

# The legs turn toward the way the body moves (foot slide, 26 Nov 2026, Dave's basics: smooth movement, no sliding). Dave's body has a forward gait and four
# crouched walks but no sideways or diagonal walk standing up, so walking sideways at 3.2 m/s the forward clip's feet slid 62 cm along the ground at every step
# and 43 cm on a diagonal; crouch-walking on a diagonal 24 cm (measured offline from the glb, /mnt/project-files/foot-slide/). After the clip is drawn the hips
# turn about the vertical by the angle between the clip's own direction and the travel (avatar_driver.gd leg_turn, at most 80 degrees standing and 60
# crouched) and the three spine bones turn back by a third each, so the chest, the head, the arms and whatever is held still face where the player looks.
# Offline the slide falls to 12-18 cm sideways (the turn stops at 80 degrees) and 9-12 cm on a diagonal, about the clip's own heel roll walking forward
# (8-10 cm); crouched 3-6 cm. The turn eases in and out (TURN_RAD_S), so the hips never snap. Drawing only: every client works it out from the body's own
# velocity (avatar_driver.gd clip_for sets the meta `leg_local` on the body, for the local player and for each other player alike).
# Turning on the spot (26 Nov 2026, the same follow-up): the body turns with the mouse, so standing still the feet swung round with it, 40 to 50 cm a quarter
# turn. Standing or crouching still, the feet now stay planted (`twist`: the hips turned back against the body's turn, the spine taking it up to the look)
# until the shoulders are STEP_FROM past them; then the feet step round, one and then the other, a lift of the thigh and the knee each (`_lift_leg`), the
# turned-side foot first, until they are under the body again. Moving, the twist eases out at the stepping rate (the gait's own steps re-plant the feet).
# Made by dynasty_body.gd under the skeleton after the Proportions and Breath modifiers; `player` is the body's AnimationPlayer, `body` the body node.

const AvatarDriverScript := preload("res://src/client/character/avatar_driver.gd")

const P := "mixamorig_"
const SPINE := ["Spine", "Spine1", "Spine2"]
const TURN_RAD_S := 5.0                 # how fast the legs swing to a new angle (80 degrees in about 0.3 s)
const STILL_CLIPS := ["idle", "crouch", "carry_idle"]   # gait_of names in which the feet stay planted while the body turns
const STEP_FROM := 0.7                  # radians (40 degrees): the shoulders turn this far over planted feet, then the feet step round
const STEP_RAD_S := 3.5                 # how fast the feet come round while stepping (40 degrees in 0.2 s), and the twist eases out when moving
const STEP_HALF_S := 0.22               # one foot's step, lifted and set down; the other foot follows
const TWIST_MOST := 1.3                 # a faster spin than the feet can step drags them beyond this
const LIFT_RAD := 0.4                   # the stepping thigh swings this far forward and the knee bends twice as far: the foot rises about 7 cm

var player: AnimationPlayer
var body: Node3D
var angle: float = 0.0                  # radians, + to the body's left: where the legs point now
var twist: float = 0.0                  # radians, + to the body's left: the legs held back against the body's own turn, so the feet stay put
var stepping: bool = false              # the feet are stepping round to catch the body up
var _plant_yaw: float = NAN             # the world yaw the planted feet face
var _step_t: float = 0.0
var _step_end: int = -1                 # the half-step after which the stepping stops (set once the feet have caught up)
var _first: int = 0                     # the foot that steps first: 0 left, 1 right
var _hips: int = -2
var _spine: Array = []
var _legs: Array = []                   # [UpLeg, Leg, Foot] left, then right


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
	var lift: Array = _plant(AvatarDriverScript.gait_of(clip) in STILL_CLIPS, _yaw_of(body), delta)
	var total: float = angle + twist

	if absf(total) < 0.001 and float(lift[1]) <= 0.0:
		return

	if _hips == -2:
		_hips = s.find_bone(P + "Hips")

		for bone in SPINE:
			_spine.append(s.find_bone(P + bone))

		for side in ["Left", "Right"]:
			for bone in ["UpLeg", "Leg", "Foot"]:
				_legs.append(s.find_bone(P + side + bone))

	if _hips < 0 or _spine.has(-1) or _legs.has(-1):
		return

	# Skeleton space is up +Y, front +Z, left +X (dynasty_body.gd), so a turn by + angle about +Y swings the front toward the left. Each bone's parent frame after
	# its parent turned is worked out here (head_look.gd does the same) rather than read back from the skeleton straight after a pose write.
	var turn: Quaternion = Quaternion(Vector3.UP, total)
	var back: Quaternion = Quaternion(Vector3.UP, -total / float(SPINE.size()))
	var parent: Quaternion = _global_rot(s, s.get_bone_parent(_hips))
	var before: Quaternion = parent * s.get_bone_pose_rotation(_hips)
	_turn_bone(s, _hips, turn, parent)
	parent = turn * before

	if float(lift[1]) > 0.0:
		var leg: int = int(lift[0]) * 3
		_lift_leg(s, _legs[leg], _legs[leg + 1], _legs[leg + 2], parent, turn * Vector3.RIGHT, float(lift[1]) * LIFT_RAD)

	for i in _spine:
		before = parent * s.get_bone_pose_rotation(i)
		_turn_bone(s, i, back, parent)
		parent = back * before


# The feet's plant for this frame: sets `twist` (clamped, eased while stepping or moving) and returns [the foot stepping (0 left, 1 right), its lift 0..1].
func _plant(still: bool, yaw: float, delta: float) -> Array:
	if is_nan(_plant_yaw):
		_plant_yaw = yaw

	var off: float = wrapf(_plant_yaw - yaw, -PI, PI)
	var out: Array = [0, 0.0]

	if not still:
		stepping = false
		off = move_toward(off, 0.0, STEP_RAD_S * delta)
	else:
		if not stepping and absf(off) > STEP_FROM:
			stepping = true
			_step_t = 0.0
			_step_end = -1
			_first = 0 if off < 0.0 else 1   # off < 0: the body turned left of the feet, the left foot leads

		if stepping:
			_step_t += delta
			off = move_toward(off, 0.0, STEP_RAD_S * delta)
			var half: int = int(_step_t / STEP_HALF_S)

			if absf(off) < 0.001 and _step_end < 0:
				_step_end = half + (1 if half % 2 == 0 else 0)   # both feet step at least once, and the one in the air comes down

			if _step_end >= 0 and half > _step_end:
				stepping = false
			else:
				out = [(_first + half) % 2, sin(PI * fmod(_step_t, STEP_HALF_S) / STEP_HALF_S)]

	twist = clampf(off, -TWIST_MOST, TWIST_MOST)
	_plant_yaw = yaw + twist
	return out


# The body's facing about the vertical in the world (its +Z, the front of Dave's skeleton).
static func _yaw_of(node: Node3D) -> float:
	var z: Vector3 = node.global_basis.z
	return atan2(z.x, z.z)


# One foot off the ground: the thigh forward by `a` about the hips' side axis `side` (skeleton frame), the knee bent back by twice that, the foot turned back
# level. `hips` is the hips' rotation in the skeleton after their turn.
static func _lift_leg(s: Skeleton3D, up_leg: int, leg: int, foot: int, hips: Quaternion, side: Vector3, a: float) -> void:
	var thigh: Quaternion = Quaternion(side, -a)       # about the left (+X) axis, minus swings a hanging bone toward the front (+Z)
	var knee: Quaternion = Quaternion(side, 2.0 * a)
	var level: Quaternion = Quaternion(side, -a)
	var up_before: Quaternion = hips * s.get_bone_pose_rotation(up_leg)
	_turn_bone(s, up_leg, thigh, hips)
	var up_after: Quaternion = thigh * up_before
	var leg_before: Quaternion = up_after * s.get_bone_pose_rotation(leg)
	_turn_bone(s, leg, knee, up_after)
	_turn_bone(s, foot, level, knee * leg_before)


static func _global_rot(s: Skeleton3D, bone: int) -> Quaternion:
	return s.get_bone_global_pose(bone).basis.get_rotation_quaternion() if bone >= 0 else Quaternion.IDENTITY


# Turns `bone` by `q` (skeleton frame) about its own joint; its pose is in its parent's frame, whose rotation in the skeleton is `parent`.
static func _turn_bone(s: Skeleton3D, bone: int, q: Quaternion, parent: Quaternion) -> void:
	s.set_bone_pose_rotation(bone, (parent.inverse() * q * parent * s.get_bone_pose_rotation(bone)).normalized())
