extends SceneTree

# The You column (R-HUD-INVENTORY-WORN, Dave 27 Nov 2026): no character picture; a well for each of the 27 worn positions and the item in hand,
# armour left, clothing middle, carried gear right; silhouettes while empty; drop on a well puts on, a worn piece drags out.
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
	var places: Array = view.worn_places()
	var all_there: bool = part.wells.has(YouColumn.HAND) and part.wells.size() == places.size() + 1

	for place in places:
		all_there = all_there and part.wells.has(place)

	check(all_there, "a well for every worn position and the item in hand (%d wells)" % part.wells.size())
	check(part.wells["head:base"].is_empty() and (part.wells["head:base"].get_node("Ghost") as Control).visible, "an empty well shows its silhouette")
	check(part.wells["body:mail"].tooltip_text.contains("Body, mail"), "an empty well names its position (%s)" % part.wells["body:mail"].tooltip_text)
	check(not part.wells["body:base"].is_empty() and not (part.wells["body:base"].get_node("Ghost") as Control).visible, "the worn shirt sits in the body well")
	# Every layer shows in its own well: the hood under the helm, the shirt under the cloak.
	view.worn[places.find("body:outer")] = 8
	view.worn[places.find("head:base")] = 9
	view.worn[places.find("head:rigid")] = 10
	part.refresh()
	check(part.wells["body:outer"].tooltip_text.contains("Hide cloak") and part.wells["body:base"].tooltip_text.contains("Linen shirt"), "the cloak and the shirt under it each show (%s / %s)" % [part.wells["body:outer"].tooltip_text, part.wells["body:base"].tooltip_text])
	check(part.wells["head:rigid"].tooltip_text.contains("Iron helm") and part.wells["head:base"].tooltip_text.contains("Hide hood"), "the helm and the hood under it each show")
	check(not part.wells[YouColumn.HAND].is_empty(), "the item in hand shows in the hand well")
	check(not part.wells[YouColumn.HAND].can_drop.is_valid() and not part.wells[YouColumn.HAND].drag_data.is_valid(), "the hand well takes no drops and drags nothing")
	check(part.wells["head:base"].custom_minimum_size.is_equal_approx(Vector2(YouColumn.GEAR_PX, YouColumn.GEAR_PX)), "wells are %d px" % int(YouColumn.GEAR_PX))
	# Drop on the well the piece is worn in puts it on; a worn piece drags out as its worn position (the pack slot, Dave 15 Nov 2026).
	var back_well = part.wells["back:base"]
	check(back_well.can_drop.call({"slot": 6}) and not back_well.can_drop.call({"slot": 4}) and not back_well.can_drop.call({"slot": 8}) and not back_well.can_drop.call({"worn": 5}), "the Back well takes a backpack from the inventory, not an axe, a shoulder bag or a worn piece")
	check(part.wells["shoulder:base"].can_drop.call({"slot": 8}) and not part.wells["head:base"].can_drop.call({"slot": 6}), "the Fibre - Backpack drops on the Shoulder well; a pack does not drop on Head")
	check(back_well.drag_data.call() == null, "an empty Back well has nothing to drag")
	back_well.on_drop.call({"slot": 6})
	check(view.sent == [["wear", 6]], "dropping the backpack on the Back well puts it on (%s)" % str(view.sent))
	var back_at: int = places.find("back:base")
	view.worn[back_at] = 11
	view.inventory.numbers[6] = 0
	var shoulder_at: int = places.find("shoulder:base")
	view.worn[shoulder_at] = 12
	view.inventory.numbers[8] = 0
	part.refresh()
	check(back_well.tooltip_text.contains("Simple - Backpack") and back_well.drag_data.call() == {"worn": back_at}, "the worn backpack shows in the Back well and drags out as its worn position (%s)" % str(back_well.drag_data.call()))
	check(part.wells["shoulder:base"].tooltip_text.contains("Fibre - Backpack") and part.wells["shoulder:base"].drag_data.call() == {"worn": shoulder_at}, "the Fibre - Backpack shows in its own Shoulder well beside the pack")
	check(part.wells["head:rigid"].drag_data.call() == {"worn": places.find("head:rigid")}, "any worn piece drags out as its worn position")
	check(built.get_combined_minimum_size().x <= ArtKit.YOU.size.x - 2.0 * ArtKit.INSET + 1.0, "the wells fit the You column's 408 px (%d)" % int(built.get_combined_minimum_size().x))
	built.queue_free()
	await process_frame
	print("you column: %d failures" % failures)
	quit(1 if failures > 0 else 0)
