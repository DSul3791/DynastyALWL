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

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
		mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x), mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y),
		f.z);
}

void fragment() {
	float total = max(dot(material_weights, vec4(1.0)), 0.0001);
	vec3 color = vec3(0.0);
	for (int n = 0; n < 4; n++) {
		color += palette[clamp(int(material_indices[n] + 0.5), 0, 63)] * material_weights[n];
	}
	color /= total;

	// The table colors are display (sRGB) values; convert so they read as
	// intended, then mute them toward natural earth tones.
	color = pow(color, vec3(2.2));
	float grey = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(grey), color, 0.78) * 1.25;

	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float rock_mask = smoothstep(0.3, 0.6, slope);
	color = mix(color, color * 0.7 + vec3(0.42, 0.40, 0.38) * 0.3 * 0.5, rock_mask);

	// Detail from noise in world space: no textures to load. Fine grain fades
	// out with distance so far ground stays calm and cheap.
	float dist = length(VERTEX);
	float closeness = 1.0 - smoothstep(50.0, 220.0, dist);
	float large = vnoise(world_pos * 0.012);
	float medium = vnoise(world_pos * 0.31) * 0.6 + vnoise(world_pos * 0.9 + 7.0) * 0.4;
	float fine = closeness > 0.0 ? vnoise(world_pos * 3.1 + 3.0) : 0.5;
	color *= 1.0 + (medium - 0.5) * 0.45 + (fine - 0.5) * 0.3 * closeness;
	// Broad patches of dry and lush, so wide fields are not one flat color.
	color *= mix(vec3(1.06, 1.0, 0.86), vec3(0.92, 1.04, 0.94), large);

	// Rock strata on steep faces: bands that wander with the surface.
	float strata = vnoise(vec3(world_pos.x * 0.06, world_pos.y * 1.1 + large * 3.0, world_pos.z * 0.06));
	color *= mix(1.0, 0.7 + 0.55 * strata, rock_mask);

	// Sea bed and shallows: wet, muddy.
	color = mix(vec3(0.07, 0.065, 0.05), color, smoothstep(-3.0, 0.0, world_pos.y));

	// Light touches on the surface: a little bump on the normal near the eye.
	vec3 bump = vec3(vnoise(world_pos * 1.3) - 0.5, 0.0, vnoise(world_pos * 1.3 + 11.0) - 0.5);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(bump, 0.0)).xyz * 0.55 * closeness);

	ALBEDO = color;
	ROUGHNESS = 0.92;
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
