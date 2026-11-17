extends Node3D

# Copper rocks (src/client/copper_rock_look.gd) for tools/shot_node.gd: the game's mesh and malachite material at the sizes the server lays
# out (radius 0.06 to 0.3 m, and a 1 m mountain-foot boulder behind), on tan gravel, with a 14 cm blue pen for scale like Dave's photo.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/copper_rock_view.gd --out=C:/temp/copper_rocks.png --height=1.2 --pitch=-35
# Sized and sunk as inventory_view._size_boulder does. Not the game lighting; tools/look_rig.sh at a copper rock shows that.

const CopperRockLook := preload("res://src/client/copper_rock_look.gd")


func _init() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(4.0, 3.0)
	var gravel: StandardMaterial3D = StandardMaterial3D.new()
	gravel.albedo_color = Color(0.66, 0.6, 0.5)
	plane.material = gravel
	ground.mesh = plane
	add_child(ground)

	# [x, z, radius, yaw]: the small rocks in a row in front, the big one behind.
	for spec in [[-0.75, 0.3, 0.06, 0.0], [-0.5, 0.3, 0.09, 1.0], [-0.2, 0.3, 0.14, 2.0], [0.2, 0.3, 0.2, 0.0], [0.7, 0.3, 0.3, 1.0], [0.0, -0.9, 1.0, 2.0]]:
		var mesh: ArrayMesh = CopperRockLook.mesh_for(float(spec[3]))
		var box: AABB = mesh.get_aabb()
		var lump: MeshInstance3D = MeshInstance3D.new()
		lump.mesh = mesh
		lump.material_override = CopperRockLook.material()
		var scale_by: float = float(spec[2]) / maxf(maxf(box.size.x, box.size.z) * 0.5, 0.01)
		lump.scale = Vector3.ONE * scale_by
		lump.position = Vector3(float(spec[0]), -(box.position.y + box.size.y * 0.2) * scale_by, float(spec[1]))
		lump.rotation.y = float(spec[3]) * 1.7
		add_child(lump)

	var pen: MeshInstance3D = MeshInstance3D.new()
	var rod: CylinderMesh = CylinderMesh.new()
	rod.top_radius = 0.005
	rod.bottom_radius = 0.005
	rod.height = 0.14
	var blue: StandardMaterial3D = StandardMaterial3D.new()
	blue.albedo_color = Color(0.1, 0.3, 0.85)
	rod.material = blue
	pen.mesh = rod
	pen.rotation = Vector3(0.0, 0.6, PI * 0.5)
	pen.position = Vector3(0.0, 0.006, 0.55)
	add_child(pen)
