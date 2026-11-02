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

# What each kind looks like comes from its items.json "pile" row: {"shape": "pyramid" | "mound", "handful", "color", "rock" (rock size scale), "squash",
# optional "tight" (scales footprint and row rise with the lump size, default 1.0) and "jitter" (lump size spread, default 0.2)}.
# Soil and clay (Dave 2026-10-24): lumps half the size of one dirt clump, packed tight so neighbours overlap.

static var _cache: Dictionary = {}
static var _material: StandardMaterial3D


# A pile row may set its own "min" (firewood: 2, so every split piece beside the chopping block shows; bug 3, Dave 1 Nov 2026).
static func is_pile(entry: Dictionary, count: int) -> bool:
	return entry.has("pile") and count >= int((entry["pile"] as Dictionary).get("min", MIN_PILE))


# The mesh for `count` of `item_id`; `seed_id` (the world item id) decides rock sizes and tilt. Cached by (kind, count, seed).
static func mesh_for(item_id: String, entry: Dictionary, count: int, seed_id: int) -> Mesh:
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
