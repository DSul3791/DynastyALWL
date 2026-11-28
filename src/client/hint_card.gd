extends CanvasLayer

# The hint card (Dave 28 Nov 2026, R-HUD-HINT-BOX: "if you want a real hint to come up on the screen, and if it's at the right time, it should
# come up in a box where you have to click OK"). A guide hint (data/items/hints.json: one with a `goal`, or one of BOX_IDS) and a "Goal done ... Next:"
# line come up here instead of the passing line under the crosshair, and stay until OK is clicked or Enter is pressed. The game never pauses
# (multiplayer): a card waits in the queue until the player is safe (terrain_client _hint_safe: no screen or menu up, no animal attacking near,
# not hurt lately, not swimming or fainting, no mouse button held), and a card up when danger comes is put back and the mouse handed back at once.
# One card at a time, each line once per run: the server says a hint once per character, and the once-more it says for a goal still open after
# 5 minutes (server_items.gd _hints_check) is not shown again. Low on the screen like the welcome card.

const KeyBindings := preload("res://src/client/key_bindings.gd")
const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const HINTS_PATH := "res://data/items/hints.json"
const BOX_IDS := ["hotbar", "kit", "place_fire", "roof_panel"]   # steps of the guide with no goal of their own: using the axe, the campfire, the roof
const WIDTH_PX := 620.0
const PAD_PX := 20.0
const BOTTOM_GAP_PX := 210.0   # above the hotbar, as the welcome card
const GAP_MS := 1500           # between one card's OK and the next card

var queue: Array = []          # raw lines waiting their turn
var showing: String = ""       # the raw line on the card now, "" none
var mouse_free: bool = true    # false in the headless tests: the card never touches the mouse mode

var _box_texts: Dictionary = {}
var _said: Dictionary = {}     # raw lines already queued this run
var _owns_mouse: bool = false
var _next_ms: int = 0
var _panel: PanelContainer
var _text: Label
var _ok: Button


func _init(hints_path: String = HINTS_PATH) -> void:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(hints_path))

	for hint in (parsed.get("hints", []) if typeof(parsed) == TYPE_DICTIONARY else []):
		if str(hint.get("goal", "")) != "" or BOX_IDS.has(str(hint.get("id", ""))):
			_box_texts[str(hint.get("text", ""))] = true


# True when the server's line belongs on the card, not the passing line.
func wanted(text: String) -> bool:
	return _box_texts.has(text) or (text.begins_with("Goal done:") and text.contains(" Next: "))


# Queues a wanted line (once per run). False when the line is not the card's (the caller shows it as before).
func offer(text: String) -> bool:
	if not wanted(text):
		return false

	if not _said.has(text):
		_said[text] = true
		queue.append(text)

	return true


# Each frame: `safe` from terrain_client. Shows the next card when safe; puts a showing card back when not, handing the mouse back to the
# camera unless `screen_up` (the menu or a window took it).
func tick(safe: bool, now_ms: int, screen_up: bool = false) -> void:
	if showing != "":
		if not safe:
			queue.push_front(showing)
			_hide(not screen_up)
			_next_ms = now_ms + GAP_MS

		return

	if safe and not queue.is_empty() and now_ms >= _next_ms:
		_show(str(queue.pop_front()))


# Shows a line now, past the queue (the screen audit's picture).
func show_text(text: String) -> void:
	_show(text)


func ok() -> void:
	if showing == "":
		return

	_hide()
	_next_ms = Time.get_ticks_msec() + GAP_MS


# Enter closes the card (terrain_client asks first, before its other keys). True when the key was the card's.
func take_key(event: InputEventKey) -> bool:
	if showing == "" or not event.pressed or event.echo:
		return false

	if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
		ok()
		return true

	return false


# The words as the player reads them: their own keys, and the next goal on its own line.
static func words(text: String) -> String:
	return KeyBindings.localize(text).replace(" Next: ", "\n\nNext: ")


func _show(text: String) -> void:
	if _panel == null:
		_build()

	showing = text
	_text.text = words(text)
	visible = true

	if mouse_free and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE   # the OK button can be clicked
		_owns_mouse = true


func _hide(give_mouse: bool = true) -> void:
	showing = ""
	visible = false

	if give_mouse and _owns_mouse and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # straight back to looking round

	_owns_mouse = false


func _build() -> void:
	layer = 40
	_panel = PanelContainer.new()
	_panel.name = "HintCard"
	var style: StyleBoxFlat = DynastyTheme.panel_style().duplicate()
	style.content_margin_left = PAD_PX
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
	var rows: VBoxContainer = VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	_panel.add_child(rows)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(WIDTH_PX - PAD_PX * 2.0, 0.0)
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_override("font", DynastyTheme.text_font())
	_text.add_theme_font_size_override("font_size", 20)
	rows.add_child(_text)
	_ok = Button.new()
	_ok.text = "OK (Enter)"
	_ok.focus_mode = Control.FOCUS_NONE   # Space (jump) and other keys never press it by accident; Enter is take_key's
	_ok.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_ok.custom_minimum_size = Vector2(160.0, 40.0)
	_ok.add_theme_font_override("font", DynastyTheme.button_font())
	_ok.add_theme_font_size_override("font_size", 18)
	_ok.pressed.connect(ok)
	rows.add_child(_ok)
	visible = false
