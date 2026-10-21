extends Node3D

# Grass near the player (client only, never stored or synced; DESIGN_IDEAS
# Section 4 "Grass"). The ground around the player is cut into square cells.
# Each cell finds the ground with downward rays against the terrain's own
# collision, keeps spots on grass-bearing soil that are gentle, dry and not
# covered by ore or rock, and draws a tuft there. Tufts sway in the wind, fade
# to nothing toward the edge, and are drawn as painted-texture cards in muted
# storybook greens tinted by the soil, in three layers (ground cover, short
# grass, tall grass patches). Cells are built a few rays per frame so walking never stalls.

const Layout := preload("res://src/worldgen/runtime/terrain_layout.gd")
const TrampleScript := preload("res://src/client/grass_trample.gd")
const CELL_M := 6.0
const RAYS_PER_FRAME := 40
const BUILD_USEC := 5000                 # cells are built for at most this long a frame (at least one)
const LOOKAHEAD_S := 1.5                 # the scan is centred this many seconds of movement ahead
const RESCAN_MSEC := 800                 # the scan also repeats this often while some cell is unbuilt, to retry cells
const IDLE_RESCAN_MSEC := 8000           # and this often when every cell in reach is built
const RETRY_MSEC := 500
const MIN_SLOPE_Y := 0.58                # surface normal y; steeper is bare rock
const COVER_FROM := 0.14                 # slope (1 - normal y) where grass starts to thin
const COVER_TO := 0.42                   # slope where it is gone, except in patches and on ledges
const TUFTS_PER_POINT := 3
# Depth under a crown is 0 at the drip line (the whole crown radius, the same disc as the rain shelter) and 1 at the trunk. Dave 2026-10-21:
# litter and bare ground reach the canopy distance, the grass fading out over the outer fifth so there is no sharp circle.
const CROWN_GRASS_FROM := 0.0            # grass starts thinning at the drip line
const CROWN_GRASS_TO := 0.22             # ... and is nearly gone (4 percent left) a fifth of the way in
const CROWN_LITTER_FROM := 0.0           # litter starts getting denser at the drip line
const CROWN_LITTER_TO := 0.3             # ... and reaches its full depth here
const LITTER_DEEP_LEAVES := 5.0          # leaf cards per sample at full depth, times the normal count
const LITTER_DEEP_TWIGS := 4.0           # twigs likewise
const SCENERY_PEBBLES := true            # owner (2026-10-21): pebbles are decoration (not pickable, not harvestable, like a voxel texture); they vanish when the ground under them is dug (ground_changed)
const SCENERY_BOULDERS := false          # server-owned boulders (Items, build 361) are drawn by inventory_view with GrassView._make_boulder(); the client scenery boulders would double up
const SHORT_SOIL_LIFT := 1.9    # short grass: soil thickness times at most this, capped at 1 (0.5 becomes 0.95, 0.3 becomes 0.57)

# Soil ids that carry grass, with how thick (0 to 1).
const GRASS_SOILS := {3: 0.9, 4: 0.5, 5: 1.0, 6: 0.7, 7: 1.0, 8: 0.6, 9: 0.3}

# The three layers, from the ground up. "reach" is the share of the grass
# radius the layer is drawn to; "per_point" is how many cards per ground sample.
const LAYERS := [
	{"name": "cover", "texture": "ground_cover", "width": 0.6, "height": 0.0, "per_point": 6, "reach": 0.4, "quads": 0, "wind": 0.0, "backlight": 0.0},
	{"name": "short", "texture": "grass_short", "width": 0.8, "height": 0.7, "per_point": 16, "reach": 1.0, "quads": 2, "wind": 1.0, "backlight": 0.0},
	{"name": "tall", "texture": "grass_tall", "width": 0.7, "height": 0.95, "per_point": 6, "reach": 1.0, "quads": 2, "wind": 1.4, "backlight": 0.35},
	# Forest floor under tree crowns (look only, nothing is stored, synced or pickable; section 24 of
	# ART_DIRECTION.md): fallen leaves and dead branches. Drawn within litter_m of the player.
	{"name": "leaves", "texture": "litter", "width": 0.9, "height": 0.0, "per_point": 2, "reach": 1.0, "quads": 0, "wind": 0.0, "backlight": 0.0, "litter": true},
	{"name": "branches", "texture": "", "width": 1.0, "height": 0.0, "per_point": 0.35, "reach": 1.0, "quads": 0, "wind": 0.0, "backlight": 0.0, "litter": true, "branch": true},
	# Shore (ART_DIRECTION.md section 26): pebbles on the banks and on the shallow bed seen through clear
	# water, and reeds where still water meets the land. Drawn within shore_m of the player.
	{"name": "pebbles", "texture": "", "width": 1.0, "height": 0.0, "per_point": 4, "reach": 1.0, "quads": 0, "wind": 0.0, "backlight": 0.0, "shore": true, "pebble": true},
	{"name": "reeds", "texture": "grass_tall", "width": 0.5, "height": 1.5, "per_point": 0.8, "reach": 1.0, "quads": 3, "wind": 1.0, "backlight": 0.35, "shore": true, "reed": true},
	# Boulders (section 31): granite lumps on slopes, mossy on top and on their north side, clustered
	# at the base of slopes and along banks. Drawn within shore_m with the shore layers.
	{"name": "boulders", "texture": "", "width": 1.0, "height": 0.0, "per_point": 0.1, "reach": 1.0, "quads": 0, "wind": 0.0, "backlight": 0.0, "shore": true, "boulder": true},
]
# Distance bands (owner, 2026-10-20: grass 3 ft tall and everywhere, visible tens of metres out). A cell is
# built at one of three levels of detail by its distance from the player and rebuilt, the old cards swapped
# for the new in the same frame, when the player moves it into another band: 0 full samples, 1 half the
# samples per side with cards 1.5 times as wide, 2 two samples per side with cards 2.1 times as wide (no
# ground-cover cards beyond band 0).
const LOD_SCALE := [1.0, 2.0, 3.0, 4.0]       # card width by band: near, middle, far, very far (reach beyond 50 m)
const LOD_SCALE_SHORT := [1.0, 1.5, 2.1, 2.1] # the Low tier (reach 40 m)
const BAND_SHARE := [1.0, 0.4, 0.35, 0.35]    # share of the cards drawn per band beyond 50 m (the cost cap, section 33)
const NEAR_END_MIN := 14.0
const NEAR_END_MAX := 20.0
const CLOSURE_OFFSETS := [Vector2(0.0, 0.0), Vector2(4.0, 0.0), Vector2(-4.0, 0.0), Vector2(0.0, 4.0), Vector2(0.0, -4.0), Vector2(3.0, 3.0), Vector2(-3.0, -3.0)]
const LOD_HYSTERESIS_M := 3.0
const GRASS_LAYERS := 3                  # the first layers are grass; then forest litter, then the shore
const BOULDER_LAYER := 7                 # index of the boulders layer in LAYERS
const LITTER_END := 5                    # layers GRASS_LAYERS to LITTER_END - 1 are litter, the rest shore

# Dead branches: a thin weathered stick with one side twig, lying along x from 0 to 1.
const BRANCH_SHADER := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform float fade_start = 12.0;
uniform float fade_end = 18.0;
varying vec3 wood;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fade = 1.0 - smoothstep(fade_start, fade_end, length(wp - CAMERA_POSITION_WORLD));
	VERTEX *= fade;
	wood = INSTANCE_CUSTOM.rgb;
}

void fragment() {
	ALBEDO = wood;
	ROUGHNESS = 1.0;
}
"""

# Boulders: grey granite with moss on the tops and the north side (north is -z); custom a is how mossy
# this rock is (damp ground, shade), custom rgb the stone colour.
const BOULDER_SHADER := """
shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform float fade_start = 12.0;
uniform float fade_end = 18.0;
uniform vec3 moss_color : source_color = vec3(0.17, 0.27, 0.10);
varying vec3 stone;
varying vec3 world_normal;
varying float mossy;
varying vec3 world_pos;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float fade = 1.0 - smoothstep(fade_start, fade_end, length(wp - CAMERA_POSITION_WORLD));
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	VERTEX *= fade;
	stone = INSTANCE_CUSTOM.rgb;
	mossy = INSTANCE_CUSTOM.a;
	world_pos = wp;
}

void fragment() {
	// Mottle the stone with a soft pattern and lay moss where the face looks up or north, in patches.
	float mottle = 0.5 + 0.25 * sin(world_pos.x * 5.3 + world_pos.z * 3.1) * sin(world_pos.y * 7.7 + world_pos.x * 2.3) + 0.25 * sin(world_pos.z * 11.0 - world_pos.y * 4.0);
	float up = clamp(world_normal.y * 1.1, 0.0, 1.0);
	float north = clamp(-world_normal.z * 0.9, 0.0, 1.0);
	float moss = max(up, north * 0.7) * mossy * (0.6 + 0.8 * mottle);
	moss = smoothstep(0.2, 0.55, moss);
	ALBEDO = mix(stone * (0.85 + 0.3 * mottle), moss_color * (0.8 + 0.4 * mottle), moss);
	ROUGHNESS = 1.0;
}
"""

const SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D blades : source_color, filter_linear_mipmap, repeat_disable;
uniform float fade_start = 20.0;
uniform float fade_end = 30.0;
uniform float wind_strength = 0.12;
uniform float backlight = 0.0;
uniform sampler2D trample : filter_nearest, repeat_enable, hint_default_black;   // where the grass was trodden (grass_trample.gd)
uniform float trample_now = 0.0;
uniform float recover_s = 300.0;        // data/look/grass_trample.json
uniform float trample_squash = 0.75;
varying vec3 blade_color;
varying float tip;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float reach = length(wp - CAMERA_POSITION_WORLD);
	float fade = 1.0 - smoothstep(fade_start, fade_end, reach);
	tip = 1.0 - UV.y;
	float gust = sin(TIME * 1.7 + wp.x * 0.35 + wp.z * 0.21) + 0.5 * sin(TIME * 3.1 + wp.x * 0.9 + wp.z * 0.6);
	VERTEX.x += gust * wind_strength * tip * tip;
	VERTEX.z += gust * wind_strength * 0.5 * tip * tip;
	// Trodden grass lies down by how recently it was trodden and rises again over five minutes.
	vec4 trod = textureLod(trample, MODEL_MATRIX[3].xz / 256.0, 0.0);
	float flat_down = 0.0;
	if (trod.b > 0.5) {
		float age = mod(trample_now - (trod.r * 255.0 + trod.g * 255.0 * 256.0) + 65536.0, 65536.0);
		// Stays down most of the time (so the trail reads) and stands back up smoothly, fully only after recover_s.
		float q = clamp(age / recover_s, 0.0, 1.0);
		flat_down = 1.0 - q * q;
	}
	VERTEX.y *= 1.0 - trample_squash * flat_down;
	VERTEX *= fade;
	blade_color = INSTANCE_CUSTOM.rgb * (1.0 - 0.12 * flat_down);
}

void fragment() {
	vec4 t = texture(blades, UV);
	if (t.a < 0.5) {
		discard;
	}
	// Light every card as if it faced up, front or back, so the ground's lighting carries over.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	// The painted card already shades root to tip; a little more here, and light that shows through the blades.
	ALBEDO = t.rgb * blade_color * mix(0.85, 1.05, tip);
	BACKLIGHT = ALBEDO * backlight;
	ROUGHNESS = 1.0;
}
"""

var radius_m: float = 30.0
var _near_end: float = 14.0               # band limits in metres (set_radius): near, middle, far, very far
var _mid_end: float = 26.0
var _far_end: float = 40.0                # the very far band starts here and runs to radius_m
var points_per_side: int = 4
var density: float = 1.0                 # share of each layer's per_point cards drawn (quality)
var tufts: int = 0                       # cards drawn now
var cells_built: int = 0
var cleared: Array = []                  # Vector3 spots of placed items: no grass or litter within clear_m (set_cleared)
var clear_m: float = 5.0
var clear_edge_m: float = 1.5
var trunks: Array = []                   # felled trunks lying on the grass: [ax, az, bx, bz, radius at a, radius at b] (set_trunks)
var trunk_margin_m: float = 0.3
var trunk_squash: float = 0.15           # a blade under or beside a trunk keeps this share of its height
var litter_m: float = 0.0                # forest litter drawn this far (0 off), set by the client per quality
var litter_density: float = 0.0          # share of each litter layer's per_point drawn
var litter_cap: int = 1 << 30            # hard limit on leaf cards and branches drawn at once (Technical direction: Low 3k, Medium 20k, High 40k, Ultra 60k)
var litter_cards: int = 0                # leaf cards and branches drawn now
var shore_m: float = 0.0                 # pebbles and reeds drawn this far (0 off)
var shore_density: float = 0.0
var shore_cards: int = 0                 # pebbles and reeds drawn now

var _terrain: Node3D
var _trample = null                      # GrassTrample: where the grass is trodden down
var _trample_msec: int = 0
var _trail_mult: float = 1.0
var _flora
var _tables
var _soil_color: Dictionary = {}         # soil id -> Color
var _meshes: Array = []                  # one card mesh per layer
var _materials: Array = []               # one material per layer
var _patch := FastNoiseLite.new()        # where tall grass grows
var _tint := FastNoiseLite.new()         # greener and yellower patches
var _cover := FastNoiseLite.new()        # breaks the grass up into patches on slopes
var _cells: Dictionary = {}              # Vector2i -> {"cell", "bufs" (layer -> card buffer), "retry", "busy", "built", "count"}
var merge_cells: int = 2                 # cells per side drawn by one MultiMesh per layer (set_merge): fewer draw calls (TD audit 2026-10-21)
var draw_nodes: int = 0                  # MultiMesh nodes drawn now
var _groups: Dictionary = {}             # Vector2i group -> {layer: MultiMeshInstance3D}
var _dirty: Dictionary = {}              # groups whose cards changed this frame (rebuilt once at the end of update)
var _pending: Array = []                 # cells waiting for rays, nearest first
var _scan_cell: Vector2i = Vector2i(1 << 30, 1 << 30)
var _scan_msec: int = 0
var _scan_active: bool = false           # a scan of the cells in reach is in progress (rows of cells a frame)
var _scan_row: int = 0
var _scan_cx: int = 0
var _scan_cz: int = 0
var _scan_span: int = 0
var _scan_at: Vector2 = Vector2.ZERO
var _scan_extra: float = 0.0
var _next_rescan: int = 0                 # msec: when the next scan is due without the player changing cell (when a waiting cell's retry falls due)
var _scan_next: int = 1 << 60
var _scan_now: int = 0
var _scan_keep: Dictionary = {}
const SCAN_ROWS_PER_FRAME := 4
var _center: Vector3 = Vector3.ZERO
var _edits: Array = []                   # [when msec, cells] ground changes waiting for their collision before cells are redrawn
var _last_position: Vector3 = Vector3.ZERO
var _last_msec: int = 0
var _velocity: Vector2 = Vector2.ZERO
var enabled: bool = true


func setup(terrain: Node3D, flora, tables) -> void:
	_terrain = terrain
	_flora = flora
	_tables = tables

	for entry in tables.get_entries("soils"):
		var c: Array = entry["color"]
		_soil_color[int(entry["id"])] = Color(float(c[0]), float(c[1]), float(c[2]))

	_patch.seed = 41
	_patch.frequency = 0.035
	_tint.seed = 77
	_tint.frequency = 0.08
	_cover.seed = 113
	_cover.frequency = 0.45
	var shader: Shader = Shader.new()
	shader.code = SHADER

	var branch_shader: Shader = Shader.new()
	branch_shader.code = BRANCH_SHADER

	var boulder_shader: Shader = Shader.new()
	boulder_shader.code = BOULDER_SHADER

	for layer in LAYERS:
		if layer.get("boulder", false):
			_meshes.append(_make_boulder())
			var rock: ShaderMaterial = ShaderMaterial.new()
			rock.shader = boulder_shader
			_materials.append(rock)
			continue

		if layer.get("branch", false) or layer.get("pebble", false):
			_meshes.append(_make_branch() if layer.get("branch", false) else _make_pebble())
			var wood: ShaderMaterial = ShaderMaterial.new()
			wood.shader = branch_shader
			_materials.append(wood)
			continue

		_meshes.append(_make_cards(float(layer["width"]), float(layer["height"]), int(layer["quads"])))
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("blades", _load_texture(str(layer["texture"])))
		material.set_shader_parameter("wind_strength", 0.12 * float(layer["wind"]))
		material.set_shader_parameter("backlight", float(layer["backlight"]))
		_materials.append(material)

	_trample = TrampleScript.new()

	for n in range(_materials.size()):
		if not _is_solid(n):
			_materials[n].set_shader_parameter("trample", _trample.texture)
			_materials[n].set_shader_parameter("recover_s", _trample.recover_s)
			_materials[n].set_shader_parameter("trample_squash", _trample.squash)

	set_radius(radius_m)


# How much grass grows at a spot on soil `soil`, by the same rules the tufts
# are placed by: x is the thickness (0 none to 1 thick), y the share of it that
# is tall meadow grass. The sound stage uses it for the swish against the boots.
func grass_at(x: float, z: float, soil: int) -> Vector2:
	if not GRASS_SOILS.has(soil):
		return Vector2.ZERO

	var thick: float = float(GRASS_SOILS[soil])
	return Vector2(thick, clampf((_patch.get_noise_2d(x, z) - 0.05) * 3.0, 0.0, 1.0) * 0.9)


# Grass lies down under a foot at this position (the local player each step; other players and creatures
# the client can see call it too). It rises again over five minutes of real time (grass_trample.gd).
# Tracking skill (Dave 2026-10-21): a good tracker sees the grass stay down longer on their own client. Base recover_s times the multiplier.
func set_trail_multiplier(mult: float) -> void:
	var m: float = clampf(mult, 1.0, 6.0)

	if is_equal_approx(m, _trail_mult):
		return

	_trail_mult = m

	for n in range(_materials.size()):
		if not _is_solid(n):
			_materials[n].set_shader_parameter("recover_s", _trample.recover_s * m)


func trail_reach_m() -> float:
	return _trample.trail_reach_m


func trail_budget() -> int:
	return _trample.trail_budget


func stamp(position: Vector3) -> void:
	if enabled and _trample != null:
		_trample.stamp(position)


# The wind sways the grass with the same gusts the sound stage plays
# (strength about 0 calm to 1.6 for a strong gust high up).
func set_wind(strength: float) -> void:
	for n in range(GRASS_LAYERS):
		_materials[n].set_shader_parameter("wind_strength", 0.12 * float(LAYERS[n]["wind"]) * clampf(0.6 + 0.5 * strength, 0.6, 1.4))


# The painted texture, imported by the editor or else straight from the file.
static func _load_texture(name: String) -> Texture2D:
	var path: String = "res://assets/grass/%s.png" % name

	if ResourceLoader.exists(path):
		var imported: Texture2D = load(path) as Texture2D

		if imported != null:
			return imported

	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))

	if image == null:
		image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.4, 0.6, 0.3, 1.0))

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


func set_radius(meters: float) -> void:
	radius_m = meters
	enabled = meters > 0.0
	_near_end = clampf(meters * 0.3, NEAR_END_MIN, NEAR_END_MAX)

	if meters > 50.0:
		_mid_end = meters * 0.5
		_far_end = meters * 0.8
	else:
		_mid_end = meters * 0.65
		_far_end = meters

	for n in range(GRASS_LAYERS):
		var reach: float = meters * float(LAYERS[n]["reach"])
		# The cards shrink to nothing over the last 12 m (no pop at the edge).
		_materials[n].set_shader_parameter("fade_start", maxf(reach - 12.0, 1.0))
		_materials[n].set_shader_parameter("fade_end", maxf(reach, 2.0))

	if not enabled:
		_clear_all()


# Forest litter range and amount per quality (0 meters or 0 density: none). A change rebuilds the cells.
func set_trample_rate(msec: int) -> void:
	if _trample != null:
		_trample.upload_msec = msec


func set_litter(meters: float, amount: float, cap: int = 1 << 30) -> void:
	var changed: bool = not is_equal_approx(meters, litter_m) or not is_equal_approx(amount, litter_density) or cap != litter_cap
	litter_cap = cap
	litter_m = meters
	litter_density = amount

	for n in range(GRASS_LAYERS, LITTER_END):
		_materials[n].set_shader_parameter("fade_start", maxf(meters - 5.0, 1.0))
		_materials[n].set_shader_parameter("fade_end", maxf(meters, 2.0))

	if changed and enabled:
		_clear_all()


# Crossed upright cards (2 or 3 of them, turned evenly), base at y = 0.
# UV y is 1 at the base and 0 at the tip (the shader sways by the tip).
static func _make_cards(width: float, height: float, quads: int) -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var indices: PackedInt32Array = PackedInt32Array()

	if quads == 0:
		# Flat card lying on the ground (ground cover seen from above).
		var half: float = width * 0.5
		var y: float = 0.03
		var flat: Array = []
		flat.resize(Mesh.ARRAY_MAX)
		flat[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-half, y, half), Vector3(half, y, half), Vector3(half, y, -half), Vector3(-half, y, -half)])
		flat[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		flat[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
		var flat_mesh: ArrayMesh = ArrayMesh.new()
		flat_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, flat)
		return flat_mesh

	for n in range(quads):
		var angle: float = PI * float(n) / float(quads)
		var d: Vector3 = Vector3(cos(angle), 0.0, sin(angle)) * width * 0.5
		var first: int = vertices.size()
		vertices.append_array([-d, d, d + Vector3.UP * height, -d + Vector3.UP * height])
		uvs.append_array([Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)])
		indices.append_array([first, first + 1, first + 2, first, first + 2, first + 3])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# Shore range and amount per quality (0 meters or 0 density: none). A change rebuilds the cells.
func set_shore(meters: float, amount: float) -> void:
	var changed: bool = not is_equal_approx(meters, shore_m) or not is_equal_approx(amount, shore_density)
	shore_m = meters
	shore_density = amount

	for n in range(LITTER_END, LAYERS.size()):
		_materials[n].set_shader_parameter("fade_start", maxf(meters - 5.0, 1.0))
		_materials[n].set_shader_parameter("fade_end", maxf(meters, 2.0))

	if changed and enabled:
		_clear_all()


# Layers drawn as small solid meshes (branches, pebbles, boulders) rather than grass cards.
static func _is_solid(layer: int) -> bool:
	return LAYERS[layer].get("branch", false) or LAYERS[layer].get("pebble", false) or LAYERS[layer].get("boulder", false)


# A boulder: an icosphere split once (80 faces), each vertex pushed in or out, the bottom flattened,
# flat shaded, 1 m across before the per-card scale.
static func _make_boulder() -> ArrayMesh:
	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var base: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces: Array = [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 31
	var points: Array = []

	for v in base:
		points.append((v as Vector3).normalized())

	var middles: Dictionary = {}
	var triangles: Array = []

	for f in range(0, faces.size(), 3):
		var ids: Array = [faces[f], faces[f + 1], faces[f + 2]]
		var mid: Array = []

		for e in range(3):
			var a: int = ids[e]
			var b: int = ids[(e + 1) % 3]
			var key: int = mini(a, b) * 100 + maxi(a, b)

			if not middles.has(key):
				middles[key] = points.size()
				points.append(((points[a] as Vector3) + (points[b] as Vector3)).normalized())

			mid.append(middles[key])

		triangles.append_array([ids[0], mid[0], mid[2], ids[1], mid[1], mid[0], ids[2], mid[2], mid[1], mid[0], mid[1], mid[2]])

	var shaped: Array = []

	for p in points:
		var d: Vector3 = p as Vector3
		var r: float = rng.randf_range(0.42, 0.56)
		var q: Vector3 = d * r
		# Wider than tall, flat underneath so it sits in the ground.
		q.y = maxf(q.y * 0.7, -0.12)
		shaped.append(q)

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()

	for f in range(0, triangles.size(), 3):
		var a: Vector3 = shaped[triangles[f]]
		var b: Vector3 = shaped[triangles[f + 1]]
		var c: Vector3 = shaped[triangles[f + 2]]
		var n: Vector3 = (b - a).cross(c - a).normalized()
		var first: int = vertices.size()
		vertices.append_array([a + Vector3(0.0, 0.12, 0.0), b + Vector3(0.0, 0.12, 0.0), c + Vector3(0.0, 0.12, 0.0)])
		normals.append_array([n, n, n])
		indices.append_array([first, first + 2, first + 1])   # Godot draws clockwise faces as the front

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# A pebble: a rounded lump (a twelve-point solid, jittered per vertex, flattened), 1 m across before the
# per-card scale.
static func _make_pebble() -> ArrayMesh:
	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var base: Array = [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var faces: Array = [0, 11, 5, 0, 5, 1, 0, 1, 7, 0, 7, 10, 0, 10, 11, 1, 5, 9, 5, 11, 4, 11, 10, 2, 10, 7, 6, 7, 1, 8, 3, 9, 4, 3, 4, 2, 3, 2, 6, 3, 6, 8, 3, 8, 9, 4, 9, 5, 2, 4, 11, 6, 2, 10, 8, 6, 7, 9, 8, 1]
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var flat: PackedVector3Array = PackedVector3Array()

	for v in base:
		var d: Vector3 = (v as Vector3).normalized() * rng.randf_range(0.42, 0.55)
		flat.append(Vector3(d.x, d.y * 0.55, d.z))

	for f in range(0, faces.size(), 3):
		var a: Vector3 = flat[faces[f]]
		var b: Vector3 = flat[faces[f + 1]]
		var c: Vector3 = flat[faces[f + 2]]
		var n: Vector3 = (b - a).cross(c - a).normalized()
		var first: int = vertices.size()
		vertices.append_array([a + Vector3(0.0, 0.2, 0.0), b + Vector3(0.0, 0.2, 0.0), c + Vector3(0.0, 0.2, 0.0)])
		normals.append_array([n, n, n])
		indices.append_array([first, first + 2, first + 1])   # Godot draws clockwise faces as the front

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# A dead branch lying along +x from 0 to 1 (three-sided, tapered) with a side twig at 0.55.
static func _make_branch() -> ArrayMesh:
	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var indices: PackedInt32Array = PackedInt32Array()
	var limbs: Array = [
		[Vector3(0.0, 0.03, 0.0), Vector3(1.0, 0.03, 0.0), 0.035, 0.012],
		[Vector3(0.55, 0.03, 0.0), Vector3(0.9, 0.08, 0.26), 0.02, 0.006],
	]

	for limb in limbs:
		var from: Vector3 = limb[0]
		var to: Vector3 = limb[1]
		var axis: Vector3 = (to - from).normalized()
		var side: Vector3 = axis.cross(Vector3.UP).normalized()
		var up: Vector3 = side.cross(axis).normalized()
		var first: int = vertices.size()

		for end in range(2):
			var centre: Vector3 = from if end == 0 else to
			var radius: float = float(limb[2]) if end == 0 else float(limb[3])

			for k in range(3):
				var a: float = TAU * float(k) / 3.0
				var out: Vector3 = side * cos(a) + up * sin(a)
				vertices.append(centre + out * radius)
				normals.append(out)

		for k in range(3):
			var k2: int = (k + 1) % 3
			indices.append_array([first + k, first + k2, first + 3 + k2, first + k, first + 3 + k2, first + 3 + k])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _free_cell_nodes(entry: Dictionary) -> void:
	if not entry.get("bufs", {}).is_empty():
		_dirty[_group_of(entry["cell"])] = true

	tufts -= int(entry.get("count", 0))
	litter_cards -= int(entry.get("litter", 0))
	shore_cards -= int(entry.get("shore", 0))
	entry["bufs"] = {}
	entry["count"] = 0
	entry["litter"] = 0
	entry["shore"] = 0


func _group_of(cell: Vector2i) -> Vector2i:
	return Vector2i(int(floor(float(cell.x) / float(merge_cells))), int(floor(float(cell.y) / float(merge_cells))))


# Cells per MultiMesh side (2 normally, 4 at Low): one draw call per layer and group instead of per cell. A change redraws all.
func set_merge(cells: int) -> void:
	cells = clampi(cells, 1, 8)

	if cells != merge_cells:
		merge_cells = cells
		_clear_all()


# Rebuilds the MultiMesh of every group whose cells changed: the layer's card buffers of its cells, end to end.
# Called at the end of update(), so a rebuilt cell still swaps its cards within the frame.
func _flush_groups() -> void:
	if _dirty.is_empty():
		return

	var span: float = float(merge_cells) * CELL_M

	for g in _dirty.keys():
		var group: Dictionary = _groups.get(g, {})

		for layer in range(LAYERS.size()):
			var merged: PackedFloat32Array = PackedFloat32Array()

			for dz in range(merge_cells):
				for dx in range(merge_cells):
					var entry = _cells.get(Vector2i(g.x * merge_cells + dx, g.y * merge_cells + dz))

					if entry != null and entry["bufs"].has(layer):
						merged.append_array(entry["bufs"][layer])

			var count: int = merged.size() / 16
			var node = group.get(layer)

			if count == 0:
				if node != null:
					node.queue_free()
					group.erase(layer)
					draw_nodes -= 1

				continue

			if node == null:
				node = _make_group_node(layer, span)
				group[layer] = node
				draw_nodes += 1

			node.custom_aabb = AABB(Vector3(float(g.x) * span - 1.0, _center.y - 150.0, float(g.y) * span), Vector3(span, 300.0, span))
			var multi: MultiMesh = node.multimesh

			if multi.instance_count != count:
				multi.instance_count = count

			multi.buffer = merged

		if group.is_empty():
			_groups.erase(g)
		else:
			_groups[g] = group

	_dirty.clear()


func _make_group_node(layer: int, span: float) -> MultiMeshInstance3D:
	var multi: MultiMesh = MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_custom_data = true
	multi.mesh = _meshes[layer]
	var node: MultiMeshInstance3D = MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = _materials[layer]
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if layer >= GRASS_LAYERS:
		# Measured from the group's middle: the cards fade out in their shader at the litter or shore range, this only culls.
		node.visibility_range_end = (litter_m if layer < LITTER_END else shore_m) + span
		node.visibility_range_end_margin = 2.0

	add_child(node)
	return node


func _clear_all() -> void:
	for key in _cells:
		_free_cell_nodes(_cells[key])

	_flush_groups()

	for g in _groups.keys():
		for node in _groups[g].values():
			node.queue_free()

	_groups.clear()
	draw_nodes = 0
	_dirty.clear()
	_cells.clear()
	_pending.clear()
	_scan_active = false
	tufts = 0
	litter_cards = 0
	shore_cards = 0


# Call from the client's physics step with the player's position.
# The ground changed (a dig): the grass, litter and rocks standing there are redrawn from the new ground a
# moment later, once its collision has caught up (owner, 2026-10-21: pebbles and grass should vanish when
# anyone digs the voxel under them). Twice, the second time to catch a slow collision.
# The placed things of the world (a fire, a bench, a chest...): no grass or litter within radius of any, thinning over the last edge_m.
# The cells around a spot that was added or taken away are built again at once.
func set_cleared(spots: Array, radius: float, edge: float) -> void:
	var changed: Array = []

	for spot in spots:
		if not cleared.has(spot):
			changed.append(spot)

	for spot in cleared:
		if not spots.has(spot):
			changed.append(spot)

	cleared = spots
	clear_m = radius
	clear_edge_m = edge

	for spot in changed:
		var reach: float = radius + 1.0
		var cells: Array = []

		for cz in range(int(floor((spot.z - reach) / CELL_M)), int(floor((spot.z + reach) / CELL_M)) + 1):
			for cx in range(int(floor((spot.x - reach) / CELL_M)), int(floor((spot.x + reach) / CELL_M)) + 1):
				cells.append(Vector2i(cx, cz))

		_edits.push_front([Time.get_ticks_msec() + 50, cells])


# Is (x, z) inside a placed item's circle (with the soft edge decided by a fixed scatter, so the same spot always gives the same answer).
func _cleared_at(x: float, z: float) -> bool:
	for spot in cleared:
		var d: float = Vector2(x - spot.x, z - spot.z).length()

		if d >= clear_m:
			continue

		var keep: float = smoothstep(clear_m - clear_edge_m, clear_m, d)

		var scatter: float = fposmod(sin(floorf(x * 3.0) * 12.9898 + floorf(z * 3.0) * 78.233) * 43758.5453, 1.0)   # a fixed random number per third of a metre

		if keep <= scatter:
			return true

	return false


# Felled trunks (Dave 2026-10-21): the grass under a lying trunk and trunk_margin_m out on each side is pressed flat (kept low, below
# the trunk's surface) for as long as the trunk lies there. The strip follows the trunk's real line, not a circle.
func set_trunks(list: Array, margin: float, squash: float) -> void:
	var changed: Array = []

	for t in list:
		if not trunks.has(t):
			changed.append(t)

	for t in trunks:
		if not list.has(t):
			changed.append(t)

	trunks = list
	trunk_margin_m = margin
	trunk_squash = squash

	for t in changed:
		var reach: float = maxf(t[4], t[5]) + margin + 1.0
		var cells: Array = []

		for cz in range(int(floor((minf(t[1], t[3]) - reach) / CELL_M)), int(floor((maxf(t[1], t[3]) + reach) / CELL_M)) + 1):
			for cx in range(int(floor((minf(t[0], t[2]) - reach) / CELL_M)), int(floor((maxf(t[0], t[2]) + reach) / CELL_M)) + 1):
				cells.append(Vector2i(cx, cz))

		_edits.push_front([Time.get_ticks_msec() + 50, cells])


# Is (x, z) under or within the margin of a lying trunk?
func _flat_at(x: float, z: float) -> bool:
	for t in trunks:
		var a: Vector2 = Vector2(t[0], t[1])
		var ab: Vector2 = Vector2(t[2], t[3]) - a
		var along: float = clampf((Vector2(x, z) - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d: float = (Vector2(x, z) - (a + ab * along)).length()

		if d < lerpf(t[4], t[5], along) + trunk_margin_m:
			return true

	return false


func ground_changed(center: Vector3, radius: float) -> void:
	var reach: float = radius + 1.0
	var x0: int = int(floor((center.x - reach) / CELL_M))
	var x1: int = int(floor((center.x + reach) / CELL_M))
	var z0: int = int(floor((center.z - reach) / CELL_M))
	var z1: int = int(floor((center.z + reach) / CELL_M))
	var cells: Array = []

	for cz in range(z0, z1 + 1):
		for cx in range(x0, x1 + 1):
			cells.append(Vector2i(cx, cz))

	var now: int = Time.get_ticks_msec()
	_edits.append([now + 600, cells])
	_edits.append([now + 2500, cells])


func update(position: Vector3) -> void:
	if not enabled or _meshes.is_empty():
		return

	while not _edits.is_empty() and Time.get_ticks_msec() >= int(_edits[0][0]):
		var due: Array = _edits.pop_front()

		for cell in due[1]:
			var entry = _cells.get(cell)

			if entry != null and entry["built"] and not entry["busy"]:
				entry["busy"] = true
				_pending.push_front(cell)

	_center = position
	var now: int = Time.get_ticks_msec()
	_trample.flush()
	var clock: float = TrampleScript.now_s()

	for n in range(_materials.size()):
		if not _is_solid(n):
			_materials[n].set_shader_parameter("trample_now", clock)

	# Owner (2026-10-20, pauses while walking): the scan listed and sorted every cell in range
	# every 0.4 s. Now only when the player is in another cell, or every 1.5 s to retry cells.
	# Owner (2026-10-21, running): "the grass stops rendering while I am moving ... it pops into view as I step
	# on it". Three causes: cells were built only between scans, and at a run a new scan starts every cell
	# crossing so building was starved; the ray budget could not keep up with the cells that change band or
	# come into reach at a run; and cells whose ground collision was not loaded waited 1.5 s. Now: building
	# goes on during a scan, the budget grows while moving, the scan is centred a little ahead of the
	# movement, and retries are quicker.
	var moved: Vector3 = position - _last_position
	var dt: float = maxf(float(now - _last_msec) / 1000.0, 0.001)
	_last_position = position
	_last_msec = now
	var speed: float = clampf(Vector2(moved.x, moved.z).length() / dt, 0.0, 30.0)
	_velocity = _velocity.lerp(Vector2(moved.x, moved.z) / dt if dt < 0.5 else Vector2.ZERO, 0.2)
	var ahead: Vector3 = position + Vector3(_velocity.x, 0.0, _velocity.y) * LOOKAHEAD_S
	var here_cell: Vector2i = Vector2i(int(floor(ahead.x / CELL_M)), int(floor(ahead.z / CELL_M)))

	# Standing still costs nothing: a rescan only repeats (to retry cells whose ground was not ready) while
	# some cell is still unbuilt, otherwise every IDLE_RESCAN_MSEC (owner table 2026-10-21: the frame was CPU bound).
	if not _scan_active and (here_cell != _scan_cell or now >= _next_rescan):
		_scan_msec = now
		_scan_cell = here_cell
		_rescan_begin(ahead, now)

	# The scan runs a few rows a frame (the whole 160 m reach is 2000 cells; one pass took about 30 ms).
	if _scan_active:
		_rescan_step()

	var rays: int = RAYS_PER_FRAME * (2 if speed > 2.5 and _pending.size() > 20 else 1)
	var started: int = Time.get_ticks_usec()

	while rays > 0 and not _pending.is_empty():
		var cell: Vector2i = _pending.pop_front()

		if not _cells.has(cell) or not _cells[cell]["busy"]:
			continue

		rays -= _build(cell)

		if Time.get_ticks_usec() - started > BUILD_USEC:
			break

	_flush_groups()


# The band of a cell by its distance: 0 near (full samples), 1 middle, 2 far, 3 very far (reach beyond 50 m).
# Limits come from set_radius. A cell keeps its band until it is LOD_HYSTERESIS_M past the boundary (builds
# up to 282 had this backwards, so a cell within 3 m of a boundary flipped between two bands at every
# rescan and the grass popped there; owner: "popping in and out of existence right in front of me").
func _lod_of(cell: Vector2i, held: int) -> int:
	var centre: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_M
	var d: float = centre.distance_to(Vector2(_center.x, _center.z))

	for band in range(3):
		# Held in this band or nearer: stay until past the limit; held farther: come back only when inside it.
		var slack: float = LOD_HYSTERESIS_M if held == band else (-LOD_HYSTERESIS_M if held > band else (LOD_HYSTERESIS_M if held >= 0 else 0.0))

		if d < (_near_end if band == 0 else (_mid_end if band == 1 else _far_end)) + slack:
			return band

	return 3 if radius_m > 50.0 else 2


func _lod_points(lod: int) -> int:
	if radius_m > 50.0:
		return [points_per_side, 3, 2, 1][lod]

	return [points_per_side, maxi(2, int(round(points_per_side * 0.5))), 2, 2][lod]


func _rescan_begin(position: Vector3, now: int) -> void:
	_scan_cx = int(floor(position.x / CELL_M))
	_scan_cz = int(floor(position.z / CELL_M))
	_scan_at = Vector2(position.x, position.z)
	# The scan is centred ahead of the player; its reach grows by that offset so nothing behind is dropped early.
	_scan_extra = _scan_at.distance_to(Vector2(_center.x, _center.z))
	_scan_span = int(ceil((radius_m + CELL_M + _scan_extra) / CELL_M))
	_scan_row = -_scan_span
	_scan_now = now
	_scan_keep = {}
	_scan_active = true


# A few rows of the scan: every cell in reach is kept, new ones queued, built ones whose band changed queued
# again; when the last row is done the queue is ordered nearest first and cells out of reach are freed.
func _rescan_step() -> void:
	var span: int = _scan_span
	var limit: float = radius_m + CELL_M + _scan_extra

	for r in range(SCAN_ROWS_PER_FRAME):
		if _scan_row > span:
			break

		var dz: int = _scan_row
		_scan_row += 1

		for dx in range(-span, span + 1):
			var cell: Vector2i = Vector2i(_scan_cx + dx, _scan_cz + dz)
			var centre: Vector2 = (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_M

			if centre.distance_to(_scan_at) > limit:
				continue

			_scan_keep[cell] = true
			var entry = _cells.get(cell)

			if entry != null and not entry["built"] and not entry["busy"]:
				_scan_next = mini(_scan_next, int(entry["retry"]))

			if entry == null:
				_cells[cell] = {"cell": cell, "bufs": {}, "count": 0, "retry": 0, "busy": true, "built": false}
				_pending.append(cell)
			elif not entry["built"] and not entry["busy"] and _scan_now >= int(entry["retry"]):
				entry["busy"] = true
				_pending.append(cell)
			elif entry["built"] and not entry["busy"] and _lod_of(cell, int(entry.get("lod", 0))) != int(entry.get("lod", 0)):
				entry["busy"] = true
				entry["built"] = true
				_pending.append(cell)

	if _scan_row <= span:
		return

	_scan_active = false
	_next_rescan = _scan_now + (RESCAN_MSEC if not _pending.is_empty() else clampi(_scan_next - _scan_now, RESCAN_MSEC, IDLE_RESCAN_MSEC))
	_scan_next = 1 << 60

	if _pending.size() > 1:
		# Nearest first, in one pass: a bucket per cell ring (sorting 2000 cells with a lambda took about 30 ms).
		var near: Vector2 = Vector2(_center.x, _center.z) / CELL_M      # nearest the player first
		var buckets: Array = []
		buckets.resize(span + 2)

		for n in range(buckets.size()):
			buckets[n] = []

		for cell in _pending:
			var ring: int = clampi(int((Vector2(cell) + Vector2(0.5, 0.5)).distance_to(near)), 0, span + 1)    # clamped: a NaN centre gave int min
			buckets[ring].append(cell)

		_pending.clear()

		for bucket in buckets:
			_pending.append_array(bucket)

	for cell in _cells.keys():
		if not _scan_keep.has(cell):
			_free_cell_nodes(_cells[cell])
			_cells.erase(cell)

	_scan_keep = {}


# Rays for one cell; returns how many were cast.
func _build(cell: Vector2i) -> int:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var tool: VoxelTool = _terrain.get_voxel_tool()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(cell)
	var entry: Dictionary = _cells[cell]
	var lod: int = _lod_of(cell, int(entry.get("lod", 0)) if entry["built"] else -1)
	var pps: int = _lod_points(lod)
	var width_scale: float = float((LOD_SCALE if radius_m > 50.0 else LOD_SCALE_SHORT)[lod])
	var big: bool = radius_m > 50.0
	var band_share: float = float(BAND_SHARE[lod]) if big else 1.0
	var spacing: float = CELL_M / float(pps)
	# Cards are written straight into one MultiMesh buffer per layer: 12 floats of transform (rows of
	# the 3 x 4 matrix) and 4 of custom colour each (about half the cost of building Transform3D and
	# Color objects first).
	var buffers: Array = []
	var counts: Array = []
	# Cells are built once, as they come into grass range, so litter is made for all of them and the
	# engine culls the ones beyond litter_m (visibility_range_end below).
	var litter_here: bool = litter_m > 0.0 and litter_density > 0.0
	var shore_here: bool = shore_m > 0.0 and shore_density > 0.0

	for layer in range(LAYERS.size()):
		var cap: PackedFloat32Array = PackedFloat32Array()
		var share: float = density if layer < GRASS_LAYERS else (litter_density if layer < LITTER_END else shore_density)
		# Tall grass is drawn thicker near water (up to twice the cards), so its buffer holds twice.
		var room: float = 2.0 if layer == 2 else (1.0 if layer < GRASS_LAYERS or layer >= LITTER_END else (LITTER_DEEP_TWIGS if LAYERS[layer].get("branch", false) else LITTER_DEEP_LEAVES))
		cap.resize(pps * pps * (int(ceil(float(LAYERS[layer]["per_point"]) * share * room)) + 1) * 16)
		buffers.append(cap)
		counts.append(0)

	var rays: int = 0
	var missed: int = 0

	for j in range(pps):
		for i in range(pps):
			var x: float = float(cell.x) * CELL_M + (float(i) + rng.randf()) * spacing
			var z: float = float(cell.y) * CELL_M + (float(j) + rng.randf()) * spacing
			var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(Vector3(x, _center.y + 80.0, z), Vector3(x, _center.y - 120.0, z))
			var hit: Dictionary = space.intersect_ray(query)
			rays += 1

			if hit.is_empty():
				missed += 1
				continue

			var collider = hit["collider"]

			if collider.has_meta("species_ids") or hit["normal"].y < MIN_SLOPE_Y:
				continue

			var point: Vector3 = hit["position"]
			var water: float = _flora.water_level_at(x, z)

			if shore_here:
				_put_shore(buffers, counts, rng, point, spacing, water)
				if SCENERY_BOULDERS:
					_put_boulders(buffers, counts, rng, point, spacing, hit["normal"].y, water)

			if not is_nan(water) and point.y < water + 0.3:
				continue

			if not cleared.is_empty() and _cleared_at(x, z):
				continue

			# Owner (2026-10-21): under a big crown almost no grass except at the edge of its canopy footprint,
			# and a floor so covered in leaves and twigs that no ground shows. `under` is 0 at the drip line, 1 at the trunk.
			var under: float = _flora.cover.crown_depth(Vector3(x, point.y + 1.0, z))

			if litter_here and under > 0.0 and litter_cards + int(counts[3]) + int(counts[4]) < litter_cap:
				_put_litter(buffers, counts, rng, point, spacing, under)

			var soil: int = _grass_soil(tool, point - hit["normal"] * 0.4)

			if soil < 0:
				continue

			var short_soil: float = minf(1.0 / float(GRASS_SOILS[soil]), SHORT_SOIL_LIFT)       # the short grass's soil share is lifted to near 1 (see the short layer below)
			var thick: float = float(GRASS_SOILS[soil]) * _cover_at(x, z, hit["normal"].y)
			# Owner (2026-10-20): in a closed forest the litter and shade under the trees stop the grass; in
			# open fields and sparse trees it grows right up to and under them. Closure thins it gradually.
			thick *= 1.0 - 0.95 * smoothstep(0.4, 0.9, _closure(x, point.y, z))
			thick *= 1.0 - 0.96 * smoothstep(CROWN_GRASS_FROM, CROWN_GRASS_TO, under)

			if thick < 0.04:
				continue

			var base: Color = _soil_color.get(soil, Color(0.3, 0.4, 0.2))
			var green: Color = Color(0.46, 0.58, 0.28).lerp(base, 0.2)
			# Patches: yellower where the tint noise is high; tall grass where the patch noise is.
			var warm: float = clampf(_tint.get_noise_2d(x, z) * 1.4, 0.0, 1.0)
			green = green.lerp(Color(0.68, 0.64, 0.30), warm * 0.55)
			var meadow: float = _patch.get_noise_2d(x, z)

			# Wet ground (owner, 2026-10-20: the tall grass "needs to be thicker around water"): how close the
			# water is, for the tall grass below.
			var wet: float = _wetness(point, water)

			for layer in range(GRASS_LAYERS):
				if layer == 0 and lod > 0:
					continue

				# Owner (2026-10-21): all the grass has the same draw distance, so the short grass is drawn in
				# the far bands too (it used to stop at 85 percent of the reach and drop out of the far bands).
				var want: float = float(LAYERS[layer]["per_point"]) * density * band_share * (1.0 + wet if layer == 2 else 1.0)
				var count: int = int(want) + (1 if rng.randf() < want - floorf(want) else 0)
				var chance: float = thick

				if layer == 2:
					# Tall grass only in meadow patches, thinning toward their edges; by water it grows everywhere.
					chance = lerpf(thick * clampf((meadow - 0.05) * 3.0, 0.0, 1.0) * 0.9, thick, wet)
				elif layer == 1:
					# Owner (2026-10-21): the short grass should cover about 98 percent of the ground. Poor soils
					# no longer halve it (soil 4 was 0.5) and meadow patches thin it only a little.
					chance = thick * short_soil * (1.0 - clampf((meadow - 0.2) * 1.5, 0.0, 0.25))

				for k in range(count):
					if rng.randf() > chance:
						continue

					var ox: float = point.x + rng.randf_range(-0.5, 0.5) * spacing * 0.95
					var oz: float = point.z + rng.randf_range(-0.5, 0.5) * spacing * 0.95
					var size: float = rng.randf_range(0.75, 1.15)
					var yaw: float = rng.randf() * TAU
					var sy: float = size * rng.randf_range(0.8, 1.15)

					if not trunks.is_empty() and _flat_at(ox, oz):
						sy *= trunk_squash
					var cy: float = cos(yaw) * size * width_scale
					var sny: float = sin(yaw) * size * width_scale
					var shade: float = rng.randf_range(0.82, 1.15)
					var buffer: PackedFloat32Array = buffers[layer]
					var o: int = int(counts[layer]) * 16
					counts[layer] = int(counts[layer]) + 1
					buffer[o] = cy
					buffer[o + 1] = 0.0
					buffer[o + 2] = sny
					buffer[o + 3] = ox
					buffer[o + 4] = 0.0
					buffer[o + 5] = sy
					buffer[o + 6] = 0.0
					buffer[o + 7] = point.y - 0.03
					buffer[o + 8] = -sny
					buffer[o + 9] = 0.0
					buffer[o + 10] = cy
					buffer[o + 11] = oz
					# A slight hue shift per card keeps a field from looking stamped.
					buffer[o + 12] = green.r * shade * rng.randf_range(0.93, 1.07)
					buffer[o + 13] = green.g * shade
					buffer[o + 14] = green.b * shade * rng.randf_range(0.9, 1.1)
					buffer[o + 15] = 1.0
					buffers[layer] = buffer

	entry["busy"] = false

	if missed * 2 > rays:
		# The ground collision is not ready here yet; try again later.
		# Back off: a cell with no ground collision (beyond its range) is tried again after 0.5, 1, 2, 4, 8 s.
		var fails: int = int(entry.get("fails", 0))
		entry["fails"] = mini(fails + 1, 4)
		entry["retry"] = Time.get_ticks_msec() + (RETRY_MSEC << fails)
		return rays

	entry["built"] = true
	entry["lod"] = lod
	cells_built += 1
	_free_cell_nodes(entry)      # a rebuilt cell swaps its cards in the same frame

	for layer in range(LAYERS.size()):
		var count: int = int(counts[layer])

		if count == 0:
			continue

		var buffer: PackedFloat32Array = buffers[layer]
		buffer.resize(count * 16)
		entry["bufs"][layer] = buffer
		_dirty[_group_of(cell)] = true

		if layer >= LITTER_END:
			entry["shore"] = int(entry.get("shore", 0)) + count
			shore_cards += count
		elif layer >= GRASS_LAYERS:
			entry["litter"] = int(entry.get("litter", 0)) + count
			litter_cards += count
		else:
			entry["count"] += count
			tufts += count

	return rays


# How wet the ground is at a point, 0 dry to 1 at the water's edge: water within 3.5 m and no more than 2 m
# below the point (banks of rivers, brooks, lakes and ponds, wet low ground).
func _wetness(point: Vector3, water: float) -> float:
	var best: float = 0.0

	for d in [Vector2(3.5, 0.0), Vector2(-3.5, 0.0), Vector2(0.0, 3.5), Vector2(0.0, -3.5)]:
		var near: float = _flora.water_level_at(point.x + d.x, point.z + d.y)

		if not is_nan(near):
			best = maxf(best, 1.0 - clampf((point.y - near) / 2.0, 0.0, 1.0))

	if not is_nan(water):
		best = 1.0

	return best


# One ground sample at the water's edge (water is the surface level here or NAN): pebbles on the dry bank
# and on the shallow bed under clear water, reeds along still water only (ponds and lakes, not the current).
func _put_shore(buffers: Array, counts: Array, rng: RandomNumberGenerator, point: Vector3, spacing: float, water: float) -> void:
	var depth: float = -1.0           # metres of water over the ground here; negative: dry
	var edge: float = -1.0            # how far above the nearest water the dry ground lies; negative: no water near

	if not is_nan(water):
		depth = water - point.y
	else:
		edge = 99.0

		for d in [Vector2(2.5, 0.0), Vector2(-2.5, 0.0), Vector2(0.0, 2.5), Vector2(0.0, -2.5)]:
			var near: float = _flora.water_level_at(point.x + d.x, point.z + d.y)

			if not is_nan(near):
				edge = minf(edge, point.y - near)

		if edge > 1.0:
			return

	var still: bool = _flora.water_speed_at(point.x, point.z) < 0.35
	var bank: float = 1.0 - clampf(edge / 1.0, 0.0, 1.0) if depth < 0.0 else 1.0 - clampf(depth / 0.9, 0.0, 1.0)

	if bank <= 0.0:
		return

	for layer in range(LITTER_END, LAYERS.size()):
		if LAYERS[layer].get("boulder", false) or (LAYERS[layer].get("pebble", false) and not SCENERY_PEBBLES):
			continue

		var reed: bool = LAYERS[layer].get("reed", false)

		if reed and not (still and depth < 0.4 and (depth >= 0.0 or edge < 0.6)):
			continue

		var want: float = float(LAYERS[layer]["per_point"]) * shore_density * (1.0 if reed else bank)
		var count: int = int(want) + (1 if rng.randf() < want - floorf(want) else 0)

		for k in range(count):
			var ox: float = point.x + rng.randf_range(-0.5, 0.5) * spacing * 0.95
			var oz: float = point.z + rng.randf_range(-0.5, 0.5) * spacing * 0.95
			var yaw: float = rng.randf() * TAU
			var c: float = cos(yaw)
			var s: float = sin(yaw)
			var size: float = rng.randf_range(0.5, 1.3) if reed else rng.randf_range(0.07, 0.22)
			var tall: float = size * rng.randf_range(0.8, 1.2) if reed else size * rng.randf_range(0.5, 1.0)
			var shade: float = rng.randf_range(0.8, 1.1)
			var buffer: PackedFloat32Array = buffers[layer]
			var o: int = int(counts[layer]) * 16
			counts[layer] = int(counts[layer]) + 1
			buffer[o] = c * size
			buffer[o + 1] = 0.0
			buffer[o + 2] = s * size
			buffer[o + 3] = ox
			buffer[o + 4] = 0.0
			buffer[o + 5] = tall
			buffer[o + 6] = 0.0
			buffer[o + 7] = point.y - 0.04
			buffer[o + 8] = -s * size
			buffer[o + 9] = 0.0
			buffer[o + 10] = c * size
			buffer[o + 11] = oz

			if reed:
				buffer[o + 12] = 0.62 * shade
				buffer[o + 13] = 0.68 * shade
				buffer[o + 14] = 0.36 * shade
			else:
				# Rounded river stones: pale grey, warm grey and brown, darker where wet.
				var wet: float = 0.8 if depth >= 0.0 else 1.0
				var warm: float = rng.randf()
				buffer[o + 12] = (0.42 + 0.14 * warm) * shade * wet
				buffer[o + 13] = (0.4 + 0.1 * warm) * shade * wet
				buffer[o + 14] = (0.37 + 0.04 * warm) * shade * wet

			buffer[o + 15] = 1.0
			buffers[layer] = buffer


# One ground sample on a slope or by water: now and then a boulder, in clusters (the patch noise), more
# on the steeper ground and at the foot of a slope, half buried, mossy where it is damp or shaded.
func _put_boulders(buffers: Array, counts: Array, rng: RandomNumberGenerator, point: Vector3, spacing: float, normal_y: float, water: float) -> void:
	var slope: float = 1.0 - clampf(normal_y, 0.0, 1.0)
	var near_water: bool = not is_nan(water)
	var by_slope: float = smoothstep(0.1, 0.3, slope)
	var chance: float = maxf(by_slope, 0.25 if near_water else 0.0)

	if chance <= 0.0:
		return

	# Clusters: boulders gather where the patch noise is high and are absent elsewhere.
	var cluster: float = smoothstep(0.1, 0.5, _patch.get_noise_2d(point.x * 1.7 + 311.0, point.z * 1.7))

	if cluster <= 0.0:
		return

	var layer: int = BOULDER_LAYER
	var want: float = float(LAYERS[layer]["per_point"]) * shore_density * chance * cluster * 4.0
	var count: int = int(want) + (1 if rng.randf() < want - floorf(want) else 0)

	for k in range(count):
		var ox: float = point.x + rng.randf_range(-0.5, 0.5) * spacing * 0.95
		var oz: float = point.z + rng.randf_range(-0.5, 0.5) * spacing * 0.95
		var yaw: float = rng.randf() * TAU
		var c: float = cos(yaw)
		var s: float = sin(yaw)
		var size: float = rng.randf_range(0.35, 1.2) * rng.randf_range(0.6, 1.0)
		size = maxf(size, 0.3)
		var tall: float = size * rng.randf_range(0.65, 1.1)
		var shade: float = rng.randf_range(0.85, 1.1)
		var mossy: float = clampf(0.35 + 0.5 * (cluster - 0.3) + (0.3 if near_water else 0.0) + rng.randf_range(-0.2, 0.2), 0.0, 1.0)
		var buffer: PackedFloat32Array = buffers[layer]
		var o: int = int(counts[layer]) * 16
		counts[layer] = int(counts[layer]) + 1
		buffer[o] = c * size
		buffer[o + 1] = 0.0
		buffer[o + 2] = s * size
		buffer[o + 3] = ox
		buffer[o + 4] = 0.0
		buffer[o + 5] = tall
		buffer[o + 6] = 0.0
		buffer[o + 7] = point.y - 0.2 * tall
		buffer[o + 8] = -s * size
		buffer[o + 9] = 0.0
		buffer[o + 10] = c * size
		buffer[o + 11] = oz
		# Granite: pale grey, a little warmer or bluer per rock.
		var warm: float = rng.randf()
		buffer[o + 12] = (0.33 + 0.06 * warm) * shade
		buffer[o + 13] = (0.32 + 0.04 * warm) * shade
		buffer[o + 14] = (0.30 + 0.02 * warm) * shade
		buffer[o + 15] = mossy
		buffers[layer] = buffer


# One ground sample under a crown: leaf cards and, now and then, a dead branch (layers GRASS_LAYERS on).
func _put_litter(buffers: Array, counts: Array, rng: RandomNumberGenerator, point: Vector3, spacing: float, under: float) -> void:
	var deep: float = smoothstep(CROWN_LITTER_FROM, CROWN_LITTER_TO, under)
	var rim: float = smoothstep(0.0, 0.12, under)   # litter thins out to nothing at the drip line, no sharp circle

	for layer in range(GRASS_LAYERS, LITTER_END):
		# Deeper under the crown the floor gets up to LITTER_DEEP_LEAVES / LITTER_DEEP_TWIGS times the litter.
		var want: float = rim * float(LAYERS[layer]["per_point"]) * litter_density * (1.0 + deep * ((LITTER_DEEP_TWIGS if LAYERS[layer].get("branch", false) else LITTER_DEEP_LEAVES) - 1.0))
		var count: int = int(want) + (1 if rng.randf() < want - floorf(want) else 0)
		var branch: bool = LAYERS[layer].get("branch", false)

		for k in range(count):
			var ox: float = point.x + rng.randf_range(-0.5, 0.5) * spacing * 0.95
			var oz: float = point.z + rng.randf_range(-0.5, 0.5) * spacing * 0.95
			var yaw: float = rng.randf() * TAU
			var c: float = cos(yaw)
			var s: float = sin(yaw)
			var along: float = rng.randf_range(0.45, 1.3) if branch else rng.randf_range(0.8, 1.3)
			var across: float = rng.randf_range(0.8, 1.4) if branch else along
			var shade: float = rng.randf_range(0.75, 1.1)
			var buffer: PackedFloat32Array = buffers[layer]
			var o: int = int(counts[layer]) * 16
			counts[layer] = int(counts[layer]) + 1
			buffer[o] = c * along
			buffer[o + 1] = 0.0
			buffer[o + 2] = s * across
			buffer[o + 3] = ox
			buffer[o + 4] = 0.0
			buffer[o + 5] = 1.0
			buffer[o + 6] = 0.0
			# Leaf cards lie a hair apart so overlapping ones do not flicker.
			buffer[o + 7] = point.y - 0.03 + (0.0 if branch else rng.randf() * 0.025)
			buffer[o + 8] = -s * along
			buffer[o + 9] = 0.0
			buffer[o + 10] = c * across
			buffer[o + 11] = oz

			if branch:
				# Weathered grey-brown wood, dark and thin, unlike the pale sticks of loose world items.
				buffer[o + 12] = 0.2 * shade
				buffer[o + 13] = 0.15 * shade
				buffer[o + 14] = 0.11 * shade
			else:
				buffer[o + 12] = shade
				buffer[o + 13] = shade * rng.randf_range(0.9, 1.05)
				buffer[o + 14] = shade * rng.randf_range(0.85, 1.0)

			buffer[o + 15] = 1.0
			buffers[layer] = buffer


# How closed the canopy is around a spot, 0 (open field) to 1 (every sample under a crown): seven points
# within 4 m, tested against the shared cover index. Scattered trees give about 0.15 to 0.3, a forest 1.
func _closure(x: float, y: float, z: float) -> float:
	var covered: int = 0

	for d in CLOSURE_OFFSETS:
		if _flora.cover.covers(Vector3(x + d.x, y + 1.0, z + d.y)):
			covered += 1

	return float(covered) / float(CLOSURE_OFFSETS.size())


# Share of the grass that holds at a spot of the given slope: full on level ground, thinning
# toward steep faces in patches, nothing on rock. The ground shader fades the soil colour by
# the same rule (ground_material.gd), so grass and green ground agree; a ledge has a level
# surface of its own, so it keeps its grass on a steep face.
func _cover_at(x: float, z: float, normal_y: float) -> float:
	var slope: float = 1.0 - clampf(normal_y, 0.0, 1.0)
	var noise: float = _cover.get_noise_2d(x, z) * 0.5 + 0.5
	return 1.0 - smoothstep(COVER_FROM, COVER_TO, slope + (noise - 0.5) * 0.24)


# The soil id at a point if it carries grass, else -1 (rock, ore, sand, snow...).
func _grass_soil(tool: VoxelTool, point: Vector3) -> int:
	var cell: Vector3i = Vector3i(point.floor())
	tool.channel = Layout.CHANNEL_RESOURCE

	if tool.get_voxel(cell) > 0:
		return -1

	tool.channel = Layout.CHANNEL_MATERIAL
	var material: int = tool.get_voxel(cell)

	if GRASS_SOILS.has(material):
		return material

	return -1
