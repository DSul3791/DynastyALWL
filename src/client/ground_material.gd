extends RefCounted

# The ground's look (starter-town playtest work): each voxel's ground
# material (terrain_layout.gd CHANNEL_MATERIAL) drawn in its soil or rock
# color from soils.json and rocks.json, blended across cells by the mesher
# (VoxelMesherTransvoxel TEXTURES_SINGLE_S4: CUSTOM1.x packs 4 material
# indices, CUSTOM1.y their 4 weights). Steep slopes darken toward bare
# stone (rock) or bare earth (soil); mud (lake and river beds) is glossy;
# the sea bed is muddied.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const PALETTE_SIZE := 64

const SHADER := """
shader_type spatial;
uniform vec3 palette[64];
// Ground detail (ART_DIRECTION.md step 2): six tileable surface textures in one array
// (0 turf, 1 forest litter, 2 gravel, 3 mud and clay, 4 sand, 5 rock). R is a brightness
// detail the soil colour is multiplied by, G and B a bump, A the height. Each palette
// entry names the layer it uses; a mix of materials mixes the layers.
uniform sampler2DArray ground_detail : filter_linear_mipmap, repeat_enable;
uniform float layer_of[64];
uniform float layer_mean[6];
uniform float layer_strength[6];
uniform float tile_m = 3.0;             // metres one texture tile covers
uniform bool triplanar = true;          // Low skips the side projections
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
	float stone = 0.0;
	float mud = 0.0;
	for (int n = 0; n < 4; n++) {
		int index = clamp(int(material_indices[n] + 0.5), 0, 63);
		color += palette[index] * material_weights[n];
		stone += (index >= 32 || index == 0) ? material_weights[n] : 0.0;
		mud += (index == 16) ? material_weights[n] : 0.0;
	}
	color /= total;
	stone /= total;
	mud /= total;

	// The table colors are display (sRGB) values; convert so they read as
	// intended, then mute them toward natural earth tones.
	color = pow(color, vec3(2.2));
	float grey = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(grey), color, 0.78) * 1.25;

	float slope = 1.0 - clamp(world_normal.y, 0.0, 1.0);
	float rock_mask = smoothstep(0.3, 0.6, slope);
	// Steep faces: stone turns toward grey rock, soil toward darker bare earth.
	vec3 steep_tint = mix(vec3(0.40, 0.31, 0.21), vec3(0.42, 0.40, 0.38), stone);
	color = mix(color, color * 0.7 + steep_tint * 0.15, rock_mask);

	// Detail: broad noise for patches, painted textures for the surface up close. The
	// texture fades out with distance so far ground stays calm and cheap.
	float dist = length(VERTEX);
	float closeness = 1.0 - smoothstep(60.0, 260.0, dist);
	float large = vnoise(world_pos * 0.012);
	float medium = vnoise(world_pos * 0.31) * 0.6 + vnoise(world_pos * 0.9 + 7.0) * 0.4;
	color *= 1.0 + (medium - 0.5) * 0.35;

	float lw[6];
	for (int k = 0; k < 6; k++) {
		lw[k] = 0.0;
	}
	for (int n = 0; n < 4; n++) {
		int index = clamp(int(material_indices[n] + 0.5), 0, 63);
		lw[clamp(int(layer_of[index] + 0.5), 0, 5)] += material_weights[n] / total;
	}
	// Steep faces are drawn as rock.
	for (int k = 0; k < 5; k++) {
		lw[k] *= 1.0 - rock_mask;
	}
	lw[5] = mix(lw[5], 1.0, rock_mask);

	vec3 tw = vec3(0.0, 1.0, 0.0);
	if (triplanar && world_normal.y < 0.93) {
		tw = pow(abs(world_normal), vec3(4.0));
		tw /= tw.x + tw.y + tw.z;
	}
	float detail = 0.0;
	float contrast = 0.0;
	vec2 slope_push = vec2(0.0);
	vec2 uv_top = world_pos.xz / tile_m;
	vec2 uv_x = world_pos.zy / tile_m;
	vec2 uv_z = world_pos.xy / tile_m;
	for (int k = 0; k < 6; k++) {
		if (lw[k] < 0.02) {
			continue;
		}
		vec4 t = texture(ground_detail, vec3(uv_top, float(k)));
		float d = t.r;
		vec2 b = t.gb * 2.0 - 1.0;
		if (tw.y < 0.99) {
			d = d * tw.y + texture(ground_detail, vec3(uv_x, float(k))).r * tw.x + texture(ground_detail, vec3(uv_z, float(k))).r * tw.z;
		}
		detail += (d - layer_mean[k]) * layer_strength[k] * lw[k];
		slope_push += b * tw.y * layer_strength[k] * lw[k];
	}
	color *= 1.0 + detail * closeness;
	// Broad patches of dry and lush, so wide fields are not one flat color.
	color *= mix(vec3(1.06, 1.0, 0.86), vec3(0.92, 1.04, 0.94), large);

	// Rock strata on steep faces: bands that wander with the surface.
	float strata = vnoise(vec3(world_pos.x * 0.03, world_pos.y * 0.4 + large * 3.0, world_pos.z * 0.03));
	color *= mix(1.0, 0.8 + 0.35 * strata, rock_mask);

	// Sea bed and shallows: wet, muddy.
	color = mix(vec3(0.07, 0.065, 0.05), color, smoothstep(-3.0, 0.0, world_pos.y));

	// Light touches on the surface: the texture's bump on the normal near the eye.
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(slope_push.x, 0.0, slope_push.y, 0.0)).xyz * 0.6 * closeness);

	ALBEDO = color;
	// Mud is wet: a little sheen.
	ROUGHNESS = mix(0.92, 0.55, mud);
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


# Texture layer of each palette entry: soil ids 0 to 16, rocks at MATERIAL_ROCK + id.
const SOIL_LAYER := [5, 4, 2, 0, 3, 0, 1, 0, 1, 2, 2, 4, 4, 4, 4, 4, 3]
const LAYER_FILES := ["layer_0_turf", "layer_1_litter", "layer_2_gravel", "layer_3_mud", "layer_4_sand", "layer_5_rock"]
const LAYER_MEAN := [0.48, 0.46, 0.56, 0.58, 0.50, 0.68]       # average of each texture's R, so detail is centred
const LAYER_STRENGTH := [0.9, 1.3, 1.1, 0.8, 0.5, 1.1]         # how hard each layer's detail pushes the colour
const TEXTURE_PX := [256, 512, 512, 512]                         # per quality level (Low, Medium, High, Ultra)


static func layers() -> PackedFloat32Array:
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(PALETTE_SIZE)
	out.fill(5.0)

	for n in range(SOIL_LAYER.size()):
		out[n] = float(SOIL_LAYER[n])

	return out


# The six textures as one array, at the size the quality level allows.
static func detail_array(quality: int) -> Texture2DArray:
	var px: int = TEXTURE_PX[clampi(quality, 0, TEXTURE_PX.size() - 1)]
	var images: Array[Image] = []

	for name in LAYER_FILES:
		var path: String = "res://assets/ground/%s.png" % name
		var image: Image = null

		if ResourceLoader.exists(path):
			var imported: Texture2D = load(path) as Texture2D

			if imported != null:
				image = imported.get_image()

				if image != null and image.is_compressed():
					image.decompress()

		if image == null:
			image = Image.load_from_file(ProjectSettings.globalize_path(path))

		if image == null:
			image = Image.create(8, 8, false, Image.FORMAT_RGBA8)
			image.fill(Color(0.5, 0.5, 0.5, 0.5))

		image.convert(Image.FORMAT_RGBA8)

		if image.get_width() != px:
			image.resize(px, px, Image.INTERPOLATE_LANCZOS)

		image.generate_mipmaps()
		images.append(image)

	var array: Texture2DArray = Texture2DArray.new()
	array.create_from_images(images)
	return array


static func make(tables, quality: int = 2) -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = SHADER
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("palette", palette(tables))
	material.set_shader_parameter("layer_of", layers())
	material.set_shader_parameter("layer_mean", PackedFloat32Array(LAYER_MEAN))
	material.set_shader_parameter("layer_strength", PackedFloat32Array(LAYER_STRENGTH))
	material.set_shader_parameter("ground_detail", detail_array(quality))
	material.set_shader_parameter("triplanar", quality >= 1)
	return material


# Quality change: new texture size, side projections on or off.
static func apply_quality(material: ShaderMaterial, quality: int) -> void:
	material.set_shader_parameter("ground_detail", detail_array(quality))
	material.set_shader_parameter("triplanar", quality >= 1)


static func _put(colors: PackedVector3Array, index: int, entry: Dictionary) -> void:
	var rgb: Variant = entry.get("color")

	if index < 0 or index >= PALETTE_SIZE or typeof(rgb) != TYPE_ARRAY or rgb.size() != 3:
		return

	colors[index] = Vector3(float(rgb[0]), float(rgb[1]), float(rgb[2]))
