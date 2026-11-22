extends RefCounted

# The pinned recipe (docs/design/INVENTORY_CRAFTING_LOOK.md section 9; Morgan's report: a pinned recipe stays on screen as a checklist).
# "Pin" in the chosen recipe's detail puts a small card (the art kit's reading card) at the right edge of the screen, shown with the
# window open or shut: the recipe's name, then each ingredient with what you have of it now (the pack and what crafting may reach) and a
# check mark that ticks as you gather. "Unpin" on the card takes it away. The pin lasts until unpinned or the game closes.

const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")

var view            # the InventoryView that owns this part (src/client/inventory_view.gd)
var number: int = 0  # the pinned recipe, 0 for none
var _card: PanelContainer   # the card (ArtKit.card) on the HUD layer, or null


func _init(owner_view) -> void:
	view = owner_view


func pin(recipe_number: int) -> void:
	number = recipe_number
	refresh()


func unpin() -> void:
	number = 0
	refresh()


# The checklist as text lines (the tests read these): "Name  have / need" per ingredient, and whether each is met.
func lines() -> Array:
	var out: Array = []
	var r: Dictionary = view.recipes.recipe(number) if number != 0 else {}

	if r.is_empty():
		return out

	for need in r["needs"] + r["keeps"]:
		var have: int = view.stock_fill(int(need[0]))
		out.append({"text": "%s  %d / %d" % [view.table.cost_name(int(need[0])), mini(have, int(need[1])), int(need[1])], "done": have >= int(need[1])})

	return out


func refresh() -> void:
	if view._layer == null:
		return

	var r: Dictionary = view.recipes.recipe(number) if number != 0 else {}

	if r.is_empty():
		if is_instance_valid(_card):
			_card.queue_free()

		_card = null
		return

	if is_instance_valid(_card):
		_card.queue_free()

	_card = ArtKit.card(str(r["name"]))
	_card.mouse_filter = Control.MOUSE_FILTER_PASS
	view._layer.add_child(_card)
	_card.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_card.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_card.offset_right = -24.0
	var box: VBoxContainer = _card.get_child(0) as VBoxContainer

	for line in lines():
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(InventoryLook.tick_mark(18, bool(line["done"])))
		row.add_child(ArtKit.card_label(str(line["text"]), "garamond", 18, ArtKit.CREAM if bool(line["done"]) else ArtKit.BAD))
		box.add_child(row)

	var off: Button = Button.new()
	off.text = "Unpin"
	off.flat = true
	off.size_flags_horizontal = Control.SIZE_SHRINK_END
	off.add_theme_font_override("font", ArtKit.font("garamond_semibold"))
	off.add_theme_font_size_override("font_size", 18)
	off.add_theme_color_override("font_color", ArtKit.CREAM)
	off.add_theme_color_override("font_hover_color", ArtKit.HEADING)
	off.pressed.connect(unpin)
	box.add_child(off)
