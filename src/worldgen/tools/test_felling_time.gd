extends SceneTree

# The time to fell a tree and chop a stump stays the same when the axe swing gets slower (balance, 31 Oct: the swing went from 0.55 s to 1.05 s, Dave tunes data/items/drops.json "felling").
# Compares the old blow counts and swing time with the current ones for trunks 0.1 to 0.8 m thick: felling and a stump (a felled tree comes down in its
# logs, 16 Nov 2026: there is no trunk to cut).
#   godot --headless --path . --script res://src/worldgen/tools/test_felling_time.gd

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var drops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
	var fell: Dictionary = drops["felling"]
	var stump: Dictionary = drops["stump"]
	var before: float = float(fell["swing_s_before"])
	var now: float = float(fell["swing_s_now"])
	var total_ratio: float = 0.0
	var counted: int = 0

	for hundredths in range(10, 81, 5):
		var radius: float = float(hundredths) / 100.0
		var old_blows: int = clampi(int(float(fell["old_tree_base"]) + radius * float(fell["old_tree_per_trunk_m"])), int(fell["old_tree_min"]), int(fell["old_tree_max"]))
		var new_blows: int = clampi(int(round(float(fell["tree_base"]) + radius * float(fell["tree_per_trunk_m"]))), int(fell["tree_min"]), int(fell["tree_max"]))
		var ratio: float = (float(new_blows) * now) / (float(old_blows) * before)
		total_ratio += ratio
		counted += 1

		if float(old_blows) * before >= 5.0:   # short jobs are a blow or two: one blow is already over 10 percent of them
			check(absf(ratio - 1.0) <= 0.10, "felling a %.2f m trunk takes %.1f s, was %.1f s (%.0f percent)" % [radius, new_blows * now, old_blows * before, ratio * 100.0])

	var mean: float = total_ratio / float(counted)
	check(absf(mean - 1.0) <= 0.10, "felling time over all trunk sizes is within 10 percent of the old (mean %.0f percent)" % (mean * 100.0))

	var old_stump: float = ceil(3.0 + 0.3 * 15.0) * before
	var new_stump: float = ceil(float(stump["blows_base"]) + 0.3 * float(stump["blows_per_radius_m"])) * now
	check(absf(new_stump / old_stump - 1.0) <= 0.25, "chopping a 0.3 m stump takes %.1f s, was %.1f s" % [new_stump, old_stump])
	print("felling time tests: %d failures (mean felling time %.0f percent of the old)" % [failures, mean * 100.0])
	quit(1 if failures > 0 else 0)
