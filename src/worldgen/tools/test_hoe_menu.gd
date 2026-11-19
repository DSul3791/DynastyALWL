extends SceneTree
# Headless check of the hoe's right-click list (src/client/held_item.gd, BugsList_Current.md entry 4; Dave's play test 19 Nov 2026: the list began at
# the middle of the screen, ran off the right edge with every action's explanation on its line, and lay over the hotbar and its caption).
# At every text size (display_settings.gd TEXT_SCALES) the plate is inside the window, above the caption, the rows
# are the six short names in Dave's order with only the highlighted one marked, and the explanation shown is the highlighted action's. A long plant
# list shows a window of rows that keeps the highlighted row on the plate.
# With a window (not --headless) and `-- --pictures=DIR` it also saves hoe_menu_<text size>.png at 1920 x 1080 over the hotbar tray, for Dave to see.

const HeldItem := preload("res://src/client/held_item.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var failures: int = 0


class FakeInventory:
	extends RefCounted
	var numbers: Array = []
	var counts: Array = []
	var slot_count: int = 30

	func inst_of(_slot: int) -> Dictionary:
		return {}


class FakeView:
	extends Node
	var table
	var inventory = FakeInventory.new()
	var scale: float = 1.0

	func refresh_hotbar() -> void:
		pass

	func _on_notice(_text: String) -> void:
		pass

	func text_px(size: int) -> int:   # inventory_view.gd: the size times the player's text size, never under 16 for a font
		return maxi(int(round(float(size) * scale)), 16)

	func fire_light_near(_point: Vector3, _radius: float) -> bool:
		return false

	func edible_slot(_slot: int) -> bool:
		return false

	func is_broken(_slot: int) -> bool:
		return false

	func key_slot(_key: int) -> int:
		return -1


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	run.call_deferred()


# The plate as laid out, after the containers have sorted.
func _plate(held) -> Rect2:
	await process_frame
	await process_frame
	return held._hoe_menu_panel.get_global_rect()


func _shown_rows(held) -> Array:
	var shown: Array = []

	for label in held._hoe_menu_rows.get_children():
		if label.visible:
			shown.append(label)

	return shown


func run() -> void:
	var table = ItemTableScript.load_default()
	var view: FakeView = FakeView.new()
	view.table = table
	view.inventory.numbers.resize(30)
	view.inventory.numbers.fill(0)
	view.inventory.counts.resize(30)
	view.inventory.counts.fill(0)
	root.add_child(view)
	var camera: Camera3D = Camera3D.new()
	view.add_child(camera)
	var world: Node3D = Node3D.new()
	view.add_child(world)
	var layer: CanvasLayer = CanvasLayer.new()
	view.add_child(layer)
	var held = HeldItem.new()
	view.add_child(held)
	await process_frame
	held.setup(view, null, camera, world, layer, Callable())
	held.set_process(false)   # its frame step closes the list when no hoe is in hand; the list is driven by hand here
	held._label.text = "Level (right click: choose what it does)"   # the caption above the hotbar the plate must stay above
	var pictures: String = ""

	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--pictures="):
			pictures = arg.trim_prefix("--pictures=")

	if pictures != "" and DisplayServer.get_name() != "headless":
		await _save_pictures(held, view, layer, pictures)
	var names: Array = []

	for mode in HeldItem.HOE_MODES:
		names.append(str(mode["name"]))

	for window in [Vector2i(1920, 1080)]:   # the game draws its HUD on a 1920 x 1080 canvas at any window size (display_settings.gd)
		root.size = window
		await process_frame

		for scale in [0.7, 0.85, 1.0, 1.2]:
			view.scale = scale
			held.hoe_mode = "till"
			held._hoe_menu_open_now("modes")
			var plate: Rect2 = await _plate(held)
			var screen: Rect2 = layer.get_viewport().get_visible_rect()
			var tag: String = "window %dx%d, text %.2f" % [screen.size.x, screen.size.y, scale]
			var caption_top: float = screen.size.y - HeldItem.LABEL_ABOVE - held._label.get_theme_font("font").get_height(20)
			_check(screen.encloses(plate), "%s: the plate %s is inside the window" % [tag, str(plate)])
			_check(plate.end.y <= caption_top + 0.5, "%s: the plate ends above the caption over the hotbar (%.0f <= %.0f)" % [tag, plate.end.y, caption_top])
			_check(absf(plate.get_center().x - screen.size.x / 2.0) < 1.0, "%s: the plate is centred" % tag)
			var rows: Array = _shown_rows(held)
			var texts: Array = rows.map(func(label: Label) -> String: return label.text)
			var expected: Array = []

			for n in names.size():
				expected.append("%d. %s" % [n + 1, names[n]])

			_check(texts == expected, "%s: the rows are the six short names in order: %s" % [tag, str(texts)])
			var marked: Array = rows.filter(func(label: Label) -> bool: return label.get_theme_stylebox("normal") is StyleBoxFlat)
			_check(marked.size() == 1 and marked[0].text == "3. Till Garden Grid - 20m Edge Blend", "%s: only the current action is marked" % tag)
			_check(held._hoe_menu_help.text.begins_with("Till Garden Grid - 20m Edge Blend: one left click"), "%s: the explanation is the marked action's" % tag)
			_check(held._hoe_menu_help.get_line_count() >= 2 and held._hoe_menu_help.get_visible_line_count() == held._hoe_menu_help.get_line_count(), "%s: every line of the explanation is shown (%d of %d)" % [tag, held._hoe_menu_help.get_visible_line_count(), held._hoe_menu_help.get_line_count()])

			for label in rows:
				_check(label.size.x <= plate.size.x, "%s: row '%s' is no wider than the plate" % [tag, label.text])

			held.wheel(true)
			_check(held._hoe_menu_help.text.begins_with("Till Soil 2m:"), "%s: the wheel moves the mark and the explanation with it" % tag)
			plate = await _plate(held)
			_check(screen.encloses(plate), "%s: still inside the window after the wheel" % tag)
			held._hoe_menu_close()

	# A long plant list at the largest text: a window of rows round the highlighted one, still inside the window and above the caption.
	view.scale = 1.5
	held._hoe_menu_open = true
	held._hoe_menu_panel.visible = true
	var plants: Array = []

	for n in 40:
		plants.append("Plant number %d with a rather long name to see it trimmed (%d)" % [n, n])

	held._hoe_menu_show("What to plant?", plants, 25, "Plant on tilled soil.", "Wheel: move    Left click: choose    Right click: back")
	var long_plate: Rect2 = await _plate(held)
	var view_rect: Rect2 = layer.get_viewport().get_visible_rect()
	var shown: Array = _shown_rows(held)
	_check(view_rect.encloses(long_plate), "long list: the plate %s is inside the window" % str(long_plate))
	_check(shown.size() < plants.size() and shown.size() >= 3, "long list: %d of 40 rows shown" % shown.size())
	_check(shown.any(func(label: Label) -> bool: return label.text == plants[25] and label.get_theme_stylebox("normal") is StyleBoxFlat), "long list: the highlighted row is shown and marked")
	_check(shown[0].text == "..." and shown[shown.size() - 1].text == "...", "long list: '...' at both ends where rows are hidden")
	print("hoe_menu: %d failures" % failures)
	quit(1 if failures > 0 else 0)


# The plate as the player sees it at 1920 x 1080, over a dark ground with the hotbar tray, at the normal text size and the largest.
func _save_pictures(held, view: FakeView, layer: CanvasLayer, folder: String) -> void:
	DirAccess.make_dir_recursive_absolute(folder)
	root.size = Vector2i(1920, 1080)
	var ground: ColorRect = ColorRect.new()
	ground.color = Color(0.16, 0.13, 0.09)
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ground)
	layer.move_child(ground, 0)
	var tray: Control = Control.new()
	tray.set_anchors_preset(Control.PRESET_FULL_RECT)
	tray.draw.connect(func() -> void: ArtKit.draw_hotbar_tray(tray))
	layer.add_child(tray)
	layer.move_child(tray, 1)

	for scale in [0.85, 1.2]:
		view.scale = scale
		held.hoe_mode = "smooth"
		held._hoe_menu_open_now("modes")

		for frame in 4:
			await process_frame

		var path: String = folder.path_join("hoe_menu_%.2f.png" % scale)
		root.get_texture().get_image().save_png(path)
		print("picture: ", path)
		held._hoe_menu_close()

	ground.queue_free()
	tray.queue_free()
