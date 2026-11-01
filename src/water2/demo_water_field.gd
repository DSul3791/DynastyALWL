extends SceneTree

# Dynasty water stage c: picture demos from a real render (Sonny, 31 Oct 2026). Needs a window.
#   godot --path . --resolution 1280x720 --script res://src/water2/demo_water_field.gd -- [--out=res://src/water2/art] [--only=basin|valley|kinds]
# basin: a spring fills a bowl on a hillside, spills over its low rim and runs down around a hill (4 frames).
# valley: the same fast river drawn calm (turbulence 0.05) and rough (0.95): flow speed and waves are separate settings.
# kinds: water, swamp and lava down the same slope after the same time.
# The water surface here is a throw-away demo shader (flow-advected ripples, foam from speed x turbulence); the game keeps its own water shader.

const Field := preload("res://src/water2/water_field.gd")
const Traits := preload("res://src/water2/water_traits.gd")
const WaterMaterial := preload("res://src/client/water_material.gd")   # the game's own water shader (stage c2): per-vertex flow in COLOR, traits in its uniforms

const WATER_SHADER := """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 tint = vec3(0.1, 0.35, 0.45);
uniform float clarity = 4.0;
uniform float turb = 0.3;
uniform float glow = 0.0;
varying vec3 wp;
varying vec2 flow;
varying float spd;
varying float dep;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	flow = UV;
	spd = COLOR.g * 4.0;
	dep = COLOR.r * 3.0;
}
void fragment() {
	vec2 d = length(flow) > 0.01 ? normalize(flow) : vec2(1.0, 0.0);
	float k = 0.45;
	float ph = dot(wp.xz, d) * k - spd * 3.0;
	float ph2 = dot(wp.xz, vec2(-d.y, d.x)) * 0.7 + dot(wp.xz, d) * 0.3;
	vec3 n = normalize(vec3(-turb * 0.5 * cos(ph) * d.x - turb * 0.2 * cos(ph2), 1.0, -turb * 0.5 * cos(ph) * d.y - turb * 0.2 * sin(ph2)));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	float foam = smoothstep(0.5, 1.0, spd / 4.0) * turb;
	float thick = 1.0 - exp(-dep / max(clarity, 0.05));
	vec3 col = mix(tint * 1.5, tint * 0.6, thick);
	ALBEDO = mix(col, vec3(0.92), clamp(foam, 0.0, 1.0));
	ALPHA = mix(0.55, 0.96, thick);
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	EMISSION = tint * glow;
}
"""

var _out: String = "res://src/water2/art"
var _only: String = ""


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--out="):
			_out = argument.trim_prefix("--out=")
		elif argument.begins_with("--only="):
			_only = argument.trim_prefix("--only=")

	_run()


func _frames(count: int = 5) -> void:
	for _i in range(count):
		await process_frame

	await RenderingServer.frame_post_draw


func _scene() -> Camera3D:
	for child in root.get_children():
		child.queue_free()

	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42, 35, 0)
	sun.light_energy = 0.8
	root.add_child(sun)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.sky.sky_material = ProceduralSkyMaterial.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 55.0
	cam.far = 2000.0
	root.add_child(cam)
	cam.current = true
	return cam


func _terrain(f) -> MeshInstance3D:
	var verts: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()
	var idx: PackedInt32Array = PackedInt32Array()

	for j in range(f.h):
		for i in range(f.w):
			var y: float = f.bed[j * f.w + i]
			verts.append(Vector3(i * f.cell_m, y, j * f.cell_m))
			var slope: float = 0.0

			if i < f.w - 1 and j < f.h - 1:
				slope = absf(f.bed[j * f.w + i + 1] - y) + absf(f.bed[(j + 1) * f.w + i] - y)

			cols.append(Color(0.32, 0.42, 0.2).lerp(Color(0.5, 0.45, 0.3), clampf(slope / (f.cell_m * 0.5), 0.0, 1.0)))

	for j in range(f.h - 1):
		for i in range(f.w - 1):
			var a: int = j * f.w + i
			idx.append_array([a, a + f.w, a + 1, a + 1, a + f.w, a + f.w + 1])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var st: SurfaceTool = SurfaceTool.new()
	st.create_from(mesh, 0)
	st.generate_normals()
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.albedo_color = Color(0.7, 0.7, 0.7)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	return mi


func _water(f, turb: float) -> MeshInstance3D:
	var verts: PackedVector3Array = PackedVector3Array()
	var cols: PackedColorArray = PackedColorArray()
	var uvs: PackedVector2Array = PackedVector2Array()
	var idx: PackedInt32Array = PackedInt32Array()

	for j in range(f.h):
		for i in range(f.w):
			var k: int = j * f.w + i
			var wet: bool = f.depth[k] > 0.004
			var y: float = f.bed[k] + f.depth[k] if wet else f.bed[k] - 0.05
			verts.append(Vector3(i * f.cell_m, y + 0.02, j * f.cell_m))
			var v: Vector2 = f.velocity(i, j)
			var dir: Vector2 = v.normalized() * clampf(v.length() / 6.0, 0.0, 1.0) if v.length() > 0.02 else Vector2.ZERO
			cols.append(Color(0.5 + 0.5 * dir.x, 0.5 + 0.5 * dir.y, 0.0, 1.0))
			uvs.append(v)

	for j in range(f.h - 1):
		for i in range(f.w - 1):
			var a: int = j * f.w + i
			var n: int = 0

			for o in [a, a + 1, a + f.w, a + f.w + 1]:
				if f.depth[o] > 0.004:
					n += 1

			if n >= 3:
				idx.append_array([a, a + f.w, a + 1, a + 1, a + f.w, a + f.w + 1])

	var mi: MeshInstance3D = MeshInstance3D.new()

	if idx.is_empty():
		return mi

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = mesh
	var sm: ShaderMaterial = WaterMaterial.make()
	var t = f.traits
	var base: Color = t.color
	sm.set_shader_parameter("shallow_color", Vector3(base.r * 1.4, base.g * 1.4, base.b * 1.4))
	sm.set_shader_parameter("deep_color", Vector3(base.r * 0.4, base.g * 0.4, base.b * 0.5))
	sm.set_shader_parameter("clarity_m", maxf(t.clarity_m * 0.3, 0.05))
	sm.set_shader_parameter("rough", turb)   # calm or choppy: a trait, NOT the flow speed (the game ties it to the flow rate)
	sm.set_shader_parameter("fastest_m_s", 6.0)
	sm.set_shader_parameter("mud", clampf(1.0 - t.clarity_m / 2.0, 0.0, 1.0))
	mi.material_override = sm
	return mi


func _shot(f, turb: float, cam_pos: Vector3, look: Vector3) -> Image:
	var cam: Camera3D = _scene()
	root.add_child(_terrain(f))
	root.add_child(_water(f, turb))
	cam.look_at_from_position(cam_pos, look, Vector3.UP)
	await _frames()
	var im: Image = root.get_texture().get_image()
	im.convert(Image.FORMAT_RGB8)
	return im


func _slope_bed(n: int, cell: float, slope: float) -> PackedFloat32Array:
	var bed: PackedFloat32Array = PackedFloat32Array()
	bed.resize(n * n)

	for j in range(n):
		for i in range(n):
			bed[j * n + i] = 24.0 - slope * cell * float(i)

	return bed


func _save(im: Image, name: String) -> void:
	print("saved ", name, " ", im.save_png(ProjectSettings.globalize_path("%s/%s.png" % [_out, name])))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_out))
	root.size = Vector2i(1280, 720)

	if _only == "" or _only == "basin":
		await _basin()

	if _only == "" or _only == "valley":
		await _valley()

	if _only == "" or _only == "kinds":
		await _kinds()

	quit(0)


func _basin() -> void:
	var n: int = 96
	var cell: float = 2.0
	var bed: PackedFloat32Array = _slope_bed(n, cell, 0.12)

	for j in range(n):
		for i in range(n):
			var x: float = i * cell
			var z: float = j * cell
			bed[j * n + i] += -6.0 * exp(-(pow(x - 50.0, 2.0) + pow(z - 96.0, 2.0)) / (2.0 * 9.0 * 9.0)) + 8.0 * exp(-(pow(x - 120.0, 2.0) + pow(z - 70.0, 2.0)) / (2.0 * 12.0 * 12.0))

	var f = Field.new(n, n, cell, bed)
	f.open_edges = true
	f.add_spring(25, 48, 6.0)
	var shots: Array = []
	var at: float = 0.0

	for t in [20.0, 70.0, 140.0, 300.0]:
		while at < t:
			f.step(1.0)
			at += 1.0

		var im: Image = await _shot(f, 0.5, Vector3(20.0, 38.0, 170.0), Vector3(110.0, 4.0, 85.0))
		shots.append(im)
		_save(im, "basin_%03ds" % int(t))
		print("basin t=%d s volume %.0f m3 awake blocks %d" % [int(t), f.volume_m3(), f.awake_blocks()])

	var sheet: Image = Image.create(1280, 720, false, Image.FORMAT_RGB8)

	for k in range(4):
		var small: Image = shots[k].duplicate()
		small.resize(640, 360, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(small, Rect2i(0, 0, 640, 360), Vector2i((k % 2) * 640, (k / 2) * 360))

	_save(sheet, "basin_series")


func _valley() -> void:
	var n: int = 96
	var cell: float = 2.0
	var bed: PackedFloat32Array = _slope_bed(n, cell, 0.07)

	for j in range(n):
		for i in range(n):
			var across: float = absf(float(j) * cell - 96.0)
			bed[j * n + i] += minf(across * across * 0.012, 14.0) - 2.2 * exp(-pow(across, 2.0) / 120.0)

	var f = Field.new(n, n, cell, bed)
	f.open_edges = true

	for j in range(46, 51):
		f.add_spring(3, j, 4.0)

	for s in range(200):
		f.step(1.0)

	var mid: Vector2 = f.velocity(48, 48)
	print("valley: speed in mid channel %.2f m/s, depth %.2f m" % [mid.length(), f.depth[48 * n + 48]])
	var calm: Image = await _shot(f, 0.05, Vector3(14.0, 28.0, 102.0), Vector3(90.0, 16.0, 96.0))
	var rough: Image = await _shot(f, 0.95, Vector3(14.0, 28.0, 102.0), Vector3(90.0, 16.0, 96.0))
	_save(calm, "valley_calm")
	_save(rough, "valley_rough")
	var pair: Image = Image.create(1280, 360, false, Image.FORMAT_RGB8)
	var both: Array = [calm, rough]

	for k in range(2):
		var small: Image = both[k].duplicate()
		small.resize(640, 360, Image.INTERPOLATE_LANCZOS)
		pair.blit_rect(small, Rect2i(0, 0, 640, 360), Vector2i(k * 640, 0))

	_save(pair, "valley_calm_vs_rough")


func _kinds() -> void:
	var n: int = 96
	var cell: float = 2.0
	var sheet: Image = Image.create(1280, 360, false, Image.FORMAT_RGB8)
	var k: int = 0

	for kind in ["fresh", "swamp", "lava"]:
		var bed: PackedFloat32Array = _slope_bed(n, cell, 0.1)

		for j in range(n):
			for i in range(n):
				var across: float = absf(float(j) * cell - 96.0)
				bed[j * n + i] += minf(across * across * 0.02, 12.0)

		var f = Field.new(n, n, cell, bed, Traits.of(kind))
		f.open_edges = true

		for j in range(46, 51):
			f.add_spring(3, j, 3.0)

		for s in range(60):
			f.step(1.0)

		var front: int = 0

		for i in range(n):
			if f.depth[48 * n + i] > 0.02:
				front = i

		print("kinds: %s front after 60 s at %d m" % [kind, int(front * cell)])
		var im: Image = await _shot(f, f.traits.turbulence, Vector3(-12.0, 48.0, 110.0), Vector3(110.0, 4.0, 96.0))
		im.resize(430, 360, Image.INTERPOLATE_LANCZOS)
		sheet.blit_rect(im, Rect2i(0, 0, 430, 360), Vector2i(k * 425, 0))
		k += 1

	_save(sheet, "kinds_fresh_swamp_lava")
