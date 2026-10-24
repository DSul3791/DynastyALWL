extends SceneTree

# Join hang (Dave, build 787): the ground under the player never loads and nothing is outstanding. Simulates the join with a real stream's test drop
# (--drop-ground-blocks) and the watchdog, with and without the fix.
#   godot --headless --path . --script res://src/worldgen/tools/test_ground_watchdog.gd
# Prints "Test done: N pass, N fail".

const StreamScript := preload("res://src/stream/network_voxel_stream.gd")
const WatchdogScript := preload("res://src/client/ground_watchdog.gd")

var passes: int = 0
var failures: int = 0


func check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		print("FAIL ", what)


# One join: the engine asks a stream once for the block under the player. `drop` blocks fail for good on the first stream (and on every new stream when
# `drop_new` is true). Returns {"opened_s": seconds until the ground was ready or -1, "gave_up_s": seconds until give_up or -1, "tries": retries made}.
func _join(drop: int, drop_new: bool, fix: bool, limit_s: float) -> Dictionary:
	var key: Vector4i = Vector4i(3, 1, 4, 0)
	var stream = StreamScript.new()
	stream.drop_blocks_left = drop
	var ready: bool = not stream._drop_for_test(key)
	var watchdog = WatchdogScript.new()
	var opened: float = 0.0 if ready else -1.0
	var gave_up: float = -1.0
	var now: int = 0

	while opened < 0.0 and gave_up < 0.0 and float(now) * 0.001 < limit_s:
		now += 100
		var action: String = watchdog.step(now, not ready, 0) if fix else ""

		if action == "retry":
			stream = StreamScript.new()
			stream.drop_blocks_left = drop if drop_new else 0
			ready = not stream._drop_for_test(key)
		elif action == "give_up":
			gave_up = float(now) * 0.001

		if ready:
			opened = float(now) * 0.001

	return {"opened_s": opened, "gave_up_s": gave_up, "tries": watchdog.tries}


func _init() -> void:
	var hang: Dictionary = _join(1, false, false, 120.0)
	check(hang["opened_s"] < 0.0, "without the fix the dropped ground block never comes (120 s, hangs)")

	var fixed: Dictionary = _join(1, false, true, 120.0)
	check(fixed["opened_s"] >= 0.0 and fixed["opened_s"] <= 15.0, "with the fix the ground opens within 15 s (%.1f s)" % fixed["opened_s"])
	check(fixed["tries"] == 1, "one retry was enough (%d)" % fixed["tries"])

	var clean: Dictionary = _join(0, false, true, 120.0)
	check(clean["opened_s"] == 0.0 and clean["tries"] == 0, "a normal join never triggers the watchdog")

	var stubborn: Dictionary = _join(1, true, true, 200.0)
	check(stubborn["tries"] == 6 and stubborn["gave_up_s"] > 0.0 and stubborn["gave_up_s"] <= 80.0, "a ground that never comes gives up after 6 tries within 80 s (%.1f s, %d tries)" % [stubborn["gave_up_s"], stubborn["tries"]])

	# The test drop: the first N distinct blocks fail every time, later ones and a new stream are fine.
	var stream = StreamScript.new()
	stream.drop_blocks_left = 2
	var a: Vector4i = Vector4i(0, 0, 0, 0)
	var b: Vector4i = Vector4i(1, 0, 0, 0)
	var c: Vector4i = Vector4i(2, 0, 0, 0)
	check(stream._drop_for_test(a) and stream._drop_for_test(a) and stream._drop_for_test(b) and not stream._drop_for_test(c), "--drop-ground-blocks: the first N blocks fail every time, the next ones do not")
	check(not StreamScript.new()._drop_for_test(a), "a new stream drops nothing")

	# With a column set, only blocks holding that x,z (at any LOD) are dropped: the far coarse blocks the engine loads first are not.
	var column = StreamScript.new()
	column.drop_blocks_left = 5
	column.drop_xz = Vector2(53301.0, 68427.0)
	check(not column._drop_for_test(Vector4i(50, 4, 63, 6)), "a coarse far block outside the spawn column is not dropped")
	check(column._drop_for_test(Vector4i(int(floor(53301.0 / 16.0)), 3, int(floor(68427.0 / 16.0)), 0)), "the LOD 0 block under the spawn is dropped")
	check(column._drop_for_test(Vector4i(int(floor(53301.0 / 1024.0)), 0, int(floor(68427.0 / 1024.0)), 6)), "the LOD 6 block over the spawn is dropped")
	check(column.drop_blocks_left == 3, "only dropped blocks use up the count (%d left)" % column.drop_blocks_left)

	# The watchdog does nothing while ground is not wanted, or while blocks are still outstanding (under 60 s).
	var idle = WatchdogScript.new()
	var quiet: bool = true

	for t in range(1, 600):
		quiet = quiet and idle.step(t * 100, false, 0) == ""
		quiet = quiet and idle.step(t * 100, true, 5) == ""

	check(quiet and idle.tries == 0, "no retry while not waiting, nor while 5 blocks are outstanding for under 60 s")

	var busy = WatchdogScript.new()
	var fired: int = 0

	for t in range(1, 1300):
		if busy.step(t * 100, true, 5) == "retry":
			fired += 1

	check(fired == 3, "blocks outstanding but no ground: retried at 60, 90 and 120 s (%d in 130 s)" % fired)

	# A stream that keeps delivering (received rising, a block outstanding now and then) never trips the 8 s rule; one that stops delivering does.
	var flowing = WatchdogScript.new()
	var flow_fired: int = 0

	for t in range(1, 500):
		if flowing.step(t * 100, true, t % 2, t) == "retry":
			flow_fired += 1

	check(flow_fired == 0, "blocks arriving all the time, pending flickering 0/1: no retry in 50 s (%d)" % flow_fired)

	var stalled = WatchdogScript.new()
	var stall_at: int = -1

	for t in range(1, 400):
		var got: int = mini(t, 30)   # blocks arrive for 3 s, then nothing, one still outstanding
		if stalled.step(t * 100, true, 1, got) == "retry" and stall_at < 0:
			stall_at = t * 100

	check(stall_at >= 10900 and stall_at <= 11200, "delivery stops at 3 s with a block outstanding: retry 8 s later (%.1f s)" % (float(stall_at) * 0.001))

	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
