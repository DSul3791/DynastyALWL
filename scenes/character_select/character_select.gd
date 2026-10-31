extends Control

# The first page of the game (Sonny, 30 Oct 2026): the player's characters, each with a small picture of its body. Pick one and press Play, or make a new character in the
# creator. With no characters yet it goes straight to the creator. Rename and Delete (with a confirm) are here too. Everything is local: see character_store.gd.
#   godot --path . res://scenes/character_select/character_select.tscn

const Store := preload("res://src/client/character/character_store.gd")
const Record := preload("res://src/client/character/character_record.gd")
const Style := preload("res://src/client/character/page_style.gd")
const GeneratedBody := preload("res://src/client/character/generated_body.gd")

const CREATOR_SCENE := "res://scenes/creator_proto/creator_proto.tscn"
const ROW_HEIGHT := 190
const PICTURE := Vector2i(130, 180)

var selected_id: String = ""
var auto_creator: bool = true          # tests and picture scripts turn this off to see the empty page

var _rows: VBoxContainer
var _group: ButtonGroup = ButtonGroup.new()
var _play: Button
var _rename: Button
var _delete: Button
var _status: Label
var _confirm: ConfirmationDialog
var _rename_dialog: ConfirmationDialog
var _rename_edit: LineEdit
var _empty_note: Label


func _ready() -> void:
	if auto_creator and Store.count() == 0:
		call_deferred("_to_creator")
		return

	_build_ui()
	refresh()


func _to_creator() -> void:
	get_tree().change_scene_to_file(CREATOR_SCENE)


func _build_ui() -> void:
	var page: VBoxContainer = Style.page(self)
	var title: Label = Label.new()
	title.text = "Choose your character"
	title.add_theme_font_size_override("font_size", Style.FONT_TITLE)
	page.add_child(title)
	_status = Label.new()
	_status.add_theme_color_override("font_color", Color(0.75, 0.8, 0.7))
	page.add_child(_status)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 10)
	scroll.add_child(_rows)
	var bar: HBoxContainer = HBoxContainer.new()
	bar.add_theme_constant_override("separation", 12)
	page.add_child(bar)
	_play = Style.big_button("Play", Style.FONT_TITLE, Style.PRIMARY)
	_play.custom_minimum_size = Vector2(240, 72)
	_play.pressed.connect(_press_play)
	bar.add_child(_play)
	var new_button: Button = Style.big_button("New character", Style.FONT_BUTTON, Style.ACCENT)
	new_button.pressed.connect(_to_creator)
	bar.add_child(new_button)
	var spacer: Control = Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_rename = Style.big_button("Rename", Style.FONT_BUTTON, Style.NEUTRAL)
	_rename.pressed.connect(_press_rename)
	bar.add_child(_rename)
	_delete = Style.big_button("Delete character", Style.FONT_BUTTON, Style.DANGER)
	_delete.pressed.connect(_press_delete)
	bar.add_child(_delete)
	_confirm = ConfirmationDialog.new()
	_confirm.title = "Delete character"
	_confirm.ok_button_text = "Delete"
	_confirm.cancel_button_text = "Keep"
	_confirm.min_size = Vector2i(640, 200)
	_confirm.confirmed.connect(_delete_selected)
	add_child(_confirm)
	_rename_dialog = ConfirmationDialog.new()
	_rename_dialog.title = "Rename character"
	_rename_dialog.ok_button_text = "Rename"
	_rename_dialog.min_size = Vector2i(640, 180)
	_rename_edit = LineEdit.new()
	_rename_edit.max_length = Record.NAME_MAX
	_rename_edit.custom_minimum_size = Vector2(0, 48)
	_rename_dialog.add_child(_rename_edit)
	_rename_dialog.confirmed.connect(_rename_selected)
	add_child(_rename_dialog)


# Rebuilds the list from the files. Keeps the selection when that character still exists, else selects the active one (or the first).
func refresh() -> void:
	for child in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()

	var all: Array = Store.list()
	var keep: String = selected_id
	selected_id = ""

	for one in all:
		var row: Button = _make_row(one)
		_rows.add_child(row)

	var want: String = keep if not Store.get_character(keep).is_empty() else Store.active_id()

	if Store.get_character(want).is_empty() and not all.is_empty():
		want = str((all[all.size() - 1] as Dictionary)["id"])

	for row in _rows.get_children():
		if str(row.get_meta("id")) == want:
			(row as Button).button_pressed = true
			selected_id = want

	_update_buttons()


func _make_row(one: Dictionary) -> Button:
	var row: Button = Button.new()
	row.toggle_mode = true
	row.button_group = _group
	row.text = str(one["name"])
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	row.add_theme_font_size_override("font_size", Style.FONT_SECTION)
	row.set_meta("id", str(one["id"]))
	Style.style_button(row, Color(0.24, 0.28, 0.36))

	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var box: StyleBoxFlat = row.get_theme_stylebox(state if state != "hover_pressed" else "pressed") as StyleBoxFlat

		if box == null:
			continue

		box = box.duplicate()
		box.content_margin_left = float(PICTURE.x) + 36.0

		if state == "pressed" or state == "hover_pressed":
			box.bg_color = Style.PRIMARY.darkened(0.1)

		row.add_theme_stylebox_override(state, box)

	row.pressed.connect(func() -> void:
		selected_id = str(one["id"])
		_update_buttons())
	row.add_child(_make_picture(one["genome"]))
	return row


# A small picture of the body: a viewport of its own, drawn once. Cheap: a coarse body (7 cm voxels, no fingers) and one frame.
func _make_picture(genome: Dictionary) -> Control:
	var holder: SubViewportContainer = SubViewportContainer.new()
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.position = Vector2(14.0, (ROW_HEIGHT - PICTURE.y) / 2.0)
	holder.size = Vector2(PICTURE)
	var view: SubViewport = SubViewport.new()
	view.own_world_3d = true
	view.size = PICTURE
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	holder.add_child(view)
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.24, 0.28)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.68)
	env.ambient_light_energy = 0.9
	var we: WorldEnvironment = WorldEnvironment.new()
	we.environment = env
	view.add_child(we)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, -30.0, 0.0)
	view.add_child(sun)
	var cam: Camera3D = Camera3D.new()
	cam.fov = 30.0
	view.add_child(cam)
	cam.look_at_from_position(Vector3(0.0, 1.0, 5.4), Vector3(0.0, 0.95, 0.0))
	var body: Node3D = GeneratedBody.new(genome, 0.06, false, false)
	body.rotation_degrees.y = 180.0
	view.add_child(body)
	return holder


func _update_buttons() -> void:
	var has: bool = selected_id != ""
	_play.disabled = not has
	_rename.disabled = not has
	_delete.disabled = not has
	var n: int = _rows.get_child_count()
	_status.text = "%d character%s. Pick one and press Play, or make a new one." % [n, "" if n == 1 else "s"]


func _press_play() -> void:
	play(selected_id)


# Makes the character the active one and starts the game (back through the launcher, which now sees creator_done). Returns false when there is no such character.
func play(id: String) -> bool:
	if not Store.set_active(id):
		return false

	Engine.set_meta("creator_done", true)
	get_tree().change_scene_to_file("res://scenes/launcher.tscn")
	return true


func _press_delete() -> void:
	var one: Dictionary = Store.get_character(selected_id)

	if not one.is_empty():
		_confirm.dialog_text = "Delete %s for good? This cannot be undone." % str(one["name"])
		_confirm.popup_centered()


func _delete_selected() -> void:
	Store.delete(selected_id)
	selected_id = ""

	if Store.count() == 0 and auto_creator:
		_to_creator()
		return

	refresh()


func _press_rename() -> void:
	var one: Dictionary = Store.get_character(selected_id)

	if not one.is_empty():
		_rename_edit.text = str(one["name"])
		_rename_dialog.popup_centered()
		_rename_edit.grab_focus()
		_rename_edit.select_all()


func _rename_selected() -> void:
	var chosen: String = _rename_edit.text.strip_edges()

	if Store.rename(selected_id, chosen):
		refresh()
	else:
		_status.text = "That name will not do (1 to %d characters)." % Record.NAME_MAX
