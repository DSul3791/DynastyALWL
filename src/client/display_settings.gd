extends RefCounted

# Window and display choices that are saved between runs (owner, 2026-10-20): the 3D
# resolution (16:9 sizes, 1920x1080 the highest), windowed or fullscreen windowed, VSync
# and the quality tier. Esc > Settings changes them; the file is user://display_settings.cfg.
#
# The resolution is the size the 3D picture is drawn at, always exactly that size and 16:9.
# Fullscreen windowed (Godot's Window.MODE_FULLSCREEN: a borderless window the size of the
# screen, not exclusive fullscreen) stretches it to the screen.

# The game is drawn on a fixed 2880x1620 canvas (the project's base size, so the menus and HUD
# keep their layout) that is scaled to the window keeping 16:9, with bars where the window is
# a different shape (Window content scale mode "viewport", aspect "keep"). The 3D picture is
# rendered at a fixed share of that canvas, so 1920x1080 is always 1920x1080 whatever the
# window shape, then scaled to the window with the canvas.
const BASE := Vector2i(2880, 1620)
const PATH := "user://display_settings.cfg"
const SIZES := [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080)]
const DEFAULT_SIZE := 3                  # 1920x1080
const VSYNC_MODES := [DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_DISABLED]
const VSYNC_NAMES := ["on", "adaptive", "off"]

var size_index: int = DEFAULT_SIZE
var fullscreen: bool = false
var vsync_index: int = 0
const TEXT_SCALES := [0.7, 0.85, 1.0, 1.2]
const TEXT_NAMES := ["small", "medium", "large", "extra large"]
const SORT_NAMES := ["Unsorted", "Name", "Weight (ascending)", "Weight (descending)", "Value (ascending)", "Value (descending)"]
var sort_index: int = 0                  # inventory sort: unsorted (order picked up), name, weight, value
var text_index: int = 1                  # size of the crafting and inventory screen's text (default a little smaller)
var quality: int = -1                    # -1: not saved yet (the game's default)


func load_saved() -> void:
	var file: ConfigFile = ConfigFile.new()

	if file.load(PATH) != OK:
		return

	size_index = clampi(int(file.get_value("display", "size", DEFAULT_SIZE)), 0, SIZES.size() - 1)
	fullscreen = bool(file.get_value("display", "fullscreen", false))
	vsync_index = clampi(int(file.get_value("display", "vsync", 0)), 0, VSYNC_MODES.size() - 1)
	quality = int(file.get_value("display", "quality", -1))
	text_index = clampi(int(file.get_value("display", "text", 1)), 0, TEXT_SCALES.size() - 1)
	# Saved choices from before the six-way list: 2 weight and 3 value were highest first; they map to descending.
	var saved_sort: int = int(file.get_value("display", "sort", 0))
	var sort_version: int = int(file.get_value("display", "sort_version", 1))
	sort_index = clampi(saved_sort, 0, SORT_NAMES.size() - 1)

	if sort_version < 2:
		sort_index = {0: 0, 1: 1, 2: 3, 3: 5}.get(saved_sort, 0)


func save() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("display", "size", size_index)
	file.set_value("display", "fullscreen", fullscreen)
	file.set_value("display", "vsync", vsync_index)
	file.set_value("display", "quality", quality)
	file.set_value("display", "text", text_index)
	file.set_value("display", "sort", sort_index)
	file.set_value("display", "sort_version", 2)
	file.save(PATH)


# Back to the first-run choices (the game puts the quality back to High).
func reset() -> void:
	size_index = DEFAULT_SIZE
	fullscreen = false
	vsync_index = 0
	quality = -1
	text_index = 1


# True when the game runs inside the editor's Game tab: the editor owns that window, so a script
# cannot resize it or make it fullscreen (only the 3D picture size can change).
static func embedded() -> bool:
	return Engine.has_method("is_embedded_in_editor") and Engine.is_embedded_in_editor()


# The 3D picture size for a quality tier: the chosen resolution; Low at most 1280x720
# (about 1 megapixel); Ultra a third larger, at most 2560x1440.
func render_size(quality_tier: int) -> Vector2i:
	var width: float = float(size().x)

	if quality_tier <= 0:
		width = minf(width, 1280.0)
	elif quality_tier >= 3:
		width = minf(width * 4.0 / 3.0, 2560.0)

	return Vector2i(roundi(width), roundi(width * 9.0 / 16.0))


func size() -> Vector2i:
	return SIZES[size_index]


func size_text() -> String:
	return "%dx%d" % [size().x, size().y]


# Puts the choices on the window (nothing in a headless run).
func apply(window: Window) -> void:
	if DisplayServer.get_name() == "headless":
		return

	DisplayServer.window_set_vsync_mode(VSYNC_MODES[vsync_index])
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = BASE

	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return

	window.mode = Window.MODE_WINDOWED
	window.size = size()
	# Keep the window on the screen after it grew.
	var screen: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
	window.position = Vector2i(maxi(screen.position.x, screen.position.x + (screen.size.x - window.size.x) / 2), maxi(screen.position.y, screen.position.y + (screen.size.y - window.size.y) / 2))
