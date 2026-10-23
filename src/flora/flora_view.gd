extends Node3D

# Draws trees and plants (plan step 15) from chunk item lists, wherever they
# come from: the flora placer directly (terrain preview) or the server
# (terrain client).
#
# Each chunk is drawn at a level set by its distance from the player: trees
# out to view_m.tree, shrubs to view_m.shrub, small plants to view_m.plant
# (tile_rules.json "runtime_flora"). One MultiMesh per species and part of
# the chunk (256 m for trees, 128 m for shrubs and plants), so whole groups
# are culled cheaply. Trees and shrubs within collision_m get trunk
# colliders so the player cannot walk through them.
#
# Each chunk also carries its rivers and lakes (WaterGrid levels), drawn as
# flat water out to tree view distance.
#
# Meshes are simple stand-ins built from the species table (trunk, crown
# shape and color) until real models exist.

const WaterGridScript := preload("res://src/worldgen/runtime/water_grid.gd")
const TreeBuilder := preload("res://src/flora/tree_builder.gd")
const TreeImpostor := preload("res://src/flora/tree_impostor.gd")
const WaterFallsScript := preload("res://src/worldgen/runtime/water_falls.gd")
const WaterMaterial := preload("res://src/client/water_material.gd")
const CoverScript := preload("res://src/shared/cover.gd")
const IceScript := preload("res://src/shared/ice.gd")
const KIND_TREE := 0
const KIND_SHRUB := 1
const KIND_PLANT := 2
const AUTUMN: Array[Color] = [
	Color(0.80, 0.66, 0.24), Color(0.76, 0.54, 0.20), Color(0.78, 0.43, 0.18), Color(0.70, 0.31, 0.16),
	Color(0.60, 0.22, 0.16), Color(0.46, 0.17, 0.14), Color(0.66, 0.48, 0.22),
	# The bright ones: lemon yellow, burning orange, flame and scarlet red.
	Color(0.98, 0.82, 0.10), Color(1.00, 0.72, 0.08), Color(1.00, 0.46, 0.04), Color(0.96, 0.30, 0.04),
	Color(0.92, 0.12, 0.06), Color(0.82, 0.07, 0.09), Color(0.98, 0.78, 0.12), Color(1.00, 0.40, 0.06)
]

const FOLIAGE_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform sampler2D leaves : source_color, filter_linear_mipmap, repeat_disable;
uniform float sway = 0.012;
uniform float flutter = 0.06;
// Leaves are not opaque: about 40% of the sunlight comes through, so a crown
// glows when the sun is behind it (owner, 2026-10-18: autumn leaves shine).
uniform float backlight = 0.4;
// Leaves that glow (the witness tree): EMISSION = glow times the instance
// custom alpha (how strongly this tree glows; young ones weakly). Black for
// every other species. Faint by day, plain at night.
uniform vec3 glow : source_color = vec3(0.0);
varying vec3 tint;
varying float glow_amount;
varying vec3 view_normal;
varying float crown_up;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = sin(TIME * 0.9 + wp.x * 0.05 + wp.z * 0.04) + 0.4 * sin(TIME * 1.9 + wp.x * 0.11 + wp.z * 0.09);
	float bend = max(VERTEX.y, 0.0) * sway;
	VERTEX.x += gust * bend;
	VERTEX.z += gust * bend * 0.6;
	crown_up = normalize(MODEL_NORMAL_MATRIX * NORMAL).y;
	VERTEX += vec3(sin(TIME * 3.7 + wp.x * 1.7 + VERTEX.y), 0.0, cos(TIME * 3.1 + wp.z * 1.3 + VERTEX.y)) * flutter * COLOR.a;
	tint = INSTANCE_CUSTOM.rgb;
	glow_amount = INSTANCE_CUSTOM.a;
	view_normal = normalize((MODELVIEW_NORMAL_MATRIX * NORMAL));
}

void fragment() {
	vec4 t = texture(leaves, UV);
	if (t.a < 0.5) {
		discard;
	}
	// Light every card the same from both sides, using the crown's soft normals.
	NORMAL = view_normal;
	// Crown shading: undersides sit in the crown's own shadow, and each patch of leaves
	// gets its own tone so a crown reads as clusters, not one smooth lump.
	float under = mix(0.6, 1.0, smoothstep(-0.7, 0.5, crown_up));
	vec2 cell = floor(UV * 7.0);
	float speck = 0.88 + 0.24 * fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = t.rgb * COLOR.rgb * tint * under * speck;
	BACKLIGHT = ALBEDO * backlight;
	ROUGHNESS = 1.0;
	EMISSION = glow * glow_amount * (0.6 + 0.4 * t.r);
}
"""

const BARK_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D bark : source_color, filter_linear_mipmap, repeat_enable;
uniform float sway = 0.004;
varying float base_h;
varying float north_face;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	base_h = VERTEX.y;
	north_face = -normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz).z;   // north is -z
	float gust = sin(TIME * 0.9 + wp.x * 0.05 + wp.z * 0.04) + 0.4 * sin(TIME * 1.9 + wp.x * 0.11 + wp.z * 0.09);
	float bend = max(VERTEX.y, 0.0) * sway;
	VERTEX.x += gust * bend;
	VERTEX.z += gust * bend * 0.6;
}

void fragment() {
	vec4 t = texture(bark, UV);
	vec3 c = t.rgb * COLOR.rgb * 1.8;
	c *= mix(0.72, 1.12, t.a);                                       // furrows darker, ridges lighter
	float moss = (1.0 - smoothstep(0.1, 1.1, base_h)) * (0.35 + 0.65 * (1.0 - t.a));   // damp moss at the foot
	c = mix(c, c * vec3(0.55, 0.75, 0.32), moss * 0.6);
	// Moss on the north side of the trunk (ART_DIRECTION.md section 32), thinning up the trunk.
	float north_moss = smoothstep(0.3, 0.9, north_face) * (1.0 - smoothstep(1.5, 5.0, base_h)) * (0.4 + 0.6 * (1.0 - t.a));
	c = mix(c, c * vec3(0.5, 0.72, 0.3), north_moss * 0.55);
	ALBEDO = c;
	ROUGHNESS = 1.0;
}
"""

# Everember: dark ridged bark with glowing veins in its furrows. The glow
# (EMISSION) is strongest where the bark texture is darkest (the furrows),
# broken up by a second, coarser sample so not every furrow burns, and scaled
# by the vertex alpha (1 low on the trunk and roots, fading up the tree, 0 on
# small limbs). It pulses very slowly.
const EMBER_SHADER := """
shader_type spatial;
render_mode diffuse_burley, specular_disabled;
uniform sampler2D bark : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 glow_color : source_color = vec3(1.0, 0.42, 0.1);
uniform float glow_energy = 4.0;
uniform vec2 uv_scale = vec2(3.0, 0.5);

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1.0, 0.0)), f.x), mix(hash2(i + vec2(0.0, 1.0)), hash2(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec3 t = texture(bark, UV * uv_scale).rgb;
	ALBEDO = t * COLOR.rgb * 1.8;
	ROUGHNESS = 1.0;
	// Veins: thin lines where a stretched noise crosses its middle, mostly
	// running up the trunk, with a finer second set branching off them.
	float n1 = vnoise(UV * vec2(4.0, 0.12));
	float n2 = vnoise(UV * vec2(9.0, 0.4) + 7.3);
	float vein = max(1.0 - smoothstep(0.015, 0.05, abs(n1 - 0.5)), 0.6 * (1.0 - smoothstep(0.01, 0.035, abs(n2 - 0.5))));
	float pulse = 0.85 + 0.15 * sin(TIME * 0.6 + UV.y * 0.3);
	ALBEDO *= 1.0 - 0.6 * vein * COLOR.a;
	EMISSION = glow_color * glow_energy * vein * COLOR.a * pulse;
}
"""

# Mirrorbark: polished chrome bark. Fully metallic and nearly smooth, so it
# mirrors the sky and ground; the bark is split into faceted patches, each
# tipped a little differently, so the mirror breaks up like the owner's pictures.
const CHROME_SHADER := """
shader_type spatial;
render_mode diffuse_burley;
uniform float sway = 0.004;

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = sin(TIME * 0.9 + wp.x * 0.05 + wp.z * 0.04) + 0.4 * sin(TIME * 1.9 + wp.x * 0.11 + wp.z * 0.09);
	float bend = max(VERTEX.y, 0.0) * sway;
	VERTEX.x += gust * bend;
	VERTEX.z += gust * bend * 0.6;
}

float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(UV * vec2(4.0, 3.0));
	float a = hash2(cell);
	float b = hash2(cell + 17.0);
	NORMAL = normalize(NORMAL + (VIEW_MATRIX * vec4(a - 0.5, 0.0, b - 0.5, 0.0)).xyz * 0.5);
	ALBEDO = vec3(0.9, 0.91, 0.93) * (0.85 + 0.3 * a) * COLOR.rgb * 1.6;
	METALLIC = 1.0;
	ROUGHNESS = 0.06 + 0.08 * b;
	SPECULAR = 0.8;
}
"""

const KINDS := ["tree", "shrub", "plant"]
const GLOW_CELL_M := 24.0   # one glow light per this square of a glowing grove
const GLOW_LIGHTS := 24     # at most this many glow lights per chunk
const PART_M := [256.0, 128.0, 128.0]
const PART_M_LOW := [256.0, 256.0, 256.0]   # Low and Medium: shrubs and plants also in one part per chunk (a quarter of the draws)
const SHAPES_PER_BODY := 64  # trunk colliders per body
# Tree distances. The full model reaches near_m (tile rules, times the client's quality factor
# 0.4 / 0.7 / 1.0 / 1.0: 60, 105, 150 m), the cheaper far model reaches IMPOSTOR_M, and beyond it a pair of
# crossed quads (tree_impostor.gd) reaches view_m (180, 315, 450 m). Switch distances pulled closer 2026-10-20 (flora cost plan step 2). By quality: Low, Medium, High, Ultra.
const IMPOSTOR_M := [100.0, 150.0, 180.0, 210.0]
const IMPOSTOR_TILE_PX := [Vector2i(64, 128), Vector2i(128, 256), Vector2i(128, 256), Vector2i(128, 256)]   # one view; the atlas holds two
const MAX_DROPS_PER_UPDATE := 2
const SHADOW_M := [0.0, 45.0, 60.0, 50.0]   # full-detail trees cast shadows only this near (64 m cells; the sun's shadow range is a render setting)
const TIER_FAR := 0
const TIER_FULL := 1
const TIER_IMPOSTOR := 2
const TIER_MID := 3
const CELL_M := 64.0       # trees choose their tier (full or mid model, shadows) per cell of this size inside a chunk
const FULL_MIN_M := 30.0   # full-detail trees reach at least this far, even where there are no shadows (Low)
const CONTACT_M := 30.0    # full models cast the sun shadow only this near; farther full trees cast it from their far model
const TIER_FULL_LIT := 4   # plan keys only: a full model that does not cast (its shadow is the proxy's)
const TIER_PROXY := 5      # plan keys only: the far model drawn into the sun's shadow pass alone
const PROXY_BIT := 7       # level bits 7 and up: one per 64 m cell, set where a full-model cell is past CONTACT_M
const MID_MIN_TRIANGLES := 500   # trees with fewer triangles than this keep their full model at every near distance
const MID_LOD_SCALE_MIN := 25.0  # ImporterMesh.generate_lods merge angle (degrees)
const FAR_SHADOWS := [false, false, false, false]   # far-model trees cast no sun shadow (build 453: their shadows fall past the 90 m shadow range, and a part's whole MultiMesh is drawn into every cascade it touches)

var chunk_m: float = 256.0
var view_m: PackedFloat32Array = PackedFloat32Array([900.0, 300.0, 120.0])
var collision_m: float = 160.0
var near_m: PackedFloat32Array = PackedFloat32Array([260.0, 110.0, 0.0])   # full-detail model out to this distance (tree, shrub)
var canopy_version: int = 0           # counts changes to the held trees (the canopy map redraws on it)
var part_m: Array = PART_M            # the size of the square one shrub or plant MultiMesh covers (set by set_quality)
var impostor_m: float = 300.0          # trees beyond this are drawn as impostors (set by set_quality)
var far_shadows: bool = false
var shadow_m: float = 60.0
var instances: int = 0                 # items drawn now
var colliders: int = 0                 # trunk colliders now
var water_chunks: int = 0              # chunks with water drawn
var water_cells: int = 0

var cover = CoverScript.Index.new()   # tree crowns of the chunks held (Cover.at(pos, cover)): rain, sun and fire shelter
var _species: Dictionary = {}          # species id -> {"kind", "mesh", "trunk", "height"}
var _familiarity: Dictionary = {}      # species id -> base chance (percent) of knowing it on sight
var _display: Dictionary = {}          # species id -> display name
var _alikes: Dictionary = {}           # species id -> names of look-alike species
var _slugs: Dictionary = {}            # species id -> table name
var _labels: Dictionary = {}           # species id -> name with a note on its main property
var _chunks: Dictionary = {}           # Vector2i -> {"items", "level", "node"}
var _serial: int = 0                   # numbers each chunk plan, so an outdated plan is skipped
var _tasks: Array = []                 # WorkerThreadPool tasks making chunk plans
var _setup_queue: Array = []           # species entries still to build (see _setup_step)
var _setup_next: int = 0
var _models_ready: Dictionary = {}      # species id -> [near meshes, far meshes] from the worker
var _models_mutex: Mutex = Mutex.new()
var _models_task_id: int = -1
var _setup_total: int = 0
var _setup_done: bool = false
var _mid_wanted: Array = []            # [species id, variant, full mesh] still to be simplified (see _decimate_task)
var _mid_ready: Array = []             # [species id, variant, [surface arrays], [materials]] from the worker, built into meshes in apply_built
var _mid_task: int = -1
var _built: Array = []                 # finished plans: [chunk, serial, level, plan]
var _built_mutex: Mutex = Mutex.new()
var _trunk_shapes: Dictionary = {}     # radius in cm -> CylinderShape3D
var _jobs: Array = []                  # chunk drawings being put in the scene piece by piece
var _trunk_material: StandardMaterial3D
var _softwood_material: StandardMaterial3D   # conifer trunks: dark brown
var _hardwood_material: StandardMaterial3D   # broadleaf trunks: gray
var _water_material: ShaderMaterial
var _fall_material: ShaderMaterial
var _splash_material: ShaderMaterial
var _foam_material: ShaderMaterial
# Falls drawn per water chunk, by quality (Low, Medium, High, Ultra); farther than FALL_VIEW_M none.
const FALL_CAP := [2, 4, 8, 12]
const FALL_VIEW_M := 700.0   # measured from the chunk corner (the mesh origin), not the fall: 350 hid ribbons in a chunk's far half (Dave, build 483)
var fall_cap: int = 4

# Set by the client: whether any ground has arrived over a world point (network_voxel_stream.gd column_loaded). A chunk's plants and
# fall ribbons stay hidden until the ground under its middle exists, so nothing floats over ground that is not built yet (Dave, build 483).
var ground_ready: Callable = Callable()
var cleared: Array = []               # Vector3 spots of placed items: shrubs and small plants within clear_m are not drawn (set_cleared)
var clear_m: float = 5.0
var trunks: Array = []               # felled trunks: [ax, az, bx, bz, radius a, radius b]; no small plants under or beside them (set_trunks)
var trunk_margin_m: float = 0.3
var _last_position: Vector3 = Vector3.ZERO
var _ground_msec: int = 0
var falls_drawn: int = 0
var _tree_materials: Dictionary = {}       # TreeBuilder materials (bark, broad, conifer, palm)
var _impostors: Dictionary = {}            # species id -> {"mesh", "material"}; replaced whole when a capture finishes
var _impostor_tile: Vector2i = Vector2i.ZERO   # tile size of the finished (or running) capture
var _impostor_node: Node


# Owner (2026-10-19): rivers and ponds stay clear up to the start flow and turn muddy brown
# above it, like runoff after rain (fully brown from about 8 times it). The sea stays clear.
# The start flow was x1 until 2026-10-20 and is x10 now.
const START_FLOW_RATE := 10.0      # water_live.gd DEFAULT_RATE (the server's start rate)


# Ctrl+Shift+W hides every river and lake drawing (debug: does an odd patch on the water stay, then it is ground).
var water_hidden: bool = false


func toggle_water_visible() -> void:
	water_hidden = not water_hidden
	get_tree().call_group("water_draw", "set_visible", not water_hidden)


func water_material() -> Material:
	return _water_material


# Quality (F2): the distance where trees turn into impostors, their shadows, and the size of
# the impostor images (rendered once; again when the size changes). Safe to call again.
func set_quality(quality: int) -> void:
	quality = clampi(quality, 0, IMPOSTOR_M.size() - 1)
	impostor_m = IMPOSTOR_M[quality]
	far_shadows = FAR_SHADOWS[quality]
	part_m = PART_M_LOW if quality <= 1 else PART_M
	shadow_m = SHADOW_M[quality]
	var tile: Vector2i = IMPOSTOR_TILE_PX[quality]

	if tile != _impostor_tile and TreeImpostor.can_render():
		_impostor_tile = tile
		_capture_impostors(tile)


func _capture_impostors(tile: Vector2i) -> void:
	if _impostor_node == null:
		_impostor_node = TreeImpostor.new()
		add_child(_impostor_node)
		_impostor_node.finished.connect(_on_impostors)

	if _impostor_node._running:
		_impostor_tile = Vector2i.ZERO     # busy: try again at the next set_quality
		return

	var wanted: Dictionary = {}

	for id in _species:
		var info: Dictionary = _species[id]

		if int(info["kind"]) != KIND_TREE or not bool(info["tinted"]) or bool(info["glows"]):
			continue

		wanted[id] = {"mesh": info["far"][0]}     # the far model, so the two tiers match

	_impostor_node.start(wanted, tile)


# A finished capture replaces the images; chunks redraw on their next update (the level bit).
func _on_impostors(meshes: Dictionary) -> void:
	if not meshes.is_empty():
		_impostors = meshes


func set_water_quality(quality: int) -> void:
	fall_cap = FALL_CAP[clampi(quality, 0, FALL_CAP.size() - 1)]
	WaterMaterial.apply_quality(_water_material, quality)
	if _fall_material != null:
		_fall_material.set_shader_parameter("detail", 1.0 if quality >= 1 else 0.0)
	water_ease = quality >= 1


# Storm murk of the land water (weather_look.gd), 0 clear .. 1 big storm.
func set_storm_murk(amount: float) -> void:
	if _water_material != null:
		_water_material.set_shader_parameter("storm", amount)


# The sky colours of the day cycle for the land water (weather_look.gd).
func set_day_sky(top: Color, horizon: Color, cloud_shadow: Color, daylight: float) -> void:
	WaterMaterial.apply_day(_water_material, top, horizon, cloud_shadow, daylight)


func set_flow_rate(rate: float) -> void:
	rate /= START_FLOW_RATE

	if _water_material != null:
		_water_material.set_shader_parameter("mud", clampf(log(maxf(rate, 1.0)) / log(8.0), 0.0, 1.0))
		# Owner (2026-10-19): more flow looks more violent (raging from about 10 times the start flow).
		_water_material.set_shader_parameter("rough", clampf(log(maxf(rate, 1.0)) / log(10.0), 0.0, 1.0))


func setup(tables, tile_rules: Dictionary) -> void:
	var rules: Dictionary = tile_rules.get("runtime_flora", {})
	chunk_m = float(rules.get("chunk_m", 256.0))
	var view: Dictionary = rules.get("view_m", {})

	for n in range(3):
		view_m[n] = float(view.get(KINDS[n], view_m[n]))

	collision_m = float(rules.get("collision_m", collision_m))
	var near: Dictionary = rules.get("near_m", {})
	near_m[0] = float(near.get("tree", near_m[0]))
	near_m[1] = float(near.get("shrub", near_m[1]))
	_make_tree_materials()
	_trunk_material = StandardMaterial3D.new()
	_trunk_material.albedo_color = Color(0.32, 0.24, 0.16)
	_trunk_material.roughness = 1.0
	_softwood_material = StandardMaterial3D.new()
	_softwood_material.albedo_color = Color(0.2, 0.13, 0.08)
	_softwood_material.roughness = 1.0
	_hardwood_material = StandardMaterial3D.new()
	_hardwood_material.albedo_color = Color(0.5, 0.5, 0.5)
	_hardwood_material.roughness = 1.0
	_water_material = WaterMaterial.make()     # the same look as the sea (src/client/water_material.gd)
	_fall_material = WaterFallsScript.make_fall_material()
	_splash_material = WaterFallsScript.make_splash_material()
	_foam_material = WaterFallsScript.make_foam_material()

	_setup_queue = tables.get_entries("flora").filter(func(entry): return not entry.get("retired", false))
	_setup_total = _setup_queue.size()
	_models_task_id = WorkerThreadPool.add_task(_models_task.bind(_setup_queue.duplicate()), false, "flora models")


# Worker thread: builds each species' models (a tree species took 14 to 56 ms on the main thread).
# Only meshes are made here; the tables are filled on the main thread in _setup_entry.
func _models_task(entries: Array) -> void:
	for entry in entries:
		var height: Array = entry["height_m"]
		var reference: float = 0.5 * (float(height[0]) + float(height[1]))
		var kind: int = KINDS.find(str(entry["kind"]))
		var shape: String = str(entry["shape"])
		var built: bool = kind != KIND_PLANT or shape in ["grass", "reed", "fern", "flower", "shrub", "cactus"]
		var near_meshes: Array = []
		var far_meshes: Array = []

		if not built:
			var plain: ArrayMesh = _make_mesh(entry, reference)
			near_meshes = [plain]
			far_meshes = [plain]
		elif kind == KIND_PLANT:
			# Small plants: two variants, one model at every distance.
			for v in range(2):
				var model: ArrayMesh = TreeBuilder.build(entry, reference, v, false, _tree_materials)
				near_meshes.append(model)
				far_meshes.append(model)
		else:
			for v in range(TreeBuilder.VARIANTS):
				near_meshes.append(TreeBuilder.build(entry, reference, v, false, _tree_materials))
				far_meshes.append(TreeBuilder.build(entry, reference, v, true, _tree_materials))

			_override_models(str(entry["name"]), near_meshes, far_meshes)

		_models_mutex.lock()
		_models_ready[int(entry["id"])] = [near_meshes, far_meshes]
		_models_mutex.unlock()


# Owner-made models (2026-10-20): a glb named like the species in user://tree_meshes/ or
# res://assets/tree_meshes/ replaces the procedural near models (<name>.glb, objects <name>_v0 ..)
# and/or far models (<name>_far.glb, objects <name>_v0_far ..), as exported by
# tools/export_tree_meshes.gd. Anything missing or unreadable keeps the procedural model; nothing
# here touches saves or the protocol. Runs on the worker thread.
const MODEL_DIRS := ["user://tree_meshes/", "res://assets/tree_meshes/"]


func _override_models(species: String, near_meshes: Array, far_meshes: Array) -> void:
	for far in [false, true]:
		var meshes: Array = far_meshes if far else near_meshes
		var suffix: String = "_far" if far else ""

		for dir in MODEL_DIRS:
			var path: String = "%s%s%s.glb" % [dir, species, suffix]

			if not FileAccess.file_exists(path):
				continue

			var document: GLTFDocument = GLTFDocument.new()
			var state: GLTFState = GLTFState.new()

			if document.append_from_file(path, state) != OK:
				push_warning("tree mesh %s could not be read, using the built-in model" % path)
				continue

			var root: Node = document.generate_scene(state)

			if root == null:
				continue

			for v in range(meshes.size()):
				var node: Node = root.find_child("%s_v%d%s" % [species, v, suffix], true, false)

				if node is MeshInstance3D and (node as MeshInstance3D).mesh is ArrayMesh:
					var mesh: ArrayMesh = (node as MeshInstance3D).mesh
					_use_game_materials(mesh)
					meshes[v] = mesh

			root.free()
			break


# The glb carries plain stand-in materials named after the game's (bark, leaves ...): put the
# game's own shaders back so wind, back-light and moss still work.
func _use_game_materials(mesh: ArrayMesh) -> void:
	for s in range(mesh.get_surface_count()):
		var material: Material = mesh.surface_get_material(s)

		if material == null:
			continue

		# The importer renames a material that shares a name with an object ("oak" becomes "oak2").
		var key: String = material.resource_name

		while not _tree_materials.has(key) and not key.is_empty() and key[key.length() - 1].is_valid_int():
			key = key.substr(0, key.length() - 1)

		if _tree_materials.has(key):
			mesh.surface_set_material(s, _tree_materials[key])


# Builds every queued species now (tools and the preview, which have no frame budget).
func finish_setup() -> void:
	if _models_task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_models_task_id)

	_setup_step(1 << 40)


# Builds queued species until budget_usec is spent (at least one). Returns true once all are built.
func _setup_step(budget_usec: int = 4000) -> bool:
	var start: int = Time.get_ticks_usec()

	while _setup_next < _setup_queue.size():
		if not _setup_entry(_setup_queue[_setup_next]):
			break      # the worker has not built this species yet

		_setup_next += 1

		if Time.get_ticks_usec() - start >= budget_usec:
			break

	if _setup_next < _setup_queue.size():
		return false

	if not _setup_done:
		_setup_done = true
		_setup_queue = []
		WorkerThreadPool.wait_for_task_completion(_models_task_id)
		_models_task_id = -1
		_start_mid_task()

		# Chunks that arrived before their species were built had no crowns in the cover index.
		for chunk in _chunks.keys():
			CoverScript.add_chunk(cover, chunk, _chunks[chunk]["items"], _cover_info)

		canopy_version += 1

	return true


# Builds one species (models and look table). setup queues them; _setup_step does a few per frame
# so the welcome does not stall on all of them at once (build 233).
func _setup_entry(entry: Dictionary) -> bool:
	var height: Array = entry["height_m"]
	var reference: float = 0.5 * (float(height[0]) + float(height[1]))
	_labels[int(entry["id"])] = _label_for(entry)
	_familiarity[int(entry["id"])] = int(entry.get("familiarity", 50))
	_alikes[int(entry["id"])] = entry.get("look_alikes", [])
	_slugs[int(entry["id"])] = str(entry["name"])
	_display[int(entry["id"])] = str(entry.get("display", entry.get("name", "")))
	var kind: int = KINDS.find(str(entry["kind"]))
	var shape: String = str(entry["shape"])
	var built: bool = kind != KIND_PLANT or shape in ["grass", "reed", "fern", "flower", "shrub", "cactus"]
	# The models come from the worker (_models_task); wait for this species' turn.
	_models_mutex.lock()
	var models: Array = _models_ready.get(int(entry["id"]), [])
	_models_mutex.unlock()

	if models.is_empty():
		return false

	var near_meshes: Array = models[0]
	var far_meshes: Array = models[1]

	if OS.has_environment("FLORA_DEBUG"):
		var counts: Array = []

		for mesh in near_meshes:
			var total: int = 0

			for s in range(mesh.get_surface_count()):
				total += (mesh.surface_get_arrays(s)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()

			counts.append(total)

		print("FLORA_DEBUG ", entry["name"], " id=", entry["id"], " kind=", entry["kind"], " shape=", shape, " model=", entry.get("model", "-"), " height=", reference, " near_vertices=", counts, " built=", built)

	# The mid model starts as the full model; _decimate_task swaps in the simplified one when ready.
	var mid_meshes: Array = near_meshes.duplicate()
	if kind == KIND_TREE and built:
		for v in range(near_meshes.size()):
			_mid_wanted.append([int(entry["id"]), v, near_meshes[v]])

	var c: Array = entry["color"]
	_species[int(entry["id"])] = {
		"kind": kind,
		"height": reference,
		"trunk": float(entry["trunk_m"]),
		"crown": float(entry["crown_m"]),
		# Hardwoods, and any species with autumn colors of its own (the
		# wardpine), take an autumn tint.
		"hardwood": str(entry["shape"]) == "broadleaf" or entry.has("autumn_colors"),
		"tinted": built,
		"near": near_meshes,
		"mid": mid_meshes,
		"far": far_meshes,
		"shape": shape,
		"glows": entry.has("glow") or entry.has("leaf_glow"),
		"tint": _plant_tint(entry, c),
	}

	if entry.has("young_below_m"):
		_species[int(entry["id"])]["young_below"] = float(entry["young_below_m"])

	if entry.has("leaf_glow"):
		_species[int(entry["id"])]["leaf_glow"] = true

	if entry.has("glow"):
		var g: Array = entry["glow"]
		_species[int(entry["id"])]["glow"] = Color(float(g[0]), float(g[1]), float(g[2]))
		_species[int(entry["id"])]["glow_energy"] = float(entry.get("glow_energy", 2.0))
		_species[int(entry["id"])]["glow_height"] = float(entry.get("glow_height", 0.0))   # light height, fraction of the tree

	if entry.has("autumn_colors"):
		var palette: Array[Color] = []
		for ac in entry["autumn_colors"]:
			palette.append(Color(float(ac[0]), float(ac[1]), float(ac[2])))
		_species[int(entry["id"])]["autumn"] = palette

	if entry.has("young_color"):
		var yc: Array = entry["young_color"]
		_species[int(entry["id"])]["young_tint"] = _plant_tint(entry, yc)
		_species[int(entry["id"])]["young_m"] = entry.get("young_m", [4.0, 15.0])
	return true

func _make_tree_materials() -> void:
	var foliage: Shader = Shader.new()
	foliage.code = FOLIAGE_SHADER
	var bark: Shader = Shader.new()
	bark.code = BARK_SHADER
	_tree_materials = {}
	var bark_material: ShaderMaterial = ShaderMaterial.new()
	bark_material.shader = bark
	bark_material.set_shader_parameter("bark", _load_texture("res://assets/trees/bark.png"))
	_tree_materials["bark"] = bark_material
	var birch_material: ShaderMaterial = ShaderMaterial.new()
	birch_material.shader = bark
	birch_material.set_shader_parameter("bark", _load_texture("res://assets/trees/bark_birch.png"))
	_tree_materials["birch_bark"] = birch_material
	var smooth_material: ShaderMaterial = ShaderMaterial.new()
	smooth_material.shader = bark
	smooth_material.set_shader_parameter("bark", _load_texture("res://assets/trees/bark_smooth.png"))
	_tree_materials["smooth_bark"] = smooth_material
	var chrome: Shader = Shader.new()
	chrome.code = CHROME_SHADER
	var chrome_material: ShaderMaterial = ShaderMaterial.new()
	chrome_material.shader = chrome
	_tree_materials["chrome"] = chrome_material
	var ember: Shader = Shader.new()
	ember.code = EMBER_SHADER
	var ember_material: ShaderMaterial = ShaderMaterial.new()
	ember_material.shader = ember
	ember_material.set_shader_parameter("bark", _load_texture("res://assets/trees/bark.png"))
	_tree_materials["ember"] = ember_material

	for pair in [["broad", "res://assets/trees/leaf_broad.png"], ["conifer", "res://assets/trees/leaf_conifer.png"], ["palm", "res://assets/trees/leaf_palm.png"], ["grass", "res://assets/grass/grass_tall.png"], ["twig", "res://assets/trees/twig_birch.png"], ["oak", "res://assets/trees/leaf_oak.png"], ["willow", "res://assets/trees/leaf_willow.png"], ["rowan", "res://assets/trees/leaf_rowan.png"], ["maple", "res://assets/trees/leaf_maple.png"], ["witness", "res://assets/trees/leaf_witness.png"]]:
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = foliage
		material.set_shader_parameter("leaves", _load_texture(pair[1]))
		_tree_materials[pair[0]] = material

	# Conifer boughs hang from the trunk, so they sway less; palms sway more.
	_tree_materials["conifer"].set_shader_parameter("sway", 0.006)
	_tree_materials["conifer"].set_shader_parameter("backlight", 0.25)   # needles are denser
	_tree_materials["palm"].set_shader_parameter("sway", 0.02)
	_tree_materials["grass"].set_shader_parameter("sway", 0.09)
	_tree_materials["grass"].set_shader_parameter("flutter", 0.01)
	_tree_materials["grass"].set_shader_parameter("backlight", 0.3)
	_tree_materials["twig"].set_shader_parameter("backlight", 0.0)   # bare twigs are solid wood
	_tree_materials["witness"].set_shader_parameter("glow", Color(0.42, 0.26, 0.7))   # soft lavender night glow


# A painted texture, imported by the editor or else read straight from the file.
static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var imported: Texture2D = load(path) as Texture2D

		if imported != null:
			return imported

	var image: Image = Image.load_from_file(ProjectSettings.globalize_path(path))

	if image == null:
		image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.5, 0.6, 0.4, 1.0))

	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


# "Hemlock (Toxic)": the display name, with the first listed property as a note.
static func _label_for(entry: Dictionary) -> String:
	var text: String = str(entry.get("display", entry.get("name", "Plant")))
	var properties: Array = entry.get("properties", [])

	if not properties.is_empty():
		text += " (%s)" % str(properties[0]).replace("_", " ").capitalize()

	return text


func label_of(species_id: int) -> String:
	return str(_labels.get(species_id, ""))


# The base percent chance a character already knows this species on sight.
func familiarity_of(species_id: int) -> int:
	return int(_familiarity.get(species_id, 50))


# Display names of the species this one might be mistaken for (the table's
# look_alikes), or other species of the same kind when none are listed.
func lookalikes(species_id: int) -> Array:
	var names: Array = []

	for slug in _alikes.get(species_id, []):
		for id in _display:
			if _slugs.get(id, "") == slug:
				names.append(str(_display[id]))

	if not names.is_empty() or not _species.has(species_id):
		return names

	var kind: int = int(_species[species_id]["kind"])

	for id in _species:
		if id != species_id and int(_species[id]["kind"]) == kind:
			names.append(str(_display.get(id, "")))

	return names


# The species id of the shrub, plant or tree standing nearest `point` within
# `radius` metres (-1 when none).
func species_near(point: Vector3, radius: float) -> int:
	var chunk: Vector2i = Vector2i(int(floor(point.x / chunk_m)), int(floor(point.z / chunk_m)))

	if not _chunks.has(chunk):
		return -1

	var items: Dictionary = _chunks[chunk]["items"]
	var best: float = radius * radius
	var found: int = -1
	var positions: PackedVector3Array = items["positions"]
	var ids: PackedInt32Array = items["ids"]

	for n in range(positions.size()):
		var d: Vector3 = positions[n] - point
		var squared: float = d.x * d.x + d.z * d.z + 0.25 * d.y * d.y

		if squared < best:
			best = squared
			found = ids[n] >> 16

	return found


# The chunks to have, nearest first: every chunk within tree view distance.
func wanted_chunks(from_position: Vector3) -> Array:
	var reach: int = int(ceil(view_m[KIND_TREE] / chunk_m))
	var center: Vector2i = Vector2i(int(floor(from_position.x / chunk_m)), int(floor(from_position.z / chunk_m)))
	var list: Array = []

	for dz in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var chunk: Vector2i = center + Vector2i(dx, dz)
			var distance: float = _distance(chunk, from_position)

			if distance <= view_m[KIND_TREE]:
				list.append([distance, chunk])

	list.sort_custom(func(a, b): return a[0] < b[0])
	return list.map(func(entry): return entry[1])


func has_chunk(chunk: Vector2i) -> bool:
	return _chunks.has(chunk)


# The chunks held now.
func held_chunks() -> Array:
	return _chunks.keys()


const EASE_STEPS := 3                  # a moved water surface reaches its new level in this many redraws
const EASE_STEP_MSEC := 150
const EASE_MIN_M := 0.02              # levels that moved less than this just jump
var water_ease: bool = true           # off at Low: a chunk's water jumps to the new level (set by the quality setting)
var _ease: Dictionary = {}            # chunk -> {"old", "new", "step", "next_msec"}


# Species facts for the cover query: [kind, crown_m, reference height], empty when unknown.
func _cover_info(species_id: int) -> Array:
	var info: Dictionary = _species.get(species_id, {})
	return [] if info.is_empty() else [int(info["kind"]), float(info.get("crown", 0.0)), float(info["height"])]


# Redraws only a held chunk's water (the simulated water moved). Owner (2026-10-20): the water
# eases to its new levels over a few redraws instead of jumping; only chunks whose levels
# moved are redrawn more than once, and nothing runs while the water is still.
func set_water(chunk: Vector2i, water: Dictionary) -> void:
	var entry: Dictionary = _chunks.get(chunk, {})

	if entry.is_empty():
		return

	_ease.erase(chunk)
	var old: Dictionary = entry.get("grid", {})
	WaterGridScript.steady_edges(old, water)

	if water_ease and WaterGridScript.moved(old, water, EASE_MIN_M):
		_ease[chunk] = {"old": old, "new": water, "step": 1, "next_msec": Time.get_ticks_msec() + EASE_STEP_MSEC}
		_draw_water(chunk, entry, WaterGridScript.blend(old, water, 1.0 / float(EASE_STEPS)))
		return

	_draw_water(chunk, entry, water)


func _ease_water() -> void:
	var now: int = Time.get_ticks_msec()

	for chunk in _ease.keys():
		var job: Dictionary = _ease[chunk]
		var entry: Dictionary = _chunks.get(chunk, {})

		if entry.is_empty():
			_ease.erase(chunk)
			continue

		if now < int(job["next_msec"]):
			continue

		job["step"] = int(job["step"]) + 1
		job["next_msec"] = now + EASE_STEP_MSEC

		if int(job["step"]) >= EASE_STEPS:
			_ease.erase(chunk)
			_draw_water(chunk, entry, job["new"])
		else:
			_draw_water(chunk, entry, WaterGridScript.blend(job["old"], job["new"], float(job["step"]) / float(EASE_STEPS)))

		# One chunk's mesh per frame keeps the cost flat.
		return


# The ice cover on still water (src/shared/ice.gd; the same number everywhere). From
# Ice.WALK_COVER up, each chunk's pond and lake water gets a flat collider at the water level, so a
# person walks on it and can never fall through (owner, 2026-10-21). Redrawn when it crosses that line.
var ice_cover: float = 0.0
var _ice_bears: bool = false


func set_ice_cover(value: float) -> void:
	ice_cover = value

	if _water_material != null:
		_water_material.set_shader_parameter("ice", value)

	var bears: bool = IceScript.bears(value)

	if bears == _ice_bears:
		return

	_ice_bears = bears

	for chunk in _chunks:
		var entry: Dictionary = _chunks[chunk]
		_draw_ice(chunk, entry, entry.get("grid", {}))


func _draw_ice(chunk: Vector2i, entry: Dictionary, water: Dictionary) -> void:
	var old: StaticBody3D = entry.get("ice")

	if old != null:
		old.queue_free()
		entry["ice"] = null

	if not _ice_bears or int(water.get("wet", 0)) == 0:
		return

	var triangles: PackedVector3Array = WaterGridScript.ice_triangles(water)

	if triangles.is_empty():
		return

	var shape: ConcavePolygonShape3D = ConcavePolygonShape3D.new()
	shape.set_faces(triangles)
	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.shape = shape
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 2        # the ice layer: a swimmer's ground ray (layer 1) does not see it
	body.collision_mask = 0
	body.add_child(collision)
	body.position = Vector3(float(chunk.x) * chunk_m, 0.0, float(chunk.y) * chunk_m)
	add_child(body)
	entry["ice"] = body


func _draw_water(chunk: Vector2i, entry: Dictionary, water: Dictionary) -> void:
	var old: MeshInstance3D = entry.get("water")

	if old != null:
		water_chunks -= 1
		water_cells -= old.mesh.surface_get_array_index_len(0) / 6
		old.queue_free()
		entry["water"] = null

	entry["grid"] = water

	if int(water.get("wet", 0)) > 0:
		var mesh: ArrayMesh = water["mesh"] if water.has("mesh") else WaterGridScript.build_mesh(water, _water_material)

		if mesh.get_surface_count() > 0:
			var draw: MeshInstance3D = MeshInstance3D.new()
			draw.mesh = mesh
			draw.position = Vector3(float(chunk.x) * chunk_m, 0.0, float(chunk.y) * chunk_m)
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			draw.visible = not water_hidden
			draw.add_to_group("water_draw")
			add_child(draw)
			entry["water"] = draw
			water_chunks += 1
			@warning_ignore("integer_division")
			water_cells += mesh.surface_get_array_index_len(0) / 6

	_draw_ice(chunk, entry, water)
	_draw_falls(chunk, entry, water)


# Owner (2026-10-20, Dave, builds 281 at x1 and x10): the fall ribbons drawn over the running
# water looked fake, patchy and misaligned with the real water. At the x10 start flow the sim's
# own water runs down the drops, so water over a drop is shown only by the water surface. The
# fall finder still feeds the list below (sound, mist, spray, wet rock); only the ribbon
# meshes, their splash and foam strips are not drawn. Set true to bring them back.
const DRAW_FALL_RIBBONS := true


# The chunk's fall columns (water_falls.gd): kept while the same mesh is still the right one.
func _draw_falls(chunk: Vector2i, entry: Dictionary, water: Dictionary) -> void:
	var mesh: ArrayMesh = water.get("falls_mesh")

	if mesh == null and DRAW_FALL_RIBBONS and not water.get("falls", []).is_empty():
		mesh = WaterFallsScript.build_mesh(water["falls"], fall_cap)

	var old: MeshInstance3D = entry.get("falls")

	if old != null and old.mesh == mesh:
		return

	if old != null:
		falls_drawn -= old.mesh.get_surface_count()
		old.queue_free()
		entry["falls"] = null

	if mesh == null or mesh.get_surface_count() == 0:
		return

	var draw: MeshInstance3D = MeshInstance3D.new()
	draw.mesh = mesh
	draw.position = Vector3(float(chunk.x) * chunk_m, 0.0, float(chunk.y) * chunk_m)
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	draw.extra_cull_margin = 30.0
	draw.visibility_range_end = FALL_VIEW_M
	draw.visible = bool(entry.get("ground", true))
	draw.set_surface_override_material(0, _fall_material)

	if mesh.get_surface_count() > 1:
		draw.set_surface_override_material(1, _splash_material)
		draw.set_surface_override_material(2, _foam_material)

	add_child(draw)
	entry["falls"] = draw
	falls_drawn += mesh.get_surface_count()


# Every fall in the held chunks, for other systems (mist, wet rock and moss on the walls,
# sound): [{"id": int, "top": Vector3, "base": Vector3, "pool": float, "flow": m3/s, "width": m}] in
# world coordinates; the id is stable while the fall's chunk is held and its water unchanged.
func fall_list() -> Array:
	var list: Array = []

	for chunk in _chunks:
		for n in range(_chunks[chunk].get("grid", {}).get("falls", []).size()):
			var fall: Dictionary = _chunks[chunk]["grid"]["falls"][n]
			var points: PackedVector3Array = fall["points"]
			var corner: Vector3 = Vector3(float(chunk.x) * chunk_m, 0.0, float(chunk.y) * chunk_m)
			list.append({"id": (chunk.x * 73856093) ^ (chunk.y * 19349663) ^ (n * 83492791), "top": points[0] + corner, "base": points[points.size() - 1] + corner, "pool": float(fall.get("pool", points[points.size() - 1].y)), "flow": float(fall["flow"]), "width": float(fall["width"])})

	return list


# A water grid may carry its drawing already built under "mesh" (made on a worker
# thread by the client, see terrain_client.gd _decode_in).
# Sets a chunk's items (as from FloraPlacer.chunk_items or decode).
func set_chunk(chunk: Vector2i, items: Dictionary, from_position: Vector3, water: Dictionary = {}, full: bool = true) -> void:
	drop_chunk(chunk)
	canopy_version += 1
	var entry: Dictionary = {"items": items, "level": -1, "node": null, "water": null, "grid": water, "full": full, "ground": _ground_here(chunk)}
	_chunks[chunk] = entry
	_filter_cleared(chunk, false)
	CoverScript.add_chunk(cover, chunk, items, _cover_info)

	if int(water.get("wet", 0)) > 0:
		var mesh: ArrayMesh = water["mesh"] if water.has("mesh") else WaterGridScript.build_mesh(water, _water_material)

		if mesh.get_surface_count() > 0:
			var draw: MeshInstance3D = MeshInstance3D.new()
			draw.mesh = mesh
			draw.position = Vector3(float(chunk.x) * chunk_m, 0.0, float(chunk.y) * chunk_m)
			draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			draw.visible = not water_hidden
			draw.add_to_group("water_draw")
			add_child(draw)
			entry["water"] = draw
			water_chunks += 1
			@warning_ignore("integer_division")
			water_cells += mesh.surface_get_array_index_len(0) / 6

	_draw_ice(chunk, entry, water)
	_draw_falls(chunk, entry, water)
	_refresh(chunk, from_position)


# The lake or river surface level at a point (NAN where there is none).
func water_level_at(x: float, z: float) -> float:
	var chunk: Vector2i = Vector2i(int(floor(x / chunk_m)), int(floor(z / chunk_m)))
	var grid: Dictionary = _chunks.get(chunk, {}).get("grid", {})

	if int(grid.get("wet", 0)) == 0:
		return NAN

	var spacing: float = float(grid["spacing"])
	var count: int = int(grid["count"])
	var fx: float = (x - float(chunk.x) * chunk_m) / spacing
	var fz: float = (z - float(chunk.y) * chunk_m) / spacing
	var i0: int = clampi(int(floor(fx)), 0, count - 1)
	var j0: int = clampi(int(floor(fz)), 0, count - 1)
	var best: float = NAN

	# The highest wet corner of the square the point is in (a single nearest corner
	# missed the water at the bottom of a steep pond).
	for j in range(j0, mini(j0 + 2, count)):
		for i in range(i0, mini(i0 + 2, count)):
			var level: float = float(grid["levels"][j * count + i])

			if not is_nan(level) and (is_nan(best) or level > best):
				best = level

	return best


# The water surface at a point for footsteps: the wet corners of the square,
# blended by distance (bilinear weights over the wet corners only), NAN when
# half the square or less is wet. Unlike water_level_at (the highest wet corner, which the
# underwater check needs), it does not lift a dry bank to the level of
# higher water beside it.
func water_surface_at(x: float, z: float) -> float:
	var chunk: Vector2i = Vector2i(int(floor(x / chunk_m)), int(floor(z / chunk_m)))
	var grid: Dictionary = _chunks.get(chunk, {}).get("grid", {})

	if int(grid.get("wet", 0)) == 0:
		return NAN

	var spacing: float = float(grid["spacing"])
	var count: int = int(grid["count"])
	var fx: float = (x - float(chunk.x) * chunk_m) / spacing
	var fz: float = (z - float(chunk.y) * chunk_m) / spacing
	var i0: int = clampi(int(floor(fx)), 0, count - 2)
	var j0: int = clampi(int(floor(fz)), 0, count - 2)
	var tx: float = clampf(fx - float(i0), 0.0, 1.0)
	var tz: float = clampf(fz - float(j0), 0.0, 1.0)
	var total: float = 0.0
	var weight: float = 0.0

	for c in range(4):
		var i: int = i0 + (c & 1)
		var j: int = j0 + (c >> 1)
		var level: float = float(grid["levels"][j * count + i])

		if is_nan(level):
			continue

		var w: float = (tx if c & 1 else 1.0 - tx) * (tz if c >> 1 else 1.0 - tz) + 0.0001
		total += level * w
		weight += w

	# One wet corner up to 8 m away is not water under the feet: need more than half the square wet.
	return total / weight if weight > 0.5 else NAN


# The speed of the water current (m/s) at the nearest wet grid point, -1 where there is no water
# or the chunk carries no current. Cheap: one chunk lookup and one point (used by the water sounds).
func water_speed_at(x: float, z: float) -> float:
	var chunk: Vector2i = Vector2i(int(floor(x / chunk_m)), int(floor(z / chunk_m)))
	var grid: Dictionary = _chunks.get(chunk, {}).get("grid", {})

	if int(grid.get("wet", 0)) == 0:
		return -1.0

	var vel: PackedFloat32Array = grid.get("vel", PackedFloat32Array())
	var spacing: float = float(grid["spacing"])
	var count: int = int(grid["count"])
	var i: int = clampi(int(round((x - float(chunk.x) * chunk_m) / spacing)), 0, count - 1)
	var j: int = clampi(int(round((z - float(chunk.y) * chunk_m) / spacing)), 0, count - 1)
	var n: int = j * count + i

	if vel.size() != count * count * 2 or is_nan(float(grid["levels"][n])):
		return -1.0

	return Vector2(vel[n * 2], vel[n * 2 + 1]).length()


func drop_chunk(chunk: Vector2i) -> void:
	_ease.erase(chunk)
	var entry: Dictionary = _chunks.get(chunk, {})

	if entry.is_empty():
		return

	canopy_version += 1
	_clear_node(entry)
	cover.remove_chunk(chunk)
	var water: MeshInstance3D = entry.get("water")

	if water != null:
		water_chunks -= 1
		water_cells -= water.mesh.surface_get_array_index_len(0) / 6
		water.queue_free()

	var falls: MeshInstance3D = entry.get("falls")

	if falls != null:
		falls_drawn -= falls.mesh.get_surface_count()
		falls.queue_free()

	var ice: StaticBody3D = entry.get("ice")

	if ice != null:
		ice.queue_free()

	_chunks.erase(chunk)


# Owner (2026-10-19): trees are drawn far, shrubs and small plants only near. Chunks
# beyond this distance are asked for with their trees only; a chunk coming
# closer is asked for again in full.
func full_m() -> float:
	return maxf(view_m[KIND_SHRUB], view_m[KIND_PLANT]) + 0.25 * chunk_m


func needs_full(chunk: Vector2i, from_position: Vector3) -> bool:
	return _distance(chunk, from_position) <= full_m()


func holds_full(chunk: Vector2i) -> bool:
	return bool(_chunks.get(chunk, {}).get("full", false))


# A held chunk's items replaced (its trees-only form by the full one). The old
# drawing stays until the new one is built, so nothing blinks.
func replace_items(chunk: Vector2i, items: Dictionary, from_position: Vector3, full: bool) -> void:
	var entry: Dictionary = _chunks.get(chunk, {})

	if entry.is_empty():
		return

	canopy_version += 1
	entry["items"] = items
	entry["full"] = full
	entry["level"] = -1
	entry.erase("building")
	_filter_cleared(chunk, false)
	_refresh(chunk, from_position)


# Removes one item (cut down) and redraws its chunk.
func remove_item(chunk: Vector2i, id: int, from_position: Vector3) -> void:
	var entry: Dictionary = _chunks.get(chunk, {})

	if entry.is_empty():
		return

	var items: Dictionary = entry["items"]
	var index: int = items["ids"].find(id)

	if index < 0:
		return

	canopy_version += 1

	for key in ["ids", "positions", "heights", "yaws"]:
		items[key].remove_at(index)

	cover.remove_item(chunk, id)

	entry["level"] = -1
	entry.erase("building")
	_refresh(chunk, from_position)


# The placed things of the world: no shrubs or small plants within radius of any of them (trees stay; felling is the server's).
# Items already held are filtered now, and later chunks as they arrive.
func set_cleared(spots: Array, radius: float) -> void:
	cleared = spots
	clear_m = radius

	for chunk in _chunks.keys():
		_filter_cleared(chunk, true)


# Felled trunks (Dave 2026-10-21): small plants growing out of a lying log are not drawn (the grass is pressed flat in grass_view).
func set_trunks(list: Array, margin: float) -> void:
	trunks = list
	trunk_margin_m = margin

	for chunk in _chunks.keys():
		_filter_cleared(chunk, true)


func _under_trunk(p: Vector3) -> bool:
	for t in trunks:
		var a: Vector2 = Vector2(t[0], t[1])
		var ab: Vector2 = Vector2(t[2], t[3]) - a
		var along: float = clampf((Vector2(p.x, p.z) - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)

		if (Vector2(p.x, p.z) - (a + ab * along)).length() < lerpf(t[4], t[5], along) + trunk_margin_m + 0.2:
			return true

	return false


func _filter_cleared(chunk: Vector2i, redraw: bool) -> void:
	var entry: Dictionary = _chunks.get(chunk, {})

	if entry.is_empty() or (cleared.is_empty() and trunks.is_empty()):
		return

	var items: Dictionary = entry["items"]
	var positions = items["positions"]
	var ids = items["ids"]
	var n: int = ids.size() - 1
	var removed: bool = false

	while n >= 0:
		var species: Dictionary = _species.get(int(ids[n]) >> 16, {})

		if not species.is_empty() and int(species["kind"]) != KIND_TREE and not trunks.is_empty() and _under_trunk(positions[n]):
			for key in ["ids", "positions", "heights", "yaws"]:
				items[key].remove_at(n)

			removed = true
		elif not species.is_empty() and int(species["kind"]) != KIND_TREE:
			for spot in cleared:
				if Vector2(positions[n].x - spot.x, positions[n].z - spot.z).length() < clear_m:
					for key in ["ids", "positions", "heights", "yaws"]:
						items[key].remove_at(n)

					removed = true
					break

		n -= 1

	if removed and redraw:
		entry["level"] = -1
		entry.erase("building")
		_refresh(chunk, _last_position)


# Once a second: chunks still waiting for ground are asked again; the moment it is there their plants and ribbons are shown (and stay).
func _check_ground() -> void:
	var now: int = Time.get_ticks_msec()

	if now - _ground_msec < 1000:
		return

	_ground_msec = now

	for chunk in _chunks:
		var entry: Dictionary = _chunks[chunk]

		if not bool(entry.get("ground", true)) and _ground_here(chunk):
			entry["ground"] = true
			var node: Node3D = entry.get("node")
			var falls: Node3D = entry.get("falls")

			if node != null:
				node.visible = true

			if falls != null:
				falls.visible = true


func _ground_here(chunk: Vector2i) -> bool:
	return not ground_ready.is_valid() or bool(ground_ready.call((float(chunk.x) + 0.5) * chunk_m, (float(chunk.y) + 0.5) * chunk_m))


# Redraws chunks whose level changed and drops far ones. Returns the
# chunks dropped.
func update(from_position: Vector3) -> Array:
	var dropped: Array = []
	_last_position = from_position
	_check_ground()

	if not _ease.is_empty():
		_ease_water()

	for chunk in _chunks.keys():
		if _distance(chunk, from_position) > view_m[KIND_TREE] + 2.0 * chunk_m:
			# Freeing a chunk's draws and colliders costs up to 30 ms (build 176 probe), so a few
			# at a time; the rest go on the next update. They are out of view range meanwhile.
			if dropped.size() < MAX_DROPS_PER_UPDATE:
				drop_chunk(chunk)
				dropped.append(chunk)
		else:
			_refresh(chunk, from_position)

	return dropped


# The crowns of the held trees within radius_m of (x, z), as [x, z, canopy radius]: the shared
# cover index (src/shared/cover.gd, owner Q8, 2026-10-20: anywhere under a crown counts as
# cover). The canopy map (src/client/canopy_map.gd) is drawn from this.
func canopy_discs(x: float, z: float, radius_m: float) -> Array:
	return cover.discs_near(x, z, radius_m)


func item_count() -> int:
	var total: int = 0

	for chunk in _chunks:
		total += _chunks[chunk]["items"]["ids"].size()

	return total


# ---------------------------------------------------------------- drawing

# Level bits: 1 trees, 2 shrubs, 4 plants, 8 colliders, 16 and 32 full models, 64 tree impostors.
func _level(chunk: Vector2i, from_position: Vector3) -> int:
	var distance: float = _distance(chunk, from_position)
	var level: int = 0

	for kind in range(3):
		if distance <= view_m[kind]:
			level |= 1 << kind

	if distance <= collision_m:
		level |= 8

	# Full-detail models near the player (trees 16, shrubs 32).
	for kind in range(2):
		if distance <= near_m[kind]:
			level |= 16 << kind

	# Trees choose their model per 64 m cell of the chunk, not per chunk (a chunk is 256 m wide, so
	# one near corner used to give the whole chunk full models): two bits per cell from bit 32 up,
	# TIER_FAR 0, TIER_FULL 1 (casts shadows), TIER_IMPOSTOR 2, TIER_MID 3.
	if (level & 1) != 0:
		var cells: int = int(chunk_m / CELL_M)
		var full_range_m: float = maxf(shadow_m, FULL_MIN_M)
		var x0: float = float(chunk.x) * chunk_m
		var z0: float = float(chunk.y) * chunk_m

		for cz in range(cells):
			for cx in range(cells):
				var dx: float = maxf(maxf(x0 + float(cx) * CELL_M - from_position.x, from_position.x - (x0 + float(cx + 1) * CELL_M)), 0.0)
				var dz: float = maxf(maxf(z0 + float(cz) * CELL_M - from_position.z, from_position.z - (z0 + float(cz + 1) * CELL_M)), 0.0)
				var d: float = sqrt(dx * dx + dz * dz)
				var tier: int = TIER_FAR

				if d <= full_range_m:
					tier = TIER_FULL

					if shadow_m > CONTACT_M and d > CONTACT_M:
						level |= 1 << (PROXY_BIT + cz * cells + cx)
				elif d <= near_m[0]:
					tier = TIER_MID
				elif not _impostors.is_empty() and d > impostor_m:
					tier = TIER_IMPOSTOR

				level |= tier << (32 + 2 * (cz * cells + cx))

	return level


# Owner (2026-10-19): the game paused while flying because redrawing a chunk (hundreds of
# trees, set one by one) ran on the main thread, several chunks at a time. Now the layout of
# a chunk is worked out on a worker thread (_plan) and only the finished pieces are put in
# the scene on the main thread (apply_built, called every frame).
func _refresh(chunk: Vector2i, from_position: Vector3) -> void:
	if not _setup_done:
		return

	var entry: Dictionary = _chunks[chunk]
	var level: int = _level(chunk, from_position)

	if level == entry["level"] or level == entry.get("building", -2):
		return

	_serial += 1
	entry["building"] = level
	entry["serial"] = _serial
	# The worker gets real copies of the arrays: remove_item (felling) changes the chunk's own arrays on the
	# main thread while the worker reads, and sharing them crashed the worker (out of bounds in _plan, 2026-10-21).
	var items: Dictionary = {}

	for key in entry["items"]:
		var value = entry["items"][key]
		items[key] = value.duplicate() if (value is PackedInt32Array or value is PackedFloat32Array or value is PackedVector3Array) else value
	_tasks.append(WorkerThreadPool.add_task(_plan_task.bind(chunk, _serial, level, items), false, "flora chunk"))


func _plan_task(chunk: Vector2i, serial: int, level: int, items: Dictionary) -> void:
	var plan: Dictionary = _plan(items, level)
	_built_mutex.lock()
	_built.append([chunk, serial, level, plan])
	_built_mutex.unlock()


# Puts finished chunks in the scene a few pieces at a time, for about budget_usec per call
# (always some progress). Call every frame. A chunk keeps its old drawing until the new
# one is complete, so nothing blinks out.
func apply_built(budget_usec: int = 3000) -> void:
	if not _setup_done:
		_setup_step()

	var still: Array = []

	for task in _tasks:
		if WorkerThreadPool.is_task_completed(task):
			WorkerThreadPool.wait_for_task_completion(task)
		else:
			still.append(task)

	_tasks = still

	if _mid_task != -1 and not _mid_ready.is_empty():
		_apply_mid(1)

	_built_mutex.lock()
	var arrived: Array = _built
	_built = []
	_built_mutex.unlock()

	for next in arrived:
		var entry: Dictionary = _chunks.get(next[0], {})

		# Dropped, or asked again since: a newer plan is on its way.
		if not entry.is_empty() and int(entry.get("serial", -1)) == int(next[1]):
			var node: Node3D = Node3D.new()
			node.name = "Chunk_%d_%d" % [next[0].x, next[0].y]
			add_child(node)
			_jobs.append({"chunk": next[0], "serial": next[1], "level": next[2], "plan": next[3], "node": node, "draw": 0, "shape": 0})

	var started: int = Time.get_ticks_usec()

	while not _jobs.is_empty() and Time.get_ticks_usec() - started < budget_usec:
		var job: Dictionary = _jobs[0]
		var entry: Dictionary = _chunks.get(job["chunk"], {})

		if entry.is_empty() or int(entry.get("serial", -1)) != int(job["serial"]):
			_discard(job["node"])
			_jobs.pop_front()
			continue

		if _apply_step(job):
			_clear_node(entry)
			entry["node"] = job["node"]
			job["node"].visible = bool(entry.get("ground", true))
			entry["level"] = job["level"]
			entry.erase("building")
			entry["drawn"] = _drawn_count(job["node"])
			_jobs.pop_front()


# A half-built drawing that is no longer wanted.
func _discard(node: Node3D) -> void:
	for child in node.get_children():
		if child is MultiMeshInstance3D:
			instances -= child.multimesh.instance_count
		elif child is StaticBody3D:
			colliders -= child.get_child_count()

	node.queue_free()


func _exit_tree() -> void:
	finish_tasks()


# Waits for chunk work still running (call before freeing the view).
func finish_tasks() -> void:
	if _models_task_id != -1:
		WorkerThreadPool.wait_for_task_completion(_models_task_id)
		_models_task_id = -1

	for task in _tasks:
		WorkerThreadPool.wait_for_task_completion(task)

	_tasks = []

	if _mid_task != -1:
		WorkerThreadPool.wait_for_task_completion(_mid_task)
		_mid_task = -1


# The drawing of a chunk at a level, as plain data (safe on a worker thread): per group of
# one species, part and model a MultiMesh buffer; trunk colliders; glow lights.
func _plan(items: Dictionary, level: int) -> Dictionary:
	var ids: PackedInt32Array = items["ids"]
	var groups: Dictionary = {}       # [species, part x, part z, variant, near] -> PackedInt32Array of indices
	var shapes: Array = []            # [species, radius, position]
	var lights: Array = []
	# Never past the shortest of the item arrays (they change together; a mismatch must not crash the worker).
	var count: int = mini(mini(ids.size(), items["positions"].size()), mini(items["heights"].size(), items["yaws"].size()))

	for n in range(count):
		var species_id: int = ids[n] >> 16
		var info: Dictionary = _species.get(species_id, {})

		if info.is_empty() or (level & (1 << int(info["kind"]))) == 0:
			continue

		var p: Vector3 = items["positions"][n]
		var part_size: float = float(part_m[info["kind"]])
		var variant: int = (ids[n] * 2654435761 >> 5) % int(info["near"].size())

		if info.has("young_below"):
			# First half of the variants mature, second half young (beech).
			@warning_ignore("integer_division")
			var half: int = int(info["near"].size()) / 2
			variant = variant % half + (half if float(items["heights"][n]) < float(info["young_below"]) else 0)
		var proxy: bool = false
		var is_near: int = 1 if (int(info["kind"]) != KIND_PLANT and (level & (16 << int(info["kind"]))) != 0) else 0

		if int(info["kind"]) == KIND_TREE:
			# The model of this tree's 64 m cell (see _level): far 0, full 1, impostor 2, mid 3.
			var cells: int = int(chunk_m / CELL_M)
			var cx: int = posmod(int(floor(p.x / CELL_M)), cells)
			var cz: int = posmod(int(floor(p.z / CELL_M)), cells)
			is_near = (level >> (32 + 2 * (cz * cells + cx))) & 3

			if is_near == TIER_FULL and ((level >> (PROXY_BIT + cz * cells + cx)) & 1) != 0:
				proxy = true
				is_near = TIER_FULL_LIT

			if is_near == TIER_IMPOSTOR:
				if _impostors.has(species_id):
					variant = 0
				else:
					is_near = TIER_FAR

			# Far trees are small on the screen: one far model per species, so their draws merge (a third of the nodes).
			if is_near == TIER_FAR:
				variant = 0

		var key: Array = [species_id, int(floor(p.x / part_size)), int(floor(p.z / part_size)), variant, is_near]

		if not groups.has(key):
			groups[key] = PackedInt32Array()

		groups[key].append(n)

		if proxy:
			var proxy_key: Array = [species_id, key[1], key[2], variant, TIER_PROXY]

			if not groups.has(proxy_key):
				groups[proxy_key] = PackedInt32Array()

			groups[proxy_key].append(n)

		if (level & 8) != 0 and int(info["kind"]) != KIND_PLANT and float(info["trunk"]) >= 0.1:
			var size_scale: float = float(items["heights"][n]) / float(info["height"])
			shapes.append([species_id, float(info["trunk"]) * size_scale, p + Vector3(0.0, 1.2, 0.0)])

	# Glowing trees (everember, witness tree) light the ground around them, near the player
	# only: one warm light per GLOW_CELL_M square, at most GLOW_LIGHTS per chunk.
	if (level & 8) != 0:
		var lit: Dictionary = {}

		for n in range(count):
			var info: Dictionary = _species.get(ids[n] >> 16, {})

			if not info.has("glow") or lit.size() >= GLOW_LIGHTS:
				continue

			var p: Vector3 = items["positions"][n]
			var cell: Vector2i = Vector2i(int(floor(p.x / GLOW_CELL_M)), int(floor(p.z / GLOW_CELL_M)))

			if lit.has(cell):
				continue

			if float(items["heights"][n]) < float(info.get("young_below", 0.0)):
				continue

			lit[cell] = true
			var size_scale: float = float(items["heights"][n]) / float(info["height"])
			lights.append([info["glow"], float(info["glow_energy"]),
				maxf(8.0 + float(info["trunk"]) * size_scale * 4.0, float(items["heights"][n]) * 0.6),
				p + Vector3(0.0, maxf(2.0, float(items["heights"][n]) * float(info["glow_height"])), 0.0)])

	var draws: Array = []

	for key in groups:
		var info: Dictionary = _species[key[0]]
		var indices: PackedInt32Array = groups[key]
		var tinted: bool = bool(info["tinted"])
		var stride: int = 16 if tinted else 12
		var buffer: PackedFloat32Array = PackedFloat32Array()
		buffer.resize(indices.size() * stride)

		for m in range(indices.size()):
			var n: int = indices[m]
			var size_scale: float = float(items["heights"][n]) / float(info["height"])
			var axes: Basis = Basis(Vector3.UP, float(items["yaws"][n])).scaled(Vector3.ONE * size_scale)
			# Sunk a little so slopes do not show a gap under the trunk.
			var origin: Vector3 = items["positions"][n] - Vector3(0.0, 0.15, 0.0)
			var o: int = m * stride
			buffer[o] = axes.x.x
			buffer[o + 1] = axes.y.x
			buffer[o + 2] = axes.z.x
			buffer[o + 3] = origin.x
			buffer[o + 4] = axes.x.y
			buffer[o + 5] = axes.y.y
			buffer[o + 6] = axes.z.y
			buffer[o + 7] = origin.y
			buffer[o + 8] = axes.x.z
			buffer[o + 9] = axes.y.z
			buffer[o + 10] = axes.z.z
			buffer[o + 11] = origin.z

			if tinted:
				var custom: Color = _autumn_tint(ids[n], info.get("autumn", AUTUMN)) if info["hardwood"] else (_conifer_tint(ids[n], _age_tint(info, float(items["heights"][n]))) if info["kind"] == KIND_TREE else info["tint"])
				# Glowing leaves: young trees glow weakly, grown ones fully.
				custom.a = clampf(float(items["heights"][n]) / float(info.get("young_below", 1.0)), 0.25, 1.0) if info.has("leaf_glow") else 0.0
				buffer[o + 12] = custom.r
				buffer[o + 13] = custom.g
				buffer[o + 14] = custom.b
				buffer[o + 15] = custom.a

		draws.append([key, indices.size(), buffer])

	return {"draws": draws, "shapes": shapes, "lights": lights}


# Adds the next piece of a job's drawing: a batch of trunk colliders (each batch its own
# small body: one body taking a thousand shapes took most of a second), the glow lights, or
# one MultiMesh. Returns true when the drawing is complete.
func _apply_step(job: Dictionary) -> bool:
	var plan: Dictionary = job["plan"]
	var node: Node3D = job["node"]
	var shapes: Array = plan["shapes"]

	if int(job["shape"]) < shapes.size():
		var first: int = int(job["shape"])
		var last: int = mini(first + SHAPES_PER_BODY, shapes.size())
		var body: StaticBody3D = StaticBody3D.new()
		var shape_species: PackedInt32Array = PackedInt32Array()

		for k in range(first, last):
			var item: Array = shapes[k]
			var shape: CollisionShape3D = CollisionShape3D.new()
			shape.shape = _trunk_shape(float(item[1]))
			shape.position = item[2]
			body.add_child(shape)
			shape_species.append(int(item[0]))

		body.set_meta("species_ids", shape_species)
		node.add_child(body)
		colliders += last - first
		job["shape"] = last
		return false

	if int(job["draw"]) == 0:
		for item in plan["lights"]:
			var light: OmniLight3D = OmniLight3D.new()
			light.light_color = item[0]
			light.light_energy = item[1]
			light.omni_range = item[2]
			light.shadow_enabled = false
			light.distance_fade_enabled = true
			light.distance_fade_begin = collision_m * 0.7
			light.distance_fade_length = collision_m * 0.3
			light.position = item[3]
			node.add_child(light)

	var draws: Array = plan["draws"]

	if int(job["draw"]) >= draws.size():
		return true

	var draw_plan: Array = draws[int(job["draw"])]
	job["draw"] = int(job["draw"]) + 1
	var key: Array = draw_plan[0]
	var info: Dictionary = _species[key[0]]
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var proxy_pass: bool = key[4] == TIER_PROXY
	var models: Array = info["near"] if (key[4] == TIER_FULL or key[4] == TIER_FULL_LIT) else (info["mid"] if key[4] == TIER_MID else info["far"])
	multimesh.mesh = _impostors[key[0]]["mesh"] if key[4] == TIER_IMPOSTOR and _impostors.has(key[0]) else models[key[3] % models.size()]
	multimesh.use_custom_data = bool(info["tinted"])
	multimesh.instance_count = int(draw_plan[1])
	multimesh.buffer = draw_plan[2]
	var draw: MultiMeshInstance3D = MultiMeshInstance3D.new()
	draw.multimesh = multimesh
	draw.visibility_range_end = view_m[info["kind"]] + 0.7 * float(part_m[info["kind"]])
	var casts: bool = info["kind"] == KIND_TREE and (key[4] == TIER_FULL or proxy_pass or (key[4] == TIER_FAR and far_shadows))
	draw.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if proxy_pass else (GeometryInstance3D.SHADOW_CASTING_SETTING_ON if casts else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	draw.set_meta("kind", int(info["kind"]))      # for the GPU probe (src/debug/gpu_probe.gd)
	draw.set_meta("casts", casts)
	node.add_child(draw)
	instances += 0 if proxy_pass else int(draw_plan[1])
	return int(job["draw"]) >= draws.size()


# The mid model of each variant: the full model with its triangles cut to about a third by mesh
# simplification (Godot's meshoptimizer, ImporterMesh.generate_lods), done once at startup.
# Variants with few triangles keep the full model.
# Simplified mid models (Godot's meshoptimizer, ImporterMesh.generate_lods, about a third of the
# triangles) for trees, made on a worker thread so the start-up does not wait for them; the
# main thread builds the meshes one or two per frame (apply_built) and swaps them into the
# species. Draws planned before a swap keep the full model, later ones use the mid model.
func _start_mid_task() -> void:
	if _mid_wanted.is_empty() or _mid_task != -1:
		return

	_mid_task = WorkerThreadPool.add_task(_decimate_task.bind(_mid_wanted), false, "flora mid models")
	_mid_wanted = []


func _decimate_task(wanted: Array) -> void:
	for item in wanted:
		var mesh: ArrayMesh = item[2]
		var triangles: int = 0
		var arrays_list: Array = []
		var materials: Array = []

		for surface in range(mesh.get_surface_count()):
			var arrays: Array = mesh.surface_get_arrays(surface)
			@warning_ignore("integer_division")
			triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
			arrays_list.append(arrays)
			materials.append(mesh.surface_get_material(surface))

		if triangles < MID_MIN_TRIANGLES:
			continue

		var importer: ImporterMesh = ImporterMesh.new()

		for surface in range(arrays_list.size()):
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, arrays_list[surface], [], {}, materials[surface], "")

		importer.generate_lods(MID_LOD_SCALE_MIN, 60.0, [])
		var out_arrays: Array = []

		for surface in range(importer.get_surface_count()):
			var arrays: Array = importer.get_surface_arrays(surface)

			if importer.get_surface_lod_count(surface) > 0:
				arrays[Mesh.ARRAY_INDEX] = importer.get_surface_lod_indices(surface, 0)

			out_arrays.append(arrays)

		_built_mutex.lock()
		_mid_ready.append([item[0], item[1], out_arrays, materials])
		_built_mutex.unlock()


func _apply_mid(limit: int) -> void:
	_built_mutex.lock()
	var due: Array = _mid_ready.slice(0, limit)
	_mid_ready = _mid_ready.slice(limit)
	_built_mutex.unlock()

	for item in due:
		var info: Dictionary = _species.get(item[0], {})

		if info.is_empty():
			continue

		var out: ArrayMesh = ArrayMesh.new()

		for surface in range(item[2].size()):
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, item[2][surface])
			out.surface_set_material(surface, item[3][surface])

		info["mid"][item[1]] = out


# One shared trunk shape per radius (to the centimetre).
func _trunk_shape(radius: float) -> CylinderShape3D:
	var key: int = int(round(radius * 100.0))
	var shape: CylinderShape3D = _trunk_shapes.get(key)

	if shape == null:
		shape = CylinderShape3D.new()
		shape.radius = float(key) / 100.0
		shape.height = 3.0
		_trunk_shapes[key] = shape

	return shape


func _clear_node(entry: Dictionary) -> void:
	var node: Node3D = entry.get("node")

	if node == null:
		return

	for child in node.get_children():
		if child is MultiMeshInstance3D:
			instances -= child.multimesh.instance_count
		elif child is StaticBody3D:
			colliders -= child.get_child_count()

	node.queue_free()
	entry["node"] = null


# Draw statistics for the audit and the checks: MultiMesh nodes and instances held, by kind (tree, shrub, plant, in that order),
# and how many nodes hold fewer than 50 instances (the ones a merge would fold together).
func draw_stats() -> Dictionary:
	var nodes: Array = [0, 0, 0]
	var counts: Array = [0, 0, 0]
	var small: int = 0

	for chunk in _chunks:
		var node: Node3D = _chunks[chunk].get("node")

		if node == null:
			continue

		for child in node.get_children():
			if child is MultiMeshInstance3D:
				var kind: int = int(child.get_meta("kind", 0))
				nodes[kind] += 1
				counts[kind] += child.multimesh.instance_count

				if child.multimesh.instance_count < 50:
					small += 1

	return {"nodes": nodes, "instances": counts, "small": small}


static func _drawn_count(node: Node3D) -> int:
	var total: int = 0

	for child in node.get_children():
		if child is MultiMeshInstance3D and child.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY:
			total += child.multimesh.instance_count

	return total


# Distance from the player to the nearest point of a chunk (flat).
func _distance(chunk: Vector2i, from_position: Vector3) -> float:
	var x0: float = float(chunk.x) * chunk_m
	var z0: float = float(chunk.y) * chunk_m
	var dx: float = maxf(maxf(x0 - from_position.x, from_position.x - (x0 + chunk_m)), 0.0)
	var dz: float = maxf(maxf(z0 - from_position.z, from_position.z - (z0 + chunk_m)), 0.0)
	return sqrt(dx * dx + dz * dz)


# One autumn leaf color per hardwood tree, fixed by the tree's id so it
# looks the same for every player and every visit.
func _autumn_color(id: int, palette: Array[Color] = AUTUMN) -> Color:
	var mix: int = (id * 2654435761) & 0x7fffffff
	var base: Color = palette[mix % palette.size()]
	var shade: float = 0.9 + 0.2 * float((mix >> 8) % 100) / 100.0
	return Color(minf(base.r * shade, 1.0), minf(base.g * shade, 1.0), minf(base.b * shade, 1.0))


# The foliage tint for a species: grasses stay near the painted blade color,
# flowers show their bloom color, the rest take the species green.
static func _plant_tint(entry: Dictionary, c: Array) -> Color:
	var base: Color = Color(float(c[0]), float(c[1]), float(c[2]))
	var shape: String = str(entry["shape"])

	if shape == "grass" or shape == "reed":
		return Color(1.0, 1.0, 1.0).lerp(_natural(base) * 2.2, 0.3)

	if shape == "flower":
		return base * 1.9

	return _natural(base) * 1.5


# The leaf tint for a hardwood tree: its autumn color, scaled up because the
# painted leaf texture is light gray and the tint multiplies it. A species
# with its own autumn colors (birch: golden yellow) picks from those.
func _autumn_tint(id: int, palette: Array[Color] = AUTUMN) -> Color:
	var c: Color = _autumn_color(id, palette)
	return Color(c.r * 1.5, c.g * 1.5, c.b * 1.5)


# Species with a young color (balsam fir) are bright when small and darken as
# they grow.
static func _age_tint(info: Dictionary, height: float) -> Color:
	if not info.has("young_tint"):
		return info["tint"]

	var span: Array = info["young_m"]
	var t: float = clampf((height - float(span[0])) / maxf(float(span[1]) - float(span[0]), 0.1), 0.0, 1.0)
	return (info["young_tint"] as Color).lerp(info["tint"], t)


# Evergreens vary tree to tree like a real stand: dark blue-green spruce, mid
# green fir, and the odd bright lime young tree, fixed by the tree's id.
func _conifer_tint(id: int, base: Color) -> Color:
	var mix: int = (id * 2654435761) & 0x7fffffff
	var f: float = float(mix % 1000) / 1000.0
	var dark: Color = Color(0.82, 0.92, 0.86)
	var lime: Color = Color(1.15, 1.35, 0.8)

	if f < 0.1:
		return base * lime

	return base * dark.lerp(Color(1.0, 1.1, 0.95), (f - 0.1) / 0.9)


# Mutes a species color toward natural tones: a little less saturated and
# slightly darker, so greens read as foliage and not as paint.
static func _natural(c: Color) -> Color:
	var grey: float = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	return Color(lerpf(grey, c.r, 0.72) * 0.9, lerpf(grey, c.g, 0.72) * 0.9, lerpf(grey, c.b, 0.72) * 0.9)


# ---------------------------------------------------------------- meshes

# A stand-in mesh for a species at its reference height `h`.
func _make_mesh(entry: Dictionary, h: float) -> ArrayMesh:
	var mesh: ArrayMesh = ArrayMesh.new()
	var color: Array = entry["color"]
	var leaf: StandardMaterial3D = StandardMaterial3D.new()
	leaf.albedo_color = _natural(Color(float(color[0]), float(color[1]), float(color[2])))
	leaf.roughness = 1.0
	var broadleaf: bool = str(entry["shape"]) == "broadleaf"

	if broadleaf:
		# Each tree brings its own leaf color (multimesh instance color).
		leaf.albedo_color = Color.WHITE
		leaf.vertex_color_use_as_albedo = true
	var crown: float = float(entry["crown_m"])
	var trunk: float = maxf(float(entry["trunk_m"]), 0.03)

	match str(entry["shape"]):
		"broadleaf":
			_add(mesh, _cylinder(trunk * 0.7, trunk, h * 0.6, 6), Vector3(0.0, h * 0.3, 0.0), _hardwood_material)
			_add(mesh, _sphere(crown, minf(crown * 1.7, h * 0.75), 8, 5), Vector3(0.0, h - minf(crown * 0.85, h * 0.375), 0.0), leaf)
		"conifer":
			_add(mesh, _cylinder(trunk * 0.5, trunk, h * 0.35, 6), Vector3(0.0, h * 0.175, 0.0), _softwood_material)
			_add(mesh, _cylinder(0.0, crown, h * 0.82, 8), Vector3(0.0, h * 0.59, 0.0), leaf)
		"palm":
			_add(mesh, _cylinder(trunk * 0.8, trunk, h, 6), Vector3(0.0, h * 0.5, 0.0), _trunk_material)
			_add(mesh, _sphere(crown, crown * 0.6, 8, 4), Vector3(0.0, h, 0.0), leaf)
		"cactus":
			_add(mesh, _cylinder(trunk, trunk, h, 8), Vector3(0.0, h * 0.5, 0.0), leaf)
		"shrub":
			_add(mesh, _sphere(crown, h, 7, 4), Vector3(0.0, h * 0.5, 0.0), leaf)
		"mushroom":
			_add(mesh, _cylinder(0.03, 0.04, h * 0.7, 5), Vector3(0.0, h * 0.35, 0.0), _trunk_material)
			_add(mesh, _sphere(crown * 0.5, h * 0.4, 6, 3), Vector3(0.0, h * 0.75, 0.0), leaf)
		"fern":
			_add(mesh, _sphere(crown, h, 6, 3), Vector3(0.0, h * 0.4, 0.0), leaf)
		_:
			# grass, reed, flower: a thin cone tuft.
			_add(mesh, _cylinder(0.0, crown, h, 5), Vector3(0.0, h * 0.5, 0.0), leaf)

	return mesh


static func _cylinder(top: float, bottom: float, height: float, sides: int) -> PrimitiveMesh:
	var cylinder: CylinderMesh = CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = sides
	cylinder.rings = 1
	return cylinder


static func _sphere(radius: float, height: float, sides: int, rings: int) -> PrimitiveMesh:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = radius
	sphere.height = height
	sphere.radial_segments = sides
	sphere.rings = rings
	return sphere


static func _add(mesh: ArrayMesh, part: PrimitiveMesh, offset: Vector3, material: Material) -> void:
	var arrays: Array = part.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]

	for n in range(vertices.size()):
		vertices[n] += offset

	arrays[Mesh.ARRAY_VERTEX] = vertices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, material)
