extends SceneTree

# Headless check (Sonny, plan 12): every worn item hangs on the generated body with the same number of parts as on the old body, every anchor sits on a real bone of
# the generated skeleton, and the old body is unchanged by the bone-name mapping in src/client/worn_look.gd.
#   godot --headless --path . --script res://tools/check_worn_generated.gd
# Exit code 1 on any failure.

const WornLook := preload("res://src/client/worn_look.gd")
const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const RagdollScript := preload("res://src/client/ragdoll_body.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	var old: Node3D = RagdollScript.new()
	var fresh: Node3D = GeneratedBody.new({}, 0.07)
	root.add_child(old)
	root.add_child(fresh)
	var ids: Array = WornLook.table().keys()
	_ok(ids.size() >= 9, "the worn table has items (%d)" % ids.size())

	for id in ids:
		var on_old: int = WornLook.attach(old, [id], false)
		var on_new: int = WornLook.attach(fresh, [id], false)
		_ok(on_old > 0, "%s hangs on the old body (%d parts)" % [id, on_old])
		_ok(on_new == on_old, "%s hangs on the generated body with the same number of parts (%d vs %d)" % [id, on_new, on_old])
		_ok(_anchors_valid(fresh), "%s: every anchor on the generated body names a real bone" % id)
		_ok(_anchors_valid(old), "%s: every anchor on the old body names a real bone" % id)

	var all_old: int = WornLook.attach(old, ids, false)
	var all_new: int = WornLook.attach(fresh, ids, false)
	_ok(all_old == all_new and all_new > 20, "everything at once: %d parts on both bodies" % all_new)
	var far_new: int = WornLook.attach(fresh, ids, true)
	_ok(far_new > 0 and far_new <= all_new, "far detail hangs fewer or equal parts (%d)" % far_new)
	_check_fit()
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


func _anchors_valid(rig: Node) -> bool:
	var skeleton: Skeleton3D = rig.get("skeleton") as Skeleton3D
	var found: int = 0

	for child in skeleton.get_children():
		if str(child.name).begins_with("Worn_"):
			found += 1

			if skeleton.find_bone((child as BoneAttachment3D).bone_name) < 0:
				return false

	return found > 0


# Plan 15: worn pieces are scaled to each body's proportions. On the neutral body the pieces must equal the old body's; on broad and stocky bodies the width-bound
# pieces must be wider than on a lean one, and length-bound pieces must follow the leg length.
func _piece_sizes(rig: Node) -> Array:
	var out: Array = []
	var skeleton: Skeleton3D = rig.get("skeleton") as Skeleton3D

	for anchor in skeleton.get_children():
		if str(anchor.name).begins_with("Worn_"):
			for mesh in anchor.get_children():
				var tr: Transform3D = (mesh as Node3D).transform
				out.append("%s|%s|%s" % [str(anchor.name).substr(5), str(snapped(tr.basis.get_scale().x, 0.0001)) + "," + str(snapped(tr.basis.get_scale().y, 0.0001)) + "," + str(snapped(tr.basis.get_scale().z, 0.0001)), str(snapped(tr.origin.x, 0.0001)) + "," + str(snapped(tr.origin.y, 0.0001)) + "," + str(snapped(tr.origin.z, 0.0001))])

	return out


func _check_fit() -> void:
	var Gen: GDScript = load("res://src/client/character/body_generator.gd")
	var ids: Array = ["hide_leggings", "hide_boots", "hide_cloak", "backpack"]
	var neutral: Node3D = GeneratedBody.new(Gen.make_genome("average"), 0.07)
	var old: Node3D = RagdollScript.new()
	root.add_child(neutral)
	root.add_child(old)
	WornLook.attach(neutral, ids, false)
	WornLook.attach(old, ids, false)
	var fit: Dictionary = Gen.worn_fit(Gen.make_genome("average"))

	for key in fit:
		_ok((fit[key] as Vector3).is_equal_approx(Vector3.ONE), "the neutral body has fit 1 on " + str(key))

	# Same number of pieces and the same sizes (the anchors have different names, so compare the numbers only).
	var a: Array = []
	var b: Array = []

	for s in _piece_sizes(neutral):
		a.append(str(s).get_slice("|", 1) + "|" + str(s).get_slice("|", 2))

	for s in _piece_sizes(old):
		b.append(str(s).get_slice("|", 1) + "|" + str(s).get_slice("|", 2))

	a.sort()
	b.sort()
	_ok(a == b, "on the neutral body every worn piece has exactly the old body's size and place (%d pieces)" % a.size())
	var lean: Node3D = GeneratedBody.new(Gen.make_genome("lean"), 0.07)
	var broad: Node3D = GeneratedBody.new(Gen.make_genome("broad"), 0.07)
	var stocky: Node3D = GeneratedBody.new(Gen.make_genome("stocky"), 0.07)
	root.add_child(lean)
	root.add_child(broad)
	root.add_child(stocky)

	for body in [lean, broad, stocky]:
		WornLook.attach(body, ["hide_leggings"], false)

	var thigh_lean: float = _thigh_width(lean)
	var thigh_broad: float = _thigh_width(broad)
	var thigh_stocky: float = _thigh_width(stocky)
	_ok(thigh_broad > thigh_lean * 1.2, "leggings are wider on a broad body (%.3f) than on a lean one (%.3f)" % [thigh_broad, thigh_lean])
	_ok(thigh_stocky > thigh_lean * 1.1, "and on a stocky one (%.3f)" % thigh_stocky)
	var leg_lean: float = _thigh_length(lean)
	var leg_stocky: float = _thigh_length(stocky)
	_ok(leg_lean > leg_stocky * 1.3, "leggings are longer on the long-legged lean body (%.3f) than on the short-legged stocky one (%.3f)" % [leg_lean, leg_stocky])


func _first_piece(rig: Node, bone: String) -> Node3D:
	var skeleton: Skeleton3D = rig.get("skeleton") as Skeleton3D
	var anchor: Node = skeleton.get_node_or_null("Worn_" + bone)
	return anchor.get_child(0) as Node3D if anchor != null and anchor.get_child_count() > 0 else null


func _thigh_width(rig: Node) -> float:
	var piece: Node3D = _first_piece(rig, "LeftUpperLeg")
	return piece.transform.basis.get_scale().x if piece != null else 0.0


func _thigh_length(rig: Node) -> float:
	var piece: Node3D = _first_piece(rig, "LeftUpperLeg")
	return piece.transform.basis.get_scale().y if piece != null else 0.0
