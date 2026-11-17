extends Node3D

# Close-up of the loose Tin ore (the glassy river tin stone, src/client/basic_look.gd "tin_glass") for tools/shot_node.gd: the stone as the
# game draws it (BASIC_DROP_SCALE, lifted as a loose item), beside a loose Copper ore and a 14 cm blue pen for scale, on a small patch of gravel.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/tin_stone_view.gd --out=C:/temp/tin_stone.png --height=0.22 --pitch=-30
# The shot's sun gives the highlight; the game's sky reflection is not in it (tools/look_rig.sh shows that).

const BasicLook := preload("res://src/client/basic_look.gd")
const LOOSE_SCALE := 1.8   # inventory_view.BASIC_DROP_SCALE
const LOOSE_LIFT_M := 0.16   # ground + 0.12 (server) + 0.04 (inventory_view._dress_item)


func _init() -> void:
	var ground: MeshInstance3D = MeshInstance3D.new()
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(0.36, 0.3)
	var gravel: StandardMaterial3D = StandardMaterial3D.new()
	gravel.albedo_color = Color(0.66, 0.6, 0.5)
	plane.material = gravel
	ground.mesh = plane
	add_child(ground)

	for loose in [["tin_ore", 0.0, 0.0], ["copper_ore", -0.15, -0.06]]:
		var drop: MeshInstance3D = MeshInstance3D.new()
		drop.mesh = BasicLook.mesh_for(str(loose[0]))
		drop.scale = Vector3.ONE * LOOSE_SCALE
		drop.position = Vector3(float(loose[1]), LOOSE_LIFT_M, float(loose[2]))
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
	pen.rotation = Vector3(0.0, 0.3, PI * 0.5)
	pen.position = Vector3(0.02, 0.006, 0.09)
	add_child(pen)
