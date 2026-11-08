extends RefCounted

# The new look of the crafting, inventory and chest window (docs/design/INVENTORY_CRAFTING_LOOK.md sections 3 and 4; Kathleen 8 Nov 2026), steps B and C (section 9: recipe rows, chest marks, the keep-out lock, craft ring, made items flying in, the bulk toast and chest glow, the pinned recipe).
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


# ---- step C: recipe rows and craft feedback (look doc section 9) ----

const DisplaySettings := preload("res://src/client/display_settings.gd")
const ParchmentTooltip := preload("res://src/client/ui/inventory/parchment_tooltip.gd")
const TOAST_S := 2.0
const GLOW_S := 1.0
const GLOW_ENERGY := 1.6
const GLOW_RANGE_M := 2.5
const GLOW_COLOR := Color(1.0, 0.78, 0.45)
const FLY_S := 0.25
const POP_S := 0.15
const POP_SCALE := 1.15


# A recipe row: makeable rows carry a warm gold bar on their left edge; the others are plain and dim (the row's text says what is missing).
static func recipe_row_style(makeable: bool, chosen: bool, unit: float) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = DynastyTheme.WOOD_LIT if chosen else (DynastyTheme.WOOD if makeable else DynastyTheme.WOOD_DARK)
	s.border_color = DynastyTheme.GOLD if makeable else DynastyTheme.GOLD_DIM.darkened(0.3)
	s.border_width_left = roundi((4.0 if makeable else 1.0) * unit)
	s.border_width_top = 0
	s.border_width_bottom = 1
	s.border_width_right = 0
	s.set_corner_radius_all(roundi(3.0 * unit))
	s.content_margin_left = 12.0 * unit
	s.content_margin_right = 8.0 * unit
	return s


static func style_recipe_row(entry: Button, makeable: bool, chosen: bool, unit: float) -> void:
	entry.modulate = Color.WHITE
	var normal: StyleBoxFlat = recipe_row_style(makeable, chosen, unit)
	var hover: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	hover.bg_color = DynastyTheme.WOOD_LIT
	hover.border_color = DynastyTheme.GOLD_BRIGHT if makeable else DynastyTheme.GOLD_DIM
	var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
	pressed.bg_color = DynastyTheme.WOOD_PRESSED
	pressed.content_margin_left += 2.0 * unit      # the row presses in by 2 px
	pressed.content_margin_top = 2.0 * unit
	entry.add_theme_stylebox_override("normal", normal)
	entry.add_theme_stylebox_override("hover", hover)
	entry.add_theme_stylebox_override("pressed", pressed)
	entry.add_theme_stylebox_override("focus", hover)
	entry.flat = false
	var ink: Color = DynastyTheme.CREAM if makeable else DynastyTheme.CREAM_DIM
	entry.add_theme_color_override("font_color", ink)
	entry.add_theme_color_override("font_hover_color", DynastyTheme.GOLD_BRIGHT if makeable else DynastyTheme.CREAM)
	entry.add_theme_color_override("font_pressed_color", DynastyTheme.GOLD)


# A tiny chest drawn beside an ingredient that comes from a chest in reach (like Dragonwilds' linked marker).
static func chest_mark(px: int) -> Control:
	var mark: Control = Control.new()
	mark.name = "ChestMark"
	mark.custom_minimum_size = Vector2(float(px), float(px))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.tooltip_text = "Some of this comes from your chests nearby"
	mark.draw.connect(func() -> void:
		var w: float = mark.size.x
		var body: Rect2 = Rect2(w * 0.1, w * 0.38, w * 0.8, w * 0.5)
		mark.draw_rect(Rect2(w * 0.1, w * 0.2, w * 0.8, w * 0.2), DynastyTheme.WOOD_LIT)
		mark.draw_rect(body, DynastyTheme.WOOD_LIT)
		mark.draw_rect(Rect2(w * 0.1, w * 0.36, w * 0.8, w * 0.06), DynastyTheme.GOLD)
		mark.draw_rect(Rect2(w * 0.44, w * 0.32, w * 0.12, w * 0.18), DynastyTheme.GOLD_BRIGHT)
		mark.draw_rect(Rect2(w * 0.1, w * 0.2, w * 0.8, w * 0.68), DynastyTheme.GOLD_DIM, false, maxf(1.0, w * 0.06)))
	return mark


# A small padlock for the plate of a container ticked "keep out" (crafting leaves it alone).
static func lock_mark(px: int) -> Control:
	var mark: Control = Control.new()
	mark.name = "Lock"
	mark.custom_minimum_size = Vector2(float(px), float(px))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func() -> void:
		var w: float = mark.size.x
		mark.draw_arc(Vector2(w * 0.5, w * 0.42), w * 0.22, PI, TAU, 16, DynastyTheme.GOLD, maxf(1.5, w * 0.1), true)
		mark.draw_rect(Rect2(w * 0.2, w * 0.42, w * 0.6, w * 0.45), DynastyTheme.GOLD)
		mark.draw_circle(Vector2(w * 0.5, w * 0.6), w * 0.07, DynastyTheme.WOOD_DARK))
	return mark


# A check mark for the pinned recipe card: green when the need is met, an empty ring while it is not.
static func tick_mark(px: int, done: bool) -> Control:
	var mark: Control = Control.new()
	mark.custom_minimum_size = Vector2(float(px), float(px))
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(func() -> void:
		var w: float = mark.size.x

		if done:
			mark.draw_polyline(PackedVector2Array([Vector2(w * 0.18, w * 0.52), Vector2(w * 0.42, w * 0.76), Vector2(w * 0.84, w * 0.26)]), DynastyTheme.GOOD, maxf(2.0, w * 0.14), true)
		else:
			mark.draw_arc(Vector2(w * 0.5, w * 0.5), w * 0.3, 0.0, TAU, 20, DynastyTheme.INK, maxf(1.0, w * 0.08), true))
	return mark


# A short parchment toast at the top of the screen for a bulk button ("12 stacks into 3 chests"), gone after TOAST_S.
static func toast(layer: CanvasLayer, text: String, unit: float) -> Control:
	var card = ParchmentTooltip.new()
	card.set_lines(text, [], unit)
	card.name = "BulkToast"

	for old in layer.get_children():
		if old.name == "BulkToast":
			old.queue_free()

	layer.add_child(card)
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.offset_top = 40.0 * unit

	if not card.is_inside_tree():
		return card

	var tween: Tween = card.create_tween()

	if DisplaySettings.reduce_motion:
		tween.tween_interval(TOAST_S)
	else:
		tween.tween_interval(TOAST_S - 0.4)
		tween.tween_property(card, "modulate:a", 0.0, 0.4)

	tween.tween_callback(card.queue_free)
	return card


# The words of a bulk toast. Kinds as Net.ACT_BULK: 0 Take all, 1 Store all, 2 Stack to nearby, 3 Sort.
static func bulk_text(kind: int, stacks: int, containers: int) -> String:
	var stack_words: String = "%d stack%s" % [stacks, "" if stacks == 1 else "s"]
	var chest_words: String = "%d chest%s" % [containers, "" if containers == 1 else "s"]

	match kind:
		0:
			return "Took %s" % stack_words if stacks > 0 else "Nothing to take"
		1:
			return "Stored %s" % stack_words if stacks > 0 else "Nothing to store"
		2:
			return "%s into %s" % [stack_words, chest_words] if stacks > 0 else "Nothing matches your chests nearby"

	return "Sorted"


# Each chest that took something glows warm for a moment in the world, so you can see where it went.
static func glow_chests(world_root: Node3D, positions: Array) -> void:
	if world_root == null or not world_root.is_inside_tree():
		return

	for at in positions:
		var light: OmniLight3D = OmniLight3D.new()
		light.light_color = GLOW_COLOR
		light.light_energy = GLOW_ENERGY
		light.omni_range = GLOW_RANGE_M
		light.shadow_enabled = false
		world_root.add_child(light)
		var spot: Vector3 = at
		light.global_position = spot + Vector3(0.0, 0.6, 0.0)
		var tween: Tween = light.create_tween()

		if DisplaySettings.reduce_motion:
			tween.tween_interval(GLOW_S * 0.6)
		else:
			tween.tween_property(light, "light_energy", 0.0, GLOW_S).set_ease(Tween.EASE_IN)

		tween.tween_callback(light.queue_free)


# A made item pops and flies from where it was made to the slot it lands in (look doc section 9). Reduce motion: the slot only shimmers.
static func fly_to(layer: CanvasLayer, from_global: Vector2, slot: Control, texture: Texture2D, caption: String, unit: float) -> void:
	if slot == null or not slot.is_inside_tree() or DisplaySettings.reduce_motion:
		if slot != null and slot.has_method("flash_new"):
			slot.call("flash_new")
		return

	var side: float = 52.0 * unit
	var picture: Control

	if texture != null:
		var rect: TextureRect = TextureRect.new()
		rect.texture = texture
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture = rect
	else:
		var word: Label = Label.new()
		word.text = caption
		word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		word.add_theme_color_override("font_color", DynastyTheme.GOLD_BRIGHT)
		word.add_theme_font_size_override("font_size", maxi(10, roundi(14.0 * unit)))
		picture = word

	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.size = Vector2(side, side)
	picture.pivot_offset = Vector2(side, side) * 0.5
	layer.add_child(picture)
	picture.global_position = from_global - Vector2(side, side) * 0.5
	var target: Vector2 = slot.global_position + (slot.size - Vector2(side, side)) * 0.5
	var tween: Tween = picture.create_tween()
	tween.tween_property(picture, "scale", Vector2(POP_SCALE, POP_SCALE), POP_S * 0.5)
	tween.tween_property(picture, "scale", Vector2.ONE, POP_S * 0.5)
	tween.tween_property(picture, "global_position", target, FLY_S).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func() -> void:
		picture.queue_free()

		if is_instance_valid(slot) and slot.has_method("flash_new"):
			slot.call("flash_new"))


# A gold ring round the head of the craft queue, filling as the craft works (the head's end time and the recipe's craft time).
static func craft_ring(view, px: int) -> Control:
	var ring: Control = Control.new()
	ring.name = "CraftRing"
	ring.custom_minimum_size = Vector2(float(px), float(px))
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.draw.connect(func() -> void:
		var w: float = ring.size.y
		var centre: Vector2 = Vector2(w * 0.5, w * 0.5)
		var radius: float = w * 0.38
		var thick: float = maxf(2.0, w * 0.1)
		ring.draw_arc(centre, radius, 0.0, TAU, 32, DynastyTheme.SLOT_BG, thick, true)
		var fraction: float = craft_fraction(view)

		if fraction > 0.0:
			ring.draw_arc(centre, radius, -PI * 0.5, -PI * 0.5 + TAU * fraction, 32, DynastyTheme.GOLD, thick, true))
	ring.tree_entered.connect(func() -> void:
		if not ring.get_tree().process_frame.is_connected(ring.queue_redraw):
			ring.get_tree().process_frame.connect(ring.queue_redraw))
	return ring


# How far the head craft is: 0 just started, 1 done.
static func craft_fraction(view) -> float:
	if view.craft_entries.is_empty():
		return 0.0

	var craft_s: float = float(view.recipes.recipe(int(view.craft_entries[0][0])).get("craft_s", 0.0))

	if craft_s <= 0.0:
		return 1.0

	var left_s: float = maxf(float(view._craft_head_end_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
	return clampf(1.0 - left_s / craft_s, 0.0, 1.0)
