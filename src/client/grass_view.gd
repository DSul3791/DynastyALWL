extends Node3D

# Grass near the player (client only, never stored or synced; DESIGN_IDEAS
# Section 4 "Grass"). The ground around the player is cut into square cells.
# Each cell finds the ground with downward rays against the terrain's own
# collision, keeps spots on grass-bearing soil that are gentle, dry and not
# covered by ore or rock, and draws a tuft there. Tufts sway in the wind, fade
# to nothing toward the edge, and are drawn in muted storybook greens tinted
# by the soil. Cells are built a few rays per frame so walking never stalls.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const CELL_M := 6.0
const RAYS_PER_FRAME := 40
const RETRY_MSEC := 1500
const MIN_SLOPE_Y := 0.80                # surface normal y; steeper is bare
const TUFTS_PER_POINT := 3

# Soil ids that carry grass, with how thick (0 to 1).
const GRASS_SOILS := {3: 0.9, 4: 0.5, 5: 1.0, 6: 0.7, 7: 1.0, 8: 0.6, 9: 0.3}

const SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform float fade_start = 20.0;
uniform float fade_end = 30.0;
uniform float wind_strength = 0.12;
varying vec3 tint;
varying vec3 blade_color;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float reach = length(wp - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(fade_start, fade_end, reach);
	float tip = COLOR.r;
	float gust = sin(TIME * 1.7 + wp.x * 0.35 + wp.z * 0.21) + 0.5 * sin(TIME * 3.1 + wp.x * 0.9 + wp.z * 0.6);
	VERTEX.x += gust * wind_strength * tip;
	VERTEX.z += gust * wind_strength * 0.5 * tip;
	VERTEX.y *= fade;
	blade_color = INSTANCE_CUSTOM.rgb;
	tint = mix(vec3(0.55, 0.62, 0.45), vec3(1.15, 1.1, 0.85), tip);
}

void fragment() {
	ALBEDO = tint * blade_color;
	ROUGHNESS = 1.0;
}
"""

var radius_m: float = 30.0
var points_per_side: int = 4
var tufts: int = 0                       # tufts drawn now
var cells_built: int = 0

var _terrain: Node3D
var _flora
var _tables
var _soil_color: Dictionary = {}         # soil id -> Color
var _mesh: ArrayMesh
var _material: ShaderMaterial
var _cells: Dictionary = {}              # Vector2i -> {"node": MultiMeshInstance3D or null, "retry": msec}
var _pending: Array = []                 # cells waiting for rays, nearest first
var _scan_msec: int = 0
var _center: Vector3 = Vector3.ZERO
var enabled: bool = true


func setup(terrain: Node3D, flora, tables) -> void:
	_terrain = terrain
	_flora = flora
	_tables = tables

	for entry in tables.get_entries("soils"):
		var c: Array = entry["color"]
		_soil_color[int(entry["id"])] = Color(float(c[0]), float(c[1]), float(c[2]))

	_mesh = _make_tuft()
	_material = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = SHADER
	_material.shader = shader
	set_radius(radius_m)


func set_radius(meters: float) -> void:
	radius_m = meters
	enabled = meters > 0.0

	if _material != null:
		_material.set_shader_parameter("fade_start", maxf(meters - 10.0, 1.0))
		_material.set_shader_parameter("fade_end", maxf(meters, 2.0))

	if not enabled:
		_clear_all()


# A tuft of five blades fanned around a point: base dark (vertex color r = 0),
# tip light (r = 1), a little curved so it reads as grass from any side.
static func _make_tuft() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var colors: PackedColorArray = PackedColorArray()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7

	for n in range(5):
		var angle: float = TAU * float(n) / 5.0 + rng.randf() * 0.5
		var lean: float = 0.10 + rng.randf() * 0.12
		var height: float = 0.38 + rng.randf() * 0.30
		var d: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
		var side: Vector3 = Vector3(-d.z, 0.0, d.x)
		var base: Vector3 = d * 0.05
		var half: float = 0.028
		var mid: Vector3 = base + d * lean * 0.5 + Vector3.UP * height * 0.55
		var tip: Vector3 = base + d * lean + Vector3.UP * height
		vertices.append_array([base - side * half, base + side * half, mid - side * half * 0.7])
		colors.append_array([Color(0, 0, 0), Color(0, 0, 0), Color(0.5, 0, 0)])
		vertices.append_array([base + side * half, mid + side * half * 0.7, mid - side * half * 0.7])
		colors.append_array([Color(0, 0, 0), Color(0.5, 0, 0), Color(0.5, 0, 0)])
		vertices.append_array([mid - side * half * 0.7, mid + side * half * 0.7, tip])
		colors.append_array([Color(0.5, 0, 0), Color(0.5, 0, 0), Color(1, 0, 0)])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _clear_all() -> void:
	for key in _cells:
		var node = _cells[key]["node"]

		if node != null:
			node.queue_free()

	_cells.clear()
	_pending.clear()
	tufts = 0


# Call from the client's physics step with the player's position.
func update(position: Vector3) -> void:
	if not enabled or _mesh == null:
		return

	_center = position
	var now: int = Time.get_ticks_msec()

	if now - _scan_msec > 400:
		_scan_msec = now
		_rescan(position, now)

	var rays: int = RAYS_PER_FRAME

	while rays > 0 and not _pending.is_empty():
		var cell: Vector2i = _pending.pop_front()

		if not _cells.has(cell) or _cells[cell].get("busy", false) == false:
			continue

		rays -= _build(cell)


func _rescan(position: Vector3, now: int) -> void:
	var cx: int = int(floor(position.x / CELL_M))
	var cz: int = int(floor(position.z / CELL_M))
	var span: int = int(ceil((radius_m + CELL_M) / CELL_M))
	var wanted: Array = []

	for dz in range(-span, span + 1):
		for dx in range(-span, span + 1):
			var cell: Vector2i = Vector2i(cx + dx, cz + dz)
			var centre: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_M

			if centre.distance_to(Vector2(position.x, position.z)) > radius_m + CELL_M:
				continue

			wanted.append(cell)

	for cell in wanted:
		var entry = _cells.get(cell)

		if entry == null:
			_cells[cell] = {"node": null, "retry": 0, "busy": true, "built": false}
			_pending.append(cell)
		elif not entry["built"] and not entry["busy"] and now >= int(entry["retry"]):
			entry["busy"] = true
			_pending.append(cell)

	var near: Vector2 = Vector2(position.x, position.z)
	_pending.sort_custom(func(a, b):
		return (Vector2(a) + Vector2(0.5, 0.5)).distance_squared_to(near / CELL_M) < (Vector2(b) + Vector2(0.5, 0.5)).distance_squared_to(near / CELL_M))
	var keep: Dictionary = {}

	for cell in wanted:
		keep[cell] = true

	for cell in _cells.keys():
		if not keep.has(cell):
			var node = _cells[cell]["node"]

			if node != null:
				tufts -= node.multimesh.instance_count
				node.queue_free()

			_cells.erase(cell)


# Rays for one cell; returns how many were cast.
func _build(cell: Vector2i) -> int:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var tool: VoxelTool = _terrain.get_voxel_tool()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(cell)
	var spacing: float = CELL_M / float(points_per_side)
	var transforms: Array = []
	var colors: Array = []
	var rays: int = 0
	var missed: int = 0

	for j in range(points_per_side):
		for i in range(points_per_side):
			var x: float = float(cell.x) * CELL_M + (float(i) + rng.randf()) * spacing
			var z: float = float(cell.y) * CELL_M + (float(j) + rng.randf()) * spacing
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, _center.y + 80.0, z), Vector3(x, _center.y - 120.0, z))
			var hit: Dictionary = space.intersect_ray(query)
			rays += 1

			if hit.is_empty():
				missed += 1
				continue

			var collider = hit["collider"]

			if collider.has_meta("species_ids") or hit["normal"].y < MIN_SLOPE_Y:
				continue

			var point: Vector3 = hit["position"]
			var water: float = _flora.water_level_at(x, z)

			if not is_nan(water) and point.y < water + 0.3:
				continue

			var soil: int = _grass_soil(tool, point - hit["normal"] * 0.4)

			if soil < 0:
				continue

			var thick: float = float(GRASS_SOILS[soil])
			var base: Color = _soil_color.get(soil, Color(0.3, 0.4, 0.2))
			var green: Color = Color(0.40, 0.52, 0.22).lerp(base, 0.25)

			for k in range(TUFTS_PER_POINT):
				if rng.randf() > thick:
					continue

				var at: Vector3 = point + Vector3(rng.randf_range(-0.5, 0.5) * spacing, 0.0, rng.randf_range(-0.5, 0.5) * spacing) * 0.9
				var size: float = rng.randf_range(0.8, 1.35)
				var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * rng.randf_range(0.8, 1.2), size))
				transforms.append(Transform3D(basis, at - Vector3(0.0, 0.03, 0.0)))
				var shade: float = rng.randf_range(0.8, 1.15)
				colors.append(Color(green.r * shade, green.g * shade, green.b * shade * rng.randf_range(0.9, 1.1)))

	var entry: Dictionary = _cells[cell]
	entry["busy"] = false

	if missed * 2 > rays:
		# The ground collision is not ready here yet; try again later.
		entry["retry"] = Time.get_ticks_msec() + RETRY_MSEC
		return rays

	entry["built"] = true
	cells_built += 1

	if transforms.is_empty():
		return rays

	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = _mesh
	multi.instance_count = transforms.size()

	for n in range(transforms.size()):
		multi.set_instance_transform(n, transforms[n])
		multi.set_instance_custom_data(n, colors[n])

	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = _material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.custom_aabb = AABB(Vector3(float(cell.x) * CELL_M, _center.y - 150.0, float(cell.y) * CELL_M), Vector3(CELL_M, 300.0, CELL_M))
	add_child(node)
	entry["node"] = node
	tufts += transforms.size()
	return rays


# The soil id at a point if it carries grass, else -1 (rock, ore, sand, snow...).
func _grass_soil(tool: VoxelTool, point: Vector3) -> int:
	var cell: Vector3i = Vector3i(point.floor())
	tool.channel = Layout.CHANNEL_RESOURCE

	if tool.get_voxel(cell) > 0:
		return -1

	tool.channel = Layout.CHANNEL_MATERIAL
	var material: int = tool.get_voxel(cell)

	if GRASS_SOILS.has(material):
		return material

	return -1
