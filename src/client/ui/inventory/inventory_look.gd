extends RefCounted

# Shared helpers of the inventory window (docs/ui/inventory_crafting_redesign.md; the frame, panels, plates, wells and cards are drawn
# by art_kit.gd): slot icons and stacks, the carry bar's colour, recipe rows, the chest and keep-out marks, the pinned recipe's ticks,
# the bulk toast and chest glow, made items flying in and the craft ring.
# Hand rules (Morgan's report): a click selects and moves inside the pack as before; shift-click moves the stack to the other side;
# double-click uses; right-click opens the slot menu. What is not on the server yet is a marked STUB (see each one).

const DynastyTheme := preload("res://src/client/ui/dynasty_theme.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")
const SmithingRules := preload("res://src/shared/smithing_rules.gd")

const ICON_DIR := "res://assets/ui/item_icons/"     # tools/icon_bake.gd output, committed once Dave has looked at the sheet
const CARRY_WARN := 0.7                             # carry bar: gold below this share of the limit, amber to CARRY_BAD, red from there
const CARRY_BAD := 0.8                              # the same steps as CarryRules.bar_color (the free load ends at 0.8 of the limit)

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
# `most`: the slot's current maximum durability (Inventory.max_durability), 0 for the row's.
static func show_stack(view, slot, number: int, count: int, wear: int, tooltip: String, most: int = 0) -> void:
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
		var durability: int = most if most > 0 else int(view.table.entry(item_id).get("durability", 0))     # the same rule as InventoryView.condition

		if durability > 0 and wear > 0:
			fraction = clampf(1.0 - float(wear) / float(durability), 0.0, 1.0)

	slot.set_wear(fraction)
	slot.tooltip_text = tooltip


# ---- step C: recipe rows and craft feedback (look doc section 9) ----

const DisplaySettings := preload("res://src/client/display_settings.gd")
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


# The golden line round a recipe row that can be made now (Dave 10 Nov 2026: by hand, or at a working station within 12 m), the same colour, line and
# glow as a pack well at a station (data/ui/station_highlight.json, item_slot.gd).
static func glow_recipe_row(entry: Button, cfg: Dictionary, unit: float) -> void:
	var colour: Color = Color(str(cfg.get("colour", "#ffc83a")))
	var line: int = maxi(roundi(float(cfg.get("line_px", 2.0)) * unit), 1)

	for look in ["normal", "hover", "pressed", "focus"]:
		var box: StyleBoxFlat = entry.get_theme_stylebox(look) as StyleBoxFlat

		if box == null:
			continue

		box = box.duplicate() as StyleBoxFlat
		box.border_color = colour
		box.border_width_left = maxi(box.border_width_left, line)
		box.border_width_top = line
		box.border_width_right = line
		box.border_width_bottom = line
		box.shadow_color = Color(colour, float(cfg.get("glow_alpha", 0.5)))
		box.shadow_size = roundi(float(cfg.get("glow_px", 6.0)) * unit * 0.5)
		entry.add_theme_stylebox_override(look, box)


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


# A small padlock beside the tick of a container ticked "keep out" (crafting leaves it alone).
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
			mark.draw_polyline(PackedVector2Array([Vector2(w * 0.18, w * 0.52), Vector2(w * 0.42, w * 0.76), Vector2(w * 0.84, w * 0.26)]), ArtKit.WEAR_GOOD, maxf(2.0, w * 0.14), true)
		else:
			mark.draw_arc(Vector2(w * 0.5, w * 0.5), w * 0.3, 0.0, TAU, 20, ArtKit.DIM, maxf(1.0, w * 0.08), true))
	return mark


# A short toast at the top of the screen for a bulk button ("12 stacks into 3 chests"), on the art kit's card, gone after TOAST_S.
static func toast(layer: CanvasLayer, text: String) -> Control:
	var card: PanelContainer = ArtKit.card(text)
	card.name = "BulkToast"

	for old in layer.get_children():
		if old.name == "BulkToast":
			old.queue_free()

	layer.add_child(card)
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.offset_top = 40.0

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

	var head: Array = view.craft_entries[0]
	var craft_s: float = float(view.recipes.recipe(int(head[0])).get("craft_s", 0.0)) * (SmithingRules.time_mult(int(head[2])) if head.size() > 2 else 1.0)

	if craft_s <= 0.0:
		return 1.0

	var left_s: float = maxf(float(view._craft_head_end_msec - Time.get_ticks_msec()) / 1000.0, 0.0)
	return clampf(1.0 - left_s / craft_s, 0.0, 1.0)
