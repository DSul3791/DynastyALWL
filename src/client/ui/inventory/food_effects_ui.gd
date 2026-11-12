extends RefCounted

# Temporary food effects on the HUD and the replace question (master s3.16 [D16, D17]; Mission 001 phase 7; protocol 110).
# The server decides everything (server_items.gd "Temporary food effects"): this part shows food_effects as lines under the comfort
# line, and food_ask as a small window whose buttons send ACT_EAT back with the answer.
# shortcut: plain placeholder lines and panel in the inventory's colours (NOT visually complete); revisit with Art.

const Net := preload("res://src/stream/terrain_net.gd")
const FoodEffects := preload("res://src/shared/food_effects.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")

var view   # the InventoryView (src/client/inventory_view.gd)
var cfg: Dictionary = FoodEffects.load_config()
var rows: Array = []        # the last food_effects
var _label: Label
var _ask_panel: PanelContainer
var _ask_note: Label
var _ask_row: HFlowContainer


func _init(owner_view) -> void:
	view = owner_view


func is_open() -> bool:
	return _ask_panel != null and _ask_panel.visible


func close() -> void:
	if _ask_panel != null:
		_ask_panel.visible = false


# One HUD line per live effect: "Main meal (Roast joint): Fitness XP +15 %, health regeneration +10 %, 14 min".
func lines() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()

	for row in rows:
		var group: String = FoodEffects.group_at(int(row[0]), cfg)
		var item_id: String = view.table.id_of(int(row[1]))
		out.append("%s (%s): %s, %d min" % [FoodEffects.group_name(group, cfg), view.table.name_of(int(row[1])), FoodEffects.describe(group, int(row[2]), item_id, cfg), int(row[3])])

	return out


func on_effects(new_rows: Array) -> void:
	rows = new_rows

	if _label == null:
		_label = Label.new()
		_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_label.anchor_left = 1.0
		_label.anchor_right = 1.0
		_label.offset_left = -720.0
		_label.offset_right = -20.0
		_label.offset_top = 56.0
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_label.add_theme_font_size_override("font_size", 20)
		_label.add_theme_constant_override("outline_size", 5)
		_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		view._layer.add_child(_label)

	_label.text = "\n".join(lines())
	_label.visible = not rows.is_empty()


func on_ask(slot: int, number: int, groups: PackedInt32Array) -> void:
	if _ask_panel == null:
		var parts: Array = view._storage_ui._panel("EAT")
		_ask_panel = parts[0]
		var box: VBoxContainer = parts[2]
		_ask_note = view._storage_ui._label("", 20, ArtKit.CREAM)
		_ask_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_ask_note.custom_minimum_size = Vector2(520.0, 0.0)
		box.add_child(_ask_note)
		_ask_row = HFlowContainer.new()
		_ask_row.add_theme_constant_override("h_separation", 12)
		box.add_child(_ask_row)

	for child in _ask_row.get_children():
		child.queue_free()

	var group: String = str(FoodEffects.profile(view.table.id_of(number), cfg).get("group", ""))
	var weaker: bool = groups.size() == 1 and FoodEffects.group_at(groups[0], cfg) == group
	_ask_note.text = ("The %s is weaker than the %s effect you have. Replace it?" % [view.table.sentence_name(number), FoodEffects.group_name(group, cfg)]) if weaker else ("You already have three food effects. Which one should the %s (%s) replace?" % [view.table.sentence_name(number), FoodEffects.group_name(group, cfg)])

	for g in groups:
		_add_button("Replace %s" % FoodEffects.group_name(FoodEffects.group_at(g, cfg), cfg), slot, number, g)

	_add_button("Eat, keep my effects", slot, number, FoodEffects.DECLINE)
	_add_button("Cancel", slot, number, -1)
	_ask_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _add_button(text: String, slot: int, number: int, answer: int) -> void:
	var button: Button = view._storage_ui._button(text)
	button.pressed.connect(func() -> void:
		_ask_panel.visible = false

		if answer >= 0 and slot < view.inventory.SLOTS and view.inventory.numbers[slot] == number:   # the food is still where it was asked about
			view.net.inventory_action.rpc_id(1, Net.ACT_EAT, slot, answer, 0, Vector3.ZERO)

		view._storage_ui._release_mouse())
	_ask_row.add_child(button)
