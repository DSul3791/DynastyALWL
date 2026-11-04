extends SceneTree

# BUG-016/017: walking, crouch-walking and a slow turn-and-walk cross small lips (a stick 3 cm, a 1.5 cm seam, a 12 cm root) at every pace and
# heading, including due north and south, without stalling. Run: godot --headless --path . --script res://src/worldgen/tools/test_step_up_slow.gd

const StepUp := preload("res://src/client/step_up.gd")
const TICKS := 600   # physics ticks a second: the run is paced by the clock, so a fast tick keeps the test short
const D := 1.0 / 600.0

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _box(parent: Node3D, at: Vector3, size: Vector3) -> void:
	var b: StaticBody3D = StaticBody3D.new()
	var s: CollisionShape3D = CollisionShape3D.new()
	var bx: BoxShape3D = BoxShape3D.new()
	bx.size = size
	s.shape = bx
	b.add_child(s)
	b.position = at
	parent.add_child(b)


func _initialize() -> void:
	Engine.physics_ticks_per_second = TICKS
	var rn: Node3D = Node3D.new()
	root.add_child.call_deferred(rn)
	await process_frame
	_box(rn, Vector3(0, -0.5, 0), Vector3(200, 1, 200))
	# Lips every 0.6 m along both axes: thin strips of 1.5 cm, 3 cm and 12 cm.
	for n in range(-40, 41):
		var h: float = [0.015, 0.03, 0.12][posmod(n, 3)]
		_box(rn, Vector3(0, h * 0.5, n * 0.6 + 0.3), Vector3(200, h, 0.05))
		_box(rn, Vector3(n * 0.6 + 0.3, h * 0.5, 0), Vector3(0.05, h, 200))

	for crouch in [false, true]:
		for speed in ([0.63] if crouch else [1.4, 3.2]):
			for ang in [0.0, 180.0, 90.0, 270.0, 30.0]:
				var body: CharacterBody3D = CharacterBody3D.new()
				body.wall_min_slide_angle = 0.0
				var sh: CollisionShape3D = CollisionShape3D.new()
				var cap: CapsuleShape3D = CapsuleShape3D.new()
				cap.radius = 0.35
				cap.height = 1.2 if crouch else 1.8
				sh.shape = cap
				sh.position.y = -0.3 if crouch else 0.0
				body.add_child(sh)
				rn.add_child(body)
				body.global_position = Vector3(0.1, 1.0, 0.1)
				await physics_frame
				var dir: Vector3 = Vector3(sin(deg_to_rad(ang)), 0, cos(deg_to_rad(ang)))
				var start: Vector3 = body.global_position

				for k in 1500:
					body.velocity = dir * speed + Vector3(0, body.velocity.y - 20.0 * D, 0)

					if body.is_on_floor():
						StepUp.try(body, Vector3(body.velocity.x, 0.0, body.velocity.z) * D, 0.5)

					body.move_and_slide()
					await physics_frame

				var moved: float = Vector2(body.global_position.x - start.x, body.global_position.z - start.z).length()
				var want: float = speed * 2.5
				_check(moved > want * 0.95, "%s %.2f m/s heading %.0f crosses lips: %.2f of %.2f m" % ["crouch" if crouch else "walk", speed, ang, moved, want])
				body.queue_free()

	# The pace multipliers can never stall a walker: none is near 0 in the data.
	var path: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/path_speed.json"))
	var exertion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/exertion.json"))
	_check(float(path["walk_factor"]) >= 0.5 and float(path["jog_factor"]) >= 0.5 and float(path["run_factor"]) >= 0.5, "path pace factors are not near 0")
	_check(float(exertion["over_speed_factor"]) >= 0.5, "over-exerted pace factor is not near 0")
	print("step up slow: %d failures" % failures)
	quit(1 if failures > 0 else 0)
