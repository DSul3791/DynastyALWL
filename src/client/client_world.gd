class_name ClientWorld
extends Node3D


const LocalBakedVoxelStreamScript = preload(
	"res://src/client/local_baked_voxel_stream.gd"
)

const BakedWorldConfigScript = preload(
	"res://src/shared/baked_world_config.gd"
)

const BakedVoxelLayoutScript = preload(
	"res://src/shared/baked_voxel_layout.gd"
)


const VIEW_DISTANCE := 1024

const FLY_SPEED := 40.0
const FAST_MULTIPLIER := 4.0
const MOUSE_SENSITIVITY := 0.002

const INITIAL_READY_AREA_SIZE := 128.0
const LOADING_STATUS_UPDATE_INTERVAL := 0.20
const READY_MESSAGE_TIME := 1.0


var _block_store = null
var _voxel_stream = null

var _terrain: VoxelLodTerrain = null
var _player: Node3D = null
var _camera: Camera3D = null
var _viewer: VoxelViewer = null

var _pitch: float = 0.0
var _is_ready: bool = false


# ==================================================
# LOADING UI
# ==================================================

var _loading_layer: CanvasLayer = null
var _loading_panel: PanelContainer = null
var _loading_status_label: Label = null
var _loading_details_label: Label = null
var _loading_progress: ProgressBar = null

var _loading_update_timer: float = 0.0
var _loading_finished: bool = false
var _loading_finish_timer: float = 0.0

var _loading_start_msec: int = 0


# ==================================================
# INITIALIZATION
# ==================================================

func initialize(
	block_store
) -> bool:
	if block_store == null:
		push_error(
			"ClientWorld received a null block store."
		)

		return false


	if not block_store.is_ready():
		push_error(
			"ClientWorld received a block store that is not ready."
		)

		return false


	_block_store = block_store


	_create_loading_overlay()


	if not _create_terrain():
		return false


	_create_player()
	_create_lighting()


	_loading_start_msec = Time.get_ticks_msec()

	_is_ready = true


	print(
		"ClientWorld ready."
	)

	print(
		"Terrain: 7 LODs | View distance: ",
		VIEW_DISTANCE,
		" m"
	)

	print(
		"Fly controls: WASD, Space/Ctrl vertical, Shift fast, mouse look."
	)


	return true


# ==================================================
# LOADING OVERLAY
# ==================================================

func _create_loading_overlay() -> void:
	_loading_layer = CanvasLayer.new()
	_loading_layer.name = "LoadingOverlay"

	add_child(
		_loading_layer
	)


	var center := CenterContainer.new()

	center.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)

	_loading_layer.add_child(
		center
	)


	_loading_panel = PanelContainer.new()

	_loading_panel.custom_minimum_size = Vector2(
		520.0,
		0.0
	)

	center.add_child(
		_loading_panel
	)


	var margin := MarginContainer.new()

	margin.add_theme_constant_override(
		"margin_left",
		24
	)

	margin.add_theme_constant_override(
		"margin_right",
		24
	)

	margin.add_theme_constant_override(
		"margin_top",
		20
	)

	margin.add_theme_constant_override(
		"margin_bottom",
		20
	)

	_loading_panel.add_child(
		margin
	)


	var vertical := VBoxContainer.new()

	vertical.add_theme_constant_override(
		"separation",
		10
	)

	margin.add_child(
		vertical
	)


	var title := Label.new()

	title.text = "Loading World"

	title.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	title.add_theme_font_size_override(
		"font_size",
		24
	)

	vertical.add_child(
		title
	)


	_loading_status_label = Label.new()

	_loading_status_label.text = (
		"Starting terrain streamer..."
	)

	_loading_status_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	vertical.add_child(
		_loading_status_label
	)


	_loading_progress = ProgressBar.new()

	_loading_progress.custom_minimum_size = Vector2(
		0.0,
		28.0
	)

	_loading_progress.indeterminate = true
	_loading_progress.show_percentage = false

	vertical.add_child(
		_loading_progress
	)


	_loading_details_label = Label.new()

	_loading_details_label.text = (
		"Preparing baked voxel data..."
	)

	_loading_details_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	vertical.add_child(
		_loading_details_label
	)


# ==================================================
# TERRAIN
# ==================================================

func _create_terrain() -> bool:
	_voxel_stream = (
		LocalBakedVoxelStreamScript.new()
	)


	if not _voxel_stream.initialize(
		_block_store
	):
		push_error(
			"ClientWorld could not initialize voxel stream."
		)

		return false


	_terrain = VoxelLodTerrain.new()
	_terrain.name = "VoxelLodTerrain"


	# Keep the terrain effectively unbounded.
	# The current 4096 x 4096 baked core is NOT
	# treated as the permanent world bounds.

	_terrain.lod_count = (
		BakedWorldConfigScript.LOD_COUNT
	)

	_terrain.view_distance = (
		VIEW_DISTANCE
	)

	_terrain.mesh_block_size = (
		BakedWorldConfigScript.MESH_BLOCK_SIZE
	)

	_terrain.cache_generated_blocks = false
	_terrain.full_load_mode_enabled = false
	_terrain.generate_collisions = false


	# --------------------------------------------------
	# VOXEL FORMAT
	# --------------------------------------------------

	var voxel_format := VoxelFormat.new()


	voxel_format.set_channel_depth(
		BakedVoxelLayoutScript.CHANNEL_SDF,
		BakedVoxelLayoutScript.SDF_DEPTH
	)

	voxel_format.set_channel_depth(
		BakedVoxelLayoutScript.CHANNEL_GEOLOGY,
		BakedVoxelLayoutScript.GEOLOGY_DEPTH
	)

	voxel_format.set_channel_depth(
		BakedVoxelLayoutScript.CHANNEL_SURFICIAL_DEPOSIT,
		BakedVoxelLayoutScript.SURFICIAL_DEPOSIT_DEPTH
	)

	voxel_format.set_channel_depth(
		BakedVoxelLayoutScript.CHANNEL_RESOURCE,
		BakedVoxelLayoutScript.RESOURCE_DEPTH
	)


	_terrain.format = voxel_format


	# --------------------------------------------------
	# MESHING
	# --------------------------------------------------

	var mesher := VoxelMesherTransvoxel.new()

	_terrain.mesher = mesher


	# --------------------------------------------------
	# STREAM
	# --------------------------------------------------

	_terrain.stream = _voxel_stream


	# --------------------------------------------------
	# TEMPORARY PROCEDURAL TERRAIN MATERIAL
	# --------------------------------------------------

	_terrain.material = (
		_create_debug_terrain_material()
	)


	add_child(
		_terrain
	)


	return true


# ==================================================
# TEMPORARY TERRAIN MATERIAL
# ==================================================

func _create_debug_terrain_material() -> ShaderMaterial:
	var shader := Shader.new()


	shader.code = """
shader_type spatial;

render_mode diffuse_burley, specular_schlick_ggx;

varying vec3 world_pos;
varying vec3 world_normal;


float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);

	return fract(p.x * p.y);
}


float noise2d(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);

	f = f * f * (3.0 - 2.0 * f);

	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));

	return mix(
		mix(a, b, f.x),
		mix(c, d, f.x),
		f.y
	);
}


float triplanar_noise(
	vec3 position,
	vec3 normal,
	float scale
) {
	vec3 blend = abs(normal);

	blend = max(
		blend,
		vec3(0.0001)
	);

	blend /= (
		blend.x
		+ blend.y
		+ blend.z
	);


	float x_noise = noise2d(
		position.yz * scale
	);

	float y_noise = noise2d(
		position.xz * scale
	);

	float z_noise = noise2d(
		position.xy * scale
	);


	return (
		x_noise * blend.x
		+ y_noise * blend.y
		+ z_noise * blend.z
	);
}


void vertex() {
	world_pos = (
		MODEL_MATRIX
		* vec4(
			VERTEX,
			1.0
		)
	).xyz;


	world_normal = normalize(
		(
			MODEL_MATRIX
			* vec4(
				NORMAL,
				0.0
			)
		).xyz
	);
}


void fragment() {
	vec3 n = normalize(
		world_normal
	);


	float slope = (
		1.0
		- abs(n.y)
	);


	float broad_noise = (
		triplanar_noise(
			world_pos,
			n,
			0.045
		)
	);


	float fine_noise = (
		triplanar_noise(
			world_pos,
			n,
			0.30
		)
	);


	// ---------------------------------------------
	// BASIC TEMPORARY TERRAIN PALETTE
	// ---------------------------------------------

	vec3 grass = vec3(
		0.20,
		0.34,
		0.12
	);

	vec3 dry_grass = vec3(
		0.29,
		0.35,
		0.16
	);

	vec3 dirt = vec3(
		0.29,
		0.20,
		0.12
	);

	vec3 rock = vec3(
		0.35,
		0.36,
		0.37
	);

	vec3 deep_rock = vec3(
		0.25,
		0.26,
		0.27
	);

	vec3 lake_bed = vec3(
		0.30,
		0.29,
		0.21
	);


	// ---------------------------------------------
	// FLAT GROUND
	// ---------------------------------------------

	vec3 base = mix(
		grass,
		dry_grass,
		broad_noise
	);


	// ---------------------------------------------
	// DIRT ON MODERATE SLOPES
	// ---------------------------------------------

	float dirt_amount = smoothstep(
		0.18,
		0.42,
		slope
	);


	base = mix(
		base,
		dirt,
		dirt_amount * 0.65
	);


	// ---------------------------------------------
	// ROCK ON STEEP SLOPES
	// ---------------------------------------------

	float rock_amount = smoothstep(
		0.38,
		0.70,
		slope
	);


	base = mix(
		base,
		rock,
		rock_amount
	);


	// ---------------------------------------------
	// BELOW THE MAIN WATER REFERENCE
	//
	// Y = 0 is our approximate primary surface /
	// water reference.
	// ---------------------------------------------

	float below_water = (
		1.0
		- smoothstep(
			-12.0,
			8.0,
			world_pos.y
		)
	);


	base = mix(
		base,
		lake_bed,
		below_water * 0.72
	);


	// Very deep terrain becomes increasingly rocky.

	float deep_amount = (
		1.0
		- smoothstep(
			-500.0,
			-120.0,
			world_pos.y
		)
	);


	base = mix(
		base,
		deep_rock,
		deep_amount * 0.75
	);


	// Preserve cliff rock even underwater.

	base = mix(
		base,
		rock,
		rock_amount * 0.85
	);


	// ---------------------------------------------
	// SMALL-SCALE DETAIL
	//
	// This is deliberately visible enough to give
	// us a sense of meters and movement while flying.
	// ---------------------------------------------

	float detail = (
		(fine_noise - 0.5)
		* 0.18
	);


	base *= (
		1.0 + detail
	);


	// Broader patches reduce the "flat paint" look.

	base *= mix(
		0.90,
		1.08,
		broad_noise
	);


	ALBEDO = base;

	ROUGHNESS = 0.92;

	SPECULAR = 0.18;
}
"""


	var material := ShaderMaterial.new()

	material.shader = shader


	return material


# ==================================================
# PLAYER / VIEWER
# ==================================================

func _create_player() -> void:
	_player = Node3D.new()
	_player.name = "FlyPlayer"

	add_child(
		_player
	)


	_player.position = Vector3(
		0.0,
		20.0,
		0.0
	)


	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	_camera.current = true
	_camera.far = 5000.0

	_player.add_child(
		_camera
	)


	_viewer = VoxelViewer.new()
	_viewer.name = "VoxelViewer"

	_viewer.view_distance = (
		VIEW_DISTANCE
	)

	_viewer.requires_visuals = true
	_viewer.requires_collisions = false

	_player.add_child(
		_viewer
	)


	Input.mouse_mode = (
		Input.MOUSE_MODE_CAPTURED
	)


# ==================================================
# LIGHTING
# ==================================================

func _create_lighting() -> void:
	var light := DirectionalLight3D.new()

	light.name = "Sun"

	light.rotation_degrees = Vector3(
		-55.0,
		-35.0,
		0.0
	)

	light.shadow_enabled = true

	add_child(
		light
	)


	var world_environment := WorldEnvironment.new()

	world_environment.name = "WorldEnvironment"


	var environment := Environment.new()

	environment.background_mode = (
		Environment.BG_COLOR
	)

	environment.background_color = Color(
		0.45,
		0.60,
		0.75
	)

	environment.ambient_light_source = (
		Environment.AMBIENT_SOURCE_COLOR
	)

	environment.ambient_light_color = Color.WHITE

	environment.ambient_light_energy = 0.45


	world_environment.environment = environment

	add_child(
		world_environment
	)


# ==================================================
# PROCESS
# ==================================================

func _process(
	delta: float
) -> void:
	if not _is_ready:
		return


	_update_loading_display(
		delta
	)


	_process_flying(
		delta
	)


# ==================================================
# LOADING STATUS
# ==================================================

func _update_loading_display(
	delta: float
) -> void:
	if _loading_panel == null:
		return


	if not _loading_panel.visible:
		return


	if _loading_finished:
		_loading_finish_timer -= delta


		if _loading_finish_timer <= 0.0:
			_loading_panel.visible = false


		return


	_loading_update_timer += delta


	if (
		_loading_update_timer
		< LOADING_STATUS_UPDATE_INTERVAL
	):
		return


	_loading_update_timer = 0.0


	var data_blocks: int = (
		_terrain.debug_get_data_block_count()
	)


	var mesh_blocks: int = (
		_terrain.debug_get_mesh_block_count()
	)


	var elapsed_seconds: float = (
		float(
			Time.get_ticks_msec()
			- _loading_start_msec
		)
		/ 1000.0
	)


	var half_size: float = (
		INITIAL_READY_AREA_SIZE
		* 0.5
	)


	var ready_area := AABB(
		_player.global_position
		- Vector3(
			half_size,
			half_size,
			half_size
		),

		Vector3(
			INITIAL_READY_AREA_SIZE,
			INITIAL_READY_AREA_SIZE,
			INITIAL_READY_AREA_SIZE
		)
	)


	var area_meshed: bool = (
		_terrain.is_area_meshed(
			ready_area,
			0
		)
	)


	if data_blocks == 0:
		_loading_status_label.text = (
			"Reading baked terrain..."
		)

	elif mesh_blocks == 0:
		_loading_status_label.text = (
			"Decoding voxel blocks..."
		)

	elif not area_meshed:
		_loading_status_label.text = (
			"Building terrain meshes..."
		)

	else:
		_loading_status_label.text = (
			"Terrain ready"
		)


	_loading_details_label.text = (
		"Voxel blocks: %d    Mesh blocks: %d    %.1f sec"
		% [
			data_blocks,
			mesh_blocks,
			elapsed_seconds
		]
	)


	if (
		area_meshed
		and mesh_blocks > 0
	):
		_loading_finished = true
		_loading_finish_timer = READY_MESSAGE_TIME

		_loading_progress.indeterminate = false
		_loading_progress.min_value = 0.0
		_loading_progress.max_value = 100.0
		_loading_progress.value = 100.0
		_loading_progress.show_percentage = true


# ==================================================
# FLYING
# ==================================================

func _process_flying(
	delta: float
) -> void:
	var movement := Vector3.ZERO


	if Input.is_key_pressed(KEY_W):
		movement.z -= 1.0

	if Input.is_key_pressed(KEY_S):
		movement.z += 1.0

	if Input.is_key_pressed(KEY_A):
		movement.x -= 1.0

	if Input.is_key_pressed(KEY_D):
		movement.x += 1.0

	if Input.is_key_pressed(KEY_SPACE):
		movement.y += 1.0

	if Input.is_key_pressed(KEY_CTRL):
		movement.y -= 1.0


	if movement.length_squared() <= 0.0:
		return


	movement = movement.normalized()


	var speed: float = FLY_SPEED


	if Input.is_key_pressed(KEY_SHIFT):
		speed *= FAST_MULTIPLIER


	var horizontal := Vector3(
		movement.x,
		0.0,
		movement.z
	)


	horizontal = (
		_player.global_transform.basis
		* horizontal
	)


	var final_movement := Vector3(
		horizontal.x,
		movement.y,
		horizontal.z
	)


	_player.global_position += (
		final_movement
		* speed
		* delta
	)


# ==================================================
# INPUT
# ==================================================

func _unhandled_input(
	event: InputEvent
) -> void:
	if not _is_ready:
		return


	if (
		event is InputEventMouseMotion
		and Input.mouse_mode
			== Input.MOUSE_MODE_CAPTURED
	):
		_player.rotate_y(
			-event.relative.x
			* MOUSE_SENSITIVITY
		)


		_pitch -= (
			event.relative.y
			* MOUSE_SENSITIVITY
		)

		_pitch = clampf(
			_pitch,
			deg_to_rad(-89.0),
			deg_to_rad(89.0)
		)


		_camera.rotation.x = _pitch


	if (
		event is InputEventKey
		and event.pressed
		and event.keycode == KEY_ESCAPE
	):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
		)


	if (
		event is InputEventMouseButton
		and event.pressed
		and event.button_index
			== MOUSE_BUTTON_LEFT
	):
		Input.mouse_mode = (
			Input.MOUSE_MODE_CAPTURED
		)
