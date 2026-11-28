extends SceneTree

# A dragged tail (tail_drag.gd, models.json "tail_drag"; Dave 27 Nov 2026, the alligator: "all the actions need to let the tail drag on
# the ground"): a tail a clip holds up is laid back on the floor joint by joint, keeps the clip's sideways swing, and follows a body
# the clip lowers below its rest floor. The crawl (crawl.gd; Dave 27 Nov: "bend his legs more like a real alligator ... so he crawls"):
# a body a clip holds tall and tilted is levelled and let down to its rest height, never raised, the feet staying where the clip put them
# with the elbows bent out; off in other clips and when the body is rolled onto its side; the attacks laid flatter, feet on the ground.
#   godot --headless --path . --script res://src/worldgen/tools/test_tail_drag.gd

const TailDrag := preload("res://src/client/tail_drag.gd")
const Crawl := preload("res://src/client/crawl.gd")

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
	# The modifier's own work is called directly with a floor (lay), out of the tree: Lane A at 7905c47f, with the skeleton in the tree in
	# _initialize, the ground-node path left the tail as the clip had it. The ground floor's maths is checked on its own (ground_floor).
	var drag = TailDrag.new()
	check(drag.setup(sk, ["t0", "t1", "t2"]).is_empty(), "the tail bones are found")
	check(is_equal_approx(drag.bone_floor(sk), 0.0), "the rest floor is the toe (%.3f)" % drag.bone_floor(sk))
	var at: Transform3D = Transform3D(Basis(Vector3.UP, 1.0).scaled(Vector3(2.0, 2.0, 2.0)), Vector3(5.0, 0.3, -2.0))      # a skeleton scaled x2, turned, 0.3 up
	check(is_equal_approx(TailDrag.ground_floor(at, Vector3(7.0, 0.0, 1.0)), -0.15), "the ground 0.3 m below a skeleton scaled x2 is 0.15 below it in its own space (%.3f)" % TailDrag.ground_floor(at, Vector3(7.0, 0.0, 1.0)))

	# The clip holds the tail up 50 degrees like a cat's and swings it 30 degrees to the side.
	sk.set_bone_pose_rotation(t0, Quaternion(Vector3.UP, deg_to_rad(30.0)) * Quaternion(Vector3.RIGHT, deg_to_rad(-50.0)))
	sk.set_bone_pose_rotation(t2, Quaternion(Vector3.RIGHT, deg_to_rad(-40.0)))
	var held: float = TailDrag.global_of(sk, t2).origin.y
	drag.lay(sk, 0.0)
	var tip: Vector3 = TailDrag.global_of(sk, t2).origin
	check(held > 0.2 and absf(tip.y) < 0.01, "a raised tail is laid back on the floor (tip %.3f m up, was %.3f)" % [tip.y, held])
	check(absf(TailDrag.global_of(sk, t1).origin.y - 0.1) < 0.01, "the middle joint at its rest height above the floor (%.3f)" % TailDrag.global_of(sk, t1).origin.y)
	check(tip.x > 0.1, "the clip's sideways swing is kept (tip %.2f m to the side)" % tip.x)
	check(sk.get_bone_pose_rotation(t2).is_equal_approx(Quaternion.IDENTITY), "the tip bone lies on as at rest, not curled up")

	# The animal's ground 0.1 lower than the rest floor (a ground_clips lift moves the body up): the tail lies on that ground.
	sk.set_bone_pose_rotation(t0, Quaternion.IDENTITY)
	drag.lay(sk, -0.1)
	check(absf(TailDrag.global_of(sk, t2).origin.y + 0.1) < 0.01, "the tail lies on the animal's ground (%.3f)" % TailDrag.global_of(sk, t2).origin.y)

	# No ground node: a clip that lowers the whole body 0.1 below the rest floor (a lie) takes the tail down with it.
	sk.set_bone_pose_position(hips, Vector3(0.0, 0.2, 0.0))
	check(is_equal_approx(drag.bone_floor(sk), -0.1), "no ground: the lowered toe is the floor (%.3f)" % drag.bone_floor(sk))
	drag.lay(sk, drag.bone_floor(sk))
	check(absf(TailDrag.global_of(sk, t2).origin.y + 0.1) < 0.01, "no ground: the tail on the lowered body's floor (%.3f)" % TailDrag.global_of(sk, t2).origin.y)

	# A body raised high: the tail slopes down no steeper than SLOPE_DEG, then lies on.
	sk.set_bone_pose_position(hips, Vector3(0.0, 0.8, 0.0))
	drag.lay(sk, 0.0)
	var a: Vector3 = TailDrag.global_of(sk, t0).origin
	var b: Vector3 = TailDrag.global_of(sk, t1).origin
	check((a.y - b.y) / a.distance_to(b) <= sin(deg_to_rad(TailDrag.SLOPE_DEG)) + 0.01, "a raised body: the tail slopes down at most %d degrees" % int(TailDrag.SLOPE_DEG))
	check(TailDrag.global_of(sk, t2).origin.y < 0.8 - 0.3, "a raised body: the tail comes well down toward the ground (tip %.2f)" % TailDrag.global_of(sk, t2).origin.y)

	var short = TailDrag.new()
	check(short.setup(sk, ["t0", "nope"]) == PackedStringArray(["nope"]) and short.chain.is_empty(), "a bone the skeleton lacks is named, and no tail is dragged")
	short.free()
	# The crawl: hips 0.3 up, chest 0.5 ahead of them, a front leg each side under the chest reaching out to a foot 0.2 to the side on the floor.
	var body: Skeleton3D = Skeleton3D.new()
	var top: int = _bone(body, "root", -1, Vector3.ZERO)
	var mid: int = _bone(body, "hips", top, Vector3(0.0, 0.3, 0.0))
	var front: int = _bone(body, "chest", mid, Vector3(0.0, 0.0, 0.5))
	var up_l: int = _bone(body, "upr.L", front, Vector3(0.1, 0.0, 0.0))
	var low_l: int = _bone(body, "lwr.L", up_l, Vector3(0.1, -0.1, 0.0))
	var foot_l: int = _bone(body, "foot.L", low_l, Vector3(0.0, -0.2, 0.0))
	var up_r: int = _bone(body, "upr.R", front, Vector3(-0.1, 0.0, 0.0))
	var low_r: int = _bone(body, "lwr.R", up_r, Vector3(-0.1, -0.1, 0.0))
	var foot_r: int = _bone(body, "foot.R", low_r, Vector3(0.0, -0.2, 0.0))
	var spec: Dictionary = {"hips": "hips", "chest": "chest", "legs": [["upr.L", "lwr.L", "foot.L"], ["upr.R", "lwr.R", "foot.R"]], "clips": ["cat_walk"]}
	var crawl = Crawl.new()
	check(crawl.setup(body, spec).is_empty() and crawl.legs.size() == 2 and crawl.top == top, "the crawl's bones are found, the root above the hips")
	check(crawl.lowers("cat_walk") and crawl.lowers("Armature|cat_walk") and not crawl.lowers("Running"), "only the named clips let the body down")

	# The clip holds the body 0.1 too high and tips it 10 degrees, hips over chest (a cat's stance).
	body.set_bone_pose_position(top, Vector3(0.0, 0.1, 0.0))
	body.set_bone_pose_rotation(top, Quaternion(Vector3.RIGHT, deg_to_rad(10.0)))
	var clip_l: Transform3D = TailDrag.global_of(body, foot_l)
	var clip_r: Transform3D = TailDrag.global_of(body, foot_r)
	check(TailDrag.global_of(body, mid).origin.y > 0.39 and TailDrag.global_of(body, front).origin.y < TailDrag.global_of(body, mid).origin.y - 0.08, "the clip stands it tall, hips over chest")
	crawl.apply(body)
	var hips_y: float = TailDrag.global_of(body, mid).origin.y
	check(absf(hips_y - 0.3) < 0.002, "the hips let down to their rest height (%.3f)" % hips_y)
	check(absf(TailDrag.global_of(body, front).origin.y - hips_y) < 0.002, "the back levelled, chest as high as the hips (%.3f)" % TailDrag.global_of(body, front).origin.y)
	check(TailDrag.global_of(body, foot_l).origin.distance_to(clip_l.origin) < 0.002 and TailDrag.global_of(body, foot_r).origin.distance_to(clip_r.origin) < 0.002, "the feet stay where the clip put them (no sliding)")
	check(TailDrag.global_of(body, low_l).origin.x > 0.15 and TailDrag.global_of(body, low_r).origin.x < -0.15, "the elbows bend out to the sides (%.2f, %.2f)" % [TailDrag.global_of(body, low_l).origin.x, TailDrag.global_of(body, low_r).origin.x])
	check(TailDrag.global_of(body, foot_l).basis.get_rotation_quaternion().angle_to(clip_l.basis.get_rotation_quaternion()) < 0.001, "the foot keeps the clip's turn")

	# A body already lower than its rest height is not raised; one rolled onto its side (a death clip) is left as the clip has it.
	body.reset_bone_poses()
	body.set_bone_pose_position(top, Vector3(0.0, -0.05, 0.0))
	crawl.apply(body)
	check(absf(TailDrag.global_of(body, mid).origin.y - 0.25) < 0.002, "a low body is not raised (%.3f)" % TailDrag.global_of(body, mid).origin.y)
	body.reset_bone_poses()
	var rolled: Quaternion = Quaternion(Vector3.BACK, deg_to_rad(80.0))
	body.set_bone_pose_rotation(top, rolled)
	body.set_bone_pose_position(top, Vector3(0.0, 0.1, 0.0))
	crawl.apply(body)
	check(body.get_bone_pose_position(top).is_equal_approx(Vector3(0.0, 0.1, 0.0)) and body.get_bone_pose_rotation(top).is_equal_approx(rolled), "a body on its side keeps the clip's pose")

	# An attack laid flat (spec "flat", "spine"; Dave 28 Nov: the bite and tail swipe "still hunch like a cat"): a leap 0.2 up, turned 40
	# degrees to the side and the back arched 30 degrees (the head thrown up) is let down with the back flat at its rest slope, the head as low
	# as at rest, the clip's sideways turn kept and the feet on the ground.
	var neck: int = _bone(body, "neck", front, Vector3(0.0, 0.05, 0.2))
	var attack = Crawl.new()
	var flat_spec: Dictionary = spec.duplicate(true)
	flat_spec["flat"] = ["leopard_skill_feipu_once"]
	flat_spec["spine"] = ["hips", "chest", "neck"]
	check(attack.setup(body, flat_spec).is_empty() and attack.spine.size() == 3 and attack.flat("Armature|leopard_skill_feipu_once") and not attack.flat("cat_walk"), "the spine is found, only the named attacks are laid flat")
	body.reset_bone_poses()
	var side: Basis = Basis(Vector3.UP, deg_to_rad(40.0))
	body.set_bone_pose_position(top, Vector3(0.0, 0.2, 0.0))
	body.set_bone_pose_rotation(top, side.get_rotation_quaternion())
	body.set_bone_pose_rotation(mid, Quaternion(Vector3.RIGHT, deg_to_rad(-30.0)))
	attack.flat_now = true
	attack.apply(body)
	var h_at: Vector3 = TailDrag.global_of(body, mid).origin
	var c_at: Vector3 = TailDrag.global_of(body, front).origin
	var n_at: Vector3 = TailDrag.global_of(body, neck).origin
	check(absf(h_at.y - 0.3) < 0.002 and absf(c_at.y - 0.3) < 0.002 and absf(n_at.y - 0.35) < 0.002, "the back flat and the head low (hips %.3f, chest %.3f, head %.3f)" % [h_at.y, c_at.y, n_at.y])
	var heading: Vector3 = Vector3(c_at.x - h_at.x, 0.0, c_at.z - h_at.z).normalized()
	check(heading.distance_to(side * Vector3.BACK) < 0.01, "the clip's sideways turn is kept")
	check(absf(TailDrag.global_of(body, foot_l).origin.y) < 0.01 and absf(TailDrag.global_of(body, foot_r).origin.y) < 0.01, "the feet on the ground (%.3f, %.3f)" % [TailDrag.global_of(body, foot_l).origin.y, TailDrag.global_of(body, foot_r).origin.y])
	attack.free()

	var lame = Crawl.new()
	check(lame.setup(body, {"hips": "hips", "chest": "chest", "legs": [["upr.L", "nope", "foot.L"]]}) == PackedStringArray(["nope"]) and lame.hips == -1, "a bone the skeleton lacks is named, and the crawl is off")
	lame.free()
	body.free()
	drag.free()
	crawl.free()
	sk.free()
	quit(1 if failures > 0 else 0)
