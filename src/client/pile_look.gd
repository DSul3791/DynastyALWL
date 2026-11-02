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


static func is_pile(entry: Dictionary, count: int) -> bool:
	return count >= MIN_PILE and entry.has("pile")


# The mesh for `count` of `item_id`; `seed_id` (the world item id) decides rock sizes and tilt. Cached by (kind, count, seed).
static func mesh_for(item_id: String, entry: Dictionary, count: int, seed_id: int) -> Mesh:
	var key: String = "%s|%d|%d" % [item_id, count, seed_id]

	if _cache.has(key):
		return _cache[key]

	if _cache.size() > 200:
		_cache.clear()

	var kind: Dictionary = entry["pile"]
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
