extends RefCounted

# The sky with drifting clouds (owner, 2026-10-19: "can we now add clouds"). Client only.
# Puffy fair-weather clouds on a layer about 2 km up, carried by a steady wind and slowly
# changing shape (each octave drifts at its own speed), lit from the sun: bright tops,
# blue-grey shaded sides, a silver edge when they pass near the sun. Thin high streaks
# above them from Medium up. The camera's own position moves through the layer, so flying
# or riding fast passes under the clouds.
#
# Cost follows quality (F2): Low has 3 noise octaves and no high streaks, Medium 4, High 5
# with a second light sample, Ultra 6. (Half and quarter resolution sky passes were tried
# and drew a white sky in the test renderer, so the clouds draw at full resolution.)
# The sky's lighting cubemap (ambient light and reflections) is drawn once with a cheap cloud cover and is not redrawn as the clouds move (PROCESS_MODE_QUALITY),
# so moving clouds cost no cubemap updates. TIME wraps once an hour (Godot default), so the
# cloud field jumps once an hour; no weather system yet (coverage is fixed).

const SHADER := """
shader_type sky;

uniform vec3 sky_top_color : source_color = vec3(0.33, 0.47, 0.68);
uniform vec3 sky_horizon_color : source_color = vec3(0.63, 0.68, 0.75);
uniform vec3 ground_bottom_color : source_color = vec3(0.2, 0.169, 0.133);
uniform vec3 ground_horizon_color : source_color = vec3(0.63, 0.68, 0.75);
uniform vec3 cloud_shadow_color : source_color = vec3(0.46, 0.52, 0.62);
uniform float cloud_height_m = 2000.0;   // base of the cloud layer above sea level
uniform float cloud_scale_m = 1800.0;    // size of the biggest cloud shapes
uniform float coverage = 0.53;           // higher = fewer clouds (0.4 overcast, 0.62 a few)
uniform float softness = 0.2;            // width of the cloud edge
uniform vec2 wind_m_s = vec2(9.0, 4.0);  // drift of the cloud layer (east, south)
uniform float cirrus_amount = 0.3;
uniform float sun_angle_max = 0.52;      // glow around the sun (radians)
uniform float sun_curve = 0.15;
uniform float gloom = 0.0;               // 0 clear, 1 storm: sky and clouds turn dark grey (weather_look.gd)
uniform float night = 0.0;               // 0 day .. 1 night: stars (day_cycle.gd)
uniform float flash = 0.0;               // lightning: lights the clouds from within (weather_look.gd)

// No sine in the hash: stays exact for large coordinates.
float hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Octaves turned against each other so no grid shows; each drifts a little faster than the
// one below it so clouds change shape as they travel. foot is the size of a pixel on the
// layer in noise units: octaves finer than that fade to grey so the far clouds do not sparkle.
float fbm(vec2 p, int octaves, float foot, vec2 drift) {
	const mat2 turn = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float sum = 0.0;
	float amp = 0.5;
	float freq = 1.0;
	float total = 0.0;
	for (int i = 0; i < octaves; i++) {
		float keep = clamp(1.2 - freq * foot * 6.0, 0.0, 1.0);
		sum += amp * mix(0.5, noise(p + drift * float(i) * 0.35), keep);
		total += amp;
		p = turn * p * 2.03 + 11.7;
		amp *= 0.5;
		freq *= 2.03;
	}
	return sum / total;
}

vec3 base_sky(vec3 dir, bool with_sun) {
	float v_angle = acos(clamp(dir.y, -1.0, 1.0));
	vec3 color;
	if (dir.y >= 0.0) {
		float c = 1.0 - v_angle / (PI * 0.5);
		color = mix(sky_horizon_color, sky_top_color, clamp(1.0 - pow(1.0 - c, 1.0 / 0.15), 0.0, 1.0));
	} else {
		float c = (v_angle - PI * 0.5) / (PI * 0.5);
		// Tyler (2026-10-21): the sea plane ends 6 km out, so from height a strip of this below-horizon sky shows
		// between its rim and the horizon, and it was a dark brown band. It now stays close to the horizon colour.
		color = mix(ground_horizon_color, mix(ground_horizon_color, ground_bottom_color, 0.25), clamp(1.0 - pow(1.0 - c, 1.0 / 0.02), 0.0, 1.0));
	}
	if (with_sun && LIGHT0_ENABLED) {
		float sun_angle = acos(clamp(dot(LIGHT0_DIRECTION, dir), -1.0, 1.0));
		vec3 sun = LIGHT0_COLOR * LIGHT0_ENERGY;
		if (sun_angle < LIGHT0_SIZE) {
			color = sun;
		} else if (sun_angle < sun_angle_max) {
			float c2 = (sun_angle - LIGHT0_SIZE) / (sun_angle_max - LIGHT0_SIZE);
			color = mix(sun, color, clamp(1.0 - pow(1.0 - c2, 1.0 / sun_curve), 0.0, 1.0));
		}
	}
	return color;
}

// Cloud colour (rgb) and cover (a) in the view direction.
vec4 clouds(vec3 dir, vec3 eye, int octaves, int light_samples, bool cirrus, float pixel) {
	if (dir.y < 0.01) {
		return vec4(0.0);
	}
	vec3 sun_dir = LIGHT0_ENABLED ? LIGHT0_DIRECTION : vec3(0.0, 1.0, 0.0);
	vec3 sun = LIGHT0_ENABLED ? LIGHT0_COLOR * LIGHT0_ENERGY : vec3(1.0);
	float toward_sun = max(dot(dir, sun_dir), 0.0);
	float haze = smoothstep(0.03, 0.4, dir.y);   // far clouds melt into the horizon
	vec4 result = vec4(0.0);

	if (cirrus) {
		float t2 = max(cloud_height_m * 4.0 - eye.y, 500.0) / dir.y;
		vec2 p2 = (eye.xz + dir.xz * t2 + wind_m_s * TIME * 2.0) / (cloud_scale_m * 3.0);
		vec2 along = normalize(wind_m_s);
		vec2 s = vec2(dot(p2, along) * 0.6, dot(p2, vec2(-along.y, along.x)) * 1.8);
		float n2 = fbm(s, 3, t2 * pixel / (cloud_scale_m * 3.0), vec2(0.0));
		float a2 = smoothstep(0.58, 0.85, n2) * cirrus_amount * haze * haze;
		vec3 c2 = mix(cloud_shadow_color, sun, 0.75 + 0.25 * toward_sun);
		result = vec4(c2, a2);
	}

	float h = max(cloud_height_m - eye.y, 200.0);
	float t = h / dir.y;
	vec2 drift = wind_m_s * TIME / cloud_scale_m;
	vec2 p = (eye.xz + dir.xz * t) / cloud_scale_m + drift;
	float foot = t * pixel / cloud_scale_m;
	vec2 morph = drift * 0.6;
	float n = fbm(p, octaves, foot, morph);
	float cover = smoothstep(coverage, coverage + softness, n);
	if (cover <= 0.0) {
		return result;
	}

	// Light: denser cloud between this point and the sun means a shaded side.
	vec2 to_sun = normalize(sun_dir.xz + vec2(1e-4)) * (1.0 - sun_dir.y * 0.7);
	float shade = 0.0;
	for (int i = 1; i <= light_samples; i++) {
		float m = fbm(p + to_sun * 0.06 * float(i), max(octaves - 2, 2), foot, morph);
		shade += max(m - n, 0.0);
	}
	shade = shade / float(light_samples);
	float lit = exp(-shade * 9.0);
	float core = smoothstep(coverage + 0.05, coverage + 0.4, n);   // thick middles have greyer bellies
	vec3 color = mix(cloud_shadow_color, sun, lit * (1.0 - 0.35 * core));
	color *= 1.0 - 0.18 * core;
	color += sun * pow(toward_sun, 10.0) * (1.0 - cover) * 1.2;      // silver edge near the sun
	color = mix(sky_horizon_color, color, 0.35 + 0.65 * haze);
	float alpha = cover * (0.25 + 0.75 * haze);
	return vec4(mix(result.rgb, color, alpha), result.a + alpha * (1.0 - result.a));
}

// Stars: one jittered point per cell of a 3D grid over the sky, a few of the cells lit, some brighter.
vec3 stars(vec3 dir) {
	vec3 p = dir * 140.0;
	vec3 cell = floor(p);
	float h = hash(cell.xy + cell.z * 57.31);
	if (h < 0.985) {
		return vec3(0.0);
	}
	vec3 at = vec3(hash(cell.yz + 3.1), hash(cell.zx + 7.7), hash(cell.xy + 11.3));
	float d = length(fract(p) - (0.2 + 0.6 * at));
	float size = 0.1 + 0.08 * hash(cell.xz + 19.9);
	float bright = smoothstep(size, 0.0, d) * (0.4 + 1.6 * hash(cell.xy + 29.0 + cell.z));
	return vec3(0.85, 0.9, 1.0) * bright;
}

// Weather grading: grey and darker with gloom (weather_look.gd uses the same formula for the
// fog), and a lightning flash that lights the clouds far more than the open sky.
vec3 weather_grade(vec3 c, float cover) {
	float grey = (c.r + c.g + c.b) / 3.0 * (1.0 - 0.6 * gloom);
	c = mix(c, vec3(grey), 0.85 * gloom);
	c += flash * vec3(0.55, 0.6, 0.85) * (0.15 + 1.2 * cover);
	return c;
}

void sky() {
	if (AT_CUBEMAP_PASS) {
		// Ambient light and reflections: a cheap, still cloud cover.
		vec4 c = clouds(EYEDIR, POSITION, 3, 1, false, 0.01);
		COLOR = weather_grade(mix(base_sky(EYEDIR, true), c.rgb, c.a), c.a);
	} else {
		vec4 c = clouds(EYEDIR, POSITION, OCTAVES, LIGHT_SAMPLES, CIRRUS, 0.001);
		COLOR = weather_grade(mix(base_sky(EYEDIR, true), c.rgb, c.a), c.a);
		if (night > 0.0 && EYEDIR.y > 0.0) {
			COLOR += stars(EYEDIR) * night * (1.0 - c.a) * (1.0 - gloom) * smoothstep(0.0, 0.12, EYEDIR.y);
		}
	}
}
"""

# The sky colour at the horizon (the shader's sky_horizon_color); the client's fog uses it so
# far hills melt into the sky.
const HORIZON := Color(0.63, 0.68, 0.75)

# Per quality (Low, Medium, High, Ultra): octaves, light samples, high streaks.
const OCTAVES := [3, 4, 5, 6]
const LIGHT_SAMPLES := [1, 1, 2, 2]
const CIRRUS := [false, true, true, true]

static var _shaders: Array = [null, null, null, null]


static func shader_for(quality: int) -> Shader:
	var q: int = clampi(quality, 0, OCTAVES.size() - 1)
	if _shaders[q] == null:
		var shader: Shader = Shader.new()
		var defines: String = "#define OCTAVES %d\n#define LIGHT_SAMPLES %d\n#define CIRRUS %s\n" % [
			OCTAVES[q], LIGHT_SAMPLES[q], "true" if CIRRUS[q] else "false"]
		# Windows checkouts have CRLF line ends (.gitattributes text=auto), so match the first
		# line without its newline; build 44 matched "\n" only, the defines went missing and the
		# shader failed to compile on the owner's PC (black sky, dark ambient light).
		shader.code = SHADER.replace("\r", "").replace("shader_type sky;", "shader_type sky;\n" + defines)
		_shaders[q] = shader
	return _shaders[q]


static func make_sky(quality: int) -> Sky:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader_for(quality)
	var sky: Sky = Sky.new()
	sky.sky_material = material
	# Drawn once: the moving clouds are not redrawn into the lighting cubemap (see top).
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	return sky


static func set_quality(sky: Sky, quality: int) -> void:
	var material: ShaderMaterial = sky.sky_material as ShaderMaterial
	if material != null:
		material.shader = shader_for(quality)
