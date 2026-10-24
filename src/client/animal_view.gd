extends Node3D

# Animals on the client (protocol 48): a simple low-poly rabbit until Art makes a real one (brown body, head, two ears, white
# tail). The server sends rows about four times a second; the view glides to each, faces the way it goes and hops while moving
# (higher and quicker when it bolts). At most MAX_DRAWN are drawn, the nearest ones (the server already sends only 30 within 120 m).

const MAX_DRAWN := 30
const GRAZE := 0
const HOP := 1
const FLEE := 2

signal state_changed(kind: String, state: int, at: Vector3)     # an animal alerts, flees, warns or charges (sounds listen)
signal stepped(kind: String, at: Vector3)                       # a hoof or paw lands (each whole count of the gait; a rabbit hop lands): the step sounds listen

const KIND_OF_SPECIES := {1: "rabbit", 2: "deer", 3: "wolf", 4: "moose", 5: "fox", 6: "duck", 7: "horse"}
const VOICED_STATES := [2, 3, 10, 11]         # flee, alert, warn, charge

var _bodies: Dictionary = {}     # id -> {node, target Vector3, heading, state, phase}
var _mats: Dictionary = {}
var _t: float = 0.0
var _blood: Array = []           # MeshInstance3D pool, one per drop shown
var _blood_mat: StandardMaterial3D


func on_rows(rows: Array) -> void:
	var seen: Dictionary = {}

	for row in rows:
		var id: int = int(row[0])
		seen[id] = true

		if not _bodies.has(id):
			if _bodies.size() >= MAX_DRAWN:
				continue

			var node: Node3D = _make_flock(id) if int(row[1]) == 6 else _make_horse(id) if int(row[1]) == 7 else _make_fox() if int(row[1]) == 5 else _make_moose(id) if int(row[1]) == 4 else (_make_wolf() if int(row[1]) == 3 else (_make_deer(id) if int(row[1]) == 2 else _make_rabbit()))
			node.position = row[2]
			add_child(node)
			_bodies[id] = {"node": node, "target": row[2], "heading": float(row[3]), "state": int(row[4]), "phase": float(id % 7), "deer": int(row[1]) >= 2, "wolf": int(row[1]) == 3, "quad": node.has_meta("quad"), "kind": KIND_OF_SPECIES.get(int(row[1]), ""), "step_count": -1}

		if int(row[4]) != int(_bodies[id]["state"]) and int(row[4]) in VOICED_STATES and KIND_OF_SPECIES.has(int(row[1])):
			state_changed.emit(KIND_OF_SPECIES[int(row[1])], int(row[4]), row[2])

		_bodies[id]["target"] = row[2]
		_bodies[id]["heading"] = float(row[3])
		_bodies[id]["state"] = int(row[4])

	for id in _bodies.keys():
		if not seen.has(id):
			_bodies[id]["node"].queue_free()
			_bodies.erase(id)


# The blood trail (protocol 55): dark red flat spots on the ground where a wounded animal ran, a pooled MeshInstance3D each,
# size varied by position so the trail does not look stamped.
func on_blood(points: PackedVector3Array) -> void:
	if _blood_mat == null:
		_blood_mat = StandardMaterial3D.new()
		_blood_mat.albedo_color = Color(0.32, 0.03, 0.03)
		_blood_mat.roughness = 0.35   # wet
		_blood_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	while _blood.size() < points.size():
		var spot: MeshInstance3D = MeshInstance3D.new()
		var mesh: CylinderMesh = CylinderMesh.new()
		mesh.top_radius = 0.1
		mesh.bottom_radius = 0.1
		mesh.height = 0.01
		mesh.radial_segments = 8
		mesh.rings = 1
		mesh.material = _blood_mat
		spot.mesh = mesh
		spot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spot)
		_blood.append(spot)

	for i in _blood.size():
		var spot: MeshInstance3D = _blood[i]
		spot.visible = i < points.size()

		if i < points.size():
			spot.position = points[i] + Vector3(0.0, 0.03, 0.0)
			var scale_xz: float = 0.6 + 0.8 * fposmod(points[i].x * 7.31 + points[i].z * 3.17, 1.0)
			spot.scale = Vector3(scale_xz, 1.0, scale_xz * 0.8)


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
	_t += delta

	for id in _bodies:
		var b: Dictionary = _bodies[id]
		var node: Node3D = b["node"]
		var state: int = b["state"]
		var before: Vector3 = node.position
		node.position = node.position.lerp(b["target"], clampf(delta * (10.0 if state == FLEE or state == 11 or state == 14 or state == 15 else 5.0), 0.0, 1.0))
		node.rotation.y = lerp_angle(node.rotation.y, -float(b["heading"]) - PI * 0.5, clampf(delta * 10.0, 0.0, 1.0))
		var rig: Node3D = node.get_node("Rig")
		var rate: float = 9.0 if state == FLEE else 5.0
		var big: bool = bool(b.get("deer", false))
		var lift: float = ((0.06 if big else 0.22) if state == FLEE else (0.02 if big else 0.1)) * absf(sin(_t * (rate * (0.8 if big else 1.0)) + float(b["phase"]))) if state != GRAZE and state != 3 else 0.0
		# Wolf idle (protocol states 8 roll in the grass, 9 play): placeholder motion until Mandy animates it.
		var roll: float = PI * 0.5 if state == 8 else 0.0
		# Big game (protocol states 10 warn: head down and stamping, 11 charge: gallop, 12 recover): placeholder motion until Mandy animates it.
		rig.rotation.x = lerp_angle(rig.rotation.x, 0.28 if state == 10 or state == 13 else (0.12 if state == 11 or state == 15 else 0.0), clampf(delta * 8.0, 0.0, 1.0))
		rig.rotation.z = lerp_angle(rig.rotation.z, roll, clampf(delta * 6.0, 0.0, 1.0))
		if bool(b.get("wolf", false)):
			_animate_wolf(node, b, state, Vector2(node.position.x - before.x, node.position.z - before.z).length() / maxf(delta, 0.001), delta)
		elif bool(b.get("quad", false)):
			_animate_quad(node, b, state, Vector2(node.position.x - before.x, node.position.z - before.z).length() / maxf(delta, 0.001), delta)
		else:
			rig.position.y = lerp(rig.position.y, lift + (0.25 * absf(sin(_t * 7.0 + float(b["phase"]))) if state == 9 else 0.0), clampf(delta * 20.0, 0.0, 1.0))

		_emit_steps(b, node, state, Vector2(node.position.x - before.x, node.position.z - before.z).length() / maxf(delta, 0.001))


# A step lands when the gait (four-legged and wolf) passes a whole number, or a rabbit's hop comes down; none while standing, grazing or a duck flock (no gait yet).
func _emit_steps(b: Dictionary, node: Node3D, state: int, speed: float) -> void:
	var kind: String = str(b.get("kind", ""))

	if kind == "" or kind == "duck" or speed < 0.4:
		return

	var count: int
	if kind == "rabbit":
		if state == GRAZE:
			return

		count = int(floor((_t * (9.0 if state == FLEE else 5.0) + float(b["phase"])) / PI))
	else:
		count = int(floor(float(b.get("gait", 0.0))))

	if int(b["step_count"]) >= 0 and count != int(b["step_count"]):
		stepped.emit(kind, node.global_position)

	b["step_count"] = count


func _material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()

	if not _mats.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		_mats[key] = m

	return _mats[key]


func _ball(parent: Node3D, radius: float, scale_v: Vector3, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8 if radius >= 0.05 else 5      # tiny balls (eyes, nostrils, tail tips) need few facets
	mesh.rings = 4 if radius >= 0.05 else 2
	mesh.material = _material(color)
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.scale = scale_v
	inst.position = at
	inst.rotation = rot
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


# Facing -Z (the heading turns the root). About 0.45 m long, 0.3 m to the ear tips.
func _make_rabbit() -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var fur: Color = Color(0.45, 0.36, 0.26)
	_ball(rig, 0.1, Vector3(1.0, 0.9, 1.6), Vector3(0.0, 0.11, 0.02), fur)
	_ball(rig, 0.065, Vector3(1.0, 1.0, 1.2), Vector3(0.0, 0.19, -0.15), fur)

	for side in [-1.0, 1.0]:
		var ear: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.025, 0.11, 0.012)
		box.material = _material(Color(0.5, 0.4, 0.3))
		ear.mesh = box
		ear.position = Vector3(side * 0.025, 0.28, -0.13)
		ear.rotation = Vector3(0.25, 0.0, side * 0.15)
		ear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(ear)

	_ball(rig, 0.035, Vector3.ONE, Vector3(0.0, 0.15, 0.19), Color(0.92, 0.9, 0.86))
	return root


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.rotation = rot
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


# The wolf (Dave 2026-10-21): about 1.3 m of body and 0.8 m at the shoulder, grey with a pale belly and muzzle, a deep chest, a thick neck, a
# long snout, upright ears, a bushy tail and four legs on pivots so they can walk, trot, run and kick. Facing -Z. The pieces are named for
# `_animate_wolf`: Rig (everything that rolls and crouches), Head, Tail, Leg_FL, Leg_FR, Leg_HL, Leg_HR.
func _make_wolf() -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var coat: Color = Color(0.36, 0.35, 0.33)
	var dark: Color = Color(0.24, 0.23, 0.22)
	var pale: Color = Color(0.72, 0.69, 0.63)
	_ball(rig, 0.2, Vector3(0.95, 1.05, 1.5), Vector3(0.0, 0.62, -0.18), coat)      # chest and shoulders, deep
	_ball(rig, 0.17, Vector3(0.9, 0.95, 1.5), Vector3(0.0, 0.6, 0.28), coat)        # hips
	_ball(rig, 0.15, Vector3(0.85, 0.7, 1.7), Vector3(0.0, 0.5, 0.05), pale)        # belly
	_ball(rig, 0.17, Vector3(0.9, 0.8, 1.0), Vector3(0.0, 0.74, -0.36), dark)       # mane over the shoulders
	var neck: Node3D = Node3D.new()
	neck.name = "Head"
	neck.position = Vector3(0.0, 0.66, -0.42)
	rig.add_child(neck)
	_ball(neck, 0.12, Vector3(0.85, 0.85, 1.5), Vector3(0.0, 0.04, -0.12), coat)     # neck
	_ball(neck, 0.11, Vector3(0.9, 0.85, 1.0), Vector3(0.0, 0.06, -0.3), coat)       # head
	_box(neck, Vector3(0.09, 0.075, 0.2), Vector3(0.0, 0.03, -0.43), pale)          # snout
	_box(neck, Vector3(0.05, 0.03, 0.05), Vector3(0.0, 0.07, -0.54), Color(0.08, 0.07, 0.07))   # nose

	for side in [-1.0, 1.0]:
		_box(neck, Vector3(0.05, 0.1, 0.035), Vector3(side * 0.06, 0.2, -0.28), dark, Vector3(-0.15, 0.0, side * 0.15))   # ears
		_ball(neck, 0.018, Vector3.ONE, Vector3(side * 0.055, 0.09, -0.4), Color(0.9, 0.7, 0.2))                        # eyes

	var tail: Node3D = Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.0, 0.66, 0.42)
	rig.add_child(tail)
	_ball(tail, 0.08, Vector3(0.8, 0.8, 2.6), Vector3(0.0, -0.08, 0.2), coat, Vector3(0.7, 0.0, 0.0))
	_ball(tail, 0.05, Vector3(0.8, 0.8, 1.6), Vector3(0.0, -0.2, 0.36), dark, Vector3(0.7, 0.0, 0.0))

	for leg in [["Leg_FL", -1.0, -0.26], ["Leg_FR", 1.0, -0.26], ["Leg_HL", -1.0, 0.3], ["Leg_HR", 1.0, 0.3]]:
		var pivot: Node3D = Node3D.new()
		pivot.name = leg[0]
		pivot.position = Vector3(float(leg[1]) * 0.1, 0.5, float(leg[2]))
		rig.add_child(pivot)
		_box(pivot, Vector3(0.09, 0.28, 0.1), Vector3(0.0, -0.13, 0.0), coat)       # upper leg
		_box(pivot, Vector3(0.06, 0.26, 0.07), Vector3(0.0, -0.36, 0.0), dark)      # lower leg
		_box(pivot, Vector3(0.075, 0.04, 0.12), Vector3(0.0, -0.49, -0.02), dark)   # paw

	return root


# The wolf's legs, head and tail follow what it does: legs swing with the real ground speed (walk, trot, gallop), the head sinks to sniff or
# stalk, the tail wags at play and hangs low when stalking, a roll kicks the legs up. `speed` is metres a second.
func _animate_wolf(node: Node3D, b: Dictionary, state: int, speed: float, delta: float) -> void:
	var rig: Node3D = node.get_node("Rig")
	var head: Node3D = rig.get_node("Head")
	var tail: Node3D = rig.get_node("Tail")
	var gallop: float = clampf((speed - 2.5) / 3.5, 0.0, 1.0)
	b["gait"] = float(b.get("gait", 0.0)) + speed * delta * lerpf(2.6, 1.8, gallop)
	var amp: float = clampf(speed / 1.8, 0.0, 1.0) * lerpf(0.5, 0.95, gallop)
	var swing: float = sin(float(b["gait"]) * TAU * 0.5)
	var rolling: bool = state == 8
	var kick: float = sin(_t * 9.0) * 0.6 if rolling else 0.0
	var legs: Dictionary = {"Leg_FL": swing, "Leg_HR": swing, "Leg_FR": -swing, "Leg_HL": -swing}

	if gallop > 0.5:
		legs = {"Leg_FL": swing, "Leg_FR": swing * 0.9, "Leg_HL": -swing, "Leg_HR": -swing * 0.9}      # bounding: the pairs move together

	for leg in legs:
		var pivot: Node3D = rig.get_node(leg)
		var target: float = float(legs[leg]) * amp + (kick * (1.0 if leg.ends_with("L") else -1.0) + 1.2 if rolling else 0.0)
		pivot.rotation.x = lerpf(pivot.rotation.x, target, clampf(delta * 18.0, 0.0, 1.0))

	var head_down: float = 0.0

	if state == 6:
		head_down = 0.55          # stalking: head low, eyes on the prey
	elif state == 0 and speed < 0.3:
		head_down = 0.35 + 0.15 * sin(_t * 1.3 + float(b["phase"]))      # grazing wolf: nose to the ground, sniffing
	elif state == 3:
		head_down = -0.25         # alert: head high
	elif state == 7 or gallop > 0.5:
		head_down = 0.1

	head.rotation.x = lerpf(head.rotation.x, -(head_down + 0.04 * swing * amp), clampf(delta * 8.0, 0.0, 1.0))
	var tail_target: float = 0.2
	var tail_wag: float = 0.0

	if state == 6:
		tail_target = -0.2        # low and straight
	elif state == 9:
		tail_target = 0.5
		tail_wag = sin(_t * 12.0) * 0.5
	elif gallop > 0.5:
		tail_target = -0.35       # streaming behind

	tail.rotation.x = lerpf(tail.rotation.x, tail_target, clampf(delta * 6.0, 0.0, 1.0))
	tail.rotation.y = lerpf(tail.rotation.y, tail_wag, clampf(delta * 10.0, 0.0, 1.0))
	# Crouch low when stalking, bob with the stride, play bow (front down, hips up) when playing.
	var crouch: float = -0.12 if state == 6 else 0.0
	var bob: float = absf(sin(float(b["gait"]) * TAU * 0.5)) * 0.04 * amp
	rig.position.y = lerpf(rig.position.y, crouch + bob + (0.06 if state == 9 else 0.0), clampf(delta * 10.0, 0.0, 1.0))


# A flock of ducks for now (placeholder until Art): 6 to 13 small birds spread over a few metres (one wire record per flock).
# State 3 heads up, 15 in the air (the whole flock rises and leans forward).
func _make_flock(id: int) -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = id * 7919

	for k in 6 + id % 8:
		var at: Vector3 = Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(-3.0, 3.0))
		var drake: bool = k % 2 == 0      # drakes: green head, white neck ring, grey flanks; hens: plain mottled brown
		_ball(rig, 0.16, Vector3(0.8, 0.7, 1.4), at + Vector3(0.0, 0.1, 0.0), Color(0.5, 0.5, 0.52) if drake else Color(0.45, 0.36, 0.26))
		_ball(rig, 0.055, Vector3(0.9, 1.4, 0.9), at + Vector3(0.0, 0.24, -0.16), Color(0.92, 0.9, 0.86) if drake else Color(0.45, 0.36, 0.26))   # neck
		_ball(rig, 0.07, Vector3.ONE, at + Vector3(0.0, 0.32, -0.2), Color(0.12, 0.34, 0.2) if drake else Color(0.4, 0.31, 0.22))
		_box(rig, Vector3(0.05, 0.02, 0.09), at + Vector3(0.0, 0.31, -0.29), Color(0.9, 0.68, 0.15))                            # bill

	return root


# Fox, horse and moose share one four-legged build (Mandy 2026-10-22). `spec` sizes it: leg_h (hip height), rb (body radius), len (shoulder to
# hip), neck, head (head length), coat, dark, pale, plus flags hump, mane, antlers, bushy, snout. Facing -Z. Pieces named for `_animate_quad`: Rig,
# Head (neck and head), Ear_L, Ear_R, Tail, Leg_FL, Leg_FR, Leg_HL, Leg_HR.
func _make_quad(spec: Dictionary) -> Node3D:
	var root: Node3D = Node3D.new()
	root.set_meta("quad", true)
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var leg_h: float = float(spec["leg_h"])
	var rb: float = float(spec["rb"])
	var half: float = float(spec["len"]) * 0.5
	var nk: float = float(spec["neck"])
	var hd: float = float(spec["head"])
	var coat: Color = spec["coat"]
	var dark: Color = spec["dark"]
	var pale: Color = spec["pale"]
	var back: float = leg_h + rb * 0.8
	rig.set_meta("leg_h", leg_h)
	_ball(rig, rb, Vector3(0.85, 1.0, 1.5), Vector3(0.0, leg_h + rb * 0.35, -half * 0.45), coat)       # chest
	_ball(rig, rb * 0.95, Vector3(0.85, 0.95, 1.5), Vector3(0.0, leg_h + rb * 0.3, half * 0.5), coat)  # hips
	_ball(rig, rb * 0.8, Vector3(0.8, 0.8, 2.2), Vector3(0.0, leg_h + rb * 0.15, 0.0), pale if bool(spec.get("pale_belly", true)) else coat)   # belly

	if bool(spec.get("hump", false)):
		_ball(rig, rb * 0.7, Vector3(0.8, 0.9, 1.3), Vector3(0.0, back + rb * 0.35, -half * 0.55), dark)   # shoulder hump

	var head: Node3D = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, back - rb * 0.1, -half * 0.8)
	rig.add_child(head)
	_ball(head, nk * 0.22, Vector3(0.8, 0.8, 1.0), Vector3(0.0, nk * 0.3, -nk * 0.3), coat, Vector3(0.7, 0.0, 0.0))      # neck (long)
	_ball(head, nk * 0.2, Vector3(0.75, 0.75, 1.3), Vector3(0.0, nk * 0.55, -nk * 0.55), coat, Vector3(0.7, 0.0, 0.0))
	var top: Vector3 = Vector3(0.0, nk * 0.78, -nk * 0.85)
	_ball(head, hd * 0.28, Vector3(0.85, 0.9, 1.4), top, coat if not bool(spec.get("dark_head", false)) else dark)       # skull
	var snout: float = float(spec.get("snout", 1.0))
	_box(head, Vector3(hd * 0.34, hd * 0.3, hd * 0.55 * snout), top + Vector3(0.0, -hd * 0.08, -hd * 0.45 * snout), pale if bool(spec.get("pale_snout", false)) else dark)
	_ball(head, hd * 0.05, Vector3.ONE, top + Vector3(0.1 * hd, hd * 0.12, -hd * 0.18), Color(0.05, 0.04, 0.04))        # eyes
	_ball(head, hd * 0.05, Vector3.ONE, top + Vector3(-0.1 * hd, hd * 0.12, -hd * 0.18), Color(0.05, 0.04, 0.04))

	for side in [-1.0, 1.0]:
		var ear: Node3D = Node3D.new()
		ear.name = "Ear_L" if side < 0.0 else "Ear_R"
		ear.position = top + Vector3(side * hd * 0.2, hd * 0.2, hd * 0.1)
		head.add_child(ear)
		_box(ear, Vector3(hd * 0.1, hd * 0.32, hd * 0.06), Vector3(0.0, hd * 0.16, 0.0), dark, Vector3(0.0, 0.0, side * -0.35))

		if bool(spec.get("antlers", false)):
			# Bull moose: broad flat palms swept out and up from above the ears, with tines along the rim.
			_box(head, Vector3(hd * 1.1, hd * 0.05, hd * 0.55), top + Vector3(side * hd * 0.75, hd * 0.4, 0.0), Color(0.72, 0.66, 0.54), Vector3(0.0, side * 0.3, side * -0.25))

			for tine in 4:
				_box(head, Vector3(hd * 0.05, hd * 0.05, hd * 0.3), top + Vector3(side * hd * (0.7 + 0.2 * float(tine)), hd * 0.48, -hd * 0.3 + hd * 0.2 * float(tine)), Color(0.72, 0.66, 0.54), Vector3(0.0, side * 0.2, 0.0))

	if bool(spec.get("mane", false)):
		_box(head, Vector3(hd * 0.06, nk * 0.6, hd * 0.25), Vector3(0.0, nk * 0.55, -nk * 0.4), dark, Vector3(0.7, 0.0, 0.0))

	# Goal 2 batch A details, all children of existing nodes (names and animation unchanged): nostrils, then per species marks.
	_ball(head, hd * 0.045, Vector3(1.0, 0.7, 0.7), top + Vector3(hd * 0.08, -hd * 0.1, -hd * 0.45 * snout - hd * 0.28 * snout), Color(0.04, 0.03, 0.03))
	_ball(head, hd * 0.045, Vector3(1.0, 0.7, 0.7), top + Vector3(-hd * 0.08, -hd * 0.1, -hd * 0.45 * snout - hd * 0.28 * snout), Color(0.04, 0.03, 0.03))

	if bool(spec.get("blaze", false)):
		_box(head, Vector3(hd * 0.1, hd * 0.05, hd * 0.8), top + Vector3(0.0, hd * 0.14, -hd * 0.3), pale, Vector3(-0.15, 0.0, 0.0))      # a white stripe down the face

	if bool(spec.get("bell", false)):
		_ball(head, hd * 0.12, Vector3(0.6, 1.8, 0.6), top + Vector3(0.0, -hd * 0.55, hd * 0.12), dark)      # the moose's dangling bell under the throat

	if bool(spec.get("tines", false)):
		# A deer's antlers: a main beam sweeping up and back from each side with three tines.
		for side in [-1.0, 1.0]:
			var beam: Vector3 = top + Vector3(side * hd * 0.22, hd * 0.3, hd * 0.12)
			_box(head, Vector3(hd * 0.05, hd * 0.9, hd * 0.05), beam + Vector3(side * hd * 0.1, hd * 0.4, hd * 0.2), Color(0.76, 0.7, 0.58), Vector3(0.45, 0.0, side * -0.25))

			for tine in 3:
				_box(head, Vector3(hd * 0.035, hd * 0.3, hd * 0.035), beam + Vector3(side * hd * (0.12 + 0.05 * float(tine)), hd * (0.25 + 0.22 * float(tine)), hd * (0.12 + 0.08 * float(tine))), Color(0.76, 0.7, 0.58), Vector3(-0.3, 0.0, side * 0.5))

	if bool(spec.get("rump", false)):
		_ball(rig, rb * 0.6, Vector3(0.8, 0.9, 0.5), Vector3(0.0, leg_h + rb * 0.4, half * 0.5 + rb * 0.8), pale)      # the pale rump patch

	var tail: Node3D = Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0.0, leg_h + rb * 0.7, half * 0.9)
	rig.add_child(tail)

	if bool(spec.get("bushy", false)):
		_ball(tail, rb * 1.1, Vector3(0.8, 0.8, 2.6), Vector3(0.0, -rb * 0.2, rb * 1.4), coat, Vector3(0.5, 0.0, 0.0))
		_ball(tail, rb * 0.7, Vector3(0.8, 0.8, 1.4), Vector3(0.0, -rb * 0.7, rb * 2.8), Color(0.92, 0.9, 0.86), Vector3(0.5, 0.0, 0.0))
	elif bool(spec.get("long_tail", false)):
		_box(tail, Vector3(rb * 0.3, leg_h * 0.95, rb * 0.2), Vector3(0.0, -leg_h * 0.45, rb * 0.2), dark, Vector3(0.12, 0.0, 0.0))      # a horse's tail hangs nearly to the hocks
		_box(tail, Vector3(rb * 0.2, leg_h * 0.5, rb * 0.15), Vector3(rb * 0.12, -leg_h * 0.62, rb * 0.28), dark, Vector3(0.18, 0.0, 0.1))
	else:
		_box(tail, Vector3(rb * 0.12, leg_h * 0.5, rb * 0.12), Vector3(0.0, -leg_h * 0.22, rb * 0.1), dark, Vector3(0.1, 0.0, 0.0))

	for leg in [["Leg_FL", -1.0, -half * 0.8], ["Leg_FR", 1.0, -half * 0.8], ["Leg_HL", -1.0, half * 0.8], ["Leg_HR", 1.0, half * 0.8]]:
		var pivot: Node3D = Node3D.new()
		pivot.name = leg[0]
		pivot.position = Vector3(float(leg[1]) * rb * 0.55, leg_h, float(leg[2]))
		rig.add_child(pivot)
		var w: float = rb * 0.3
		_box(pivot, Vector3(w, leg_h * 0.5, w), Vector3(0.0, -leg_h * 0.24, 0.0), coat)
		_box(pivot, Vector3(w * 0.7, leg_h * 0.5, w * 0.7), Vector3(0.0, -leg_h * 0.74, 0.0), dark if not bool(spec.get("socks", false)) else pale)
		_box(pivot, Vector3(w * 0.9, leg_h * 0.06, w * 1.2), Vector3(0.0, -leg_h * 0.98, -w * 0.1), Color(0.12, 0.1, 0.09))      # hoof

	return root


# Legs swing with the real ground speed; the head sinks to graze, lifts to watch, lowers to warn; ears go forward when alert and flat when
# warning; the front hoof stamps at a warn (10, the moose telegraph: head low, ears flat, one fore hoof pawing, unmistakable); a charge (11)
# gallops with the head low; a recover (12) stands blowing, the chest heaving. `speed` is metres a second.
func _animate_quad(node: Node3D, b: Dictionary, state: int, speed: float, delta: float) -> void:
	var rig: Node3D = node.get_node("Rig")
	var head: Node3D = rig.get_node("Head")
	var tail: Node3D = rig.get_node("Tail")
	var leg_h: float = float(rig.get_meta("leg_h"))
	var gallop: float = clampf((speed - 3.0) / 4.0, 0.0, 1.0)
	b["gait"] = float(b.get("gait", 0.0)) + speed * delta / (leg_h * lerpf(1.8, 1.3, gallop))
	var amp: float = clampf(speed / 1.2, 0.0, 1.0) * lerpf(0.45, 0.85, gallop)
	var swing: float = sin(float(b["gait"]) * TAU * 0.5)
	var legs: Dictionary = {"Leg_FL": swing, "Leg_HR": swing, "Leg_FR": -swing, "Leg_HL": -swing}

	if gallop > 0.5:
		legs = {"Leg_FL": swing, "Leg_FR": swing * 0.9, "Leg_HL": -swing, "Leg_HR": -swing * 0.9}

	for leg in legs:
		var pivot: Node3D = rig.get_node(leg)
		var target: float = float(legs[leg]) * amp

		if state == 10 and leg == "Leg_FR":
			target = -0.9 + 0.9 * maxf(0.0, sin(_t * 9.0))      # paws and stamps the ground
		elif state == 10 and leg == "Leg_FL":
			target = -0.2 * maxf(0.0, sin(_t * 9.0 + 3.1))

		pivot.rotation.x = lerpf(pivot.rotation.x, target, clampf(delta * 18.0, 0.0, 1.0))

	var head_down: float = 0.0

	if state == 0 and speed < 0.3:
		head_down = 0.9 + 0.08 * sin(_t * 0.9 + float(b["phase"]))      # grazing
	elif state == 3:
		head_down = -0.35
	elif state == 10:
		head_down = 0.75 + 0.1 * sin(_t * 9.0)
	elif state == 11 or gallop > 0.5:
		head_down = 0.45
	elif state == 12:
		head_down = 0.2 + 0.1 * sin(_t * 3.5)

	head.rotation.x = lerpf(head.rotation.x, -(head_down + 0.05 * swing * amp), clampf(delta * 8.0, 0.0, 1.0))
	var ear_back: float = 1.2 if state == 10 or state == 11 else (-0.3 if state == 3 else 0.2 * sin(_t * 0.7 + float(b["phase"]) * 9.0) * (1.0 if state == 0 else 0.0))

	for ear_name in ["Ear_L", "Ear_R"]:
		var ear: Node3D = head.get_node(ear_name)
		ear.rotation.x = lerpf(ear.rotation.x, ear_back, clampf(delta * 12.0, 0.0, 1.0))

	var tail_target: float = -0.4 if gallop > 0.5 else (0.15 + 0.1 * sin(_t * 2.0 + float(b["phase"])))
	tail.rotation.x = lerpf(tail.rotation.x, tail_target, clampf(delta * 6.0, 0.0, 1.0))
	var bob: float = absf(swing) * leg_h * 0.04 * amp
	var heave: float = 0.012 * sin(_t * 7.0) * leg_h if state == 12 else 0.0
	rig.position.y = lerpf(rig.position.y, bob + heave, clampf(delta * 10.0, 0.0, 1.0))


# A fox (Mandy 2026-10-22): small, rusty red, pale belly and muzzle, dark socks, big bushy white-tipped brush. State 13 creeps low, 14 runs with food.
func _make_fox() -> Node3D:
	return _make_quad({"leg_h": 0.22, "rb": 0.1, "len": 0.5, "neck": 0.16, "head": 0.2, "snout": 1.3, "coat": Color(0.72, 0.34, 0.12), "dark": Color(0.2, 0.12, 0.08), "pale": Color(0.93, 0.88, 0.8), "pale_snout": true, "bushy": true})


# A horse (Mandy 2026-10-22): coat chosen from the animal id (bay, chestnut, grey, black, dun), dark mane and tail. Foals and harness come later.
func _make_horse(id: int) -> Node3D:
	var coats: Array = [[Color(0.36, 0.2, 0.11), Color(0.08, 0.06, 0.05)], [Color(0.5, 0.26, 0.12), Color(0.34, 0.17, 0.08)], [Color(0.66, 0.66, 0.64), Color(0.45, 0.45, 0.44)], [Color(0.1, 0.09, 0.09), Color(0.05, 0.04, 0.04)], [Color(0.62, 0.5, 0.32), Color(0.2, 0.14, 0.09)]]
	var pick: Array = coats[id % coats.size()]
	return _make_quad({"leg_h": 0.85, "rb": 0.32, "len": 1.05, "neck": 0.75, "head": 0.55, "snout": 1.2, "coat": pick[0], "dark": pick[1], "pale": pick[0].lerp(Color(0.9, 0.85, 0.78), 0.25), "mane": true, "socks": false, "long_tail": true, "blaze": id % 3 == 0})


# A moose (Mandy 2026-10-22): about 2.7 m long, 2.1 m at the shoulder hump, dark brown, long pale legs, big drooping muzzle; every second one is a bull with broad antlers.
func _make_moose(id: int) -> Node3D:
	return _make_quad({"leg_h": 1.15, "rb": 0.5, "len": 1.4, "neck": 0.8, "head": 0.65, "snout": 1.2, "coat": Color(0.2, 0.14, 0.1), "dark": Color(0.12, 0.09, 0.07), "pale": Color(0.4, 0.33, 0.27), "hump": true, "socks": true, "antlers": id % 2 == 0, "pale_belly": false, "bell": true})


# A deer (goal 2 batch A, Kathleen): the shared four-legged build, so it walks, grazes and watches like the others. About 1.5 m long, 1.2 m to the back, tan coat, pale belly and rump,
# a stag's branched antlers on every second one (by id).
func _make_deer(id: int = 0) -> Node3D:
	return _make_quad({"leg_h": 0.62, "rb": 0.22, "len": 1.05, "neck": 0.5, "head": 0.32, "snout": 1.1, "coat": Color(0.52, 0.38, 0.24), "dark": Color(0.32, 0.23, 0.15), "pale": Color(0.9, 0.85, 0.77), "rump": true, "tines": id % 2 == 0, "socks": false})
