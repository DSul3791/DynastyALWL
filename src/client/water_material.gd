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
uniform vec3 mud_color : source_color = vec3(0.36, 0.27, 0.16);
uniform float rough = 0.0;           // 0 calm, 1 raging (flow rate above x1, set by the client)
uniform float mud = 0.0;             // 0 clear, 1 brown flood water (rivers and ponds above x1, set by the client)
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
	// No sine: stays exact for the large world coordinates (sin of big numbers breaks up on GPUs).
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
	float murk = 1.0 - exp(-through / (clarity_m * (1.0 - 0.7 * mud)));

	// Running water (owner, 2026-10-19): ripples carried downstream at a speed that grows
	// with the slope (about as the square root, as in real channels); two copies half a
	// cycle apart blend so the pattern never stretches. Still water only shivers.
	float steep = clamp(length(flow), 0.0, 1.0);
	vec2 velocity = steep > 0.001 ? normalize(flow) * fastest_m_s * sqrt(steep) : vec2(0.0);
	// Higher flow: faster, stronger chop, bigger swells and more white water. The pattern
	// moves at most about one ripple per cycle (the cycle shortens as the flow rises), so it
	// always reads as flowing instead of flickering. Positions are taken modulo 4 km to keep
	// precision far from the world origin; time only enters through the repeating phases.
	velocity *= 1.0 + 0.8 * rough;
	float scale = 1.6;
	vec2 local = mod(world_pos.xz, 4096.0);
	vec2 p = local / scale;
	float cycle = mix(1.5, 0.7, rough);            // the same everywhere, so phases never band
	velocity *= min(1.0, 1.2 * scale / max(length(velocity) * cycle, 0.001));
	float phase0 = fract(TIME / cycle);
	float phase1 = fract(TIME / cycle + 0.5);
	float blend = abs(phase0 - 0.5) * 2.0;
	vec2 run = mix(ripple_slope(p - velocity * phase0 * cycle / scale), ripple_slope(p + 31.0 - velocity * phase1 * cycle / scale), blend);
	vec2 swell = mix(ripple_slope(local / 5.0 - velocity * phase0 * cycle / 5.0), ripple_slope(local / 5.0 + 7.0 - velocity * phase1 * cycle / 5.0), blend);
	float drift = mod(TIME, 2000.0);
	vec2 still = ripple_slope(local / 5.0 + vec2(drift * 0.03, drift * 0.02));
	vec2 bump = (run * (0.05 + 0.35 * sqrt(steep)) * (1.0 + 0.8 * rough) + swell * 0.5 * rough) * step(0.001, steep) + still * 0.04;
	vec3 up = (INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(up - vec3(bump.x, 0.0, bump.y)), 0.0)).xyz);

	// Streaks of foam where the water runs fast, stretched along the flow.
	vec2 along = steep > 0.001 ? normalize(flow) : vec2(1.0, 0.0);
	vec2 streak_p = vec2(dot(local, along) * 0.25, dot(local, vec2(-along.y, along.x)) * 1.5);
	float carried = length(velocity) * cycle * 0.25;
	float streaks = smoothstep(0.55, 0.72, mix(ripples(streak_p - vec2(phase0 * carried, 0.0)), ripples(streak_p + 11.0 - vec2(phase1 * carried, 0.0)), blend));
	// Foam follows the water speed (about the square root of the slope): riffles on ordinary
	// streams already show some, fast water much more (owner, 2026-10-19: no foam was seen).
	float speed = sqrt(steep);
	float foam = streaks * smoothstep(mix(0.2, 0.05, rough), mix(0.55, 0.3, rough), speed) * step(0.001, steep);
	// White water breaking on the fastest stretches when the flow is high.
	float white = mix(ripples(p * 1.7 - velocity * phase0 * cycle * 1.7 / scale), ripples(p * 1.7 + 5.0 - velocity * phase1 * cycle * 1.7 / scale), blend);
	foam = max(foam, smoothstep(0.52, 0.7, white) * rough * smoothstep(0.1, 0.4, speed));

	vec3 water = mix(mix(shallow_color, deep_color, murk), mud_color * mix(1.0, 0.7, murk), mud);
	ALBEDO = mix(water, mix(foam_color, mud_color * 1.6, mud * 0.6), foam * 0.85);
	ALPHA = max(mix(edge_alpha, 0.97, murk), foam * 0.9) * sheet_alpha;
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
