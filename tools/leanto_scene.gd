extends Node3D

# The lean-to with a rough bed inside and two player-height figures (Kathleen, 2026-10-31): one lying on the bed, one standing near the open front, for tools/shot_node.gd.
#   godot --path . --script res://tools/shot_node.gd -- --script=res://tools/leanto_scene.gd --out=C:/temp/leanto.png --height=2.2 --pitch=-15

const BuildingLook := preload("res://src/client/building_look.gd")
const PieceLook := preload("res://src/client/piece_look.gd")


func _figure(height: float, lying: bool, at: Vector3) -> void:
	var skin: StandardMaterial3D = StandardMaterial3D.new()
	skin.albedo_color = Color(0.7, 0.45, 0.35)
	var cloth: StandardMaterial3D = StandardMaterial3D.new()
	cloth.albedo_color = Color(0.3, 0.38, 0.5)
	var body: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.2
	capsule.height = height - 0.25
	capsule.material = cloth
	body.mesh = capsule
	var head: MeshInstance3D = MeshInstance3D.new()
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 0.11
	ball.height = 0.22
	ball.material = skin
	head.mesh = ball
	var root: Node3D = Node3D.new()
	root.position = at
	body.position = Vector3(0.0, (height - 0.25) * 0.5, 0.0)
	head.position = Vector3(0.0, height - 0.11, 0.0)
	root.add_child(body)
	root.add_child(head)

	if lying:
		root.rotation = Vector3(0.0, 0.0, -PI * 0.5)

	add_child(root)


func _crawler(at: Vector3) -> void:
	var cloth: StandardMaterial3D = StandardMaterial3D.new()
	cloth.albedo_color = Color(0.5, 0.35, 0.3)
	var body: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.16
	capsule.height = 1.1
	capsule.material = cloth
	body.mesh = capsule
	body.rotation = Vector3(PI * 0.5, 0.0, 0.0)
	body.position = at + Vector3(0.0, 0.5, -0.4)
	add_child(body)
	var head: MeshInstance3D = MeshInstance3D.new()
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 0.11
	ball.height = 0.22
	head.mesh = ball
	head.position = at + Vector3(0.0, 0.6, -1.0)
	add_child(head)


func _init() -> void:
	add_child(BuildingLook.leanto())
	var bed: Node3D = PieceLook.rough_bed()
	bed.position = Vector3(0.0, 0.0, 0.2)
	add_child(bed)
	_figure(1.75, true, Vector3(-0.9, 0.55, 0.2))     # lying on the bed, feet at the left end, head to the right
	_figure(1.75, false, Vector3(-1.9, 0.0, 0.9))      # standing beside the front upright
	_crawler(Vector3(1.6, 0.0, 1.1))                    # crawling in at the front
