extends SkeletonModifier3D

# A hand closed on what it holds (BugsList 177, picture checker 26 Nov 2026: "a smooth fingerless ball at the wrist with the shaft through it, and the open real
# hand below"). Dave's body has no finger bones, so since his decision card of 5 Nov a skin-coloured ball was drawn round every third-person grip (held_item.gd
# third_fist_on); the hand stayed open and its fingers hung below the ball. Here, while a hand mount holds something drawn, the hand bone is drawn shorter along
# its length (CLOSED_LENGTH, about where the knuckles of a fist are) and a little thicker, so the real hand sits round the grip like a closed hand, in the body's
# own skin, and the ball is not drawn (held_item.gd BALL_FIST off). The mount is scaled back by the same amount, so the tool keeps its size and turn; the grip
# point comes in with the shorter hand. It eases in and out over EASE_S, so changing what is held never pops. Drawing only: the hand mesh and the mounts.
# Made by dynasty_body.gd under the skeleton, after the Proportions modifier (which writes the hand's own scale each frame); `body` is the body node.

const P := "mixamorig_"
const CLOSED_LENGTH := 0.55   # the hand's length while closed: 19 cm to about 10.5 cm, a fist's wrist to knuckles
const CLOSED_THICK := 1.3     # and its thickness: the curled fingers stand off the palm
const EASE_S := 0.12

static var closes: bool = true   # false: the old ball fist instead (tools/shot_held.gd and body_pose_shot.gd --fist=ball, for before and after pictures)

var body: Node3D
var closed: Array = [0.0, 0.0]   # right, left: 0 open, 1 closed
var _hands: Array = [-2, -2]     # bone index of the right and left hand, found on the first frame
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


# Whether a hand mount holds something that is drawn.
static func holds(mount: Node3D) -> bool:
	if mount == null or not mount.is_visible_in_tree():
		return false

	for child in mount.get_children():
		if child is Node3D and (child as Node3D).visible:
			return true

	return false


func _process_modification_with_delta(delta: float) -> void:
	var s: Skeleton3D = get_skeleton()

	if s == null or body == null or not is_instance_valid(body):
		return

	if int(_hands[0]) == -2:
		_find(s)

	var mounts: Array = [body.get("hand_mount_r"), body.get("hand_mount_l")]

	for side in 2:
		var i: int = int(_hands[side])
		var mount: Marker3D = mounts[side] as Marker3D

		if i < 0 or mount == null:
			continue

		var want: float = 1.0 if closes and holds(mount) else 0.0
		closed[side] = move_toward(float(closed[side]), want, delta / EASE_S)
		var k: Vector3 = closed_scale(float(closed[side]), int(_axes[side]), int(_thick[side]))
		var own: float = float(body.call("hand_scale")) if body.has_method("hand_scale") else 1.0   # the creator's hand slider (Proportions writes it each frame)
		s.set_bone_pose_scale(i, Vector3.ONE * own * k)   # written whole every frame, so it never adds up
		var base: Transform3D = body.call("mount_base", mount)
		mount.transform = Transform3D(Basis.from_scale(Vector3.ONE / k) * base.basis, base.origin)   # the tool back at its size and turn; the grip comes in with the hand


# Each hand's bone, its axis along the hand (the forearm's direction at rest, read in the hand bone's own frame) and the palm's axis (the body's front at rest,
# as dynasty_body.gd _mount takes it). At rest the arms are out and the palms down, so the front runs across the knuckles and the remaining axis through the palm.
func _find(s: Skeleton3D) -> void:
	for side in 2:
		var side_name: String = ["Right", "Left"][side]
		var hand: int = s.find_bone(P + side_name + "Hand")
		var fore: int = s.find_bone(P + side_name + "ForeArm")
		_hands[side] = hand

		if hand < 0 or fore < 0:
			continue

		var rest: Basis = s.get_bone_global_rest(hand).basis.orthonormalized()
		var along: Vector3 = rest.inverse() * (s.get_bone_global_rest(hand).origin - s.get_bone_global_rest(fore).origin).normalized()
		var front: Vector3 = rest.inverse() * Vector3(0.0, 0.0, 1.0)
		_axes[side] = along.abs().max_axis_index()
		var rest_axes: Array = [0, 1, 2]
		rest_axes.erase(int(_axes[side]))
		# Of the two axes across the hand, the one nearer the body's front runs across the knuckles (the hand's width); the other goes through the palm.
		_thick[side] = int(rest_axes[1]) if absf(front[int(rest_axes[0])]) > absf(front[int(rest_axes[1])]) else int(rest_axes[0])
