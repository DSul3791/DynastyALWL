extends Control

# The title page (Kathreen 5 Nov 2026; Dave's approved front-page paintings, art/Art_Direction.md "Reference Paintings"). It opens before character select, once per
# launch and again whenever Esc on the character pages comes back to it. One of Dave's paintings fills the window. They tell a story like a comic book, so each time the
# page opens it shows the next one in story order, remembered between launches (Dave 5 Nov 2026: "rotate the picture because they tell a story"; the dragon battle
# does not fit the story and goes at the end). Each painting
# has the Dynasty logo and four buttons drawn into it (New Game, Continue, Settings, Exit); the page lays an invisible button over each drawn one, so the painting's own
# buttons are used (QA card kathreen-title-buttons, the recommended option). The mouse over one, or the keyboard focus on it, lights it with a warm glow. Continue is
# dimmed and does nothing until this machine has a character.
#   New Game: the character creator. Continue: the character select page. Settings: window, VSync and the keys (the rest stays in the Esc menu in game). Exit: quits.
# 16_Last_Call_at_Inn came without drawn buttons; its copy here has 13_Rogue_Card_Game's buttons laid on in the same place (soft edges), so the story's last page is in.
#   godot --path . res://scenes/title/title.tscn

const Store := preload("res://src/client/character/character_store.gd")
const DisplaySettingsScript := preload("res://src/client/display_settings.gd")
const TitleSettings := preload("res://scenes/title/title_settings.gd")

const CREATOR_SCENE := "res://scenes/creator_proto/creator_proto.tscn"
const SELECT_SCENE := "res://scenes/character_select/character_select.tscn"
const DIR := "res://assets/ui/title/"
const NOTE := "user://title.cfg"         # which painting showed last (its file name), so the next time shows the next page of the story
const IMAGE_SIZE := Vector2(1670.0, 941.0)
const BUTTON_H := 65.0
const ACTIONS := ["new_game", "continue", "settings", "exit"]
# Each painting: its file and where its four drawn buttons are, in the painting's own pixels: the left and right edge (all four share them) and the top of each button,
# in ACTIONS order. Read off the paintings by hand, 5 Nov 2026. In story order: the inn, the dungeon door, the ogre's banquet and the escape, the rest in the forest,
# riding home, the goblins in the market, the card game, the arm wrestling, the wizard's story, last call; then the dragon battle on its own.
const PAINTINGS := [
	{"file": "02_paladin_at_inn.jpg", "x": [1340, 1660], "top": [497, 577, 658, 742]},
	{"file": "03_dungeon_door.jpg", "x": [1302, 1635], "top": [522, 605, 688, 772]},
	{"file": "04_ogre_banquet.jpg", "x": [1305, 1640], "top": [525, 605, 688, 772]},
	{"file": "05_escape_from_banquet.jpg", "x": [1330, 1655], "top": [525, 605, 688, 772]},
	{"file": "07_exhausted_in_forest.jpg", "x": [1305, 1640], "top": [523, 603, 687, 770]},
	{"file": "08_riding_home.jpg", "x": [1305, 1645], "top": [490, 572, 655, 740]},
	{"file": "12_goblin_antics.jpg", "x": [1305, 1635], "top": [525, 605, 688, 772]},
	{"file": "13_rogue_card_game.jpg", "x": [1330, 1660], "top": [493, 575, 657, 740]},
	{"file": "14_dwarf_arm_wrestling.jpg", "x": [1328, 1655], "top": [490, 572, 655, 738]},
	{"file": "15_wizard_storytelling.jpg", "x": [1330, 1662], "top": [493, 575, 657, 740]},
	{"file": "16_last_call_at_inn.jpg", "x": [1330, 1660], "top": [493, 575, 657, 740]},
	{"file": "11_dragon_battle.jpg", "x": [1305, 1640], "top": [525, 605, 688, 772]},
]

var painting: int = -1                    # index into PAINTINGS; tests set it before the page is added
var buttons: Dictionary = {}              # action -> the invisible Button over the drawn one
var _art: TextureRect
var _glows: Dictionary = {}               # action -> the glow Panel
var _dim: ColorRect                       # darkens the drawn Continue while there is no character
var _settings = null
var _fade: ColorRect


# The painting after the one named `last_file`, in story order, back to the first after the last (the first when nothing showed yet, or the name is unknown).
static func next_after(last_file: String) -> int:
	for n in range(PAINTINGS.size()):
		if PAINTINGS[n]["file"] == last_file:
			return (n + 1) % PAINTINGS.size()

	return 0


# Where the drawn button `action` of painting `p` is, in the painting's pixels.
static func button_rect(p: Dictionary, action: String) -> Rect2:
	var n: int = ACTIONS.find(action)
	var x0: float = float(p["x"][0])
	return Rect2(x0, float(p["top"][n]), float(p["x"][1]) - x0, BUTTON_H)


# A rect in the painting's pixels, on a view of size `view` (the painting is stretched to fill it).
static func to_view(r: Rect2, view: Vector2) -> Rect2:
	var s: Vector2 = view / IMAGE_SIZE
	return Rect2(r.position * s, r.size * s)


static func load_painting(file: String) -> Texture2D:
	var path: String = DIR + file

	if ResourceLoader.exists(path):
		return load(path) as Texture2D

	# Not imported yet (a fresh checkout before the editor has seen the file): read the jpg itself.
	var image: Image = Image.new()

	if image.load_jpg_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null

	return ImageTexture.create_from_image(image)


func _ready() -> void:
	Engine.set_meta("title_done", true)
	_apply_saved_display()
	set_anchors_preset(Control.PRESET_FULL_RECT)

	if painting < 0:
		painting = _next_and_note()

	var back: ColorRect = ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	_art = TextureRect.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_SCALE
	_art.texture = load_painting(PAINTINGS[painting]["file"])
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	for action in ACTIONS:
		_add_button(action)

	_dim = ColorRect.new()
	_dim.color = Color(0.0, 0.0, 0.0, 0.55)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)
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
	resized.connect(_layout)
	refresh()
	_layout()
	_first_button().call_deferred("grab_focus")


# Continue is on only when this machine has a character.
func refresh() -> void:
	var can_continue: bool = Store.count() > 0
	buttons["continue"].disabled = not can_continue
	buttons["continue"].focus_mode = Control.FOCUS_ALL if can_continue else Control.FOCUS_NONE
	buttons["continue"].mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if can_continue else Control.CURSOR_ARROW
	_dim.visible = not can_continue
	_update_glows()


func _first_button() -> Button:
	return buttons["continue"] if not buttons["continue"].disabled else buttons["new_game"]


func _add_button(action: String) -> void:
	var glow: Panel = Panel.new()
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.78, 0.4, 0.13)
	style.border_color = Color(1.0, 0.82, 0.45, 0.85)
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(1.0, 0.7, 0.3, 0.55)
	style.shadow_size = 22
	glow.add_theme_stylebox_override("panel", style)
	var add: CanvasItemMaterial = CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.visible = false
	add_child(glow)
	_glows[action] = glow
	var b: Button = Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()

	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(state, empty)

	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			b.grab_focus())
	b.focus_entered.connect(_update_glows)
	b.focus_exited.connect(_update_glows)
	b.pressed.connect(press.bind(action))
	add_child(b)
	buttons[action] = b


func _update_glows() -> void:
	for action in ACTIONS:
		var b: Button = buttons[action]
		_glows[action].visible = b.has_focus() and not b.disabled


func _layout() -> void:
	var p: Dictionary = PAINTINGS[painting]

	for action in ACTIONS:
		var r: Rect2 = to_view(button_rect(p, action), size)
		buttons[action].position = r.position
		buttons[action].size = r.size
		_glows[action].position = r.position
		_glows[action].size = r.size

	var c: Rect2 = to_view(button_rect(p, "continue"), size)
	_dim.position = c.position
	_dim.size = c.size


# What each drawn button does. Returns false when it does nothing (Continue with no character).
func press(action: String) -> bool:
	match action:
		"new_game":
			get_tree().change_scene_to_file(CREATOR_SCENE)
		"continue":
			if buttons["continue"].disabled:
				return false

			get_tree().change_scene_to_file(SELECT_SCENE)
		"settings":
			_settings.open()
			_update_glows()
		"exit":
			get_tree().quit()
		_:
			return false

	return true


func _on_settings_closed() -> void:
	buttons["settings"].grab_focus()


# The next page of the story for this showing, remembered for the next one.
func _next_and_note() -> int:
	var file: ConfigFile = ConfigFile.new()
	file.load(NOTE)
	var n: int = next_after(str(file.get_value("title", "last_file", "")))
	file.set_value("title", "last_file", PAINTINGS[n]["file"])
	file.save(NOTE)
	return n


# The saved window choices (fullscreen, size, VSync) from Esc > Settings > Display, so the title page opens the way the game will look.
func _apply_saved_display() -> void:
	if DisplaySettingsScript.embedded() or not is_inside_tree():
		return

	var display = DisplaySettingsScript.new()
	display.load_saved()
	display.apply(get_window())
