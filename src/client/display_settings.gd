extends RefCounted

const SettingsRead := preload("res://src/client/settings_read.gd")

# Window and display choices that are saved between runs (owner, 2026-10-20): the 3D
# resolution (16:9 sizes, 1920x1080 the highest), windowed or fullscreen windowed, VSync
# and the quality tier. Esc > Settings changes them; the file is user://display_settings.cfg.
#
# The resolution is the size the 3D picture is drawn at, always exactly that size and 16:9.
# Fullscreen windowed (Godot's Window.MODE_FULLSCREEN: a borderless window the size of the
# screen, not exclusive fullscreen) stretches it to the screen.

# The game is drawn on a fixed 1920x1080 canvas, the project's UI design size (Dave, 9 Nov 2026:
# chosen so the game plays on older, smaller machines; 1366x768 is the supported floor). Every
# menu and HUD size is a pixel on this canvas. The canvas is scaled to the window keeping 16:9,
# with bars where the window is a different shape (Window content scale mode "viewport", aspect
# "keep"). The 3D picture is rendered at a fixed share of that canvas, so 1920x1080 is always
# 1920x1080 whatever the window shape (Ultra draws a third more and scales down), then scaled to
# the window with the canvas.
const BASE := Vector2i(1920, 1080)
const PATH := "user://display_settings.cfg"
var path: String = PATH                   # tests point this at their own file
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
var hud_text: bool = true                # F4: the text overlay (build, position, debug lines) shown or hidden
var idle_minutes: int = 60               # Esc > Settings > Display, Idle timeout: minutes without input before the game warns and then closes (60 to 120, idle_timeout.gd)
var damage_numbers: bool = true         # Esc > Settings > Gameplay, Damage numbers: floating text where a hit lands (Dave 2 Nov 2026, on by default)
static var fahrenheit: bool = false      # Esc > Settings > Gameplay, Temperature: show body temperature in C or F (Dave 2 Nov 2026, saved; static so every screen reads it)
static var reduce_motion: bool = false   # Esc > Settings > Gameplay, Reduce motion: the inventory's eases, fly-to-slot and shimmer become instant (look doc section 11; static so every slot reads it)
var mouse_look: float = 1.0              # Esc > Settings > Gameplay, Mouse sensitivity: times the base turn rate (MOUSE_LOOK_MIN to MOUSE_LOOK_MAX)
const MOUSE_LOOK_MIN := 0.1
const MOUSE_LOOK_MAX := 3.0
var fitted: Vector2i = Vector2i.ZERO      # the window size apply() last asked for (the chosen size, or smaller to fit the screen)
var cave_dark: bool = true               # Esc > Settings, Cave darkness: Dark (pitch black under rock without a light) or Normal (12%)
var quality: int = -1                    # -1: not saved yet (the game's default)


func load_saved() -> void:
	var file: ConfigFile = ConfigFile.new()

	if file.load(path) != OK:
		return

	size_index = clampi(SettingsRead.whole(file, "display", "size", DEFAULT_SIZE), 0, SIZES.size() - 1)
	fullscreen = SettingsRead.flag(file, "display", "fullscreen", false)
	vsync_index = clampi(SettingsRead.whole(file, "display", "vsync", 0), 0, VSYNC_MODES.size() - 1)
	quality = SettingsRead.whole(file, "display", "quality", -1)
	text_index = clampi(SettingsRead.whole(file, "display", "text", 1), 0, TEXT_SCALES.size() - 1)
	hud_text = SettingsRead.flag(file, "display", "hud_text", true)
	cave_dark = SettingsRead.flag(file, "display", "cave_dark", true)
	damage_numbers = SettingsRead.flag(file, "display", "damage_numbers", true)
	idle_minutes = clampi(SettingsRead.whole(file, "display", "idle_minutes", 60), 60, 120)
	fahrenheit = SettingsRead.flag(file, "display", "fahrenheit", false)
	reduce_motion = SettingsRead.flag(file, "display", "reduce_motion", false)
	mouse_look = clampf(SettingsRead.number(file, "display", "mouse_look", 1.0), MOUSE_LOOK_MIN, MOUSE_LOOK_MAX)
	# Saved choices from before the six-way list: 2 weight and 3 value were highest first; they map to descending.
	var saved_sort: int = SettingsRead.whole(file, "display", "sort", 0)
	var sort_version: int = SettingsRead.whole(file, "display", "sort_version", 1)
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
	file.set_value("display", "hud_text", hud_text)
	file.set_value("display", "idle_minutes", clampi(idle_minutes, 60, 120))
	file.set_value("display", "cave_dark", cave_dark)
	file.set_value("display", "damage_numbers", damage_numbers)
	file.set_value("display", "fahrenheit", fahrenheit)
	file.set_value("display", "reduce_motion", reduce_motion)
	file.set_value("display", "mouse_look", clampf(mouse_look, MOUSE_LOOK_MIN, MOUSE_LOOK_MAX))
	file.set_value("display", "sort", sort_index)
	file.set_value("display", "sort_version", 2)
	file.save(path)


# Body temperature for the Temperature readout: warmth 100% is a healthy 37 C, 0% is 28 C (deep hypothermia), straight between.
static func body_temp_c(warmth_percent: float) -> float:
	return 28.0 + 9.0 * clampf(warmth_percent, 0.0, 100.0) / 100.0


static func temp_text(warmth_percent: float) -> String:
	var c: float = body_temp_c(warmth_percent)
	if fahrenheit:
		return "%.1f °F" % (c * 9.0 / 5.0 + 32.0)
	return "%.1f °C" % c


static func air_text(air_c: float) -> String:
	if fahrenheit:
		return "%.0f °F" % (air_c * 9.0 / 5.0 + 32.0)
	return "%.0f °C" % air_c


# What apply(keep_current) does with the window's present mode: MODE_FULLSCREEN when the player has it fullscreen (either kind), MODE_MAXIMIZED
# when maximised and the saved choice is windowed, else -1 (the saved choice is applied as usual).
static func keep_mode(current: int, saved_fullscreen: bool) -> int:
	if current == Window.MODE_FULLSCREEN or current == Window.MODE_EXCLUSIVE_FULLSCREEN:
		return Window.MODE_FULLSCREEN

	if current == Window.MODE_MAXIMIZED and not saved_fullscreen:
		return Window.MODE_MAXIMIZED

	return -1


# Back to the first-run choices (the game puts the quality back to High).
func reset() -> void:
	size_index = DEFAULT_SIZE
	fullscreen = false
	vsync_index = 0
	quality = -1
	text_index = 1
	cave_dark = true
	damage_numbers = true
	idle_minutes = 60
	reduce_motion = false


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


# The windowed size for `want` on a screen whose usable area is `room`: `want`, or the biggest 16:9 size inside `room` when it does not fit.
static func fit_window(want: Vector2i, room: Vector2i) -> Vector2i:
	if room.x <= 0 or room.y <= 0 or (want.x <= room.x and want.y <= room.y):
		return want

	if room.x * want.y <= room.y * want.x:   # the width limits: whole numbers, so the limiting side is exactly the room
		@warning_ignore("integer_division")
		return Vector2i(room.x, maxi(room.x * want.y / want.x, 1))

	@warning_ignore("integer_division")
	return Vector2i(maxi(room.y * want.x / want.y, 1), room.y)


func size() -> Vector2i:
	return SIZES[size_index]


func size_text() -> String:
	return "%dx%d" % [size().x, size().y]


# Puts the choices on the window (nothing in a headless run). keep_current (joining a world, opening the title page): a window the player
# made larger themselves (maximised, or fullscreen from the title bar or the keyboard) stays as it is (Dave 23 Nov 2026: he went fullscreen
# before joining and the join shrank the window; "we need consistency"); a fullscreen one is saved as the Fullscreen choice. The Settings
# switches pass false, so turning Fullscreen off still makes a window.
func apply(window: Window, keep_current: bool = false) -> void:
	if DisplayServer.get_name() == "headless":
		return

	var mode: int = keep_mode(window.mode, fullscreen) if keep_current else -1

	if mode == Window.MODE_FULLSCREEN and not fullscreen:
		fullscreen = true
		save()

	DisplayServer.window_set_vsync_mode(VSYNC_MODES[vsync_index])
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_size = BASE

	if mode == Window.MODE_MAXIMIZED:
		return   # maximised by the player: left so

	if fullscreen:
		window.mode = Window.MODE_FULLSCREEN
		return

	window.mode = Window.MODE_WINDOWED
	# A window never larger than the screen's usable area (the 1366x768 floor with the 1920x1080 default would hang off the screen): the
	# chosen size, else the biggest 16:9 size that fits. The 3D picture keeps the chosen size (render_size) and is scaled to it.
	var decor: Vector2i = window.get_size_with_decorations() - window.size   # the title bar and borders: the usable area holds them too
	fitted = fit_window(size(), DisplayServer.screen_get_usable_rect(window.current_screen).size - decor)
	window.size = fitted
	# Keep the window on the screen after it grew.
	var screen: Rect2i = DisplayServer.screen_get_usable_rect(window.current_screen)
	var outer: Vector2i = window.size + decor
	var title: Vector2i = window.position - window.get_position_with_decorations()   # the client area's offset inside the frame (title bar, border)
	@warning_ignore("integer_division")
	window.position = title + Vector2i(maxi(screen.position.x, screen.position.x + (screen.size.x - outer.x) / 2), maxi(screen.position.y, screen.position.y + (screen.size.y - outer.y) / 2))
