extends SceneTree

# The spawn clear of trees and shrubs (docs/design/no_spawn_placement_design.md 2; spawn_point.gd clear_of): a shrub on the spawn moves it to
# the nearest clear point; a ring of shrubs at 1.5 m moves it out past them; no shrub leaves it where it was; a ledge or a pond beside it is
# skipped; with nothing clear it stays.
#   godot --headless --path . --script res://src/worldgen/tools/test_spawn_clear.gd

const SpawnPointScript := preload("res://src/shared/spawn_point.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	var at: Vector2 = Vector2(100.0, 200.0)
	var flat: Callable = func(_x: float, _z: float) -> float: return 10.0
	var dry: Callable = func(_x: float, _z: float) -> bool: return false

	check(SpawnPointScript.clear_of(at, PackedVector2Array(), flat, dry) == at, "no tree or shrub: the spawn stays")
	check(SpawnPointScript.clear_of(at, PackedVector2Array([Vector2(103.0, 200.0)]), flat, dry) == at, "a shrub 3 m off: the spawn stays")

	var moved: Vector2 = SpawnPointScript.clear_of(at, PackedVector2Array([at]), flat, dry)
	check(moved != at and moved.distance_to(at) >= 2.0 and moved.distance_to(at) <= 2.01, "a shrub on the spawn: moved to the nearest clear ring, 2 m (%.2f m)" % moved.distance_to(at))

	var ring: PackedVector2Array = PackedVector2Array()

	for n in range(12):
		ring.append(at + Vector2.from_angle(TAU * float(n) / 12.0) * 1.5)

	var out: Vector2 = SpawnPointScript.clear_of(at, ring, flat, dry)
	var all_clear: bool = true

	for t in ring:
		all_clear = all_clear and out.distance_to(t) >= 2.0

	check(out != at and all_clear and out.distance_to(at) <= 4.01, "a ring of shrubs at 1.5 m: moved out past them (%.2f m)" % out.distance_to(at))

	# East of x 101 is a ledge (12 m) and north of z 199 is a pond: the move goes west or south.
	var ledge: Callable = func(x: float, _z: float) -> float: return 12.0 if x > 101.0 else 10.0
	var pond: Callable = func(_x: float, z: float) -> bool: return z < 199.0
	var skip: Vector2 = SpawnPointScript.clear_of(at, PackedVector2Array([at]), ledge, pond)
	check(skip != at and skip.x <= 101.0 and skip.y >= 199.0, "a ledge or a pond beside it is skipped (%s)" % str(skip))

	var sea: Callable = func(_x: float, _z: float) -> float: return -1.0
	check(SpawnPointScript.clear_of(at, PackedVector2Array([at]), sea, dry) == at, "nothing clear (all sea): the spawn stays")

	print("test_spawn_clear: ", "PASS" if failures == 0 else "%d FAILURES" % failures)
	quit(1 if failures > 0 else 0)
