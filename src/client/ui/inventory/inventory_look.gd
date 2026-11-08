extends RefCounted

# The new look of the crafting, inventory and chest window (docs/design/INVENTORY_CRAFTING_LOOK.md sections 3 and 4; Kathleen 8 Nov 2026), step B.
# Behind --new-inventory and off by default until Dino's pictures and Dave's look. With it on:
#   one window of three columns: recipes on the left, the open chest or station in the middle (only while one is open), the pack on the right;
#   the window is solid dark walnut with a 2 px gold frame and brass corner plates; each column has a carved name plate in Cinzel;
#   the pack and chest slots are item_slot.gd (recessed wells, hover glow, parchment tooltips), the hotbar strip uses the same slot;
#   under the chest column, the four bulk buttons in fixed places: Take all, Store all, Stack to nearby, Sort;
#   the carry bar is gold, turning amber then red as the load nears the limit.
# Hand rules (Morgan's report): a click selects and moves inside the pack as before; shift-click moves the stack to the other side;
# double-click uses; right-click opens the slot menu. What is not on the server yet is a marked STUB (see each one).

const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")

const ICON_DIR := "res://assets/ui/item_icons/"     # tools/icon_bake.gd output, committed once Dave has looked at the sheet
const EMBLEM_DIR := "res://assets/ui/emblems/"      # station emblems for the name plates (hammer and anvil, pot, saw): art to come
const PLATE_PX := 4                                 # plate corner radius at unit 1
const CORNER_PLATE_PX := 22.0                       # brass corner plate size at unit 1
const CARRY_WARN := 0.7                             # carry bar: gold below this share of the limit, amber to CARRY_BAD, red from there
const CARRY_BAD := 0.8                              # the same steps as CarryRules.bar_color (the free load ends at 0.8 of the limit)

static var on: bool = OS.get_cmdline_user_args().has("--new-inventory")
static var _icons: Dictionary = {}


# The slot scale for a view: its text size times the window height (InventoryView._px), as a float.
static func unit_of(view) -> float:
	return float(view._px(1000)) / 1000.0


# An item's baked icon, or null while it has none (the slot then shows the name).
static func icon_for(item_id: String) -> Texture2D:
	if item_id == "":
		return null

	if _icons.has(item_id):
		return _icons[item_id]

	var path: String = ICON_DIR + item_id + ".png"
	var texture: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_icons[item_id] = texture
	return texture


# A station's emblem for its plate, or null until the art exists.
static func emblem_for(station: String) -> Texture2D:
	var path: String = EMBLEM_DIR + station + ".png"
	return load(path) as Texture2D if station != "" and ResourceLoader.exists(path) else null


# The window: solid walnut, the calmer 2 px gold frame, the menu theme (cream Garamond, wooden buttons), and parchment for every plain
# tooltip (a slot's own card clears the engine's box in item_slot.tooltip_theme). The panel's own theme (the tooltip text size) is kept on top.
static func style_window(panel: PanelContainer, margin_px: int) -> void:
	var frame: StyleBoxFlat = DynastyTheme.frame_style()
	frame.set_content_margin_all(float(margin_px))
	panel.add_theme_stylebox_override("panel", frame)
	var t: Theme = DynastyTheme.make()

	if panel.theme != null:
		t.merge_with(panel.theme)

	t.set_stylebox("panel", "TooltipPanel", DynastyTheme.parchment_style())
	t.set_color("font_color", "TooltipLabel", DynastyTheme.INK)
	var f: Font = DynastyTheme.text_font()

	if f != null:
		t.set_font("font", "TooltipLabel", f)

	panel.theme = t
	add_corner_plates(panel, margin_px)


# Brass plates on the frame's four corners, like a studded chest (look doc section 4: ornament there and nowhere else).
static func add_corner_plates(panel: PanelContainer, margin_px: int) -> void:
	var plates: Control = Control.new()
	plates.name = "CornerPlates"
	plates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plates.draw.connect(func() -> void:
		var unit: float = maxf(float(margin_px) / 18.0, 0.5)
		var side: float = CORNER_PLATE_PX * unit
		var out: float = float(margin_px) - 1.0
		var r: Rect2 = Rect2(-out, -out, plates.size.x + out * 2.0, plates.size.y + out * 2.0)

		for corner in [r.position, Vector2(r.end.x - side, r.position.y), Vector2(r.position.x, r.end.y - side), r.end - Vector2(side, side)]:
			var at: Vector2 = corner
			plates.draw_rect(Rect2(at, Vector2(side, side)), DynastyTheme.GOLD_DIM.darkened(0.25))
			plates.draw_rect(Rect2(at + Vector2(1.0, 1.0) * unit, Vector2(side, side) - Vector2(2.0, 2.0) * unit), DynastyTheme.GOLD)
			plates.draw_circle(at + Vector2(side, side) * 0.5, 2.5 * unit, DynastyTheme.GOLD_BRIGHT)
			plates.draw_circle(at + Vector2(side, side) * 0.5, 1.2 * unit, DynastyTheme.GOLD_DIM.darkened(0.4)))
	plates.resized.connect(plates.queue_redraw)
	panel.add_child(plates)


# A column's carved name plate: gold Cinzel on a lighter wood board with a thin dim gold edge. The station's emblem, when its art exists,
# sits before the name.
static func plate(label: Label, text: String, px: int, unit: float, station: String = "") -> void:
	label.text = text
	var f: Font = DynastyTheme.heading_font()

	if f != null:
		label.add_theme_font_override("font", f)

	label.add_theme_font_size_override("font_size", px)
	label.add_theme_color_override("font_color", DynastyTheme.HEADING)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.7))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_stylebox_override("normal", plate_style(unit))
	var emblem: Texture2D = emblem_for(station)

	for child in label.get_children():
		if child.name == "Emblem":
			child.queue_free()

	if emblem != null:
		var mark: TextureRect = TextureRect.new()
		mark.name = "Emblem"
		mark.texture = emblem
		mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mark.custom_minimum_size = Vector2(float(px), float(px))
		mark.size = Vector2(float(px), float(px))
		mark.position = Vector2(8.0 * unit, 4.0 * unit)
		label.add_child(mark)


static func plate_style(unit: float) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = DynastyTheme.WOOD
	s.border_color = DynastyTheme.GOLD_DIM
	s.set_border_width_all(1)
	s.set_corner_radius_all(roundi(PLATE_PX * unit))
	s.content_margin_left = 14.0 * unit
	s.content_margin_right = 14.0 * unit
	s.content_margin_top = 4.0 * unit
	s.content_margin_bottom = 4.0 * unit
	return s


# A column's inset board inside the frame: WOOD at about 60 % over the dark walnut, with a 1 px dim gold edge.
static func board_style(margin_px: int) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = DynastyTheme.WOOD_DARK.lerp(DynastyTheme.WOOD, 0.6)
	s.border_color = DynastyTheme.GOLD_DIM
	s.set_border_width_all(1)
	s.set_corner_radius_all(4)
	s.set_content_margin_all(float(margin_px))
	return s


# The carry bar's colour: gold while there is room, amber nearing the limit, heraldic red at it.
static func carry_color(fraction: float) -> Color:
	if fraction < CARRY_WARN:
		return DynastyTheme.GOLD

	if fraction < CARRY_BAD:
		return DynastyTheme.GOLD.lerp(DynastyTheme.WARN, (fraction - CARRY_WARN) / (CARRY_BAD - CARRY_WARN))

	return DynastyTheme.BAD


# The carry bar's track and fill in the window's colours.
static func style_carry_bar(bar: ProgressBar, unit: float) -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = DynastyTheme.SLOT_BG
	track.border_color = DynastyTheme.GOLD_DIM
	track.set_border_width_all(1)
	track.set_corner_radius_all(roundi(3.0 * unit))
	bar.add_theme_stylebox_override("background", track)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = DynastyTheme.GOLD
	fill.set_corner_radius_all(roundi(3.0 * unit))
	bar.add_theme_stylebox_override("fill", fill)


# One item slot for a view, sized to its text.
static func make_slot(view, index: int) -> Control:
	var slot = ItemSlot.new()
	slot.index = index
	slot.set_unit(unit_of(view))
	return slot


# Shows pack or chest slot contents on an item slot: icon (or the name while there is no icon), count, wear or freshness, tooltip.
static func show_stack(view, slot, number: int, count: int, wear: int, tooltip: String) -> void:
	if number == 0:
		slot.set_item(null, 0)
		slot.set_caption("")
		slot.set_wear(1.0)
		slot.tooltip_text = tooltip
		return

	var item_id: String = view.table.id_of(number)
	var texture: Texture2D = icon_for(item_id)
	slot.set_item(texture, count)
	slot.set_caption(view.table.name_of(number) if texture == null else "")
	var fraction: float = 1.0

	if view.table.shelf_units(number) > 0:
		fraction = view.table.freshness(number, wear)
	else:
		var durability: int = int(view.table.entry(item_id).get("durability", 0))     # the same rule as InventoryView.condition

		if durability > 0 and wear > 0:
			fraction = clampf(1.0 - float(wear) / float(durability), 0.0, 1.0)

	slot.set_wear(fraction)
	slot.tooltip_text = tooltip
