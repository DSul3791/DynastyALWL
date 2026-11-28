extends RefCounted

# The You column's top half: a well for every worn position (data/items/clothing.json worn) and the item in hand, no character picture.
# Dave, 27 Nov 2026 (R-HUD-INVENTORY-WORN): "remove the picture and put more spaces for clothing so we can have clothing on rose on the inside
# and armour and weapons on the outside". Six wells a row in three pairs: armour on the left, clothing in the middle, weapons and carried
# gear on the right, each pair head to feet. An empty well shows the engraved silhouette of its body slot; "" is a gap in a pair.

const ArtKit := preload("res://src/client/ui/art_kit.gd")
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")

const GEAR_PX := 56.0       # six wells and the gaps between pairs fit the column's 408 px
const PAIR_GAP := 20
const HAND := "right"       # the item in hand (no worn position)
const GHOST_OF := {"body:outer": "outer", "neck:base": "outer", "shoulder:base": "back", "strap:base": "waist"}   # wells whose silhouette is not their body slot's
const GROUPS := [
	["Armour", ["head:mail", "head:rigid", "body:padding", "body:mail", "body:rigid", "hands:rigid", "legs:mail", "legs:rigid", "feet:over", ""]],
	["Clothing", ["head:base", "neck:base", "body:base", "body:over", "body:outer", "hands:base", "legs:base", "", "feet:socks", "feet:footwear"]],
	["Carried", [HAND, "shoulder:base", "back:base", "back:roll", "strap:base", "waist:base", "waist:pouch", "waist:quiver", "waist:scabbard", "waist:tools"]],
]

var view                            # the InventoryView (src/client/inventory_view.gd)
var root: Control
var wells: Dictionary = {}          # worn position ("body:mail") or HAND -> its ItemSlot
var well_at: Dictionary = {}        # worn position -> its index in view.worn while something is worn there, else -1


func _init(owner_view) -> void:
	view = owner_view


func build() -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", PAIR_GAP)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	for group in GROUPS:
		row.add_child(_pair(str(group[0]), group[1]))

	root = row
	return root


func _pair(title: String, places: Array) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	var caption: Label = Label.new()
	caption.text = title
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font", ArtKit.font("garamond"))
	caption.add_theme_font_size_override("font_size", view._px(18))
	caption.add_theme_color_override("font_color", ArtKit.DIM)
	box.add_child(caption)
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	box.add_child(grid)

	for place in places:
		grid.add_child(_gap() if place == "" else _well(str(place)))

	return box


func _gap() -> Control:
	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(GEAR_PX, GEAR_PX)
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return gap


func _well(place: String) -> Control:
	var slot = InventoryLook.make_slot(view, -1)
	slot.set_unit(GEAR_PX / ItemSlot.SLOT_PX)
	slot.focus_mode = Control.FOCUS_NONE
	var ghost: Control = Control.new()
	ghost.name = "Ghost"
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.set_anchors_preset(Control.PRESET_FULL_RECT)
	var glyph: String = str(ArtKit.GEAR_GHOST.get(GHOST_OF.get(place, place.get_slice(":", 0)), "all"))
	ghost.draw.connect(func() -> void:
		var side: float = GEAR_PX * 0.55
		ArtKit.draw_glyph(ghost, glyph, Rect2(ghost.size * 0.5 - Vector2(side, side) * 0.5, Vector2(side, side)), ArtKit.GHOST, ArtKit.WELL))
	slot.add_child(ghost)
	wells[place] = slot

	if place == HAND:
		return slot

	slot.clicked.connect(func(button: int, _shift: bool) -> void:
		if button == MOUSE_BUTTON_LEFT:
			view.open_bag(int(well_at.get(place, -1))))

	# Drop a piece from the inventory on the well it is worn in to put it on (the server checks it); drag a worn piece back into the
	# inventory to take it off (pack_grid.gd takes {"worn": position}). The Back well's pack drag (Dave 15 Nov 2026), now on every well.
	slot.can_drop = func(data: Variant) -> bool: return typeof(data) == TYPE_DICTIONARY and data.has("slot") and _place_of(int(data["slot"])) == place
	slot.on_drop = func(data: Variant) -> void: view.wear_slot(int(data["slot"]))
	slot.drag_data = func() -> Variant:
		if int(well_at.get(place, -1)) < 0:
			return null

		return {"worn": int(well_at[place])}

	return slot


# The worn position ("body:mail") the piece in a pack slot goes to, "" for none: its body slot and its wear_layer, else the slot's first layer.
func _place_of(pack_slot: int) -> String:
	var body: String = view.wear_slot_of(pack_slot)

	if body == "":
		return ""

	var layers: Array = view.clothing_cfg.get("layers", {}).get(body, ["base"])
	var entry: Dictionary = view.table.entry(view.table.id_of(view.inventory.numbers[pack_slot]))
	return "%s:%s" % [body, str(entry.get("wear_layer", layers[0] if not layers.is_empty() else "base"))]


# Every well from what is worn and what is in hand.
func refresh() -> void:
	if root == null or not is_instance_valid(root):
		return

	var places: Array = view.worn_places()
	var labels: Dictionary = view.clothing_cfg.get("worn_labels", {})

	for place in wells:
		var number: int = 0
		var item_inst: Dictionary = {}

		if place == HAND:
			if view.held_slot_now.is_valid():
				var held: int = int(view.held_slot_now.call())
				number = view.inventory.numbers[held] if held >= 0 and held < view.inventory.slot_count else 0
				item_inst = view.inventory.inst_of(held) if number != 0 else {}
		else:
			var at: int = places.find(place)
			at = at if at >= 0 and at < view.worn.size() and view.worn[at] != 0 else -1
			well_at[place] = at

			if at >= 0:
				number = view.worn[at]
				item_inst = view.worn_inst.get(at, {})

		var slot = wells[place]
		var empty_label: String = "In hand" if place == HAND else str(labels.get(place, place))
		InventoryLook.show_stack(view, slot, number, 1, 0, view.inst_label(number, item_inst) if number != 0 else empty_label)
		(slot.get_node("Ghost") as Control).visible = number == 0
