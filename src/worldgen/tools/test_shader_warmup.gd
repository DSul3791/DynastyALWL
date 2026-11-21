extends SceneTree

# BugsList 93: the join's shader warm-up (src/client/shader_warmup.gd) finds the world's 3D materials (on nodes, in meshes, kept in a
# script for later, next passes), shows each once on the warm-up layer while the camera sees only that layer, and gives the camera
# back its own view when done. Headless: nothing is drawn, the bookkeeping is checked.
# Run: godot --headless --path . --script res://src/worldgen/tools/test_shader_warmup.gd

const WarmupScript := preload("res://src/client/shader_warmup.gd")

var failures: int = 0


func check(ok: bool, text: String) -> void:
	if not ok:
		print("FAIL " + text)
		failures += 1


func _init() -> void:
	var world: Node3D = Node3D.new()
	root.add_child(world)
	var camera: Camera3D = Camera3D.new()
	camera.cull_mask = 0xFFFFF
	world.add_child(camera)

	var on_node: StandardMaterial3D = StandardMaterial3D.new()
	var in_mesh: StandardMaterial3D = StandardMaterial3D.new()
	var second_pass: StandardMaterial3D = StandardMaterial3D.new()
	in_mesh.next_pass = second_pass
	var kept: ShaderMaterial = ShaderMaterial.new()
	kept.shader = Shader.new()
	kept.shader.code = "shader_type spatial;\nvoid fragment() { ALBEDO = vec3(0.5); }\n"
	var canvas: ShaderMaterial = ShaderMaterial.new()
	canvas.shader = Shader.new()
	canvas.shader.code = "shader_type canvas_item;\n"

	var a: MeshInstance3D = MeshInstance3D.new()
	a.mesh = BoxMesh.new()
	a.material_override = on_node
	world.add_child(a)
	var b: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.material = in_mesh
	b.mesh = box
	a.add_child(b)
	var shared: MeshInstance3D = MeshInstance3D.new()
	shared.mesh = BoxMesh.new()
	shared.material_override = on_node   # the same material twice is shown once
	world.add_child(shared)

	# A script that keeps materials for later, in a dictionary, before anything in the world uses them.
	var keeper: Node = Node.new()
	var keeper_script: GDScript = GDScript.new()
	keeper_script.source_code = "extends Node\nvar looks: Dictionary = {}\nvar flat: Material\n"
	keeper_script.reload()
	keeper.set_script(keeper_script)
	keeper.set("looks", {"tree": kept})
	keeper.set("flat", canvas)
	world.add_child(keeper)

	var warm = WarmupScript.new()
	var roots: Array[Object] = [world]
	warm.start(camera, roots)
	check(warm.busy, "busy after start")
	check(camera.cull_mask == WarmupScript.LAYER, "the camera sees only the warm-up layer (mask %d)" % camera.cull_mask)

	var frames: int = 0

	while frames < 50:
		warm.step()
		frames += 1

	check(warm.busy and camera.cull_mask == WarmupScript.LAYER, "still warming while the ground is not ready")
	warm.ground_ready = true
	warm.sweep_msec = 0

	while warm.busy and frames < 200:
		warm.step()
		frames += 1

	check(not warm.busy, "done within 200 frames once the ground is ready")
	check(warm.shown == 4, "four 3D materials shown, the canvas one left out (shown %d)" % warm.shown)
	check(camera.cull_mask == 0xFFFFF, "the camera's own mask is back (mask %d)" % camera.cull_mask)

	for material in [on_node, in_mesh, second_pass, kept]:
		check(warm._seen.has(material), "material found: %s" % str(material))

	# Materials made after the first sweep are found by a later one.
	var warm2 = WarmupScript.new()
	warm2.start(camera, roots)
	warm2.start(camera, roots)   # a second start while busy changes nothing
	warm2.ground_ready = true
	warm2.sweep_msec = 0
	var late: MeshInstance3D = MeshInstance3D.new()
	late.mesh = BoxMesh.new()
	late.material_override = StandardMaterial3D.new()
	world.add_child(late)
	frames = 0

	while warm2.busy and frames < 200:
		warm2.step()
		frames += 1

	check(warm2.shown == 5, "a material added during the warm-up is shown by a later sweep (shown %d)" % warm2.shown)
	check(camera.cull_mask == 0xFFFFF, "the second start kept the camera's own mask (mask %d)" % camera.cull_mask)

	# finish() early (the join window closed) gives the view back at once.
	var warm3 = WarmupScript.new()
	warm3.start(camera, roots)
	warm3.finish()
	check(not warm3.busy and camera.cull_mask == 0xFFFFF, "finish gives the view back")

	world.queue_free()
	print("test_shader_warmup: %d failures" % failures)
	quit(failures)
