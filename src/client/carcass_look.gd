extends RefCounted

# A dead animal lying on its side (Kathleen, goal 2 batch A). `build(species)` returns a Node3D whose origin is on the ground in the middle of the body, nose toward -Z, from the row of
# data/animals/carcass.json: ellipsoid body with a pale belly, four straight legs, neck and head, tail, antlers or a beak where the species has them. Meshes and materials are shared.
# About 300-390 triangles per carcass. The ground model is the only thing that changes: ids, collision and the carry weight stay as they were.

const PATH := "res://data/animals/carcass.json"

static var _rows: Dictionary = {}
static var _loaded: bool = false
static var _meshes: Dictionary = {}
static var _materials: Dictionary = {}


static func row(species: String) -> Dictionary:
	if not _loaded:
		_loaded = true
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))

		if parsed is Dictionary:
			_rows = parsed.get("species", {})

	return _rows.get(species, _rows.get("deer", {}))


static func _mesh(shape: String) -> Mesh:
	if not _meshes.has(shape):
		var mesh: Mesh

		if shape == "box":
			var box: BoxMesh = BoxMesh.new()
			box.size = Vector3.ONE
			mesh = box
		elif shape == "cyl":
			var cyl: CylinderMesh = CylinderMesh.new()
			cyl.top_radius = 0.5
			cyl.bottom_radius = 0.5
			cyl.height = 1.0
			cyl.radial_segments = 6
			cyl.rings = 1
			cyl.cap_top = false
			cyl.cap_bottom = false
			mesh = cyl
		elif shape == "cone":
			var cone: CylinderMesh = CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.5
			cone.height = 1.0
			cone.radial_segments = 6
			cone.rings = 1
			mesh = cone
		else:
			var sph: SphereMesh = SphereMesh.new()
			sph.radius = 0.5
			sph.height = 1.0
			sph.radial_segments = 6
			sph.rings = 3
			mesh = sph

		_meshes[shape] = mesh

	return _meshes[shape]


static func _material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()

	if not _materials.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		_materials[key] = m

	return _materials[key]


static func _part(root: Node3D, shape: String, at: Vector3, size: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var node: MeshInstance3D = MeshInstance3D.new()
	node.mesh = _mesh(shape)
	node.material_override = _material(color)
	node.transform = Transform3D(Basis.from_euler(rot).scaled(size), at)
	root.add_child(node)


static func build(species: String) -> Node3D:
	var d: Dictionary = row(species)
	var root: Node3D = Node3D.new()
	var length: float = float(d["len"])
	var width: float = float(d["width"])
	var height: float = float(d["height"])
	var leg: float = float(d["legs"])
	var head: float = float(d["head"])
	var neck: float = float(d["neck"])
	var coat: Color = Color.html(str(d["coat"]))
	var pale: Color = Color.html(str(d["pale"]))
	var dark: Color = coat.darkened(0.35)
	var lift: float = width * 0.5          # on its side the body stands as high as it is wide

	_part(root, "sph", Vector3(0.0, lift, 0.0), Vector3(height, width, length), coat)
	_part(root, "sph", Vector3(height * 0.28, lift * 0.9, 0.0), Vector3(height * 0.5, width * 0.7, length * 0.8), pale)   # the belly, turned up and out

	# Legs stick straight out sideways from shoulder and hip, a little drooped.
	for z in [-length * 0.32, length * 0.32]:
		for k in range(2):
			var spread: float = float(k) * 0.06
			_part(root, "cyl", Vector3(height * 0.5 + leg * 0.45, lift + width * 0.15 - float(k) * width * 0.25, z + spread), Vector3(maxf(leg * 0.1, 0.02), leg, maxf(leg * 0.1, 0.02)), dark, Vector3(0.0, 0.0, PI * 0.5 - 0.15))

	# Neck and head reach forward along the ground.
	_part(root, "cyl", Vector3(0.0, lift * 0.9, -length * 0.5 - neck * 0.35), Vector3(width * 0.45, neck, width * 0.45), coat, Vector3(PI * 0.5 - 0.1, 0.0, 0.0))
	var head_at: Vector3 = Vector3(0.0, lift * 0.75, -length * 0.5 - neck * 0.8 - head * 0.4)
	_part(root, "sph", head_at, Vector3(width * 0.45, width * 0.42, head), coat if not bool(d.get("beak", false)) else Color(0.2, 0.4, 0.25))

	if bool(d.get("beak", false)):
		_part(root, "box", head_at + Vector3(0.0, -width * 0.04, -head * 0.6), Vector3(width * 0.2, width * 0.06, head * 0.5), Color(0.85, 0.65, 0.15))

	if bool(d["antlers"]):
		for side in [-1.0, 1.0]:
			_part(root, "cyl", head_at + Vector3(side * width * 0.2, width * 0.35 + head * 0.25, head * 0.25), Vector3(0.025, head * 0.9, 0.025), Color(0.78, 0.72, 0.6), Vector3(0.0, 0.0, side * 0.6))
			_part(root, "cyl", head_at + Vector3(side * width * 0.4, width * 0.5 + head * 0.35, head * 0.1), Vector3(0.02, head * 0.5, 0.02), Color(0.78, 0.72, 0.6), Vector3(0.5, 0.0, side * 0.4))

	var tail: float = float(d["tail"])
	_part(root, "cone", Vector3(0.0, lift * 0.8, length * 0.5 + tail * 0.4), Vector3(width * 0.3, tail, width * 0.3), pale if species == "rabbit" else coat, Vector3(PI * 0.5 + 0.1, 0.0, 0.0))
	return root
