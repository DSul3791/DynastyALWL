extends RefCounted

# The player's own movement, measured as it happens (coordinator 23 Nov 2026, Dave: "motion must be fluid"; the first basic before any
# looks): each frame of walking (terrain_client._move_player's walk branch) is set against what the keys asked for, and every place the
# body is held, slowed, set back or shoved is printed with what it touched, so a robot run (tools/robots.sh, every robot client) or a
# play with --motion-audit names the spots and the causes. Client only, nothing is sent.
#   MOTION stop <gait> <s> s at x,y,z: asked <m/s>, moved <m/s>; touched <what>        held near still while the keys asked to move
#   MOTION slow <gait> <s> s at x,y,z: asked <m/s>, moved <m/s> (<pct>) on flat ground; touched <what>   well under the asked pace
#   MOTION snap <m> m at x,y,z: <source>                                                 the body set somewhere else between two walk frames
#   MOTION push <m> m at x,y,z: <source>                                                 a log or an animal moved it more than a step
#   MOTION summary <gait>: asked <s> s, <pct> of the asked distance made, stops <n>, slows <n>, snaps <n>, pushes <n>; short <pct> against
#     things, <pct> on slopes, <pct> on clear flat ground (where the distance not made went)
# "no cause" in the touched list: only the floor was touched (nothing stood in the way).

const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")

const STOP_SHARE := 0.25        # moved under this share of the asked pace counts as held
const STOP_S := 0.4             # held this long is a stop
const SLOW_SHARE := 0.7         # on flat ground, under this share for SLOW_S is a slow stretch
const SLOW_S := 1.0
const FLAT_Y := 0.97            # a floor normal this upright is flat ground
const MIN_ASK_MPS := 0.3        # slower asks (a tired crawl) are not judged
const SNAP_M := 0.3             # set this far between two walk frames, outside the walk itself
const PUSH_M := 0.15            # a log or an animal moved the body this far in one frame
const SUMMARY_S := 60.0

var _last_end: Vector3 = Vector3.INF
var _held_s: float = 0.0
var _held_asked: float = 0.0
var _held_moved: float = 0.0
var _held_at: Vector3 = Vector3.ZERO
var _held_gait: String = ""
var _held_touch: String = ""
var _slow_s: float = 0.0
var _slow_asked: float = 0.0
var _slow_moved: float = 0.0
var _slow_at: Vector3 = Vector3.ZERO
var _slow_gait: String = ""
var _slow_touch: String = ""
var _gaits: Dictionary = {}     # gait -> {asked_s, asked_m, moved_m, stops, slows, snaps, pushes}
var _summary_in: float = SUMMARY_S
var lines: int = 0              # MOTION lines printed (tests)
var last_line: String = ""


# Between walk frames: a seat, a bed, a ladder or a teleport moved the body: the next walk frame starts fresh.
func reset() -> void:
	_last_end = Vector3.INF
	_end_held()
	_end_slow()


# One walk frame. `asked`: the velocity the keys and the ground asked for (m/s, before move_and_slide); `from`: the body before it;
# `slid`: after move_and_slide; `to`: after the logs and animals stopped it; `touched`: what the slide touched (normals and names);
# `floor_y`: the floor normal's y (1 = flat; 0 off the floor).
# `end`: after the stuck-rescue (rescue.gd) had its say, where the next frame should start.
func frame(delta: float, gait: String, asked: Vector3, from: Vector3, slid: Vector3, to: Vector3, end: Vector3, touched: Array, floor_y: float) -> void:
	if delta <= 0.0:
		return

	if _last_end != Vector3.INF:
		var off: float = Vector2(from.x - _last_end.x, from.z - _last_end.z).length()

		if off > SNAP_M:
			_count(gait, "snaps")
			_say("snap %.2f m at %s: set between walk frames (not by the walk: the server, a teleport or a placement)" % [off, _at(from)])

	var pushed: float = Vector2(to.x - slid.x, to.z - slid.z).length()

	if pushed > PUSH_M:
		_count(gait, "pushes")
		_say("push %.2f m at %s: a loose log or an animal's body" % [pushed, _at(to)])

	var rescued: float = (end - to).length()

	if rescued > SNAP_M:
		_count(gait, "snaps")
		_say("snap %.2f m at %s: the stuck rescue moved the body (to %s)" % [rescued, _at(to), _at(end)])

	_last_end = end
	var asked_mps: float = Vector2(asked.x, asked.z).length()
	var moved_mps: float = Vector2(slid.x - from.x, slid.z - from.z).length() / delta

	if asked_mps < MIN_ASK_MPS:
		_end_held()
		_end_slow()
		return

	var g: Dictionary = _gait(gait)
	g["asked_s"] = float(g["asked_s"]) + delta
	g["asked_m"] = float(g["asked_m"]) + asked_mps * delta
	# Not capped per frame: the walk carries a frame's missed headway into the next (terrain_client._carry_slide), so one frame short and the
	# next long is full pace. Signed, so the catch-up pays back where the shortfall was put; the summary caps the made share at 100%.
	g["moved_m"] = float(g["moved_m"]) + moved_mps * delta
	var short_m: float = (asked_mps - moved_mps) * delta
	var against: bool = touched.any(func(t): return (t[1] as Vector3).y < 0.7)
	var where: String = "short_against" if against else ("short_flat" if floor_y >= FLAT_Y else "short_slope")
	g[where] = float(g[where]) + short_m
	var what: String = _what(touched)

	if moved_mps < asked_mps * STOP_SHARE:
		if _held_s <= 0.0:
			_held_at = from
			_held_gait = gait

		_held_s += delta
		_held_asked += asked_mps * delta
		_held_moved += moved_mps * delta
		_held_touch = what
	else:
		_end_held()

	if floor_y >= FLAT_Y and moved_mps < asked_mps * SLOW_SHARE and moved_mps >= asked_mps * STOP_SHARE:
		if _slow_s <= 0.0:
			_slow_at = from
			_slow_gait = gait

		_slow_s += delta
		_slow_asked += asked_mps * delta
		_slow_moved += moved_mps * delta
		_slow_touch = what
	elif moved_mps >= asked_mps * SLOW_SHARE:
		_end_slow()

	_summary_in -= delta

	if _summary_in <= 0.0:
		_summary_in = SUMMARY_S
		summary()


func summary() -> void:
	for gait in _gaits:
		var g: Dictionary = _gaits[gait]
		var asked_m: float = maxf(float(g["asked_m"]), 0.001)
		_say("summary %s: asked %.1f s, %.0f%% of the asked distance made, stops %d, slows %d, snaps %d, pushes %d; short %.0f%% against things, %.0f%% on slopes, %.0f%% on clear flat ground" % [gait,
			float(g["asked_s"]), minf(100.0, 100.0 * float(g["moved_m"]) / asked_m), int(g["stops"]), int(g["slows"]), int(g["snaps"]), int(g["pushes"]),
			maxf(0.0, 100.0 * float(g["short_against"]) / asked_m), maxf(0.0, 100.0 * float(g["short_slope"]) / asked_m), maxf(0.0, 100.0 * float(g["short_flat"]) / asked_m)])


func gait_row(gait: String) -> Dictionary:
	return _gait(gait)


func _end_held() -> void:
	if _held_s >= STOP_S:
		_count(_held_gait, "stops")
		_say("stop %s %.1f s at %s: asked %.2f m/s, moved %.2f m/s; touched %s" % [_held_gait, _held_s, _at(_held_at), _held_asked / _held_s, _held_moved / _held_s, _held_touch])

	_held_s = 0.0
	_held_asked = 0.0
	_held_moved = 0.0


func _end_slow() -> void:
	if _slow_s >= SLOW_S:
		_count(_slow_gait, "slows")
		_say("slow %s %.1f s at %s: asked %.2f m/s, moved %.2f m/s (%.0f%%) on flat ground; touched %s" % [_slow_gait, _slow_s, _at(_slow_at), _slow_asked / _slow_s,
			_slow_moved / _slow_s, 100.0 * _slow_moved / maxf(_slow_asked, 0.001), _slow_touch])

	_slow_s = 0.0
	_slow_asked = 0.0
	_slow_moved = 0.0


func _gait(gait: String) -> Dictionary:
	if not _gaits.has(gait):
		_gaits[gait] = {"asked_s": 0.0, "asked_m": 0.0, "moved_m": 0.0, "stops": 0, "slows": 0, "snaps": 0, "pushes": 0, "short_against": 0.0, "short_slope": 0.0, "short_flat": 0.0}

	return _gaits[gait]


func _count(gait: String, key: String) -> void:
	var g: Dictionary = _gait(gait)
	g[key] = int(g[key]) + 1


# What the slide touched: each collider's name and normal; only floors (normal up) is "no cause".
static func _what(touched: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var only_floor: bool = true

	for t in touched:
		var n: Vector3 = t[1]

		if n.y < 0.7:
			only_floor = false

		var name: String = str(t[0])

		if not parts.has("%s (normal %.2f,%.2f,%.2f)" % [name, n.x, n.y, n.z]):
			parts.append("%s (normal %.2f,%.2f,%.2f)" % [name, n.x, n.y, n.z])

	if parts.is_empty():
		return "nothing (no cause)"

	return ("no cause: only the floor, " if only_floor else "") + "; ".join(parts.slice(0, 4))


static func _at(p: Vector3) -> String:
	return "%.1f,%.1f,%.1f" % [p.x, p.y, p.z]


func _say(text: String) -> void:
	lines += 1
	last_line = text
	FreezeWatchScript.printer.line("MOTION " + text)
