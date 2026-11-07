extends SceneTree

# Animals stop at walls (MikeW, 4 Nov 2026): every walker of server_animals.gd (grazers, fleeing game, foxes, moose, wolves)
# steps through Steering with the module's `crossing`, which asks server_items.structure_blocks_step (Hammer's grid, #166).
# A long wall stops a sprint dead, even with strides far longer than the wall is thick; a short wall is walked round.
#   godot --headless --path . --script res://src/worldgen/tools/test_animal_walls.gd

const AnimalsScript := preload("res://src/stream/server_animals.gd")
const GridScript := preload("res://src/stream/structure_grid.gd")
const Steering := preload("res://src/shared/steering.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)
	failures += 0 if ok else 1


func walk(a, from: Vector3, to: Vector3, speed: float, dt: float, steps: int) -> Array:
	var pos: Vector3 = from
	var heading: float = 0.0
	var min_z: float = from.z

	for i in range(steps):
		var r: Dictionary = Steering.step(pos, to, speed, dt, a.ground_height, a.blocked, 0.4, heading, a.crossing)

		if r["arrived"]:
			break

		pos = r["pos"]
		heading = r["heading"]
		min_z = minf(min_z, pos.z)

	return [pos, min_z]


func _init() -> void:
	var a = AnimalsScript.new()
	a.ground_height = func(_x, _z): return 10.0
	a.blocked = func(_x, _z): return false
	a.player_positions = func(): return []
	a.setup()
	a.traits = false   # seeded checks from before temperaments and young (test_big_game covers those)

	var grid = GridScript.new()
	var items: Dictionary = {1: {"struct": {"kind": "log_wall"}}, 2: {"struct": {"kind": "log_wall"}}}
	grid.add(1, "log_wall", 0.0, 0.0, 0.0, 40.0, 0.25)     # a long wall along x at z = 0
	grid.add(2, "log_wall", 100.0, 0.0, 0.0, 2.0, 0.25)    # a short one at x = 100
	a.walls = func(x0, z0, x1, z1, margin): return grid.segment_blocked(x0, z0, x1, z1, margin, items)

	check(a.crosses_wall(0.0, 3.0, 0.0, -3.0), "a 6 m stride across the wall is a crossing")
	check(not a.crosses_wall(0.0, 3.0, 5.0, 3.0), "a stride beside it is not")

	# A fleeing rabbit at 11 m/s with 0.5 s steps (5.5 m strides) runs at the long wall: it never gets to the far side.
	var sprint: Array = walk(a, Vector3(0.0, 10.0, 8.0), Vector3(0.0, 10.0, -8.0), 11.0, 0.5, 40)
	check(sprint[1] > 0.0, "a sprint at the long wall stays on its side (closest z %.2f)" % sprint[1])

	# The same rabbit heading through the short wall goes round it and arrives.
	var round_it: Array = walk(a, Vector3(100.0, 10.0, 6.0), Vector3(100.0, 10.0, -6.0), 1.5, 0.25, 200)
	check((round_it[0] as Vector3).distance_to(Vector3(100.0, 10.0, -6.0)) < 1.0, "a walk at the short wall goes round it and arrives")

	# The wall taken down: the way is open again.
	items.erase(1)
	var free: Array = walk(a, Vector3(0.0, 10.0, 8.0), Vector3(0.0, 10.0, -8.0), 11.0, 0.5, 40)
	check((free[0] as Vector3).z < -7.0, "with the wall gone the rabbit runs straight through")

	# Without the hook (tests, old saves) nothing is blocked.
	var b = AnimalsScript.new()
	b.setup()
	b.traits = false   # seeded checks from before temperaments and young (test_big_game covers those)
	check(not b.crosses_wall(0.0, 3.0, 0.0, -3.0), "no walls hook means no walls")

	print("test_animal_walls: %d fail" % failures)
	quit(1 if failures > 0 else 0)
