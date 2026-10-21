extends Node3D

# Classic NPCs on the client (protocol 45). Placeholder body until Art dresses the player ragdoll with their outfit: a capsule
# body and a round head with a name above. The server sends rows about four times a second; the view glides to each and lies the
# body down for sleep and lowers it for sitting. At most MAX_DRAWN are drawn (the nearest), nothing is built for the rest.

const MAX_DRAWN := 20
const STAND := 0
const WALK := 1
const SIT := 2
const SLEEP := 3

var roster: Dictionary = {}      # id -> {name, role, outfit}
var _bodies: Dictionary = {}     # id -> {node, target Vector3, heading, state}
var _skin: StandardMaterial3D = null
var _cloth: Dictionary = {}


func on_roster(rows: Array) -> void:
	roster.clear()

	for row in rows:
		roster[str(row[0])] = {"name": str(row[1]), "role": str(row[2]), "outfit": str(row[3])}


func on_rows(rows: Array) -> void:
	var seen: Dictionary = {}

	for row in rows:
		var id: String = str(row[0])
		seen[id] = true

		if not _bodies.has(id):
			if _bodies.size() >= MAX_DRAWN:
				continue

			var node: Node3D = _make_body(id)
			node.position = row[1]
			add_child(node)
			_bodies[id] = {"node": node, "target": row[1], "heading": float(row[2]), "state": int(row[3])}

		_bodies[id]["target"] = row[1]
		_bodies[id]["heading"] = float(row[2])
		_bodies[id]["state"] = int(row[3])

	for id in _bodies.keys():
		if not seen.has(id):
			_bodies[id]["node"].queue_free()
			_bodies.erase(id)


func drawn_count() -> int:
	return _bodies.size()


func _process(delta: float) -> void:
	for id in _bodies:
		var body: Dictionary = _bodies[id]
		var node: Node3D = body["node"]
		var state: int = body["state"]
		node.position = node.position.lerp(body["target"], clampf(delta * 6.0, 0.0, 1.0))
		node.rotation.y = lerp_angle(node.rotation.y, -float(body["heading"]) - PI * 0.5, clampf(delta * 8.0, 0.0, 1.0))
		var rig: Node3D = node.get_node("Rig")
		rig.rotation.x = lerp_angle(rig.rotation.x, -PI * 0.5 if state == SLEEP else 0.0, clampf(delta * 4.0, 0.0, 1.0))
		rig.position.y = lerp(rig.position.y, 0.25 if state == SLEEP else (-0.35 if state == SIT else 0.0), clampf(delta * 4.0, 0.0, 1.0))


func _material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()

	if not _cloth.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		_cloth[key] = m

	return _cloth[key]


func _make_body(id: String) -> Node3D:
	var info: Dictionary = roster.get(id, {})
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var coat: Color = Color(0.36, 0.3, 0.22) if str(info.get("outfit", "")) == "merchant" else (Color(0.3, 0.32, 0.38) if str(info.get("outfit", "")) == "guard" else Color(0.4, 0.34, 0.28))
	var body: MeshInstance3D = MeshInstance3D.new()
	var capsule: CapsuleMesh = CapsuleMesh.new()
	capsule.radius = 0.24
	capsule.height = 1.25
	capsule.material = _material(coat)
	body.mesh = capsule
	body.position = Vector3(0.0, 0.85, 0.0)
	rig.add_child(body)
	var head: MeshInstance3D = MeshInstance3D.new()
	var ball: SphereMesh = SphereMesh.new()
	ball.radius = 0.15
	ball.height = 0.3
	ball.material = _material(Color(0.78, 0.6, 0.48))
	head.mesh = ball
	head.position = Vector3(0.0, 1.62, 0.0)
	rig.add_child(head)
	var label: Label3D = Label3D.new()
	label.text = str(info.get("name", id))
	label.font_size = 48
	label.pixel_size = 0.005
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0.0, 2.05, 0.0)
	label.modulate = Color(1.0, 0.95, 0.8)
	label.outline_size = 8
	root.add_child(label)
	return root
