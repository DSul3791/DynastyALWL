extends Node3D

# Draws trees and plants (plan step 15) from chunk item lists, wherever they
# come from: the flora placer directly (terrain preview) or the server
# (terrain client).
#
# Each chunk is drawn at a level set by its distance from the player: trees
# out to view_m.tree, shrubs to view_m.shrub, small plants to view_m.plant
# (tile_rules.json "runtime_flora"). One MultiMesh per species and part of
# the chunk (256 m for trees, 128 m for shrubs and plants), so whole groups
# are culled cheaply. Trees and shrubs within collision_m get trunk
# colliders so the player cannot walk through them.
#
# Each chunk also carries its rivers and lakes (WaterGrid levels), drawn as
# flat water out to tree view distance.
#
# Meshes are simple stand-ins built from the species table (trunk, crown
# shape and color) until real models exist.

const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const KIND_TREE := 0
const KIND_SHRUB := 1
const KIND_PLANT := 2
const AUTUMN: Array[Color] = [
	Color(0.95, 0.8, 0.15), Color(0.9, 0.65, 0.1), Color(0.93, 0.5, 0.1), Color(0.85, 0.32, 0.08),
	Color(0.78, 0.15, 0.1), Color(0.6, 0.1, 0.1), Color(0.8, 0.55, 0.15)
]
const KINDS := ["tree", "shrub", "plant"]
const PART_M := [256.0, 128.0, 128.0]

var chunk_m: float = 256.0
var view_m: PackedFloat32Array = PackedFloat32Array([900.0, 300.0, 120.0])
var collision_m: float = 160.0
var instances: int = 0                 # items drawn now
var colliders: int = 0                 # trunk colliders now
var water_chunks: int = 0              # chunks with water drawn
var water_cells: int = 0

var _species: Dictionary = {}          # species id -> {"kind", "mesh", "trunk", "height"}
var _chunks: Dictionary = {}           # Vector2i -> {"items", "level", "node"}
var _trunk_material: StandardMaterial3D
var _softwood_material: StandardMaterial3D   # conifer trunks: dark brown
var _hardwood_material: StandardMaterial3D   # broadleaf trunks: gray
var _water_material: StandardMaterial3D


func setup(tables, tile_rules: Dictionary) -> void:
	var rules: Dictionary = tile_rules.get("runtime_flora", {})
	chunk_m = float(rules.get("chunk_m", 256.0))
	var view: Dictionary = rules.get("view_m", {})

	for n in range(3):
		view_m[n] = float(view.get(KINDS[n], view_m[n]))

	collision_m = float(rules.get("collision_m", collision_m))
	_trunk_material = StandardMaterial3D.new()
	_trunk_material.albedo_color = Color(0.32, 0.24, 0.16)
	_trunk_material.roughness = 1.0
	_softwood_material = StandardMaterial3D.new()
	_softwood_material.albedo_color = Color(0.2, 0.13, 0.08)
	_softwood_material.roughness = 1.0
	_hardwood_material = StandardMaterial3D.new()
	_hardwood_material.albedo_color = Color(0.5, 0.5, 0.5)
	_hardwood_material.roughness = 1.0
	_water_material = StandardMaterial3D.new()
	_water_material.albedo_color = Color(0.16, 0.36, 0.42, 0.78)
	_water_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_material.roughness = 0.08
	_water_material.metallic_specular = 0.8
	_water_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_water_material.vertex_color_use_as_albedo = true

	for entry in tables.get_entries("flora"):
		if entry.get("retired", false):
			continue

		var height: Array = entry["height_m"]
		var reference: float = 0.5 * (float(height[0]) + float(height[1]))
		_species[int(entry["id"])] = {
			"kind": KINDS.find(str(entry["kind"])),
			"height": reference,
			"trunk": float(entry["trunk_m"]),
			"hardwood": str(entry["shape"]) == "broadleaf",
			"mesh": _make_mesh(entry, reference),
		}


# The chunks to have, nearest first: every chunk within tree view distance.
func wanted_chunks(position: Vector3) -> Array:
	var reach: int = int(ceil(view_m[KIND_TREE] / chunk_m))
	var center: Vector2i = Vector2i(int(floor(position.x / chunk_m)), int(floor(position.z / chunk_m)))
	var list: Array = []

	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var chunk: Vector2i = center + Vector2i(dx, dz)
			var distance: float = _distance(chunk, position)

			if distance <= view_m[KIND_TREE]:
				list.append([distance, chunk])

	list.sort_custom(func(a, b): return a[0] < b[0])
	return list.map(func(entry): return entry[1])


func has_chunk(chunk: Vector2i) -> bool:
	return _chunks.has(chunk)


# Sets a chunk's items (as from FloraPlacer.chunk_items or decode).
func set_chunk(chunk: Vector2i, items: Dictionary, position: Vector3, water: Dictionary = {}) -> void:
	drop_chunk(chunk)
	var entry: Dictionary = {"items": items, "level": -1, "node": null, "water": null}
	_chunks[chunk] = entry

	if int(water.get("wet", 0)) > 0:
		var mesh: ArrayMesh = WaterGridScript.build_mesh(water, _water_material)

		if mesh.get_surface_count() > 0:
			var draw: MeshInstance3D = MeshInstance3D.new()
			draw.mesh = mesh
			draw.position = Vector3(float(chunk.x) * chunk_m, 0.0, float(chunk.y) * chunk_m)
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(draw)
			entry["water"] = draw
			water_chunks += 1
			water_cells += mesh.surface_get_array_index_len(0) / 6

	_refresh(chunk, position)


func drop_chunk(chunk: Vector2i) -> void:
	var entry: Dictionary = _chunks.get(chunk, {})

	if entry.is_empty():
		return

	_clear_node(entry)
	var water: MeshInstance3D = entry.get("water")

	if water != null:
		water_chunks -= 1
		water_cells -= water.mesh.surface_get_array_index_len(0) / 6
		water.queue_free()

	_chunks.erase(chunk)


# Removes one item (cut down) and redraws its chunk.
func remove_item(chunk: Vector2i, id: int, position: Vector3) -> void:
	var entry: Dictionary = _chunks.get(chunk, {})

	if entry.is_empty():
		return

	var items: Dictionary = entry["items"]
	var index: int = items["ids"].find(id)

	if index < 0:
		return

	for key in ["ids", "positions", "heights", "yaws"]:
		items[key].remove_at(index)

	entry["level"] = -1
	_refresh(chunk, position)


# Redraws chunks whose level changed and drops far ones. Returns the
# chunks dropped.
func update(position: Vector3) -> Array:
	var dropped: Array = []

	for chunk in _chunks.keys():
		if _distance(chunk, position) > view_m[KIND_TREE] + 2.0 * chunk_m:
			drop_chunk(chunk)
			dropped.append(chunk)
		else:
			_refresh(chunk, position)

	return dropped


func item_count() -> int:
	var total: int = 0

	for chunk in _chunks:
		total += _chunks[chunk]["items"]["ids"].size()

	return total


# ---------------------------------------------------------------- drawing

# Level bits: 1 trees, 2 shrubs, 4 plants, 8 colliders.
func _level(chunk: Vector2i, position: Vector3) -> int:
	var distance: float = _distance(chunk, position)
	var level: int = 0

	for kind in range(3):
		if distance <= view_m[kind]:
			level |= 1 << kind

	if distance <= collision_m:
		level |= 8

	return level


func _refresh(chunk: Vector2i, position: Vector3) -> void:
	var entry: Dictionary = _chunks[chunk]
	var level: int = _level(chunk, position)

	if level == entry["level"]:
		return

	_clear_node(entry)
	entry["level"] = level
	var node: Node3D = Node3D.new()
	node.name = "Chunk_%d_%d" % [chunk.x, chunk.y]
	add_child(node)
	entry["node"] = node
	var items: Dictionary = entry["items"]
	var ids: PackedInt32Array = items["ids"]
	var groups: Dictionary = {}       # [species, part] -> PackedInt32Array of indices
	var body: StaticBody3D = null

	for n in range(ids.size()):
		var species_id: int = ids[n] >> 16
		var info: Dictionary = _species.get(species_id, {})

		if info.is_empty() or (level & (1 << int(info["kind"]))) == 0:
			continue

		var p: Vector3 = items["positions"][n]
		var part_m: float = PART_M[info["kind"]]
		var key: Array = [species_id, int(floor(p.x / part_m)), int(floor(p.z / part_m))]

		if not groups.has(key):
			groups[key] = PackedInt32Array()

		groups[key].append(n)

		if (level & 8) != 0 and int(info["kind"]) != KIND_PLANT and float(info["trunk"]) >= 0.1:
			if body == null:
				body = StaticBody3D.new()
				node.add_child(body)

			var shape: CollisionShape3D = CollisionShape3D.new()
			var cylinder: CylinderShape3D = CylinderShape3D.new()
			var scale: float = float(items["heights"][n]) / float(info["height"])
			cylinder.radius = float(info["trunk"]) * scale
			cylinder.height = 3.0
			shape.shape = cylinder
			shape.position = p + Vector3(0.0, 1.2, 0.0)
			body.add_child(shape)
			colliders += 1

	for key in groups:
		var info: Dictionary = _species[key[0]]
		var indices: PackedInt32Array = groups[key]
		var multimesh: MultiMesh = MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.mesh = info["mesh"]
		multimesh.use_colors = bool(info["hardwood"])
		multimesh.instance_count = indices.size()

		for m in range(indices.size()):
			var n: int = indices[m]
			var scale: float = float(items["heights"][n]) / float(info["height"])
			var basis: Basis = Basis(Vector3.UP, float(items["yaws"][n])).scaled(Vector3.ONE * scale)
			# Sunk a little so slopes do not show a gap under the trunk.
			multimesh.set_instance_transform(m, Transform3D(basis, items["positions"][n] - Vector3(0.0, 0.15, 0.0)))

			if info["hardwood"]:
				multimesh.set_instance_color(m, _autumn_color(ids[n]))

		var draw: MultiMeshInstance3D = MultiMeshInstance3D.new()
		draw.multimesh = multimesh
		draw.visibility_range_end = view_m[info["kind"]] + 0.7 * PART_M[info["kind"]]
		draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if info["kind"] == KIND_TREE else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(draw)
		instances += indices.size()

	entry["drawn"] = _drawn_count(node)


func _clear_node(entry: Dictionary) -> void:
	var node: Node3D = entry.get("node")

	if node == null:
		return

	for child in node.get_children():
		if child is MultiMeshInstance3D:
			instances -= child.multimesh.instance_count
		elif child is StaticBody3D:
			colliders -= child.get_child_count()

	node.queue_free()
	entry["node"] = null


static func _drawn_count(node: Node3D) -> int:
	var total: int = 0

	for child in node.get_children():
		if child is MultiMeshInstance3D:
			total += child.multimesh.instance_count

	return total


# Distance from the player to the nearest point of a chunk (flat).
func _distance(chunk: Vector2i, position: Vector3) -> float:
	var x0: float = float(chunk.x) * chunk_m
	var z0: float = float(chunk.y) * chunk_m
	var dx: float = maxf(maxf(x0 - position.x, position.x - (x0 + chunk_m)), 0.0)
	var dz: float = maxf(maxf(z0 - position.z, position.z - (z0 + chunk_m)), 0.0)
	return sqrt(dx * dx + dz * dz)


# One autumn leaf color per hardwood tree, fixed by the tree's id so it
# looks the same for every player and every visit.
func _autumn_color(id: int) -> Color:
	var mix: int = (id * 2654435761) & 0x7fffffff
	var base: Color = AUTUMN[mix % AUTUMN.size()]
	var shade: float = 0.9 + 0.2 * float((mix >> 8) % 100) / 100.0
	return Color(minf(base.r * shade, 1.0), minf(base.g * shade, 1.0), minf(base.b * shade, 1.0))


# ---------------------------------------------------------------- meshes

# A stand-in mesh for a species at its reference height `h`.
func _make_mesh(entry: Dictionary, h: float) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var color: Array = entry["color"]
	var leaf: StandardMaterial3D = StandardMaterial3D.new()
	leaf.albedo_color = Color(float(color[0]), float(color[1]), float(color[2]))
	leaf.roughness = 1.0
	var broadleaf: bool = str(entry["shape"]) == "broadleaf"

	if broadleaf:
		# Each tree brings its own leaf color (multimesh instance color).
		leaf.albedo_color = Color.WHITE
		leaf.vertex_color_use_as_albedo = true
	var crown: float = float(entry["crown_m"])
	var trunk: float = maxf(float(entry["trunk_m"]), 0.03)

	match str(entry["shape"]):
		"broadleaf":
			_add(mesh, _cylinder(trunk * 0.7, trunk, h * 0.6, 6), Vector3(0.0, h * 0.3, 0.0), _hardwood_material)
			_add(mesh, _sphere(crown, minf(crown * 1.7, h * 0.75), 8, 5), Vector3(0.0, h - minf(crown * 0.85, h * 0.375), 0.0), leaf)
		"conifer":
			_add(mesh, _cylinder(trunk * 0.5, trunk, h * 0.35, 6), Vector3(0.0, h * 0.175, 0.0), _softwood_material)
			_add(mesh, _cylinder(0.0, crown, h * 0.82, 8), Vector3(0.0, h * 0.59, 0.0), leaf)
		"palm":
			_add(mesh, _cylinder(trunk * 0.8, trunk, h, 6), Vector3(0.0, h * 0.5, 0.0), _trunk_material)
			_add(mesh, _sphere(crown, crown * 0.6, 8, 4), Vector3(0.0, h, 0.0), leaf)
		"cactus":
			_add(mesh, _cylinder(trunk, trunk, h, 8), Vector3(0.0, h * 0.5, 0.0), leaf)
		"shrub":
			_add(mesh, _sphere(crown, h, 7, 4), Vector3(0.0, h * 0.5, 0.0), leaf)
		"mushroom":
			_add(mesh, _cylinder(0.03, 0.04, h * 0.7, 5), Vector3(0.0, h * 0.35, 0.0), _trunk_material)
			_add(mesh, _sphere(crown * 0.5, h * 0.4, 6, 3), Vector3(0.0, h * 0.75, 0.0), leaf)
		"fern":
			_add(mesh, _sphere(crown, h, 6, 3), Vector3(0.0, h * 0.4, 0.0), leaf)
		_:
			# grass, reed, flower: a thin cone tuft.
			_add(mesh, _cylinder(0.0, crown, h, 5), Vector3(0.0, h * 0.5, 0.0), leaf)

	return mesh


static func _cylinder(top: float, bottom: float, height: float, sides: int) -> PrimitiveMesh:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = sides
	cylinder.rings = 1
	return cylinder


static func _sphere(radius: float, height: float, sides: int, rings: int) -> PrimitiveMesh:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = height
	sphere.radial_segments = sides
	sphere.rings = rings
	return sphere


static func _add(mesh: ArrayMesh, part: PrimitiveMesh, offset: Vector3, material: Material) -> void:
	var arrays: Array = part.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]

	for n in range(vertices.size()):
		vertices[n] += offset

	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
