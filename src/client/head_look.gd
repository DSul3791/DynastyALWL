extends SkeletonModifier3D

# An animal turns its head to watch a player (Dave 23 Nov 2026: animals "like really bad animatronics", "not actually acting like
# animals"; docs/design/ANIMAL_GAIT.md "Head tracking"). Client drawing only: the server still owns where the body is and which way it
# faces. After the clip is applied each frame, the neck and head bones are turned together toward the watched point, at most
# YAW_MAX sideways and PITCH_UP / PITCH_DOWN up and down; nothing is looked at behind the shoulder (BEHIND). animal_view.gd picks the
# point (`goal`) and eases toward it (`steer`); this node only lays the eased turn over the pose, so any rig works without knowing
# its bone axes: the turn is built in the body's frame and carried into each bone's parent frame.

const YAW_MAX := deg_to_rad(70.0)
const PITCH_UP := deg_to_rad(35.0)
const PITCH_DOWN := deg_to_rad(30.0)
const BEHIND := deg_to_rad(110.0)      # a point further round than this is not watched (the animal would turn its body, not its neck)
const TURN_RAD_S := 3.0                 # how fast the head swings to a new point (about 170 degrees a second)
const WEIGHT_S := 2.5                   # how fast it starts or stops watching (0 to 1 in 0.4 s)
const NECK_SHARE := 0.4                 # with a neck bone, it takes this share of the turn and the head the rest

var head: int = -1
var neck: int = -1
var body: Node3D = null                 # the animal's root: its -Z is the way the body faces
var weight: float = 0.0
var yaw: float = 0.0                    # radians, + to the animal's left
var pitch: float = 0.0                  # radians, + up


func setup(sk: Skeleton3D, head_bone: int, root: Node3D) -> void:
	head = head_bone
	body = root
	var parent: int = sk.get_bone_parent(head_bone)
	neck = parent if parent >= 0 and sk.get_bone_name(parent).to_lower().contains("neck") else -1


# What to watch: [weight, yaw, pitch] toward the nearest of `points` within `range_m` of `at` (the head), in the frame `frame`
# (the body's basis); [0, 0, 0] when none is in range or the nearest is behind the shoulder. Angles are held to the limits.
static func goal(at: Vector3, frame: Basis, points: Array, range_m: float, strength: float) -> Vector3:
	var best: Vector3 = Vector3.INF
	var best_d: float = range_m

	for p in points:
		var d: float = at.distance_to(p)

		if d < best_d and d > 0.3:
			best_d = d
			best = p

	if best == Vector3.INF or strength <= 0.0:
		return Vector3.ZERO

	var local: Vector3 = frame.orthonormalized().inverse() * (best - at)
	var turn: float = atan2(-local.x, -local.z)

	if absf(turn) > BEHIND:
		return Vector3.ZERO

	var rise: float = atan2(local.y, Vector2(local.x, local.z).length())
	return Vector3(strength, clampf(turn, -YAW_MAX, YAW_MAX), clampf(rise, -PITCH_DOWN, PITCH_UP))


# Eases this head toward `want` ([weight, yaw, pitch] from goal) over `delta` seconds. Stopping watching keeps the angles while
# the weight fades, so the head comes back along the way it went.
func steer(want: Vector3, delta: float) -> void:
	weight = move_toward(weight, want.x, WEIGHT_S * delta)

	if want.x > 0.0:
		yaw = move_toward(yaw, want.y, TURN_RAD_S * delta)
		pitch = move_toward(pitch, want.z, TURN_RAD_S * delta)


# The turn in the body's frame as a rotation in the skeleton's frame.
func _turn_in(sk: Skeleton3D) -> Quaternion:
	var b: Basis = body.global_transform.basis.orthonormalized()
	var world: Quaternion = Quaternion(b.y, yaw * weight) * Quaternion(b.x, pitch * weight)
	var s: Quaternion = sk.global_transform.basis.orthonormalized().get_rotation_quaternion()
	return s.inverse() * world * s


func _process_modification() -> void:
	var sk: Skeleton3D = get_skeleton()

	if sk == null or head < 0 or weight < 0.01 or body == null or not is_instance_valid(body):
		return

	var turn: Quaternion = _turn_in(sk)

	if neck >= 0:
		_turn_bone(sk, neck, Quaternion.IDENTITY.slerp(turn, NECK_SHARE))
		_turn_bone(sk, head, Quaternion.IDENTITY.slerp(turn, 1.0 - NECK_SHARE))
	else:
		_turn_bone(sk, head, turn)


# Turns `bone` by `q` (skeleton frame) about its own joint: its pose is in its parent's frame, so q is carried into that frame.
static func _turn_bone(sk: Skeleton3D, bone: int, q: Quaternion) -> void:
	var parent: int = sk.get_bone_parent(bone)
	var p: Quaternion = sk.get_bone_global_pose(parent).basis.get_rotation_quaternion() if parent >= 0 else Quaternion.IDENTITY
	sk.set_bone_pose_rotation(bone, (p.inverse() * q * p * sk.get_bone_pose_rotation(bone)).normalized())
