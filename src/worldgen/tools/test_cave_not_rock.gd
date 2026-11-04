extends SceneTree

# BUG-027: placed structures (a lean-to roof) and plants are not rock for the cave enclosure rays; terrain and boulders are.
#   godot --headless --path . --script res://src/worldgen/tools/test_cave_not_rock.gd

const CaveSounds := preload("res://src/client/cave_sounds.gd")
const BuildingLook := preload("res://src/client/building_look.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var roof: StaticBody3D = BuildingLook._leanto_roof_body()
	check(CaveSounds.is_not_rock(roof), "a lean-to roof is not rock")
	var plant: StaticBody3D = StaticBody3D.new()
	plant.set_meta("species_ids", [1])
	check(CaveSounds.is_not_rock(plant), "a plant is not rock")
	var rock: StaticBody3D = StaticBody3D.new()
	check(not CaveSounds.is_not_rock(rock), "a plain static body (terrain, a boulder) is rock")
	print("cave not rock: %d failures" % failures)
	quit(1 if failures > 0 else 0)
