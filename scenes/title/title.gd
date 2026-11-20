extends Control

# The title page (Kathreen 5 Nov 2026; Dave's approved front-page paintings, art/Art_Direction.md "Reference Paintings"). It opens before character select, once per
# launch and again whenever Esc on the character pages comes back to it. The painted page itself (the story painting, the next one each time, and its four drawn
# buttons) is title_art.gd, shared with the Esc menu in game. Continue is dimmed and does nothing until this machine has a character.
#   New Game: the character creator (a client-only build: Play, the server pick page). Continue: the character select page (a client-only
#   build: straight into the last server as its last character, continue_last). Settings: window, VSync and the keys (the rest stays in the Esc menu in game). Exit: quits.
#   godot --path . res://scenes/title/title.tscn

const Store := preload("res://src/client/character/character_store.gd")
const DisplaySettingsScript := preload("res://src/client/display_settings.gd")
const TitleArt := preload("res://scenes/title/title_art.gd")
const TitleSettings := preload("res://scenes/title/title_settings.gd")
const BuildStamp := preload("res://src/shared/build_stamp.gd")
const GitStamp := preload("res://src/debug/git_stamp.gd")

const CREATOR_SCENE := "res://scenes/creator_proto/creator_proto.tscn"
const SELECT_SCENE := "res://scenes/character_select/character_select.tscn"
const SERVERS_SCENE := "res://scenes/server_pick/server_pick.tscn"
const JoinAddress := preload("res://src/client/join_address.gd")
const ServerList := preload("res://src/client/server_list.gd")

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


# Continue in a client-only build (provisional, Dave's choice 1 in docs/design/SERVER_PICK_PAGE.md): straight into the server played last, as
# the character last played there, with Cancel on the joining screen. With no such server or character, the server pick page instead.
# Returns true when it goes straight in.
func continue_last() -> bool:
	var order: Array = ServerList.sorted(ServerList.load_rows())
	var last: Dictionary = order[0] if not order.is_empty() else {}
	var character: String = str(last.get("last_character", ""))

	if int(last.get("last_played", 0)) <= 0 or character == "" or Store.get_character(character).is_empty():
		get_tree().change_scene_to_file(SERVERS_SCENE)
		return false

	JoinAddress.save(str(last["address"]))
	Store.set_active(character)
	Engine.set_meta("server_picked", str(last["address"]))
	Engine.set_meta("continue_join", true)
	Engine.set_meta("creator_done", true)
	get_tree().change_scene_to_file("res://scenes/launcher.tscn")
	return true


# What each drawn button does. Returns false when it does nothing (Continue with no character).
func press(action: String) -> bool:
	match action:
		"new_game":
			# A client-only build (the testers' game): the painted New Game is Play, which opens the server pick page first
			# (docs/design/SERVER_PICK_PAGE.md); the character page follows the server.
			get_tree().change_scene_to_file(SERVERS_SCENE if JoinAddress.client_only() else CREATOR_SCENE)
		"continue":
			if not art.is_enabled("continue"):
				return false

			if JoinAddress.client_only():
				continue_last()
			else:
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
