extends Node3D

# Animals on the client (protocol 48): a simple low-poly rabbit until Art makes a real one (brown body, head, two ears, white
# tail). The server sends rows about four times a second; the view glides to each, faces the way it goes and hops while moving
# (higher and quicker when it bolts). At most MAX_DRAWN are drawn, the nearest ones (the server already sends only 30 within 120 m).

const MAX_DRAWN := 30
const GRAZE := 0
const HOP := 1
const FLEE := 2

var _bodies: Dictionary = {}     # id -> {node, target Vector3, heading, state, phase}
var _mats: Dictionary = {}
var _t: float = 0.0


func on_rows(rows: Array) -> void:
	var seen: Dictionary = {}

	for row in rows:
		var id: int = int(row[0])
		seen[id] = true

		if not _bodies.has(id):
			if _bodies.size() >= MAX_DRAWN:
				continue

			var node: Node3D = _make_deer() if int(row[1]) == 2 else _make_rabbit()
			node.position = row[2]
			add_child(node)
			_bodies[id] = {"node": node, "target": row[2], "heading": float(row[3]), "state": int(row[4]), "phase": float(id % 7), "deer": int(row[1]) == 2}

		_bodies[id]["target"] = row[2]
		_bodies[id]["heading"] = float(row[3])
		_bodies[id]["state"] = int(row[4])

	for id in _bodies.keys():
		if not seen.has(id):
			_bodies[id]["node"].queue_free()
			_bodies.erase(id)


func drawn_count() -> int:
	return _bodies.size()


func _process(delta: float) -> void:
	_t += delta

	for id in _bodies:
		var b: Dictionary = _bodies[id]
		var node: Node3D = b["node"]
		var state: int = b["state"]
		node.position = node.position.lerp(b["target"], clampf(delta * (10.0 if state == FLEE else 5.0), 0.0, 1.0))
		node.rotation.y = lerp_angle(node.rotation.y, -float(b["heading"]) - PI * 0.5, clampf(delta * 10.0, 0.0, 1.0))
		var rig: Node3D = node.get_node("Rig")
		var rate: float = 9.0 if state == FLEE else 5.0
		var big: bool = bool(b.get("deer", false))
		var lift: float = ((0.06 if big else 0.22) if state == FLEE else (0.02 if big else 0.1)) * absf(sin(_t * (rate * (0.8 if big else 1.0)) + float(b["phase"]))) if state != GRAZE and state != 3 else 0.0
		rig.position.y = lerp(rig.position.y, lift, clampf(delta * 20.0, 0.0, 1.0))


func _material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()

	if not _mats.has(key):
		var m: StandardMaterial3D = StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 1.0
		_mats[key] = m

	return _mats[key]


func _ball(parent: Node3D, radius: float, scale_v: Vector3, at: Vector3, color: Color) -> void:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	mesh.material = _material(color)
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.scale = scale_v
	inst.position = at
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


# Facing -Z (the heading turns the root). About 0.45 m long, 0.3 m to the ear tips.
func _make_rabbit() -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var fur: Color = Color(0.45, 0.36, 0.26)
	_ball(rig, 0.1, Vector3(1.0, 0.9, 1.6), Vector3(0.0, 0.11, 0.02), fur)
	_ball(rig, 0.065, Vector3(1.0, 1.0, 1.2), Vector3(0.0, 0.19, -0.15), fur)

	for side in [-1.0, 1.0]:
		var ear: MeshInstance3D = MeshInstance3D.new()
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(0.025, 0.11, 0.012)
		box.material = _material(Color(0.5, 0.4, 0.3))
		ear.mesh = box
		ear.position = Vector3(side * 0.025, 0.28, -0.13)
		ear.rotation = Vector3(0.25, 0.0, side * 0.15)
		ear.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		rig.add_child(ear)

	_ball(rig, 0.035, Vector3.ONE, Vector3(0.0, 0.15, 0.19), Color(0.92, 0.9, 0.86))
	return root


func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var inst: MeshInstance3D = MeshInstance3D.new()
	inst.mesh = mesh
	inst.position = at
	inst.rotation = rot
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(inst)


# A deer for now (placeholder until Art): tan body, neck and head, four thin legs, short antlers. About 1.5 m long, 1.2 m to the back.
func _make_deer() -> Node3D:
	var root: Node3D = Node3D.new()
	var rig: Node3D = Node3D.new()
	rig.name = "Rig"
	root.add_child(rig)
	var coat: Color = Color(0.52, 0.38, 0.24)
	_ball(rig, 0.3, Vector3(0.85, 0.85, 1.9), Vector3(0.0, 0.85, 0.0), coat)
	_box(rig, Vector3(0.14, 0.5, 0.16), Vector3(0.0, 1.15, -0.55), coat, Vector3(-0.5, 0.0, 0.0))
	_ball(rig, 0.11, Vector3(0.8, 0.8, 1.4), Vector3(0.0, 1.38, -0.75), coat)
	_ball(rig, 0.05, Vector3.ONE, Vector3(0.0, 0.9, 0.55), Color(0.9, 0.86, 0.8))

	for lx in [-0.12, 0.12]:
		for lz in [-0.38, 0.4]:
			_box(rig, Vector3(0.06, 0.62, 0.06), Vector3(lx, 0.31, lz), Color(0.4, 0.3, 0.2))

	for side in [-1.0, 1.0]:
		_box(rig, Vector3(0.025, 0.28, 0.025), Vector3(side * 0.07, 1.55, -0.75), Color(0.75, 0.7, 0.6), Vector3(0.0, 0.0, side * -0.4))

	return root
