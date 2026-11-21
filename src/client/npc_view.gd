extends Node3D

const FrameProbe := preload("res://src/debug/frame_probe.gd")

# Classic NPCs on the client (protocol 45). Each is the player's rounded ragdoll (ragdoll_body.gd), dressed in a coat, trousers
# and shoes by outfit with a small colour variation per NPC, a name above, and the clips idle / walk / jog / run / sit / lie chosen
# from the server state and the measured speed. The server sends rows about four times a second; the view glides to each.
# Animation by distance from the camera (Tyler Report 17, Dave: full within 15 m, reduced beyond, frozen past 70 m): every frame
# to 15 m, every 2nd frame to 40 m, every 4th to 70 m, a held pose beyond. At most MAX_DRAWN are drawn (the nearest).

const MAX_DRAWN := 20
const STAND := 0
const WALK := 1
const SIT := 2
const SLEEP := 3
const WORK := 4                          # protocol 146: a goblin tribe member at a chore (its "work" clip: gathering, feeding the fire)
const GUARD := 5                         # protocol 146: standing its ground at a weapon in hand, spear forward (its guard clip, models.json "10")
const SPEAR_GUARD_DEG := 15.0            # the spear's angle above level in the guard stance
const CHITTER_S := [2.0, 4.0]            # seconds between a guarding goblin's angry calls
const HISS_GAP_S := 9.0                   # at most one squaring-up hiss per goblin this often
const SEAT_TOP_M := 0.45                 # the chair's seat top above its feet (building_look.gd chair: slats at 0.43, 0.045 thick)
const SEAT_HIPS_ABOVE_M := 0.07          # the hips joint over the seat top, as the player sits (terrain_client.gd, #517)
const SEAT_LIFT_MAX_M := 0.6             # never move the body more than this to meet the seat
const MotionBuffer := preload("res://src/client/motion_buffer.gd")   # goblins are drawn between sent points, as the animals are (Dave 20 Nov 2026: "keep their motions fluid and smooth")
const GeneratedBodyScript := preload("res://src/client/character/generated_body.gd")
const BodyGenerator := preload("res://src/client/character/body_generator.gd")
const DynastyBodyScript := preload("res://src/client/character/dynasty_body.gd")
const VARIANTS := 8                  # with --generated-body: this many body types, built once each and shared (see _make_body)
const BuildingLook := preload("res://src/client/building_look.gd")
const WornSync := preload("res://src/client/worn_sync.gd")
const OUTFITS_PATH := "res://data/npcs/outfits.json"
const HeldItem := preload("res://src/client/held_item.gd")   # look_tool_node: the Wooden spear a camp goblin carries (Dave 20 Nov 2026)
const GOBLIN_SPEAR := "wooden_spear"
const SPEAR_STAFF_DEG := 90.0     # a goblin at rest or at work holds its spear upright, butt down, like a staff
const SPEAR_HOLD_M := 0.3         # the hand holds it this far below the spear's middle (toward the butt)
const FULL_M := 15.0
const HALF_M := 40.0
const QUARTER_M := 70.0

var roster: Dictionary = {}      # id -> {name, role, outfit}
var _outfits: Dictionary = {}    # outfit name -> item ids worn on top of the ragdoll (data/npcs/outfits.json)
var _bodies: Dictionary = {}     # id -> {node, target Vector3, heading, state}
signal goblin_called(at: Vector3, mood: String)   # a camp goblin's angry call (creature_sounds.gd "goblin"): chitter on guard, hiss as it starts
var goblin_maker: Callable       # (variant, look_seed) -> Node3D or null: a goblin tribe member's body (AnimalView.make_goblin), set by the client
var _gap: float = 0.25           # recent seconds between rows, for MotionBuffer
var _rows_at: float = -1.0       # when the last rows came


func _exit_tree() -> void:
	BodyGenerator.wait_for_jobs()      # no prewarm job may still be running when the program quits


func _ready() -> void:
	# Dave's body (the default): start reading its file on a loader thread, so the first NPC does not wait for it.
	# (ResourceLoader.exists, not available(): available() loads the 28 MB file on this thread.)
	if ResourceLoader.exists(DynastyBodyScript.GLB):
		DynastyBodyScript.warm()
	# The generated body (only when the glb is not there): start building the body types on worker threads now, so no NPC waits for its mesh when it first appears.
	else:
		for variant in range(VARIANTS):
			BodyGenerator.prewarm(BodyGenerator.genome_from_seed(variant), 0.045, false)
			BodyGenerator.prewarm(BodyGenerator.genome_from_seed(variant), BodyGenerator.lod_voxel(2), false)     # the far level (Plan 18)


func on_roster(rows: Array) -> void:
	roster.clear()

	for row in rows:
		roster[str(row[0])] = {"name": str(row[1]), "role": str(row[2]), "outfit": str(row[3])}


func on_rows(rows: Array) -> void:
	var seen: Dictionary = {}
	var now_s: float = float(Time.get_ticks_usec()) / 1.0e6

	if _rows_at >= 0.0:
		_gap = lerpf(_gap, clampf(now_s - _rows_at, 0.05, 0.5), 0.2)

	_rows_at = now_s

	for row in rows:
		var id: String = str(row[0])
		seen[id] = true

		if not _bodies.has(id):
			if _bodies.size() >= MAX_DRAWN:
				continue

			var node: Node3D = _make_body(id)
			node.position = row[1]
			add_child(node)
			_bodies[id] = {"node": node, "target": row[1], "heading": float(row[2]), "state": int(row[3]), "samples": []}

		_bodies[id]["target"] = row[1]
		_bodies[id]["heading"] = float(row[2])
		_bodies[id]["state"] = int(row[3])
		MotionBuffer.push(_bodies[id]["samples"], row[1], float(row[2]), now_s, _gap)

	for id in _bodies.keys():
		if not seen.has(id):
			_bodies[id]["node"].queue_free()
			_bodies.erase(id)


# The nearest NPC within reach of a point: {"id", "name"} or {} (for the Press E to talk prompt).
# Every body within `reach` (flat) of `point`, nearest first, as nearest() gives one: [{"id", "name", "pos"}].
func within(point: Vector3, reach: float) -> Array:
	var out: Array = []

	for id in _bodies:
		var at: Vector3 = _bodies[id]["target"]
		var d: float = Vector2(at.x - point.x, at.z - point.z).length()

		if d <= reach:
			out.append({"id": id, "name": str(roster.get(id, {}).get("name", id)), "pos": at, "d": d})

	out.sort_custom(func(x, y): return float(x["d"]) < float(y["d"]))
	return out


func nearest(point: Vector3, reach: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = reach

	for id in _bodies:
		var d: float = Vector2(_bodies[id]["target"].x - point.x, _bodies[id]["target"].z - point.z).length()

		if d <= best_d:
			best_d = d
			best = {"id": id, "name": str(roster.get(id, {}).get("name", id)), "pos": _bodies[id]["target"]}

	return best


# Where this view's bodies walked since the last call (grass trails, Dave 2026-10-21): a point a little behind each one that moved, within
# max_m of `from`, so no blade drops flat in front of anyone. Costs one distance test per body.
func trail_points(from: Vector3, max_m: float) -> Array:
	var out: Array = []

	for id in _bodies:
		var b: Dictionary = _bodies[id]
		var at: Vector3 = b["node"].position
		var last: Vector3 = b.get("trail_at", at)
		var step: Vector3 = Vector3(at.x - last.x, 0.0, at.z - last.z)

		if step.length() < 0.5 or from.distance_to(at) > max_m:
			continue

		b["trail_at"] = at
		out.append(at - step.normalized() * 0.6)

	return out


func drawn_count() -> int:
	return _bodies.size()


func _process(delta: float) -> void:
	var t: int = FrameProbe.start()
	_process_body(delta)
	FrameProbe.stop("npcs", t)


func _process_body(delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var frame: int = Engine.get_process_frames()

	for id in _bodies:
		var body: Dictionary = _bodies[id]
		var node: Node3D = body["node"]
		var state: int = body["state"]

		if node.has_meta("goblin"):
			_process_goblin(node, body, delta)
			continue
		var before: Vector3 = node.position
		node.position = node.position.lerp(body["target"], clampf(delta * 6.0, 0.0, 1.0))
		node.rotation.y = lerp_angle(node.rotation.y, -float(body["heading"]) - PI * 0.5, clampf(delta * 8.0, 0.0, 1.0))
		var ragdoll: Node3D = node.get_node("Rig")
		node.get_node("Chair").visible = state == SIT
		node.get_node("Bed").visible = state == SLEEP
		var pace: float = lerpf(float(body.get("pace", 0.0)), Vector2(node.position.x - before.x, node.position.z - before.z).length() / maxf(delta, 0.001), clampf(delta * 5.0, 0.0, 1.0))
		body["pace"] = pace
		# On the chair, not on the ground inside it (Dave 10 Nov 2026: "Edda is still sitting on the ground"): the chair clip, hips on the seat.
		var clip: String = "lie" if state == SLEEP else (_sit_clip(ragdoll) if state == SIT else "idle")

		if state == WALK or (state == STAND and pace > 0.5):
			clip = "run" if pace > 5.0 else ("jog" if pace > 2.2 else ("walk" if pace > 0.4 else "idle"))

		if ragdoll.current() != clip and not ragdoll.is_one_shot_playing():
			ragdoll.play(clip, 1.0, 0.25)

		var lift: float = 0.25 if state == SLEEP else (seat_lift(node, ragdoll) if state == SIT else 0.0)   # lying on the bed, sitting on the chair
		ragdoll.position.y = lerpf(ragdoll.position.y, lift, clampf(delta * 4.0, 0.0, 1.0))
		var player: AnimationPlayer = ragdoll.animation_player
		player.speed_scale = clampf(pace / 1.4, 0.5, 1.7) if clip == "walk" else (clampf(pace / 3.2, 0.8, 1.6) if clip == "jog" else (clampf(pace / 6.0, 0.8, 2.0) if clip == "run" else 1.0))
		var distance: float = eye.distance_to(node.global_position)
		body["far_t"] = float(body.get("far_t", randf())) - delta

		if float(body["far_t"]) <= 0.0:
			# One look a second: dress the body for its distance (far bodies skip the detail parts; a few metres of hysteresis).
			body["far_t"] = 1.0
			var far: bool = WornSync.far_after(distance, bool(body.get("far", false)))
			body["far"] = far

			if ragdoll.has_method("set_far"):
				ragdoll.set_far(far)

			WornSync.apply(ragdoll, _worn_of(str(roster.get(id, {}).get("outfit", ""))), far)

		var every: int = 1 if distance <= FULL_M else (2 if distance <= HALF_M else (4 if distance <= QUARTER_M else 0))
		body["owed"] = float(body.get("owed", 0.0)) + delta

		if every > 0 and (frame + int(id.hash() & 3)) % every == 0:
			player.advance(float(body["owed"]))
			body["owed"] = 0.0
		elif every == 0:
			body["owed"] = 0.0


# A goblin tribe member (outfit "goblin:<variant>"): drawn a little in the past on the line between its sent points (MotionBuffer, as the
# animals since animals part 2), so it walks at a steady speed with no lunge after each send; its turn is eased, and it plays its model's idle,
# walk or run clip by the measured speed (data/animals/models.json goblin clips "0", "walk", "run"), cross-faded, on the model's own player.
func _process_goblin(node: Node3D, body: Dictionary, delta: float) -> void:
	var before: Vector3 = node.position
	var drawn: Array = MotionBuffer.at(body["samples"], float(Time.get_ticks_usec()) / 1.0e6 - MotionBuffer.delay_s(_gap)) if not (body["samples"] as Array).is_empty() else [body["target"], body["heading"]]
	node.position = drawn[0]
	node.rotation.y = lerp_angle(node.rotation.y, -float(drawn[1]) - PI * 0.5, clampf(delta * 8.0, 0.0, 1.0))
	var pace: float = lerpf(float(body.get("pace", 0.0)), Vector2(node.position.x - before.x, node.position.z - before.z).length() / maxf(delta, 0.001), clampf(delta * 5.0, 0.0, 1.0))
	body["pace"] = pace
	var model: Node3D = node.get_node_or_null("Goblin")
	var player: AnimationPlayer = model.get_meta("player") as AnimationPlayer if model != null and model.has_meta("player") else null

	if player == null:
		return

	var roles: Dictionary = player.get_meta("roles", {})
	var role: String = "run" if pace > 2.2 else ("walk" if pace > 0.4 else "0")
	var state: int = int(body["state"])

	if role == "0" and state == WORK and roles.has("work"):
		role = "work"   # at a chore: gathering, kneeling at the fire, at the chest or a rack
	elif role == "0" and state == GUARD and roles.has("10"):
		role = "10"     # its guard stance (Skritch's Combat_Stance, Rukz's Alert)

	node.set_meta("spear_deg", SPEAR_GUARD_DEG if state == GUARD else SPEAR_STAFF_DEG)
	_chitter(node, body, state, delta)
	var clip: String = str(roles.get(role, roles.get("0", "")))

	if clip != "" and player.current_animation != clip:
		player.play(clip, 0.3)

	var ref: float = float(player.get_animation(clip).get_meta("travel_mps", 0.0)) if clip != "" and player.has_animation(clip) and role != "0" else 0.0
	player.speed_scale = clampf(pace / ref, 0.5, 2.0) if ref > 0.0 else 1.0
	_hold_spear(node, delta)


# A guarding goblin calls angrily every CHITTER_S (a hiss as it first squares up), through the creature voices (rate limited there).
func _chitter(node: Node3D, body: Dictionary, state: int, delta: float) -> void:
	if state != GUARD:
		body["chitter"] = -1.0
		return

	var wait: float = float(body.get("chitter", -1.0))

	if wait < 0.0:
		var now: float = Time.get_ticks_msec() / 1000.0

		if now - float(body.get("hissed", -INF)) >= HISS_GAP_S:   # one hiss as it squares up, not one per flicker at the edge of spook_m
			body["hissed"] = now
			goblin_called.emit(node.global_position, "threat")

		wait = randf_range(CHITTER_S[0], CHITTER_S[1])

	wait -= delta

	if wait <= 0.0:
		goblin_called.emit(node.global_position, "alert")
		wait = randf_range(CHITTER_S[0], CHITTER_S[1])

	body["chitter"] = wait


# The spear rides the right hand (its bone moves it with every clip) but keeps its own steady angle from the body's facing, as the player's spear
# does (held_item.gd _aim_spear): upright like a staff, eased toward `spear_deg` (a later guard stance points it ahead), so no clip twists it into
# the fist. Its size follows the goblin's.
func _hold_spear(node: Node3D, delta: float) -> void:
	var spear: Node3D = node.get_meta("spear", null) as Node3D

	if spear == null or not spear.is_inside_tree():
		return

	var want: float = float(node.get_meta("spear_deg", SPEAR_STAFF_DEG))
	var deg: float = lerpf(float(node.get_meta("spear_now", want)), want, clampf(delta * 4.0, 0.0, 1.0))
	node.set_meta("spear_now", deg)
	var size: float = (node.get_node("Goblin") as Node3D).global_basis.get_scale().y
	var turn: Basis = node.global_basis.orthonormalized() * Basis(Vector3.RIGHT, deg_to_rad(deg))   # the spear's point (-Z) turned up from the body's front
	var hand: Vector3 = (spear.get_parent() as Node3D).global_position
	spear.global_transform = Transform3D(turn.scaled(Vector3.ONE * size), hand + turn * Vector3(0.0, 0.0, -SPEAR_HOLD_M * size))


# The sitting clip: on the chair (the clip the player sits on a seat with) when the body has it, else the ground sit.
static func _sit_clip(ragdoll: Node3D) -> String:
	var player: AnimationPlayer = ragdoll.get("animation_player") as AnimationPlayer
	return "sit_chair" if player != null and player.has_animation("sit_chair") else "sit"


# How high the rig must stand in its NPC node so the posed hips joint rests SEAT_HIPS_ABOVE_M over the chair's seat (the chair stands
# on the node's ground): measured from the skeleton, so it holds for any body, clip or bone lengths, as terrain_client.gd does for
# the player. The rig's current lift is part of the measurement, so the answer is where it should be, not a step.
static func seat_lift(node: Node3D, ragdoll: Node3D) -> float:
	var skel: Skeleton3D = ragdoll.get("skeleton") as Skeleton3D

	if skel == null or not skel.is_inside_tree():
		return 0.0

	var hips: int = skel.find_bone("mixamorig_Hips")

	if hips < 0:
		return 0.0

	var hips_y: float = (node.global_transform.affine_inverse() * (skel.global_transform * skel.get_bone_global_pose(hips).origin)).y
	return clampf(ragdoll.position.y + SEAT_TOP_M + SEAT_HIPS_ABOVE_M - hips_y, -SEAT_LIFT_MAX_M, SEAT_LIFT_MAX_M)


# The worn items of an outfit name (data/npcs/outfits.json), read once.
func _worn_of(outfit: String) -> Array:
	if _outfits.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUTFITS_PATH))
		_outfits = parsed if typeof(parsed) == TYPE_DICTIONARY else {"": []}

	return WornSync.known_ids(_outfits.get(outfit, []))


# The body an NPC wears (Dave 4 Nov 2026: "NPCs can use your body by randomizing all the sliders"): Dave's own Dynasty body, the same one the player wears, with every creator
# slider (body, width and face) and the skin drawn at random from the NPC's id, so each townsperson looks different and keeps the same look every visit. The shaped mesh with
# the width and face blend shapes is shared by every Dynasty body; each NPC only sets its own weights and bone lengths. When the glb is not
# imported the NPCs wear the generated body (a few shared body types).
static func genome_of(id: String) -> Dictionary:
	var g: Dictionary = BodyGenerator.genome_from_seed(id.hash())
	g["bust"] = BodyGenerator.BUST_NONE      # NPCs wear Body 1 (dynasty_body.gd); the bust slider drawn at random would give every man a bust now that it shows (20 Nov 2026)
	return g


func _make_rig(id: String) -> Node3D:
	if DynastyBodyScript.available():
		var body: Node3D = DynastyBodyScript.new()
		body.set_proportions(genome_of(id))
		return body

	return GeneratedBodyScript.new(BodyGenerator.genome_from_seed(id.hash() % VARIANTS), 0.045, false, true)


func _make_body(id: String) -> Node3D:
	var info: Dictionary = roster.get(id, {})
	var goblin: Node3D = _make_goblin(id, str(info.get("outfit", "")), str(info.get("name", id)))

	if goblin != null:
		return goblin

	var root: Node3D = Node3D.new()
	var ragdoll: Node3D = _make_rig(id)
	ragdoll.name = "Rig"
	ragdoll.rotation.y = 0.0
	root.add_child(ragdoll)
	var outfit: String = str(info.get("outfit", ""))
	var coat: Color = Color(0.36, 0.3, 0.22) if outfit == "merchant" else (Color(0.3, 0.32, 0.38) if outfit == "guard" else Color(0.4, 0.34, 0.28))
	var trousers: Color = Color(0.22, 0.2, 0.19) if outfit == "guard" else Color(0.27, 0.22, 0.17)
	var h: int = id.hash()
	var shade: float = 1.0 + (float(h & 255) / 255.0 - 0.5) * 0.35
	var skin: Color = Color(0.78, 0.62, 0.5).lerp(Color(0.5, 0.36, 0.28), float((h >> 8) & 255) / 255.0 * 0.6)
	ragdoll.dress(skin, Color(coat.r * shade, coat.g * shade, coat.b * shade), Color(trousers.r * shade, trousers.g * shade, trousers.b * shade))
	WornSync.apply(ragdoll, _worn_of(outfit), false)
	ragdoll.animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	ragdoll.play("idle")
	# The furniture they use goes with them (shown by state): a chair under a sitter, a bed under a sleeper. The markers are on the
	# server; a permanent chair or bed would be a placed structure.
	var chair: Node3D = BuildingLook.chair()
	chair.name = "Chair"
	chair.visible = false
	root.add_child(chair)
	var bed: Node3D = BuildingLook.bed()
	bed.name = "Bed"
	bed.visible = false
	root.add_child(bed)
	var label: Label3D = Label3D.new()
	label.text = str(info.get("name", id))
	label.font_size = 48
	label.pixel_size = 0.008
	label.no_depth_test = false           # Dave, build 612: names showed through the walls of a hole
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 2.05, 0.0)
	label.modulate = Color(1.0, 0.95, 0.8)
	label.outline_size = 8
	root.add_child(label)
	return root


# A goblin tribe member's body (data/creatures/goblin_tribes.json "body" sent as outfit "goblin:<variant>"), the wild goblin's model, with the
# name above its head; null for anyone else, or when the model cannot be made (then the ordinary body stands in).
func _make_goblin(id: String, outfit: String, title: String) -> Node3D:
	if not outfit.begins_with("goblin:") or not goblin_maker.is_valid():
		return null

	var model: Node3D = goblin_maker.call(int(outfit.substr(7)), id.hash()) as Node3D

	if model == null:
		return null

	var root: Node3D = Node3D.new()
	root.set_meta("goblin", true)
	model.name = "Goblin"
	root.add_child(model)
	var spear: Node3D = _goblin_spear(model)

	if spear != null:
		root.set_meta("spear", spear)
	var label: Label3D = Label3D.new()
	label.text = title
	label.font_size = 48
	label.pixel_size = 0.008
	label.no_depth_test = false
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 1.75, 0.0)   # over a goblin's head (0.6-1.6 m tall)
	label.modulate = Color(1.0, 0.95, 0.8)
	label.outline_size = 8
	root.add_child(label)
	return root


# A camp goblin's Wooden spear (Dave 20 Nov 2026: "they should carry spears for weapons"), the same look as the player's, on a bone attachment of
# the model's right hand (Mixamo "RightHand"); null when the model has no such bone or the spear has no look. _hold_spear angles it every frame.
static func _goblin_spear(model: Node3D) -> Node3D:
	var skeletons: Array = model.find_children("*", "Skeleton3D", true, false)

	if skeletons.is_empty():
		return null

	var skel: Skeleton3D = skeletons[0] as Skeleton3D
	var bone: String = ""

	for i in skel.get_bone_count():
		if skel.get_bone_name(i).ends_with("RightHand"):
			bone = skel.get_bone_name(i)
			break

	if bone == "" or not HeldItem.BasicLook.has_look(GOBLIN_SPEAR):
		return null

	var mount: BoneAttachment3D = BoneAttachment3D.new()
	mount.name = "SpearHand"
	mount.bone_name = bone
	skel.add_child(mount)
	var spear: Node3D = HeldItem.look_tool_node(GOBLIN_SPEAR)
	spear.name = "Spear"
	mount.add_child(spear)
	return spear
