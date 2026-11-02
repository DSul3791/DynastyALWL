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
		# Builders in the body's skip list (tunic and trousers, which its mesh draws itself) add no separate pieces: since Kathleen's builder overrides, hide_tunic and
		# hide_trousers use those builders, so on the generated body they show the body's own cloth instead of a second layer.
		var skipped: bool = str(WornLook.table()[id].get("builder", "")) in (fresh.get_meta("worn_skip_builders", []) as Array)
		_ok(on_new == (0 if skipped else on_old), "%s hangs on the generated body with the same number of parts (%d vs %d%s)" % [id, on_new, on_old, ", skipped: the body draws it" if skipped else ""])
		_ok(skipped or _anchors_valid(fresh), "%s: every anchor on the generated body names a real bone" % id)
		_ok(_anchors_valid(old), "%s: every anchor on the old body names a real bone" % id)

	var all_old: int = WornLook.attach(old, ids, false)
	var all_new: int = WornLook.attach(fresh, ids, false)
	var drawn_by_body: int = 0

	for id in ids:
		if str(WornLook.table()[id].get("builder", "")) in (fresh.get_meta("worn_skip_builders", []) as Array):
			drawn_by_body += WornLook.attach(old, [id], false)

	var all_old_again: int = WornLook.attach(old, ids, false)
	_ok(all_old == all_old_again and all_new == all_old - drawn_by_body and all_new > 20, "everything at once: %d parts on the generated body, %d on the old one (%d are the tunic and trousers the generated body draws itself)" % [all_new, all_old, drawn_by_body])
	var far_new: int = WornLook.attach(fresh, ids, true)
	_ok(far_new > 0 and far_new <= all_new, "far detail hangs fewer or equal parts (%d)" % far_new)
	_check_fit()
	_check_not_buried()
	_check_bare()
	_check_measures()
	_check_skip()
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


# No worn piece may be completely hidden inside the body: at least one corner of each piece's box must lie outside the body surface (the union of the body parts).
func _body_sdf(prims: Array, p: Vector3) -> float:
	var best: float = 1000.0

	for q in prims:
		best = minf(best, (load("res://src/client/character/body_generator.gd") as GDScript).prim_sdf(q, p))

	return best


func _check_not_buried() -> void:
	var Gen: GDScript = load("res://src/client/character/body_generator.gd")
	var ids: Array = WornLook.table().keys()

	for preset in ["average", "broad", "lean", "stocky"]:
		var g: Dictionary = Gen.make_genome(preset)
		var body: Node3D = GeneratedBody.new(g, 0.07)
		root.add_child(body)
		var skeleton: Skeleton3D = body.skeleton
		var prims: Array = Gen.primitives(g, Gen.rig(g), false)

		for id in ids:
			WornLook.attach(body, [id], false)
			var pieces: int = 0
			var buried: int = 0

			for anchor in skeleton.get_children():
				if not str(anchor.name).begins_with("Worn_"):
					continue

				var rest: Transform3D = skeleton.get_bone_global_rest(skeleton.find_bone((anchor as BoneAttachment3D).bone_name))

				for piece in anchor.get_children():
					var mesh_node: MeshInstance3D = piece as MeshInstance3D
					var box: AABB = mesh_node.mesh.get_aabb()
					var out: bool = false

					for cx in [0.0, 1.0]:
						for cy in [0.0, 1.0]:
							for cz in [0.0, 1.0]:
								var corner: Vector3 = box.position + box.size * Vector3(cx, cy, cz)
								var model_pos: Vector3 = rest * (mesh_node.transform * corner)

								if _body_sdf(prims, model_pos) > 0.004:
									out = true

					pieces += 1

					if not out:
						buried += 1

			_ok(buried == 0, "%s on the %s body: no piece is completely buried in the body (%d pieces, %d buried)" % [id, preset, pieces, buried])

		body.queue_free()


func _check_bare() -> void:
	var body: Node3D = GeneratedBody.new({}, 0.07)
	root.add_child(body)
	body.set_clothed(false)
	_ok(is_equal_approx(float((body.body_mesh.material_override as ShaderMaterial).get_shader_parameter("show_cloth")), 0.0), "a body can be shown bare (clothes hidden)")
	body.set_clothed(true)
	_ok(is_equal_approx(float((body.body_mesh.material_override as ShaderMaterial).get_shader_parameter("show_cloth")), 1.0), "and clothed again")
	body.queue_free()


# Body measures for clothing builders: sensible values on the neutral body, and they follow the sliders.
func _check_measures() -> void:
	var Gen: GDScript = load("res://src/client/character/body_generator.gd")
	var n: Dictionary = Gen.measures(Gen.make_genome("average"))
	_ok(absf(float(n["upper_arm_radius"]) - 0.052) < 0.0005 and absf(float(n["forearm_radius"]) - 0.042) < 0.0005, "neutral arm radii are the body's own (0.052, 0.042)")
	_ok(absf(float(n["thigh_radius"]) - 0.085) < 0.0005 and absf(float(n["shin_radius"]) - 0.058) < 0.0005, "neutral leg radii are the body's own (0.085, 0.058)")
	_ok(absf(float(n["hand_length"]) - 0.15) < 0.001 and int(n["finger_count"]) == 4, "neutral hand length 0.15 m, four finger groups (thumb plus three)")
	var lean: Dictionary = Gen.measures(Gen.make_genome("lean"))
	var broad: Dictionary = Gen.measures(Gen.make_genome("broad"))
	_ok(float(broad["chest_half_width"]) > float(lean["chest_half_width"]) * 1.4, "chest width follows the body type (%.3f vs %.3f)" % [float(broad["chest_half_width"]), float(lean["chest_half_width"])])
	_ok(float(lean["thigh_length"]) > float(broad["thigh_length"]), "leg length follows the body type")
	var body: Node3D = GeneratedBody.new(Gen.make_genome("stocky"), 0.07)
	_ok(body.has_meta("worn_measures") and body.has_meta("worn_fit"), "a generated body carries worn_measures and worn_fit")
	body.free()


func _check_skip() -> void:
	var body: Node3D = GeneratedBody.new({}, 0.07)
	root.add_child(body)
	_ok(WornLook.attach(body, ["hide_cloak"], false) > 0, "a cloak hangs on the generated body")
	body.set_meta("worn_skip_builders", ["cloak"])
	_ok(WornLook.attach(body, ["hide_cloak"], false) == 0, "an item whose builder the body skips adds no pieces")
	_ok((body.get_meta("worn_skip_builders") as Array).size() == 1, "the skip list is per body")
	var fresh: Node3D = GeneratedBody.new({}, 0.07)
	_ok((fresh.get_meta("worn_skip_builders") as Array).has("tunic") and (fresh.get_meta("worn_skip_builders") as Array).has("trousers"), "a generated body skips the tunic and trousers builders by default")
	body.queue_free()
	fresh.free()
