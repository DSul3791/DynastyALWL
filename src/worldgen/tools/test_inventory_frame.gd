extends SceneTree

# The inventory window's frame, redesign step 3a (docs/ui/inventory_crafting_redesign.md section 4, v4): three columns placed inside the
# Pack, You and Craft panels under their title plates, clear of the hotbar strip; titles change; an overflowing column is reported.
#   godot --headless --path . --script res://src/worldgen/tools/test_inventory_frame.gd

const ArtKit := preload("res://src/client/ui/art_kit.gd")
const InventoryFrame := preload("res://src/client/ui/inventory/inventory_frame.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var frame: InventoryFrame = InventoryFrame.new()
	root.add_child(frame)
	await process_frame

	for pair in [["Pack", frame.pack_column, ArtKit.PACK], ["You", frame.you_column, ArtKit.YOU], ["Craft", frame.craft_column, ArtKit.CRAFT]]:
		var column: Control = pair[1]
		var panel: Rect2 = pair[2]
		var rect: Rect2 = Rect2(column.position, column.size)
		check(panel.grow(-float(ArtKit.INSET)).encloses(rect), "%s column sits inside its panel's frame and air" % pair[0])
		check(rect.position.y >= 76.0, "%s column starts under the title plate (y %.0f)" % [pair[0], rect.position.y])
		check(rect.end.y <= ArtKit.HOTBAR_TRAY.position.y, "%s column ends above the hotbar tray" % pair[0])

	check(frame.header.position.x > ArtKit.PACK.position.x + 200.0 and frame.header.position.y < 92.0, "the Pack title row (search) sits right of the plate")
	check(frame.mouse_filter == Control.MOUSE_FILTER_STOP, "the frame takes the clicks the world would get")
	check(frame.columns_fit(), "empty columns fit")
	check(frame.fit_report().count("fits") == 3, "and the fit report says so for all three")
	frame.set_title(1, "ALDWIN OF THE FORD")
	check(frame.titles[1] == "ALDWIN OF THE FORD", "the You title takes the character's name")
	var wide: Control = Control.new()
	wide.custom_minimum_size = Vector2(900.0, 10.0)
	frame.pack_column.add_child(wide)
	await process_frame
	check(not frame.columns_fit(), "a 900 px wide child does not fit the 650 px Pack column")
	check(frame.get_combined_minimum_size().x > 1920.0, "the frame then asks for more than the canvas, so the text test sees it")
	var report: String = frame.fit_report()
	check(report.begins_with("pack 900x10 in 650x820 OVER (Control 900x10)") and report.contains("you 0x0 in 408x820 fits"), "the fit report names the column and the control that overflows: " + report)
	wide.queue_free()
	await process_frame
	await process_frame
	check(frame.columns_fit(), "it fits again once the child is gone")
	frame.queue_free()
	print("inventory frame: %d failures" % failures)
	quit(1 if failures > 0 else 0)
