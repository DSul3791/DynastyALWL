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
uniform float clarity_m = 0.45;      // water this thick hides about two thirds of what is behind it
uniform float edge_alpha = 0.35;     // the thinnest water
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;

varying float sheet_alpha;

void vertex() {
	sheet_alpha = COLOR.a;
}

void fragment() {
	float scene = texture(depth_texture, SCREEN_UV).r;
	vec4 behind = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, scene, 1.0);
	behind.xyz /= behind.w;
	float through = max(VERTEX.z - behind.z, 0.0);   // meters of water along the view ray
	float murk = 1.0 - exp(-through / clarity_m);
	ALBEDO = mix(shallow_color, deep_color, murk);
	ALPHA = mix(edge_alpha, 0.97, murk) * sheet_alpha;
	ROUGHNESS = 0.08;
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
