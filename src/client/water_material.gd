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
uniform float storm = 0.0;           // 0 calm, 1 big storm: darker, dirtier, murkier, a little more foam (weather_look.gd, lagged)
uniform vec3 storm_color : source_color = vec3(0.13, 0.12, 0.09);
uniform float mud = 0.0;             // 0 clear, 1 brown flood water (rivers and ponds above x1, set by the client)
uniform float clarity_m = 1.1;       // water this thick hides about two thirds of what is behind it (clear brook water: the bed shows)
uniform float edge_alpha = 0.12;     // the thinnest water
uniform float fastest_m_s = 2.5;     // drawn speed of the steepest running water
uniform vec3 sky_top : source_color = vec3(0.33, 0.47, 0.68);         // the sky shader's colours (sky_clouds.gd)
uniform vec3 sky_horizon : source_color = vec3(0.63, 0.68, 0.75);
uniform float far_fade_from_m = 3200.0;   // the sea plane is 12 km across: from here out the water takes the horizon colour
uniform float far_fade_to_m = 5400.0;
uniform vec3 cloud_lit : source_color = vec3(0.92, 0.92, 0.9);
uniform vec3 cloud_shadow : source_color = vec3(0.46, 0.52, 0.62);
uniform float cloud_height_m = 2000.0;   // the cloud layer of sky_clouds.gd, so the mirrored clouds
uniform float cloud_scale_m = 1800.0;    // line up with the ones overhead
uniform float coverage = 0.53;
uniform float softness = 0.2;
uniform vec2 wind_m_s = vec2(9.0, 4.0);
uniform float ice = 0.0;             // 0 open water .. 1 a full sheet of ice on STILL water (src/shared/ice.gd; flora_view.gd set_ice_cover)
uniform float daylight = 1.0;       // 1 day .. about 0.14 night: the body glow follows it (day_cycle.gd, set by weather_look.gd)
uniform vec3 sun_toward = vec3(0.3, 0.8, 0.5);   // the direction to the sun (weather_look.gd), for the sea's glints
uniform float sea = 0.0;             // 1 on the sea plane (terrain_client.gd): swell, depth colours from the beach out, surf foam at the shore, a darker line at the horizon
uniform float debug_flow = 0.0;      // Ctrl+Shift+V: colour the water by what the shader thinks it is (red running, blue still, green foam)
uniform float refraction = 1.0;      // 0 (Low quality): see-through by blending; 1: the bottom bends under the ripples
#ifdef SCENE_READS
// Reading the depth or the screen makes Forward+ copy the whole frame, so Low quality
// (no SCENE_READS) leaves them out: the sky colour and the depth tint come from the vertices.
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
#endif

const float MOUTH_FROM_M = 0.4;        // surface this high above the sea or lower is the river mouth (all sea colour)
const float MOUTH_TO_M = 4.5;          // and this high or more is fresh river water (brown flood colour allowed)

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

// The sky shader's cloud noise (value noise, three octaves; the sky draws more).
float cloud_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// Clouds seen in the water along a mirrored ray: colour (rgb) and cover (a).
vec4 mirrored_clouds(vec3 dir, vec3 from) {
	if (dir.y < 0.01) {
		return vec4(0.0);
	}
	const mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float t = max(cloud_height_m - from.y, 200.0) / dir.y;
	vec2 drift = wind_m_s * TIME / cloud_scale_m;
	vec2 p = (from.xz + dir.xz * t) / cloud_scale_m + drift;
	vec2 morph = drift * 0.6;
	float sum = 0.0;
	float amp = 0.5;
	float total = 0.0;
	for (int i = 0; i < 3; i++) {
		sum += amp * cloud_noise(p + morph * float(i) * 0.35);
		total += amp;
		p = turn * p * 2.03 + 11.7;
		amp *= 0.5;
	}
	float n = sum / total;
	float cover = smoothstep(coverage, coverage + softness, n);
	float core = smoothstep(coverage + 0.05, coverage + 0.4, n);
	float haze = smoothstep(0.03, 0.4, dir.y);
	vec3 color = mix(sky_horizon, mix(cloud_lit, cloud_shadow, 0.4 * core), 0.35 + 0.65 * haze);
	return vec4(color, cover * (0.25 + 0.75 * haze));
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

// The sea's swell: four waves of different length and direction (slopes, not heights: the plane is flat). Long swell runs onto the beach, the short ones glitter in the sun.
vec2 sea_slope(vec2 p, float time, float dist) {
	vec2 slope = vec2(0.0);
	const vec4 dirs[4] = vec4[4](vec4(0.94, 0.34, 64.0, 0.55), vec4(-0.55, 0.83, 29.0, 0.50), vec4(0.38, -0.92, 13.0, 0.45), vec4(-0.97, -0.24, 6.0, 0.40));
	for (int i = 0; i < 4; i++) {
		vec2 d = dirs[i].xy;
		float k = 6.2831853 / dirs[i].z;
		float speed = sqrt(9.81 * k) * 0.6;
		float phase = dot(d, p) * k - time * speed;
		slope += d * k * dirs[i].w * cos(phase) / (1.0 + dist / (dirs[i].z * 25.0));      // a wave fades out at 25 of its own lengths, so far water has only the long swell (no moire)
	}
	return slope;
}

void fragment() {
	// River mouth (owner, 2026-10-21: rivers run into the sea as one body, brown is only a test colour): within
	// a few metres of sea level (0 m) the flood brown fades out, so the river water takes the sea's colour
	// with no edge or step, and where fresh meets salt a soft band of foam rides the water. The sea itself
	// sits at 0 m (mouth 1, no band). Storm colour is shared by both, so the storm look matches.
	float mouth = 1.0 - smoothstep(MOUTH_FROM_M, MOUTH_TO_M, world_pos.y);
	float mud_here = mud * (1.0 - mouth);
	float mouth_band = 4.0 * mouth * (1.0 - mouth);
#ifdef SCENE_READS
	float scene = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	behind.xyz /= behind.w;
	float through = max(VERTEX.z - behind.z, 0.0);   // meters of water along the view ray
#else
	float through = mix(0.1, 1.6, sheet_alpha);      // no depth read at Low: the sheet's edge fade stands in
	if (sea > 0.5) { through = 30.0; }
#endif
	float murk = 1.0 - exp(-through / (clarity_m * (1.0 - 0.7 * mud_here) * (1.0 - 0.65 * storm)));

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
	// Owner playtest (2026-10-19): the GPU time rose with the new water; the costly layers are
	// only worked out where they show (running water, high flow, low view angles).
	bool running = steep > 0.001;
	vec2 run = running ? mix(ripple_slope(p - velocity * phase0 * cycle / scale), ripple_slope(p + 31.0 - velocity * phase1 * cycle / scale), blend) : vec2(0.0);
	vec2 swell = running && rough > 0.001 ? mix(ripple_slope(local / 5.0 - velocity * phase0 * cycle / 5.0), ripple_slope(local / 5.0 + 7.0 - velocity * phase1 * cycle / 5.0), blend) : vec2(0.0);
	float drift = mod(TIME, 2000.0);
	vec2 still = ripple_slope(local / 5.0 + vec2(drift * 0.03, drift * 0.02));
	vec2 bump = (run * (0.05 + 0.35 * sqrt(steep)) * (1.0 + 0.8 * rough) + swell * 0.5 * rough) * step(0.001, steep) + still * 0.04;
	// Ripples fade with distance (far away they only sparkle in single pixels).
	float distance_m = length(VERTEX);
	bump *= 1.0 / (1.0 + distance_m / 35.0);
	if (sea > 0.5) {
		// The swell carries to the horizon, fading slowly; the shortest waves fade first so far water does not shimmer.
		vec2 sw = sea_slope(world_pos.xz, TIME, distance_m);
		bump += sw * 0.55;
	}
	// The mesh's own normal tilts differently on each 8 m square; water is nearly flat, so
	// lean it toward straight up to hide the square seams.
	// A fall (build 325): the sheet's own normal is near horizontal on a drop. The face is a thick
	// white-blue sheet with streaks running down it, whatever lies behind it.
	vec3 face_normal = normalize((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	float face = 1.0 - smoothstep(0.35, 0.8, face_normal.y);
	vec3 up = normalize(mix((INV_VIEW_MATRIX * vec4(NORMAL, 0.0)).xyz, vec3(0.0, 1.0, 0.0), 0.75));
	vec3 normal_world = normalize(up - vec3(bump.x, 0.0, bump.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_world, 0.0)).xyz);

	// Sky in the water (the plan for Atlas-like water, step 1): the surface mirrors the sky
	// more the lower the view angle (Fresnel), from the horizon colour to the sky above,
	// and the clouds of the sky shader drifting with the same wind.
	vec3 to_eye = normalize(INV_VIEW_MATRIX[3].xyz - world_pos);
	float facing = clamp(dot(normal_world, to_eye), 0.0, 1.0);
	float fresnel = 0.02 + 0.98 * pow(1.0 - facing, 5.0);
	vec3 mirrored = reflect(-to_eye, normal_world);
	// Sun on the swell (sea only): a tight bright glint where a wave faces the sun, a broad soft sheen around it.
	float glint = sea > 0.5 ? pow(clamp(dot(mirrored, normalize(sun_toward)), 0.0, 1.0), 350.0) * 5.0 + pow(clamp(dot(mirrored, normalize(sun_toward)), 0.0, 1.0), 14.0) * 0.22 : 0.0;
	vec3 sky = mix(sky_horizon, sky_top, sqrt(clamp(mirrored.y, 0.0, 1.0)));
	vec4 cloud = fresnel > 0.03 ? mirrored_clouds(mirrored, world_pos) : vec4(0.0);
	sky = mix(sky, cloud.rgb, cloud.a);

	// Shore foam (step 3): a soft, moving line where the water thins against the bank.
	float thickness = through * max(to_eye.y, 0.15);
	float shore = 1.0 - smoothstep(0.02, 0.35, thickness);
	float shore_foam = shore > 0.0 ? shore * smoothstep(0.42, 0.68, ripples(local / 1.3 + vec2(drift * 0.12, -drift * 0.08))) : 0.0;

	// Patches of foam carried by the flow (the same moving pattern as the ripples, coarser).
	// Owner (2026-10-19): stretching the foam along the local flow direction drew zigzags,
	// because the direction changes from square to square; carried noise has no seams.
	float streaks = running ? smoothstep(0.56, 0.82, mix(ripples(local / 3.0 - velocity * phase0 * cycle / 3.0), ripples(local / 3.0 + 13.0 - velocity * phase1 * cycle / 3.0), blend)) : 0.0;
	// Foam follows the water speed (about the square root of the slope): riffles on ordinary
	// streams already show some, fast water much more.
	float speed = sqrt(steep);
	// Owner (2026-10-20): foam only behind rocks, on corners, over falls and down rapids; calm
	// ponds and slow straight reaches have none. So the carried foam needs fast water (rapids
	// and falls), the white water more so, and the line along a shore only where the water
	// runs (a bank or rock in fast water), barely at all on still water.
	float foam = streaks * smoothstep(mix(0.5, 0.3, rough), mix(0.85, 0.6, rough), speed) * step(0.001, steep);
	// White water breaking on the fastest stretches when the flow is high.
	float white = running && rough > 0.001 ? mix(ripples(p * 1.7 - velocity * phase0 * cycle * 1.7 / scale), ripples(p * 1.7 + 5.0 - velocity * phase1 * cycle * 1.7 / scale), blend) : 0.0;
	foam = max(foam, smoothstep(0.5, 0.75, white) * rough * smoothstep(0.4, 0.7, speed));
	foam = max(foam, shore_foam * 0.28 * smoothstep(0.25, 0.55, speed));   // 31 Oct: the 13 cm film of a shallow reach is all 'shore' to this term; at 0.8 it drew pale foam strips over whole brooks
	// Soft foam where the river's fresh water meets the sea (moving water only).
	float meet = mouth_band * step(0.001, steep) * smoothstep(0.45, 0.75, ripples(local / 2.2 + vec2(drift * 0.1, -drift * 0.07)));
	foam = max(foam, meet * 0.45);
	foam *= 1.0 / (1.0 + distance_m / 120.0);
	// Streaks running down the face of a fall, brighter near the lip and the foot.
	float fall_streaks = face > 0.01 ? smoothstep(0.45, 0.8, ripples(vec2((world_pos.x + world_pos.z) * 1.7, world_pos.y * 0.22 + drift * 2.5))) : 0.0;
	foam = max(foam, face * (0.08 + 0.55 * fall_streaks));

	if (sea > 0.5) {
		// Surf: a bright line where the water meets the sand, bands of foam that run in and out with the swell over the first metre of depth, fading with distance (the shore reads by colour far off).
		float surf = 1.0 - smoothstep(0.0, 1.5, thickness);
		float pulse = 0.5 + 0.5 * sin(thickness * 5.0 - TIME * 1.15 + noise(local / 7.0) * 3.5);
		float line = 1.0 - smoothstep(0.05, 0.5, thickness);
		float lace = smoothstep(0.35, 0.75, noise(local / 1.7 + vec2(TIME * 0.05, 0.0)));     // the foam breaks into lace, so it reads as foam and not as a painted stripe
		float surf_foam = clamp(surf * smoothstep(0.3, 0.7, pulse) * (0.7 + 0.6 * lace) + line * (0.9 + 0.3 * lace), 0.0, 1.0) / (1.0 + distance_m / 2200.0);
		foam = max(foam, surf_foam);
	}
	murk = max(murk, face * 0.8);
	vec3 water = mix(mix(shallow_color, deep_color, murk), mud_color * mix(1.0, 0.7, murk), mud_here);
	if (sea > 0.5) {
		// From the beach out: turquoise shallows, a mid blue, the deep sea colour (0 to 3 m, 3 to 25 m, beyond); the bottom shows through the shallows.
		vec3 c_shore = vec3(0.30, 0.58, 0.52);
		vec3 c_mid = vec3(0.06, 0.36, 0.47);
		vec3 c_deep = vec3(0.02, 0.12, 0.25);
		water = mix(mix(c_shore, c_mid, smoothstep(0.0, 3.0, thickness)), c_deep, smoothstep(3.0, 25.0, thickness));
		murk = max(murk * 0.5, 1.0 - exp(-thickness / 3.5));
	}
	water = mix(water, storm_color * mix(1.0, 0.6, murk), storm * 0.65);   // storm: dark grey-brown churned water
	foam *= 1.0 + 0.5 * storm;
	vec3 foam_tint = mix(foam_color, mud_color * 1.6, clamp(mud_here * 0.6 + storm * 0.35, 0.0, 1.0));
	float body_alpha = max(mix(edge_alpha, 0.97, murk), face * 0.85);
	// Thin water (a pond edge, a shallow shelf) is seen over its bed at a low angle; mirroring the whole sky there turned ponds into pale grey patches (build 826 play-test, 30 Oct 2026):
	// the sky's share grows from 22 percent at the thinnest (31 Oct: was 40, shallow brook reaches still read as pale grey strips) to full over about a metre of water.
	float mirror_k = mix(0.22, 1.0, murk) * (1.0 - 0.62 * sea);

#ifdef SCENE_READS
	if (refraction > 0.5) {
		// Refraction (step 2): look through the water at the scene behind it, pushed sideways
		// by the ripples; only where what is seen there really lies behind the water.
		vec2 bent_uv = SCREEN_UV + bump * 0.04 * (1.0 - murk) / (1.0 + distance_m / 20.0);
		float bent_depth = texture(depth_texture, bent_uv).r;
		vec4 bent_behind = INV_PROJECTION_MATRIX * vec4(bent_uv * 2.0 - 1.0, bent_depth, 1.0);
		bent_behind.xyz /= bent_behind.w;
		bent_uv = bent_behind.z < VERTEX.z ? bent_uv : SCREEN_UV;
		vec3 below = textureLod(screen_texture, bent_uv, 0.0).rgb;
		// The bed seen through the water: red light is absorbed first, so it greens and
		// darkens with depth (Beer-Lambert), and bright caustic lines from the ripples
		// play on it where the water is shallow (the look of the reference brook).
		float bed_m = min(through, 6.0);
		below *= exp(-bed_m * vec3(0.55, 0.16, 0.10) * (1.0 + 2.0 * mud_here));
		float caustic_fade = (1.0 - smoothstep(0.4, 1.8, bed_m)) * (1.0 - mud_here) / (1.0 + distance_m / 25.0);
		if (caustic_fade > 0.01) {
			vec2 cp = local / 0.9 + vec2(drift * 0.09, drift * 0.06);
			float c1 = 1.0 - abs(noise(cp) * 2.0 - 1.0);
			float c2 = 1.0 - abs(noise(cp * 1.7 - vec2(drift * 0.12, 3.0)) * 2.0 - 1.0);
			below += vec3(1.0, 0.95, 0.8) * pow(c1 * c2, 5.0) * 0.9 * caustic_fade;
		}
		vec3 seen = mix(below, water, body_alpha);
		seen = mix(seen, sky, fresnel * 0.8 * mirror_k * (1.0 - 0.7 * face));
		// The lighting adds the sun glint on top; keep the body itself unlit-looking.
		ALBEDO = mix(seen * 0.6, foam_tint, foam * 0.85);
		EMISSION = seen * 0.4 * (1.0 - foam) * daylight;
		ALPHA = sheet_alpha;
	} else
#endif
	{
		ALBEDO = mix(mix(water, sky, fresnel * 0.8 * mirror_k * (1.0 - 0.7 * face)), foam_tint, foam * 0.85);
		ALPHA = max(max(body_alpha, fresnel * 0.8 * mirror_k), foam * 0.9) * sheet_alpha;
	}
	EMISSION += foam_tint * foam * (sea > 0.5 ? 0.45 : 0.12) * daylight;   // foam is lit by the whole sky, not only the sun, so it stays white against pale sand and a pale sea
	ROUGHNESS = 0.08 + 0.3 * foam;
	SPECULAR = 0.6;

	// The far edge of the sea plane (Tyler, 2026-10-21, a dark tube-like strip at the horizon in every still): the sea
	// is a 12 km plane, so its rim stood against the sky as a band. Far away the water fades to the sky's horizon
	// colour and goes opaque, so the rim and the sky meet without an edge.
	float far_fade = smoothstep(far_fade_from_m, far_fade_to_m, distance_m);
	ALBEDO *= 1.0 - far_fade;
	vec3 far_color = mix(sky_horizon, mix(sky_horizon, deep_color * 2.2 + vec3(0.04, 0.07, 0.10), 0.5), sea);      // the sea ends in a slightly darker band than the sky at the horizon, so the line shows
	EMISSION = mix(EMISSION, far_color, far_fade);
	EMISSION += vec3(1.0, 0.93, 0.78) * glint * daylight * (1.0 - far_fade) * (1.0 - 0.7 * storm);
	ALPHA = mix(ALPHA, 1.0, far_fade);
	SPECULAR *= 1.0 - far_fade;

	// Ice (still water only: running water never freezes). The sheet grows in from the shore and from the shallows,
	// in patches, until it covers everything; a thin sheet is clear and dark (the bed shows), a thick one milky white-blue
	// with cracks. It is flat and glossy: the ripples stop, and no foam rides it.
	if (ice > 0.001 && steep < 0.02) {
		float edge = 1.0 - smoothstep(0.0, 1.4, through);
		float patch = noise(local / 7.0 + 3.7);
		float grown = ice * 1.25 + edge * 0.5 - patch * 0.5 - 0.05;
		float sheet = smoothstep(0.0, 0.25, grown);
		float thick = clamp(ice * 1.4 - 0.15 + 0.3 * patch, 0.0, 1.0);
		// Cracks: thin dark lines where noise crosses its middle, two sizes, more of them in a thin sheet.
		float cr1 = 1.0 - smoothstep(0.0, 0.035, abs(noise(local / 2.6) - 0.5));
		float cr2 = 1.0 - smoothstep(0.0, 0.05, abs(noise(local / 0.9 + 9.0) - 0.5));
		float cracks = clamp(cr1 + 0.5 * cr2, 0.0, 1.0) * (1.0 - 0.5 * thick);
		vec3 clear_ice = vec3(0.30, 0.46, 0.55);
		vec3 milky = vec3(0.80, 0.89, 0.94);
		vec3 ice_col = mix(clear_ice, milky, thick);
		ice_col = mix(ice_col, vec3(0.38, 0.55, 0.68), cracks * 0.7);
		ice_col = mix(ice_col, sky, 0.12 + 0.35 * fresnel);
		float lit = mix(0.55, 1.0, daylight);
		ALBEDO = mix(ALBEDO, ice_col * lit, sheet);
		ALPHA = max(ALPHA, sheet * mix(0.55, 0.97, thick));
#ifdef SCENE_READS
		EMISSION = mix(EMISSION, ice_col * 0.25 * daylight, sheet);
#endif
		ROUGHNESS = mix(ROUGHNESS, 0.18 + 0.2 * cracks, sheet);
		SPECULAR = mix(SPECULAR, 0.9, sheet);
		NORMAL = normalize(mix(NORMAL, (VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz, sheet * 0.95));
	}

	if (debug_flow > 0.5) {
		float red = clamp(steep * 3.0, 0.0, 1.0);
		vec3 mark = vec3(red, clamp(foam * 2.0, 0.0, 1.0), 1.0 - red);
		ALBEDO = mark * 0.8;
		EMISSION = mark * 0.6;
		ALPHA = 0.95;
	}
}
"""

static var _shader: Shader = null        # Medium and up: reads the scene behind the water
static var _shader_low: Shader = null    # Low: no screen or depth copy


static func make() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = "#define SCENE_READS\n" + SHADER
		_shader_low = Shader.new()
		_shader_low.code = SHADER

	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = _shader
	return material


# The sea plane's material: the same shader with the sea look switched on.
static func make_sea() -> ShaderMaterial:
	var material: ShaderMaterial = make()
	material.set_shader_parameter("sea", 1.0)
	return material


# The sky colours and the daylight share the sky shader is using now (day_cycle.gd), so at dusk and at night the water
# mirrors the dark sky and does not glow.
static func apply_day(material: ShaderMaterial, top: Color, horizon: Color, cloud_shadow: Color, daylight: float) -> void:
	if material != null:
		material.set_shader_parameter("sky_top", top)
		material.set_shader_parameter("sky_horizon", horizon)
		material.set_shader_parameter("cloud_shadow", cloud_shadow)
		material.set_shader_parameter("daylight", daylight)


# Quality (F2): Low is the cheap variant (no depth or screen read, blended by vertex alpha);
# Medium and up bend the view through the ripples.
static func apply_quality(material: ShaderMaterial, quality: int) -> void:
	if material != null:
		if _shader == null:
			make()

		material.shader = _shader if quality >= 1 else _shader_low
		material.set_shader_parameter("refraction", 1.0 if quality >= 1 else 0.0)
