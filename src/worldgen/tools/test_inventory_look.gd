extends SceneTree

# The inventory look, step B (docs/design/INVENTORY_CRAFTING_LOOK.md sections 3 and 4): behind --new-inventory and off by default; the window
# frame, its corner plates and parchment tooltips; the name plates; the carry bar's colours; slots with no icon yet show the item's name.
#   godot --headless --path . --script res://src/worldgen/tools/test_inventory_look.gd

const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const InventoryLook := preload("res://src/client/ui/inventory/inventory_look.gd")
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")
const CarryRules := preload("res://src/shared/carry_rules.gd")
const PinnedRecipe := preload("res://src/client/ui/inventory/pinned_recipe.gd")
const RecipeList := preload("res://src/client/ui/inventory/recipe_list.gd")


# Just enough of an InventoryView for the step C parts: a two-ingredient recipe, names, and the stock in reach.
class FakeTable:
	func name_of(number: int) -> String:
		return {1: "Twine", 2: "Stick", 9: "Snare"}.get(number, "?")


class FakeRecipes:
	func recipe(number: int) -> Dictionary:
		return {"number": 9, "name": "Snare", "needs": [[1, 5], [2, 2]], "keeps": [], "craft_s": 4.0, "gives": [9, 1]} if number == 9 else {}


class FakeView:
	var table: FakeTable = FakeTable.new()
	var recipes: FakeRecipes = FakeRecipes.new()
	var stock: Dictionary = {1: 2, 2: 3}
	var craft_entries: Array = []
	var _craft_head_end_msec: int = 0
	var _layer: CanvasLayer = null

	func stock_fill(number: int) -> int:
		return int(stock.get(number, 0))

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	check(not InventoryLook.on, "the new look is off unless --new-inventory is given")
	_check_window()
	_check_plate()
	_check_carry()
	_check_slot_extras()
	_check_step_c()
	print("inventory look: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _check_window() -> void:
	var panel: PanelContainer = PanelContainer.new()
	var old: Theme = Theme.new()
	old.set_font_size("font_size", "TooltipLabel", 21)
	panel.theme = old
	InventoryLook.style_window(panel, 18)
	var frame: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	check(frame != null and frame.border_width_top == 2 and frame.bg_color == DynastyTheme.WOOD_DARK and frame.bg_color.a == 1.0, "the window is solid walnut with a 2 px gold frame")
	check(panel.get_node_or_null("CornerPlates") != null, "brass corner plates on the frame")
	check(panel.theme.get_font_size("font_size", "TooltipLabel") == 21, "the window's own tooltip text size is kept")
	var tip: StyleBoxFlat = panel.theme.get_stylebox("panel", "TooltipPanel") as StyleBoxFlat
	check(tip != null and tip.bg_color == DynastyTheme.PARCHMENT and panel.theme.get_color("font_color", "TooltipLabel") == DynastyTheme.INK, "plain tooltips are ink on parchment")
	check(panel.theme.get_stylebox("normal", "Button") is StyleBoxFlat, "buttons are the menu's wooden buttons")
	panel.free()


func _check_plate() -> void:
	var label: Label = Label.new()
	InventoryLook.plate(label, "Pack", 30, 1.0)
	var board: StyleBoxFlat = label.get_theme_stylebox("normal") as StyleBoxFlat
	check(label.text == "Pack" and label.get_theme_color("font_color") == DynastyTheme.HEADING, "a name plate is gold lettering")
	check(board != null and board.bg_color == DynastyTheme.WOOD and board.border_color == DynastyTheme.GOLD_DIM, "on a wood board with a dim gold edge")
	check(label.get_node_or_null("Emblem") == null, "no emblem until its art exists")
	label.free()
	check(InventoryLook.emblem_for("") == null and InventoryLook.icon_for("") == null, "no station, no item: no picture")
	check(InventoryLook.icon_for("no_such_item_here") == null, "an item without a baked icon has none (the slot shows its name)")


func _check_carry() -> void:
	check(InventoryLook.carry_color(0.3) == DynastyTheme.GOLD, "the carry bar is gold while there is room")
	check(InventoryLook.carry_color(0.9) == DynastyTheme.BAD, "and red at the limit")
	var mid: Color = InventoryLook.carry_color(0.75)
	check(mid != DynastyTheme.GOLD and mid != DynastyTheme.BAD, "amber between")
	# The steps match the game's own (CarryRules.bar_color turns at 0.7 and 0.8).
	check(CarryRules.bar_color(InventoryLook.CARRY_WARN - 0.01) != CarryRules.bar_color(InventoryLook.CARRY_WARN), "it turns where the old bar turned amber")
	check(CarryRules.bar_color(InventoryLook.CARRY_BAD - 0.01) != CarryRules.bar_color(InventoryLook.CARRY_BAD), "and where it turned red")
	var bar: ProgressBar = ProgressBar.new()
	InventoryLook.style_carry_bar(bar, 1.0)
	check((bar.get_theme_stylebox("background") as StyleBoxFlat).bg_color == DynastyTheme.SLOT_BG, "its track is the slot colour")
	bar.free()


func _check_slot_extras() -> void:
	var slot = ItemSlot.new()
	slot.set_item(null, 3)
	slot.set_caption("Oak log")
	check(not slot.is_empty() and slot.caption == "Oak log", "a stack with no icon yet shows its name")
	slot.set_marked(ItemSlot.MARK_GOLD)
	check(slot.marked == ItemSlot.MARK_GOLD, "the held or selected slot is marked")
	slot.set_key_number(9)
	check(slot.key_number == 9 and ItemSlot.key_text(slot.key_number) == "0", "a hotbar slot carries its key")
	slot.free()


func _check_step_c() -> void:
	var view: FakeView = FakeView.new()
	var pinned = PinnedRecipe.new(view)
	pinned.number = 9
	var lines: Array = pinned.lines()
	check(lines.size() == 2 and str(lines[0]["text"]) == "Twine  2 / 5" and not bool(lines[0]["done"]), "the pinned card lists what is short, with the count")
	check(bool(lines[1]["done"]) and str(lines[1]["text"]) == "Stick  2 / 2", "and ticks what is met")
	view.stock[1] = 5
	check(bool(pinned.lines()[0]["done"]), "it ticks once you have gathered enough")
	view.stock[1] = 2
	var list = RecipeList.new(view)
	check(list.missing_text(view.recipes.recipe(9)) == "needs twine 2 / 5", "a dim recipe row says what it needs, with the count")
	view.stock[2] = 0
	check(list.missing_text(view.recipes.recipe(9)) == "needs twine 2 / 5 and 1 more", "and how many more are short")
	check(InventoryLook.bulk_text(2, 12, 3) == "12 stacks into 3 chests" and InventoryLook.bulk_text(1, 1, 1) == "Stored 1 stack", "the bulk toast's words")
	check(InventoryLook.bulk_text(0, 0, 1) == "Nothing to take", "an empty take says so")
	var row: StyleBoxFlat = InventoryLook.recipe_row_style(true, false, 1.0)
	var dim: StyleBoxFlat = InventoryLook.recipe_row_style(false, false, 1.0)
	check(row.border_width_left == 4 and row.border_color == DynastyTheme.GOLD and dim.border_width_left == 1, "a makeable row has the gold bar on its left, the others none")
	check(InventoryLook.craft_fraction(view) == 0.0, "no craft queued: the ring is empty")
	view.craft_entries = [[9, 1]]
	view._craft_head_end_msec = Time.get_ticks_msec() + 2000
	var half: float = InventoryLook.craft_fraction(view)
	check(half > 0.4 and half < 0.6, "halfway through a 4 s craft the ring is half full (%.2f)" % half)
