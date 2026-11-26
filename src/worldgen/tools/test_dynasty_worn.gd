extends SceneTree

# Worn clothing on Dave's body (dynasty_body.gd _worn_frames, worn_look.gd "worn_frames"): the pieces hang, each where it belongs on a 1.7 m body standing at the origin and
# facing -Z (boots at the feet, the hood on the head, the tunic on the chest, sleeves on the arms, gloves at the hands), in metres, right on the right; a second attach
# replaces the first. Run: godot --headless --path . --script res://src/worldgen/tools/test_dynasty_worn.gd
const Body := preload("res://src/client/character/dynasty_body.gd")
const WornLook := preload("res://src/client/worn_look.gd")
const Ragdoll := preload("res://src/client/ragdoll_body.gd")

var _fails: int = 0


# The balls on `bone` centred on its joint (worn_look.gd joint_caps, or a builder's own).
func _caps(parts: Array, bone: String) -> int:
	var n: int = 0

	for part in parts:
		if str(part["bone"]) == bone and str(part["shape"]).begins_with("sph") and (part["at"] as Vector3).length() < 0.03:
			n += 1

	return n


func _check(ok: bool, what: String) -> void:
	print(("pass " if ok else "FAIL ") + what)
	_fails += 0 if ok else 1


# Every worn piece's world position, by the old bone it was written for.
func _pieces(skeleton: Skeleton3D) -> Dictionary:
	var out: Dictionary = {}

	for holder in skeleton.get_children():
		if not str(holder.name).begins_with("Worn_"):
			continue

		var old: String = str(holder.name).trim_prefix("Worn_")

		for node in holder.find_children("*", "MeshInstance3D", true, false):
			if not out.has(old):
				out[old] = []

			out[old].append(node)

	return out


func _init() -> void:
	if not Body.available():
		print("dynasty worn tests: Dave's body is not imported, nothing to test")
		quit()
		return

	var body: Node3D = Body.new()
	root.add_child(body)
	body.play("idle", 1.0, 0.0)
	body.animation_player.seek(0.0, true)
	# Held on the first frame: under a loaded gate the two frames below can be long and the idle would play on, so the pose (and every height checked) would
	# depend on the machine's speed (PC gate 5 Nov: the hood's cape read 1.30 m in the gate and passed alone).
	body.animation_player.speed_scale = 0.0
	var s: Skeleton3D = body.skeleton
	var hung: int = WornLook.attach(body, ["hide_boots", "hide_tunic", "hide_hood", "hide_trousers", "hide_gloves"], false)
	await process_frame
	await process_frame
	_check(hung > 10, "the outfit hangs pieces (%d)" % hung)
	var pieces: Dictionary = _pieces(s)

	for old in ["foot_r", "foot_l", "shin_r", "thigh_r", "hips", "chest", "head", "arm_r", "forearm_l", "hand_r", "hand_l"]:
		_check(pieces.has(old), "pieces on " + old)

	for node in pieces.get("foot_r", []) + pieces.get("foot_l", []):
		var at: Vector3 = (node as Node3D).global_position
		_check(at.y > -0.02 and at.y < 0.16, "boot foot at the ground (y %.2f)" % at.y)

	for node in pieces.get("foot_r", []):
		_check((node as Node3D).global_position.x > 0.05, "right boot on the right (+X)")

	# The hood's crown (its big shell) sits on his head; its shoulder cape hangs round the neck down to the tops of the shoulders (his neck joint is at about
	# 1.40 m, the cape's middle about 7 cm under the hood frame's chin line), so pieces sit between the shoulders and the crown.
	var crown_y: float = -1.0

	for node in pieces.get("head", []):
		var at: Vector3 = (node as Node3D).global_position
		crown_y = maxf(crown_y, at.y)
		_check(at.y > 1.25 and at.y < 1.8, "hood piece at the head, neck or shoulders (y %.2f)" % at.y)

	_check(crown_y > 1.45, "hood crown on the head (y %.2f)" % crown_y)

	for node in pieces.get("chest", []):
		var at: Vector3 = (node as Node3D).global_position
		_check(at.y > 0.85 and at.y < 1.6 and absf(at.x) < 0.12, "tunic on the chest (%.2f, %.2f)" % [at.x, at.y])

	for node in pieces.get("arm_r", []):
		var at: Vector3 = (node as Node3D).global_position
		_check(at.x > 0.12 and at.y > 1.0 and at.y < 1.5, "right sleeve on the right upper arm (%.2f, %.2f)" % [at.x, at.y])   # up to 1.5: the shoulder's joint ball (QA #15) sits on the joint

	for side in ["r", "l"]:
		var hand: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_" + ("RightHand" if side == "r" else "LeftHand")))).origin

		for node in pieces.get("hand_" + side, []):
			_check((node as Node3D).global_position.distance_to(hand) < 0.25, "glove at the %s hand" % side)

	# Metres: a boot's shin cylinder is 0.14 m wide plus a 3 cm layer, whatever the skeleton's centimetre scale.
	var widest: float = 0.0

	for node in pieces.get("shin_r", []):
		widest = maxf(widest, (node as Node3D).global_transform.basis.get_scale().x)

	_check(widest > 0.12 and widest < 0.3, "pieces are metre-sized (shin %.3f)" % widest)
	# QA #15 (25 Nov 2026, "limbs not attached"): a garment that covers both sides of a joint puts a ball of its colour on it (worn_look.gd joint_caps), on the child
	# bone at the joint, so a bent elbow or a raised arm never opens a gap between rigid pieces.
	var tunic: Array = WornLook.parts_of("tunic", 0.03)
	_check(_caps(tunic, "arm_r") == 1 and _caps(tunic, "forearm_r") == 1 and _caps(tunic, "arm_l") == 1 and _caps(tunic, "forearm_l") == 1, "a sleeved tunic has a ball at each shoulder and elbow")
	_check(_caps(WornLook.parts_of("padded", 0.03), "forearm_l") == 1 and _caps(WornLook.parts_of("trousers", 0.0), "thigh_r") == 1 and _caps(WornLook.parts_of("gloves", 0.0), "hand_r") == 1, "the gambeson's elbow, the trousers' hip and the gloves' wrist are joined")
	var mail: Array = WornLook.parts_of("mailshirt", 0.03)
	_check(_caps(mail, "arm_r") == 1 and _caps(mail, "forearm_r") == 0, "a short mail sleeve joins at the shoulder only (it does not reach the elbow)")
	_check(_caps(WornLook.parts_of("leggings", 0.0), "shin_r") == 1, "the leggings' own knee ball is not doubled")
	_check(WornLook.joint_caps(WornLook.parts_of("hood", 0.0)).is_empty() and WornLook.joint_caps(WornLook.parts_of("cloak", 0.0)).is_empty(), "no balls where a garment bends at no joint")

	# The joint heights are ragdoll_body.gd's bone offsets, and on Dave's body the ball sits on his own joint.
	var bones: Dictionary = {}

	for row in Ragdoll.BONES:
		bones[str(row[0])] = row

	var heights_match: bool = true

	for joint in WornLook.JOINTS:
		heights_match = heights_match and str(bones[joint[1]][1]) == str(joint[0]) and is_equal_approx((bones[joint[1]][2] as Vector3).y, float(joint[2]))

	_check(heights_match, "the worn joints are the rig's joints (ragdoll_body.gd BONES)")

	for bone_pair in [["arm_r", "mixamorig_RightArm"], ["forearm_l", "mixamorig_LeftForeArm"]]:
		var joint_at: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone(str(bone_pair[1])))).origin
		var nearest: float = INF

		for node in pieces.get(str(bone_pair[0]), []):
			nearest = minf(nearest, (node as Node3D).global_position.distance_to(joint_at))

		_check(nearest < 0.03, "a ball on the %s joint of Dave's body (%.3f m off)" % [str(bone_pair[0]), nearest])

	for part in tunic:
		if str(part["bone"]) == "arm_r" and str(part["shape"]) == "sph":
			_check(float((part["size"] as Vector3).x) >= 0.15, "the shoulder ball is wider than the sleeve (%.3f m)" % float((part["size"] as Vector3).x))

	WornLook.attach(body, ["hide_hood"], false)
	await process_frame
	var after: Dictionary = _pieces(s)
	_check(after.keys() == ["head"], "a second attach replaces the first (%s)" % str(after.keys()))
	print("dynasty worn tests: %d failures" % _fails)
	quit(1 if _fails > 0 else 0)
