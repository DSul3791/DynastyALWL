extends SceneTree

# The pack's info strip, redesign step 3b (docs/ui/inventory_crafting_redesign.md section 4.1): it shows an item's name, one line of
# description and its facts; a long description is cut to one line; with nothing to show it draws a hint; pack slots are 100 px, and
# the slot scroll shows whole rows only.
#   godot --headless --path . --script res://src/worldgen/tools/test_info_strip.gd

const InfoStrip := preload("res://src/client/ui/inventory/info_strip.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")
const ItemSlot := preload("res://src/client/ui/inventory/item_slot.gd")
const PackGrid := preload("res://src/client/ui/inventory/pack_grid.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var strip: InfoStrip = InfoStrip.new()
	strip.size = Vector2(650.0, InfoStrip.HEIGHT)
	root.add_child(strip)
	check(strip.custom_minimum_size.y == InfoStrip.HEIGHT and strip.title == "", "an empty strip is 92 px tall and shows the hint")
	strip.show_item(null, "Bucket", "A wooden bucket bound with cord. Holds eight litres.", [["Holds", "8 L"], ["Condition", "80 %"]])
	check(strip.title == "Bucket" and strip.facts.size() == 2, "it takes an item's name and facts")
	await process_frame
	strip.clear()
	check(strip.title == "" and strip.icon == null and strip.facts.is_empty(), "clear empties it")
	var font: Font = ArtKit.font("garamond")
	var long_text: String = "A very long description that goes on and on about the item and what it does and where it came from and more."
	var cut: String = InfoStrip._fit(font, long_text, 300.0)
	check(cut.ends_with("…") and font.get_string_size(cut, HORIZONTAL_ALIGNMENT_LEFT, -1, InfoStrip.BODY_PX).x <= 300.0, "a long description is cut to one line with an ellipsis")
	check(InfoStrip._fit(font, "Short.", 300.0) == "Short.", "a short one is left alone")
	check(InfoStrip._fit(font, "First line\nSecond line", 600.0) == "First line", "only the first line shows")
	var slot: ItemSlot = ItemSlot.new()
	slot.set_unit(PackGrid.SLOT_UNIT)
	check(slot.custom_minimum_size.is_equal_approx(Vector2(100.0, 100.0)), "a pack slot is 100 canvas px")
	check(6.0 * 100.0 + 5.0 * ArtKit.SLOT_GAP == 650.0, "6 slots and 5 gaps fill the 650 px Pack column")
	var grid: PackGrid = PackGrid.new(null)
	grid._slot_scroll = ScrollContainer.new()
	root.add_child(grid._slot_scroll)
	grid.fit_rows(Vector2(650.0, 560.0))
	check(grid._slot_scroll.size.y == 540.0, "the slot scroll shows whole rows: 5 in 560 px")
	grid.fit_rows(Vector2(650.0, 500.0))
	check(grid._slot_scroll.size.y == 430.0, "and 4, never 4.5, in 500 px (text 1.2's taller header)")
	grid.fit_rows(Vector2(650.0, 40.0))
	check(grid._slot_scroll.size.y == 100.0, "and at least one row")
	grid._slot_scroll.queue_free()
	root.add_child(slot)
	slot.set_marked(ItemSlot.MARK_GOLD)
	await process_frame
	await process_frame
	slot.queue_free()
	strip.queue_free()
	print("info strip: %d failures" % failures)
	quit(1 if failures > 0 else 0)
