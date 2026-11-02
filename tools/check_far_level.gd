extends SceneTree

# Headless check and measurement (Sonny, plan 18): the far level of a generated body (7 cm grid, no fingers, no face) is much lighter than the NPC near level, uses the
# same bones, is shared between bodies of the same type, switches back and forth, and the mesh bound to the skeleton still skins (bones indices inside the skeleton).
#   godot --headless --path . --script res://tools/check_far_level.gd
# Exit code 1 on any failure.

const Generator := preload("res://src/client/character/body_generator.gd")
const GeneratedBody := preload("res://src/client/character/generated_body.gd")

var _fails: int = 0
var _checked: int = 0


func _initialize() -> void:
	_check_sizes()
	_check_switch()
	_check_sharing()
	print("checked %d cases, %d failures" % [_checked, _fails])
	quit(1 if _fails > 0 else 0)


func _ok(ok: bool, what: String) -> void:
	_checked += 1

	if not ok:
		_fails += 1
		print("FAIL  " + what)


func _check_sizes() -> void:
	for seed_value in [1, 2, 3]:
		var g: Dictionary = Generator.genome_from_seed(seed_value)
		var rows: Array = []

		for level in [[0.03, true], [0.045, false], [0.07, false], [0.1, false]]:
			var b: Dictionary = Generator.build(g, float(level[0]), bool(level[1]))
			rows.append(b)

		var tri: Array = []

		for b2 in rows:
			tri.append(int(b2["triangle_count"]))

		print("seed %d triangles: 3 cm with fingers %d, 4.5 cm %d, 7 cm %d, 10 cm %d; build ms %.0f / %.0f / %.0f / %.0f" % [seed_value, tri[0], tri[1], tri[2], tri[3], float((rows[0]["ms"] as Dictionary)["total"]), float((rows[1]["ms"] as Dictionary)["total"]), float((rows[2]["ms"] as Dictionary)["total"]), float((rows[3]["ms"] as Dictionary)["total"])])
		_ok(tri[2] < tri[1] * 0.6, "seed %d: the far level has well under 60%% of the near NPC level's triangles (%d vs %d)" % [seed_value, tri[2], tri[1]])
		var arrays: Array = rows[2]["arrays"]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var ok: bool = true

		for bi in bones:
			if bi < 0 or bi >= Generator.BONES.size():
				ok = false

		_ok(ok, "seed %d: far mesh bone indices are inside the skeleton" % seed_value)


func _check_switch() -> void:
	var body: Node3D = GeneratedBody.new(Generator.genome_from_seed(4), 0.045, false, true)
	root.add_child(body)
	var near: Mesh = body.body_mesh.mesh
	_ok(not body.is_far() and body.face.visible, "a new body is near, with its face")
	body.set_far(true)
	_ok(body.is_far() and not body.face.visible, "far hides the face")
	_ok(body.body_mesh.mesh != near and body.body_mesh.mesh.surface_get_array_len(0) < near.surface_get_array_len(0), "far swaps in a mesh with fewer vertices (%d vs %d)" % [body.body_mesh.mesh.surface_get_array_len(0), near.surface_get_array_len(0)])
	_ok(body.body_mesh.skin != null and body.body_mesh.skeleton == NodePath(".."), "the skin and skeleton binding stay")
	body.set_far(false)
	_ok(body.body_mesh.mesh == near and body.face.visible, "back to near restores the same mesh and the face")
	body.queue_free()


func _check_sharing() -> void:
	var g: Dictionary = Generator.genome_from_seed(6)
	var a: Node3D = GeneratedBody.new(g, 0.045, false, true)
	var b: Node3D = GeneratedBody.new(g, 0.045, false, true)
	root.add_child(a)
	root.add_child(b)
	a.set_far(true)
	var t0: int = Time.get_ticks_usec()
	b.set_far(true)
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	_ok(a.body_mesh.mesh == b.body_mesh.mesh, "two bodies of one type share the far mesh")
	_ok(ms < 5.0, "the second far switch only swaps a mesh (%.2f ms)" % ms)
	var pa: AnimationPlayer = a.animation_player
	pa.play("walk")
	pa.advance(0.3)
	_ok(a.skeleton.get_bone_pose_position(a.skeleton.find_bone("Hips")).is_finite(), "animating a far body works")
	a.queue_free()
	b.queue_free()
