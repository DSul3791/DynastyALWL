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
