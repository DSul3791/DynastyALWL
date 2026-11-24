extends SceneTree

# The You column, redesign step 3d (docs/ui/inventory_crafting_redesign.md sections 4.2 and 6.6): ten gear wells (eight until the outer and waist slots, 10 Nov 2026) with silhouettes
# while empty, the worn item in its well, the item in hand in the right hand, and the live preview rendering only while the window is open.
#   godot --headless --path . --script res://src/worldgen/tools/test_you_column.gd

const YouColumn := preload("res://src/client/ui/inventory/you_column.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")


class FakeTable:
	func id_of(number: int) -> String:
		return {3: "linen_shirt", 7: "stone_axe", 8: "hide_cloak", 9: "hide_hood", 10: "iron_helm", 11: "simple_backpack", 12: "fibre_shoulder_bag"}.get(number, "")

	func name_of(number: int) -> String:
		return {3: "Linen shirt", 7: "Stone axe", 8: "Hide cloak", 9: "Hide hood", 10: "Iron helm", 11: "Simple - Backpack", 12: "Fibre - Backpack"}.get(number, "")

	func shelf_units(_number: int) -> int:
		return 0

	func entry(_id: String) -> Dictionary:
		return {}

	func sentence_name(number: int) -> String:
		return in_sentence(name_of(number))

	func in_sentence(text: String) -> String:
		return text.replace(" - ", " ").to_lower()


class FakeInventory:
	const SLOTS := 30
	var slot_count: int = SLOTS
	var numbers: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		numbers.resize(SLOTS)
		numbers[4] = 7
		numbers[6] = 11   # a Simple - Backpack in the inventory
		numbers[8] = 12   # a Fibre - Backpack (worn on the shoulder) in the inventory

	func inst_of(_slot: int) -> Dictionary:   # protocol 106: no instance data here
		return {}


class FakeView:
	var table: FakeTable = FakeTable.new()
	var inventory: FakeInventory = FakeInventory.new()
	var worn: PackedInt32Array = PackedInt32Array()
	var held_slot_now: Callable = func() -> int: return 4
	var text_scale: float = 1.0
	var clothing_cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/clothing.json"))

	func _init() -> void:
		worn.resize(worn_places().size())
		worn[1] = 3   # body:base

	func worn_places() -> Array:
		return clothing_cfg["worn"]

	# As inventory_view.gd worn_top: the outermost worn layer of a slot.
	func worn_top(slot: String, skip: Array = []) -> int:
		var layers: Array = clothing_cfg["layers"].get(slot, [])

		for k in range(layers.size() - 1, -1, -1):
			var at: int = worn_places().find("%s:%s" % [slot, layers[k]])

			if not skip.has(layers[k]) and at >= 0 and worn[at] != 0:
				return at

		return -1

	func _px(size: int) -> int:
		return size

	func _item_label(number: int) -> String:
		return table.name_of(number)

	var worn_inst: Dictionary = {}   # protocol 106: the worn pieces' instance data (none here)

	func inst_label(number: int, _item_inst: Dictionary) -> String:
		return table.name_of(number)

	var sent: Array = []   # what the wells asked the server: ["wear", pack slot] or ["off", worn position]

	# As inventory_view.gd wear_slot_of: the body slot of the piece in a pack slot (only the backpack is wearable here).
	func wear_slot_of(slot: int) -> String:
		if slot < 0 or slot >= inventory.slot_count:
			return ""

		return {11: "back", 12: "shoulder"}.get(inventory.numbers[slot], "")

	func wear_slot(slot: int) -> void:
		sent.append(["wear", slot])

	func take_off(place: int) -> void:
		sent.append(["off", place])

	func open_bag(_place: int) -> void:
		pass

var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	var view: FakeView = FakeView.new()
	var part: YouColumn = YouColumn.new(view)
	var built: Control = part.build()
	root.add_child(built)
	part.refresh()
	await process_frame
	check(part.wells.size() == 10, "ten gear wells: head, body, outer, legs, feet, hands, back, waist and both hands")
	check(part.wells["head"].is_empty() and (part.wells["head"].get_node("Ghost") as Control).visible, "an empty well shows its silhouette")
	check(not part.wells["body"].is_empty() and not (part.wells["body"].get_node("Ghost") as Control).visible, "the worn shirt sits in the body well")
	# Layers (protocol 107): the Outer well is body:outer, the Body well what is under it, the Head well the outermost head layer.
	view.worn[view.worn_places().find("body:outer")] = 8
	view.worn[view.worn_places().find("head:base")] = 9
	view.worn[view.worn_places().find("head:rigid")] = 10
	part.refresh()
	check(part.wells["outer"].tooltip_text.contains("Hide cloak") and part.wells["body"].tooltip_text.contains("Linen shirt"), "a cloak shows in the Outer well and the shirt stays in Body (%s / %s)" % [part.wells["outer"].tooltip_text, part.wells["body"].tooltip_text])
	check(part.wells["head"].tooltip_text.contains("Iron helm"), "the helm over the hood shows in the Head well (%s)" % part.wells["head"].tooltip_text)
	check(not part.wells["right"].is_empty(), "the item in hand shows in the right hand")
	check(part.wells["left"].is_empty(), "the left hand is empty until the game has an off-hand item")
	check(part.wells["head"].custom_minimum_size.is_equal_approx(Vector2(96.0, 96.0)), "gear wells are 96 px")
	# The pack slot (Dave 15 Nov 2026): a backpack dragged from the inventory onto the Back well is put on; the worn one dragged off comes off.
	var back_well = part.wells["back"]
	check(back_well.can_drop.call({"slot": 6}) and not back_well.can_drop.call({"slot": 4}) and not back_well.can_drop.call({"worn": 5}) and not part.wells["head"].can_drop.is_valid(), "the Back well takes a backpack from the inventory, not an axe or a worn piece; other wells take no drops")
	check(back_well.drag_data.call() == null, "an empty Back well has nothing to drag")
	back_well.on_drop.call({"slot": 6})
	check(view.sent == [["wear", 6]], "dropping the backpack on the Back well puts it on (%s)" % str(view.sent))
	var back_at: int = view.worn_places().find("back:base")
	view.worn[back_at] = 11
	view.inventory.numbers[6] = 0
	part.refresh()
	check(back_well.tooltip_text.contains("Simple - Backpack") and back_well.drag_data.call() == {"worn": back_at}, "the worn backpack shows in the Back well and drags out as its worn position (%s)" % str(back_well.drag_data.call()))
	# The Fibre - Backpack is worn on the shoulder (Dave 24 Nov 2026: "call it a FiberBackpack"): with no pack on the back the Back well shows it,
	# drags it out and takes it as a drop; with a pack on the back the pack wins.
	var shoulder_at: int = view.worn_places().find("shoulder:base")
	view.worn[shoulder_at] = 12
	view.inventory.numbers[8] = 0
	part.refresh()
	check(back_well.tooltip_text.contains("Simple - Backpack") and back_well.drag_data.call() == {"worn": back_at}, "with a pack on the back too, the Back well still shows the pack (%s)" % back_well.tooltip_text)
	view.worn[back_at] = 0
	part.refresh()
	check(back_well.tooltip_text.contains("Fibre - Backpack") and back_well.drag_data.call() == {"worn": shoulder_at}, "no pack on the back: the Back well shows the Fibre - Backpack and drags it out as its shoulder position (%s, %s)" % [back_well.tooltip_text, str(back_well.drag_data.call())])
	view.worn[shoulder_at] = 0
	view.inventory.numbers[8] = 12
	view.sent.clear()
	check(back_well.can_drop.call({"slot": 8}), "the Back well takes the Fibre - Backpack from the inventory")
	back_well.on_drop.call({"slot": 8})
	check(view.sent == [["wear", 8]], "dropping it there puts it on (%s)" % str(view.sent))
	check(part.preview.render_target_update_mode == SubViewport.UPDATE_DISABLED, "the preview does not render while the window is shut")
	part.set_active(true)
	await process_frame
	check(part.preview.render_target_update_mode != SubViewport.UPDATE_DISABLED, "it renders while the window is open")
	check(built.get_combined_minimum_size().x <= ArtKit.YOU.size.x - 2.0 * ArtKit.INSET + 1.0, "gear and figure fit the You column's 408 px")
	part.set_active(false)
	await process_frame
	check(part.preview.render_target_update_mode == SubViewport.UPDATE_DISABLED, "and stops when it shuts")
	built.queue_free()
	await process_frame
	print("you column: %d failures" % failures)
	quit(1 if failures > 0 else 0)
