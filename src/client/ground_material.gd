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
uniform float wet = 0.0;                // 0 dry, 1 soaked by rain: darker and glossier (weather_look.gd)
uniform float snow = 0.0;               // 0 bare, 1 snow lies on level ground (weather_look.gd)
uniform vec4 fall_zone[3];              // nearest waterfalls: base x, z, spray radius, strength 0..1 (set_falls)
uniform vec2 fall_height[3];            // their base and top height; the walls are damp up to the top
uniform sampler2D canopy : filter_linear, hint_default_black;   // where trees shelter the ground (canopy_map.gd)
uniform vec3 canopy_box = vec3(0.0, 0.0, 128.0);                // its corner x, z and width in metres
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
	// Grass and soil hold on a hillside only up to a point (owner, 2026-10-20: real slopes
	// lose their cover in patches and keep it on ledges): the cover thins as the slope grows,
	// with noise so it breaks up in patches; flat ledges keep theirs because their own surface
	// is flat. grass_view.gd uses the same rule to place the grass.
	float cover_noise = 0.6 * vnoise(world_pos * 0.45) + 0.4 * vnoise(world_pos * 1.6 + 5.0);
	float cover = 1.0 - smoothstep(0.14, 0.42, slope + (cover_noise - 0.5) * 0.24);
	float bare = (1.0 - stone) * (1.0 - cover);
	rock_mask = max(rock_mask, bare);
	// Steep faces: stone turns toward grey rock, soil toward darker bare earth.
	vec3 steep_tint = mix(vec3(0.40, 0.31, 0.21), vec3(0.42, 0.40, 0.38), stone);
	color = mix(color, color * 0.7 + steep_tint * 0.15, rock_mask);
	// Where the cover has failed the stone beneath shows through.
	color = mix(color, vec3(0.22, 0.205, 0.185), bare * 0.8);

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
	// Slopes that lose their cover turn to loose ground first (owner, 2026-10-20): gravel, or sand
	// and gravel where the rock is soft or the patch is dry (broad noise picks), and only the
	// steepest faces show bare cracked rock.
	float face = smoothstep(0.46, 0.7, slope);
	float scree = rock_mask * (1.0 - face);
	float sandy = smoothstep(0.35, 0.65, vnoise(world_pos * 0.017 + 3.0)) * (1.0 - stone * 0.6);
	for (int k = 0; k < 5; k++) {
		lw[k] *= 1.0 - rock_mask;
	}
	lw[2] += scree * (1.0 - 0.55 * sandy);
	lw[4] += scree * 0.55 * sandy;
	lw[5] = mix(lw[5] * (1.0 - scree), 1.0, face * rock_mask);
	color = mix(color, mix(vec3(0.27, 0.25, 0.22), vec3(0.40, 0.34, 0.24), sandy), scree * 0.5);

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
	// Grassy ground takes the colour of the grass drawn on it (grass_view.gd), so the meadow reads
	// as one green carpet near and far, and no dark soil shows between the blades.
	vec3 meadow = mix(vec3(0.15, 0.25, 0.07), vec3(0.22, 0.27, 0.08), large) * (0.85 + 0.3 * medium);
	color = mix(color, meadow, 0.8 * lw[0] * cover);
	// Broad patches of dry and lush, so wide fields are not one flat color.
	color *= mix(vec3(1.06, 1.0, 0.86), vec3(0.92, 1.04, 0.94), large);

	// Rock strata on steep faces: bands that wander with the surface.
	float strata = vnoise(vec3(world_pos.x * 0.03, world_pos.y * 0.4 + large * 3.0, world_pos.z * 0.03));
	color *= mix(1.0, 0.8 + 0.35 * strata, rock_mask);

	// Sea bed and shallows: wet, muddy.
	color = mix(vec3(0.07, 0.065, 0.05), color, smoothstep(-3.0, 0.0, world_pos.y));

	// Waterfall base (owner, 2026-10-20): the spray keeps the rock and ground around a fall wet:
	// darker, glossy, with moss and ferny green on the walls and down the banks.
	float damp = 0.0;
	for (int f = 0; f < 3; f++) {
		float zone_r = fall_zone[f].z;
		if (zone_r > 0.0) {
			float spray = 1.0 - smoothstep(0.3 * zone_r, zone_r, distance(world_pos.xz, fall_zone[f].xy));
			float up = 1.0 - smoothstep(fall_height[f].y, fall_height[f].y + 5.0, world_pos.y);
			float down = smoothstep(fall_height[f].x - 4.0, fall_height[f].x, world_pos.y);
			damp = max(damp, spray * up * down * fall_zone[f].w);
		}
	}
	if (damp > 0.0) {
		float moss_n = vnoise(world_pos * vec3(0.9, 0.6, 0.9)) * 0.65 + vnoise(world_pos * 3.1) * 0.35;
		float moss = damp * smoothstep(0.35, 0.65, moss_n) * (0.55 + 0.45 * rock_mask);
		vec3 moss_color = mix(vec3(0.05, 0.12, 0.04), vec3(0.11, 0.2, 0.06), vnoise(world_pos * 1.7));
		color *= 1.0 - 0.38 * damp;
		color = mix(color, moss_color, moss * 0.8);
	}

	// Light touches on the surface: the texture's bump on the normal near the eye.
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(slope_push.x, 0.0, slope_push.y, 0.0)).xyz * 0.6 * closeness);

	// Weather: rain darkens the ground and gives it a sheen, snow whitens level ground above the sea.
	float shelter = 0.0;
	if (wet + snow > 0.01) {
		vec2 cuv = (world_pos.xz - canopy_box.xy) / canopy_box.z;
		if (cuv.x > 0.0 && cuv.x < 1.0 && cuv.y > 0.0 && cuv.y < 1.0) {
			shelter = texture(canopy, cuv).r;      // under a crown the rain and the snow do not reach the ground
		}
	}
	float soak = wet * (1.0 - shelter);
	color *= 1.0 - 0.35 * soak * (1.0 - snow);
	float lying = snow * (1.0 - 0.75 * shelter) * smoothstep(0.62, 0.9, world_normal.y) * smoothstep(0.0, 1.0, world_pos.y) * (1.0 - 0.6 * rock_mask);
	color = mix(color, vec3(0.88, 0.9, 0.94), lying);
	ALBEDO = color;
	// Mud is wet: a little sheen.
	ROUGHNESS = mix(mix(0.92, 0.55, mud), 0.38, max(soak * 0.7 * (1.0 - lying), damp * 0.8));
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


# Feeds the three nearest waterfalls to the ground shader (flora.fall_list(): top, base, flow, width).
# Spray radius grows with the flow; the moisture is the same at every quality tier (a few ALU ops).
static func set_falls(material: ShaderMaterial, falls: Array, at: Vector3) -> void:
	if material == null:
		return

	var near: Array = []

	for fall in falls:
		var base: Vector3 = fall["base"]
		var d: float = Vector2(base.x - at.x, base.z - at.z).length()

		if d < 220.0:
			near.append([d, fall])

	near.sort_custom(func(a, b): return a[0] < b[0])
	var zones: PackedVector4Array = PackedVector4Array()
	var heights: PackedVector2Array = PackedVector2Array()

	for n in range(3):
		if n < near.size():
			var fall: Dictionary = near[n][1]
			var base: Vector3 = fall["base"]
			var top: Vector3 = fall["top"]
			var flow: float = float(fall["flow"])
			var radius: float = clampf(14.0 + 5.0 * sqrt(maxf(flow, 0.0)) + 0.4 * float(fall["width"]), 14.0, 40.0)
			zones.append(Vector4(base.x, base.z, radius, clampf(0.5 + 0.5 * flow / 20.0, 0.5, 1.0)))
			heights.append(Vector2(base.y, top.y))
		else:
			zones.append(Vector4(0.0, 0.0, 0.0, 0.0))
			heights.append(Vector2(0.0, 0.0))

	material.set_shader_parameter("fall_zone", zones)
	material.set_shader_parameter("fall_height", heights)
