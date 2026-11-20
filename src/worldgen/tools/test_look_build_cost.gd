extends SceneTree

# Item looks (src/client/basic_look.gd) are built in GDScript part by part. Lag check (3 Nov 2026): every look is timed once; a look is built once per
# run and shared, so taking a tool or food in hand again costs nothing. Prints the five slowest looks.
# A look over the bar is built cold twice more and judged by its best build (20 Nov 2026: on Dave's PC one first build read 248 ms in a full run and
# 56 ms alone, then 9 to 11 ms on the next three runs, a different saw each time: the machine stalling the process, not the look). A look that
# is really slow is slow every time and still fails; all three builds are printed. It runs in the serial lane (tools/test_lanes.json).
#   godot --headless --path . --script res://src/worldgen/tools/test_look_build_cost.gd

const BasicLook := preload("res://src/client/basic_look.gd")
const FIRST_BAR_MS := 40.0     # one look's first build
const AGAIN_BAR_MS := 0.2      # any later ask for it
const RETIMES := 2             # more cold builds of a look over FIRST_BAR_MS

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _init() -> void:
	BasicLook.entry("")   # loads looks.json
	var ids: Array = BasicLook._table.keys() + BasicLook.ART_OVERRIDES.keys()
	var times: Array = []
	var worst_again: float = 0.0

	for id in ids:
		if BasicLook._built.has(id):
			continue

		var t0: int = Time.get_ticks_usec()
		var first: Mesh = BasicLook.mesh_for(str(id))
		var first_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		t0 = Time.get_ticks_usec()
		var again: Mesh = BasicLook.mesh_for(str(id))
		var again_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		worst_again = maxf(worst_again, again_ms)
		times.append([first_ms, str(id)])

		if first != null and again != first:
			check(false, "%s: the second ask returns the same mesh" % id)

	for row in times:
		if float(row[0]) < FIRST_BAR_MS:
			continue

		var builds: Array = [row[0]]

		for _n in RETIMES:
			BasicLook._built.erase(row[1])   # cold again: the look is built part by part as on its first ask
			var t1: int = Time.get_ticks_usec()
			BasicLook.mesh_for(str(row[1]))
			builds.append(float(Time.get_ticks_usec() - t1) / 1000.0)

		row[0] = builds.min()
		print("re-timed %s: %s ms (best %.1f)" % [row[1], ", ".join(builds.map(func(b): return "%.1f" % b)), row[0]])

	times.sort_custom(func(a, b): return a[0] > b[0])
	print("look build: %d looks; slowest: %s" % [times.size(), ", ".join(times.slice(0, 5).map(func(t): return "%s %.1f ms" % [t[1], t[0]]))])
	check(times.is_empty() or float(times[0][0]) < FIRST_BAR_MS, "no look takes over %.0f ms to build (%s)" % [FIRST_BAR_MS, "none" if times.is_empty() else "%s %.1f ms" % [times[0][1], times[0][0]]])
	check(worst_again < AGAIN_BAR_MS, "asking again is free (worst %.3f ms)" % worst_again)
	print("test_look_build_cost: %d failures" % failures)
	quit(1 if failures > 0 else 0)
