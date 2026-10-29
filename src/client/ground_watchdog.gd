extends RefCounted

# Join watchdog (Dave, build 787: "Loading the ground under you: 0 blocks still arriving, 83 s" for ever). A block that failed for good (refused, zeroed or
# timed out) is not asked for again by the voxel engine until the player moves, and a player waiting for ground does not move. So while the ground is not
# ready and the stream has nothing outstanding, the client starts a new stream (same cache, nothing cleared) and the engine asks for everything again.
#   var watchdog := GroundWatchdog.new()
#   match watchdog.step(now_msec, waiting_for_ground, stream.pending()):   "retry": restream; "give_up": show the failure; "": nothing
# Numbers (Tyler, 24 Oct): idle 8 s, a retry at most every 10 s, 6 tries. "Idle" is nothing outstanding for 8 s, or no block arrived for 8 s (after the
# first one: a server still reading its tiles is the existing "not sending ground" guard's business).
# 25 Oct (BUG-001 reopened, Mike's log, tech/ACTION_PLANS/Steve_ground_quiet.md): a stream that keeps delivering is NEVER restarted. A restart throws away work
# and the new stream is asked for nothing (the engine already holds the loaded blocks). So a retry needs either NEW block failures (refused, zeroed, timed out or
# dropped since the last retry) while the stream is idle, or a stream that has stopped dead: no block for STALL_S while ground has been wanted for STALL_WAIT_S,
# at most MAX_STALL times (so the first-start hang cannot come back, and a healthy slow join cannot be killed). `received` and `failed` are TOTALS since the
# welcome, carried across restarts by the caller.

const IDLE_S := 8.0
const EVERY_S := 10.0
const MAX_TRIES := 6
const STALL_S := 20.0
const STALL_WAIT_S := 30.0
const MAX_STALL := 2

var tries: int = 0
var stall_tries: int = 0
var _wait_start_msec: int = -1
var _idle_since_msec: int = -1
var _last_try_msec: int = -1
var _last_received: int = -1
var _progress_msec: int = -1
var _failed_at_try: int = 0


# One call per frame. Returns "retry" (start a new stream), "give_up" (the sixth retry did not help) or "".
func step(now_msec: int, waiting: bool, pending: int, received: int = 0, failed: int = 0) -> String:
	if not waiting:
		_wait_start_msec = -1
		_idle_since_msec = -1
		return ""

	if _wait_start_msec < 0:
		_wait_start_msec = now_msec
		_progress_msec = now_msec

	if received != _last_received:
		_last_received = received
		_progress_msec = now_msec

	if pending > 0:
		_idle_since_msec = -1
	elif _idle_since_msec < 0:
		_idle_since_msec = now_msec

	var since_try: float = 1.0e9 if _last_try_msec < 0 else float(now_msec - _last_try_msec) * 0.001
	var idle: bool = _idle_since_msec >= 0 and float(now_msec - _idle_since_msec) * 0.001 >= IDLE_S
	idle = idle or (received > 0 and float(now_msec - _progress_msec) * 0.001 >= IDLE_S)
	var failed_new: bool = failed > _failed_at_try
	var failure_due: bool = idle and failed_new and since_try >= EVERY_S
	var stalled: bool = float(now_msec - _progress_msec) * 0.001 >= STALL_S and float(now_msec - _wait_start_msec) * 0.001 >= STALL_WAIT_S
	var stall_due: bool = stalled and not failed_new and stall_tries < MAX_STALL and since_try >= EVERY_S

	if not failure_due and not stall_due:
		return ""

	if failure_due and tries >= MAX_TRIES:
		return "give_up"

	tries += 1

	if not failure_due:
		stall_tries += 1

	_last_try_msec = now_msec
	_idle_since_msec = -1
	_progress_msec = now_msec
	_failed_at_try = failed
	return "retry"


# The line the join window shows after the first retry.
func note() -> String:
	return "" if tries == 0 else "Ground is slow: asking the server again (try %d of %d)" % [tries, MAX_TRIES]
