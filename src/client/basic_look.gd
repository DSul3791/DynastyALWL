extends RefCounted

# Stage-one models (Kathleen, art/MODEL_PLAN.md): any loose item drawn from a small shape and a colour, so every item has a look before
# any item gets a good one. `data/items/looks.json` maps an item id to {shape, color, size}; `mesh()` returns one vertex-coloured ArrayMesh
# (under 150 triangles, one shared material) centred on its middle with the underside near y = -0.06 * size. Upgrading an item later means
# deleting its looks.json entry or giving it a real model; nothing here changes.

const LOOKS_PATH := "res://data/items/looks.json"

static var _table: Dictionary = {}
static var _loaded: bool = false
static var _material: StandardMaterial3D


# The looks table, read once: item id -> {shape, color, size}. A missing or broken file means no entries (everything keeps its old look).
static func entry(item_id: String) -> Dictionary:
	if not _loaded:
		_loaded = true
		var file: FileAccess = FileAccess.open(LOOKS_PATH, FileAccess.READ)

		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())

			if parsed is Dictionary:
				_table = parsed.get("items", {})

	return _table.get(item_id, {})


static func has_look(item_id: String) -> bool:
	return not entry(item_id).is_empty()


static func mesh_for(item_id: String) -> Mesh:
	var def: Dictionary = entry(item_id)

	if def.is_empty():
		return null

	return mesh(str(def.get("shape", "chunk")), Color.html(str(def.get("color", "#8a8a8a"))), float(def.get("size", 1.0)))


static func mesh(shape: String, color: Color, size: float = 1.0) -> ArrayMesh:
	var parts: Array = []

	if shape not in ["bone", "coil", "coin", "ingot"]:
		color = Color.from_hsv(color.h, minf(color.s * 1.35, 1.0), minf(color.v * 1.08, 1.0))      # bolder colours so loose items tell apart on the grass (Dave 2026-10-22)
	var dark: Color = color.darkened(0.35)
	var light: Color = color.lightened(0.25)

	match shape:
		"sack":
			_sph(parts, 0.1, Vector3(1.0, 1.1, 1.0), Vector3(0.0, 0.0, 0.0), color)
			_cyl(parts, 0.04, 0.05, Vector3(0.0, 0.11, 0.0), Vector3.ZERO, dark)
		"ingot":
			_box(parts, Vector3(0.24, 0.05, 0.1), Vector3(0.0, -0.035, 0.0), color)
			_box(parts, Vector3(0.2, 0.03, 0.07), Vector3(0.0, 0.0, 0.0), light)
		"pile":
			_sph(parts, 0.15, Vector3(1.0, 0.45, 1.0), Vector3(0.0, -0.03, 0.0), color)
			_sph(parts, 0.06, Vector3(1.0, 0.7, 1.0), Vector3(0.07, 0.03, 0.03), light)
			_sph(parts, 0.05, Vector3(1.0, 0.7, 1.0), Vector3(-0.06, 0.02, -0.05), dark)
		"chunk":
			_sph(parts, 0.08, Vector3(1.0, 0.8, 1.1), Vector3(0.0, -0.02, 0.0), color)
			_sph(parts, 0.055, Vector3(1.0, 0.8, 1.0), Vector3(0.08, -0.03, 0.04), dark)
			_sph(parts, 0.05, Vector3(1.0, 0.9, 1.0), Vector3(-0.05, -0.02, 0.07), light)
		"bundle":
			_cyl(parts, 0.055, 0.34, Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), color)
			_cyl(parts, 0.06, 0.03, Vector3(-0.07, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), dark)
			_cyl(parts, 0.06, 0.03, Vector3(0.07, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), dark)
		"planks":
			for k in 4:
				_box(parts, Vector3(0.5, 0.025, 0.13), Vector3(0.01 * float(k % 2), -0.04 + 0.028 * float(k), 0.0), color.lightened(0.04 * float(k % 2)))
		"beams":
			_box(parts, Vector3(0.55, 0.07, 0.07), Vector3(0.0, -0.035, -0.04), color)
			_box(parts, Vector3(0.55, 0.07, 0.07), Vector3(0.0, -0.035, 0.04), dark)
			_box(parts, Vector3(0.55, 0.07, 0.07), Vector3(0.0, 0.035, 0.0), color.lightened(0.05))
		"hide":
			_sph(parts, 0.17, Vector3(1.0, 0.08, 0.75), Vector3(0.0, -0.05, 0.0), color)
			_sph(parts, 0.1, Vector3(1.0, 0.09, 0.6), Vector3(0.04, -0.03, 0.0), dark)
		"coil":
			_torus(parts, 0.07, 0.02, Vector3(0.0, -0.03, 0.0), color)
			_torus(parts, 0.07, 0.02, Vector3(0.0, 0.0, 0.0), dark)
		"bone":
			_cyl(parts, 0.018, 0.22, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), color)
			_sph(parts, 0.035, Vector3.ONE, Vector3(-0.11, 0.0, 0.015), color)
			_sph(parts, 0.035, Vector3.ONE, Vector3(-0.11, 0.0, -0.015), color)
			_sph(parts, 0.035, Vector3.ONE, Vector3(0.11, 0.0, 0.015), color)
			_sph(parts, 0.035, Vector3.ONE, Vector3(0.11, 0.0, -0.015), color)
		"feather":
			_box(parts, Vector3(0.22, 0.006, 0.06), Vector3(0.0, -0.05, 0.0), color)
			_box(parts, Vector3(0.24, 0.01, 0.008), Vector3(0.0, -0.045, 0.0), dark)
		"bark":
			_box(parts, Vector3(0.3, 0.02, 0.16), Vector3(0.0, -0.04, 0.0), color)
			_box(parts, Vector3(0.3, 0.02, 0.05), Vector3(0.0, -0.025, 0.06), dark)
		"leaves":
			_sph(parts, 0.13, Vector3(1.0, 0.35, 1.0), Vector3(0.0, -0.04, 0.0), color)
			_sph(parts, 0.09, Vector3(1.0, 0.4, 1.0), Vector3(0.03, 0.0, -0.02), light)
		"bottle":
			_cyl(parts, 0.045, 0.14, Vector3(0.0, -0.01, 0.0), Vector3.ZERO, color)
			_cyl(parts, 0.02, 0.07, Vector3(0.0, 0.095, 0.0), Vector3.ZERO, color)
			_cyl(parts, 0.022, 0.025, Vector3(0.0, 0.14, 0.0), Vector3.ZERO, dark)
		"loaf":
			_sph(parts, 0.1, Vector3(1.3, 0.55, 0.8), Vector3(0.0, -0.025, 0.0), color)
			_sph(parts, 0.07, Vector3(1.2, 0.3, 0.6), Vector3(0.0, 0.01, 0.0), light)
		"fruit":
			_sph(parts, 0.07, Vector3(1.0, 0.9, 1.0), Vector3(0.0, -0.01, 0.0), color)
			_cyl(parts, 0.006, 0.04, Vector3(0.0, 0.055, 0.0), Vector3.ZERO, Color(0.3, 0.22, 0.12))
		"bowl":
			_cyl(parts, 0.1, 0.05, Vector3(0.0, -0.04, 0.0), Vector3.ZERO, dark)
			_cyl(parts, 0.085, 0.012, Vector3(0.0, -0.012, 0.0), Vector3.ZERO, color)
		"fish":
			_sph(parts, 0.09, Vector3(1.9, 0.6, 0.55), Vector3(0.0, -0.03, 0.0), color)
			_box(parts, Vector3(0.07, 0.012, 0.09), Vector3(0.2, -0.03, 0.0), dark)
			_sph(parts, 0.07, Vector3(1.6, 0.3, 0.5), Vector3(0.0, -0.05, 0.0), light)
		"meat":
			_sph(parts, 0.09, Vector3(1.2, 0.7, 0.9), Vector3(0.0, -0.02, 0.0), color)
			_sph(parts, 0.05, Vector3(1.0, 0.8, 1.0), Vector3(0.07, 0.0, 0.03), dark)
			_cyl(parts, 0.012, 0.09, Vector3(-0.1, -0.02, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.88, 0.85, 0.78))
		"skewer":
			_cyl(parts, 0.008, 0.4, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), Color(0.4, 0.28, 0.16))

			for k in 3:
				_sph(parts, 0.04, Vector3.ONE, Vector3(-0.09 + 0.09 * float(k), 0.0, 0.0), color if k != 1 else dark)
		"coin":
			_cyl(parts, 0.035, 0.008, Vector3(0.0, -0.05, 0.0), Vector3.ZERO, color)
			_cyl(parts, 0.027, 0.01, Vector3(0.0, -0.05, 0.0), Vector3.ZERO, light)
		"cloth":
			_box(parts, Vector3(0.26, 0.04, 0.2), Vector3(0.0, -0.04, 0.0), color)
			_box(parts, Vector3(0.22, 0.03, 0.16), Vector3(0.01, -0.005, 0.0), light)
			_box(parts, Vector3(0.18, 0.025, 0.12), Vector3(0.0, 0.02, 0.0), color)
		"shaft":
			# A spear: a long shaft and a long, plainly pointed cone head at the +x end (Dave: it must be pointy).
			_cyl(parts, 0.016, 0.9, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), Color(0.42, 0.3, 0.17))
			_cone(parts, 0.045, 0.28, Vector3(0.58, 0.0, 0.0), color)
			_cyl(parts, 0.024, 0.04, Vector3(0.43, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.8, 0.7, 0.4))   # the binding below the head
		"axe":
			_handle(parts, 0.5)
			_box(parts, Vector3(0.1, 0.12, 0.04), Vector3(0.22, 0.0, 0.0), color)
		"pick":
			_handle(parts, 0.6)
			_box(parts, Vector3(0.04, 0.04, 0.3), Vector3(0.27, 0.0, 0.0), color)
		"spade":
			_handle(parts, 0.7)
			_box(parts, Vector3(0.12, 0.03, 0.16), Vector3(0.38, 0.0, 0.0), color)
		"knife":
			_handle(parts, 0.14)
			_box(parts, Vector3(0.13, 0.015, 0.035), Vector3(0.12, 0.0, 0.0), color)
		"needle":
			_cyl(parts, 0.004, 0.12, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), color)
		"rod":
			_cyl(parts, 0.008, 0.9, Vector3.ZERO, Vector3(0.0, 0.0, PI * 0.5), Color(0.4, 0.3, 0.18))
			_cyl(parts, 0.025, 0.04, Vector3(-0.3, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), color)
		"torch":
			_handle(parts, 0.5)
			_sph(parts, 0.04, Vector3(1.0, 1.4, 1.0), Vector3(0.27, 0.0, 0.0), color)
		"pot":
			_sph(parts, 0.1, Vector3(1.0, 0.9, 1.0), Vector3(0.0, -0.01, 0.0), color)
			_cyl(parts, 0.06, 0.03, Vector3(0.0, 0.085, 0.0), Vector3.ZERO, dark)
		"bucket":
			_cyl(parts, 0.1, 0.18, Vector3.ZERO, Vector3.ZERO, color)
			_cyl(parts, 0.103, 0.015, Vector3(0.0, 0.04, 0.0), Vector3.ZERO, dark)
			_cyl(parts, 0.103, 0.015, Vector3(0.0, -0.04, 0.0), Vector3.ZERO, dark)
		"skin":
			_sph(parts, 0.09, Vector3(1.0, 1.3, 0.7), Vector3.ZERO, color)
			_cyl(parts, 0.02, 0.06, Vector3(0.0, 0.12, 0.0), Vector3.ZERO, dark)
		"kit":
			_box(parts, Vector3(0.3, 0.12, 0.2), Vector3(0.0, -0.01, 0.0), color)
			_box(parts, Vector3(0.31, 0.02, 0.21), Vector3(0.0, 0.0, 0.0), dark)
			_box(parts, Vector3(0.02, 0.13, 0.21), Vector3(0.0, 0.0, 0.0), light)
		_:
			_sph(parts, 0.08, Vector3.ONE, Vector3.ZERO, color)

	return _combine(parts, size)


# A wooden handle lying along x, centred on the middle of a tool of this length (the head is added at its +x end).
static func _handle(parts: Array, length: float) -> void:
	_cyl(parts, 0.016, length, Vector3(-length * 0.05, 0.0, 0.0), Vector3(0.0, 0.0, PI * 0.5), Color(0.42, 0.3, 0.17))


static func _box(parts: Array, dims: Vector3, at: Vector3, color: Color) -> void:
	var box: BoxMesh = BoxMesh.new()
	box.size = dims
	parts.append([box, Transform3D(Basis.IDENTITY, at), color])


static func _cyl(parts: Array, radius: float, height: float, at: Vector3, tilt: Vector3, color: Color) -> void:
	var cyl: CylinderMesh = CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 8
	cyl.rings = 1
	parts.append([cyl, Transform3D(Basis.from_euler(tilt), at), color])


# A cone along x with its point at +x.
static func _cone(parts: Array, radius: float, length: float, at: Vector3, color: Color) -> void:
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = radius
	cone.height = length
	cone.radial_segments = 6
	cone.rings = 1
	parts.append([cone, Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -PI * 0.5)), at), color])


static func _sph(parts: Array, radius: float, scale_v: Vector3, at: Vector3, color: Color) -> void:
	var sph: SphereMesh = SphereMesh.new()
	sph.radius = radius
	sph.height = radius * 2.0
	sph.radial_segments = 8
	sph.rings = 4
	parts.append([sph, Transform3D(Basis.from_scale(scale_v), at), color])


static func _torus(parts: Array, ring: float, tube: float, at: Vector3, color: Color) -> void:
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = ring - tube
	torus.outer_radius = ring + tube
	torus.rings = 10
	torus.ring_segments = 5
	parts.append([torus, Transform3D(Basis.IDENTITY, at), color])


static func _combine(parts: Array, size: float) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	for part in parts:
		var arrays: Array = (part[0] as PrimitiveMesh).get_mesh_arrays()
		var xform: Transform3D = part[1]
		var color: Color = part[2]
		var first: int = vertices.size()
		var source: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var source_n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]

		for i in source.size():
			vertices.append(xform * source[i] * size)
			normals.append((xform.basis * source_n[i]).normalized())
			colors.append(color)

		for index in arrays[Mesh.ARRAY_INDEX]:
			indices.append(first + int(index))

	var out: Array = []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = vertices
	out[Mesh.ARRAY_NORMAL] = normals
	out[Mesh.ARRAY_COLOR] = colors
	out[Mesh.ARRAY_INDEX] = indices
	var result: ArrayMesh = ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	result.surface_set_material(0, _shared_material())
	return result


static func _shared_material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 1.0

	return _material
