extends Node3D

# The other players (protocol 151, Dave 22 Nov 2026, the friends' play test: players could not see each other). The server sends each
# player's look once (player_look: name, body model, body code, worn pieces) and, about eight times a second, the players within 150 m
# (players: position, facing, state, the item in the hand, the server ms of the position; src/stream/server_players.gd). Each is drawn as
# its own character, the body the creator made (dynasty_body.gd with its sliders, skin and hair, dressed like the player's own body by
# avatar_driver.gd dress_worn), a little in the past between its sent points (motion_buffer.gd, as the animals), with the player's own
# clip rules (avatar_driver.gd clip_for, hook_clip: idle, walk, jog, run, crouch, sit, lie, swim, a log on the shoulder), its held item
# in the right hand and its name above. A player who leaves or goes out of range is removed.
# Nothing collides with these bodies and nothing can hit them (no collider): player-versus-player rules are Dave's.
# Animation by distance, as npc_view.gd: every frame to 15 m, every 2nd to 40 m, every 4th to 70 m, a held pose beyond.
# Footsteps (Dave 23 Nov 2026, sound hard to pinpoint; other players made no step sound at all): a step every stride of drawn travel on
# foot, the player's own stride lengths, sent to the sounds as `stepped` (sound_stage.step_at plays it where the foot lands).

signal stepped(at: Vector3, gait: int, crouched: bool)
signal stroked(at: Vector3)               # another player's swimming stroke, where they swim (swim_sounds.gd stroke_at)
signal landed(at: Vector3, drop_m: float)  # another player came down from a fall of drop_m (2.5 m or more): the thud where their feet land (landing_sounds.gd land_at)
signal drew(at: Vector3)                  # another player drew their bow (the more byte's bow-drawn flag came on): the creak at their shoulder

const MotionBuffer := preload("res://src/client/motion_buffer.gd")
const DynastyBodyScript := preload("res://src/client/character/dynasty_body.gd")
const GeneratedBodyScript := preload("res://src/client/character/generated_body.gd")
const BodyGenerator := preload("res://src/client/character/body_generator.gd")
const BodyModels := preload("res://src/client/character/body_models.gd")
const HairModels := preload("res://src/client/character/hair_models.gd")
const AvatarDriver := preload("res://src/client/character/avatar_driver.gd")
const StanceScript := preload("res://src/client/stance.gd")
const WornSync := preload("res://src/client/worn_sync.gd")
const HeldItem := preload("res://src/client/held_item.gd")

const MAX_DRAWN := 31
const CARRY_S := 0.8                   # how long a body walks on past its newest point (MotionBuffer.at: at most two report legs)
const SWING_LEAD_S := 0.2             # how much of the swing before its impact a remote blow still shows (the downswing)
# How a correction is eased in for another player (MotionBuffer.smooth): the animals' 1.3 times their speed (#1670) left another player
# drawn 2 m behind while it ran and up to 6 m behind for 10 s after a 1.4 s freeze on this client (robots, 23 Nov 2026, dev 0b0c3247):
# a player speeds up and stops faster than its measured speed says, so a step of 1.5 frames is shown and the rest catches up at 3 m/s at least.
const SMOOTH_ROOM_X := 1.5
const SMOOTH_CATCH_X := 0.5
const SMOOTH_CATCH_MIN_MPS := 3.0
const REPORT_S := 0.2                  # a client reports its position every 0.2 s (terrain_client.gd report_position)
const MAKE_PER_ROWS := 2               # bodies made per rows message: a crowd coming into range is built over a few sends, not in one frame
const FULL_M := 15.0
const HALF_M := 40.0
const QUARTER_M := 70.0
const SWIM := 4
const CARRY := 8
const ASLEEP := 16                     # server_players.gd: asleep (the lying clip, as the player's own body)
const MORE_LIT := 1                   # server_players.gd more byte (159): a burning torch or lantern...
const MORE_BOW_RAISED := 2             # ...the hand flags (held_item.gd HAND_* << 1)...
const MORE_BOW_DRAWN := 4
const MORE_SHIELD_UP := 8
const MORE_LADDER := 16
const MORE_MEAL_SHIFT := 5             # ...and bits 5..7 eats and drinks (a change plays the drink clip)
const LIT_MOST := 4                    # at most this many other players' torches and lanterns cast light, the nearest, one light each (each light costs every pixel it reaches)
const LIT_MOST_LOW := 1                # at Low quality (terrain_client.gd sets lit_most): unmeasured, as the player's own held light budget
const TORCH_ENERGY_LANTERN := 1.6      # held_item.gd _show_off_model: a lantern's steady light
const SWING_SHIFT := 5                 # bits 5..7: the player's swing count; a change plays the tool's work clip once
const CARRY_LOG_LENGTH_M := 3.0          # terrain_client.gd CARRY_LOG_LENGTH_M
const CARRY_LOG_RADIUS_M := 0.14
const LOG_COLOR := Color(0.32, 0.23, 0.15)
const NAME_HEIGHT_M := 2.05
const NO_NAME := "Traveller"
const STEP_M := [1.2, 1.7]               # terrain_client.gd STEP_M: metres per step walking, running (the clips' own steps, R-MOVE-RUN-FEET)
const RUN_FROM_MPS: float = AvatarDriver.RUN_FROM   # drawn pace from which the run clip plays (5 m/s), so its footsteps take the run step: they follow the feet drawn
const STEP_FROM_MPS := 1.0               # slower than this makes no steps (terrain_client.gd _update_bob)
const FALL_FROM_MPS := 3.0              # sinking this fast, and steeper than the flat pace (no walk down a slope does both), is a fall
const GRAVITY_MPS2 := 9.8
const SINK_MPS := 0.5                  # sinking slower than this is standing or walking level: a fall ends
const SNAP_MPS := 40.0                 # a drawn leg faster than this is no fall (a fall of 80 m lands at 40 m/s): a teleport or an unstuck
const LAND_FROM_M := 2.5               # landing_sounds.gd THUD_FROM_M: a smaller drop lands as a step
const STEP_HEAR_M := 45.0                # sound_stage.gd OTHER_STEP_REACH_M: farther steps are not counted
const DRAW_UP_M := 0.5                   # the bow's string at the shoulder, above the body's middle
const STROKE_FROM_MPS := 0.5             # swim_sounds.gd STROKE_MIN_MPS: slower than this makes no strokes
const FEET_M := 0.9                      # the sent position is the standing body's middle

const STALL_S := 0.25                    # animal_view.gd STALL_S: a frame this long is this computer's own stall (MotionBuffer.stall_until)

var table                            # the client's item table (id_of, entry), for worn and held items
var _frame_s: float = -1.0           # when _process last drew the bodies (s, the ticks clock)
var frame_dts: Vector2 = Vector2.ZERO   # the last _process: (the engine's delta, the ticks clock's step it drew by), for test_remote_players
var _settle_until: float = -1.0      # after this computer's own stall: until then bodies are drawn where their points are (as animal_view, #1765)
var _looks: Dictionary = {}          # peer -> {"name", "body", "code", "worn"}
var _bodies: Dictionary = {}         # peer -> {"node", "rig", "samples", "row_ms", "state", "held", "path_p", "sm_err", ...}
var _clock: Dictionary = MotionBuffer.clock_new()   # the rows' clock (protocol 154, the animals' jitter buffer): offset, interval, holes, lateness


func on_look(peer: int, char_name: String, body: String, code: String, worn: PackedInt32Array) -> void:
	var before: Dictionary = _looks.get(peer, {})
	_looks[peer] = {"name": char_name, "body": body, "code": code, "worn": worn}
	var genome: Dictionary = BodyGenerator.decode(code) if code != "" else {}
	DynastyBodyScript.warm([body if BodyModels.has(body) else BodyModels.DEFAULT], [str(genome.get("hair_model", HairModels.NONE))])   # on loader threads, before the body is made

	if not _bodies.has(peer):
		return

	if str(before.get("body", "")) != body or str(before.get("code", "")) != code or str(before.get("name", "")) != char_name:
		_drop(peer)   # a new look: made again at the next rows
	else:
		_dress(_bodies[peer])


# How long a body walks on past its newest point (MotionBuffer.at): CARRY_S, or none while it is turning back and forth (any two of its last
# REVERSE_LEGS legs turned back on each other, by more than REVERSE_DEG): a dodging player's next step cannot be guessed, and walking on along
# the last leg drew it up to 2.2 m the wrong way (robots' wiggle plan, 23 Nov 2026: a run back and forth every 0.5 s on a 120 +- 30 ms link
# with 3% loss). It then stands at its newest point until the next row; one walking or running on keeps the carry through lost batches.
const REVERSE_DEG := 100.0
const REVERSE_LEGS := 4


static func carry_for(samples: Array) -> float:
	var n: int = samples.size()
	var after: Vector3 = Vector3.ZERO

	for k in range(n - 1, maxi(n - 1 - REVERSE_LEGS, 0), -1):
		var leg: Vector3 = (samples[k][0] as Vector3) - (samples[k - 1][0] as Vector3)
		leg.y = 0.0

		if leg.length() < 0.05:
			continue

		if after != Vector3.ZERO and leg.normalized().dot(after) < cos(deg_to_rad(REVERSE_DEG)):
			return 0.0

		after = leg.normalized()

	return CARRY_S


func on_rows(ids: PackedInt32Array, positions: PackedVector3Array, yaws: PackedFloat32Array, states: PackedByteArray, held: PackedInt32Array, times: PackedInt32Array, left: PackedInt32Array = PackedInt32Array(), more: PackedByteArray = PackedByteArray(), cast: PackedInt32Array = PackedInt32Array()) -> void:
	var n: int = mini(ids.size(), mini(positions.size(), mini(yaws.size(), mini(states.size(), mini(held.size(), times.size())))))
	var now_s: float = float(Time.get_ticks_usec()) / 1.0e6
	var newest: int = -1

	for i in range(n):
		newest = maxi(newest, times[i])

	if newest >= 0:
		_settle_until = MotionBuffer.stall_until(now_s, _frame_s, _settle_until, get_process_delta_time(), STALL_S)

		if newest > int(_clock["server_ms"]) or newest < int(_clock["server_ms"]) - 2000:
			MotionBuffer.clock_note(_clock, now_s, newest, now_s <= _settle_until)   # rows read late after this computer's own stall leave the lateness as it was   # the batch's newest position report (players report every 0.2 s, standing too);
			# a batch with no newer report (a swing, a player coming in range, the 1 s resend) would read as late and deepen the delay

	var seen: Dictionary = {}
	var made: int = 0

	for i in range(n):
		var peer: int = ids[i]
		seen[peer] = true

		if not _bodies.has(peer):
			if made >= MAKE_PER_ROWS or _bodies.size() >= MAX_DRAWN or not _looks.has(peer) or not _can_make(_looks[peer]):
				continue

			_bodies[peer] = _make(peer, positions[i], yaws[i])
			made += 1

		var b: Dictionary = _bodies[peer]
		var swings: int = int(states[i]) >> SWING_SHIFT

		if b.has("swings") and int(b["swings"]) != swings:
			b["swing_due"] = true   # a blow since the last rows (the first rows only note the count)

		b["swings"] = swings
		b["state"] = int(states[i])
		b["left"] = int(left[i]) if i < left.size() else 0
		var more_now: int = int(more[i]) if i < more.size() else 0

		if b.has("more") and (more_now & MORE_BOW_DRAWN) != 0 and (int(b["more"]) & MORE_BOW_DRAWN) == 0:
			drew.emit((b["node"] as Node3D).global_position + Vector3(0.0, DRAW_UP_M, 0.0))   # the string pulled back (the first rows only note it)

		b["more"] = more_now
		b["held"] = int(held[i])
		b["float_at"] = cast_point(positions[i], int(cast[i]) if i < cast.size() else 0)   # the rod's float, fixed in the world (162)
		MotionBuffer.push_row(b, positions[i], yaws[i], times[i], float(_clock["off"]), INF)   # no pause guessing: a standing player's reports keep coming

	for peer in _bodies.keys():
		if not seen.has(peer):
			_drop(peer)


# Where the drawn players walked since the last call (tester report #7, 23 Nov 2026: "Grass doesn't mat down" under other players): points
# along each one's way from where it was last asked, TRAIL_STEP_M apart (at most TRAIL_MOST a player, so a runner leaves an unbroken
# trail at the client's 0.3 s pass), at the feet, for those within max_m of `from`. Nothing for a swimmer. Look only, client only: it reads
# the positions the players rows already bring, no network or server work.
const TRAIL_STEP_M := 0.8
const TRAIL_MOST := 4
const TRAIL_RADIUS_M := 0.8         # grass_trample.gd RADIUS_M, the player's own footprint
const TRAIL_JUMP_M := 8.0           # farther in one pass (a snap, a respawn): only the new spot, no line across


func trail_points(from: Vector3, max_m: float) -> Array:
	var out: Array = []

	for peer in _bodies:
		var b: Dictionary = _bodies[peer]
		var feet: Vector3 = (b["node"] as Node3D).position + Vector3(0.0, (b["rig"] as Node3D).position.y, 0.0)
		if not b.has("trail_at"):
			b["trail_at"] = feet   # the first pass only marks where it starts
			continue

		var last: Vector3 = b["trail_at"]
		var d: float = Vector2(feet.x - last.x, feet.z - last.z).length()

		if d < 0.5:
			continue

		b["trail_at"] = feet

		if (int(b["state"]) & SWIM) != 0 or from.distance_to(feet) > max_m:
			continue

		if d > TRAIL_JUMP_M:
			out.append(feet)
			continue

		var n: int = mini(ceili(d / TRAIL_STEP_M), TRAIL_MOST)

		for i in range(1, n + 1):
			out.append(last.lerp(feet, float(i) / float(n)))

	return out


func drawn_count() -> int:
	return _bodies.size()


# [{"peer", "name", "pos"}] of the drawn players, for checks and the debug line.
func drawn() -> Array:
	var out: Array = []

	for peer in _bodies:
		out.append({"peer": peer, "name": _name_of(peer), "pos": (_bodies[peer]["node"] as Node3D).position})

	return out


# How far in the past the players are drawn: the rows' jitter buffer, never under one body's own report gap plus lateness (with several
# players near, the batches' newest time moves on more often than any one of them reports), never over MAX_DELAY_S (a hitch on this
# computer makes `late` jump; deeper than the kept points, bodies would step from point to point).
static func draw_delay(clock: Dictionary) -> float:
	return minf(maxf(MotionBuffer.clock_delay(clock), REPORT_S + float(clock["late"]) + 0.05), MotionBuffer.MAX_DELAY_S)


func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var frame: int = Engine.get_process_frames()
	var now_s: float = float(Time.get_ticks_usec()) / 1.0e6
	_settle_until = MotionBuffer.stall_until(now_s, _frame_s, _settle_until, delta, STALL_S)   # this computer's own stall (#1765, as animal_view)
	var settle: bool = now_s <= _settle_until
	# The drawn path is sampled on the ticks clock (drawn_at), so its steps, its speed, the easing and the footsteps use the same clock's step, not
	# the engine's delta: on uneven frames (Lane A on Dave's PC, a slow machine) or delta smoothing the two differ, and a body eased by a delta
	# longer than its real frame jumped (0.2 to 0.47 m in one 60 fps frame) and rushed (up to 9.9 m/s for a 3 m/s walk); with --fixed-fps, a
	# delta longer than the real frame read a walk as standing and played idle (test_remote_players, 26 Nov 2026).
	var clock_step: float = clampf(now_s - _frame_s, 0.0, STALL_S) if _frame_s >= 0.0 else delta
	frame_dts = Vector2(delta, clock_step)
	_frame_s = now_s
	var drawn_at: float = now_s - draw_delay(_clock)
	_light_pass()

	for peer in _bodies:
		var b: Dictionary = _bodies[peer]
		var node: Node3D = b["node"]
		var rig: Node3D = b["rig"]
		var before: Vector3 = b.get("path_p", node.position)

		if settle:
			MotionBuffer.settle(b)   # after this computer's own stall the others are drawn where they are, not eased in from metres behind

		if not (b["samples"] as Array).is_empty():
			var at: Array = MotionBuffer.at(b["samples"], drawn_at, carry_for(b["samples"]))   # through a hole of lost batches a player walks on (two legs at most), then the easing takes the rest
			b["path_p"] = at[0]
			# A late batch or a lost one never jumps the body: the step beyond a normal one is eased in (MotionBuffer.smooth, as the animals).
			node.position = MotionBuffer.smooth(b, at[0], MotionBuffer.speed_at(b["samples"], drawn_at), clock_step, SMOOTH_ROOM_X, SMOOTH_CATCH_X, SMOOTH_CATCH_MIN_MPS)
			node.rotation.y = lerp_angle(node.rotation.y, float(at[1]), clampf(delta * 12.0, 0.0, 1.0))

		# The legs follow the path's own speed, not the easing (a correction slid in is not a step).
		var path_v: Vector3 = ((b.get("path_p", node.position) as Vector3) - before) / maxf(clock_step, 0.001)   # the drawn path's own speed, uncapped
		var path_dt: float = drawn_at - float(b.get("fall_t", drawn_at - clock_step))   # how far the drawn moment moved on (a late batch steps it back)
		b["fall_t"] = drawn_at
		var moved: Vector3 = path_v.limit_length(MotionBuffer.CARRY_MPS)   # a carried-on point taken back is not a sprint
		var velocity: Vector3 = (b.get("velocity", Vector3.ZERO) as Vector3).lerp(moved, clampf(clock_step * 8.0, 0.0, 1.0))
		b["velocity"] = velocity
		var distance: float = eye.distance_to(node.global_position)
		_count_steps(b, velocity, clock_step, distance)
		var samples: Array = b["samples"]
		var carried: bool = fall_carried(samples, drawn_at, path_dt, clock_step) or settle
		_count_fall(b, path_v * clock_step / maxf(path_dt, 0.001), carried, clock_step, distance)   # the fall by the drawn moment's own steps
		_far_check(b, distance, delta)
		_show_held(b)
		_show_left(b, distance)
		_show_line(b, distance)
		_pose_bow(b, distance)
		var player: AnimationPlayer = rig.get("animation_player") as AnimationPlayer

		if player == null:
			continue

		var every: int = 1 if distance <= FULL_M else (2 if distance <= HALF_M else (4 if distance <= QUARTER_M else 0))
		b["owed"] = float(b.get("owed", 0.0)) + delta

		if every == 0:
			b["owed"] = 0.0
			b["swing_due"] = false   # a blow far off is not played when the body comes near later
			var pose: int = int(b["state"]) & (3 | ASLEEP | SWIM)

			if int(b.get("far_pose", -1)) != pose:   # far off the body is not animated, but it still lies, sits or swims when the player does (robots 23 Nov 2026: a far player lying down was drawn standing)
				var far_stance: int = pose & 3
				var far_clip: String = "swim_idle" if (pose & SWIM) != 0 else AvatarDriver.choose_clip(far_stance, 0.0, "", (int(b["state"]) & CARRY) != 0 and far_stance == StanceScript.STAND)

				if rig.has_method("play") and player.has_animation(far_clip):
					b["far_pose"] = pose   # kept only once its clip is on: a body whose clips are still being made (dynasty_body.gd _clips_later) tries again next frame
					rig.play(far_clip, 1.0, 0.0)   # no one-shot (a wake-up would hold its first frame): the resting pose
					player.advance(0.0)

				if str(b.get("held_kind", "")) == "spear":
					aim_spear(b["held_node"] as Node3D, rig)   # the hand is in the resting pose now: a spear aimed at the last stride (or at the bind pose of a body just drawn) would stick out of the body (bug 169)

			continue

		b.erase("far_pose")

		if (frame + (peer & 3)) % every != 0:
			continue

		var step: float = float(b["owed"])
		b["owed"] = 0.0
		_animate(b, velocity, step)
		player.advance(step)

		if str(b.get("held_kind", "")) == "spear":
			aim_spear(b["held_node"] as Node3D, b["rig"])   # after the pose: the spear keeps the facing, not the hand bone's angle
		elif b.get("held_node", null) != null:
			follow_hand(b["held_node"] as Node3D)



# A step each stride of drawn ground travel, for a player on foot (not sitting or lying) within hearing; a swimmer's strokes instead (stroked).
func _count_steps(b: Dictionary, velocity: Vector3, delta: float, distance: float) -> void:
	var state: int = int(b["state"])
	var stance: int = state & 3
	var pace: float = Vector2(velocity.x, velocity.z).length()

	if (state & SWIM) != 0 and pace >= STROKE_FROM_MPS and distance <= STEP_HEAR_M:
		var left: float = float(b.get("stroke", 0.2)) - delta   # one pull every 1.4 s slow to 0.6 s fast, as the own strokes (swim_sounds.gd)

		if left <= 0.0:
			left = lerpf(1.4, 0.6, clampf(pace / 4.0, 0.0, 1.0))
			stroked.emit((b["node"] as Node3D).global_position)

		b["stroke"] = left
		b["stride"] = 0.0
		return

	b["stroke"] = 0.2

	if (state & SWIM) != 0 or stance >= StanceScript.SIT or pace < STEP_FROM_MPS or distance > STEP_HEAR_M:
		b["stride"] = 0.0
		return

	var running: bool = pace >= RUN_FROM_MPS
	var length: float = float(STEP_M[1 if running else 0])
	var travelled: float = float(b.get("stride", 0.0)) + pace * delta

	if travelled >= length:
		travelled = fmod(travelled, length)
		stepped.emit((b["node"] as Node3D).global_position - Vector3(0.0, FEET_M, 0.0), 2 if running else 0, stance == StanceScript.CROUCH)

	b["stride"] = travelled

# A frame the fall counter skips: past the newest sent point (a lost report carries the body on: a guess, later taken back), too few
# points, or the drawn moment not moving on by about the frame (the lateness rose with a late batch and stepped it back or held it).
static func fall_carried(samples: Array, drawn_at: float, path_dt: float, delta: float) -> bool:
	if samples.size() < 2 or drawn_at > float((samples[samples.size() - 1] as Array)[2]):
		return true

	return path_dt <= 0.0 or absf(path_dt - delta) > 0.5 * delta


# A fall, from the drawn path between sent points (`path_v`, its own speed this frame): every frame the body sinks faster than SINK_MPS
# the drop adds up; it is a fall once the sinking reached FALL_FROM_MPS and was steeper than 45 degrees (no walk down a slope does both),
# so the first slow metre of a fall and a running leap count from the edge. When the sinking stops a fall of LAND_FROM_M or more is a
# landing, heard at the feet within hearing. Not counted: frames drawn past the newest sent point (a lost report carries the body on,
# then it is taken back) or after this computer's stall (`carried`: held, neither added nor ended); a leg faster than any fall (SNAP_MPS:
# a teleport, an unstuck); going into water (a dive is a splash, not a thud) or swimming.
func _count_fall(b: Dictionary, path_v: Vector3, carried: bool, delta: float, distance: float) -> void:
	if carried:
		return

	var sink: float = -path_v.y
	var flat: float = Vector2(path_v.x, path_v.z).length()

	if (int(b["state"]) & SWIM) != 0 or path_v.length() > SNAP_MPS:
		b["drop"] = 0.0
		b["falling"] = false
		return

	if sink > SINK_MPS:
		var drop_now: float = float(b.get("drop", 0.0)) + sink * delta

		if sink >= FALL_FROM_MPS and sink > flat:
			b["falling"] = true
		elif not bool(b.get("falling", false)):
			# Not yet a fall: no more than a body falling free drops before it sinks this steeply (a leap off at a run counts from the
			# edge; a long walk down a slope before a ledge does not add up).
			# shortcut: a runner braking hard on ground steeper than 45 degrees could start a fall with up to this capped drop (rare: such
			# ground is not walkable); a landing then reads a little high.
			var steep_at: float = maxf(FALL_FROM_MPS, flat)
			drop_now = minf(drop_now, steep_at * steep_at / (2.0 * GRAVITY_MPS2))

		b["drop"] = drop_now
		return

	var drop: float = float(b.get("drop", 0.0))
	var fell: bool = bool(b.get("falling", false))
	b["drop"] = 0.0
	b["falling"] = false

	if fell and drop >= LAND_FROM_M and distance <= STEP_HEAR_M:
		landed.emit((b["node"] as Node3D).global_position - Vector3(0.0, FEET_M, 0.0), drop)


# The clip, its speed and the shoulder log, by the player's own rules (avatar_driver.gd), from the drawn speed and the sent state.
func _animate(b: Dictionary, velocity: Vector3, step: float) -> void:
	var rig: Node3D = b["rig"]
	var node: Node3D = b["node"]
	var state: int = int(b["state"])
	var stance: int = state & 3
	var swimming: bool = (state & SWIM) != 0
	var carrying: bool = (state & CARRY) != 0 and stance == StanceScript.STAND
	var flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var pace: float = flat.length()
	rig.set_meta("torch_in_hand", str(b.get("held_kind", "")) == "torch")
	rig.set_meta("torch_left", str(b.get("left_kind", "")) == "torch")
	rig.set_meta("bow_pose", arm_pose(b))   # the bow raised or drawn (162): both arms in the aim (dynasty_body.gd _bow_aim)   # the arm carries it up in front (dynasty_body.gd _torch_carry), as held_item.gd torch_in_left
	var clip: String = AvatarDriver.clip_for(rig, stance, flat, node.global_transform.basis, true, pace, rig.current(), carrying, step)
	var hook: String = AvatarDriver.hook_clip(rig, {"swimming": swimming, "asleep": (state & ASLEEP) != 0, "stance": stance, "drink_stamp": 1 + (int(b.get("more", 0)) >> MORE_MEAL_SHIFT)}, pace, step)

	if hook != "":
		clip = hook

	var player: AnimationPlayer = rig.get("animation_player") as AnimationPlayer

	if bool(b.get("swing_due", false)):
		b["swing_due"] = false
		var work: String = work_clip(int(b.get("held", 0)), table)

		if work != "" and not swimming and not carrying and (state & ASLEEP) == 0 and stance == StanceScript.STAND and player.has_animation(work):
			player.play(work, 0.05)   # the blow restarts it, as the player's own body (terrain_client.gd held.swing_serial)
			# The server hears of a blow at its impact: started SWING_LEAD_S before the impact frame, the drawn blow lands close to now.
			var share: float = HeldItem.PICK_HIT_AT if work == "pick_overhead" else (HeldItem.HIT_AT if work == "chop" else (CAST_RELEASE_AT if work == "throw" else 0.0))
			player.seek(maxf(player.get_animation(work).length * share - SWING_LEAD_S, 0.0), true)
			player.speed_scale = 1.0
			return

	if rig.is_one_shot_playing():
		return   # a swing plays out at its own speed

	if rig.has_method("set_shoulder_log") and bool(b.get("log_shown", false)) != carrying:
		b["log_shown"] = carrying
		rig.set_shoulder_log(CARRY_LOG_LENGTH_M if carrying else 0.0, CARRY_LOG_RADIUS_M, LOG_COLOR)

	if rig.current() != clip:
		rig.play(clip, 1.0, 0.25)

	player.speed_scale = AvatarDriver.speed_scale(clip, pace) * AvatarDriver.backward_sign(rig, clip)


# Once a second: dress for the distance (far bodies skip the detail parts, worn_sync.gd hysteresis).
func _far_check(b: Dictionary, distance: float, delta: float) -> void:
	b["far_t"] = float(b.get("far_t", randf())) - delta

	if float(b["far_t"]) > 0.0:
		return

	b["far_t"] = 1.0
	var far: bool = WornSync.far_after(distance, bool(b.get("far", false)))

	if far == bool(b.get("far", false)):
		return

	b["far"] = far
	var rig: Node3D = b["rig"]

	if rig.has_method("set_far"):
		rig.set_far(far)

	if table != null:
		WornSync.apply(rig, WornSync.ids_of(_looks.get(int(b["peer"]), {}).get("worn", PackedInt32Array()), table), far)


# The item in the hand: its look (held_item.gd look_tool_node), held as the player's own third-person body holds it (held_item.gd
# _mount_model_third): a spear through the fist pointing ahead along the facing, placed every frame (aim_spear; Dave 23 Nov 2026 on 9257:
# another player's spear "floating in the air almost sticking out of his chest", it was laid along the fingers like a knife), a bow in the
# left hand, every other tool by third_hold with its own kind, with the closed fist round the grip. Nothing for an item without a hand look.
func _show_held(b: Dictionary) -> void:
	var number: int = int(b.get("held", 0))

	if number == int(b.get("shown_held", 0)):
		return

	b["shown_held"] = number
	var old: Node3D = b.get("held_node", null) as Node3D

	if old != null and is_instance_valid(old):
		old.queue_free()

	b["held_node"] = null
	b["held_kind"] = ""
	var rig: Node3D = b["rig"]
	var made: Array = hold_in(rig, number, table)

	if not made.is_empty():
		b["held_node"] = made[0]
		b["held_kind"] = made[1]
		b["tip_local"] = tip_of(made[0])   # where a rod's line leaves it
		b.erase("bow_rest")


# The rod's line and float (162, 23 Nov 2026: an angler looked idle to the others): a thin line from the rod's tip sagging to a small float
# on the water where the server says the cast landed, while the line is in (waiting or biting). Within LINE_M only; look only.
const LINE_M := 40.0
const LINE_POINTS := 10
const LINE_SAG := 0.12              # metres of sag per metre of line
const FLOAT_R := 0.035
const CAST_ON := 1 << 24            # server_players.gd cast_code
const CAST_RELEASE_AT := 0.8           # the cast (throw clip, Charged_Spell_Cast): the forward flick from the hands high overhead; started SWING_LEAD_S before it, past the clip's early bow
const CAST_STEP_M := 0.12


# The float's world spot from a row's `cast` int (server_players.gd cast_code) beside the row's position; INF for none.
static func cast_point(body: Vector3, code: int) -> Vector3:
	if (code & CAST_ON) == 0 or not body.is_finite():
		return Vector3.INF

	var x: int = (code >> 16) & 255
	var y: int = (code >> 8) & 255
	var z: int = code & 255
	return body + Vector3(x - 256 if x > 127 else x, y - 256 if y > 127 else y, z - 256 if z > 127 else z) * CAST_STEP_M


func _show_line(b: Dictionary, distance: float) -> void:
	var float_at: Vector3 = b.get("float_at", Vector3.INF)
	var held_node: Node3D = b.get("held_node", null) as Node3D
	var line: MeshInstance3D = b.get("line", null) as MeshInstance3D
	var rod: bool = table != null and str(table.entry(table.id_of(int(b.get("held", 0)))).get("tool_class", "")) == "rod"   # the line is the rod's (put away, no line)
	var on: bool = rod and float_at.is_finite() and distance <= LINE_M and held_node != null and is_instance_valid(held_node) and held_node.is_inside_tree()

	if not on:
		if line != null and is_instance_valid(line):
			line.visible = false

		return

	if line == null or not is_instance_valid(line):
		line = _make_line()
		(b["node"] as Node3D).add_child(line)
		b["line"] = line

	line.visible = true
	var tip: Vector3 = held_node.global_transform * (b.get("tip_local", Vector3(0.0, 1.5, 0.0)) as Vector3)
	var mesh: ImmediateMesh = line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)

	for i in range(LINE_POINTS + 1):
		var t: float = float(i) / float(LINE_POINTS)
		mesh.surface_add_vertex(line_point(tip, float_at, t))

	mesh.surface_end()
	(line.get_node("Float") as Node3D).global_position = float_at


# A point `t` (0 the tip, 1 the float) along a line that sags below the straight way between them.
static func line_point(tip: Vector3, float_at: Vector3, t: float) -> Vector3:
	return tip.lerp(float_at, t) - Vector3(0.0, LINE_SAG * tip.distance_to(float_at) * 4.0 * t * (1.0 - t), 0.0)


func _make_line() -> MeshInstance3D:
	var line: MeshInstance3D = MeshInstance3D.new()
	line.name = "RodLine"
	line.top_level = true   # its vertices are world points
	line.mesh = ImmediateMesh.new()
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var thread: StandardMaterial3D = StandardMaterial3D.new()
	thread.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	thread.albedo_color = Color(0.85, 0.85, 0.8)
	line.material_override = thread
	var bob: MeshInstance3D = MeshInstance3D.new()
	bob.name = "Float"
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = FLOAT_R
	ball.height = FLOAT_R * 2.0
	ball.radial_segments = 8
	ball.rings = 4
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.albedo_color = Color(0.8, 0.15, 0.1)
	ball.material = paint
	bob.mesh = ball
	bob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.add_child(bob)
	return line


# The far end of a held model in its own space (the tip of a rod): the corner of its meshes' box highest along its own +y, butt to tip.
static func tip_of(model: Node3D) -> Vector3:
	var best: Vector3 = Vector3(0.0, 1.5, 0.0)
	var best_d: float = -INF

	for child in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child as MeshInstance3D

		if mi.mesh == null:
			continue

		var to_model: Transform3D = model.global_transform.affine_inverse() * mi.global_transform if model.is_inside_tree() else mi.transform
		var box: AABB = mi.mesh.get_aabb()

		for k in range(8):
			var p: Vector3 = to_model * box.get_endpoint(k)

			if p.y > best_d:   # held_item.gd HELD_BASIS "rod": butt to tip along +y (the cane is held at its middle, so the farthest corner was as often the butt)
				best_d = p.y
				best = p

	return best


# The arms' held pose for the gait (avatar_driver.gd clip_for): the bow's, else "shield_up" while a shield in the left hand is raised, else "".
static func arm_pose(b: Dictionary) -> String:
	var bow: String = bow_pose(b)

	if bow != "":
		return bow

	return "shield_up" if str(b.get("left_kind", "")) == "shield" and str(b.get("held_kind", "")) != "bow" and (int(b.get("more", 0)) & MORE_SHIELD_UP) != 0 else ""


# "bow_raised", "bow_drawn" or "" (the bow down, or not a bow in hand): the more byte's bow flags (the client's held_item.gd hand_flags, 162).
static func bow_pose(b: Dictionary) -> String:
	if str(b.get("held_kind", "")) != "bow":
		return ""

	var more_now: int = int(b.get("more", 0))
	return "bow_drawn" if (more_now & MORE_BOW_DRAWN) != 0 else ("bow_raised" if (more_now & MORE_BOW_RAISED) != 0 else "")


# The bow in the aim (162): upright before the body at the left fist with its top canted to the right (as the archer's own first-person bow,
# held_item.gd _pose_bow), the string back at the right hand, the arrow nocked; lowered, it hangs at the side as before. Within FULL_M only.
func _pose_bow(b: Dictionary, distance: float) -> void:
	var held: Node3D = b.get("held_node", null) as Node3D
	var pose: String = bow_pose(b)

	if (pose == "" and not b.has("bow_rest")) or held == null or not is_instance_valid(held) or not held.is_inside_tree():
		return   # nothing to pose or put back (every body, every frame: no child walk)

	# The bow's own mesh (limbs along its x, as the player's own held_item.gd _pose_bow poses it), not the holder that turns it for the
	# hand mount: posing the holder pointed the limbs at the target, the bow lying flat (Lane A S8, 23 Nov 2026).
	var meshes: Array = held.find_children("*", "MeshInstance3D", false, false)
	var model: Node3D = meshes[0] as Node3D if meshes.size() == 1 else held

	if pose == "" or distance > FULL_M:
		if b.has("bow_rest"):
			model.transform = b["bow_rest"]
			b.erase("bow_rest")
			HeldItem._set_bow_string(model, Vector3.ZERO)
			HeldItem._place_nocked_arrow(model, Vector3.ZERO, false)

		return

	if not b.has("bow_rest"):
		b["bow_rest"] = model.transform

	var mount: Node3D = held.get_parent() as Node3D
	var body: Node3D = b["node"]
	var face: Vector3 = -body.global_basis.z
	face = Vector3(face.x, 0.0, face.z).normalized() if Vector2(face.x, face.z).length() > 0.001 else Vector3.FORWARD
	var right: Vector3 = face.cross(Vector3.UP).normalized()
	var up: Vector3 = (Vector3.UP * cos(deg_to_rad(HeldItem.BOW_CANT_DEG)) + right * sin(deg_to_rad(HeldItem.BOW_CANT_DEG))).normalized()
	var across: Vector3 = face.cross(up).normalized()
	var frame: Basis = Basis(up, across, up.cross(across).normalized())
	model.global_transform = Transform3D(frame, mount.global_position - frame.z * HeldItem.BasicLook.BOW_BRACE_M)
	var nock: Vector3 = Vector3(HeldItem.BOW_NOCK_ABOVE_M, -HeldItem.BOW_ARROW_SIDE_M, -HeldItem.BOW_DRAW_MAX_M if pose == "bow_drawn" else -0.12)
	HeldItem._set_bow_string(model, nock)
	HeldItem._place_nocked_arrow(model, nock, true)


# The left hand (159): a torch, lantern or shield made by the player's own held_item.gd makers, so it looks the same; a torch burns (its
# flame and light) only while the server says it does, a lantern by its kind (wooden_lantern lit, _dark not). Lights: only the LIT_MOST
# nearest (_light_pass). The torch stands up out of the fist and the lantern hangs, as the player's own third-person body holds them.
func _show_left(b: Dictionary, distance: float) -> void:
	var number: int = int(b.get("left", 0))
	var lit: bool = (int(b.get("more", 0)) & MORE_LIT) != 0
	var shown: int = number * 2 + (1 if lit else 0)
	b["distance"] = distance

	if shown != int(b.get("shown_left", 0)):
		b["shown_left"] = shown
		var old: Node3D = b.get("left_node", null) as Node3D

		if old != null and is_instance_valid(old):
			old.queue_free()

		b["left_node"] = null
		b["left_kind"] = ""
		var made: Array = left_in(b["rig"], number, lit, table, maker())

		if not made.is_empty():
			b["left_node"] = made[0]
			b["left_kind"] = made[1]
			var light: Node = (made[0] as Node3D).get_node_or_null("Light")

			if light is OmniLight3D:   # as bright as the player's own (held_item.gd _show_off_model), without its flicker
				(light as OmniLight3D).light_energy = TORCH_ENERGY_LANTERN if made[1] == "lantern" else HeldItem.FlameRules.TORCH_LIGHT_ENERGY

	var model: Node3D = b.get("left_node", null) as Node3D

	if model == null or not is_instance_valid(model) or not model.is_inside_tree():
		return

	var kind: String = str(b.get("left_kind", ""))
	model.visible = str(b.get("held_kind", "")) != "bow"   # a bow takes both hands: the left item is put away, as the player's own (held_item.gd _off_model)

	if kind == "lantern":
		model.global_basis = Basis.IDENTITY   # hangs straight down by its bail
	elif kind == "torch":
		HeldItem.stand_torch(model, b["rig"])
	elif kind == "shield":
		if (int(b.get("more", 0)) & MORE_SHIELD_UP) == 0:
			model.rotation = Vector3.ZERO
		else:
			model.global_basis = (b["node"] as Node3D).global_basis.orthonormalized()   # B held: the arm across the chest (the shield_up gait), its face and boss ahead (-Z), upright


var lit_most: Callable = func() -> int: return LIT_MOST
var _maker = null   # one HeldItem, never in the tree, for its torch, lantern and shield makers (they read only _inv.table and _root)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _maker != null and is_instance_valid(_maker):
		_maker.free()


# The HeldItem whose makers draw the left-hand items (made once).
func maker():
	if _maker == null:
		_maker = HeldItem.new()
		_maker._inv = MakerTable.new()
		_maker._inv.table = table
		_maker._root = self

	return _maker


class MakerTable:
	extends RefCounted
	var table


# [model, kind ("torch", "lantern", "shield")] in `rig`'s left hand for item `number`, or [] for nothing.
static func left_in(rig: Node3D, number: int, lit: bool, item_table, made_by) -> Array:
	if number <= 0 or item_table == null or rig == null:
		return []

	var mount: Node3D = rig.get("hand_mount_l") as Node3D

	if mount == null:
		return []

	var id: String = item_table.id_of(number)
	var row: Dictionary = item_table.entry(id)
	var tool_class: String = str(row.get("tool_class", ""))

	var model: Node3D
	var kind: String

	if tool_class == "shield":
		model = made_by._make_shield_model()
		kind = "shield"
	elif tool_class in ["lantern", "lantern_dark"]:
		model = made_by._make_lantern_model(id)
		kind = "lantern"
	elif tool_class == "torch":
		model = made_by._make_torch_model(id, not lit)
		kind = "torch"
	else:
		return []

	mount.add_child(model)

	if kind == "torch":
		model.set_meta("grip_y", float(HeldItem.GRIP_ALONG_Y["torch"]))
		var skin: Variant = rig.get("_skin_material")
		var tint: Color = (skin as BaseMaterial3D).albedo_color if skin is BaseMaterial3D else Color.WHITE
		HeldItem.third_fist_on(model, Color(HeldItem.THIRD_SKIN.r * tint.r, HeldItem.THIRD_SKIN.g * tint.g, HeldItem.THIRD_SKIN.b * tint.b))

	return [model, kind]


# Where other players carry a burning torch or lantern (the more byte's lit flag, the left or right hand's kind), within `max_m` of `from`,
# nearest first: [[point, "torch" or "lantern"], ...] (flame_sounds.gd others: the flame heard at their hand). Look only, a few bodies.
func flames_near(from: Vector3, max_m: float) -> Array:
	var out: Array = []

	for peer in _bodies:
		var b: Dictionary = _bodies[peer]

		if (int(b.get("more", 0)) & MORE_LIT) == 0 or not (b.get("node") is Node3D) or str(b.get("held_kind", "")) == "bow":
			continue   # unlit, or put away for the bow (_show_left)

		var kind: String = "lantern" if "lantern" in [str(b.get("left_kind", "")), str(b.get("held_kind", ""))] else "torch"
		var at: Vector3 = (b["node"] as Node3D).global_position + Vector3(0.0, DRAW_UP_M, 0.0)

		if at.distance_to(from) <= max_m:
			out.append([at, kind])

	out.sort_custom(func(p: Array, q: Array) -> bool: return (p[0] as Vector3).distance_squared_to(from) < (q[0] as Vector3).distance_squared_to(from))
	return out


# Only the LIT_MOST nearest other players' torches and lanterns cast light (once a frame, a few bodies at most).
func _light_pass() -> void:
	var lit: Array = []

	for peer in _bodies:
		var model: Node3D = _bodies[peer].get("left_node", null) as Node3D

		if model != null and is_instance_valid(model) and model.visible and model.get_node_or_null("Light") != null:   # one put away for a bow takes no slot
			lit.append([float(_bodies[peer].get("distance", 0.0)), model])

	lit.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
	var most: int = int(lit_most.call())

	for i in range(lit.size()):
		var light: OmniLight3D = (lit[i][1] as Node3D).get_node("Light") as OmniLight3D
		light.visible = i < most
		var hand: Node = (lit[i][1] as Node3D).get_node_or_null("HandLight")

		if hand is OmniLight3D:
			(hand as OmniLight3D).visible = false   # only the bearer's own torch lights their own hand: one light per other player


# Puts the held model of item `number` in `rig`'s hand as the player's own third-person body holds it: [model, kind], or [] for nothing.
# kind is "spear", "bow", "kit", "torch", "knife", "axe" or "other" (held_item.gd _mount_model). A spear is aimed by aim_spear every frame.
static func hold_in(rig: Node3D, number: int, item_table) -> Array:
	var kind: String = held_kind(number, item_table)
	var model: Node3D = held_model(number, item_table)
	var mount: Node3D = rig.get("hand_mount_l" if kind == "bow" else "hand_mount_r") as Node3D

	if model == null or mount == null:
		if model != null:
			model.free()
		return []

	mount.add_child(model)

	if kind == "bow":
		model.set_meta("grip_y", 0.03)   # a bow is held at its middle (held_item.gd _make_look_tool_model)

	if kind == "spear":
		aim_spear(model, rig)
	else:
		HeldItem.third_hold(model, kind if kind != "bow" else "other", str(item_table.entry(item_table.id_of(number)).get("tool_class", "")))

	if kind != "kit" and kind != "bow":
		var skin: Variant = rig.get("_skin_material")
		var tint: Color = (skin as BaseMaterial3D).albedo_color if skin is BaseMaterial3D else Color.WHITE
		HeldItem.third_fist_on(model, Color(HeldItem.THIRD_SKIN.r * tint.r, HeldItem.THIRD_SKIN.g * tint.g, HeldItem.THIRD_SKIN.b * tint.b))

	return [model, kind]


# The clip another player's body plays for one blow with item `number` in hand (held_item.gd work_clip for an axe or pick): the overhead arc
# for a pick axe, the jab for a spear, knife or bare hand, the wide chop for every other tool.
static func work_clip(number: int, item_table) -> String:
	var kind: String = held_kind(number, item_table)

	if kind in ["", "spear", "knife"]:
		return "jab"

	if kind == "kit" or kind == "bow" or kind == "torch":
		return ""

	var tool_class: String = str(item_table.entry(item_table.id_of(number)).get("tool_class", ""))

	if tool_class == "rod":
		return "throw"   # the cast: arms up and over, then forward (the chop read as a stoop with the rod along the ground: Lane A S7, 23 Nov 2026)

	return "pick_overhead" if tool_class == "pick" else "chop"


# How the player's own body holds an item (held_item.gd _mount_model's kind): from items.json weapon_class, tool_class and kind.
static func held_kind(number: int, item_table) -> String:
	if number <= 0 or item_table == null:
		return ""

	var id: String = item_table.id_of(number)
	var row: Dictionary = item_table.entry(id)
	var tool_class: String = str(row.get("tool_class", ""))

	if str(row.get("weapon_class", "")) in ["spear", "fish_spear"] or HeldItem.shaft_look(id):
		return "spear"   # a pike, lance or quarterstaff (a "shaft" look) too: its mesh lies point to -Z, as a spear's, not handle to head along +Y

	if str(HeldItem.BasicLook.entry(id).get("shape", "")) == "bow":
		return "bow"

	if tool_class == "torch":
		return "torch"

	if tool_class == "knife":
		return "knife"

	if tool_class in ["axe", "pick"]:
		return "axe"

	if str(row.get("kind", "")) == "placeable":
		return "kit"

	return "other"


# A held item's model, or null (nothing in hand, no table, or no hand look for it).
static func held_model(number: int, item_table) -> Node3D:
	if number <= 0 or item_table == null:
		return null

	var id: String = item_table.id_of(number)
	var shape: String = str(HeldItem.BasicLook.entry(id).get("shape", ""))

	if id == "" or not HeldItem.BasicLook.has_look(id) or not HeldItem.HELD_LOOK_TURN.has(shape):
		return null

	var node: Node3D = HeldItem.look_tool_node(id)

	if shape == "bow" and node.get_child_count() == 1 and node.get_child(0) is MeshInstance3D:
		# The hand's bow, as the player's own (held_item.gd _make_look_tool_model): no string in its mesh, two cords to the nock point and the
		# nocked arrow, so another player's drawn bow shows its string back and an arrow (review of the S8 fix, 23 Nov 2026: they were never made).
		var def: Dictionary = HeldItem.BasicLook.entry(id)
		var bow: MeshInstance3D = node.get_child(0) as MeshInstance3D
		bow.mesh = HeldItem.BasicLook.mesh("bow", Color.html(str(def.get("color", "#a8804a"))), float(def.get("size", 1.0)), (def.get("bits", []) as Array) + ["held"])
		HeldItem.add_bow_parts(bow)

	return node


# The spear's place each frame, as held_item.gd _aim_spear in third person: its point (model -Z) along the body's facing lifted SPEAR_LIFT_DEG,
# the hand SPEAR_GRIP_Z behind the middle, whatever the hand bone's angle in the clip.
static func aim_spear(model: Node3D, rig: Node3D) -> void:
	if model == null or not model.is_inside_tree() or rig == null or not rig.is_inside_tree():
		return

	var front: Vector3 = rig.global_basis * Vector3.FORWARD
	front.y = 0.0

	if front.length_squared() < 1e-12:
		return

	var tip: Vector3 = (front.normalized() + Vector3.UP * tan(deg_to_rad(HeldItem.SPEAR_LIFT_DEG))).normalized()
	var z: Vector3 = -tip
	var x: Vector3 = Vector3.UP.cross(z).normalized()
	var mount: Node3D = model.get_parent() as Node3D
	follow_hand(model)   # the hand of this step, or the spear is turned by the last step's swing
	model.global_transform = Transform3D(Basis(x, z.cross(x), z), mount.global_position + tip * HeldItem.SPEAR_GRIP_Z)
	var fist: Node3D = model.get_node_or_null(HeldItem.THIRD_FIST_NAME) as Node3D

	if fist != null:
		fist.transform = model.transform.affine_inverse() * Transform3D(Basis.from_scale(HeldItem.THIRD_FIST_SCALE), Vector3.ZERO)   # back on the hand, as held_item.gd refits it each frame


# A held item's hand mount moved to this step's hand now. The mount is on a BoneAttachment3D, which follows the bones only at the skeleton's
# deferred update, so straight after advance() it still held the last step's hand: 0.32 m off it at a run (robots 23 Nov 2026, measured
# in a node's _process after this one), until the frame's end. Drawn right either way; this keeps what code reads in the frame true.
static func follow_hand(model: Node3D) -> void:
	if model == null or not is_instance_valid(model) or not model.is_inside_tree():
		return

	var attach: BoneAttachment3D = model.get_parent().get_parent() as BoneAttachment3D if model.get_parent() != null else null

	if attach != null:
		attach.on_skeleton_update()


# The body files this look needs are read (warmed on loader threads by on_look): no main-thread read of a 28 MB glb in the middle of play.
static func _can_make(look: Dictionary) -> bool:
	var genome: Dictionary = BodyGenerator.decode(str(look.get("code", ""))) if str(look.get("code", "")) != "" else {}
	var paths: Array = [BodyModels.glb(str(look.get("body", BodyModels.DEFAULT)))]
	var hair: String = str(genome.get("hair_model", HairModels.NONE))

	if HairModels.has(hair):
		paths.append(HairModels.glb(hair))

	for path in paths:
		if DynastyBodyScript.load_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return false

	return true


func _make(peer: int, at: Vector3, yaw: float) -> Dictionary:
	var look: Dictionary = _looks[peer]
	var genome: Dictionary = BodyGenerator.decode(str(look["code"])) if str(look["code"]) != "" else {}
	var root: Node3D = Node3D.new()
	root.name = "Player%d" % peer
	root.position = at
	root.rotation.y = yaw
	var rig: Node3D = make_rig(str(look["body"]), genome)
	rig.name = "Rig"
	rig.position.y = -float(StanceScript.SHAPE_HEIGHT[StanceScript.STAND]) * 0.5   # feet on the ground: the sent position is the standing body's middle, as the player's own avatar
	root.add_child(rig)
	var label: Label3D = Label3D.new()
	label.name = "Name"
	label.text = _name_of(peer)
	label.font_size = 48
	label.pixel_size = 0.008
	label.no_depth_test = false
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, NAME_HEIGHT_M + rig.position.y, 0.0)   # over the head, from the feet as an NPC's name
	label.modulate = Color(0.85, 0.95, 1.0)   # a little bluer than an NPC's name
	label.outline_size = 8
	root.add_child(label)
	add_child(root)
	var player: AnimationPlayer = rig.get("animation_player") as AnimationPlayer

	if player != null:
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		rig.play("idle")

	var b: Dictionary = {"peer": peer, "node": root, "rig": rig, "samples": [], "row_ms": -1, "state": 0, "held": 0, "shown_held": 0}
	_dress(b)
	return b


# The body a look wears: Dave's Dynasty body of that model shaped by the creator's code, or the generated body when the glb is not imported.
static func make_rig(body: String, genome: Dictionary) -> Node3D:
	if DynastyBodyScript.available():
		var rig: Node3D = DynastyBodyScript.new(body if BodyModels.has(body) else BodyModels.DEFAULT)

		if not genome.is_empty():
			rig.set_proportions(genome)

		return rig

	return GeneratedBodyScript.new(genome)


func _dress(b: Dictionary) -> void:
	if table == null:
		return

	AvatarDriver.dress_worn(b["rig"], _looks.get(int(b["peer"]), {}).get("worn", PackedInt32Array()), table)


func _drop(peer: int) -> void:
	if _bodies.has(peer):
		(_bodies[peer]["node"] as Node3D).queue_free()
		_bodies.erase(peer)


func _name_of(peer: int) -> String:
	var shown: String = str(_looks.get(peer, {}).get("name", "")).strip_edges()
	return shown if shown != "" else NO_NAME
