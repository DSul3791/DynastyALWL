extends Control

# The title page (Kathreen 5 Nov 2026; Dave's approved front-page paintings, art/Art_Direction.md "Reference Paintings"). It opens before character select, once per
# launch and again whenever Esc on the character pages comes back to it. The painted page itself (the story painting, the next one each time, and its four drawn
# buttons) is title_art.gd, shared with the Esc menu in game. Continue is dimmed and does nothing until this machine has a character.
#   New Game: the character creator. Continue: the character select page. Settings: window, VSync and the keys (the rest stays in the Esc menu in game). Exit: quits.
#   godot --path . res://scenes/title/title.tscn

const Store := preload("res://src/client/character/character_store.gd")
const DisplaySettingsScript := preload("res://src/client/display_settings.gd")
const TitleArt := preload("res://scenes/title/title_art.gd")
const TitleSettings := preload("res://scenes/title/title_settings.gd")

const CREATOR_SCENE := "res://scenes/creator_proto/creator_proto.tscn"
const SELECT_SCENE := "res://scenes/character_select/character_select.tscn"

var painting: int = -1                    # index into TitleArt.PAINTINGS; tests set it before the page is added
var art: Control                          # the painted page (title_art.gd)
var _settings = null
var _fade: ColorRect


func _ready() -> void:
	Engine.set_meta("title_done", true)
	_apply_saved_display()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	if painting < 0:
		painting = TitleArt.advance()

	art = TitleArt.new()
	art.chosen.connect(press)
	add_child(art)
	art.show_painting(painting)
	_settings = TitleSettings.new()
	_settings.closed.connect(_on_settings_closed)
	add_child(_settings)
	_settings.visible = false
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.6)
	refresh()
	art.focus_first(["continue", "new_game"])


# Continue is on only when this machine has a character.
func refresh() -> void:
	art.set_enabled("continue", Store.count() > 0)


# What each drawn button does. Returns false when it does nothing (Continue with no character).
func press(action: String) -> bool:
	match action:
		"new_game":
			get_tree().change_scene_to_file(CREATOR_SCENE)
		"continue":
			if not art.is_enabled("continue"):
				return false

			get_tree().change_scene_to_file(SELECT_SCENE)
		"settings":
			_settings.open()
		"exit":
			get_tree().quit()
		_:
			return false

	return true


func _on_settings_closed() -> void:
	art.buttons["settings"].grab_focus()


# The saved window choices (fullscreen, size, VSync) from Esc > Settings > Display, so the title page opens the way the game will look.
func _apply_saved_display() -> void:
	if DisplaySettingsScript.embedded() or not is_inside_tree():
		return

	var display = DisplaySettingsScript.new()
	display.load_saved()
	display.apply(get_window())
