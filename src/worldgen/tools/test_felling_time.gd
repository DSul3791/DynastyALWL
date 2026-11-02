extends SceneTree

# The time to fell a tree and cut it into logs stays the same when the axe swing gets slower (balance, 31 Oct: the swing went from 0.55 s to 1.05 s, Dave tunes data/items/drops.json "felling").
# Compares the old blow counts and swing time with the current ones for trunks 0.1 to 0.8 m thick: felling, the first branch blows, a log, a stump.
#   godot --headless --path . --script res://src/worldgen/tools/test_felling_time.gd

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var drops: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/drops.json"))
	var fell: Dictionary = drops["felling"]
	var trunk: Dictionary = drops["trunk"]
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

	var old_log_s: float = float(fell["old_blows_per_log"]) * before
	var new_log_s: float = float(trunk["blows_per_log"]) * now
	check(absf(new_log_s / old_log_s - 1.0) <= 0.10, "cutting a log takes %.2f s, was %.2f s" % [new_log_s, old_log_s])
	var old_branch_s: float = float(fell["old_branch_blows"]) * before
	var new_branch_s: float = float(trunk["branch_blows"]) * now
	check(absf(new_branch_s / old_branch_s - 1.0) <= 0.35, "the branch blows take %.2f s, were %.2f s (a whole number of blows, at most 35 percent off)" % [new_branch_s, old_branch_s])
	var old_stump: float = ceil(3.0 + 0.3 * 15.0) * before
	var new_stump: float = ceil(float(stump["blows_base"]) + 0.3 * float(stump["blows_per_radius_m"])) * now
	check(absf(new_stump / old_stump - 1.0) <= 0.25, "chopping a 0.3 m stump takes %.1f s, was %.1f s" % [new_stump, old_stump])
	print("felling time tests: %d failures (mean felling time %.0f percent of the old)" % [failures, mean * 100.0])
	quit(1 if failures > 0 else 0)
