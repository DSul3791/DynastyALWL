extends RefCounted

# Join watchdog (Dave, build 787: "Loading the ground under you: 0 blocks still arriving, 83 s" for ever). A block that failed for good (refused, zeroed or
# timed out) is not asked for again by the voxel engine until the player moves, and a player waiting for ground does not move. So while the ground is not
# ready and the stream has nothing outstanding, the client starts a new stream (same cache, nothing cleared) and the engine asks for everything again.
#   var watchdog := GroundWatchdog.new()
#   match watchdog.step(now_msec, waiting_for_ground, stream.pending()):   "retry": restream; "give_up": show the failure; "": nothing
# Numbers (Tyler, 24 Oct): idle 8 s, a retry at most every 10 s, 6 tries. "Idle" is nothing outstanding for 8 s, or no block arrived for 8 s (after the
# first one: a server still reading its tiles is the existing "not sending ground" guard's business). A stream that keeps delivering but still gives
# no ground after BUSY_S (30 s) is retried too, every BUSY_RETRY_S. (Mike's run: pending flickers 0..1 while thousands of blocks arrive, so "pending is 0" alone is not idle.)

const IDLE_S := 8.0
const EVERY_S := 10.0
const MAX_TRIES := 6
const BUSY_S := 30.0
const BUSY_RETRY_S := 15.0

var tries: int = 0
var _wait_start_msec: int = -1
var _idle_since_msec: int = -1
var _last_try_msec: int = -1
var _last_received: int = -1
var _progress_msec: int = -1


# One call per frame. Returns "retry" (start a new stream), "give_up" (the sixth retry did not help) or "".
func step(now_msec: int, waiting: bool, pending: int, received: int = 0) -> String:
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
	var busy: bool = pending > 0 and float(now_msec - _wait_start_msec) * 0.001 >= BUSY_S and since_try >= BUSY_RETRY_S
	var due: bool = (idle and since_try >= EVERY_S) or busy

	if not due:
		return ""

	if tries >= MAX_TRIES:
		return "give_up"

	tries += 1
	_last_try_msec = now_msec
	_idle_since_msec = -1
	_progress_msec = now_msec
	return "retry"


# The line the join window shows after the first retry.
func note() -> String:
	return "" if tries == 0 else "Ground is slow: asking the server again (try %d of %d)" % [tries, MAX_TRIES]
