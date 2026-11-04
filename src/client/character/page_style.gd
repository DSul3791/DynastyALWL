extends RefCounted

# The look shared by the character select page and the creator: one theme with big fonts (readable at 1920x1080) and big coloured buttons.

const FONT_BASE := 22          # labels, values, text boxes
const FONT_SECTION := 28       # section headers and list rows
const FONT_BUTTON := 24        # the big buttons
const FONT_TITLE := 30         # page titles and the primary button

const PRIMARY := Color(0.2, 0.55, 0.28)
const NEUTRAL := Color(0.3, 0.32, 0.38)
const ACCENT := Color(0.36, 0.3, 0.52)
const DANGER := Color(0.6, 0.25, 0.22)
const BACKGROUND := Color(0.13, 0.14, 0.16)


static func make_theme() -> Theme:
	var t: Theme = Theme.new()
	t.default_font_size = FONT_BASE

	for type_name in ["Label", "Button", "CheckBox", "LineEdit", "ColorPickerButton"]:
		t.set_font_size("font_size", type_name, FONT_BASE)

	t.set_constant("icon_max_width", "CheckBox", 24)

	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = Color(0.3, 0.33, 0.4).lightened(0.12 if state == "hover" else 0.0).darkened(0.15 if state == "pressed" else (0.4 if state == "disabled" else 0.0))
		box.set_corner_radius_all(6)
		box.content_margin_left = 14.0
		box.content_margin_right = 14.0
		box.content_margin_top = 6.0
		box.content_margin_bottom = 6.0
		t.set_stylebox(state, "Button", box)

	var grabber: StyleBoxFlat = StyleBoxFlat.new()
	grabber.bg_color = Color(0.3, 0.32, 0.36)
	grabber.set_corner_radius_all(6)
	grabber.content_margin_top = 14.0
	grabber.content_margin_bottom = 14.0
	t.set_stylebox("slider", "HSlider", grabber)
	return t


static func big_button(text: String, size: int, tint: Color) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", size)
	style_button(b, tint)
	return b


static func style_button(b: Button, tint: Color) -> void:
	for state in ["normal", "hover", "pressed", "disabled"]:
		var box: StyleBoxFlat = StyleBoxFlat.new()
		box.bg_color = tint.lightened(0.12) if state == "hover" else (tint.darkened(0.15) if state == "pressed" else (tint.darkened(0.45) if state == "disabled" else tint))
		box.set_corner_radius_all(8)
		box.content_margin_left = 18.0
		box.content_margin_right = 18.0
		b.add_theme_stylebox_override(state, box)


# A full-window page: a dark background and a margin around the content. Returns the box to put the page's rows in.
static func page(root: Control) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = make_theme()
	var back: ColorRect = ColorRect.new()
	back.color = BACKGROUND
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(back)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)

	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)

	root.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	return box


# The body preview's little world, shared by the creator and the character select pictures (Kathreen 3 Nov 2026; Dave's art direction: warm inviting sunlight, rich natural
# colour, not a grey studio). A soft sky from a warm horizon up to blue, a warm low sun with a cool fill from the other side so the form reads, and a patch of grassy ground
# under the feet so the body stands somewhere instead of floating on a flat colour.
static func add_preview_world(view: Node) -> void:
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.36, 0.52, 0.72)
	sky_material.sky_horizon_color = Color(0.86, 0.74, 0.58)
	sky_material.ground_horizon_color = Color(0.5, 0.45, 0.36)
	sky_material.ground_bottom_color = Color(0.22, 0.2, 0.16)
	var sky: Sky = Sky.new()
	sky.sky_material = sky_material
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	view.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-32.0, -35.0, 0.0)
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	view.add_child(sun)
	var fill: DirectionalLight3D = DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 150.0, 0.0)
	fill.light_color = Color(0.62, 0.72, 0.9)
	fill.light_energy = 0.35
	view.add_child(fill)
	var ground: MeshInstance3D = MeshInstance3D.new()
	var disc: CylinderMesh = CylinderMesh.new()
	disc.top_radius = 1.6
	disc.bottom_radius = 1.6
	disc.height = 0.02
	disc.radial_segments = 48
	var soil: StandardMaterial3D = StandardMaterial3D.new()
	soil.albedo_color = Color(0.3, 0.4, 0.2)
	soil.roughness = 1.0
	disc.material = soil
	ground.mesh = disc
	ground.position = Vector3(0.0, -0.01, 0.0)
	view.add_child(ground)
