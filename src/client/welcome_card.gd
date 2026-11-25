extends CanvasLayer

# The welcome card (Dave 25 Nov 2026: "a pop up for first time players or new characters that says the basics like welcome to Dynasty. Press ? to
# enter inspect mode. if you like a cleaner hud you can keep it off. Pressing E to interact or F to open items. other keys can be found in the
# Settings"). Shown once per character on this computer, when that character first lands in the world (terrain_client _arrive_on_ground), and
# closed with Enter or Esc. It takes no clicks, so the mouse stays on the camera, and the game goes on under it. The keys it names are the
# player's own bindings (KeyBindings), never fixed letters. Which characters have seen it: user://welcome_seen.cfg.

const KeyBindings := preload("res://src/client/key_bindings.gd")
const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const SEEN_PATH := "user://welcome_seen.cfg"
const WIDTH_PX := 620.0      # on the 1920 x 1080 canvas
const BOTTOM_GAP_PX := 210.0 # above the hotbar: the HUD stays low, the crosshair stays clear

var showing: bool = false
var seen_path: String = SEEN_PATH

var _panel: PanelContainer
var _text: Label


# The card's words with the player's keys in them.
static func lines() -> Array:
	return [
		"Welcome to Dynasty.",
		"Press %s to use what you look at: gather, pick, drink, open a door, talk. Press %s to open a chest, a fire's store or a station." % [key_text("interact"), key_text("open")],
		"Press %s to turn inspection mode on or off. It names what you look at and shows what %s and %s will do there. Leave it off for a cleaner screen." % [key_text("inspect"), key_text("interact"), key_text("open")],
		"Every other key is in Esc > Settings > Controls.",
		"Press Enter to close.",
	]


# A key as the player sees it on the keyboard: "/" rather than Slash for a printable key, the binding's label (E, Ctrl+Shift+G) otherwise.
static func key_text(id: String) -> String:
	var bind: Dictionary = KeyBindings.binding(id)
	var key: int = int(bind.get("key", KEY_NONE))

	if key > 32 and key < 127 and not (key >= KEY_A and key <= KEY_Z) and not (key >= KEY_0 and key <= KEY_9):
		var mods: String = ("Ctrl+" if bool(bind.get("ctrl", false)) else "") + ("Shift+" if bool(bind.get("shift", false)) else "")
		var shown: String = mods + String.chr(key)
		return shown + " (the key with ? on it)" if key == KEY_SLASH and mods == "" else shown

	return KeyBindings.label(id)


func seen(character_id: String) -> bool:
	var file: ConfigFile = ConfigFile.new()
	return file.load(seen_path) == OK and bool(file.get_value("seen", character_id, false))


func _mark_seen(character_id: String) -> void:
	var file: ConfigFile = ConfigFile.new()
	file.load(seen_path)   # a missing file starts empty
	file.set_value("seen", character_id, true)
	file.save(seen_path)


# Shows the card unless this character has seen it. True when it shows.
func offer(character_id: String) -> bool:
	if character_id == "" or seen(character_id):
		return false

	_mark_seen(character_id)   # once: a quit with the card up does not bring it back
	show_card()
	return true


func show_card() -> void:
	if _panel == null:
		_build()

	_text.text = "\n\n".join(lines())
	visible = true
	showing = true


func close() -> void:
	visible = false
	showing = false


# Enter or Esc closes it (terrain_client asks first, before Esc opens the menu). True when the key was the card's.
func take_key(event: InputEventKey) -> bool:
	if not showing or not event.pressed or event.echo:
		return false

	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_ESCAPE:
		close()
		return true

	return false


func _build() -> void:
	layer = 40
	_panel = PanelContainer.new()
	_panel.name = "WelcomeCard"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", DynastyTheme.panel_style())
	_panel.custom_minimum_size = Vector2(WIDTH_PX, 0.0)
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_panel.offset_left = -WIDTH_PX * 0.5
	_panel.offset_right = WIDTH_PX * 0.5
	_panel.offset_bottom = -BOTTOM_GAP_PX
	add_child(_panel)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("font", DynastyTheme.text_font())
	_text.add_theme_font_size_override("font_size", 20)
	_panel.add_child(_text)
	visible = false
