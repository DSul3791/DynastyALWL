shader_type spatial;
render_mode world_vertex_coords, cull_disabled;

uniform float water_time = 0.0;
uniform vec4 wave_1 = vec4(1.0, 0.0, 0.45, 0.12);   // dir xz, amplitude m, wave number rad/m
uniform vec4 wave_2 = vec4(0.7, 0.7, 0.22, 0.31);
uniform vec4 wave_3 = vec4(-0.3, 0.95, 0.09, 0.72);
uniform vec4 wave_4 = vec4(0.9, -0.4, 0.06, 1.4);
uniform vec3 deep_color : source_color = vec3(0.018, 0.10, 0.16);
uniform float roughness = 0.12;

varying vec3 surface_world;

vec3 wave_height_gradient(vec2 xz, vec4 wave, float t) {
    vec2 dir = normalize(wave.xy);
    float amplitude = wave.z;
    float k = max(wave.w, 0.0001);
    float phase = k * dot(xz, dir) - sqrt(9.81 * k) * t;
    float height = amplitude * sin(phase);
    vec2 grad = amplitude * k * dir * cos(phase);
    return vec3(height, grad.x, grad.y);
}

void vertex() {
    vec3 a = wave_height_gradient(VERTEX.xz, wave_1, water_time);
    vec3 b = wave_height_gradient(VERTEX.xz, wave_2, water_time);
    vec3 c = wave_height_gradient(VERTEX.xz, wave_3, water_time);
    vec3 d = wave_height_gradient(VERTEX.xz, wave_4, water_time);
    vec3 result = a + b + c + d;
    VERTEX.y += result.x;
    NORMAL = normalize(vec3(-result.y, 1.0, -result.z));
    surface_world = VERTEX;
}

void fragment() {
    // Intentionally OPAQUE baseline: reflection comes from environment lighting.
    // Production refraction, absorption, and shoreline are separate passes.
    ALBEDO = deep_color;
    ROUGHNESS = roughness;
    METALLIC = 0.0;
    SPECULAR = 0.8;
}
