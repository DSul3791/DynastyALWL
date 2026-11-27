extends SkeletonModifier3D

# A hand closed on what it holds (BugsList 177, picture checker 26 Nov 2026: "a smooth fingerless ball at the wrist with the shaft through it, and the open real
# hand below"). Dave's body has no finger bones, so since his decision card of 5 Nov a skin-coloured ball was drawn round every third-person grip (held_item.gd
# third_fist_on); the hand stayed open and its fingers hung below the ball. Here, while a hand mount holds something drawn, the hand bone is drawn shorter along
# its length (CLOSED_LENGTH, about where the knuckles of a fist are) and a little thicker, so the real hand sits round the grip like a closed hand, in the body's
# own skin, and the ball is not drawn (held_item.gd hand_closes). The mount hangs on a bone of its own under the hand (dynasty_body.gd GRIP_BONE) whose scale
# undoes the hand's, so the tool keeps its size and turn even read before the modifiers ran; the grip point comes in with the shorter hand. It eases in and out over EASE_S, so changing what is held never pops. Drawing only: the hand mesh and the mounts.
# Made by dynasty_body.gd under the skeleton, after the Proportions modifier (which writes the hand's own scale each frame); `body` is the body node.

const P := "mixamorig_"
# Dave, 27 Nov 2026: "ok for now just keep the hand open but place the tools and weapons right on the hand where it should be when the hand is closed." So the hand
# is drawn as it is (1.0); the handle sits GRIP_FROM_WRIST_M down the open hand (dynasty_body.gd), where the fingers meet the palm and would wrap it; no ball.
const CLOSED_LENGTH := 1.0   # the hand's length while it holds (0.55 drew a squashed hand with open fingers)
const CLOSED_THICK := 1.0
const EASE_S := 0.12
const GRIP_BONE := "HandGrip"   # P + side + this: the bone under each hand that its mount hangs on (dynasty_body.gd _build_mounts)
const FIST_NAME := "ThirdFist"   # held_item.gd THIRD_FIST_NAME

static var closes: bool = true   # false: the old ball fist instead (tools/shot_held.gd and body_pose_shot.gd --fist=ball, for before and after pictures)

var body: Node3D
var closed: Array = [0.0, 0.0]   # right, left: 0 open, 1 closed
var _hands: Array = [-2, -2]     # bone index of the right and left hand, found on the first frame
var _grips: Array = [-1, -1]     # and of the bone under each that its mount hangs on (dynasty_body.gd GRIP_BONE)
var _mounts: Array = [null, null]
var _open_written: Array = [false, false]
var _axes: Array = [-1, -1]      # each hand bone's own axis that runs along the hand (wrist to fingers)
var _thick: Array = [-1, -1]     # and the one that runs through the palm (back of the hand to the palm)


# The hand bone's scale for a closed share `c` (0 open, 1 closed): shorter along `along`, thicker along `thick`.
static func closed_scale(c: float, along: int, thick: int) -> Vector3:
	var k: Vector3 = Vector3.ONE

	if along >= 0:
		k[along] = lerpf(1.0, CLOSED_LENGTH, c)

	if thick >= 0:
		k[thick] = lerpf(1.0, CLOSED_THICK, c)

	return k


# Whether a hand mount holds something gripped: a drawn model with the grip's fist on it (held_item.gd third_fist_on, the ball's old place). Food and
# small things carried in the palm (kits) and the bow get no fist, so their hand stays as it was.
static func holds(mount: Node3D) -> bool:
	if mount == null or not mount.is_visible_in_tree():
		return false

	for child in mount.get_children():
		if child is Node3D and (child as Node3D).visible:
			var fist: Node3D = (child as Node3D).get_node_or_null(FIST_NAME) as Node3D

			if fist != null and fist.visible:
				return true

	return false


func _process_modification_with_delta(delta: float) -> void:
	var s: Skeleton3D = get_skeleton()

	if s == null or body == null or not is_instance_valid(body):
		return

	if int(_hands[0]) == -2:
		_find(s)

	for side in 2:
		var i: int = int(_hands[side])
		var mount: Marker3D = _mounts[side] as Marker3D

		if i < 0 or int(_grips[side]) < 0 or mount == null or not is_instance_valid(mount):
			continue

		var want: float = 1.0 if closes and holds(mount) else 0.0
		closed[side] = move_toward(float(closed[side]), want, delta / EASE_S)

		if float(closed[side]) <= 0.0 and bool(_open_written[side]):
			continue   # open and already put back: nothing to write (the bones' own poses are the clip's)

		var k: Vector3 = closed_scale(float(closed[side]), int(_axes[side]), int(_thick[side]))
		var own: float = float(body.call("hand_scale"))   # the creator's hand slider (Proportions writes it each frame; written whole again here, so it never adds up)
		s.set_bone_pose_scale(i, Vector3.ONE * own * k)
		s.set_bone_pose_scale(int(_grips[side]), Vector3.ONE / k)   # undone on the mount's own bone: the mount never carries the hand's scale
		var base: Transform3D = body.call("mount_base", mount)
		mount.transform = Transform3D(base.basis, base.origin * k)   # the grip comes in with the shorter hand
		_open_written[side] = float(closed[side]) <= 0.0


# Each hand's bone, its axis along the hand (the forearm's direction at rest, read in the hand bone's own frame) and the palm's axis (the body's front at rest,
# as dynasty_body.gd _mount takes it). At rest the arms are out and the palms down, so the front runs across the knuckles and the remaining axis through the palm.
func _find(s: Skeleton3D) -> void:
	for side in 2:
		var side_name: String = ["Right", "Left"][side]
		var hand: int = s.find_bone(P + side_name + "Hand")
		var fore: int = s.find_bone(P + side_name + "ForeArm")
		_hands[side] = hand
		_grips[side] = s.find_bone(P + side_name + GRIP_BONE)
		_mounts[side] = body.get(["hand_mount_r", "hand_mount_l"][side])

		if hand < 0 or fore < 0:
			continue

		var rest: Basis = s.get_bone_global_rest(hand).basis.orthonormalized()
		var along: Vector3 = rest.inverse() * (s.get_bone_global_rest(hand).origin - s.get_bone_global_rest(fore).origin).normalized()
		var front: Vector3 = rest.inverse() * Vector3(0.0, 0.0, 1.0)
		_axes[side] = along.abs().max_axis_index()

		if absf(along[int(_axes[side])]) < 0.9:
			push_warning("dynasty_grip: the %s hand bone does not run along the forearm (%s); the closed hand may squash the wrong way" % [side_name, str(along)])

		var rest_axes: Array = [0, 1, 2]
		rest_axes.erase(int(_axes[side]))
		# Of the two axes across the hand, the one nearer the body's front runs across the knuckles (the hand's width); the other goes through the palm.
		_thick[side] = int(rest_axes[1]) if absf(front[int(rest_axes[0])]) > absf(front[int(rest_axes[1])]) else int(rest_axes[0])
