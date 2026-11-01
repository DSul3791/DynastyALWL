extends Node3D

# One lit campfire tier at night for tools/shot_node.gd (Kathleen): the real BuildingLook.fire, a ground plane, a 1.8 m post 3 m away for scale and a wall 2.8 m behind.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/fire_tier_view.gd --tier=2 --out=C:/temp/fire2.png --height=1.5 --pitch=-8
# --pot adds the tripod pot over the fire. --tier= is 1 (sticks), 2 (firewood) or 3 (logs).

const BuildingLook := preload("res://src/client/building_look.gd")
const PieceLook := preload("res://src/client/piece_look.gd")


func _slab(size: Vector3, at: Vector3, color: Color) -> void:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	var box: BoxMesh = BoxMesh.new()
	box.size = size
	box.material = m
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)


func _init() -> void:
	var tier: int = 2
	var pot: bool = false

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tier="):
			tier = int(a.trim_prefix("--tier="))
		elif a == "--pot":
			pot = true

	_slab(Vector3(6.0, 0.1, 6.0), Vector3(0.0, -0.05, 0.0), Color(0.22, 0.2, 0.14))
	_slab(Vector3(0.3, 1.8, 0.3), Vector3(-2.0, 0.9, 2.0), Color(0.5, 0.4, 0.3))
	_slab(Vector3(6.0, 3.0, 0.2), Vector3(0.0, 1.5, -2.8), Color(0.45, 0.42, 0.36))
	var fire: Node3D = BuildingLook.fire(true, false, tier)
	add_child(fire)
	fire.get_node("Light").visible = true

	if pot:
		add_child(PieceLook.tripod_pot())


func _ready() -> void:
	var vp: Node = get_parent()

	for c in vp.get_children():
		if c is WorldEnvironment:
			var env: Environment = (c as WorldEnvironment).environment
			env.background_color = Color(0.02, 0.025, 0.05)
			env.ambient_light_color = Color(0.06, 0.07, 0.12)
		elif c is DirectionalLight3D:
			(c as DirectionalLight3D).light_energy = 0.04
			(c as DirectionalLight3D).light_color = Color(0.6, 0.7, 1.0)
