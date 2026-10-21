extends Node3D

# Ocean ice floes around the player (src/shared/ice_floes.gd): a flat collider and a plain white
# slab per floe, TOP_M above the sea, with open water between. Only over the sea (a floe's spot must
# be sea floor deeper than SEA_MIN_M, checked once by a ray when its terrain is loaded) and only
# while the ice cover is up. Art restyles the slab (ice look job); the collider is what matters.

const IceFloes := preload("res://src/shared/ice_floes.gd")

const RANGE_M := 160.0           # floes are made this far round the player
const KEEP_M := 220.0            # and dropped beyond this
const SEA_MIN_M := 1.0           # the sea floor is at least this far below the water at a floe

var seed_value: int = 0
var ground_below: Callable       # (Vector3) -> float, NAN where no ground is loaded
var _floes: Dictionary = {}      # Vector2i cell -> Node3D (a floe), or null (a cell that is not over the sea)
var _material: ShaderMaterial

# The look of a floe (Art direction): snow-dusted white top with blue shadow patches, glassy blue-green sides with vertical
# streaks, hairline cracks. World-space noise, so neighbouring floes differ and nothing repeats; lit by the sun and the
# moon like any solid (no emission). One material for every floe, no textures: about 40 ALU per pixel on a few slabs.
const ICE_SHADER := """
shader_type spatial;
varying vec3 wp;

float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 q = mod(wp.xz, 2048.0);
	vec3 n = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float top = smoothstep(0.55, 0.85, n.y);
	float drift = noise(q / 5.0);
	float cracks = (1.0 - smoothstep(0.0, 0.04, abs(noise(q / 2.3) - 0.5))) * 0.8 + (1.0 - smoothstep(0.0, 0.05, abs(noise(q / 0.8 + 5.0) - 0.5))) * 0.4;
	vec3 snow = mix(vec3(0.93, 0.95, 0.98), vec3(0.70, 0.80, 0.90), smoothstep(0.35, 0.8, drift));
	snow = mix(snow, vec3(0.50, 0.64, 0.76), clamp(cracks, 0.0, 1.0) * 0.55);
	float streak = noise(vec2(q.x * 3.0 + q.y * 3.0, wp.y * 0.6));
	vec3 side = mix(vec3(0.32, 0.55, 0.66), vec3(0.62, 0.82, 0.90), streak);
	ALBEDO = mix(side, snow, top);
	ROUGHNESS = mix(0.12, 0.7, top);
	SPECULAR = mix(0.9, 0.35, top);
}
"""


func _ready() -> void:
	var shader: Shader = Shader.new()
	shader.code = ICE_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader


# Called about once a second with the player's position and the sea's ice cover (Ice.cover).
func update(player: Vector3, cover: float) -> void:
	if cover < IceFloes.MIN_COVER:
		_clear()
		return

	var wanted: Dictionary = {}

	for entry in IceFloes.floes_near(seed_value, player.x, player.z, RANGE_M, cover):
		var cell: Vector2i = Vector2i(int(entry[0]), int(entry[1]))
		var floe: Dictionary = entry[2]
		wanted[cell] = true

		if _floes.has(cell):
			_resize(_floes[cell], floe)
			continue

		var pos: Vector2 = floe["pos"]
		var floor_y: float = float(ground_below.call(Vector3(pos.x, 0.0, pos.y))) if ground_below.is_valid() else NAN

		if is_nan(floor_y):
			continue

		_floes[cell] = _make(floe) if floor_y <= -SEA_MIN_M else null

	for cell in _floes.keys():
		var node: Node3D = _floes[cell]
		var near: bool = wanted.has(cell) or (node != null and Vector2(node.position.x, node.position.z).distance_to(Vector2(player.x, player.z)) < KEEP_M)

		if not near:
			if node != null:
				node.queue_free()

			_floes.erase(cell)
		elif not wanted.has(cell) and node != null:
			node.queue_free()
			_floes.erase(cell)


func floe_count() -> int:
	var n: int = 0

	for cell in _floes:
		if _floes[cell] != null:
			n += 1

	return n


func _clear() -> void:
	for cell in _floes:
		if _floes[cell] != null:
			_floes[cell].queue_free()

	_floes.clear()


func _make(floe: Dictionary) -> Node3D:
	var pos: Vector2 = floe["pos"]
	var radius: float = float(floe["radius"])
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 2          # the ice layer (see flora_view.gd)
	body.collision_mask = 0
	body.position = Vector3(pos.x, IceFloes.TOP_M - IceFloes.THICK_M * 0.5, pos.y)
	body.rotation.y = float(floe["turn"])
	var shape: CollisionShape3D = CollisionShape3D.new()
	var cylinder: CylinderShape3D = CylinderShape3D.new()
	cylinder.radius = radius
	cylinder.height = IceFloes.THICK_M
	shape.shape = cylinder
	body.add_child(shape)
	var slab: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius * 0.96
	mesh.bottom_radius = radius * 0.85
	mesh.height = IceFloes.THICK_M
	mesh.radial_segments = 9
	mesh.rings = 1
	slab.mesh = mesh
	slab.material_override = _material
	body.add_child(slab)
	add_child(body)
	return body


# The cover moved (freezing or melting): the floe grows or shrinks in place.
func _resize(node: Node3D, floe: Dictionary) -> void:
	if node == null:
		return

	var radius: float = float(floe["radius"])
	var shape: CylinderShape3D = (node.get_child(0) as CollisionShape3D).shape
	shape.radius = radius
	var mesh: CylinderMesh = (node.get_child(1) as MeshInstance3D).mesh
	mesh.top_radius = radius * 0.96
	mesh.bottom_radius = radius * 0.85
