extends SceneTree

# No build sounds while the world loads (Dave 21 Nov 2026 play test: at login "it makes the sounds of building everything really fast. during
# this time it shouldn't"): PlacedSounds.watch_world only notes rows while `quiet`, and a batch of more than BULK_ROWS rows appearing near the
# player at once (the world streaming in) is silent; one thing placed after the load is still heard.
#   godot --headless --path . --script res://src/worldgen/tools/test_placed_quiet.gd

const StructureLook := preload("res://src/shared/structure_look.gd")


class Counting extends "res://src/client/placed_sounds.gd":
	var heard: int = 0

	func place(_kind: String, _at: Vector3) -> bool:
		heard += 1
		return true

	func pick_up(_at: Vector3) -> bool:
		return true


var failures: int = 0


func check(ok: bool, what: String) -> void:
	print("%s: %s" % ["pass" if ok else "FAIL", what])
	failures += 0 if ok else 1


func _init() -> void:
	var state: int = 6
	check(StructureLook.sound_of(state) != "", "state %d (a chest) makes a placed sound" % state)
	var here: Vector3 = Vector3.ZERO
	var sounds: Counting = Counting.new()
	var world: Dictionary = {}
	sounds.watch_world(world, here)   # primes

	sounds.quiet = true   # the join: the town streams in round the player

	for id in 12:
		world[100 + id] = {"state": state, "pos": Vector3(float(id), 0.0, 3.0)}

	sounds.watch_world(world, here)
	world[200] = {"state": state, "pos": Vector3(1.0, 0.0, -3.0)}
	sounds.watch_world(world, here)
	check(sounds.heard == 0, "nothing is heard while the world loads (%d)" % sounds.heard)

	sounds.quiet = false

	for id in 8:
		world[300 + id] = {"state": state, "pos": Vector3(float(id), 0.0, 6.0)}

	sounds.watch_world(world, here)
	check(sounds.heard == 0, "a late batch of %d rows streaming in near the player is silent too (%d)" % [8, sounds.heard])

	world[400] = {"state": state, "pos": Vector3(2.0, 0.0, 2.0)}
	sounds.watch_world(world, here)
	check(sounds.heard == 1, "one chest set down after the load is heard (%d)" % sounds.heard)

	sounds.free()
	print("placed quiet: %d failures" % failures)
	quit(1 if failures > 0 else 0)
