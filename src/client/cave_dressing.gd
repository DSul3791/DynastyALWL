extends Node3D

# Cave dressing (Dave 4 Nov 2026: bone piles at cave entrances and far ends, animal and human; stalagmites and stalactites in big caves). The bake puts
# them in each spring cave (Sonny); the server sends a tile's lists with its cave dens and the client draws them here, one MultiMesh per look per tile.
#   bones:      per entry x, y, z (the pile's floor point), kind (0 animal, 1 human), yaw (radians)
#   formations: per entry x, y, z, kind (0 stalagmite: the point is its foot on the floor; 1 stalactite: its root on the roof, hanging down), height m, radius m
# A stalagmite 0.25 m or more in radius is solid (a cylinder collider on the ground layer), so a player walks round it; stalactites hang out of reach.
# Looks (Art_Direction: believable material, age and wear, a little storybook charm): aged bone in warm ivory with darker stains; wet pale limestone with
# drip rings and a darker, wet tip.

const BasicLook := preload("res://src/client/basic_look.gd")

const BONE := Color(0.82, 0.76, 0.62)
const STONE := Color(0.72, 0.68, 0.6)
const SOLID_RADIUS_M := 0.25
const BONE_FIELDS := 5
const FORMATION_FIELDS := 6

var _flicker: Array = []                # [light, base energy, phase] per goblin den fire, so the light dances
static var _meshes: Dictionary = {}     # look name -> ArrayMesh, made once
var _tiles: Dictionary = {}             # tile -> Node3D holding that tile's dressing


func _process(_delta: float) -> void:
	if _flicker.is_empty():
		return

	var now: float = float(Time.get_ticks_msec()) / 1000.0
	var live: Array = []

	for entry in _flicker:
		var glow: OmniLight3D = entry[0] if is_instance_valid(entry[0]) else null

		if glow == null:
			continue

		var phase: float = float(entry[2])
		glow.light_energy = float(entry[1]) * (0.9 + 0.12 * sin(now * 11.0 + phase) + 0.07 * sin(now * 23.0 + phase * 2.0) + 0.05 * sin(now * 41.0 + phase * 3.0))
		live.append(entry)

	_flicker = live


# The flame's material: lit by itself (emission), colour from the flame tongues' own vertex colours, so the core reads yellow-white and the edges orange.
static func flame_material() -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color(1.0, 0.5, 0.12)
	m.emission_energy_multiplier = 2.0
	return m


# The tile's dressing, replacing what it had (empty lists take it away).
func set_tile(tile: Vector2i, bones: PackedFloat32Array, formations: PackedFloat32Array) -> void:
	var old: Node3D = _tiles.get(tile)

	if old != null:
		old.queue_free()
		_tiles.erase(tile)

	if bones.size() < BONE_FIELDS and formations.size() < FORMATION_FIELDS:
		return

	var holder: Node3D = Node3D.new()
	holder.name = "Tile_%d_%d" % [tile.x, tile.y]
	var rows: Dictionary = {"bones_animal": [], "bones_human": [], "goblin_litter": [], "goblin_fire": [], "goblin_flame": [], "stalagmite": [], "stalactite": []}

	for n in range(0, bones.size() - BONE_FIELDS + 1, BONE_FIELDS):
		var spin: Basis = Basis(Vector3.UP, bones[n + 4])
		var kind: int = int(bones[n + 3])      # 0 animal bones, 1 human bones, 2 goblin den litter, 3 goblin den fire (Dave 7 Nov 2026)
		rows[["bones_animal", "bones_human", "goblin_litter", "goblin_fire"][clampi(kind, 0, 3)]].append(Transform3D(spin, Vector3(bones[n], bones[n + 1], bones[n + 2])))

	for n in range(0, formations.size() - FORMATION_FIELDS + 1, FORMATION_FIELDS):
		var at: Vector3 = Vector3(formations[n], formations[n + 1], formations[n + 2])
		var hanging: bool = int(formations[n + 3]) == 1
		var tall: float = maxf(formations[n + 4], 0.1)
		var wide: float = maxf(formations[n + 5], 0.02)
		# The unit look is 1 m tall and 1 m across its base; a turn of the pole by its own place so no two stand alike.
		var spin: Basis = Basis(Vector3.UP, fposmod(at.x * 1.37 + at.z * 2.11, TAU))
		var form: Basis = spin * Basis.from_scale(Vector3(wide * 2.0, tall, wide * 2.0))
		rows["stalactite" if hanging else "stalagmite"].append(Transform3D(form, at))

		if not hanging and wide >= SOLID_RADIUS_M:
			holder.add_child(_solid(at, tall, wide))

	# A goblin den's fire gives light (a cave is pitch black otherwise, so its litter and stone ring were not seen): one warm omni light per fire,
	# faded out with distance so far dens cost nothing.
	for fire in rows["goblin_fire"]:
		rows["goblin_flame"].append(fire)      # the flame is its own look (a glowing material), at the same spot
		var glow: OmniLight3D = OmniLight3D.new()
		glow.name = "GoblinFireLight"
		glow.light_color = Color(1.0, 0.6, 0.25)
		glow.light_energy = 1.6
		glow.omni_range = 7.0
		glow.shadow_enabled = false
		glow.distance_fade_enabled = true
		glow.distance_fade_begin = 50.0
		glow.distance_fade_length = 20.0
		glow.position = (fire as Transform3D).origin + Vector3(0.0, 0.35, 0.0)
		holder.add_child(glow)
		_flicker.append([glow, 1.6, fposmod((fire as Transform3D).origin.x * 0.73 + (fire as Transform3D).origin.z * 1.31, TAU)])

	if not (rows["goblin_fire"] as Array).is_empty() or not (rows["goblin_litter"] as Array).is_empty():
		print("Cave dressing: tile %s has %d goblin den fires and %d litter piles" % [str(tile), (rows["goblin_fire"] as Array).size(), (rows["goblin_litter"] as Array).size()])

	for look in rows:
		if (rows[look] as Array).is_empty():
			continue

		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = look_mesh(look)
		multi.instance_count = (rows[look] as Array).size()

		for k in range(multi.instance_count):
			multi.set_instance_transform(k, rows[look][k])

		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.name = look
		node.multimesh = multi
		node.visibility_range_end = 90.0     # inside a cave nothing further is seen

		if look == "goblin_flame":
			node.material_override = flame_material()
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(node)

	holder.set_meta("rows", rows)      # look -> instance transforms (a headless run's MultiMesh keeps none)
	add_child(holder)
	_tiles[tile] = holder


func clear() -> void:
	for tile in _tiles:
		(_tiles[tile] as Node3D).queue_free()

	_tiles.clear()


func tile_node(tile: Vector2i) -> Node3D:
	return _tiles.get(tile)


func _solid(at: Vector3, tall: float, wide: float) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = wide * 0.75             # the column is thinner than its foot
	cylinder.height = tall
	shape.shape = cylinder
	body.add_child(shape)
	body.position = at + Vector3(0.0, tall * 0.5, 0.0)
	return body


# The unit meshes: "bones_animal", "bones_human" (a pile about 1 m across, its floor point at y 0) and "stalagmite", "stalactite" (1 m tall, 1 m
# across the base; a stalactite hangs down from y 0).
static func look_mesh(look: String) -> ArrayMesh:
	if _meshes.has(look):
		return _meshes[look]

	var parts: Array = []

	match look:
		"bones_animal":
			_animal_bones(parts)
		"bones_human":
			_human_bones(parts)
		"goblin_litter":
			_goblin_litter(parts)
		"goblin_fire":
			_goblin_fire(parts)
		"goblin_flame":
			_goblin_flame(parts)
		"stalagmite":
			_formation(parts, false)
		"stalactite":
			_formation(parts, true)

	var made: ArrayMesh = BasicLook._combine(parts, 1.0)
	_meshes[look] = made
	return made


# A tapering column of wet limestone: stacked rings narrowing to a rounded tip, each ring a little off the last (it grew drip by drip), pale ridges
# where the water ran, the tip darker and wet. Upside down for a stalactite, the wide root against the roof.
static func _formation(parts: Array, hanging: bool) -> void:
	var up: float = -1.0 if hanging else 1.0
	var rings: int = 7
	var y: float = 0.0

	for k in rings:
		var t0: float = float(k) / float(rings)
		var t1: float = float(k + 1) / float(rings)
		var r0: float = 0.44 * pow(1.0 - t0, 0.75) + 0.06 + 0.025 * sin(float(k) * 2.7)
		var r1: float = 0.44 * pow(1.0 - t1, 0.75) + 0.06 + 0.025 * sin(float(k + 1) * 2.7)
		var h: float = t1 - t0
		var lean: Vector3 = Vector3(0.03 * sin(float(k) * 2.1), 0.0, 0.03 * cos(float(k) * 1.7)) * t0
		var tone: Color = BasicLook._tone(STONE, k, 0.06).lerp(Color(0.5, 0.46, 0.4), 0.45 * t1 * t1)
		var bottom: float = r0 if not hanging else r1
		var top: float = r1 if not hanging else r0
		BasicLook._frustum(parts, bottom, top, h, lean + Vector3(0.0, up * (y + 0.5 * h), 0.0), tone)
		# A drip ring at each joint: a slightly wider band of paler stone.
		BasicLook._sph(parts, r1 * 1.04 + 0.006, Vector3(1.0, 0.18, 1.0), lean + Vector3(0.0, up * t1, 0.0), BasicLook._tone(STONE, k + 2, 0.05).lightened(0.04), true)
		y += h

	# Flowstone at the foot (or the root): a low lumpy skirt where the water spread out.
	for k in 5:
		var a: float = TAU * float(k) / 5.0 + 0.4
		BasicLook._sph(parts, 0.22, Vector3(1.3, 0.35, 1.0), Vector3(cos(a) * 0.32, up * 0.03, sin(a) * 0.32), BasicLook._tone(STONE, k + 3, 0.08))

	# Bulges where the flow thickened, sitting on the column (Art_Direction: natural, not machined).
	for k in 4:
		var a: float = TAU * float(k) / 4.0 + 0.7
		var t: float = 0.3 + 0.15 * float(k)
		var r: float = 0.44 * pow(1.0 - t, 0.75) + 0.06
		BasicLook._sph(parts, r * 0.38, Vector3(1.0, 1.4, 1.0), Vector3(cos(a) * r * 0.7, up * t, sin(a) * r * 0.7), BasicLook._tone(STONE, k + 5, 0.07))

	BasicLook._sph(parts, 0.07, Vector3(1.0, 0.9, 1.0), Vector3(0.0, up * 0.99, 0.0), Color(0.5, 0.47, 0.41))   # the rounded wet tip


# The bones of a large beast (a deer or an elk taken by wolves): a long skull with antler stumps, a jaw, a ribcage fallen open, a spine, leg bones
# and a shoulder blade, scattered over a bed of small fragments.
static func _animal_bones(parts: Array) -> void:
	var dark: Color = BONE.darkened(0.28)
	# Skull: a long snout, the braincase, two dark eye sockets, antler stumps.
	BasicLook._sph(parts, 0.09, Vector3(1.0, 0.8, 0.9), Vector3(0.28, 0.07, -0.12), BONE)
	BasicLook._sph(parts, 0.07, Vector3(2.4, 0.6, 0.75), Vector3(0.43, 0.05, -0.17), BONE.darkened(0.05))
	for side in [-1.0, 1.0]:
		BasicLook._sph(parts, 0.025, Vector3(1.0, 1.0, 1.0), Vector3(0.33, 0.1, -0.12 + side * 0.06), dark.darkened(0.4), true)
		BasicLook._box_rot(parts, Vector3(0.025, 0.16, 0.025), Vector3(0.22, 0.17, -0.12 + side * 0.06), Vector3(side * 0.5, 0.0, 0.35), BONE.lightened(0.04))
		BasicLook._box_rot(parts, Vector3(0.018, 0.09, 0.018), Vector3(0.2, 0.26, -0.12 + side * 0.1), Vector3(side * 0.9, 0.0, 0.2), BONE.lightened(0.04))
	BasicLook._box_rot(parts, Vector3(0.26, 0.025, 0.03), Vector3(0.45, 0.012, -0.03), Vector3(0.0, 0.5, 0.0), BONE.darkened(0.08))   # the jaw
	# Spine: a row of vertebrae curving through the pile.
	for k in 9:
		var t: float = float(k) / 8.0
		BasicLook._sph(parts, 0.035, Vector3(1.0, 0.8, 1.2), Vector3(0.15 - t * 0.6, 0.03, 0.02 + 0.08 * sin(t * 3.0)), BasicLook._tone(BONE, k, 0.06), true)
	# Ribs: curved arcs, some still up off the floor, most fallen flat.
	for k in 7:
		var x: float = 0.05 - 0.07 * float(k)
		for side in [-1.0, 1.0]:
			var fallen: bool = (k + int(side > 0.0)) % 3 != 0
			var lift: float = 0.0 if fallen else 0.6
			BasicLook._box_rot(parts, Vector3(0.018, 0.012, 0.22), Vector3(x, 0.03 + 0.06 * lift, side * 0.13), Vector3(side * lift, 0.25 * float(k % 2) - 0.1, 0.0), BasicLook._tone(BONE, k * 2 + int(side > 0.0), 0.08))
	# Leg bones with knobbed ends, a shoulder blade.
	for k in 3:
		var at: Vector3 = Vector3(-0.2 + 0.17 * float(k), 0.025, 0.25 - 0.05 * float(k))
		var yaw: float = 0.6 * float(k) - 0.4
		var along: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw)) * 0.17
		BasicLook._box_rot(parts, Vector3(0.34, 0.03, 0.03), at, Vector3(0.0, yaw, 0.0), BONE.lightened(0.03))
		BasicLook._sph(parts, 0.03, Vector3(1.2, 1.0, 1.0), at + along, BONE)
		BasicLook._sph(parts, 0.03, Vector3(1.2, 1.0, 1.0), at - along, BONE)
	BasicLook._sph(parts, 0.08, Vector3(1.3, 0.15, 0.8), Vector3(-0.3, 0.012, -0.2), BONE.darkened(0.12))
	_fragments(parts, 12, 0.45)


# A person's bones (an old death in the dark): a round skull on its side with dark eye sockets and a lower jaw, a ribcage fallen in, the pelvis,
# long arm and leg bones, a few finger bones, fragments.
static func _human_bones(parts: Array) -> void:
	var dark: Color = BONE.darkened(0.3)
	BasicLook._sph(parts, 0.1, Vector3(1.0, 0.95, 1.2), Vector3(0.36, 0.09, 0.0), BONE.lightened(0.03))      # the cranium
	BasicLook._sph(parts, 0.06, Vector3(1.0, 0.8, 1.1), Vector3(0.43, 0.04, 0.0), BONE)                     # the face
	for side in [-1.0, 1.0]:
		BasicLook._sph(parts, 0.026, Vector3(1.0, 1.0, 1.0), Vector3(0.465, 0.07, side * 0.035), dark.darkened(0.45), true)
	BasicLook._sph(parts, 0.016, Vector3(1.0, 1.2, 1.0), Vector3(0.49, 0.03, 0.0), dark.darkened(0.4), true)  # the nose hole
	BasicLook._box_rot(parts, Vector3(0.09, 0.02, 0.1), Vector3(0.52, 0.012, 0.05), Vector3(0.0, 0.5, 0.0), BONE.darkened(0.06))  # the jaw, fallen away
	for k in 7:
		var x: float = 0.22 - 0.045 * float(k)
		BasicLook._sph(parts, 0.022, Vector3(1.0, 0.8, 1.2), Vector3(x, 0.022, 0.0), BasicLook._tone(BONE, k, 0.05), true)
		for side in [-1.0, 1.0]:
			BasicLook._box_rot(parts, Vector3(0.012, 0.01, 0.14), Vector3(x + 0.01, 0.02 + 0.02 * float(k % 2), side * 0.08), Vector3(side * 0.3 * float(k % 2), 0.2 * side, 0.0), BasicLook._tone(BONE, k + 4, 0.08))
	BasicLook._sph(parts, 0.09, Vector3(0.8, 0.35, 1.3), Vector3(-0.1, 0.03, 0.0), BONE.darkened(0.05))      # the pelvis
	for row in [[Vector3(-0.32, 0.02, 0.09), 0.15, 0.4], [Vector3(-0.34, 0.02, -0.11), -0.25, 0.42], [Vector3(0.12, 0.02, 0.2), 0.9, 0.28], [Vector3(0.05, 0.02, -0.22), -1.1, 0.27]]:
		var at: Vector3 = row[0]
		var yaw: float = row[1]
		var long: float = row[2]
		var along: Vector3 = Vector3(cos(yaw), 0.0, -sin(yaw)) * long * 0.5
		BasicLook._box_rot(parts, Vector3(long, 0.026, 0.026), at, Vector3(0.0, yaw, 0.0), BONE.lightened(0.02))
		BasicLook._sph(parts, 0.022, Vector3(1.3, 1.0, 1.0), at + along, BONE)
		BasicLook._sph(parts, 0.022, Vector3(1.3, 1.0, 1.0), at - along, BONE)
	for k in 5:
		BasicLook._box_rot(parts, Vector3(0.03, 0.01, 0.01), Vector3(0.28 + 0.02 * float(k), 0.006, 0.26 + 0.012 * float(k % 3)), Vector3(0.0, 0.4 * float(k), 0.0), BONE)   # finger bones
	_fragments(parts, 9, 0.4)


# Goblin den litter (Dave 7 Nov 2026: bones, sticks and thatch strewn on the floor): a small heap about 1 m across with a few gnawed bones, a
# criss-cross of sticks and a flat mat of straw-coloured thatch.
static func _goblin_litter(parts: Array) -> void:
	_fragments(parts, 5, 0.35)
	var stick: Color = Color(0.36, 0.26, 0.17)
	var straw: Color = Color(0.72, 0.62, 0.34)

	for k in 6:
		var a: float = TAU * float(k) * 0.381966
		BasicLook._box_rot(parts, Vector3(0.5 + 0.1 * float(k % 3), 0.025, 0.025), Vector3(cos(a) * 0.15, 0.03 + 0.02 * float(k % 3), sin(a) * 0.15), Vector3(0.0, a, 0.1 * float((k % 3) - 1)), BasicLook._tone(stick, k, 0.15))

	for k in 7:
		var a: float = TAU * float(k) * 0.618034
		BasicLook._box_rot(parts, Vector3(0.38, 0.012, 0.05), Vector3(cos(a) * 0.22, 0.01 + 0.004 * float(k), sin(a) * 0.22), Vector3(0.0, a * 1.7, 0.0), BasicLook._tone(straw, k, 0.12))


# A small goblin campfire (the base, without the flame): a ring of stones round a teepee of five charred logs on a dark bed of dull embers.
# About 0.7 m across. The flame is its own look, "goblin_flame", so it can glow.
static func _goblin_fire(parts: Array) -> void:
	var stone: Color = Color(0.45, 0.43, 0.4)

	for k in 8:
		var a: float = TAU * float(k) / 8.0
		BasicLook._box_rot(parts, Vector3(0.14, 0.1, 0.12), Vector3(cos(a) * 0.3, 0.05, sin(a) * 0.3), Vector3(0.0, a, 0.0), BasicLook._tone(stone, k, 0.12))

	BasicLook._box_rot(parts, Vector3(0.4, 0.03, 0.4), Vector3(0.0, 0.03, 0.0), Vector3.ZERO, Color(0.28, 0.1, 0.05))      # the bed of dull embers

	for k in 5:
		var a: float = TAU * float(k) / 5.0 + 0.3
		# A log leaning in against the middle: its foot out at the ring, its top meeting the others (a tilt of (-sin a, 0, cos a) leans the top toward the centre).
		var lean: Vector3 = Vector3(cos(a), 0.0, sin(a))
		BasicLook._cyl(parts, 0.03, 0.42, Vector3(lean.x * 0.1, 0.16, lean.z * 0.1), Vector3(-sin(a) * 0.55, 0.0, cos(a) * 0.55), Color(0.2, 0.13, 0.08) if k % 2 == 0 else Color(0.1, 0.07, 0.05))


# The flame of a goblin den fire: a tall core tongue with four shorter ones leaning out round it, yellow-white inside, orange outside. About 0.25 m
# across and 0.45 m tall, standing on the logs. Drawn with a glowing material (flame_material) and a light that flickers.
static func _goblin_flame(parts: Array) -> void:
	_tongue(parts, 0.07, 0.46, Vector3(0.0, 0.16, 0.0), Vector3.ZERO, Color(1.0, 0.92, 0.55))

	for k in 4:
		var a: float = TAU * float(k) / 4.0 + 0.5
		var lean: float = 0.28
		_tongue(parts, 0.06, 0.3 + 0.04 * float(k % 2), Vector3(cos(a) * 0.07, 0.1, sin(a) * 0.07), Vector3(sin(a) * lean, 0.0, -cos(a) * lean), Color(1.0, 0.55, 0.12))


# One flame tongue: a cone standing on `foot` (its base centre), `height` tall, leaning by `tilt` (radians about x, y, z).
static func _tongue(parts: Array, radius: float, height: float, foot: Vector3, tilt: Vector3, color: Color) -> void:
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = height
	cone.radial_segments = 6
	cone.rings = 1
	var tilt_basis: Basis = Basis.from_euler(tilt)
	parts.append([cone, Transform3D(tilt_basis, foot + tilt_basis * Vector3(0.0, height * 0.5, 0.0)), color])


static func _fragments(parts: Array, count: int, reach: float) -> void:
	for k in count:
		var a: float = TAU * float(k) * 0.381966
		var r: float = reach * sqrt((float(k) + 0.5) / float(count))
		BasicLook._box_rot(parts, Vector3(0.04 + 0.02 * float(k % 3), 0.012, 0.015), Vector3(cos(a) * r, 0.006, sin(a) * r), Vector3(0.0, a, 0.0), BasicLook._tone(BONE.darkened(0.1), k, 0.12))
