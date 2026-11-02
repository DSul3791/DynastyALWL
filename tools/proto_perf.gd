extends SceneTree

# PROTOTYPE (Sonny, 2026-10-30), plan 16: frame time of 20 animated bodies drawn in a bare test scene with one sun with shadows, on the real GPU.
#   godot --path . --resolution 1280x720 --script res://tools/proto_perf.gd
# Needs a window. Compares: nothing, 20 old ragdolls, 20 generated bodies without fingers at 4.5 cm (the NPC setting), 20 generated bodies with fingers at 3 cm (the player setting).
# It measures this PC (not the minimum machine) and a bare scene (not the game: no terrain, trees, grass, water or sound). Frame times include the whole frame.

const Generator := preload("res://src/client/character/body_generator.gd")
const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const RagdollScript := preload("res://src/client/ragdoll_body.gd")
const COUNT := 20
const WARM := 40
const FRAMES := 240

var _viewport_root: Node3D


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	_run()


func _frames(count: int) -> Array:
	var times: Array = []
	var last: int = Time.get_ticks_usec()

	for _i in range(count):
		await process_frame
		var now: int = Time.get_ticks_usec()
		times.append(float(now - last) / 1000.0)
		last = now

	return times


func _stats(times: Array) -> String:
	var sorted: Array = times.duplicate()
	sorted.sort()
	var sum: float = 0.0

	for v in sorted:
		sum += float(v)

	return "average %.2f ms, 95th percentile %.2f ms, worst %.2f ms" % [sum / float(sorted.size()), float(sorted[int(sorted.size() * 0.95)]), float(sorted[sorted.size() - 1])]


func _run() -> void:
	_viewport_root = Node3D.new()
	root.add_child(_viewport_root)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.72, 0.8)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.62, 0.66)
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_viewport_root.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45.0, -30.0, 0.0)
	sun.shadow_enabled = true
	_viewport_root.add_child(sun)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(60.0, 60.0)
	floor_mesh.mesh = plane
	_viewport_root.add_child(floor_mesh)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 50.0
	_viewport_root.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 4.0, 12.0), Vector3(0.0, 1.0, 0.0))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("renderer: %s, window %s" % [RenderingServer.get_video_adapter_name(), str(root.size)])
	await _frames(WARM)
	lines.append("empty scene:                                   " + _stats(await _frames(FRAMES)))

	for variant in [["20 old ragdolls", 0], ["20 generated bodies, no fingers, 4.5 cm (NPC setting)", 1], ["20 generated bodies, fingers, 3 cm (player setting)", 2]]:
		var holder: Node3D = Node3D.new()
		_viewport_root.add_child(holder)
		var t_make: int = Time.get_ticks_usec()

		for i in range(COUNT):
			var body: Node3D
			var kind: int = variant[1]

			if kind == 0:
				body = RagdollScript.new()
			elif kind == 1:
				body = GeneratedBody.new(Generator.genome_from_seed(i % 8), 0.045, false, true)
			else:
				body = GeneratedBody.new(Generator.genome_from_seed(i % 8), 0.03, true, true)

			body.position = Vector3(float(i % 5) * 1.6 - 3.2, 0.0, float(i / 5) * -1.6)
			body.rotation_degrees.y = 180.0
			holder.add_child(body)
			var player: AnimationPlayer = body.get("animation_player")
			player.play("walk")

		var made_ms: float = float(Time.get_ticks_usec() - t_make) / 1000.0
		await _frames(WARM)
		lines.append("%s: %s  (made in %.0f ms)" % [str(variant[0]).rpad(52), _stats(await _frames(FRAMES)), made_ms])
		holder.queue_free()
		await _frames(5)

	var file: FileAccess = FileAccess.open("res://art/character_proto/perf.txt", FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()
	print("\n".join(lines))
	quit()
