extends Node

# Far-tree impostors (Art direction, 2026-10-20, build 125; Godot docs "Optimizing 3D
# performance": a single transparent quad per distant object). The client renders each tree
# species once at startup, from the front and from the side, into one small atlas, and makes a
# mesh of two crossed vertical quads that show those two views. FloraView draws trees beyond
# its impostor distance with these (4 triangles) instead of the far model (150 to 300).
# Nothing is shipped or saved: the images are made from the live tree models, so a model
# change needs no re-bake. The images are rendered with flat white ambient light and no sun, so
# no light direction is baked in; the shader tints the crown with the tree's own autumn or
# conifer colour (INSTANCE_CUSTOM, as the foliage shader does) and lights the quad like the
# ground (normal up). Headless runs (no rendering device) and any failed capture leave a species
# out, and FloraView keeps drawing those with the far model.

signal finished(meshes: Dictionary)

const SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform float crown_v = 0.7;         // image row (0 top, 1 bottom) where the leaves start; below it is trunk, not tinted
uniform float light_scale = 0.66;     // matches the quad's brightness to the far model's
uniform float backlight = 0.3;
varying vec3 tint;

void vertex() {
	tint = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	vec4 t = texture(atlas, UV);
	if (t.a < 0.5) {
		discard;
	}
	float crown = 1.0 - smoothstep(crown_v - 0.03, crown_v + 0.03, UV.y);
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	float low = crown * smoothstep(crown_v - 0.45, crown_v, UV.y);   // the crown's lower part sits in its own shade
	ALBEDO = t.rgb * mix(vec3(1.0), tint, crown) * light_scale * (1.0 - 0.25 * low);
	BACKLIGHT = ALBEDO * backlight * crown;
	ROUGHNESS = 1.0;
}
"""

static var _shader: Shader = null

var _running: bool = false


# Whether this run can render at all (a headless server or test run has no rendering device).
static func can_render() -> bool:
	return DisplayServer.get_name() != "headless" and RenderingServer.get_rendering_device() != null


# species: id -> {"mesh": ArrayMesh (the far model)}.
# tile: size in pixels of one view. Emits `finished` with id -> {"mesh", "material"}.
func start(species: Dictionary, tile: Vector2i) -> void:
	if _running or species.is_empty() or not can_render():
		finished.emit({})
		return

	_running = true
	_run(species, tile)


func _run(species: Dictionary, tile: Vector2i) -> void:
	var result: Dictionary = {}

	for id in species:
		var info: Dictionary = species[id]
		var made: Dictionary = await _make(info, tile)

		if not made.is_empty():
			result[id] = made

	_running = false
	finished.emit(result)


# The model's bounds from its own vertices (an ArrayMesh's get_aabb is not always tight or complete).
static func _bounds(model: ArrayMesh) -> AABB:
	var low: Vector3 = Vector3(INF, INF, INF)
	var high: Vector3 = Vector3(-INF, -INF, -INF)

	for n in range(model.get_surface_count()):
		for v in model.surface_get_arrays(n)[Mesh.ARRAY_VERTEX]:
			low = low.min(v)
			high = high.max(v)

	return AABB(low, high - low) if low.x != INF else model.get_aabb()


# Lowest point of the leaves of a model (its surfaces that use a foliage material), or the
# model's own bottom when none is found.
static func _leaf_base(model: ArrayMesh) -> float:
	var lowest: float = INF

	for n in range(model.get_surface_count()):
		var material: ShaderMaterial = model.surface_get_material(n) as ShaderMaterial

		if material == null or material.shader == null or not material.shader.code.contains("sampler2D leaves"):
			continue

		for v in model.surface_get_arrays(n)[Mesh.ARRAY_VERTEX]:
			lowest = minf(lowest, v.y)

	return lowest if lowest != INF else model.get_aabb().position.y + 0.5 * model.get_aabb().size.y


# One species: front and side images, the atlas, the crossed quads.
func _make(info: Dictionary, tile: Vector2i) -> Dictionary:
	var model: ArrayMesh = info["mesh"]
	var box: AABB = _bounds(model)
	var height: float = maxf(box.size.y, 0.5)
	var wide: float = maxf(box.size.x, box.size.z)
	# The camera frame is tile aspect (width = height / 2): tall enough for the tree and wide
	# enough for the crown, the bottom on the tree's foot.
	var frame: float = maxf(height * 1.04, 2.0 * wide * 1.04)
	var centre: Vector3 = box.position + box.size * 0.5
	var images: Array = []

	for view in range(2):
		var image: Image = await _render(model, box, frame, centre, view, tile)

		if image == null:
			return {}

		images.append(image)

	var atlas: Image = Image.create(tile.x * 2, tile.y, true, Image.FORMAT_RGBA8)
	atlas.blit_rect(images[0], Rect2i(Vector2i.ZERO, tile), Vector2i.ZERO)
	atlas.blit_rect(images[1], Rect2i(Vector2i.ZERO, tile), Vector2i(tile.x, 0))
	atlas.fix_alpha_edges()
	atlas.generate_mipmaps()
	var texture: ImageTexture = ImageTexture.create_from_image(atlas)

	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _shader
	material.set_shader_parameter("atlas", texture)
	material.set_shader_parameter("crown_v", 1.0 - (_leaf_base(model) - (box.position.y - 0.02 * frame)) / frame)
	return {"mesh": _quads(frame, box, centre, material), "material": material}


func _render(model: ArrayMesh, box: AABB, frame: float, centre: Vector3, view: int, tile: Vector2i) -> Image:
	var port: SubViewport = SubViewport.new()
	port.size = tile
	port.transparent_bg = true
	port.own_world_3d = true
	port.msaa_3d = Viewport.MSAA_4X
	port.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color.WHITE
	environment.ambient_light_energy = 1.0
	var world: WorldEnvironment = WorldEnvironment.new()
	world.environment = environment
	port.add_child(world)

	# One instance with neutral custom data (the foliage shader multiplies by it).
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = model
	multi.instance_count = 1
	multi.set_instance_transform(0, Transform3D.IDENTITY)
	multi.set_instance_custom_data(0, Color(1.0, 1.0, 1.0, 0.0))
	var draw: MultiMeshInstance3D = MultiMeshInstance3D.new()
	draw.multimesh = multi
	port.add_child(draw)

	var camera: Camera3D = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.size = frame
	camera.near = 1.0
	camera.far = 500.0
	var y: float = box.position.y + frame * 0.5 - 0.02 * frame     # bottom of the frame just under the foot
	port.add_child(camera)

	if view == 0:
		camera.position = Vector3(centre.x, y, centre.z + 200.0)
	else:
		camera.position = Vector3(centre.x + 200.0, y, centre.z)
		camera.rotation_degrees = Vector3(0.0, 90.0, 0.0)

	camera.current = true
	add_child(port)
	# Two frames: the first compiles the shaders and draws, the second is the finished picture.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var image: Image = port.get_texture().get_image()
	port.queue_free()

	if image == null or image.is_empty():
		return null

	image.convert(Image.FORMAT_RGBA8)
	var seen: bool = false

	for step in range(0, image.get_width() * image.get_height(), 7):
		@warning_ignore("integer_division")
		if image.get_pixel(step % image.get_width(), step / image.get_width()).a > 0.5:
			seen = true
			break

	return image if seen else null


# Two vertical quads crossing at the tree's axis: the front image in the XY plane, the side
# image in the ZY plane; UV x 0 to 0.5 and 0.5 to 1 of the atlas, y 0 at the top.
func _quads(frame: float, box: AABB, centre: Vector3, material: Material) -> ArrayMesh:
	var half: float = frame * 0.25         # half the quad width (frame / 2 wide)
	var y0: float = box.position.y - 0.02 * frame
	var y1: float = y0 + frame
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(centre.x - half, y0, centre.z), Vector3(centre.x + half, y0, centre.z),
		Vector3(centre.x + half, y1, centre.z), Vector3(centre.x - half, y1, centre.z),
		Vector3(centre.x, y0, centre.z + half), Vector3(centre.x, y0, centre.z - half),
		Vector3(centre.x, y1, centre.z - half), Vector3(centre.x, y1, centre.z + half),
	])
	var uvs: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 1.0), Vector2(0.5, 1.0), Vector2(0.5, 0.0), Vector2(0.0, 0.0),
		Vector2(0.5, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.5, 0.0),
	])
	var normals: PackedVector3Array = PackedVector3Array()
	normals.resize(8)
	normals.fill(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3, 4, 5, 6, 4, 6, 7])
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh
