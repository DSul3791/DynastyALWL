extends Node
# Float-precision test (Technical direction, 2026-10-20). Esc > Advanced > "Jitter test"
# or F9 flies the player to the next test spot far from the world origin and shows a
# readout plus a row of thin posts 1 cm apart in front of the camera. Far from the
# origin 32-bit floats get coarse; if the posts shimmer, swap places or the view
# wobbles while you stand still or turn, the world needs a floating origin.

const SPOTS: Array = [
	["origin", Vector2(0.0, 0.0)],
	["20 km", Vector2(20000.0, 20000.0)],
	["spawn", Vector2(53233.0, 68448.0)],
	["80 km", Vector2(80000.0, 80000.0)],
	["100 km", Vector2(100000.0, 100000.0)],
]
const HEIGHT := 400.0

var _client
var _label: Label
var _rig: Node3D
var _at: int = -1
var _worst: float = 0.0
var _samples: int = 0


func setup(client) -> void:
	_client = client
	var layer: CanvasLayer = CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(16.0, 120.0)
	_label.add_theme_font_size_override("font_size", 20)
	_label.visible = false
	layer.add_child(_label)
	add_child(layer)


func next_spot() -> void:
	_at = (_at + 1) % SPOTS.size()
	var spot: Vector2 = SPOTS[_at][1]
	_client.flying = true
	_client.body.velocity = Vector3.ZERO
	_client.body.global_position = Vector3(spot.x, HEIGHT, spot.y)
	_worst = 0.0
	_samples = 0

	if _rig != null:
		_rig.queue_free()

	_rig = Node3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.01, 1.0, 0.01)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.2, 0.2)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material

	for i in 30:
		var post: MeshInstance3D = MeshInstance3D.new()
		post.mesh = mesh
		post.position = Vector3(float(i) * 0.02 - 0.3, 0.0, 0.0)
		_rig.add_child(post)

	_client.get_tree().root.add_child(_rig)
	# 3 m in front of where the player looks.
	var fwd: Vector3 = -_client.camera.global_transform.basis.z
	_rig.global_position = _client.body.global_position + Vector3(0.0, 0.7, 0.0) + fwd * 3.0
	_rig.look_at(_rig.global_position + fwd.slide(Vector3.UP).normalized() * -1.0, Vector3.UP)
	print("Jitter test: %s at %s" % [SPOTS[_at][0], str(_client.body.global_position)])


func _process(_delta: float) -> void:
	_label.visible = _at >= 0

	if _at < 0 or _client.body == null:
		return

	var p: Vector3 = _client.body.global_position
	var big: float = maxf(absf(p.x), maxf(absf(p.y), absf(p.z)))
	# Spacing between neighbouring 32-bit floats at that distance.
	var ulp: float = pow(2.0, floorf(log(maxf(big, 1.0)) / log(2.0)) - 23.0)
	# Where the camera is against where the body plus its offset should put it.
	var err: Vector3 = _client.camera.global_position - (p + Vector3(0.0, 0.7, 0.0))
	_worst = maxf(_worst, err.length())
	_samples += 1
	_label.text = "Jitter test: %s  (F9 next spot)\npos %.0f, %.0f, %.0f\nfloat step here: %.2f mm\ncamera offset error: now %.2f mm, worst %.2f mm\nWatch the red posts (1 cm gaps): shimmer or swapping places = jitter" % [
		SPOTS[_at][0], p.x, p.y, p.z, ulp * 1000.0, err.length() * 1000.0, _worst * 1000.0]
