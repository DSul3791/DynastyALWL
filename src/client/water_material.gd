extends RefCounted

# One look for all water, the sea and the rivers and ponds alike (owner, 2026-10-19:
# the river water did not match the sea and was crystal clear). The colour and the
# opacity follow how much water the eye looks through (the scene depth behind the
# surface): a thin edge stays see-through, about a meter of water is nearly opaque
# and deep water is the dark sea colour. Vertex alpha still fades the edge of a sheet.

const SHADER := """
shader_type spatial;
render_mode blend_mix, cull_disabled, shadows_disabled, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.17, 0.33, 0.33);
uniform vec3 deep_color : source_color = vec3(0.04, 0.17, 0.24);
uniform vec3 foam_color : source_color = vec3(0.78, 0.82, 0.80);
uniform float clarity_m = 0.45;      // water this thick hides about two thirds of what is behind it
uniform float edge_alpha = 0.35;     // the thinnest water
uniform float fastest_m_s = 2.5;     // drawn speed of the steepest running water
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying float sheet_alpha;
varying vec2 flow;                   // downhill direction times 0..1 steepness (0 for lakes and the sea)
varying vec3 world_pos;

void vertex() {
	sheet_alpha = COLOR.a;
	// Blue 0 marks a flow from the water grid; meshes without colours (the sea) are still.
	flow = COLOR.b < 0.5 ? (COLOR.rg - 0.5) * 2.0 : vec2(0.0);
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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

float ripples(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.3 + 17.0) * 0.3 + noise(p * 5.1 - 9.0) * 0.1;
}

// Slope of the ripple field (finite differences).
vec2 ripple_slope(vec2 p) {
	float e = 0.08;
	float h = ripples(p);
	return vec2(ripples(p + vec2(e, 0.0)) - h, ripples(p + vec2(0.0, e)) - h) / e;
}

void fragment() {
	float scene = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	behind.xyz /= behind.w;
	float through = max(VERTEX.z - behind.z, 0.0);   // meters of water along the view ray
	float murk = 1.0 - exp(-through / clarity_m);

	// Running water (owner, 2026-10-19): ripples carried downstream at a speed that grows
	// with the slope (about as the square root, as in real channels); two copies half a
	// cycle apart blend so the pattern never stretches. Still water only shivers.
	float steep = clamp(length(flow), 0.0, 1.0);
	vec2 velocity = steep > 0.001 ? normalize(flow) * fastest_m_s * sqrt(steep) : vec2(0.0);
	vec2 p = world_pos.xz / 1.6;
	float cycle = 1.5;
	float phase0 = fract(TIME / cycle);
	float phase1 = fract(TIME / cycle + 0.5);
	float blend = abs(phase0 - 0.5) * 2.0;
	vec2 run = mix(ripple_slope(p - velocity * phase0 * cycle / 1.6), ripple_slope(p + 31.0 - velocity * phase1 * cycle / 1.6), blend);
	vec2 still = ripple_slope(world_pos.xz / 5.0 + vec2(TIME * 0.03, TIME * 0.02));
	vec2 bump = run * (0.05 + 0.35 * sqrt(steep)) * step(0.001, steep) + still * 0.04;
	vec3 up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(up - vec3(bump.x, 0.0, bump.y)), 0.0)).xyz);

	// Streaks of foam where the water runs fast, stretched along the flow.
	vec2 along = steep > 0.001 ? normalize(flow) : vec2(1.0, 0.0);
	vec2 streak_p = vec2(dot(world_pos.xz, along) * 0.25, dot(world_pos.xz, vec2(-along.y, along.x)) * 1.5);
	float streaks = smoothstep(0.62, 0.9, mix(ripples(streak_p - vec2(TIME * length(velocity) * 0.25, 0.0)), ripples(streak_p + 11.0 - vec2(TIME * length(velocity) * 0.25, 0.0)), 0.5));
	float foam = streaks * smoothstep(0.15, 0.8, steep);

	ALBEDO = mix(mix(shallow_color, deep_color, murk), foam_color, foam * 0.5);
	ALPHA = max(mix(edge_alpha, 0.97, murk), foam * 0.8) * sheet_alpha;
	ROUGHNESS = 0.08 + 0.3 * foam;
	SPECULAR = 0.6;
}
"""

static var _shader: Shader = null


static func make() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _shader
	return material
