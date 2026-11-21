class_name PileLook
extends RefCounted
# The look of a pile of loose bulk items on the ground (Dave 2026-10-23, tech/items/ROCK_PILE_DESIGN.md). The client builds it from the item count
# alone: nothing is sent. 1 to 5 stay single items; 6 or more become a pyramid of rocks, row k from the top holding 2k-1 rocks (1, 3, 5, ...), the
# last row holding what is left. Past MAX_DRAWN rocks the same footprint is drawn with MAX_DRAWN bigger rocks.

const MIN_PILE := 6
const MAX_DRAWN := 400
const ROW_RISE_M := 0.22            # height of one row
const ROW_SPREAD_M := 0.17          # footprint radius per row
const ROCK_R_M := 0.27

# What each kind looks like comes from its items.json "pile" row ("logs": _logs_mesh, "boards": _boards_mesh; the others below): {"shape": "pyramid" | "mound" | "cone" (with "density_kg_m3": a solid cone, _cone_mesh), "handful", "color", "rock" (rock size scale), "squash",
# optional "tight" (scales footprint and row rise with the lump size, default 1.0) and "jitter" (lump size spread, default 0.2)}.
# A cone row may also set "color2" with "mix" (that share of its pieces take the second colour: ore over its host rock, rust on iron),
# "lumps" (0 smooth stones to about 0.4: each piece is one of LUMP_SHAPES knobbly shapes, built once) and "rough" (material roughness, default 1.0).
# Soil and clay (Dave 2026-10-24): lumps half the size of one dirt clump, packed tight so neighbours overlap.

const PileRules := preload("res://src/shared/pile_rules.gd")
const CONE_SEGMENTS := 18        # the solid core of a cone pile
const LUMP_SHAPES := 4           # knobbly piece shapes per "lumps" amount; each piece of a lumpy cone is one of them, turned and scaled as stones are
static var _cache: Dictionary = {}
static var _material: StandardMaterial3D
static var _rough_materials: Dictionary = {}   # roughness -> material, for cone rows with their own "rough"
static var _lump_cache: Dictionary = {}        # "lumps" amount -> Array of LUMP_SHAPES [verts, normals, indices]


# A pile row may set its own "min" (firewood: 2, so every split piece beside the chopping block shows; bug 3, Dave 1 Nov 2026).
static func is_pile(entry: Dictionary, count: int) -> bool:
	return entry.has("pile") and count >= int((entry["pile"] as Dictionary).get("min", MIN_PILE))


# The mesh for `count` of `item_id`; `seed_id` (the world item id) decides rock sizes and tilt. Cached by (kind, count, seed).
# `unit_kg` is one piece's weight (weights.json), which sizes a "cone" pile (PileRules); other shapes ignore it.
static func mesh_for(item_id: String, entry: Dictionary, count: int, seed_id: int, unit_kg: float = 0.0) -> Mesh:
	var key: String = "%s|%d|%d" % [item_id, count, seed_id]

	if _cache.has(key):
		return _cache[key]

	if _cache.size() > 200:
		_cache.clear()

	var kind: Dictionary = entry["pile"]

	if str(kind.get("shape", "")) == "logs":
		var wood: Mesh = _logs_mesh(kind, count, seed_id)
		_cache[key] = wood
		return wood

	if str(kind.get("shape", "")) == "boards":
		var sawn: Mesh = _boards_mesh(kind, count, seed_id)
		_cache[key] = sawn
		return sawn

	if PileRules.is_cone(kind) and unit_kg > 0.0:
		var cone: Mesh = _cone_mesh(kind, count, seed_id, unit_kg)
		_cache[key] = cone
		return cone

	var tint: Array = kind["color"]
	var base_color: Color = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	var rock_scale: float = float(kind["rock"])
	var flat: float = float(kind["squash"])
	var tight: float = float(kind.get("tight", 1.0))
	var jitter: float = float(kind.get("jitter", 0.2))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_id * 2654435761 + 91
	var shown: int = mini(count, MAX_DRAWN)
	var rows: int = ceili(sqrt(float(shown)))
	var grow: float = sqrt(float(count) / float(shown))        # bigger rocks, same footprint, once the pile is too big to draw rock by rock
	var base: SphereMesh = SphereMesh.new()
	base.radial_segments = 7
	base.rings = 4
	var arrays: Array = base.get_mesh_arrays()
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	# Row k from the top gets its 2k-1 share of the count (scaled when the pile is not a full square), so the pile always tapers.
	var counts: Array = []
	var given: int = 0

	for k in range(1, rows + 1):
		var share: int = int(floor(float(shown) * float(2 * k - 1) / float(rows * rows)))
		counts.append(share)
		given += share

	var extra: int = rows

	while given < shown:
		counts[extra - 1] += 1
		given += 1
		extra = extra - 1 if extra > 1 else rows

	for k in range(1, rows + 1):
		var in_row: int = counts[k - 1]

		if in_row <= 0:
			continue

		var spread: float = ROW_SPREAD_M * tight * sqrt(float(in_row)) * grow
		var y: float = ROW_RISE_M * tight * float(rows - k) * flat * grow

		for i in range(in_row):
			var angle: float = float(i) * 2.39996 + rng.randf() * 0.4
			var radius: float = spread * sqrt((float(i) + 0.5) / float(in_row))
			radius *= 1.0 - 0.15 * float(rows - k) / float(rows)
			var size: float = ROCK_R_M * rock_scale * grow * rng.randf_range(1.0 - jitter, 1.0 + jitter)
			var at: Vector3 = Vector3(cos(angle) * radius, y + size * 0.6, sin(angle) * radius)
			var tilt: Basis = Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
			var squash: Basis = tilt * Basis.from_scale(Vector3(size * rng.randf_range(1.0, 1.3), size * flat * 1.2, size * rng.randf_range(1.0, 1.3)))
			var shade: float = rng.randf_range(0.85, 1.12)
			var color: Color = Color(minf(base_color.r * shade, 1.0), minf(base_color.g * shade, 1.0), minf(base_color.b * shade, 1.0))
			var first: int = verts.size()
			var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var source_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

			for v in range(source.size()):
				verts.append(at + squash * source[v])
				normals.append((tilt * source_n[v]).normalized())
				colors.append(color)

			for index in arrays[Mesh.ARRAY_INDEX]:
				indices.append(first + int(index))

	var out_arrays: Array = []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX] = verts
	out_arrays[Mesh.ARRAY_NORMAL] = normals
	out_arrays[Mesh.ARRAY_COLOR] = colors
	out_arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)

	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 1.0

	mesh.surface_set_material(0, _material)
	_cache[key] = mesh
	return mesh


# --- Cone piles (Dave 19 Nov 2026, boulders PLAN.md 5b: a solid cone with no air, more stones add layers on the outside) ---
# One mesh whatever the count: a solid core cone sized by the stones' own volume (PileRules) with up to MAX_DRAWN rocks laid over its skin,
# each big enough that together they cover it. Nothing new is sent: the client sizes it from the count, as before. Ores use it too, with their own
# colours and lumpy pieces (Dave 21 Nov 2026: "ore piles should stackup like stone piles do just with different colors and lumps").
static func _cone_mesh(kind: Dictionary, count: int, seed_id: int, unit_kg: float) -> Mesh:
	var tint: Array = kind["color"]
	var base_color: Color = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	var tint2: Array = kind.get("color2", tint)
	var second_color: Color = Color(float(tint2[0]), float(tint2[1]), float(tint2[2]))
	var mix: float = float(kind.get("mix", 0.0))
	var jitter: float = float(kind.get("jitter", 0.2))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_id * 2654435761 + 91
	var radius: float = maxf(PileRules.cone_radius(count, unit_kg, float(kind["density_kg_m3"])), PileRules.MIN_DRAWN_R_M)
	var height: float = PileRules.cone_height(radius)
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var slope_n: Vector2 = Vector2(height, radius).normalized()   # (outward, up) of the cone's side

	# The core: a cone a little inside the rocks, its apex and one ring per segment, darker so gaps between the rocks read as shadow.
	var core_r: float = radius * 0.9
	var core_h: float = height * 0.9
	var core_color: Color = base_color * 0.7
	core_color.a = 1.0

	for i in range(CONE_SEGMENTS):
		var a0: float = TAU * float(i) / float(CONE_SEGMENTS)
		var a1: float = TAU * float(i + 1) / float(CONE_SEGMENTS)
		var first: int = verts.size()
		var mid: float = (a0 + a1) * 0.5
		verts.append(Vector3(0.0, core_h, 0.0))   # clockwise seen from outside (Godot's front face)
		verts.append(Vector3(cos(a0) * core_r, 0.0, sin(a0) * core_r))
		verts.append(Vector3(cos(a1) * core_r, 0.0, sin(a1) * core_r))
		normals.append(Vector3(cos(mid) * slope_n.x, slope_n.y, sin(mid) * slope_n.x))
		normals.append(Vector3(cos(a0) * slope_n.x, slope_n.y, sin(a0) * slope_n.x))
		normals.append(Vector3(cos(a1) * slope_n.x, slope_n.y, sin(a1) * slope_n.x))
		colors.append_array(PackedColorArray([core_color, core_color, core_color]))

		indices.append_array(PackedInt32Array([first, first + 1, first + 2]))

	# The skin: rocks spread evenly over the side (golden angle round, area-even down the slant), sized to cover it.
	var shown: int = mini(count, MAX_DRAWN)
	var side_area: float = PI * radius * sqrt(radius * radius + height * height)
	var size_base: float = clampf(sqrt(side_area / float(maxi(shown, 1))) * 0.6, 0.02, ROCK_R_M * float(kind.get("rock", 1.0)))
	var shapes: Array = _lump_shapes(float(kind.get("lumps", 0.0)))

	for i in range(shown):
		var angle: float = float(i) * 2.39996 + rng.randf() * 0.4
		var t: float = sqrt((float(i) + 0.5) / float(shown))   # 0 at the apex, 1 at the foot
		var r: float = radius * t
		var size: float = size_base * rng.randf_range(1.0 - jitter, 1.0 + jitter)
		var out: Vector3 = Vector3(cos(angle) * slope_n.x, slope_n.y, sin(angle) * slope_n.x)
		var at: Vector3 = Vector3(cos(angle) * r, height * (1.0 - t), sin(angle) * r) - out * size * 0.3
		at.y = maxf(at.y, size * 0.4)
		var tilt: Basis = Basis.from_euler(Vector3(rng.randf() * TAU, rng.randf() * TAU, rng.randf() * TAU))
		var squash: Basis = tilt * Basis.from_scale(Vector3(size * rng.randf_range(1.0, 1.3), size * 0.8, size * rng.randf_range(1.0, 1.3)))
		var shade: float = rng.randf_range(0.85, 1.12)
		var piece_color: Color = second_color if mix > 0.0 and rng.randf() < mix else base_color   # no extra draws for stone, so its piles look as before
		var color: Color = Color(minf(piece_color.r * shade, 1.0), minf(piece_color.g * shade, 1.0), minf(piece_color.b * shade, 1.0))
		var shape: Array = shapes[rng.randi() % shapes.size()] if shapes.size() > 1 else shapes[0]
		var source: PackedVector3Array = shape[0]
		var source_n: PackedVector3Array = shape[1]
		var first: int = verts.size()

		for v in range(source.size()):
			verts.append(at + squash * source[v])
			normals.append((tilt * source_n[v]).normalized())
			colors.append(color)

		for index in shape[2]:
			indices.append(first + int(index))

	var out_arrays: Array = []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX] = verts
	out_arrays[Mesh.ARRAY_NORMAL] = normals
	out_arrays[Mesh.ARRAY_COLOR] = colors
	out_arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)
	mesh.surface_set_material(0, _cone_material(float(kind.get("rough", 1.0))))
	return mesh


static func _cone_material(rough: float) -> StandardMaterial3D:
	if rough >= 1.0:
		if _material == null:
			_material = StandardMaterial3D.new()
			_material.vertex_color_use_as_albedo = true
			_material.roughness = 1.0

		return _material

	if not _rough_materials.has(rough):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = rough
		_rough_materials[rough] = m

	return _rough_materials[rough]


# The piece shapes of a cone pile: the 7 x 4 sphere stones have always used (lumps 0, one shape), or LUMP_SHAPES knobbly ones with each point
# pushed in or out by a few low waves over the sphere. The push depends only on the point, so the sphere's seam points stay joined; normals
# are rebuilt from the faces and shared across the seam. Built once per amount, so a lumpy pile costs the same per piece as a stone one.
static func _lump_shapes(lumps: float) -> Array:
	if _lump_cache.has(lumps):
		return _lump_cache[lumps]

	var base: SphereMesh = SphereMesh.new()
	base.radial_segments = 7
	base.rings = 4
	var arrays: Array = base.get_mesh_arrays()
	var sphere_v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var sphere_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var sphere_i: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var shapes: Array = []

	if lumps <= 0.0:
		shapes.append([sphere_v, sphere_n, sphere_i])
		_lump_cache[lumps] = shapes
		return shapes

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7741

	for k in range(LUMP_SHAPES):
		var waves: Array = []

		for w in range(3):
			waves.append([Vector3(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)).normalized() * rng.randf_range(2.0, 4.0), rng.randf() * TAU])

		var moved: PackedVector3Array = PackedVector3Array()

		for p in sphere_v:
			var push: float = 0.0

			for wave in waves:
				push += sin((wave[0] as Vector3).dot(p * 2.0) + float(wave[1]))

			moved.append(p * (1.0 + lumps * push / 3.0))

		var by_point: Dictionary = {}   # rounded point -> summed face normal, so the seam's twin points share one normal

		for t in range(0, sphere_i.size(), 3):
			var a: Vector3 = moved[sphere_i[t]]
			var face: Vector3 = (moved[sphere_i[t + 1]] - a).cross(moved[sphere_i[t + 2]] - a)

			for c in range(3):
				var at_key: Vector3i = Vector3i((moved[sphere_i[t + c]] * 1000.0).round())
				by_point[at_key] = by_point.get(at_key, Vector3.ZERO) + face

		var moved_n: PackedVector3Array = PackedVector3Array()

		for v in range(moved.size()):
			var sum: Vector3 = by_point.get(Vector3i((moved[v] * 1000.0).round()), Vector3.ZERO)
			var n: Vector3 = sum.normalized() if sum.length_squared() > 0.0 else sphere_n[v]

			if n.dot(sphere_n[v]) < 0.0:
				n = -n   # the faces' winding is the mesh's own; keep every normal pointing out

			moved_n.append(n)

		shapes.append([moved, moved_n, sphere_i])

	_lump_cache[lumps] = shapes
	return shapes


# --- Split firewood and wooden blocks (Dave 2 Nov 2026: they looked like little brown balls) ---
# A stack of split-log pieces like a woodpile: each piece is a half-cylinder (round bark side up, flat cut side down) with pale cut ends, or for a
# whole round (kind "round": true) a short full cylinder. Pieces lie side by side along z in a triangular stack (a bottom layer of up to W, one fewer each layer up);
# more than one stack's worth makes several stacks in a grid. From items.json "pile": {"shape": "logs", "color" (bark), "len", "radius", "round" (optional)}.
const LOG_ARC := 6
const LOG_STACK_W := 6
const LOG_PALE := Color(0.84, 0.70, 0.50)
static var _logs_material: StandardMaterial3D


static func _logs_mesh(kind: Dictionary, count: int, seed_id: int) -> Mesh:
	var bark_tint: Array = kind["color"]
	var bark: Color = Color(float(bark_tint[0]), float(bark_tint[1]), float(bark_tint[2]))
	var length: float = float(kind.get("len", 0.4))
	var radius: float = float(kind.get("radius", 0.065))
	var full: bool = bool(kind.get("round", false))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_id * 2654435761 + 17
	var shown: int = mini(count, MAX_DRAWN)
	var width: int = LOG_STACK_W
	var per_stack: int = (width * (width + 1)) >> 1
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var left: int = shown
	var stack: int = 0
	var stack_w: float = float(width) * 2.0 * radius + 0.1

	while left > 0:
		var here: int = mini(left, per_stack)
		var w: int = width if here > ((width * (width - 1)) >> 1) else maxi(1, int(ceil((sqrt(8.0 * float(here) + 1.0) - 1.0) / 2.0)))   # a small last stack is only as wide as it needs
		var origin: Vector3 = Vector3(float(floori(float(stack) / 3.0)) * (length + 0.08), 0.0, float(stack % 3) * stack_w)
		var placed: int = 0
		var layer: int = 0

		while placed < here:
			var in_layer: int = mini(w - layer, here - placed)

			for i in range(in_layer):
				var z: float = (float(i) - float(in_layer - 1) * 0.5) * (2.0 * radius * 1.04)
				var y: float = float(layer) * radius * 0.95
				var jitter: Vector3 = Vector3(rng.randf_range(-0.03, 0.03), 0.0, rng.randf_range(-0.004, 0.004))
				var tone: float = rng.randf_range(0.85, 1.12)
				var piece_bark: Color = Color(minf(bark.r * tone, 1.0), minf(bark.g * tone, 1.0), minf(bark.b * tone, 1.0))
				_add_piece(verts, normals, colors, indices, origin + Vector3(0.0, y, z) + jitter, rng.randf_range(-0.12, 0.12), length * rng.randf_range(0.9, 1.1), radius * rng.randf_range(0.9, 1.1), piece_bark, full)

			placed += in_layer
			layer += 1

		left -= here
		stack += 1

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if _logs_material == null:
		_logs_material = StandardMaterial3D.new()
		_logs_material.vertex_color_use_as_albedo = true
		_logs_material.roughness = 1.0
		_logs_material.cull_mode = BaseMaterial3D.CULL_DISABLED   # thin pieces seen from any side; the winding does not matter

	mesh.surface_set_material(0, _logs_material)
	return mesh


# One piece lying along x: the arc of its round side in bark colour and pale cut ends. Half: flat side down at `at`.y; full: a round resting on it.
static func _add_piece(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, at: Vector3, yaw: float, length: float, radius: float, bark: Color, full: bool) -> void:
	var steps: int = LOG_ARC * 2 if full else LOG_ARC
	var sweep: float = TAU if full else PI
	var lift: float = radius if full else 0.0
	var turn: Basis = Basis(Vector3.UP, yaw)
	var arc: Array = []

	for i in range(steps + 1):
		var a: float = sweep * float(i) / float(steps)
		arc.append(Vector2(sin(a) * radius + lift, cos(a) * radius))   # (y, z)

	var half: float = length * 0.5

	for i in range(steps):
		var p0: Vector2 = arc[i]
		var p1: Vector2 = arc[i + 1]
		var first: int = verts.size()
		var n0: Vector3 = turn * Vector3(0.0, p0.x - lift, p0.y).normalized()
		var n1: Vector3 = turn * Vector3(0.0, p1.x - lift, p1.y).normalized()

		for corner in [[-half, p0, n0], [half, p0, n0], [half, p1, n1], [-half, p1, n1]]:
			verts.append(at + turn * Vector3(float(corner[0]), (corner[1] as Vector2).x, (corner[1] as Vector2).y))
			normals.append(corner[2])
			colors.append(bark)

		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])

	for end in [-half, half]:
		var centre: int = verts.size()
		verts.append(at + turn * Vector3(float(end), lift, 0.0))
		normals.append(turn * Vector3(signf(float(end)), 0.0, 0.0))
		colors.append(LOG_PALE)

		for i in range(steps + 1):
			verts.append(at + turn * Vector3(float(end), (arc[i] as Vector2).x, (arc[i] as Vector2).y))
			normals.append(turn * Vector3(signf(float(end)), 0.0, 0.0))
			colors.append(LOG_PALE)

		for i in range(steps):
			indices.append_array([centre, centre + 1 + i, centre + 2 + i])


# --- Sawn boards (Dave 21 Nov 2026: "dropped hardwood boards ... should look like 8ft long boards") ---
# A neat lumber stack: boards lie flat side by side, BOARD_ROW to a layer, each layer on the one below, ends a little staggered; past
# BOARD_LAYERS layers a new stack starts beside it. From items.json "pile": {"shape": "boards", "color", "len", "width", "thick"}.
# Each board is one box of 12 triangles with pale cut ends.
const BOARD_ROW := 4
const BOARD_LAYERS := 10
const BOARD_PALE := Color(0.86, 0.74, 0.56)
const BOARD_FLOOR := -0.12   # the bottom board on the drawn ground: loose items are set 0.12 m over it (InventoryView._snap_loose)


static func _boards_mesh(kind: Dictionary, count: int, seed_id: int) -> Mesh:
	var tint: Array = kind["color"]
	var wood: Color = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	var length: float = float(kind["len"])
	var width: float = float(kind["width"])
	var thick: float = float(kind["thick"])
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_id * 2654435761 + 23
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()
	var per_stack: int = BOARD_ROW * BOARD_LAYERS

	for n in range(mini(count, MAX_DRAWN)):
		var stack: int = floori(float(n) / float(per_stack))
		var layer: int = floori(float(n % per_stack) / float(BOARD_ROW))
		var row: int = n % BOARD_ROW
		var z: float = float(stack) * (float(BOARD_ROW) * width + 0.15) + (float(row) - float(BOARD_ROW - 1) * 0.5) * (width + 0.006)
		var at: Vector3 = Vector3(rng.randf_range(-0.06, 0.06), BOARD_FLOOR + (float(layer) + 0.5) * thick, z)
		var tone: float = rng.randf_range(0.88, 1.1)
		_add_board(verts, normals, colors, indices, at, rng.randf_range(-0.012, 0.012), Vector3(length, thick, width), Color(minf(wood.r * tone, 1.0), minf(wood.g * tone, 1.0), minf(wood.b * tone, 1.0)))

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	if _logs_material == null:
		_logs_material = StandardMaterial3D.new()
		_logs_material.vertex_color_use_as_albedo = true
		_logs_material.roughness = 1.0
		_logs_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	mesh.surface_set_material(0, _logs_material)
	return mesh


# One board centred on `at`, its length along x turned by `yaw`: six faces, the two ends pale.
static func _add_board(verts: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, at: Vector3, yaw: float, dims: Vector3, wood: Color) -> void:
	var turn: Basis = Basis(Vector3.UP, yaw)
	var h: Vector3 = dims * 0.5

	for axis in 3:
		for side in [-1.0, 1.0]:
			var normal: Vector3 = Vector3.ZERO
			normal[axis] = side
			var u: Vector3 = Vector3.ZERO
			var v: Vector3 = Vector3.ZERO
			u[(axis + 1) % 3] = h[(axis + 1) % 3]
			v[(axis + 2) % 3] = h[(axis + 2) % 3]
			var centre: Vector3 = normal * h[axis]
			var first: int = verts.size()

			for corner in [-u - v, u - v, u + v, -u + v]:
				verts.append(at + turn * (centre + corner))
				normals.append(turn * normal)
				colors.append(BOARD_PALE if axis == 0 else wood)

			indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3] if side > 0.0 else [first, first + 2, first + 1, first, first + 3, first + 2])
