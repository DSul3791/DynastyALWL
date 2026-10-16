extends RefCounted

# The ground's look (starter-town playtest work): each voxel's ground
# material (terrain_layout.gd CHANNEL_MATERIAL) drawn in its soil or rock
# color from soils.json and rocks.json, blended across cells by the mesher
# (VoxelMesherTransvoxel TEXTURES_SINGLE_S4: CUSTOM1.x packs 4 material
# indices, CUSTOM1.y their 4 weights). Steep slopes darken toward bare
# stone; the sea bed is muddied.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const PALETTE_SIZE := 64

const SHADER := """
shader_type spatial;
uniform vec3 palette[64];
varying vec3 world_pos;
varying vec3 world_normal;
varying vec4 material_indices;
varying vec4 material_weights;

vec4 decode_8bit_vec4(float v) {
	uint i = floatBitsToUint(v);
	return vec4(float(i & 255u), float((i >> 8u) & 255u), float((i >> 16u) & 255u), float((i >> 24u) & 255u));
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	material_indices = decode_8bit_vec4(CUSTOM1.x);
	material_weights = decode_8bit_vec4(CUSTOM1.y) / 255.0;
}

void fragment() {
	float total = max(dot(material_weights, vec4(1.0)), 0.0001);
	vec3 color = vec3(0.0);
	for (int n = 0; n < 4; n++) {
		color += palette[clamp(int(material_indices[n] + 0.5), 0, 63)] * material_weights[n];
	}
	color /= total;
	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	color = mix(color, color * 0.7 + vec3(0.42, 0.40, 0.38) * 0.3, smoothstep(0.3, 0.6, slope));
	color = mix(vec3(0.35, 0.33, 0.28), color, smoothstep(-3.0, 0.0, world_pos.y));
	ALBEDO = color;
	ROUGHNESS = 0.9;
}
"""


# The palette: soil id n at n, rock id n at MATERIAL_ROCK + n.
static func palette(tables) -> PackedVector3Array:
	var colors: PackedVector3Array = PackedVector3Array()
	colors.resize(PALETTE_SIZE)
	colors.fill(Vector3(0.5, 0.5, 0.5))

	for entry in tables.get_entries("soils"):
		_put(colors, int(entry["id"]), entry)

	for entry in tables.get_entries("rocks"):
		_put(colors, Layout.MATERIAL_ROCK + int(entry["id"]), entry)

	return colors


static func make(tables) -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("palette", palette(tables))
	return material


static func _put(colors: PackedVector3Array, index: int, entry: Dictionary) -> void:
	var rgb: Variant = entry.get("color")

	if index < 0 or index >= PALETTE_SIZE or typeof(rgb) != TYPE_ARRAY or rgb.size() != 3:
		return

	colors[index] = Vector3(float(rgb[0]), float(rgb[1]), float(rgb[2]))
