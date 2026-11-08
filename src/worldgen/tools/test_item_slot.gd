extends SceneTree

# The inventory look, step A (docs/design/INVENTORY_CRAFTING_LOOK.md sections 5, 7, 8, 11): the seven new colours, the durability
# colour, the slot's size and states, the parchment card, and the Reduce motion setting (saved, reset, instant changes).
#   godot --headless --path . --script res://src/worldgen/tools/test_item_slot.gd

const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const DisplaySettings := preload("res://src/client/display_settings.gd")
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")
const ParchmentTooltip := preload("res://src/client/ui/inventory/parchment_tooltip.gd")
const SETTINGS_PATH := "user://test_item_slot_display.cfg"

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func near(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.0001 and absf(a.g - b.g) < 0.0001 and absf(a.b - b.b) < 0.0001


func _initialize() -> void:
	_check_colours()
	_check_slot()
	_check_card()
	_check_reduce_motion()
	print("item slot: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _check_colours() -> void:
	check(near(DynastyTheme.SLOT_BG, Color(0.08, 0.05, 0.035)) and near(DynastyTheme.PARCHMENT, Color(0.93, 0.86, 0.7)) and near(DynastyTheme.INK, Color(0.2, 0.12, 0.07)), "slot, parchment and ink colours as the look doc")
	check(near(DynastyTheme.GOOD, Color(0.42, 0.66, 0.3)) and near(DynastyTheme.WARN, Color(0.92, 0.66, 0.22)) and near(DynastyTheme.BAD, Color(0.75, 0.18, 0.14)) and near(DynastyTheme.MAGIC, Color(0.62, 0.72, 1.0)), "good, warn, bad and magic colours as the look doc")
	check(near(DynastyTheme.wear_color(1.0), DynastyTheme.GOOD) and near(DynastyTheme.wear_color(0.5), DynastyTheme.WARN) and near(DynastyTheme.wear_color(0.0), DynastyTheme.BAD), "durability: green whole, amber at half, red broken")
	check(DynastyTheme.MAGIC.b > DynastyTheme.MAGIC.r and DynastyTheme.PARCHMENT.r > DynastyTheme.PARCHMENT.b, "magic is the only cold colour; parchment is warm")
	var frame: StyleBoxFlat = DynastyTheme.frame_style()
	check(frame.border_width_left == 2 and frame.corner_radius_top_left == 6 and frame.bg_color == DynastyTheme.WOOD_DARK and frame.bg_color.a == 1.0, "the window frame: solid dark wood, 2 px gold edge, 6 px corners")
	var card: StyleBoxFlat = DynastyTheme.parchment_style()
	check(card.bg_color == DynastyTheme.PARCHMENT and card.border_color == DynastyTheme.GOLD_DIM and card.border_width_top == 1, "the parchment card style")


func _check_slot() -> void:
	DisplaySettings.reduce_motion = false
	var slot = ItemSlot.new()
	check(slot.custom_minimum_size == Vector2(64.0, 64.0), "a slot is 64 px at unit 1")
	slot.set_unit(1.5)
	check(slot.custom_minimum_size == Vector2(96.0, 96.0), "and follows the text size (96 px at 1.5)")
	check(slot.is_empty() and slot.focus_mode == Control.FOCUS_ALL, "starts empty and can take keyboard focus")
	var picture: ImageTexture = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	slot.set_item(picture, 7)
	check(not slot.is_empty() and slot.count == 7, "holds an item and its count")
	slot.set_greyed(true)
	var icon: TextureRect = slot.get_child(0) as TextureRect
	check(icon != null and icon.material is ShaderMaterial and absf(icon.modulate.a - ItemSlot.GREY_ALPHA) < 0.0001, "greyed: desaturated at 60 %")
	slot.set_greyed(false)
	slot.set_dragging(true)
	check(icon.material == null and absf(icon.modulate.a - ItemSlot.DRAG_DIM) < 0.0001, "dragging dims the slot to 50 %")
	slot.set_dragging(false)
	check(ItemSlot.key_text(0) == "1" and ItemSlot.key_text(8) == "9" and ItemSlot.key_text(9) == "0", "hotbar keys read 1 to 9, then 0")
	var tip: Object = slot._make_custom_tooltip("Flint knife\nCuts hide and rope\nNeeds: twine 2 / 5")
	check(tip is PanelContainer and (tip as PanelContainer).get_child(0).get_child_count() == 3, "a tooltip is a parchment card with its three lines")
	check(slot._make_custom_tooltip("") == null, "no text, no card")
	check(slot.theme != null and slot.theme.get_stylebox("panel", "TooltipPanel") is StyleBoxEmpty, "the engine's grey tooltip box is cleared")
	(tip as Node).free()
	slot.free()


func _check_card() -> void:
	var card = ParchmentTooltip.from_text("Oak plank\nBuilding wood\n\nMissing: oak log 0 / 1", 1.0)
	var box: VBoxContainer = card.get_child(0) as VBoxContainer
	check(box.get_child_count() == 3, "blank lines are dropped")
	var title: Label = box.get_child(0) as Label
	var need: Label = box.get_child(2) as Label
	check(title.text == "Oak plank" and title.get_theme_color("font_color") == DynastyTheme.INK, "the first line is the name, in ink")
	check(need.get_theme_color("font_color") == DynastyTheme.BAD and need.text.contains("0 / 1"), "a missing line is red and also shows the count")
	card.add_need("Twine", 2, 5, "the oak chest")
	var added: Label = box.get_child(3) as Label
	check(added.text == "Twine 2 / 5  (more in the oak chest)", "a need names the count and the chest that holds more")
	check(card.px(ParchmentTooltip.BODY_PX) >= ParchmentTooltip.MIN_PX, "body text is never under 14 px")
	card.set_lines("Small", ["text"], 0.7)
	check(card.px(ParchmentTooltip.BODY_PX) == ParchmentTooltip.MIN_PX, "at the smallest text size the body stays at 14 px")
	card.free()


func _check_reduce_motion() -> void:
	var settings = DisplaySettings.new()
	settings.path = SETTINGS_PATH
	DisplaySettings.reduce_motion = false
	settings.load_saved()
	check(not DisplaySettings.reduce_motion, "reduce motion is off by default")
	DisplaySettings.reduce_motion = true
	settings.save()
	DisplaySettings.reduce_motion = false
	var back = DisplaySettings.new()
	back.path = SETTINGS_PATH
	back.load_saved()
	check(DisplaySettings.reduce_motion, "turning it on is saved")
	back.reset()
	check(not DisplaySettings.reduce_motion, "reset turns it off")
	DisplaySettings.reduce_motion = true
	var slot = ItemSlot.new()
	slot.flash_new()
	check(slot.shimmer == 0.0, "with reduce motion the new-item shimmer is skipped")
	slot._set_hovered(true, false)
	check(slot.hover == 1.0, "and hover changes at once")
	slot._set_hovered(false, true)
	check(slot.hover == 1.0, "keyboard focus looks the same as hover")
	slot._set_hovered(false, false)
	check(slot.hover == 0.0, "leaving puts it back")
	slot.free()
	DisplaySettings.reduce_motion = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SETTINGS_PATH))
