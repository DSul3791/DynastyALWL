extends RefCounted

# Window and display choices that are saved between runs (owner, 2026-10-20): the 3D
# resolution (16:9 sizes, 1920x1080 the highest), windowed or fullscreen windowed, VSync
# and the quality tier. Esc > Settings changes them; the file is user://display_settings.cfg.
#
# The resolution is the size the 3D picture is drawn at. Windowed, the window has that size.
# Fullscreen windowed (Godot's Window.MODE_FULLSCREEN: a borderless window the size of the
# screen, not exclusive fullscreen) keeps the 3D picture at that size and stretches it to the
# screen, so a 4K screen still draws 1920x1080 (render_scale.gd caps the 3D scale);
# menus and text are drawn at the screen's own size, so they stay sharp.

const PATH := "user://display_settings.cfg"
const SIZES := [Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080)]
const DEFAULT_SIZE := 3                  # 1920x1080
const VSYNC_MODES := [DisplayServer.VSYNC_ENABLED, DisplayServer.VSYNC_ADAPTIVE, DisplayServer.VSYNC_DISABLED]
const VSYNC_NAMES := ["on", "adaptive", "off"]

var size_index: int = DEFAULT_SIZE
var fullscreen: bool = false
var vsync_index: int = 0
var quality: int = -1                    # -1: not saved yet (the game's default)


func load_saved() -> void:
	var file: ConfigFile = ConfigFile.new()

	if file.load(PATH) != OK:
		return

	size_index = clampi(int(file.get_value("display", "size", DEFAULT_SIZE)), 0, SIZES.size() - 1)
	fullscreen = bool(file.get_value("display", "fullscreen", false))
	vsync_index = clampi(int(file.get_value("display", "vsync", 0)), 0, VSYNC_MODES.size() - 1)
	quality = int(file.get_value("display", "quality", -1))


func save() -> void:
	var file: ConfigFile = ConfigFile.new()
	file.set_value("display", "size", size_index)
	file.set_value("display", "fullscreen", fullscreen)
	file.set_value("display", "vsync", vsync_index)
	file.set_value("display", "quality", quality)
	file.save(PATH)


# Back to the first-run choices (the game puts the quality back to High).
func reset() -> void:
	size_index = DEFAULT_SIZE
	fullscreen = false
	vsync_index = 0
	quality = -1


# True when the game runs inside the editor's Game tab: the editor owns that window, so a script
# cannot resize it or make it fullscreen (only the 3D picture size can change).
static func embedded() -> bool:
	return Engine.has_method("is_embedded_in_editor") and Engine.is_embedded_in_editor()


func size() -> Vector2i:
	return SIZES[size_index]


func size_text() -> String:
	return "%dx%d" % [size().x, size().y]


# Puts the choices on the window (nothing in a headless run).
func apply(window: Window) -> void:
	if DisplayServer.get_name() == "headless":
		return

	DisplayServer.window_set_vsync_mode(VSYNC_MODES[vsync_index])

	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return

	window.mode = Window.MODE_WINDOWED
	window.size = size()
	# Keep the window on the screen after it grew.
	var screen: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
	window.position = Vector2i(maxi(screen.position.x, screen.position.x + (screen.size.x - window.size.x) / 2), maxi(screen.position.y, screen.position.y + (screen.size.y - window.size.y) / 2))
