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
uniform vec3 sky_top : source_color = vec3(0.385, 0.454, 0.55);       // ProceduralSkyMaterial defaults
uniform vec3 sky_horizon : source_color = vec3(0.6463, 0.6558, 0.6708);
uniform float refraction = 1.0;      // 0 (Low quality): see-through by blending; 1: the bottom bends under the ripples
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

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

// Gradient noise (smooth, no square blocks like value noise; owner 2026-10-19: blocky water).
vec2 gradient(vec2 i) {
	float a = hash(i) * 6.2831853;
	return vec2(cos(a), sin(a));
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = dot(gradient(i), f);
	float b = dot(gradient(i + vec2(1.0, 0.0)), f - vec2(1.0, 0.0));
	float c = dot(gradient(i + vec2(0.0, 1.0)), f - vec2(0.0, 1.0));
	float d = dot(gradient(i + vec2(1.0, 1.0)), f - vec2(1.0, 1.0));
	return 0.5 + 0.7 * mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Octaves turned against each other so no grid direction shows.
float ripples(vec2 p) {
	const mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	vec2 q = turn * p * 2.1 + 17.0;
	return noise(p) * 0.62 + noise(q) * 0.28 + noise(turn * q * 2.2 - 9.0) * 0.10;
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
	// Ripples fade with distance (far away they only sparkle in single pixels).
	float distance_m = length(VERTEX);
	bump *= 1.0 / (1.0 + distance_m / 35.0);
	// The mesh's own normal tilts differently on each 8 m square; water is nearly flat, so
	// lean it toward straight up to hide the square seams.
	vec3 up = normalize(mix((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz, vec3(0.0, 1.0, 0.0), 0.75));
	vec3 normal_world = normalize(up - vec3(bump.x, 0.0, bump.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_world, 0.0)).xyz);

	// Sky in the water (the plan for Atlas-like water, step 1): the surface mirrors the sky
	// more the lower the view angle (Fresnel), from the horizon colour to the sky above.
	vec3 to_eye = normalize(INV_VIEW_MATRIX[3].xyz - world_pos);
	float facing = clamp(dot(normal_world, to_eye), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
	vec3 mirrored = reflect(-to_eye, normal_world);
	vec3 sky = mix(sky_horizon, sky_top, sqrt(clamp(mirrored.y, 0.0, 1.0)));

	// Shore foam (step 3): a soft, moving line where the water thins against the bank.
	float thickness = through * max(to_eye.y, 0.15);
	float shore = 1.0 - smoothstep(0.02, 0.35, thickness);
	float shore_foam = shore * smoothstep(0.42, 0.68, ripples(local / 1.3 + vec2(drift * 0.12, -drift * 0.08)));

	// Patches of foam carried by the flow (the same moving pattern as the ripples, coarser).
	// Owner (2026-10-19): stretching the foam along the local flow direction drew zigzags,
	// because the direction changes from square to square; carried noise has no seams.
	float carried_a = ripples(local / 3.0 - velocity * phase0 * cycle / 3.0);
	float carried_b = ripples(local / 3.0 + 13.0 - velocity * phase1 * cycle / 3.0);
	float streaks = smoothstep(0.56, 0.82, mix(carried_a, carried_b, blend));
	// Foam follows the water speed (about the square root of the slope): riffles on ordinary
	// streams already show some, fast water much more.
	float speed = sqrt(steep);
	float foam = streaks * smoothstep(mix(0.2, 0.05, rough), mix(0.55, 0.3, rough), speed) * step(0.001, steep);
	// White water breaking on the fastest stretches when the flow is high.
	float white = mix(ripples(p * 1.7 - velocity * phase0 * cycle * 1.7 / scale), ripples(p * 1.7 + 5.0 - velocity * phase1 * cycle * 1.7 / scale), blend);
	foam = max(foam, smoothstep(0.5, 0.75, white) * rough * smoothstep(0.1, 0.4, speed));
	foam = max(foam, shore_foam * 0.8);
	foam *= 1.0 / (1.0 + distance_m / 120.0);

	vec3 water = mix(mix(shallow_color, deep_color, murk), mud_color * mix(1.0, 0.7, murk), mud);
	vec3 foam_tint = mix(foam_color, mud_color * 1.6, mud * 0.6);
	float body_alpha = mix(edge_alpha, 0.97, murk);

	if (refraction > 0.5) {
		// Refraction (step 2): look through the water at the scene behind it, pushed sideways
		// by the ripples; only where what is seen there really lies behind the water.
		vec2 bent_uv = SCREEN_UV + bump * 0.04 * (1.0 - murk) / (1.0 + distance_m / 20.0);
		float bent_depth = texture(depth_texture, bent_uv).r;
		vec4 bent_behind = INV_PROJECTION_MATRIX * vec4(bent_uv * 2.0 - 1.0, bent_depth, 1.0);
		bent_behind.xyz /= bent_behind.w;
		bent_uv = bent_behind.z < VERTEX.z ? bent_uv : SCREEN_UV;
		vec3 below = textureLod(screen_texture, bent_uv, 0.0).rgb;
		vec3 seen = mix(below, water, body_alpha);
		seen = mix(seen, sky, fresnel * 0.8);
		// The lighting adds the sun glint on top; keep the body itself unlit-looking.
		ALBEDO = mix(seen * 0.6, foam_tint, foam * 0.85);
		EMISSION = seen * 0.4 * (1.0 - foam);
		ALPHA = sheet_alpha;
	} else {
		ALBEDO = mix(mix(water, sky, fresnel * 0.8), foam_tint, foam * 0.85);
		ALPHA = max(max(body_alpha, fresnel * 0.8), foam * 0.9) * sheet_alpha;
	}
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


# Quality (F2): Low blends the water over the ground; Medium and up bend the view through it.
static func apply_quality(material: ShaderMaterial, quality: int) -> void:
	if material != null:
		material.set_shader_parameter("refraction", 1.0 if quality >= 1 else 0.0)
