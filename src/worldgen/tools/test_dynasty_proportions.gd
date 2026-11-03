extends SceneTree

# Proportions on Dave's body (src/client/character/dynasty_proportions.gd, Kathreen 3 Nov 2026): the creator sliders reshape the Mixamo rig after the clip. Checks, on the idle clip:
# the plain genome leaves the body unchanged; Height +1 makes the head about 12% higher and the feet stay on the ground; Legs +1 lifts the hips and keeps the feet on the ground;
# Arms +1 puts the hand further from the shoulder; the hand mount stays metre scale with any sliders (a held tool keeps its size); a reshape does not add up over frames; the skin
# colour tints only its own body.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_dynasty_proportions.gd
const Body := preload("res://src/client/character/dynasty_body.gd")
const Generator := preload("res://src/client/character/body_generator.gd")

var _fails: int = 0


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fails += 1
		print("FAIL ", what)


func _bone(body: Node3D, bone: String) -> Vector3:
	var s: Skeleton3D = body.skeleton
	return (s.global_transform * s.get_bone_global_pose(s.find_bone("mixamorig_" + bone))).origin


func _pose(sliders: Dictionary) -> Dictionary:
	var g: Dictionary = Generator.make_genome()

	for key in sliders:
		g[key] = float(sliders[key])

	var body: Node3D = Body.new()
	root.add_child(body)
	body.set_proportions(g)
	body.play("idle", 1.0, 0.0)
	body.animation_player.seek(0.5, true)
	body.animation_player.speed_scale = 0.0

	for i in range(4):
		await process_frame

	var out: Dictionary = {}

	for bone in ["Hips", "Head", "LeftFoot", "RightFoot", "LeftToeBase", "LeftArm", "LeftHand"]:
		out[bone] = _bone(body, bone)

	out["mount_scale"] = body.hand_mount_r.global_transform.basis.get_scale().x
	out["body"] = body
	return out


func _init() -> void:
	if not Body.available():
		print("dynasty proportions tests: Dave's glb is not imported, skipped (run godot --import once)")
		print("dynasty proportions tests: 0 failures")
		quit()
		return

	var plain: Dictionary = await _pose({})
	var tall: Dictionary = await _pose({"height": 1.0})
	var legs: Dictionary = await _pose({"legs": 1.0})
	var arms: Dictionary = await _pose({"arms": 1.0})
	var all: Dictionary = await _pose({"height": -1.0, "legs": 1.0, "arms": -1.0, "hands": 1.0, "head": 1.0, "neck": -1.0, "shoulders": 1.0, "torso": 1.0, "feet": 1.0})
	print("plain head %.3f hips %.3f toe %.3f; tall head %.3f toe %.3f; legs hips %.3f toe %.3f" % [plain["Head"].y, plain["Hips"].y, plain["LeftToeBase"].y, tall["Head"].y, tall["LeftToeBase"].y, legs["Hips"].y, legs["LeftToeBase"].y])

	_check(absf(plain["mount_scale"] - 1.0) < 0.01, "plain: hand mount metre scale (%.3f)" % plain["mount_scale"])
	_check(absf(tall["Head"].y / plain["Head"].y - 1.12) < 0.02, "height +1: head about 12%% higher (%.3f)" % (tall["Head"].y / plain["Head"].y))
	_check(absf(tall["LeftToeBase"].y - plain["LeftToeBase"].y) < 0.03, "height +1: feet stay on the ground")
	_check(legs["Hips"].y > plain["Hips"].y + 0.06, "legs +1: hips higher (%.3f vs %.3f)" % [legs["Hips"].y, plain["Hips"].y])
	_check(absf(legs["LeftToeBase"].y - plain["LeftToeBase"].y) < 0.04, "legs +1: feet stay on the ground (%.3f vs %.3f)" % [legs["LeftToeBase"].y, plain["LeftToeBase"].y])
	_check(legs["Head"].y > plain["Head"].y + 0.06, "legs +1: taller overall")
	var reach_plain: float = plain["LeftArm"].distance_to(plain["LeftHand"])
	var reach_arms: float = arms["LeftArm"].distance_to(arms["LeftHand"])
	_check(reach_arms > reach_plain * 1.1, "arms +1: hand further from the shoulder (%.3f vs %.3f)" % [reach_arms, reach_plain])

	for spec in [["tall", tall], ["legs", legs], ["arms", arms], ["all", all]]:
		_check(absf(float(spec[1]["mount_scale"]) - 1.0) < 0.01, "%s: hand mount stays metre scale (%.3f)" % [spec[0], spec[1]["mount_scale"]])

	# Twenty more frames: the lift and the scales are written fresh each frame, never added up.
	var body: Node3D = legs["body"]

	for i in range(20):
		await process_frame

	_check(absf(_bone(body, "Hips").y - legs["Hips"].y) < 0.005, "legs +1: hips do not keep rising (%.3f then %.3f)" % [legs["Hips"].y, _bone(body, "Hips").y])
	# Back to the plain genome on the same body: it returns to the plain shape (the creator reshapes one body in place).
	body.set_proportions(Generator.make_genome())

	for i in range(3):
		await process_frame

	_check(absf(_bone(body, "Hips").y - plain["Hips"].y) < 0.01, "back to plain: hips as plain (%.3f vs %.3f)" % [_bone(body, "Hips").y, plain["Hips"].y])
	_check(absf(_bone(body, "Head").y - plain["Head"].y) < 0.01, "back to plain: head as plain")

	# Skin colour: the default skin leaves Dave's paint alone; a dark skin darkens this body's own copy of the material and not the glb's shared one.
	var plain_body: Node3D = plain["body"]
	_check(Body.skin_tint(Body.DEFAULT_SKIN).is_equal_approx(Color(1, 1, 1)), "default skin: no tint")
	var dark: Dictionary = Generator.make_genome("average", Color(0.36, 0.24, 0.17))
	body.set_proportions(dark)
	var own: Material = body.body_mesh.get_active_material(0)
	_check(own is BaseMaterial3D and (own as BaseMaterial3D).albedo_color.r < 0.6, "dark skin: albedo tinted darker")
	var shared: Material = plain_body.body_mesh.get_active_material(0)
	_check(shared is BaseMaterial3D and (shared as BaseMaterial3D).albedo_color.r > 0.95, "the other body keeps Dave's paint")

	# Width sliders (dynasty_shapes.gd): a genome with widths puts the shaped mesh on, with five blend shapes that really move vertices, weighted by the slider.
	var wide: Dictionary = Generator.make_genome()
	wide["build"] = 1.0
	wide["belly"] = -0.5
	var wide_body: Node3D = Body.new()
	root.add_child(wide_body)
	wide_body.set_proportions(wide)
	var shaped: Mesh = wide_body.body_mesh.mesh
	_check(shaped is ArrayMesh and (shaped as ArrayMesh).get_blend_shape_count() == 9, "widths: shaped mesh with 9 blend shapes (5 body, 4 face)")

	if shaped is ArrayMesh and (shaped as ArrayMesh).get_blend_shape_count() == 9:
		var base: PackedVector3Array = (shaped as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var blends: Array = (shaped as ArrayMesh).surface_get_blend_shape_arrays(0)
		var aabb: AABB = AABB(base[0], Vector3.ZERO)

		for p in base:
			aabb = aabb.expand(p)

		for n in range(9):
			var moved: float = 0.0
			var shape: PackedVector3Array = blends[n][Mesh.ARRAY_VERTEX]

			for v in range(0, base.size(), 7):
				moved = maxf(moved, shape[v].distance_to(base[v]))

			_check(moved > aabb.size.length() * (0.005 if n < 5 else 0.002) and moved < aabb.size.length() * 0.2, "widths: shape %d moves vertices a sensible amount (%.4f of %.4f)" % [n, moved, aabb.size.length()])

		var bi: int = (shaped as ArrayMesh).find_blend_shape_by_name("build")
		_check(absf(wide_body.body_mesh.get_blend_shape_value(bi) - 1.0) < 0.001, "widths: build weight 1")
		_check(absf(wide_body.body_mesh.get_blend_shape_value((shaped as ArrayMesh).find_blend_shape_by_name("belly")) + 0.5) < 0.001, "widths: belly weight -0.5")

	_check(not plain_body.body_mesh.mesh.has_meta("dynasty_shapes"), "widths: the plain body keeps Dave's own mesh")
	var own_wide: Material = wide_body.body_mesh.get_active_material(0)
	_check(own_wide is BaseMaterial3D, "widths: the shaped body still has its material")

	print("dynasty proportions tests: %d failures" % _fails)
	quit()
