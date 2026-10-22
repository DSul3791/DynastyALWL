extends HBoxContainer

# The row of status symbols on the HUD (owner, 2026-10-20): the brain (inspection mode), a
# ghosted house (under cover), and later cold, wet, hungry, injured and so on. They sit side
# by side and the row stays centred as symbols appear and disappear.
#
# Other threads add a symbol with
#
#   client.status_icons.add_icon("wet", texture, func() -> bool: return is_wet)
#
# The Callable is asked a few times a second, not every frame. Adding the same name again
# replaces that symbol. `StatusIcons.house_texture()` is the white house; `StatusIcons.glyph(...)`
# can draw simple white shapes for placeholders.

const SIZE := 88.0
const CHECK_SEC := 0.25
const MAX_ICONS := 8             # more than this is refused (a warning is printed)
const GHOST := 0.55               # opacity of the symbols that are not the brain

var _icons: Dictionary = {}       # name -> {"node": TextureRect, "active": Callable}
var _order: Array = []
var _since: float = 0.0


func _init() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 14)
	set_anchors_preset(Control.PRESET_TOP_WIDE)
	anchor_top = 0.2
	anchor_bottom = 0.2
	offset_top = -SIZE * 0.5
	offset_bottom = SIZE * 0.5


func add_icon(icon_name: String, texture: Texture2D, active: Callable, opacity: float = GHOST) -> void:
	if not _icons.has(icon_name) and _icons.size() >= MAX_ICONS:
		push_warning("StatusIcons: %d symbols already; '%s' not added" % [MAX_ICONS, icon_name])
		return

	var node: TextureRect = _icons[icon_name]["node"] if _icons.has(icon_name) else TextureRect.new()

	if not _icons.has(icon_name):
		node.custom_minimum_size = Vector2(SIZE, SIZE)
		node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		node.visible = false
		add_child(node)
		_order.append(icon_name)

	node.texture = texture
	node.modulate = Color(1.0, 1.0, 1.0, opacity)
	_icons[icon_name] = {"node": node, "active": active}


func remove_icon(icon_name: String) -> void:
	if _icons.has(icon_name):
		_icons[icon_name]["node"].queue_free()
		_icons.erase(icon_name)
		_order.erase(icon_name)


# Asks every symbol whether it shows (a few times a second); `force` asks at once.
func tick(delta: float, force: bool = false) -> void:
	_since += delta

	if _since < CHECK_SEC and not force:
		return

	_since = 0.0

	for icon_name in _order:
		var entry: Dictionary = _icons[icon_name]
		var node: TextureRect = entry["node"]
		var show_it: bool = bool(entry["active"].call())

		if node.visible != show_it:
			node.visible = show_it


# A white drop: a point on top over a round belly.
static func drop_texture() -> Texture2D:
	var n: int = 128
	var image: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))

	for y in range(n):
		for x in range(n):
			var fx: float = float(x) / float(n) - 0.5
			var fy: float = float(y) / float(n)
			var inside: bool = Vector2(fx, fy - 0.64).length() <= 0.26

			if fy >= 0.1 and fy < 0.64:
				inside = inside or absf(fx) <= (fy - 0.1) / 0.54 * 0.26

			if inside:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))

	return ImageTexture.create_from_image(image)


# A white bubble: a ring with a small highlight (oxygen).
static func bubble_texture() -> Texture2D:
	var n: int = 128
	var image: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))

	for y in range(n):
		for x in range(n):
			var d: float = Vector2(float(x) / float(n) - 0.5, float(y) / float(n) - 0.5).length()
			var hi: float = Vector2(float(x) / float(n) - 0.36, float(y) / float(n) - 0.34).length()

			if (d <= 0.4 and d >= 0.32) or hi <= 0.06:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))

	return ImageTexture.create_from_image(image)


# A white house, soft edged: a roof triangle over a body with a door cut out.
static func house_texture() -> Texture2D:
	var n: int = 128
	var image: Image = Image.create(n, n, false, Image.FORMAT_RGBA8)
	image.fill(Color(1.0, 1.0, 1.0, 0.0))

	for y in range(n):
		for x in range(n):
			var inside: bool = false
			var fx: float = float(x) / float(n)
			var fy: float = float(y) / float(n)

			# Roof: a triangle from (0.08, 0.5) and (0.92, 0.5) up to (0.5, 0.12).
			if fy >= 0.12 and fy <= 0.5:
				var half: float = (fy - 0.12) / (0.5 - 0.12) * 0.42
				inside = absf(fx - 0.5) <= half
			elif fy > 0.5 and fy <= 0.88:
				inside = fx >= 0.2 and fx <= 0.8

				# The door.
				if fx >= 0.42 and fx <= 0.58 and fy >= 0.64:
					inside = false

			if inside:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0))

	return ImageTexture.create_from_image(image)
