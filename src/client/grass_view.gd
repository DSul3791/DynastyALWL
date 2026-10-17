extends Node3D

# Grass near the player (client only, never stored or synced; DESIGN_IDEAS
# Section 4 "Grass"). The ground around the player is cut into square cells.
# Each cell finds the ground with downward rays against the terrain's own
# collision, keeps spots on grass-bearing soil that are gentle, dry and not
# covered by ore or rock, and draws a tuft there. Tufts sway in the wind, fade
# to nothing toward the edge, and are drawn as painted-texture cards in muted
# storybook greens tinted by the soil, in three layers (ground cover, short
# grass, tall grass patches). Cells are built a few rays per frame so walking never stalls.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const CELL_M := 6.0
const RAYS_PER_FRAME := 40
const RETRY_MSEC := 1500
const MIN_SLOPE_Y := 0.80                # surface normal y; steeper is bare
const TUFTS_PER_POINT := 3

# Soil ids that carry grass, with how thick (0 to 1).
const GRASS_SOILS := {3: 0.9, 4: 0.5, 5: 1.0, 6: 0.7, 7: 1.0, 8: 0.6, 9: 0.3}

# The three layers, from the ground up. "reach" is the share of the grass
# radius the layer is drawn to; "per_point" is how many cards per ground sample.
const LAYERS := [
	{"name": "cover", "texture": "ground_cover", "width": 0.7, "height": 0.0, "per_point": 5, "reach": 0.45, "quads": 0, "wind": 0.0},
	{"name": "short", "texture": "grass_short", "width": 0.60, "height": 0.40, "per_point": 3, "reach": 0.85, "quads": 3, "wind": 1.0},
	{"name": "tall", "texture": "grass_tall", "width": 0.45, "height": 0.75, "per_point": 1, "reach": 1.0, "quads": 2, "wind": 1.4},
]

const SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform sampler2D blades : source_color, filter_linear_mipmap, repeat_disable;
uniform float fade_start = 20.0;
uniform float fade_end = 30.0;
uniform float wind_strength = 0.12;
varying vec3 blade_color;
varying float tip;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float reach = length(wp - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(fade_start, fade_end, reach);
	tip = 1.0 - UV.y;
	float gust = sin(TIME * 1.7 + wp.x * 0.35 + wp.z * 0.21) + 0.5 * sin(TIME * 3.1 + wp.x * 0.9 + wp.z * 0.6);
	VERTEX.x += gust * wind_strength * tip * tip;
	VERTEX.z += gust * wind_strength * 0.5 * tip * tip;
	VERTEX *= fade;
	blade_color = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	vec4 t = texture(blades, UV);
	if (t.a < 0.5) {
		discard;
	}
	// Light every card as if it faced up, front or back, so the ground's lighting carries over.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ALBEDO = t.rgb * blade_color * mix(0.8, 1.1, tip);
	ROUGHNESS = 1.0;
}
"""

var radius_m: float = 30.0
var points_per_side: int = 4
var tufts: int = 0                       # cards drawn now
var cells_built: int = 0

var _terrain: Node3D
var _flora
var _tables
var _soil_color: Dictionary = {}         # soil id -> Color
var _meshes: Array = []                  # one card mesh per layer
var _materials: Array = []               # one material per layer
var _patch := FastNoiseLite.new()        # where tall grass grows
var _tint := FastNoiseLite.new()         # greener and yellower patches
var _cells: Dictionary = {}              # Vector2i -> {"nodes", "retry", "busy", "built", "count"}
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

	_patch.seed = 41
	_patch.frequency = 0.035
	_tint.seed = 77
	_tint.frequency = 0.08
	var shader: Shader = Shader.new()
	shader.code = SHADER

	for layer in LAYERS:
		_meshes.append(_make_cards(float(layer["width"]), float(layer["height"]), int(layer["quads"])))
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("blades", _load_texture(str(layer["texture"])))
		material.set_shader_parameter("wind_strength", 0.12 * float(layer["wind"]))
		_materials.append(material)

	set_radius(radius_m)


# The painted texture, imported by the editor or else straight from the file.
static func _load_texture(name: String) -> Texture2D:
	var path: String = "res://assets/grass/%s.png" % name

	if ResourceLoader.exists(path):
		var imported: Texture2D = load(path) as Texture2D

		if imported != null:
			return imported

	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))

	if image == null:
		image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.4, 0.6, 0.3, 1.0))

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func set_radius(meters: float) -> void:
	radius_m = meters
	enabled = meters > 0.0

	for n in range(_materials.size()):
		var reach: float = meters * float(LAYERS[n]["reach"])
		_materials[n].set_shader_parameter("fade_start", maxf(reach - 8.0 * float(LAYERS[n]["reach"]), 1.0))
		_materials[n].set_shader_parameter("fade_end", maxf(reach, 2.0))

	if not enabled:
		_clear_all()


# Crossed upright cards (2 or 3 of them, turned evenly), base at y = 0.
# UV y is 1 at the base and 0 at the tip (the shader sways by the tip).
static func _make_cards(width: float, height: float, quads: int) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	if quads == 0:
		# Flat card lying on the ground (ground cover seen from above).
		var half: float = width * 0.5
		var y: float = 0.03
		var flat: Array = []
		flat.resize(Mesh.ARRAY_MAX)
		flat[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-half, y, half), Vector3(half, y, half), Vector3(half, y, -half), Vector3(-half, y, -half)])
		flat[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		flat[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		var flat_mesh: ArrayMesh = ArrayMesh.new()
		flat_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, flat)
		return flat_mesh

	for n in range(quads):
		var angle: float = PI * float(n) / float(quads)
		var d: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * width * 0.5
		var first: int = vertices.size()
		vertices.append_array([-d, d, d + Vector3.UP * height, -d + Vector3.UP * height])
		uvs.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _free_cell_nodes(entry: Dictionary) -> void:
	for node in entry.get("nodes", []):
		node.queue_free()

	tufts -= int(entry.get("count", 0))
	entry["nodes"] = []
	entry["count"] = 0


func _clear_all() -> void:
	for key in _cells:
		_free_cell_nodes(_cells[key])

	_cells.clear()
	_pending.clear()
	tufts = 0


# Call from the client's physics step with the player's position.
func update(position: Vector3) -> void:
	if not enabled or _meshes.is_empty():
		return

	_center = position
	var now: int = Time.get_ticks_msec()

	if now - _scan_msec > 400:
		_scan_msec = now
		_rescan(position, now)

	var rays: int = RAYS_PER_FRAME

	while rays > 0 and not _pending.is_empty():
		var cell: Vector2i = _pending.pop_front()

		if not _cells.has(cell) or not _cells[cell]["busy"]:
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
			_cells[cell] = {"nodes": [], "count": 0, "retry": 0, "busy": true, "built": false}
			_pending.append(cell)
		elif not entry["built"] and not entry["busy"] and now >= int(entry["retry"]):
			entry["busy"] = true
			_pending.append(cell)

	var near: Vector2 = Vector2(position.x, position.z) / CELL_M
	_pending.sort_custom(func(a, b):
		return (Vector2(a) + Vector2(0.5, 0.5)).distance_squared_to(near) < (Vector2(b) + Vector2(0.5, 0.5)).distance_squared_to(near))
	var keep: Dictionary = {}

	for cell in wanted:
		keep[cell] = true

	for cell in _cells.keys():
		if not keep.has(cell):
			_free_cell_nodes(_cells[cell])
			_cells.erase(cell)


# Rays for one cell; returns how many were cast.
func _build(cell: Vector2i) -> int:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var tool: VoxelTool = _terrain.get_voxel_tool()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(cell)
	var spacing: float = CELL_M / float(points_per_side)
	var transforms: Array = [[], [], []]
	var colors: Array = [[], [], []]
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
			var green: Color = Color(0.46, 0.58, 0.28).lerp(base, 0.2)
			# Patches: yellower where the tint noise is high; tall grass where the patch noise is.
			var warm: float = clampf(_tint.get_noise_2d(x, z) * 1.4, 0.0, 1.0)
			green = green.lerp(Color(0.68, 0.64, 0.30), warm * 0.55)
			var meadow: float = _patch.get_noise_2d(x, z)

			for layer in range(LAYERS.size()):
				var count: int = int(LAYERS[layer]["per_point"])
				var chance: float = thick

				if layer == 2:
					# Tall grass only in meadow patches, thinning toward their edges.
					chance = thick * clampf((meadow - 0.05) * 3.0, 0.0, 1.0) * 0.9
				elif layer == 1:
					chance = thick * (1.0 - clampf((meadow - 0.2) * 1.5, 0.0, 0.6))

				for k in range(count):
					if rng.randf() > chance:
						continue

					var at: Vector3 = point + Vector3(rng.randf_range(-0.5, 0.5) * spacing, 0.0, rng.randf_range(-0.5, 0.5) * spacing) * 0.95
					var size: float = rng.randf_range(0.75, 1.15)
					var basis: Basis = Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * rng.randf_range(0.8, 1.15), size))
					transforms[layer].append(Transform3D(basis, at - Vector3(0.0, 0.03, 0.0)))
					var shade: float = rng.randf_range(0.82, 1.15)
					var tone: Color = green
					# A slight hue shift per card keeps a field from looking stamped.
					colors[layer].append(Color(tone.r * shade * rng.randf_range(0.93, 1.07), tone.g * shade, tone.b * shade * rng.randf_range(0.9, 1.1)))

	var entry: Dictionary = _cells[cell]
	entry["busy"] = false

	if missed * 2 > rays:
		# The ground collision is not ready here yet; try again later.
		entry["retry"] = Time.get_ticks_msec() + RETRY_MSEC
		return rays

	entry["built"] = true
	cells_built += 1

	for layer in range(LAYERS.size()):
		var list: Array = transforms[layer]

		if list.is_empty():
			continue

		var multi: MultiMesh = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = _meshes[layer]
		multi.instance_count = list.size()

		for n in range(list.size()):
			multi.set_instance_transform(n, list[n])
			multi.set_instance_custom_data(n, colors[layer][n])

		var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
		node.multimesh = multi
		node.material_override = _materials[layer]
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.custom_aabb = AABB(Vector3(float(cell.x) * CELL_M, _center.y - 150.0, float(cell.y) * CELL_M), Vector3(CELL_M, 300.0, CELL_M))
		add_child(node)
		entry["nodes"].append(node)
		entry["count"] += list.size()
		tufts += list.size()

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
