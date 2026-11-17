extends Node3D

# Copper and tin rocks (src/client/ore_rock_look.gd) for tools/shot_node.gd: the game's meshes and materials at the sizes the server lays out,
# on tan gravel, with a 14 cm blue pen for scale like Dave's photos. Front row: the loose Copper ore and Tin ore picked up by hand (their
# basic_look models at the loose-item scale); middle: copper rocks of 20, 40 and 60 cm across and tin rocks of 20, 50 and 80 cm; back: a 2 m
# copper boulder and a 1.6 m tin boulder.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/ore_rock_view.gd --out=C:/temp/ore_rocks.png --height=1.6 --pitch=-35
# Sized and sunk as inventory_view._size_boulder does. Not the game lighting; tools/look_rig.sh at a rock shows that.

const OreRockLook := preload("res://src/client/ore_rock_look.gd")
const BasicLook := preload("res://src/client/basic_look.gd")
const LOOSE_SCALE := 1.8   # inventory_view.BASIC_DROP_SCALE


func _init() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(5.0, 4.0)
	var gravel: StandardMaterial3D = StandardMaterial3D.new()
	gravel.albedo_color = Color(0.66, 0.6, 0.5)
	plane.material = gravel
	ground.mesh = plane
	add_child(ground)

	# [ore, x, z, radius, yaw]
	for spec in [["copper", -1.1, 0.2, 0.1, 0.0], ["copper", -0.75, 0.2, 0.2, 1.0], ["copper", -0.2, 0.2, 0.3, 2.0], ["tin", 0.3, 0.2, 0.1, 0.0], ["tin", 0.7, 0.2, 0.25, 1.0], ["tin", 1.35, 0.2, 0.4, 2.0], ["copper", -0.8, -1.3, 1.0, 2.0], ["tin", 0.9, -1.3, 0.8, 1.0]]:
		var mesh: ArrayMesh = OreRockLook.mesh_for(float(spec[4]))
		var box: AABB = mesh.get_aabb()
		var lump: MeshInstance3D = MeshInstance3D.new()
		lump.mesh = mesh
		lump.material_override = OreRockLook.material(str(spec[0]))
		var scale_by: float = float(spec[3]) / maxf(maxf(box.size.x, box.size.z) * 0.5, 0.01)
		lump.scale = Vector3.ONE * scale_by
		lump.position = Vector3(float(spec[1]), -(box.position.y + box.size.y * 0.2) * scale_by, float(spec[2]))
		lump.rotation.y = float(spec[4]) * 1.7
		add_child(lump)

	for loose in [["copper_ore", -0.5, 0.75], ["tin_ore", 0.5, 0.75]]:
		var drop: MeshInstance3D = MeshInstance3D.new()
		drop.mesh = BasicLook.mesh_for(str(loose[0]))
		drop.scale = Vector3.ONE * LOOSE_SCALE
		drop.position = Vector3(float(loose[1]), 0.16, float(loose[2]))   # where the game puts a loose item: ground + 0.12 (server) + 0.04 (_dress_item)
		add_child(drop)

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
	pen.position = Vector3(0.0, 0.006, 0.75)
	add_child(pen)
