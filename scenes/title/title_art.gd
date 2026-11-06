extends Control

# One of Dave's story paintings filling its rect, with an invisible button over each of the four buttons drawn into it (New Game, Continue, Settings, Exit). The mouse
# over one, or the keyboard focus on it, lights it with a warm glow; a button turned off is dimmed and does nothing. Used by the title page (scenes/title/title.gd) and
# by the Esc menu in game (src/client/game_menu.gd), so both are the same painted page (Dave 6 Nov 2026: "when I press escape ... I want it to go to the new opening page").
# The paintings tell a story like a comic book (Dave 5 Nov 2026): each showing takes the next one in story order, remembered between launches (advance()).

signal chosen(action: String)

const DIR := "res://assets/ui/title/"
const NOTE := "user://title.cfg"         # which painting showed last (its file name), so the next time shows the next page of the story
const IMAGE_SIZE := Vector2(1670.0, 941.0)
const BUTTON_H := 65.0
const ACTIONS := ["new_game", "continue", "settings", "exit"]
# Each painting: its file and where its four drawn buttons are, in the painting's own pixels: the left and right edge (all four share them) and the top of each button,
# in ACTIONS order. Read off the paintings by hand, 5 Nov 2026. In story order: the inn, the dungeon door, the ogre's banquet and the escape, the rest in the forest,
# riding home, the goblins in the market, the card game, the arm wrestling, the wizard's story, last call; then the dragon battle on its own.
# 16 came without drawn buttons; its copy here has 13's buttons laid on in the same place (soft edges).
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

var painting: int = 0
var buttons: Dictionary = {}              # action -> the invisible Button over the drawn one
var texture_rect: TextureRect
var _glows: Dictionary = {}               # action -> the glow Panel
var _dims: Dictionary = {}                # action -> the shade over a drawn button that is turned off


# The painting after the one named `last_file`, in story order, back to the first after the last (the first when nothing showed yet, or the name is unknown).
static func next_after(last_file: String) -> int:
	for n in range(PAINTINGS.size()):
		if PAINTINGS[n]["file"] == last_file:
			return (n + 1) % PAINTINGS.size()

	return 0


# The next page of the story for this showing, remembered (user://title.cfg) for the next one.
static func advance() -> int:
	var file: ConfigFile = ConfigFile.new()
	file.load(NOTE)
	var n: int = next_after(str(file.get_value("title", "last_file", "")))
	file.set_value("title", "last_file", PAINTINGS[n]["file"])
	file.save(NOTE)
	return n


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


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var back: ColorRect = ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	texture_rect = TextureRect.new()
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(texture_rect)

	for action in ACTIONS:
		_add_button(action)

	for action in ACTIONS:
		var dim: ColorRect = ColorRect.new()
		dim.color = Color(0.0, 0.0, 0.0, 0.55)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		dim.visible = false
		add_child(dim)
		_dims[action] = dim

	resized.connect(_layout)


func show_painting(n: int) -> void:
	painting = clampi(n, 0, PAINTINGS.size() - 1)
	texture_rect.texture = load_painting(PAINTINGS[painting]["file"])
	_layout()


func set_enabled(action: String, on: bool) -> void:
	var b: Button = buttons[action]
	b.disabled = not on
	b.focus_mode = Control.FOCUS_ALL if on else Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if on else Control.CURSOR_ARROW
	_dims[action].visible = not on
	_update_glows()


func is_enabled(action: String) -> bool:
	return not buttons[action].disabled


# Puts the keyboard focus on the first button that is on, from `order`.
func focus_first(order: Array) -> void:
	for action in order:
		if is_enabled(action):
			_grab.call_deferred(buttons[action])
			return


func _grab(b: Button) -> void:
	if b.is_visible_in_tree():
		b.grab_focus()


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
	b.pressed.connect(func() -> void: chosen.emit(action))
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

		for c in [buttons[action], _glows[action], _dims[action]]:
			c.position = r.position
			c.size = r.size
