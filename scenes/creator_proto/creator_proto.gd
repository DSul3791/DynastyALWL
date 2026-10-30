extends Control

# PROTOTYPE (Sonny, 2026-10-30), plan 14 of CHARACTER_DESIGN_VISION.md Part 8: the character creator screen. Sliders for the 18 body and face values, colours for skin and hair,
# a lock on every value, a dice for everything and one per section, undo and redo, archetype presets, a share code box and a turntable preview of the generated body.
# Not connected to the game, the server or any account: it only edits a genome and shows the body. The rules live in src/client/character/creator_logic.gd.
#   godot --path . res://scenes/creator_proto/creator_proto.tscn        (a window opens)

const Logic := preload("res://src/client/character/creator_logic.gd")
const Generator := preload("res://src/client/character/body_generator.gd")
const GeneratedBody := preload("res://src/client/character/generated_body.gd")

const PREVIEW_VOXEL := 0.05
const REBUILD_DELAY_S := 0.35

var logic: RefCounted = Logic.new()
var _sliders: Dictionary = {}       # slider name -> HSlider
var _values: Dictionary = {}        # slider name -> Label
var _locks: Dictionary = {}         # name -> CheckBox
var _pickers: Dictionary = {}       # "skin" / "hair" -> ColorPickerButton
var _code: LineEdit
var _status: Label
var _undo_button: Button
var _redo_button: Button
var _wild: CheckBox
var _preview: SubViewport
var _body: Node3D
var _turn: float = 25.0
var _rebuild_in: float = -1.0
var _updating: bool = false
var _dragging: bool = false
var turntable: bool = true


func _ready() -> void:
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
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var back: ColorRect = ColorRect.new()
	back.color = Color(0.13, 0.14, 0.16)
	back.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(back)
	var split: HBoxContainer = HBoxContainer.new()
	split.set_anchors_preset(Control.PRESET_FULL_RECT)
	split.add_theme_constant_override("separation", 12)
	add_child(split)
	var left: PanelContainer = PanelContainer.new()
	left.custom_minimum_size = Vector2(470, 0)
	split.add_child(left)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	var column: VBoxContainer = VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 4)
	scroll.add_child(column)
	_build_top(column)

	for section in Logic.SECTIONS:
		_build_section(column, section)

	_build_colors(column)
	_build_code(column)
	var holder: SubViewportContainer = SubViewportContainer.new()
	holder.stretch = true
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.add_child(holder)
	_preview = SubViewport.new()
	_preview.own_world_3d = true
	_preview.size = Vector2i(700, 720)
	_preview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(_preview)
	_build_preview_world()


func _build_top(column: VBoxContainer) -> void:
	var title: Label = Label.new()
	title.text = "Character creator (prototype)"
	title.add_theme_font_size_override("font_size", 22)
	column.add_child(title)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	var dice: Button = Button.new()
	dice.text = "Dice: everything"
	dice.pressed.connect(func() -> void:
		logic.dice_all()
		_changed("Rolled everything (locked values kept)"))
	row.add_child(dice)
	_undo_button = Button.new()
	_undo_button.text = "Undo"
	_undo_button.pressed.connect(func() -> void:
		if logic.undo():
			_changed("Undone"))
	row.add_child(_undo_button)
	_redo_button = Button.new()
	_redo_button.text = "Redo"
	_redo_button.pressed.connect(func() -> void:
		if logic.redo():
			_changed("Redone"))
	row.add_child(_redo_button)
	_wild = CheckBox.new()
	_wild.text = "Wild dice"
	_wild.toggled.connect(func(on: bool) -> void: logic.wild = on)
	row.add_child(_wild)
	var presets: HBoxContainer = HBoxContainer.new()
	column.add_child(presets)
	var label: Label = Label.new()
	label.text = "Body type:"
	presets.add_child(label)

	for preset in ["average", "broad", "lean", "stocky"]:
		var b: Button = Button.new()
		b.text = String(preset).capitalize()
		b.pressed.connect(func() -> void:
			logic.apply_preset(preset)
			_changed("Body type: " + preset))
		presets.add_child(b)

	_status = Label.new()
	_status.text = "Drag a slider, press a dice, lock what you like."
	_status.add_theme_color_override("font_color", Color(0.75, 0.8, 0.7))
	column.add_child(_status)


func _build_section(column: VBoxContainer, section: String) -> void:
	var head: HBoxContainer = HBoxContainer.new()
	column.add_child(head)
	var label: Label = Label.new()
	label.text = section
	label.add_theme_font_size_override("font_size", 17)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	var dice: Button = Button.new()
	dice.text = "Dice"
	dice.pressed.connect(func() -> void:
		logic.dice_section(section)
		_changed("Rolled " + section))
	head.add_child(dice)

	for key in Logic.SECTIONS[section]:
		var row: HBoxContainer = HBoxContainer.new()
		column.add_child(row)
		var name_label: Label = Label.new()
		name_label.text = String(key).replace("_", " ").capitalize()
		name_label.custom_minimum_size = Vector2(100, 0)
		row.add_child(name_label)
		var slider: HSlider = HSlider.new()
		slider.min_value = -1.0
		slider.max_value = 1.0
		slider.step = 0.01
		slider.custom_minimum_size = Vector2(210, 0)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.drag_started.connect(func() -> void:
			_dragging = true
			logic.begin_edit())
		slider.drag_ended.connect(func(_changed_value: bool) -> void: _dragging = false)
		slider.value_changed.connect(func(v: float) -> void: _slider_moved(key, v))
		row.add_child(slider)
		_sliders[key] = slider
		var value: Label = Label.new()
		value.custom_minimum_size = Vector2(44, 0)
		row.add_child(value)
		_values[key] = value
		row.add_child(_lock_box(key))


func _lock_box(key: String) -> CheckBox:
	var lock: CheckBox = CheckBox.new()
	lock.text = "Lock"
	lock.toggled.connect(func(on: bool) -> void: logic.set_lock(key, on))
	_locks[key] = lock
	return lock


func _build_colors(column: VBoxContainer) -> void:
	for section in Logic.COLOR_SECTIONS:
		for key in Logic.COLOR_SECTIONS[section]:
			var row: HBoxContainer = HBoxContainer.new()
			column.add_child(row)
			var label: Label = Label.new()
			label.text = String(section) + " colour"
			label.custom_minimum_size = Vector2(150, 0)
			row.add_child(label)
			var picker: ColorPickerButton = ColorPickerButton.new()
			picker.custom_minimum_size = Vector2(90, 28)
			picker.color_changed.connect(func(c: Color) -> void: _color_picked(key, c))
			row.add_child(picker)
			_pickers[key] = picker
			var dice: Button = Button.new()
			dice.text = "Dice"
			dice.pressed.connect(func() -> void:
				logic.dice_section(section)
				_changed("Rolled " + section + " colour"))
			row.add_child(dice)
			row.add_child(_lock_box(key))


func _build_code(column: VBoxContainer) -> void:
	var label: Label = Label.new()
	label.text = "Share code"
	label.add_theme_font_size_override("font_size", 17)
	column.add_child(label)
	var row: HBoxContainer = HBoxContainer.new()
	column.add_child(row)
	_code = LineEdit.new()
	_code.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_code.placeholder_text = "paste a code and press Load"
	row.add_child(_code)
	var load_button: Button = Button.new()
	load_button.text = "Load"
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
