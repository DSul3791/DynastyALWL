extends RefCounted
# Firelight in fog, rain and snow (docs/design/firelight_weather_design.md, Jamie #645; always on since Dave's 8 Nov ruling). Client only.
# Every fire light (the held torch, campfires, forges and hearths) registers here: it keeps its base range as metadata and joins the
# group "fire_light". weather_look.gd calls update() once a second with the weather at the eye; it sets each light's reach and the
# shared halo (one mesh and one material, so one update moves every halo).

const GROUP := "fire_light"
const REACH_MIN := 0.4
const REACH_MAX := 1.8
const FOG_CUT := 0.5          # dense fog halves the reach (Jamie: about -50 %)
const SNOW_FALL_CUT := 0.2    # heavy falling snow (about -20 %)
const SNOW_LYING_GAIN := 0.6  # fresh lying snow throws the light back (1.5 to 2 times)
const HALO_ALPHA := 0.35
const HALO_SNOW := 0.6        # heavy snow's share of the halo, for the sphere of lit flakes

static var _halo_mesh: QuadMesh
static var _halo_material: StandardMaterial3D
static var _lights: Array = []          # every registered fire light: kept here as well as in the group, so a light not yet in a tree is still moved


# How far a fire light reaches, as a share of its base range.
static func reach(veil: float, heavy: float, ground_snow: float) -> float:
	var r: float = (1.0 - FOG_CUT * clampf(veil, 0.0, 1.0)) * (1.0 - SNOW_FALL_CUT * clampf(heavy, 0.0, 1.0)) * (1.0 + SNOW_LYING_GAIN * clampf(ground_snow, 0.0, 1.0))
	return clampf(r, REACH_MIN, REACH_MAX)


static func halo_strength(veil: float, heavy: float) -> float:
	return maxf(clampf(veil, 0.0, 1.0), HALO_SNOW * clampf(heavy, 0.0, 1.0))


# The torch halo's diameter in metres: 1.5 m in a light fog, 5 m in a dense one.
static func halo_diameter(strength: float) -> float:
	return lerpf(1.5, 5.0, smoothstep(0.2, 1.0, strength))


static func halo_alpha(strength: float, daylight: float) -> float:
	return HALO_ALPHA * smoothstep(0.1, 0.4, strength) * (1.0 - 0.8 * clampf(daylight, 0.0, 1.0))


# Falling snow from 0.5 up counts as heavy.
static func heavy_snow(snow: float) -> float:
	return smoothstep(0.5, 1.0, snow)


# Called where a fire light is made. halo_scale: 1 for a torch, larger for a big fire.
static func register(light: OmniLight3D, halo_scale: float = 1.0) -> void:
	if light == null:
		return

	light.set_meta("base_range", light.omni_range)
	light.add_to_group(GROUP)
	_lights.append(light)
	var halo: MeshInstance3D = MeshInstance3D.new()
	halo.name = "Halo"
	halo.mesh = _shared_mesh()
	halo.material_override = _shared_material()
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.scale = Vector3.ONE * halo_scale
	halo.layers = 2                    # like the torch's own meshes: its lights (cull mask without layer 2) do not light it
	light.add_child(halo)


static func _shared_mesh() -> QuadMesh:
	if _halo_mesh == null:
		_halo_mesh = QuadMesh.new()
		_halo_mesh.size = Vector2.ONE * halo_diameter(0.0)

	return _halo_mesh


static func _shared_material() -> StandardMaterial3D:
	if _halo_material == null:
		var gradient: Gradient = Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.45, 0.8, 1.0])
		gradient.colors = PackedColorArray([Color(1.0, 0.85, 0.6, 1.0), Color(1.0, 0.55, 0.25, 0.5), Color(0.8, 0.3, 0.1, 0.15), Color(0.8, 0.3, 0.1, 0.0)])
		var texture: GradientTexture2D = GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 128
		texture.height = 128
		_halo_material = StandardMaterial3D.new()
		_halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_halo_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		_halo_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		_halo_material.proximity_fade_enabled = true
		_halo_material.proximity_fade_distance = 1.0
		_halo_material.albedo_texture = texture
		_halo_material.albedo_color = Color(1.0, 1.0, 1.0, 0.0)

	return _halo_material


# Once a second from weather_look.gd: veil = mist x mist_inside, snow = eased falling snow (0..1), ground_snow = the ground's
# snow memory, daylight 0 night .. 1 day.
static func update(tree: SceneTree, veil: float, snow: float, ground_snow: float, daylight: float) -> void:
	if tree == null:
		return

	var heavy: float = heavy_snow(snow)
	var r: float = reach(veil, heavy, ground_snow)

	_lights = _lights.filter(func(item): return is_instance_valid(item))

	for node in _lights:
		var light: OmniLight3D = node as OmniLight3D

		if light != null and light.has_meta("base_range"):
			light.omni_range = float(light.get_meta("base_range")) * r

	var strength: float = halo_strength(veil, heavy)
	_shared_mesh().size = Vector2.ONE * halo_diameter(strength)
	var material: StandardMaterial3D = _shared_material()
	material.albedo_color = Color(1.0, 1.0, 1.0, halo_alpha(strength, daylight))
