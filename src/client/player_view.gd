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
const FULL_M := 15.0
const HALF_M := 40.0
const QUARTER_M := 70.0
const SWIM := 4
const CARRY := 8
const CARRY_LOG_LENGTH_M := 3.0          # terrain_client.gd CARRY_LOG_LENGTH_M
const CARRY_LOG_RADIUS_M := 0.14
const LOG_COLOR := Color(0.32, 0.23, 0.15)
const NAME_HEIGHT_M := 2.05
const NO_NAME := "Traveller"

var table                            # the client's item table (id_of, entry), for worn and held items
var _looks: Dictionary = {}          # peer -> {"name", "body", "code", "worn"}
var _bodies: Dictionary = {}         # peer -> {"node", "rig", "samples", "row_ms", "gap", "state", "held", ...}
var _off: float = INF                # local seconds minus server seconds (MotionBuffer.clock_off)
var _last_ms: int = -1


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


func on_rows(ids: PackedInt32Array, positions: PackedVector3Array, yaws: PackedFloat32Array, states: PackedByteArray, held: PackedInt32Array, times: PackedInt32Array) -> void:
	var n: int = mini(ids.size(), mini(positions.size(), mini(yaws.size(), mini(states.size(), mini(held.size(), times.size())))))
	var now_s: float = float(Time.get_ticks_usec()) / 1.0e6
	var newest: int = -1

	for i in range(n):
		newest = maxi(newest, times[i])

	if newest >= 0:
		_off = MotionBuffer.clock_off(_off, now_s, newest, _last_ms)
		_last_ms = newest

	var seen: Dictionary = {}

	for i in range(n):
		var peer: int = ids[i]
		seen[peer] = true

		if not _bodies.has(peer):
			if _bodies.size() >= MAX_DRAWN or not _looks.has(peer) or not _can_make(_looks[peer]):
				continue

			_bodies[peer] = _make(peer, positions[i], yaws[i])

		var b: Dictionary = _bodies[peer]
		var last_ms: int = int(b.get("row_ms", -1))

		if last_ms >= 0 and times[i] > last_ms:
			b["gap"] = lerpf(float(b["gap"]), clampf(float(times[i] - last_ms) / 1000.0, 0.05, 0.5), 0.2)

		b["state"] = int(states[i])
		b["held"] = int(held[i])
		MotionBuffer.push_row(b, positions[i], yaws[i], times[i], _off, float(b["gap"]))

	for peer in _bodies.keys():
		if not seen.has(peer):
			_drop(peer)


func drawn_count() -> int:
	return _bodies.size()


# [{"peer", "name", "pos"}] of the drawn players, for checks and the debug line.
func drawn() -> Array:
	var out: Array = []

	for peer in _bodies:
		out.append({"peer": peer, "name": _name_of(peer), "pos": (_bodies[peer]["node"] as Node3D).position})

	return out


func _process(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var frame: int = Engine.get_process_frames()
	var now_s: float = float(Time.get_ticks_usec()) / 1.0e6

	for peer in _bodies:
		var b: Dictionary = _bodies[peer]
		var node: Node3D = b["node"]
		var rig: Node3D = b["rig"]
		var before: Vector3 = node.position

		if not (b["samples"] as Array).is_empty():
			var at: Array = MotionBuffer.at(b["samples"], now_s - MotionBuffer.delay_s(float(b["gap"])))
			node.position = at[0]
			node.rotation.y = lerp_angle(node.rotation.y, float(at[1]), clampf(delta * 12.0, 0.0, 1.0))

		var moved: Vector3 = (node.position - before) / maxf(delta, 0.001)
		var velocity: Vector3 = (b.get("velocity", Vector3.ZERO) as Vector3).lerp(moved, clampf(delta * 8.0, 0.0, 1.0))
		b["velocity"] = velocity
		var distance: float = eye.distance_to(node.global_position)
		_far_check(b, distance, delta)
		_show_held(b)
		var player: AnimationPlayer = rig.get("animation_player") as AnimationPlayer

		if player == null:
			continue

		var every: int = 1 if distance <= FULL_M else (2 if distance <= HALF_M else (4 if distance <= QUARTER_M else 0))
		b["owed"] = float(b.get("owed", 0.0)) + delta

		if every == 0:
			b["owed"] = 0.0
			continue

		if (frame + (peer & 3)) % every != 0:
			continue

		var step: float = float(b["owed"])
		b["owed"] = 0.0
		_animate(b, velocity, step)
		player.advance(step)


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
	rig.set_meta("torch_in_hand", false)
	rig.set_meta("torch_left", false)
	var clip: String = AvatarDriver.clip_for(rig, stance, flat, node.global_transform.basis, true, pace, rig.current(), carrying, step)
	var hook: String = AvatarDriver.hook_clip(rig, {"swimming": swimming, "asleep": false, "stance": stance, "drink_stamp": 0}, pace, step)

	if hook != "":
		clip = hook

	if rig.has_method("set_shoulder_log") and bool(b.get("log_shown", false)) != carrying:
		b["log_shown"] = carrying
		rig.set_shoulder_log(CARRY_LOG_LENGTH_M if carrying else 0.0, CARRY_LOG_RADIUS_M, LOG_COLOR)

	if rig.current() != clip and not rig.is_one_shot_playing():
		rig.play(clip, 1.0, 0.25)

	var player: AnimationPlayer = rig.get("animation_player") as AnimationPlayer
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


# The item in the hand: its look (held_item.gd look_tool_node, held as third person holds it), or nothing for an item without a hand look.
func _show_held(b: Dictionary) -> void:
	var number: int = int(b.get("held", 0))

	if number == int(b.get("shown_held", 0)):
		return

	b["shown_held"] = number
	var old: Node3D = b.get("held_node", null) as Node3D

	if old != null and is_instance_valid(old):
		old.queue_free()

	b["held_node"] = null
	var model: Node3D = held_model(number, table)
	var rig: Node3D = b["rig"]
	var mount: Node3D = rig.get("hand_mount_r") as Node3D

	if model == null or mount == null:
		if model != null:
			model.free()
		return

	mount.add_child(model)
	b["held_node"] = model


# A held item's model in a third-person hand, or null (nothing in hand, no table, or no hand look for it).
static func held_model(number: int, item_table) -> Node3D:
	if number <= 0 or item_table == null:
		return null

	var id: String = item_table.id_of(number)
	var shape: String = str(HeldItem.BasicLook.entry(id).get("shape", ""))

	if id == "" or not HeldItem.BasicLook.has_look(id) or not HeldItem.HELD_LOOK_TURN.has(shape):
		return null

	var model: Node3D = HeldItem.look_tool_node(id)
	HeldItem.third_hold(model, "other", str(item_table.entry(id).get("tool_class", "")))
	return model


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

	var b: Dictionary = {"peer": peer, "node": root, "rig": rig, "samples": [], "row_ms": -1, "gap": 0.2, "state": 0, "held": 0, "shown_held": 0}
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
