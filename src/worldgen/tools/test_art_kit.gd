extends SceneTree

# The art kit of the inventory redesign, step 2 (docs/ui/inventory_crafting_redesign.md sections 4, 6.4, 8 and 9):
# the layout numbers add up on the 1920 x 1080 canvas; the hotbar strip is 10 keys of 76 centred under the panels;
# every glyph the brief names has a placeholder shape; with no painted art the styleboxes are code-drawn; every piece draws.
#   godot --headless --path . --script res://src/worldgen/tools/test_art_kit.gd

const ArtKit := preload("res://src/client/ui/art_kit.gd")

var failures: int = 0
var drawn: bool = false


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	_check_layout()
	_check_hotbar()
	_check_glyphs()
	_check_colours()
	_check_styleboxes()
	await _check_drawing()
	print("art kit: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _check_layout() -> void:
	var width: float = ArtKit.PACK.size.x + ArtKit.YOU.size.x + ArtKit.CRAFT.size.x + 2.0 * ArtKit.GUTTER + 2.0 * ArtKit.MARGIN
	check(is_equal_approx(width, 1920.0), "Pack 690 + You 448 + Craft 690 + 2 gutters + 2 margins = 1920 (got %s)" % width)
	check(is_equal_approx(ArtKit.YOU.position.x - ArtKit.PACK.end.x, ArtKit.GUTTER), "the gutter between Pack and You is 22")
	check(is_equal_approx(ArtKit.CRAFT.position.x - ArtKit.YOU.end.x, ArtKit.GUTTER), "the gutter between You and Craft is 22")
	check(is_equal_approx(ArtKit.PACK.end.y, 932.0) and is_equal_approx(ArtKit.YOU.end.y, 932.0) and is_equal_approx(ArtKit.CRAFT.end.y, 932.0), "the three panels end at y 932")
	var grid: float = 6.0 * ArtKit.SLOT + 5.0 * ArtKit.SLOT_GAP
	check(is_equal_approx(grid, ArtKit.PACK.size.x - 2.0 * ArtKit.INSET), "6 slots of 100 and 5 gaps of 10 fill the Pack inside (650)")
	var r: Rect2 = ArtKit.grid_rect(Vector2(44, 136), 6, 35, ArtKit.SLOT, ArtKit.SLOT_GAP)
	check(r.end.is_equal_approx(Vector2(694, 786)), "the 36th pack slot ends at (694, 786) (got %s)" % r.end)


func _check_hotbar() -> void:
	var strip: Rect2 = ArtKit.HOTBAR_STRIP
	check(is_equal_approx(strip.size.x, 10.0 * ArtKit.HOT + 9.0 * ArtKit.HOT_GAP), "the strip is 10 slots of 76 and 9 gaps of 10 (850)")
	check(is_equal_approx(strip.get_center().x, 960.0), "the strip is centred on 960")
	check(ArtKit.HOTBAR_TRAY.is_equal_approx(strip.grow(16)), "the tray is 16 px bigger than the strip all round")
	check(is_equal_approx(ArtKit.HOTBAR_TRAY.end.y, 1080.0 - ArtKit.MARGIN), "the tray ends 24 px above the bottom")
	check(ArtKit.HOTBAR_TRAY.position.y - ArtKit.PACK.end.y >= 16.0, "16 px of air between the panels and the tray")
	check(ArtKit.hotbar_slot(9).end.is_equal_approx(strip.end), "the tenth slot ends where the strip ends")
	check(ArtKit.hotbar_key_text(0) == "1" and ArtKit.hotbar_key_text(8) == "9" and ArtKit.hotbar_key_text(9) == "0", "keys read 1 to 9, then 0")


func _check_glyphs() -> void:
	var missing: Array[String] = []

	for glyph in ArtKit.GLYPH_FILE.keys():
		if not ArtKit.has_glyph(glyph):
			missing.append(glyph)

	for table in [ArtKit.STAT_GLYPH, ArtKit.TAB_GLYPH, ArtKit.GEAR_GHOST]:
		for glyph in table.values():
			if not ArtKit.has_glyph(glyph) and not missing.has(glyph):
				missing.append(glyph)

	check(missing.is_empty(), "every glyph in the brief has a placeholder shape (missing: %s)" % ", ".join(missing))
	check(ArtKit.TAB_GLYPH.size() == 11, "11 category tabs: All and the 10 recipe categories")
	check(ArtKit.GEAR_GHOST.size() == 8, "8 gear slots: 6 wear slots and two hands")
	check(not ArtKit.has_glyph("no_such_glyph"), "an unknown glyph has no shape")


func _check_colours() -> void:
	check(ArtKit.STAT_ORDER == ["Health", "Exertion", "Energy", "Temperature", "Food", "Water"], "the six stats keep the game's names (Exertion and Energy)")

	for stat in ArtKit.STAT_ORDER:
		check(ArtKit.STAT_FILL.has(stat) and ArtKit.STAT_GLYPH.has(stat), "%s has a fill and a glyph" % stat)

	check(ArtKit.STAT_FILL["Exertion"] == Color("#C08F3E"), "Exertion fill is #C08F3E")
	check(ArtKit.wear_colour(0.9) == ArtKit.WEAR_GOOD and ArtKit.wear_colour(0.5) == ArtKit.WEAR_WORN and ArtKit.wear_colour(0.1) == ArtKit.BAD, "durability colours: good, worn, nearly broken")

	for which in ["cinzel", "cinzel_bold", "garamond", "garamond_semibold"]:
		check(ArtKit.font(which) != null, "font %s loads" % which)


func _check_styleboxes() -> void:
	ArtKit.clear_cache()
	var painted: bool = ResourceLoader.exists(ArtKit.ART_DIR + "well.png")
	var well: StyleBox = ArtKit.stylebox_well()
	check(well != null, "a well stylebox")

	if not painted:
		check(well is StyleBoxFlat and (well as StyleBoxFlat).bg_color == ArtKit.WELL, "with no painted well, the placeholder is #120C08")

	var selected: StyleBox = ArtKit.stylebox_well(true)
	check(selected != null, "a selected well stylebox")

	if selected is StyleBoxFlat:
		check((selected as StyleBoxFlat).border_color == ArtKit.GOLD_BRIGHT, "the selected placeholder has the gold rim")

	for state in 3:
		check(ArtKit.stylebox_raised(state) != null, "a raised stylebox, state %d" % state)

	check(ArtKit.stylebox_brass() != null and ArtKit.stylebox_brass(true) != null, "brass button styleboxes")
	check(ArtKit.art("no_such_piece") == null, "a piece that is not painted yet is null")


func _check_drawing() -> void:
	var canvas: Control = Control.new()
	canvas.size = Vector2(1920, 1080)
	canvas.draw.connect(_draw_everything.bind(canvas))
	root.add_child(canvas)
	canvas.queue_redraw()

	for i in 3:
		await process_frame

	check(drawn, "every piece draws without a script error")
	canvas.queue_free()


func _draw_everything(ci: Control) -> void:
	ArtKit.draw_backdrop(ci, Rect2(0, 0, 1920, 1080))

	for panel in [ArtKit.PACK, ArtKit.YOU, ArtKit.CRAFT]:
		ArtKit.draw_panel(ci, panel)

	var plate: Rect2 = ArtKit.draw_title_plate(ci, 72, 30, "PACK")
	check(plate.size.x > 60.0 and is_equal_approx(plate.size.y, 46.0), "the title plate is the title + 60 wide and 46 tall")
	var long_plate: Rect2 = ArtKit.draw_title_plate(ci, 960, 30, "ALDWIN OF THE FORD", true, 368)
	check(long_plate.size.x <= 368.0 + 0.5 and is_equal_approx(long_plate.get_center().x, 960.0), "a long name steps down to fit 368 and stays centred")
	ArtKit.draw_rule(ci, 44, 694, 790)
	ArtKit.draw_well(ci, Rect2(44, 136, 100, 100))
	ArtKit.draw_well(ci, Rect2(154, 136, 100, 100), true)
	ArtKit.draw_well(ci, Rect2(264, 136, 100, 100), false, true)
	ArtKit.draw_icon(ci, null, Rect2(44, 136, 100, 100))
	ArtKit.draw_wear(ci, Rect2(44, 136, 100, 100), 0.4)
	ArtKit.draw_count(ci, Rect2(44, 136, 100, 100), 24, true)
	ArtKit.draw_raised(ci, Rect2(1490, 100, 386, 812))
	ArtKit.draw_raised(ci, Rect2(1226, 100, 48, 48), true)
	var key_w: float = ArtKit.draw_keycap(ci, Vector2(44, 882), "E")
	check(key_w >= 26.0, "a keycap is at least 26 wide")
	ArtKit.draw_keycap(ci, Vector2(300, 882), "1–0")
	var y: float = 630.0

	for stat in ArtKit.STAT_ORDER:
		ArtKit.draw_glyph(ci, ArtKit.STAT_GLYPH[stat], Rect2(764, y - 13, 26, 26), ArtKit.ENGRAVED)
		ArtKit.draw_bar(ci, Rect2(906, y - 5, 170, 10), 0.6, ArtKit.STAT_FILL[stat])
		y += 46.0

	var x: float = 20.0

	for glyph in ArtKit.GLYPH_FILE.keys():
		ArtKit.draw_glyph(ci, glyph, Rect2(x, 1050, 28, 28), ArtKit.CREAM, ArtKit.RAISED)
		x += 32.0

	ArtKit.draw_hotbar_tray(ci)

	for i in ArtKit.HOT_KEYS:
		var slot: Rect2 = ArtKit.hotbar_slot(i)
		ArtKit.draw_well(ci, slot, i == 0)
		ArtKit.draw_key_number(ci, slot, i)

	ArtKit.draw_craft_button(ci, Rect2(1504, 848, 360, 58), true, false, 0.4)
	ArtKit.draw_craft_button(ci, Rect2(1504, 848, 360, 58), false, true)
	ArtKit.draw_missing(ci, Rect2(1504, 400, 80, 80))
	ArtKit.draw_corner(ci, Vector2(100, 100), true, true)
	drawn = true
