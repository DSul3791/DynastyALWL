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
uniform float fade_cells = 1.0;                            // 0: no fade at the sheet's edge (a chunk sheet meets its neighbours)
uniform float point_grid = 0.0;                            // 1: texels sit on the sheet's corners and edges (a chunk's grid points), 0: on cell centres (the live window)
uniform vec4 hole = vec4(0.0);                             // world x, z, size x, size z of the live window: a chunk sheet steps aside there
uniform float hole_inset = 8.0;
uniform float cell_m = 8.0;                                // metres between texels
uniform vec3 shallow_color : source_color = vec3(0.17, 0.33, 0.33);
uniform vec3 deep_color : source_color = vec3(0.04, 0.17, 0.24);
uniform vec3 foam_color : source_color = vec3(0.80, 0.84, 0.82);
uniform vec3 sky_color : source_color = vec3(0.55, 0.64, 0.74);
uniform float clear_m = 1.1;        // water this deep hides about two thirds of the bed
uniform float edge_m = 0.06;        // the sheet fades in over this much depth at the shore
uniform float daylight = 1.0;
uniform float mud = 0.0;            // 0..1: brown runoff after storms or at high flow (flora_view.gd, as the grid look)
uniform vec3 mud_color : source_color = vec3(0.30, 0.24, 0.15);
uniform float rain = 0.0;           // 0..1 (weather_look.gd): raindrop rings on the surface
uniform float contact_m = 0.35;     // the sheet fades in over this much water along the view ray where it meets the ground (no hard line on a bank)
uniform float lap_m = 0.6;          // a thin lapping foam line where the water is shallower than this against the bank
uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;

varying vec2 tex_uv;
varying float depth_v;
varying vec2 flow_v;

vec4 sample_liquid(vec2 uv) {
	return textureLod(liquid, uv, 0.0);
}

void vertex() {
	// UV across the window: the plane spans the texture exactly (texel centres on the sim cells).
	tex_uv = point_grid > 0.5 ? (vec2(0.5) + UV * (cells - vec2(1.0))) / cells : UV;
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

	vec2 world = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xz;

	if (hole.z > 0.0) {
		vec2 inside = world - hole.xy;

		if (inside.x > hole_inset && inside.y > hole_inset && inside.x < hole.z - hole_inset && inside.y < hole.w - hole_inset) {
			discard;
		}
	}

	vec2 vel = t.gb;
	float speed = length(vel);

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

	// Rain: each 0.6 m cell gets a drop now and then (more cells as the rain grows); its ring spreads and fades in under a second.
	if (rain > 0.01) {
		vec2 rp = world / 0.6;
		vec2 rc = floor(rp);
		vec2 centre = vec2(hash(rc + 1.7), hash(rc + 9.2)) * 0.6 + 0.2;
		float phase = fract(TIME * 1.3 + hash(rc + 4.4));
		vec2 off = (fract(rp) - centre) * 0.6;
		float r = length(off);
		float front = phase * 0.28;
		float ring = sin((r - front) * 60.0) * (1.0 - smoothstep(0.0, 0.05, abs(r - front))) * (1.0 - phase);
		float drops = step(hash(rc + floor(TIME * 1.3 + hash(rc + 4.4)) * 0.37), rain);
		n_world = normalize(n_world + vec3(off.x, 0.0, off.y) / max(r, 0.001) * ring * drops * 0.5);
	}

	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	// How much water the eye looks through to the ground behind (the scene's depth): soft where the sheet meets the bank, deeper colour where the
	// view runs a long way through the water.
	float scene = texture(depth_tex, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	behind.xyz /= behind.w;
	float through = max(VERTEX.z - behind.z, 0.0);
	float contact = smoothstep(0.0, contact_m, through);

	// Colour by depth, a sky reflection by angle.
	float thick = 1.0 - exp(-min(through, depth * 3.0 + 0.2) / clear_m);
	vec3 water = mix(mix(shallow_color, deep_color, thick), mud_color * (1.0 - 0.4 * thick), mud * 0.8);
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);

	// Foam where it runs fast and shallow (rapids, the lip and foot of a fall), streaked along the flow.
	float streak = mix(noise(p0 * 2.5), noise(p1 * 2.5), mixk);
	float rough = clamp((speed - 1.2) / 2.5, 0.0, 1.0) * clamp(1.0 - depth / 2.0, 0.0, 1.0);
	float foam = smoothstep(0.45, 0.8, streak + rough * 0.6) * rough;
	// Lapping at the bank: a broken foam line that comes and goes where the water thins against the ground.
	float lap = (1.0 - smoothstep(0.05, lap_m, through)) * smoothstep(0.55, 0.9, 0.5 + 0.5 * sin(TIME * 1.1 + noise(world * 0.35) * 9.0)) * noise(world * 1.3 + TIME * 0.2);
	foam = max(foam, lap * 0.7);
	// Falls: where the surface itself drops steeply (only between wet texels; a shore texel's level is the bank), the water turns white, in long
	// streaks that pour down the face, faster than the river above.
	vec2 px = vec2(1.0) / cells;
	vec4 ex0 = texture(liquid, tex_uv - vec2(px.x, 0.0));
	vec4 ex1 = texture(liquid, tex_uv + vec2(px.x, 0.0));
	vec4 ez0 = texture(liquid, tex_uv - vec2(0.0, px.y));
	vec4 ez1 = texture(liquid, tex_uv + vec2(0.0, px.y));
	vec2 grad = vec2(
		min(ex0.a, ex1.a) > 0.004 ? (ex1.r - ex0.r) / (2.0 * cell_m) : 0.0,
		min(ez0.a, ez1.a) > 0.004 ? (ez1.r - ez0.r) / (2.0 * cell_m) : 0.0);
	float drop = length(grad);
	float fall = smoothstep(0.2, 0.7, drop);

	if (fall > 0.01) {
		vec2 down = -grad / max(drop, 0.0001);
		vec2 across = vec2(-down.y, down.x);
		float pour = noise(vec2(dot(world, across) * 2.2, dot(world, down) * 0.25 - TIME * 3.0));
		float pour2 = noise(vec2(dot(world, across) * 5.0 + 3.1, dot(world, down) * 0.5 - TIME * 4.2));
		foam = max(foam, fall * clamp(0.45 + 0.7 * pour * pour2 + 0.25 * pour, 0.0, 1.0));
	}

	// The shore: the sheet thins out with the water; the window's edge fades to the grid look.
	vec2 in_cells = tex_uv * cells;
	float edge = fade_cells > 0.0 ? clamp(min(min(in_cells.x, in_cells.y), min(cells.x - in_cells.x, cells.y - in_cells.y)) / fade_cells, 0.0, 1.0) : 1.0;
	float shore = smoothstep(0.0, edge_m, depth);

	ALBEDO = mix(mix(water, sky_color, fresnel * 0.6), foam_color, foam);
	EMISSION = foam_color * foam * 0.15 * daylight;
	ROUGHNESS = 0.06 + 0.35 * foam;
	SPECULAR = 0.5;
	ALPHA = clamp(max(0.35 + 0.6 * thick, foam), 0.0, 1.0) * shore * edge * contact;
}
"""

const CHUNK_STEP_M := 4.0       # vertex spacing of a chunk sheet (many of them stand at once)
const SHORE_DEPTH_M := 0.3      # a chunk sheet's depth at wet points next to the shore (no ground on the client): it thins to 0 at the shore point
const OPEN_DEPTH_M := 1.0       # and further in

static var _shader: Shader = null

var _material: ShaderMaterial = null
var _cells: Vector2i = Vector2i.ZERO
var _step_m: float = SHEET_STEP_M


func _init() -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER

	_material = ShaderMaterial.new()
	_material.shader = _shader
	visible = false


# A chunk's settled water (water_grid.gd decode: count x count points `spacing` apart from the chunk's corner) as a liquid image: R surface, G/B the current,
# A a depth stand-in (the client has no ground here): OPEN_DEPTH_M inside, SHORE_DEPTH_M next to a dry point, 0 on shore and dry points. Shore points
# (`edge`) carry their own level; dry points take the mean of their wet neighbours' levels so the sheet tucks under the bank there. null when dry.
static func image_from_grid(grid: Dictionary) -> Image:
	var count: int = int(grid.get("count", 0))
	var levels: PackedFloat32Array = grid.get("levels", PackedFloat32Array())

	if count < 2 or int(grid.get("wet", 0)) == 0 or levels.size() != count * count:
		return null

	var edge: PackedFloat32Array = grid.get("edge", PackedFloat32Array())
	var vel: PackedFloat32Array = grid.get("vel", PackedFloat32Array())
	var im: Image = Image.create(count, count, false, Image.FORMAT_RGBAF)

	for j in range(count):
		for i in range(count):
			var n: int = j * count + i
			var level: float = levels[n]

			if not is_nan(level):
				var open: bool = true

				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var a: int = i + d.x
					var b: int = j + d.y

					if a >= 0 and b >= 0 and a < count and b < count and is_nan(levels[b * count + a]):
						open = false

				var vx: float = vel[n * 2] if vel.size() == levels.size() * 2 else 0.0
				var vz: float = vel[n * 2 + 1] if vel.size() == levels.size() * 2 else 0.0
				im.set_pixel(i, j, Color(level, vx, vz, OPEN_DEPTH_M if open else SHORE_DEPTH_M))
				continue

			var near: float = 0.0
			var seen: int = 0

			for dj in range(-1, 2):
				for di in range(-1, 2):
					var a: int = i + di
					var b: int = j + dj

					if a >= 0 and b >= 0 and a < count and b < count and not is_nan(levels[b * count + a]):
						near += levels[b * count + a]
						seen += 1

			var here: float = edge[n] if not edge.is_empty() and not is_nan(edge[n]) else (near / float(seen) - 0.4 if seen > 0 else -1000.0)
			im.set_pixel(i, j, Color(here, 0.0, 0.0, 0.0))

	return im


# A chunk's sheet: `corner` is the world x, z of grid point (0, 0); the texels sit on the grid points, the sheet spans them exactly (no overlap with the
# next chunk's sheet).
func show_points(im: Image, corner: Vector2, spacing: float) -> void:
	var cells: Vector2i = Vector2i(im.get_width(), im.get_height())
	var size: Vector2 = Vector2(cells - Vector2i.ONE) * spacing
	_step_m = CHUNK_STEP_M

	if cells != _cells:
		_cells = cells
		_set_plane(size)

	position = Vector3(corner.x + size.x * 0.5, 0.0, corner.y + size.y * 0.5)
	_material.set_shader_parameter("liquid", ImageTexture.create_from_image(im))
	_material.set_shader_parameter("cells", Vector2(cells))
	_material.set_shader_parameter("fade_cells", 0.0)
	_material.set_shader_parameter("point_grid", 1.0)
	_material.set_shader_parameter("cell_m", spacing)
	visible = true


# The live window's rectangle (world corner, size): a chunk sheet does not draw there, from `inset` metres in, where the window's own sheet has faded in.
func set_hole(corner: Vector2, size: Vector2, inset: float) -> void:
	_material.set_shader_parameter("hole", Vector4(corner.x, corner.y, size.x, size.y))
	_material.set_shader_parameter("hole_inset", inset)


func _set_plane(size: Vector2) -> void:
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = size
	plane.subdivide_width = maxi(int(size.x / _step_m) - 1, 1)
	plane.subdivide_depth = maxi(int(size.y / _step_m) - 1, 1)
	plane.material = _material
	mesh = plane
	# The surface heights move every publish: the bounds must hold any of them.
	custom_aabb = AABB(Vector3(-size.x * 0.5, -200.0, -size.y * 0.5), Vector3(size.x, 2400.0, size.y))


# The newest window from the server (water_flow_texture.unpack): `origin` is the world x, z of cell (0, 0).
func show_window(im: Image, origin: Vector2, cell_m: float) -> void:
	var cells: Vector2i = Vector2i(im.get_width(), im.get_height())
	var size: Vector2 = Vector2(cells) * cell_m

	if cells != _cells:
		_cells = cells
		_set_plane(size)

	# The texture covers the cells' squares: from half a cell before cell (0, 0). A PlaneMesh is centred on its node and its UV runs 0..1 from -x, -z.
	var corner: Vector2 = origin - Vector2(0.5, 0.5) * cell_m
	position = Vector3(corner.x + size.x * 0.5, 0.0, corner.y + size.y * 0.5)
	_material.set_shader_parameter("liquid", ImageTexture.create_from_image(im))
	_material.set_shader_parameter("cells", Vector2(cells))
	_material.set_shader_parameter("fade_cells", FADE_CELLS)
	_material.set_shader_parameter("cell_m", cell_m)
	visible = true


func set_mud(value: float) -> void:
	_material.set_shader_parameter("mud", value)


func set_rain(value: float) -> void:
	_material.set_shader_parameter("rain", value)


func set_daylight(value: float) -> void:
	_material.set_shader_parameter("daylight", value)
