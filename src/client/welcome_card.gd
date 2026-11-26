extends CanvasLayer

# The welcome card (Dave 25 Nov 2026: "a pop up for first time players or new characters that says the basics like welcome to Dynasty. Press ? to
# enter inspect mode. if you like a cleaner hud you can keep it off. Pressing E to interact or F to open items. other keys can be found in the
# Settings"). Shown once per character on this computer, when that character first lands in the world (terrain_client _arrive_on_ground), and
# closed with Enter or Esc. It takes no clicks, so the mouse stays on the camera, and the game goes on under it. The keys it names are the
# player's own bindings (KeyBindings), never fixed letters. Which characters have seen it: user://welcome_seen.cfg.
#
# The same card tells a returning character that a new play-test build is a new world (R-RELEASE-CLEAN, Dave 25 Nov 2026: "the server is always
# a clean install no keeping backups"; tester, QA #13, build 10587: "had many tools and supplies when logged out, logged in today, completely
# empty"). The character's look lives on this computer and carries over, its pack and buildings do not, and nothing said so. Only on a release
# server (its build stamped): the last build each character played there is kept in the same file.

const KeyBindings := preload("res://src/client/key_bindings.gd")
const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const SettingsRead := preload("res://src/client/settings_read.gd")
const SEEN_PATH := "user://welcome_seen.cfg"
const WIDTH_PX := 620.0      # on the 1920 x 1080 canvas
const PAD_PX := 20.0         # the text's margin inside the border
const BOTTOM_GAP_PX := 210.0 # above the hotbar: the HUD stays low, the crosshair stays clear (about 230 px tall at 18 px: its top near y 640)

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


# The card for a returning character on a new build's world.
static func new_world_lines(build: int) -> Array:
	return [
		"Build %d is a new world." % build,
		"Each new play-test build starts the world fresh: what you carried, built and stored before is gone, so everyone begins again.",
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
	return file.load(seen_path) == OK and SettingsRead.flag(file, "seen", character_id, false)


# Shows the welcome card unless this character has seen it, or the new-world card when a character that has played comes to a release server
# (build > 0: its build stamped) on another build than last time there. True when a card shows.
func offer(character_id: String, server: String = "", build: int = 0) -> bool:
	if character_id == "":
		return false

	var file: ConfigFile = ConfigFile.new()
	file.load(seen_path)   # a missing file starts empty
	var first: bool = not SettingsRead.flag(file, "seen", character_id, false)
	var where: String = "%s_%s" % [character_id, server.md5_text().substr(0, 12)]   # a server name may hold spaces and quotes: never a raw config key
	var last: int = int(file.get_value("build", where, 0))
	file.set_value("seen", character_id, true)   # once: a quit with the card up does not bring it back

	if build > 0:
		file.set_value("build", where, build)

	file.save(seen_path)

	if first:
		show_card()
		return true

	if build > 0 and build != last:
		show_card(new_world_lines(build))
		return true

	return false


func show_card(words: Array = []) -> void:
	if _panel == null:
		_build()

	_text.text = "\n".join(words if not words.is_empty() else lines())
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
	var style: StyleBoxFlat = DynastyTheme.panel_style().duplicate()
	style.content_margin_left = PAD_PX       # the text clear of the border (Lane A 25 Nov 2026: it started a few pixels from the left edge)
	style.content_margin_right = PAD_PX
	style.content_margin_top = PAD_PX * 0.75
	style.content_margin_bottom = PAD_PX * 0.75
	_panel.add_theme_stylebox_override("panel", style)
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
	_text.add_theme_font_size_override("font_size", 18)
	_panel.add_child(_text)
	visible = false
