extends RefCounted
# The look of the building pieces (Radar, 2026-10-22; Dave: a full wall, floor and roof kit so players design their own houses).
# Placeholder boxes until Art draws them: a plank wall 2 m wide and 2.4 m high, a plank floor 2 by 2 m, a roof slab 2.4 m square at
# 2.5 m with four short posts. Each piece is solid (a StaticBody3D box) so you walk round a wall and stand on a floor. Pieces turn in
# quarter circles and sit on a 1 m grid (placement_rules.gd snap), so neighbours meet edge to edge.

const WOOD := Color(0.45, 0.32, 0.19)
const WOOD_DARK := Color(0.33, 0.23, 0.13)

static var _planks: StandardMaterial3D
static var _frame: StandardMaterial3D


static func _materials() -> void:
	if _planks != null:
		return

	_planks = StandardMaterial3D.new()
	_planks.albedo_color = WOOD
	_planks.roughness = 1.0
	_frame = StandardMaterial3D.new()
	_frame.albedo_color = WOOD_DARK
	_frame.roughness = 1.0


static func _box(parent: Node3D, size: Vector3, at: Vector3, material: StandardMaterial3D) -> void:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var shape: BoxMesh = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material
	mesh.position = at
	parent.add_child(mesh)


static func _solid(parent: Node3D, size: Vector3, at: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = at
	body.add_child(shape)
	parent.add_child(body)


# 2 m wide along X, 0.2 m thick, 2.4 m high, with a frame post at each end and a rail across the top.
static func wall() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.0, 2.4, 0.14), Vector3(0.0, 1.2, 0.0), _planks)

	for x in [-0.95, 0.95]:
		_box(root, Vector3(0.1, 2.4, 0.2), Vector3(x, 1.2, 0.0), _frame)

	_box(root, Vector3(2.0, 0.1, 0.2), Vector3(0.0, 2.35, 0.0), _frame)
	_solid(root, Vector3(2.0, 2.4, 0.2), Vector3(0.0, 1.2, 0.0))
	return root


# 2 by 2 m, 0.12 m thick, its top 0.12 m above the ground (a step you walk up).
static func floor_piece() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.0, 0.12, 2.0), Vector3(0.0, 0.06, 0.0), _planks)

	for x in [-0.66, 0.0, 0.66]:
		_box(root, Vector3(0.02, 0.125, 2.0), Vector3(x, 0.06, 0.0), _frame)

	_solid(root, Vector3(2.0, 0.12, 2.0), Vector3(0.0, 0.06, 0.0))
	return root


# A 2.4 m square slab 2.5 m up on four posts.
static func roof() -> Node3D:
	_materials()
	var root: Node3D = Node3D.new()
	_box(root, Vector3(2.4, 0.12, 2.4), Vector3(0.0, 2.5, 0.0), _planks)

	for x in [-1.1, 1.1]:
		for z in [-1.1, 1.1]:
			_box(root, Vector3(0.12, 2.5, 0.12), Vector3(x, 1.25, z), _frame)

	_solid(root, Vector3(2.4, 0.12, 2.4), Vector3(0.0, 2.5, 0.0))
	return root
