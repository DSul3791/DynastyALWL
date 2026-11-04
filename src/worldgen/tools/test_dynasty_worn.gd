extends SceneTree

# Worn clothing on Dave's body (dynasty_body.gd _worn_frames, worn_look.gd "worn_frames"): the pieces hang, each where it belongs on a 1.7 m body standing at the origin and
# facing -Z (boots at the feet, the hood on the head, the tunic on the chest, sleeves on the arms, gloves at the hands), in metres, right on the right; a second attach
# replaces the first. Run: godot --headless --path . --script res://src/worldgen/tools/test_dynasty_worn.gd
const Body := preload("res://src/client/character/dynasty_body.gd")
const WornLook := preload("res://src/client/worn_look.gd")

var _fails: int = 0


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

	# The hood's crown (its big shell) sits on his head; its drape band hangs at the neck, a little lower (his neck joint is at about 1.40 m).
	var crown_y: float = -1.0

	for node in pieces.get("head", []):
		var at: Vector3 = (node as Node3D).global_position
		crown_y = maxf(crown_y, at.y)
		_check(at.y > 1.35 and at.y < 1.8, "hood piece at the head or neck (y %.2f)" % at.y)

	_check(crown_y > 1.45, "hood crown on the head (y %.2f)" % crown_y)

	for node in pieces.get("chest", []):
		var at: Vector3 = (node as Node3D).global_position
		_check(at.y > 0.85 and at.y < 1.6 and absf(at.x) < 0.12, "tunic on the chest (%.2f, %.2f)" % [at.x, at.y])

	for node in pieces.get("arm_r", []):
		var at: Vector3 = (node as Node3D).global_position
		_check(at.x > 0.12 and at.y > 1.0 and at.y < 1.4, "right sleeve on the right upper arm (%.2f, %.2f)" % [at.x, at.y])

	for side in ["r", "l"]:
		var hand: Vector3 = (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_" + ("RightHand" if side == "r" else "LeftHand")))).origin

		for node in pieces.get("hand_" + side, []):
			_check((node as Node3D).global_position.distance_to(hand) < 0.25, "glove at the %s hand" % side)

	# Metres: a boot's shin cylinder is 0.14 m wide plus a 3 cm layer, whatever the skeleton's centimetre scale.
	var widest: float = 0.0

	for node in pieces.get("shin_r", []):
		widest = maxf(widest, (node as Node3D).global_transform.basis.get_scale().x)

	_check(widest > 0.12 and widest < 0.3, "pieces are metre-sized (shin %.3f)" % widest)
	WornLook.attach(body, ["hide_hood"], false)
	await process_frame
	var after: Dictionary = _pieces(s)
	_check(after.keys() == ["head"], "a second attach replaces the first (%s)" % str(after.keys()))
	print("dynasty worn tests: %d failures" % _fails)
	quit(1 if _fails > 0 else 0)
