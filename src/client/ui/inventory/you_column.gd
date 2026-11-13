extends RefCounted

# The You column's top half (docs/ui/inventory_crafting_redesign.md sections 4.2 and 6.6; Kathleen, 9 Nov 2026), step 3d:
# four gear wells on each side (head, body, legs, feet; hands, back, right hand, left hand) and between them the live character,
# a 3D preview dressed in what is worn (avatar_driver.gd dress) under a warm key light and a gold rim light, idling.
# An empty gear well shows the engraved silhouette of what goes there. The preview renders only while the window is open.

const ArtKit := preload("res://src/client/ui/art_kit.gd")
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")
const MyCharacter := preload("res://src/client/character/my_character.gd")
const AvatarDriver := preload("res://src/client/character/avatar_driver.gd")

const GEAR_PX := 96.0
const FIGURE := Vector2(196.0, 470.0)
const LEFT := ["head", "body", "outer", "legs", "feet"]
const RIGHT := ["hands", "back", "waist", "right", "left"]
const CAPTION := "Live character, as equipped"

var view                            # the InventoryView (src/client/inventory_view.gd)
var root: Control
var wells: Dictionary = {}          # gear slot name -> its ItemSlot
var well_at: Dictionary = {}        # gear slot name -> the worn position it shows (-1 none): a click on a worn bag opens it
var preview: SubViewport
var holder: SubViewportContainer    # the preview's frame; shown only while the window is open, so the preview renders only then
var rig: Node3D
var _dressed_sign: int = 0          # what the rig was last dressed in (a hash of view.worn)


func _init(owner_view) -> void:
	view = owner_view


func build() -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)
	row.add_child(_gear_column(LEFT))
	row.add_child(_figure())
	row.add_child(_gear_column(RIGHT))
	var caption: Label = Label.new()
	caption.text = CAPTION
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", ArtKit.font("garamond"))
	caption.add_theme_font_size_override("font_size", view._px(18))
	caption.add_theme_color_override("font_color", ArtKit.DIM)
	box.add_child(caption)
	root = box
	return root


func _gear_column(names: Array) -> Control:
	var column: VBoxContainer = VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)   # five wells a side since the outer and waist slots (10 Nov 2026); was four at 26

	for gear in names:
		var slot = InventoryLook.make_slot(view, -1)
		slot.set_unit(GEAR_PX / ItemSlot.SLOT_PX)
		slot.focus_mode = Control.FOCUS_NONE
		var ghost: Control = Control.new()
		ghost.name = "Ghost"
		ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
		var glyph: String = str(ArtKit.GEAR_GHOST.get(gear, "all"))
		ghost.draw.connect(func() -> void:
			var side: float = 52.0
			ArtKit.draw_glyph(ghost, glyph, Rect2(ghost.size * 0.5 - Vector2(side, side) * 0.5, Vector2(side, side)), ArtKit.GHOST, ArtKit.WELL))
		slot.add_child(ghost)
		slot.clicked.connect(func(button: int, _shift: bool) -> void:
			if button == MOUSE_BUTTON_LEFT:
				view.open_bag(int(well_at.get(gear, -1))))
		column.add_child(slot)
		wells[gear] = slot

	return column


# The live character (6.6): its own small world with a warm key light from the top left and a gold rim light from behind right.
func _figure() -> Control:
	holder = SubViewportContainer.new()
	holder.custom_minimum_size = FIGURE
	holder.stretch = true
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.visible = false
	preview = SubViewport.new()
	preview.own_world_3d = true
	preview.transparent_bg = true
	preview.size = Vector2i(FIGURE)
	holder.add_child(preview)
	var camera: Camera3D = Camera3D.new()
	camera.position = Vector3(0.0, 0.95, 3.6)
	camera.fov = 34.0
	preview.add_child(camera)
	var key: DirectionalLight3D = DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40.0, -35.0, 0.0)
	key.light_color = Color(1.0, 0.95, 0.86)
	preview.add_child(key)
	var rim: DirectionalLight3D = DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15.0, 150.0, 0.0)
	rim.light_color = Color("#FFD68C")
	rim.light_energy = 1.4
	preview.add_child(rim)
	rig = MyCharacter.make_avatar()
	preview.add_child(rig)

	if rig.has_method("play"):
		rig.call("play", "idle")

	return holder


# The window opened or shut: the preview renders only while it is open. The container owns its viewport's update mode (it sets
# "when visible" or "disabled" as it is shown or hidden), so the preview is turned on and off by showing its container.
func set_active(on: bool) -> void:
	if holder != null and is_instance_valid(holder):
		holder.visible = on


# The gear wells from what is worn and what is in hand; the rig re-dressed when what is worn changed.
func refresh() -> void:
	if root == null or not is_instance_valid(root):
		return

	for gear in LEFT + RIGHT:
		var number: int = 0
		var item_inst: Dictionary = {}
		# A well shows its slot's outermost worn layer (protocol 107); the Outer well is the body's outer layer, so Body shows what is under it.
		# Every layer, each with its own Take off, is on the Tab screen (character_screen.gd).
		var at: int = view.worn_places().find("body:outer") if gear == "outer" else view.worn_top(gear, ["outer"] if gear == "body" else [])

		if (gear == "back" or gear == "waist") and view.worn_places().find(gear + ":base") >= 0 and view.worn_places().find(gear + ":base") < view.worn.size() and view.worn[view.worn_places().find(gear + ":base")] != 0:
			at = view.worn_places().find(gear + ":base")   # the pack and the belt themselves, not the bedroll or a pouch on them (Tab lists those)

		well_at[gear] = at

		if at >= 0 and at < view.worn.size():
			number = view.worn[at]
			item_inst = view.worn_inst.get(at, {})
		elif gear == "right" and view.held_slot_now.is_valid():
			var held: int = int(view.held_slot_now.call())
			number = view.inventory.numbers[held] if held >= 0 and held < view.inventory.slot_count else 0
			item_inst = view.inventory.inst_of(held) if number != 0 else {}

		# STUB(step 3d): the left hand shows its silhouette until the game has an off-hand item (a shield or torch held in the left).
		var slot = wells[gear]
		InventoryLook.show_stack(view, slot, number, 1, 0, view.inst_label(number, item_inst) if number != 0 else str(gear).capitalize())
		(slot.get_node("Ghost") as Control).visible = number == 0

	var worn_sign: int = hash(view.worn)

	if rig != null and is_instance_valid(rig) and worn_sign != _dressed_sign:
		_dressed_sign = worn_sign
		AvatarDriver.dress(rig, view)
