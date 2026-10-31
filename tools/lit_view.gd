extends Node3D

# A lit comfort piece at dusk for tools/shot_node.gd (Kathleen): the real mesh from piece_look.gd, a dark sky, and warm lights with flame cones where the game's code adds the light.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/lit_view.gd --piece=fireplace --out=C:/temp/lit_fireplace.png --height=2.6 --pitch=-10
# --piece= is wall_torch, fireplace or chandelier. A back wall stands behind the torch and the fireplace (z = 0).

const PieceLook := preload("res://src/client/piece_look.gd")


func _flame(at: Vector3, size: float) -> void:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.7, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.55, 0.12)
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var cone: CylinderMesh = CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = size * 0.35
	cone.height = size
	cone.radial_segments = 6
	cone.rings = 1
	cone.material = m
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = cone
	mesh.position = at + Vector3(0.0, size * 0.5, 0.0)
	add_child(mesh)


func _glow(at: Vector3, energy: float, reach: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = at
	light.light_color = Color(1.0, 0.62, 0.28)
	light.light_energy = energy
	light.omni_range = reach
	light.shadow_enabled = true
	add_child(light)


func _wall() -> void:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.45, 0.38)
	m.roughness = 1.0
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(6.0, 3.0, 0.1)
	box.material = m
	var mesh: MeshInstance3D = MeshInstance3D.new()
	mesh.mesh = box
	mesh.position = Vector3(0.0, 1.5, -0.05)
	add_child(mesh)


func _init() -> void:
	var piece: String = "fireplace"

	for a in OS.get_cmdline_user_args():
		if a.begins_with("--piece="):
			piece = a.trim_prefix("--piece=")

	match piece:
		"wall_torch":
			_wall()
			add_child(PieceLook.wall_torch(true))
			_glow(Vector3(0.0, 2.5, 0.6), 2.2, 6.0)
		"chandelier":
			add_child(PieceLook.chandelier())
			_glow(Vector3(0.0, 1.9, 0.0), 2.0, 7.0)

			for k in 6:
				var a: float = TAU * float(k) / 6.0
				_flame(Vector3(cos(a) * 0.34, 1.9, sin(a) * 0.34), 0.08)
		_:
			_wall()
			add_child(PieceLook.fireplace())
			_glow(Vector3(0.0, 0.5, 0.45), 2.6, 6.0)

			for k in 4:
				_flame(Vector3(-0.2 + 0.13 * float(k), 0.1, 0.25 + 0.04 * float(k % 2)), 0.3 - 0.04 * float(k % 2))


func _ready() -> void:
	var vp: Node = get_parent()

	for c in vp.get_children():
		if c is WorldEnvironment:
			var env: Environment = (c as WorldEnvironment).environment
			env.background_color = Color(0.03, 0.04, 0.08)
			env.ambient_light_color = Color(0.1, 0.12, 0.2)
		elif c is DirectionalLight3D:
			(c as DirectionalLight3D).light_energy = 0.12
			(c as DirectionalLight3D).light_color = Color(0.6, 0.7, 1.0)
