extends SceneTree

# The motion audit (src/client/motion_audit.gd): a walk held still while the keys ask is a stop with what it touched ("no cause" when only
# the floor was), a slow stretch on flat ground is a slow, the body set elsewhere between walk frames is a snap, the stuck rescue moving it is a
# snap, a log or an animal moving it more than a step is a push; the summary gives the share of the asked distance made per gait.
#   godot --headless --path . --script res://src/worldgen/tools/test_motion_audit.gd

const MotionAudit := preload("res://src/client/motion_audit.gd")
const DT := 1.0 / 60.0

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _walk(audit, frames: int, at: Vector3, asked: Vector3, share: float, touched: Array = [], floor_y: float = 1.0, gait: String = "walk") -> Vector3:
	for n in frames:
		var to: Vector3 = at + asked * DT * share
		audit.frame(DT, gait, asked, at, to, to, to, touched, floor_y)
		at = to

	return at


func _init() -> void:
	var audit = MotionAudit.new()
	var at: Vector3 = _walk(audit, 120, Vector3.ZERO, Vector3(3.2, 0, 0), 1.0)
	check(audit.lines == 0, "a free walk prints nothing")
	at = _walk(audit, 40, at, Vector3(3.2, 0, 0), 0.0, [["Terrain/VoxelLodTerrain", Vector3.UP]])
	at = _walk(audit, 10, at, Vector3(3.2, 0, 0), 1.0)
	check(audit.last_line.begins_with("stop walk 0.7 s") and audit.last_line.contains("no cause: only the floor"), "held 0.67 s on the floor alone: a stop with no cause (%s)" % audit.last_line)
	at = _walk(audit, 10, at, Vector3(3.2, 0, 0), 0.0, [["Flora/Tree", Vector3(-1, 0, 0)]])
	at = _walk(audit, 5, at, Vector3(3.2, 0, 0), 1.0)
	check(not audit.last_line.contains("Tree"), "a 0.17 s hold at a trunk is no stop")
	at = _walk(audit, 30, at, Vector3(3.2, 0, 0), 0.0, [["Flora/Tree", Vector3(-1, 0, 0)]])
	at = _walk(audit, 5, at, Vector3(3.2, 0, 0), 1.0)
	check(audit.last_line.contains("Flora/Tree (normal -1.00,0.00,0.00)") and not audit.last_line.contains("no cause"), "held at a trunk: the trunk is named, not 'no cause'")
	at = _walk(audit, 90, at, Vector3(3.2, 0, 0), 0.5)
	at = _walk(audit, 5, at, Vector3(3.2, 0, 0), 1.0)
	check(audit.last_line.begins_with("slow walk 1.5 s") and audit.last_line.contains("(50%)"), "half pace on flat ground for 1.5 s is a slow stretch (%s)" % audit.last_line)
	var before: int = audit.lines
	at = _walk(audit, 90, at, Vector3(3.2, 0, 0), 0.5, [], 0.8)
	check(audit.lines == before, "half pace up a slope is not a slow stretch (a slope is slower)")
	audit.frame(DT, "walk", Vector3(3.2, 0, 0), at + Vector3(2, 0, 0), at + Vector3(2.05, 0, 0), at + Vector3(2.05, 0, 0), at + Vector3(2.05, 0, 0), [], 1.0)
	check(audit.last_line.begins_with("snap 2.00 m"), "set 2 m away between walk frames: a snap (%s)" % audit.last_line)
	at += Vector3(2.05, 0, 0)
	audit.frame(DT, "walk", Vector3(3.2, 0, 0), at, at + Vector3(0.05, 0, 0), at + Vector3(0.45, 0, 0), at + Vector3(0.45, 0, 0), [], 1.0)
	check(audit.last_line.begins_with("push 0.40 m"), "a log or an animal moved it 0.4 m: a push")
	at += Vector3(0.45, 0, 0)
	audit.frame(DT, "walk", Vector3(3.2, 0, 0), at, at + Vector3(0.05, 0, 0), at + Vector3(0.05, 0, 0), at + Vector3(0.05, 3, 0), [], 1.0)
	check(audit.last_line.contains("the stuck rescue moved the body"), "the rescue lifting it 3 m is a snap named as the rescue")
	audit.reset()
	audit.frame(DT, "walk", Vector3(3.2, 0, 0), at + Vector3(50, 0, 0), at + Vector3(50.05, 0, 0), at + Vector3(50.05, 0, 0), at + Vector3(50.05, 0, 0), [], 1.0)
	check(not audit.last_line.begins_with("snap 5"), "after a seat, a bed or a ladder (reset) the next walk frame is not a snap")
	var row: Dictionary = audit.gait_row("walk")
	check(int(row["stops"]) == 2 and int(row["slows"]) == 1 and int(row["snaps"]) == 2 and int(row["pushes"]) == 1, "the walk's counts: 2 stops, 1 slow, 2 snaps, 1 push (%s)" % str(row))
	_walk(audit, 60, at, Vector3(0.1, 0, 0), 0.0)
	check(int(audit.gait_row("walk")["stops"]) == 2, "a crawl under 0.3 m/s is not judged")
	var split = MotionAudit.new()
	var p: Vector3 = _walk(split, 60, Vector3.ZERO, Vector3(3.2, 0, 0), 0.5, [["Flora/Tree", Vector3(-1, 0, 0)]])
	p = _walk(split, 60, p, Vector3(3.2, 0, 0), 0.75, [], 0.8)
	p = _walk(split, 60, p, Vector3(3.2, 0, 0), 0.9)
	split.summary()
	check(split.last_line.contains("short 17% against things, 8% on slopes, 3% on clear flat ground"), "where the distance went: against a trunk, up a slope, on clear ground (%s)" % split.last_line)
	var carried = MotionAudit.new()
	var c: Vector3 = Vector3.ZERO

	for n in 60:   # every other frame goes nowhere and the next makes up for it (the walk's carried headway): full pace
		var to: Vector3 = c + Vector3(3.2, 0, 0) * DT * (0.0 if n % 2 == 0 else 2.0)
		carried.frame(DT, "crouch", Vector3(3.2, 0, 0), c, to, to, to, [], 1.0)
		c = to

	carried.summary()
	check(carried.last_line.contains("100% of the asked distance made") and carried.last_line.contains("0% on clear flat ground"), "a frame short then a frame long (the carried headway) is full pace (%s)" % carried.last_line)
	audit.summary()
	check(audit.last_line.begins_with("summary walk:"), "the summary names each gait")
	print("motion audit test: %d failures" % failures)
	quit(failures)
