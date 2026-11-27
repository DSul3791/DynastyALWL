extends SceneTree

# A dragged tail (tail_drag.gd, models.json "tail_drag"; Dave 27 Nov 2026, the alligator: "all the actions need to let the tail drag on
# the ground"): a tail a clip holds up is laid back on the floor joint by joint, keeps the clip's sideways swing, and follows a body
# the clip lowers below its rest floor. Sprawled legs (leg_sprawl.gd; Dave 27 Nov: "bend his legs more like a real alligator"): a leg
# a clip holds straight down is turned back out to its rest pose's sideways angle, keeping the clip's fore-and-aft swing.
#   godot --headless --path . --script res://src/worldgen/tools/test_tail_drag.gd

const TailDrag := preload("res://src/client/tail_drag.gd")
const LegSprawl := preload("res://src/client/leg_sprawl.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _bone(sk: Skeleton3D, bone_name: String, parent: int, at: Vector3) -> int:
	var i: int = sk.get_bone_count()
	sk.add_bone(bone_name)
	sk.set_bone_parent(i, parent)
	sk.set_bone_rest(i, Transform3D(Basis.IDENTITY, at))
	sk.set_bone_pose_position(i, at)
	return i


func _initialize() -> void:
	# A body 0.3 up on one leg whose toe is the floor (y 0), and a three-joint tail lying back from 0.2 down to 0.0.
	var sk: Skeleton3D = Skeleton3D.new()
	var hips: int = _bone(sk, "hips", -1, Vector3(0.0, 0.3, 0.0))
	_bone(sk, "toe", hips, Vector3(0.0, -0.3, 0.0))
	var t0: int = _bone(sk, "t0", hips, Vector3(0.0, -0.1, 0.1))
	var t1: int = _bone(sk, "t1", t0, Vector3(0.0, -0.1, 0.2))
	var t2: int = _bone(sk, "t2", t1, Vector3(0.0, -0.1, 0.2))
	root.add_child(sk)      # in the tree, as in the game, so the ground node counts
	var ground: Node3D = Node3D.new()
	root.add_child(ground)
	var drag = TailDrag.new()
	check(drag.setup(sk, ["t0", "t1", "t2"]).is_empty(), "the tail bones are found")
	drag.ground = ground
	sk.add_child(drag)

	# The clip holds the tail up 50 degrees like a cat's and swings it 30 degrees to the side.
	sk.set_bone_pose_rotation(t0, Quaternion(Vector3.UP, deg_to_rad(30.0)) * Quaternion(Vector3.RIGHT, deg_to_rad(-50.0)))
	sk.set_bone_pose_rotation(t2, Quaternion(Vector3.RIGHT, deg_to_rad(-40.0)))
	var held: float = TailDrag.global_of(sk, t2).origin.y
	drag._process_modification()
	var tip: Vector3 = TailDrag.global_of(sk, t2).origin
	check(held > 0.2 and absf(tip.y) < 0.01, "a raised tail is laid back on the floor (tip %.3f m up, was %.3f)" % [tip.y, held])
	check(absf(TailDrag.global_of(sk, t1).origin.y - 0.1) < 0.01, "the middle joint at its rest height above the floor (%.3f)" % TailDrag.global_of(sk, t1).origin.y)
	check(tip.x > 0.1, "the clip's sideways swing is kept (tip %.2f m to the side)" % tip.x)
	check(sk.get_bone_pose_rotation(t2).is_equal_approx(Quaternion.IDENTITY), "the tip bone lies on as at rest, not curled up")

	# The animal's ground 0.1 lower than the rest floor (a ground_clips lift moves the body up): the tail lies on that ground.
	ground.position.y = -0.1
	sk.set_bone_pose_rotation(t0, Quaternion.IDENTITY)
	drag._process_modification()
	check(absf(TailDrag.global_of(sk, t2).origin.y + 0.1) < 0.01, "the tail lies on the animal's ground (%.3f)" % TailDrag.global_of(sk, t2).origin.y)

	# No ground node: a clip that lowers the whole body 0.1 below the rest floor (a lie) takes the tail down with it.
	drag.ground = null
	sk.set_bone_pose_position(hips, Vector3(0.0, 0.2, 0.0))
	drag._process_modification()
	check(absf(TailDrag.global_of(sk, t2).origin.y + 0.1) < 0.01, "no ground: the tail on the lowered body's floor (%.3f)" % TailDrag.global_of(sk, t2).origin.y)

	# A body raised high: the tail slopes down no steeper than SLOPE_DEG, then lies on.
	drag.ground = ground
	ground.position.y = 0.0
	sk.set_bone_pose_position(hips, Vector3(0.0, 0.8, 0.0))
	drag._process_modification()
	var a: Vector3 = TailDrag.global_of(sk, t0).origin
	var b: Vector3 = TailDrag.global_of(sk, t1).origin
	check((a.y - b.y) / a.distance_to(b) <= sin(deg_to_rad(TailDrag.SLOPE_DEG)) + 0.01, "a raised body: the tail slopes down at most %d degrees" % int(TailDrag.SLOPE_DEG))
	check(TailDrag.global_of(sk, t2).origin.y < 0.8 - 0.3, "a raised body: the tail comes well down toward the ground (tip %.2f)" % TailDrag.global_of(sk, t2).origin.y)

	var short = TailDrag.new()
	check(short.setup(sk, ["t0", "nope"]) == PackedStringArray(["nope"]) and short.chain.is_empty(), "a bone the skeleton lacks is named, and no tail is dragged")
	short.free()
	# Legs: each upper bone reaches out 0.15 and down 0.05 at rest (a sprawl), the lower one straight down to the foot.
	var body: Skeleton3D = Skeleton3D.new()
	var mid: int = _bone(body, "hips", -1, Vector3(0.0, 0.3, 0.0))
	var up_l: int = _bone(body, "upr.L", mid, Vector3(0.1, 0.0, 0.0))
	var low_l: int = _bone(body, "lwr.L", up_l, Vector3(0.15, -0.05, 0.0))
	_bone(body, "foot.L", low_l, Vector3(0.0, -0.2, 0.0))
	var up_r: int = _bone(body, "upr.R", mid, Vector3(-0.1, 0.0, 0.0))
	var low_r: int = _bone(body, "lwr.R", up_r, Vector3(-0.15, -0.05, 0.0))
	_bone(body, "foot.R", low_r, Vector3(0.0, -0.2, 0.0))
	root.add_child(body)
	var sprawl = LegSprawl.new()
	check(sprawl.setup(body, [["upr.L", "lwr.L", "foot.L"], ["upr.R", "lwr.R", "foot.R"]]).is_empty() and sprawl.legs.size() == 2, "both legs found")
	body.add_child(sprawl)
	var rest_side: float = LegSprawl.side_angle(Vector3(0.15, -0.05, 0.0))

	# The clip swings the left upper leg straight down under the body (a cat's leg) and 20 degrees forward.
	var down: Quaternion = Quaternion(Vector3.BACK, -rest_side)
	body.set_bone_pose_rotation(up_l, Quaternion(Vector3.RIGHT, deg_to_rad(-20.0)) * down)
	var before: Vector3 = TailDrag.global_of(body, low_l).origin - TailDrag.global_of(body, up_l).origin
	sprawl._process_modification()
	var after: Vector3 = TailDrag.global_of(body, low_l).origin - TailDrag.global_of(body, up_l).origin
	check(absf(LegSprawl.side_angle(before)) < 0.05, "the clip holds the leg straight down (%.2f rad)" % LegSprawl.side_angle(before))
	check(absf(LegSprawl.side_angle(after) - rest_side) < 0.01, "turned back out to its rest angle (%.2f, rest %.2f)" % [LegSprawl.side_angle(after), rest_side])
	check(absf(after.z - before.z) < 0.001, "the clip's fore-and-aft swing is kept (%.3f)" % after.z)
	var foot_side: float = LegSprawl.side_angle(TailDrag.global_of(body, low_l + 1).origin - TailDrag.global_of(body, low_l).origin)
	check(absf(foot_side) < 0.01, "the lower leg back to its rest angle, straight down (%.2f)" % foot_side)

	# Rolled onto its side (a death clip): the legs are left as the clip has them.
	body.set_bone_pose_rotation(mid, Quaternion(Vector3.BACK, deg_to_rad(80.0)))
	body.set_bone_pose_rotation(up_l, down)
	sprawl._process_modification()
	check(body.get_bone_pose_rotation(up_l).is_equal_approx(down), "a body on its side keeps the clip's legs")
	body.free()
	ground.free()
	sk.free()
	quit(1 if failures > 0 else 0)
