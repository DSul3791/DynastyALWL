extends SceneTree

# Robots 23 Nov 2026 (plan moves, the built route): crouched, a player could not get onto a Refined foundation (its top 0.3 m over the ground),
# and walking stood at a 0.45 m edge, though step_up_m is 0.5; only a run went up. The hop lifted the body clear of the top but its round foot
# was still over the edge and it fell back. Now the landing is looked for StepUp.AHEAD_M over the edge and the body is held level for
# StepUp.HOVER_M after the hop (terrain_client._step_up). Walking, crouching and running onto ledges of 0.15 to 0.45 m make the pace's distance;
# a 0.6 m ledge (over step_up_m) still stops the walker. Under a doorway on the edge (its lintel 2 m over the top) the hop lifts only as far as
# the room under the lintel lets it.
#   godot --headless --path . --script res://src/worldgen/tools/test_step_onto_ledge.gd

const StepUp := preload("res://src/client/step_up.gd")
const TICKS := 600
const D := 1.0 / 600.0

var failures: int = 0


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _box(parent: Node3D, at: Vector3, size: Vector3) -> StaticBody3D:
	var b: StaticBody3D = StaticBody3D.new()
	var s: CollisionShape3D = CollisionShape3D.new()
	var bx: BoxShape3D = BoxShape3D.new()
	bx.size = size
	s.shape = bx
	b.add_child(s)
	b.position = at
	parent.add_child(b)
	return b


func _initialize() -> void:
	Engine.physics_ticks_per_second = TICKS
	var rn: Node3D = Node3D.new()
	root.add_child.call_deferred(rn)
	await process_frame
	_box(rn, Vector3(0, -0.5, 0), Vector3(60, 1, 60))

	for case in [[0.15, false], [0.3, false], [0.45, false], [0.6, false], [0.3, true], [0.45, true]]:
		var h: float = float(case[0])
		var ledge: StaticBody3D = _box(rn, Vector3(0, h * 0.5, -4.0), Vector3(4, h, 4))   # its face at z = -2
		var lintel: StaticBody3D = _box(rn, Vector3(0, h + 2.2, -2.0), Vector3(4, 0.4, 0.2)) if bool(case[1]) else null   # a doorway on the edge: 2 m clear over its top
		var where: String = " under a doorway's lintel" if bool(case[1]) else ""

		for gait in [["crouch", 0.64], ["walk", 3.2], ["run", 9.0]]:
			var pace: float = float(gait[1])
			var body: CharacterBody3D = CharacterBody3D.new()
			body.wall_min_slide_angle = 0.0
			body.safe_margin = 0.01   # terrain_client PLAYER_SAFE_MARGIN_M
			var sh: CollisionShape3D = CollisionShape3D.new()
			var cap: CapsuleShape3D = CapsuleShape3D.new()
			cap.radius = 0.35
			cap.height = 1.8
			sh.shape = cap
			body.add_child(sh)
			rn.add_child(body)
			body.global_position = Vector3(0.0, 0.92, 0.0)
			await physics_frame
			var hover: float = 0.0
			var ticks: int = int(3.0 / pace / D)   # the time 3 m takes at this pace

			for k in ticks:   # terrain_client._move_player's order: gravity, the hold, the hop, the slide, what is left of the hold
				var v: Vector3 = Vector3(0.0, body.velocity.y - 20.0 * D, -pace)

				if hover > 0.0:
					v.y = 0.0

				body.velocity = v

				if body.is_on_floor() and hover <= 0.0 and StepUp.try(body, Vector3(v.x, 0.0, v.z) * D, 0.5) > 0.0:
					hover = StepUp.HOVER_M
					body.velocity.y = 0.0

				var from: Vector3 = body.global_position
				body.move_and_slide()

				if hover > 0.0:
					hover = StepUp.hover_left(body, from, hover)

				await physics_frame

			var z: float = body.global_position.z
			var top: float = body.global_position.y - 0.9

			if h <= 0.5:
				_check(z < -2.6 and absf(top - h) < 0.05, "%s at %.2f m/s onto a %.2f m ledge%s: on it in the time 3 m takes (at z %.2f, feet %.2f m up)" % [gait[0], pace, h, where, z, top])
			else:
				_check(z > -2.0 and top < 0.1, "%s at %.2f m/s at a %.2f m ledge (over step_up_m): stopped at its face (z %.2f)" % [gait[0], pace, h, z])

			body.queue_free()
			await physics_frame

		ledge.queue_free()

		if lintel != null:
			lintel.queue_free()

		await physics_frame

	print("step onto ledge: %d failures" % failures)
	quit(1 if failures > 0 else 0)
