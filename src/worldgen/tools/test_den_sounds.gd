extends SceneTree

# Den sounds (den_sounds.gd): the nearest den, and that the generated files exist.
#   godot --headless --path . --script res://src/worldgen/tools/test_den_sounds.gd

const Den := preload("res://src/client/den_sounds.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var hit: Dictionary = Den.nearest([Vector3(0, 0, 0), Vector3(30, 0, 0)], Vector3(25, 0, 0))
	check(hit["point"] == Vector3(30, 0, 0) and is_equal_approx(float(hit["distance"]), 5.0), "nearest den is the one 5 m away")
	check(is_inf(float(Den.nearest([], Vector3.ZERO)["distance"])), "no dens: distance is infinite")

	for sound_name in ["den_breath_0", "den_shuffle_0"]:
		check(ResourceLoader.exists("res://assets/audio/den/%s.ogg" % sound_name), sound_name + " exists")

	quit(1 if failures > 0 else 0)
