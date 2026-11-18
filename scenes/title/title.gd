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
const BuildStamp := preload("res://src/shared/build_stamp.gd")
const GitStamp := preload("res://src/debug/git_stamp.gd")

const CREATOR_SCENE := "res://scenes/creator_proto/creator_proto.tscn"
const SELECT_SCENE := "res://scenes/character_select/character_select.tscn"

var painting: int = -1                    # index into TitleArt.PAINTINGS; tests set it before the page is added
var art: Control                          # the painted page (title_art.gd)
var _settings = null
var _fade: ColorRect
var build_label: Label                    # bottom right: the build this copy runs (step A1), so a tester can name it in a report


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
	build_label = Label.new()
	build_label.text = build_text()
	build_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 16)
	build_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	build_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	build_label.add_theme_font_size_override("font_size", 18)
	build_label.add_theme_constant_override("outline_size", 4)
	build_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	build_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(build_label)
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)
	create_tween().tween_property(_fade, "color:a", 0.0, 0.6)
	refresh()
	art.focus_first(["continue", "new_game"])


# "Build 412" for a release; an editor run adds its commit ("Build 826 (6dedf7f)"), as the HUD does.
static func build_text() -> String:
	if BuildStamp.stamped_build() > 0:
		return "Build %d" % BuildStamp.number()

	var commit: String = GitStamp.short_commit()
	return "Build %d (%s)" % [BuildStamp.number(), commit] if commit != "" else "Build %d" % BuildStamp.number()


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
