extends Node3D

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
const RagdollScript := preload("res://src/client/ragdoll_body.gd")
const GeneratedBodyScript := preload("res://src/client/character/generated_body.gd")
const BodyGenerator := preload("res://src/client/character/body_generator.gd")
const VARIANTS := 8                  # with --generated-body: this many body types, built once each and shared (see _make_body)
const BuildingLook := preload("res://src/client/building_look.gd")
const WornSync := preload("res://src/client/worn_sync.gd")
const OUTFITS_PATH := "res://data/npcs/outfits.json"
const FULL_M := 15.0
const HALF_M := 40.0
const QUARTER_M := 70.0

var roster: Dictionary = {}      # id -> {name, role, outfit}
var _outfits: Dictionary = {}    # outfit name -> item ids worn on top of the ragdoll (data/npcs/outfits.json)
var _bodies: Dictionary = {}     # id -> {node, target Vector3, heading, state}


func _ready() -> void:
	# --generated-body: start building the body types on worker threads now, so no NPC waits for its mesh when it first appears.
	if OS.get_cmdline_user_args().has("--generated-body"):
		for variant in range(VARIANTS):
			BodyGenerator.prewarm(BodyGenerator.genome_from_seed(variant), 0.045, false)


func on_roster(rows: Array) -> void:
	roster.clear()

	for row in rows:
		roster[str(row[0])] = {"name": str(row[1]), "role": str(row[2]), "outfit": str(row[3])}


func on_rows(rows: Array) -> void:
	var seen: Dictionary = {}

	for row in rows:
		var id: String = str(row[0])
		seen[id] = true

		if not _bodies.has(id):
			if _bodies.size() >= MAX_DRAWN:
				continue

			var node: Node3D = _make_body(id)
			node.position = row[1]
			add_child(node)
			_bodies[id] = {"node": node, "target": row[1], "heading": float(row[2]), "state": int(row[3])}

		_bodies[id]["target"] = row[1]
		_bodies[id]["heading"] = float(row[2])
		_bodies[id]["state"] = int(row[3])

	for id in _bodies.keys():
		if not seen.has(id):
			_bodies[id]["node"].queue_free()
			_bodies.erase(id)


# The nearest NPC within reach of a point: {"id", "name"} or {} (for the Press E to talk prompt).
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
	var camera: Camera3D = get_viewport().get_camera_3d()
	var eye: Vector3 = camera.global_position if camera != null else Vector3.ZERO
	var frame: int = Engine.get_process_frames()

	for id in _bodies:
		var body: Dictionary = _bodies[id]
		var node: Node3D = body["node"]
		var state: int = body["state"]
		var before: Vector3 = node.position
		node.position = node.position.lerp(body["target"], clampf(delta * 6.0, 0.0, 1.0))
		node.rotation.y = lerp_angle(node.rotation.y, -float(body["heading"]) - PI * 0.5, clampf(delta * 8.0, 0.0, 1.0))
		var ragdoll: Node3D = node.get_node("Rig")
		node.get_node("Chair").visible = state == SIT
		node.get_node("Bed").visible = state == SLEEP
		var pace: float = lerpf(float(body.get("pace", 0.0)), Vector2(node.position.x - before.x, node.position.z - before.z).length() / maxf(delta, 0.001), clampf(delta * 5.0, 0.0, 1.0))
		body["pace"] = pace
		var clip: String = "lie" if state == SLEEP else ("sit" if state == SIT else "idle")

		if state == WALK or (state == STAND and pace > 0.5):
			clip = "run" if pace > 5.0 else ("jog" if pace > 2.2 else ("walk" if pace > 0.4 else "idle"))

		if ragdoll.current() != clip and not ragdoll.is_one_shot_playing():
			ragdoll.play(clip, 1.0, 0.25)

		ragdoll.position.y = lerpf(ragdoll.position.y, 0.25 if state == SLEEP else 0.0, clampf(delta * 4.0, 0.0, 1.0))   # lying on the bed, not the floor
		var player: AnimationPlayer = ragdoll.animation_player
		player.speed_scale = clampf(pace / 1.4, 0.5, 1.7) if clip == "walk" else (clampf(pace / 3.2, 0.8, 1.6) if clip == "jog" else (clampf(pace / 6.0, 0.8, 2.0) if clip == "run" else 1.0))
		var distance: float = eye.distance_to(node.global_position)
		body["far_t"] = float(body.get("far_t", randf())) - delta

		if float(body["far_t"]) <= 0.0:
			# One look a second: dress the body for its distance (far bodies skip the detail parts; a few metres of hysteresis).
			body["far_t"] = 1.0
			var far: bool = WornSync.far_after(distance, bool(body.get("far", false)))
			body["far"] = far
			WornSync.apply(ragdoll, _worn_of(str(roster.get(id, {}).get("outfit", ""))), far)

		var every: int = 1 if distance <= FULL_M else (2 if distance <= HALF_M else (4 if distance <= QUARTER_M else 0))
		body["owed"] = float(body.get("owed", 0.0)) + delta

		if every > 0 and (frame + int(id.hash() & 3)) % every == 0:
			player.advance(float(body["owed"]))
			body["owed"] = 0.0
		elif every == 0:
			body["owed"] = 0.0


# The worn items of an outfit name (data/npcs/outfits.json), read once.
func _worn_of(outfit: String) -> Array:
	if _outfits.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(OUTFITS_PATH))
		_outfits = parsed if typeof(parsed) == TYPE_DICTIONARY else {"": []}

	return WornSync.known_ids(_outfits.get(outfit, []))


func _make_body(id: String) -> Node3D:
	var info: Dictionary = roster.get(id, {})
	var root: Node3D = Node3D.new()
	# --generated-body (off by default, untested in the running game): generated bodies, a few shared body types without fingers at 4.5 cm detail.
	var ragdoll: Node3D = GeneratedBodyScript.new(BodyGenerator.genome_from_seed(id.hash() % VARIANTS), 0.045, false, true) if OS.get_cmdline_user_args().has("--generated-body") else RagdollScript.new()
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
