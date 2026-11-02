extends MeshInstance3D

# Liquid surface (Sonny, 2 Nov 2026; Dave: "think liquid not squares... reinvent your own that actually flows like liquid water").
# One continuous sheet over the live water window, not 8 m cells switched on and off. Every vertex takes its height from the simulated water surface
# (water_flow_texture.gd: R surface, G/B flow, A depth), sampled smoothly between cells, so a stream is one body that runs down its bed, a fall is the
# water itself bending over the lip, and a pond is level. The shore is decided per pixel from the depth: the sheet thins to nothing where the water
# does, so banks are curved and soft. Ripples and foam are carried along the simulated flow (two offset phases blended, the usual flow-map trick),
# so the surface visibly travels downstream at the sim's speed.
# The grid look (water_material.gd) steps aside inside the window; outside it nothing changes.

const SHEET_STEP_M := 2.0       # vertex spacing of the sheet (the sim cell is 8 m; the texture is filtered between)
const FADE_CELLS := 1.0         # the sheet fades in over this many cells from the window's edge, where the grid look takes over

const SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, shadows_disabled, specular_schlick_ggx;

uniform sampler2D liquid : filter_linear, repeat_disable;   // R surface (m), G flow east, B flow south (m/s), A depth (m)
uniform vec2 cells = vec2(128.0);                           // texels across
uniform float fade_cells = 1.0;
uniform vec3 shallow_color : source_color = vec3(0.17, 0.33, 0.33);
uniform vec3 deep_color : source_color = vec3(0.04, 0.17, 0.24);
uniform vec3 foam_color : source_color = vec3(0.80, 0.84, 0.82);
uniform vec3 sky_color : source_color = vec3(0.55, 0.64, 0.74);
uniform float clear_m = 1.1;        // water this deep hides about two thirds of the bed
uniform float edge_m = 0.06;        // the sheet fades in over this much depth at the shore
uniform float daylight = 1.0;

varying vec2 tex_uv;
varying float depth_v;
varying vec2 flow_v;

vec4 sample_liquid(vec2 uv) {
	return textureLod(liquid, uv, 0.0);
}

void vertex() {
	// UV across the window: the plane spans the texture exactly (texel centres on the sim cells).
	tex_uv = UV;
	vec4 t = sample_liquid(tex_uv);
	depth_v = t.a;
	flow_v = t.gb;
	// Dry ground: the sheet tucks under the bed, so it never floats over a dry channel; the per-pixel fade hides the seam.
	VERTEX.y = t.a > 0.004 ? t.r : t.r - 0.4;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Small waves: two octaves, as a height for the normal.
float waves(vec2 p) {
	return noise(p) * 0.65 + noise(p * 2.3 + 7.1) * 0.35;
}

void fragment() {
	vec4 t = texture(liquid, tex_uv);   // per pixel: the shore follows the depth between cells, not the cell edges
	float depth = t.a;

	if (depth < 0.004) {
		discard;
	}

	vec2 vel = t.gb;
	float speed = length(vel);
	vec2 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;

	// Flow map: the ripple pattern is dragged downstream at the water's own speed; two copies half a cycle apart cross-fade so it never stretches.
	float cycle = 2.0;
	float ph0 = fract(TIME / cycle);
	float ph1 = fract(TIME / cycle + 0.5);
	float mixk = abs(1.0 - 2.0 * ph0);
	vec2 drift = vel * cycle;
	vec2 p0 = world / 1.6 - drift * ph0 / 1.6;
	vec2 p1 = world / 1.6 - drift * ph1 / 1.6 + 3.7;
	float e = 0.15;
	float h0 = waves(p0);
	float h1 = waves(p1);
	float hx = mix(waves(p0 + vec2(e, 0.0)), waves(p1 + vec2(e, 0.0)), mixk) - mix(h0, h1, mixk);
	float hz = mix(waves(p0 + vec2(0.0, e)), waves(p1 + vec2(0.0, e)), mixk) - mix(h0, h1, mixk);
	// Faster water is choppier; still water nearly glassy.
	float chop = 0.08 + 0.5 * clamp(speed / 2.5, 0.0, 1.0);
	vec3 n_world = normalize(vec3(-hx / e * chop, 1.0, -hz / e * chop));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	// Colour by depth, a sky reflection by angle.
	float thick = 1.0 - exp(-depth / clear_m);
	vec3 water = mix(shallow_color, deep_color, thick);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);

	// Foam where it runs fast and shallow (rapids, the lip and foot of a fall), streaked along the flow.
	float streak = mix(noise(p0 * 2.5), noise(p1 * 2.5), mixk);
	float rough = clamp((speed - 1.2) / 2.5, 0.0, 1.0) * clamp(1.0 - depth / 2.0, 0.0, 1.0);
	float foam = smoothstep(0.45, 0.8, streak + rough * 0.6) * rough;

	// The shore: the sheet thins out with the water; the window's edge fades to the grid look.
	vec2 in_cells = tex_uv * cells;
	float edge = clamp(min(min(in_cells.x, in_cells.y), min(cells.x - in_cells.x, cells.y - in_cells.y)) / fade_cells, 0.0, 1.0);
	float shore = smoothstep(0.0, edge_m, depth);

	ALBEDO = mix(mix(water, sky_color, fresnel * 0.6), foam_color, foam);
	EMISSION = foam_color * foam * 0.15 * daylight;
	ROUGHNESS = 0.06 + 0.35 * foam;
	SPECULAR = 0.5;
	ALPHA = clamp(max(0.35 + 0.6 * thick, foam), 0.0, 1.0) * shore * edge;
}
"""

var _material: ShaderMaterial = null
var _cells: Vector2i = Vector2i.ZERO


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = SHADER
	_material.shader = shader
	visible = false


# The newest window from the server (water_flow_texture.unpack): `origin` is the world x, z of cell (0, 0).
func show_window(im: Image, origin: Vector2, cell_m: float) -> void:
	var cells: Vector2i = Vector2i(im.get_width(), im.get_height())
	var size: Vector2 = Vector2(cells) * cell_m

	if cells != _cells:
		_cells = cells
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = size
		plane.subdivide_width = maxi(int(size.x / SHEET_STEP_M) - 1, 1)
		plane.subdivide_depth = maxi(int(size.y / SHEET_STEP_M) - 1, 1)
		plane.material = _material
		mesh = plane
		# The surface heights move every publish: the bounds must hold any of them.
		custom_aabb = AABB(Vector3(-size.x * 0.5, -200.0, -size.y * 0.5), Vector3(size.x, 2400.0, size.y))

	# The texture covers the cells' squares: from half a cell before cell (0, 0). A PlaneMesh is centred on its node and its UV runs 0..1 from -x, -z.
	var corner: Vector2 = origin - Vector2(0.5, 0.5) * cell_m
	position = Vector3(corner.x + size.x * 0.5, 0.0, corner.y + size.y * 0.5)
	_material.set_shader_parameter("liquid", ImageTexture.create_from_image(im))
	_material.set_shader_parameter("cells", Vector2(cells))
	_material.set_shader_parameter("fade_cells", FADE_CELLS)
	visible = true


func set_daylight(value: float) -> void:
	_material.set_shader_parameter("daylight", value)
