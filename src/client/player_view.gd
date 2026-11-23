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
const REPORT_S := 0.2                  # a client reports its position every 0.2 s (terrain_client.gd report_position)
const MAKE_PER_ROWS := 2               # bodies made per rows message: a crowd coming into range is built over a few sends, not in one frame
const FULL_M := 15.0
const HALF_M := 40.0
const QUARTER_M := 70.0
const SWIM := 4
const CARRY := 8
const ASLEEP := 16                     # server_players.gd: asleep (the lying clip, as the player's own body)
const MORE_LIT := 1                   # server_players.gd more byte (157): a burning torch or lantern...
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
const STEP_M := [1.2, 3.0]               # terrain_client.gd STEP_M: metres per step walking, running
const RUN_FROM_MPS := 6.0                # drawn pace from which a player counts as running (walk 3.2, run 9.0 m/s)
const STEP_FROM_MPS := 1.0               # slower than this makes no steps (terrain_client.gd _update_bob)
const STEP_HEAR_M := 45.0                # sound_stage.gd OTHER_STEP_REACH_M: farther steps are not counted
const FEET_M := 0.9                      # the sent position is the standing body's middle

var table                            # the client's item table (id_of, entry), for worn and held items
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


func on_rows(ids: PackedInt32Array, positions: PackedVector3Array, yaws: PackedFloat32Array, states: PackedByteArray, held: PackedInt32Array, times: PackedInt32Array, left: PackedInt32Array = PackedInt32Array(), more: PackedByteArray = PackedByteArray()) -> void:
	var n: int = mini(ids.size(), mini(positions.size(), mini(yaws.size(), mini(states.size(), mini(held.size(), times.size())))))
	var now_s: float = float(Time.get_ticks_usec()) / 1.0e6
	var newest: int = -1

	for i in range(n):
		newest = maxi(newest, times[i])

	if newest >= 0:
		if newest > int(_clock["server_ms"]) or newest < int(_clock["server_ms"]) - 2000:
			MotionBuffer.clock_note(_clock, now_s, newest)   # the batch's newest position report (players report every 0.2 s, standing too);
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
		b["more"] = int(more[i]) if i < more.size() else 0
		b["held"] = int(held[i])
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
	var drawn_at: float = now_s - draw_delay(_clock)
	_light_pass()

	for peer in _bodies:
		var b: Dictionary = _bodies[peer]
		var node: Node3D = b["node"]
		var rig: Node3D = b["rig"]
		var before: Vector3 = b.get("path_p", node.position)

		if not (b["samples"] as Array).is_empty():
			var at: Array = MotionBuffer.at(b["samples"], drawn_at, CARRY_S)   # through a hole of lost batches a player walks on (two legs at most), then the easing takes the rest
			b["path_p"] = at[0]
			# A late batch or a lost one never jumps the body: the step beyond a normal one is eased in (MotionBuffer.smooth, as the animals).
			node.position = MotionBuffer.smooth(b, at[0], MotionBuffer.speed_at(b["samples"], drawn_at), delta)
			node.rotation.y = lerp_angle(node.rotation.y, float(at[1]), clampf(delta * 12.0, 0.0, 1.0))

		# The legs follow the path's own speed, not the easing (a correction slid in is not a step).
		var moved: Vector3 = (((b.get("path_p", node.position) as Vector3) - before) / maxf(delta, 0.001)).limit_length(MotionBuffer.CARRY_MPS)   # a carried-on point taken back is not a sprint
		var velocity: Vector3 = (b.get("velocity", Vector3.ZERO) as Vector3).lerp(moved, clampf(delta * 8.0, 0.0, 1.0))
		b["velocity"] = velocity
		var distance: float = eye.distance_to(node.global_position)
		_count_steps(b, velocity, delta, distance)
		_far_check(b, distance, delta)
		_show_held(b)
		_show_left(b, distance)
		var player: AnimationPlayer = rig.get("animation_player") as AnimationPlayer

		if player == null:
			continue

		var every: int = 1 if distance <= FULL_M else (2 if distance <= HALF_M else (4 if distance <= QUARTER_M else 0))
		b["owed"] = float(b.get("owed", 0.0)) + delta

		if every == 0:
			b["owed"] = 0.0
			b["swing_due"] = false   # a blow far off is not played when the body comes near later
			continue

		if (frame + (peer & 3)) % every != 0:
			continue

		var step: float = float(b["owed"])
		b["owed"] = 0.0
		_animate(b, velocity, step)
		player.advance(step)

		if str(b.get("held_kind", "")) == "spear":
			aim_spear(b["held_node"] as Node3D, b["rig"])   # after the pose: the spear keeps the facing, not the hand bone's angle



# A step each stride of drawn ground travel, for a player on foot (not swimming, sitting or lying) within hearing.
func _count_steps(b: Dictionary, velocity: Vector3, delta: float, distance: float) -> void:
	var state: int = int(b["state"])
	var stance: int = state & 3
	var pace: float = Vector2(velocity.x, velocity.z).length()

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
	rig.set_meta("torch_left", str(b.get("left_kind", "")) == "torch")   # the arm carries it up in front (dynasty_body.gd _torch_carry), as held_item.gd torch_in_left
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
			var share: float = HeldItem.PICK_HIT_AT if work == "pick_overhead" else (HeldItem.HIT_AT if work == "chop" else 0.0)
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


# The left hand (157): a torch, lantern or shield made by the player's own held_item.gd makers, so it looks the same; a torch burns (its
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

	if kind == "lantern":
		model.global_basis = Basis.IDENTITY   # hangs straight down by its bail
	elif kind == "torch":
		HeldItem.stand_torch(model, b["rig"])
	elif kind == "shield":
		model.rotation = Vector3(0.0, 0.0, 0.0) if (int(b.get("more", 0)) & MORE_SHIELD_UP) == 0 else Vector3(deg_to_rad(-70.0), 0.0, 0.0)   # B held: up before the body


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


# Only the LIT_MOST nearest other players' torches and lanterns cast light (once a frame, a few bodies at most).
func _light_pass() -> void:
	var lit: Array = []

	for peer in _bodies:
		var model: Node3D = _bodies[peer].get("left_node", null) as Node3D

		if model != null and is_instance_valid(model) and model.get_node_or_null("Light") != null:
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

	return "pick_overhead" if str(item_table.entry(item_table.id_of(number)).get("tool_class", "")) == "pick" else "chop"


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

	return HeldItem.look_tool_node(id)


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
	model.global_transform = Transform3D(Basis(x, z.cross(x), z), mount.global_position + tip * HeldItem.SPEAR_GRIP_Z)
	var fist: Node3D = model.get_node_or_null(HeldItem.THIRD_FIST_NAME) as Node3D

	if fist != null:
		fist.transform = model.transform.affine_inverse() * Transform3D(Basis.from_scale(HeldItem.THIRD_FIST_SCALE), Vector3.ZERO)   # back on the hand, as held_item.gd refits it each frame


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
