extends Control

# PROTOTYPE (Sonny, 2026-10-30), plan 14 of CHARACTER_DESIGN_VISION.md Part 8: the character creator screen. Sliders for the 18 body and face values, colours for skin and hair,
# a lock on every value, a dice for everything and one per section, undo and redo, archetype presets, a share code box and a turntable preview of the generated body.
# Not connected to the game, the server or any account: it only edits a genome and shows the body. The rules live in src/client/character/creator_logic.gd.
#   godot --path . res://scenes/creator_proto/creator_proto.tscn        (a window opens)

const Logic := preload("res://src/client/character/creator_logic.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const GeneratedBody := preload("res://src/client/character/generated_body.gd")
const Store := preload("res://src/client/character/character_store.gd")
const Record := preload("res://src/client/character/character_record.gd")
const Style := preload("res://src/client/character/page_style.gd")

const SELECT_SCENE := "res://scenes/character_select/character_select.tscn"
const PREVIEW_VOXEL := 0.05
const REBUILD_DELAY_S := 0.35

var logic: RefCounted = Logic.new()
var _sliders: Dictionary = {}       # slider name -> HSlider
var _values: Dictionary = {}        # slider name -> Label
var _locks: Dictionary = {}         # name -> CheckBox
var _sections: Dictionary = {}      # section title -> {head: Button, body: Control}; one is open at a time
var _pickers: Dictionary = {}       # "skin" / "hair" -> ColorPickerButton
var _code: LineEdit
var _status: Label
var _undo_button: Button
var _redo_button: Button
var _wild: CheckBox
var _gender: String = Record.DEFAULT_GENDER
var _pronouns: String = Record.DEFAULT_PRONOUNS
var _frame: String = Record.DEFAULT_FRAME
var _name_field: LineEdit
var _gender_pick: OptionButton
var _pronoun_pick: OptionButton
var _frame_buttons: Dictionary = {}
var _name_dialog: ConfirmationDialog
var _name_message: Label
var _name_edit: LineEdit
var _preview: SubViewport
var _body: Node3D
var _turn: float = 25.0
var _rebuild_in: float = -1.0
var _updating: bool = false
var _dragging: bool = false
var turntable: bool = true


func _ready() -> void:
	logic.apply_frame(_frame)       # the neutral frame to start with (no gender chosen yet); not an undo step
	logic.clear_history()
	_build_ui()
	_refresh_controls()
	_rebuild_body()


func _process(delta: float) -> void:
	if turntable and _body != null:
		_turn += delta * 25.0
		_body.rotation_degrees.y = _turn

	if _rebuild_in >= 0.0:
		_rebuild_in -= delta

		if _rebuild_in < 0.0:
			_rebuild_body()


# ---------------------------------------------------------------- screen

func _build_ui() -> void:
	var page: VBoxContainer = Style.page(self)
	_build_bar(page)
	var split: HBoxContainer = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_theme_constant_override("separation", 12)
	page.add_child(split)
	var left: PanelContainer = PanelContainer.new()
	left.custom_minimum_size = Vector2(660, 0)
	split.add_child(left)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var pad: MarginContainer = MarginContainer.new()

	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 10)

	left.add_child(pad)
	pad.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)

	_build_about(_add_accordion(column, "About you"))

	for section in Logic.SECTIONS:
		var body: VBoxContainer = _add_accordion(column, section)

		if section == "Body":
			_build_presets(body)

		_build_sliders(body, section)

	_build_colors(_add_accordion(column, "Colours"))
	_build_code(_add_accordion(column, "Share code"))
	_open_section("About you")
	var holder: SubViewportContainer = SubViewportContainer.new()
	holder.stretch = true
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(holder)
	_preview = SubViewport.new()
	_preview.own_world_3d = true
	_preview.size = Vector2i(900, 800)
	_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(_preview)
	_build_preview_world()


# The bar across the top: everything a person needs to finish: randomise, save and play, play, undo, redo.
func _build_bar(page: VBoxContainer) -> void:
	var bar: PanelContainer = PanelContainer.new()
	page.add_child(bar)
	var box: VBoxContainer = VBoxContainer.new()
	bar.add_child(box)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	var title: Label = Label.new()
	title.text = "Create your character"
	title.add_theme_font_size_override("font_size", Style.FONT_TITLE)
	title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(title)

	if Store.count() > 0:
		var back_button: Button = Style.big_button("Back to my characters", Style.FONT_BUTTON, Style.NEUTRAL)
		back_button.pressed.connect(func() -> void: get_tree().change_scene_to_file(SELECT_SCENE))
		row.add_child(back_button)

	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var dice: Button = Style.big_button("Randomise everything", Style.FONT_BUTTON, Style.ACCENT)
	dice.pressed.connect(func() -> void:
		logic.dice_all()
		_changed("Rolled everything (locked values kept)"))
	row.add_child(dice)
	var play: Button = Style.big_button("Save and play", Style.FONT_TITLE, Style.PRIMARY)
	play.pressed.connect(_press_save)
	row.add_child(play)
	_undo_button = Style.big_button("Undo", Style.FONT_BUTTON, Style.NEUTRAL)
	_undo_button.pressed.connect(func() -> void:
		if logic.undo():
			_changed("Undone"))
	row.add_child(_undo_button)
	_redo_button = Style.big_button("Redo", Style.FONT_BUTTON, Style.NEUTRAL)
	_redo_button.pressed.connect(func() -> void:
		if logic.redo():
			_changed("Redone"))
	row.add_child(_redo_button)
	var info: HBoxContainer = HBoxContainer.new()
	box.add_child(info)
	_status = Label.new()
	_status.text = "Press Randomise everything, or open a section and drag a slider. Lock what you like."
	_status.add_theme_color_override("font_color", Color(0.75, 0.8, 0.7))
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_child(_status)
	_wild = CheckBox.new()
	_wild.text = "Wild dice"
	_wild.toggled.connect(func(on: bool) -> void: logic.wild = on)
	info.add_child(_wild)


# The About you section: name, gender, pronouns and the body frame. Gender sets a starting frame and the default pronouns, nothing more: the frame row lets any gender pick any
# frame, pronouns can always be changed, and every slider and colour below stays editable. No gameplay number depends on these.
func _build_about(body: VBoxContainer) -> void:
	var name_row: HBoxContainer = HBoxContainer.new()
	body.add_child(name_row)
	var name_label: Label = Label.new()
	name_label.text = "Name"
	name_label.custom_minimum_size = Vector2(150, 0)
	name_row.add_child(name_label)
	_name_field = LineEdit.new()
	_name_field.max_length = Record.NAME_MAX
	_name_field.placeholder_text = "Up to %d letters" % Record.NAME_MAX
	_name_field.custom_minimum_size = Vector2(0, 48)
	_name_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(_name_field)
	var gender_row: HBoxContainer = HBoxContainer.new()
	body.add_child(gender_row)
	var gender_label: Label = Label.new()
	gender_label.text = "Gender"
	gender_label.custom_minimum_size = Vector2(150, 0)
	gender_row.add_child(gender_label)
	_gender_pick = OptionButton.new()
	_gender_pick.custom_minimum_size = Vector2(0, 48)
	_gender_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for g in Record.GENDERS:
		_gender_pick.add_item(Record.GENDER_LABELS[g])

	_gender_pick.select(Record.GENDERS.find(_gender))
	_gender_pick.item_selected.connect(func(index: int) -> void: set_gender(Record.GENDERS[index]))
	gender_row.add_child(_gender_pick)
	var pronoun_row: HBoxContainer = HBoxContainer.new()
	body.add_child(pronoun_row)
	var pronoun_label: Label = Label.new()
	pronoun_label.text = "Pronouns"
	pronoun_label.custom_minimum_size = Vector2(150, 0)
	pronoun_row.add_child(pronoun_label)
	_pronoun_pick = OptionButton.new()
	_pronoun_pick.custom_minimum_size = Vector2(0, 48)
	_pronoun_pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	for pr in Record.PRONOUNS:
		_pronoun_pick.add_item(Record.PRONOUN_LABELS[pr])

	_pronoun_pick.select(Record.PRONOUNS.find(_pronouns))
	_pronoun_pick.item_selected.connect(func(index: int) -> void: _pronouns = Record.PRONOUNS[index])
	pronoun_row.add_child(_pronoun_pick)
	var frame_row: HBoxContainer = HBoxContainer.new()
	body.add_child(frame_row)
	var frame_label: Label = Label.new()
	frame_label.text = "Frame"
	frame_label.custom_minimum_size = Vector2(150, 0)
	frame_row.add_child(frame_label)

	for f in Record.FRAMES:
		var b: Button = Button.new()
		b.text = Record.FRAME_LABELS[f]
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(0, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void: set_frame(f))
		frame_row.add_child(b)
		_frame_buttons[f] = b

	_show_frame()
	var note: Label = Label.new()
	note.text = "Gender and frame only set a starting body and clothes. Every slider and colour can still be changed, and your pronouns are yours to pick."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.75, 0.8, 0.7))
	body.add_child(note)


# Choosing a gender sets its default pronouns and its starting frame (one undo step for the body); both can be changed afterwards.
func set_gender(gender: String) -> void:
	if not Record.GENDERS.has(gender):
		return

	_gender = gender
	_pronouns = Record.default_pronouns(gender)

	if _pronoun_pick != null:
		_gender_pick.select(Record.GENDERS.find(gender))
		_pronoun_pick.select(Record.PRONOUNS.find(_pronouns))

	set_frame(Record.default_frame(gender))


func set_frame(frame: String) -> void:
	if not Record.FRAMES.has(frame):
		return

	_frame = frame
	logic.apply_frame(frame)
	_show_frame()

	if _status != null:
		_changed("%s frame: a starting point, change anything you like" % Record.FRAME_LABELS[frame])


func _show_frame() -> void:
	for f in _frame_buttons:
		(_frame_buttons[f] as Button).button_pressed = f == _frame


# Save and play: a name typed in the About you section is used; without one the name box is asked for.
func _press_save() -> void:
	var typed: String = _name_field.text.strip_edges()

	if Store.name_ok(typed):
		_finish(typed)
	else:
		_ask_name("Every character needs a name." if typed == "" else "That name will not do (1 to %d characters)." % Record.NAME_MAX)


# Save and play: asks for a name, saves the character, makes it the active one and goes on into the game (the only way in).
func _ask_name(message: String = "") -> void:
	if _name_dialog == null:
		_name_dialog = ConfirmationDialog.new()
		_name_dialog.title = "Name your character"
		_name_dialog.ok_button_text = "Save and play"
		_name_dialog.cancel_button_text = "Back"
		_name_dialog.min_size = Vector2i(640, 220)
		var box: VBoxContainer = VBoxContainer.new()
		_name_message = Label.new()
		box.add_child(_name_message)
		_name_edit = LineEdit.new()
		_name_edit.max_length = Record.NAME_MAX
		_name_edit.placeholder_text = "Name (up to %d letters)" % Record.NAME_MAX
		_name_edit.custom_minimum_size = Vector2(0, 48)
		_name_edit.text_submitted.connect(func(_text: String) -> void: _name_dialog.get_ok_button().pressed.emit())
		box.add_child(_name_edit)
		_name_dialog.add_child(box)
		_name_dialog.confirmed.connect(func() -> void: _finish(_name_edit.text.strip_edges()))
		add_child(_name_dialog)

	_name_message.text = message if message != "" else "Every character needs a name."
	_name_edit.text = _name_field.text.strip_edges()
	_name_dialog.popup_centered()
	_name_edit.grab_focus()


func _finish(chosen: String) -> void:
	_name_field.text = chosen
	var id: String = Store.add(chosen, logic.code(), _gender, _pronouns, _frame)

	if id == "":
		_ask_name("That name will not do (1 to %d characters). Try another." % Record.NAME_MAX)
		return

	Store.set_active(id)
	Engine.set_meta("creator_done", true)
	get_tree().change_scene_to_file("res://scenes/launcher.tscn")


# A section header button with its content below it; only one section is open at a time. Returns the content box.
func _add_accordion(column: VBoxContainer, title: String) -> VBoxContainer:
	var head: Button = Style.big_button("", Style.FONT_SECTION, Color(0.24, 0.28, 0.36))
	head.alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(head)
	var body: VBoxContainer = VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	body.visible = false
	column.add_child(body)
	_sections[title] = {"head": head, "body": body}
	head.text = "+  " + title
	head.pressed.connect(func() -> void: _open_section("" if body.visible else title))
	return body


func _open_section(title: String) -> void:
	for key in _sections:
		var shown: bool = key == title
		(_sections[key]["body"] as Control).visible = shown
		(_sections[key]["head"] as Button).text = ("-  " if shown else "+  ") + String(key)


func _build_presets(body: VBoxContainer) -> void:
	var presets: HBoxContainer = HBoxContainer.new()
	body.add_child(presets)
	var label: Label = Label.new()
	label.text = "Body type:"
	presets.add_child(label)

	for preset in ["average", "broad", "lean", "stocky"]:
		var b: Button = Button.new()
		b.text = String(preset).capitalize()
		b.custom_minimum_size = Vector2(0, 44)
		b.pressed.connect(func() -> void:
			logic.apply_preset(preset)
			_changed("Body type: " + preset))
		presets.add_child(b)


func _build_sliders(body: VBoxContainer, section: String) -> void:
	var dice: Button = Button.new()
	dice.text = "Dice: " + section
	dice.custom_minimum_size = Vector2(0, 44)
	dice.pressed.connect(func() -> void:
		logic.dice_section(section)
		_changed("Rolled " + section))
	body.add_child(dice)

	for key in Logic.SECTIONS[section]:
		var row: HBoxContainer = HBoxContainer.new()
		body.add_child(row)
		var name_label: Label = Label.new()
		name_label.text = String(key).replace("_", " ").capitalize()
		name_label.custom_minimum_size = Vector2(150, 0)
		row.add_child(name_label)
		var slider: HSlider = HSlider.new()
		slider.min_value = -1.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size = Vector2(240, 36)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.drag_started.connect(func() -> void:
			_dragging = true
			logic.begin_edit())
		slider.drag_ended.connect(func(_changed_value: bool) -> void: _dragging = false)
		slider.value_changed.connect(func(v: float) -> void: _slider_moved(key, v))
		row.add_child(slider)
		_sliders[key] = slider
		var value: Label = Label.new()
		value.custom_minimum_size = Vector2(64, 0)
		row.add_child(value)
		_values[key] = value
		row.add_child(_lock_box(key))


func _lock_box(key: String) -> CheckBox:
	var lock: CheckBox = CheckBox.new()
	lock.text = "Lock"
	lock.toggled.connect(func(on: bool) -> void: logic.set_lock(key, on))
	_locks[key] = lock
	return lock


func _build_colors(body: VBoxContainer) -> void:
	for section in Logic.COLOR_SECTIONS:
		for key in Logic.COLOR_SECTIONS[section]:
			var row: HBoxContainer = HBoxContainer.new()
			body.add_child(row)
			var label: Label = Label.new()
			label.text = String(section) + " colour"
			label.custom_minimum_size = Vector2(170, 0)
			row.add_child(label)
			var picker: ColorPickerButton = ColorPickerButton.new()
			picker.custom_minimum_size = Vector2(120, 44)
			picker.color_changed.connect(func(c: Color) -> void: _color_picked(key, c))
			row.add_child(picker)
			_pickers[key] = picker
			var dice: Button = Button.new()
			dice.text = "Dice"
			dice.custom_minimum_size = Vector2(0, 44)
			dice.pressed.connect(func() -> void:
				logic.dice_section(section)
				_changed("Rolled " + section + " colour"))
			row.add_child(dice)
			row.add_child(_lock_box(key))


func _build_code(body: VBoxContainer) -> void:
	var row: HBoxContainer = HBoxContainer.new()
	body.add_child(row)
	_code = LineEdit.new()
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.custom_minimum_size = Vector2(0, 44)
	_code.placeholder_text = "paste a code and press Load"
	row.add_child(_code)
	var load_button: Button = Button.new()
	load_button.text = "Load"
	load_button.custom_minimum_size = Vector2(90, 44)
	load_button.pressed.connect(func() -> void:
		if logic.load_code(_code.text):
			_changed("Code loaded")
		else:
			_status.text = "That is not a valid code (nothing changed).")
	row.add_child(load_button)


func _build_preview_world() -> void:
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.24, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_energy = 0.9
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	_preview.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	_preview.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 30.0
	_preview.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.0, 5.4), Vector3(0.0, 0.95, 0.0))


# ---------------------------------------------------------------- reactions

func _slider_moved(key: String, value: float) -> void:
	if _updating:
		return

	if not _dragging:
		logic.begin_edit()       # a keyboard step is its own undo step

	logic.set_slider_live(key, value)
	(_values[key] as Label).text = "%+.2f" % value
	_schedule_rebuild()


func _color_picked(key: String, color: Color) -> void:
	if _updating:
		return

	logic.set_color(key, color)
	_schedule_rebuild()


func _changed(message: String) -> void:
	_status.text = message
	_refresh_controls()
	_schedule_rebuild()


func _schedule_rebuild() -> void:
	_rebuild_in = REBUILD_DELAY_S
	_code.text = logic.code()
	_undo_button.disabled = not logic.can_undo()
	_redo_button.disabled = not logic.can_redo()


func _refresh_controls() -> void:
	_updating = true

	for key in _sliders:
		(_sliders[key] as HSlider).value = float(logic.genome[key])
		(_values[key] as Label).text = "%+.2f" % float(logic.genome[key])

	for key in _pickers:
		(_pickers[key] as ColorPickerButton).color = logic.genome[key]

	for key in _locks:
		(_locks[key] as CheckBox).button_pressed = logic.is_locked(key)

	_updating = false
	_code.text = logic.code()
	_undo_button.disabled = not logic.can_undo()
	_redo_button.disabled = not logic.can_redo()


func _rebuild_body() -> void:
	var t0: int = Time.get_ticks_usec()
	var fresh: Node3D = GeneratedBody.new(logic.genome, PREVIEW_VOXEL, true, false)
	var yaw: float = _body.rotation_degrees.y if _body != null else _turn

	if _body != null:
		_body.queue_free()

	_body = fresh
	_preview.add_child(_body)
	_body.rotation_degrees.y = yaw
	_rebuild_in = -1.0
	print("creator preview rebuilt in %.0f ms" % [float(Time.get_ticks_usec() - t0) / 1000.0])
