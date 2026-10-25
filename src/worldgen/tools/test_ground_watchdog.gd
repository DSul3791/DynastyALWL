extends SceneTree

# Join hang (Dave, build 787): the ground under the player never loads and nothing is outstanding. Simulates the join with a real stream's test drop
# (--drop-ground-lods) and the watchdog, with and without the fix.
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


# One join: the engine asks a stream once for the block under the player. `drop` LODs of the column fail for good on the first stream (and on every new stream when
# `drop_new` is true). Returns {"opened_s": seconds until the ground was ready or -1, "gave_up_s": seconds until give_up or -1, "tries": retries made}.
func _join(drop: int, drop_new: bool, fix: bool, limit_s: float) -> Dictionary:
	var key: Vector4i = Vector4i(3, 1, 4, 0)
	var stream = StreamScript.new()
	stream.drop_lods = drop
	stream.drop_xz = Vector2(49.0, 65.0)   # inside the column of the block (3, 1, 4) at LOD 0
	var ready: bool = not stream._drop_for_test(key)
	var watchdog = WatchdogScript.new()
	var opened: float = 0.0 if ready else -1.0
	var gave_up: float = -1.0
	var now: int = 0
	var failed: int = stream.drops_made   # failures since the welcome, over every stream (the client carries them across a restart)

	while opened < 0.0 and gave_up < 0.0 and float(now) * 0.001 < limit_s:
		now += 100
		var action: String = watchdog.step(now, not ready, 0, 0, failed) if fix else ""

		if action == "retry":
			stream = StreamScript.new()
			stream.drop_lods = drop if drop_new else 0
			stream.drop_xz = Vector2(49.0, 65.0)
			ready = not stream._drop_for_test(key)
			failed += stream.drops_made
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

	# The test drop: every block of LOD 0 .. N-1 in the spawn column fails every time; coarser LODs, other columns and a new stream are fine.
	var column = StreamScript.new()
	column.drop_lods = 2
	column.drop_xz = Vector2(53301.0, 68427.0)
	var under: Vector4i = Vector4i(int(floor(53301.0 / 16.0)), 3, int(floor(68427.0 / 16.0)), 0)
	var lod1: Vector4i = Vector4i(int(floor(53301.0 / 32.0)), 1, int(floor(68427.0 / 32.0)), 1)
	var lod2: Vector4i = Vector4i(int(floor(53301.0 / 64.0)), 1, int(floor(68427.0 / 64.0)), 2)
	check(column._drop_for_test(under) and column._drop_for_test(under) and column._drop_for_test(lod1), "the blocks of LOD 0 and 1 under the spawn fail every time")
	check(not column._drop_for_test(lod2), "LOD 2 is not dropped when N is 2")
	check(not column._drop_for_test(Vector4i(50, 4, 63, 0)), "a block of another column is not dropped")
	check(column.drops_made == 2, "two distinct blocks dropped (%d)" % column.drops_made)
	check(not StreamScript.new()._drop_for_test(under), "a new stream drops nothing")

	# The watchdog does nothing while ground is not wanted, or while blocks are still outstanding (under 60 s).
	var idle = WatchdogScript.new()
	var quiet: bool = true

	for t in range(1, 600):
		quiet = quiet and idle.step(t * 100, false, 0) == ""
		quiet = quiet and idle.step(t * 100, true, 5) == ""

	check(quiet and idle.tries == 0, "no retry while not waiting, nor while 5 blocks are outstanding for under 60 s")

	# 25 Oct (BUG-001 reopened): nothing failed and blocks are outstanding but none arrive: only the stall retry, twice, from 30 s, never a give up.
	var busy = WatchdogScript.new()
	var fired: int = 0
	var gave: int = 0

	for t in range(1, 1300):
		var act: String = busy.step(t * 100, true, 5)
		fired += 1 if act == "retry" else 0
		gave += 1 if act == "give_up" else 0

	check(fired == 2 and gave == 0, "blocks outstanding, none arriving, nothing failed: two stall retries from 30 s, no give up (%d retries, %d give ups)" % [fired, gave])

	# Mike's failing run: the stream delivers for minutes (received rising, a block outstanding), nothing failed: never restarted.
	var slow = WatchdogScript.new()
	var slow_fired: int = 0

	for t in range(1, 2400):
		if slow.step(t * 100, true, 1, t * 5, 0) == "retry":
			slow_fired += 1

	check(slow_fired == 0, "a slow stream that keeps delivering with no failures is never restarted in 4 minutes (%d)" % slow_fired)

	# Everything arrived (pending 0, nothing new for ages) and nothing failed: collision is just late; only the two stall retries, never a failure retry or give up.
	var done = WatchdogScript.new()
	var done_acts: Array = []

	for t in range(1, 3000):
		var act2: String = done.step(t * 100, true, 0, 500, 0)

		if act2 != "":
			done_acts.append(act2)

	check(done_acts == ["retry", "retry"], "all blocks arrived, ground late: two stall retries at most, no give up (%s)" % str(done_acts))

	# New failures while idle retry (a real missing block), and new failures while still delivering wait for the idle.
	var failing = WatchdogScript.new()
	var first_retry: int = -1

	for t in range(1, 400):
		var got2: int = mini(t, 30)
		if failing.step(t * 100, true, 1, got2, 3) == "retry" and first_retry < 0:
			first_retry = t * 100

	check(first_retry >= 10900 and first_retry <= 11200, "delivery stops, 3 blocks failed: retry 8 s later (%d ms)" % first_retry)

	# A stream that keeps delivering (received rising, a block outstanding now and then) never trips the 8 s rule; one that stops delivering does.
	var flowing = WatchdogScript.new()
	var flow_fired: int = 0

	for t in range(1, 250):
		if flowing.step(t * 100, true, t % 2, t) == "retry":
			flow_fired += 1

	check(flow_fired == 0, "blocks arriving all the time, pending flickering 0/1: no retry in 25 s (%d)" % flow_fired)

	var stalled = WatchdogScript.new()
	var stall_at: int = -1

	for t in range(1, 400):
		var got: int = mini(t, 30)   # blocks arrive for 3 s, then nothing, one still outstanding
		if stalled.step(t * 100, true, 1, got) == "retry" and stall_at < 0:
			stall_at = t * 100

	check(stall_at >= 10900 and stall_at <= 11200, "delivery stops at 3 s with a block outstanding: retry 8 s later (%.1f s)" % (float(stall_at) * 0.001))

	print("Test done: %d pass, %d fail" % [passes, failures])
	quit(1 if failures > 0 else 0)
