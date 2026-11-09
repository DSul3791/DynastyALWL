extends SceneTree

# The You column, redesign step 3d (docs/ui/inventory_crafting_redesign.md sections 4.2 and 6.6): eight gear wells with silhouettes
# while empty, the worn item in its well, the item in hand in the right hand, and the live preview rendering only while the window is open.
#   godot --headless --path . --script res://src/worldgen/tools/test_you_column.gd

const YouColumn := preload("res://src/client/ui/inventory/you_column.gd")
const ArtKit := preload("res://src/client/ui/art_kit.gd")


class FakeTable:
	func id_of(number: int) -> String:
		return {3: "linen_shirt", 7: "stone_axe"}.get(number, "")

	func name_of(number: int) -> String:
		return {3: "Linen shirt", 7: "Stone axe"}.get(number, "")

	func shelf_units(_number: int) -> int:
		return 0

	func entry(_id: String) -> Dictionary:
		return {}


class FakeInventory:
	const SLOTS := 30
	var numbers: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		numbers.resize(SLOTS)
		numbers[4] = 7


class FakeView:
	var table: FakeTable = FakeTable.new()
	var inventory: FakeInventory = FakeInventory.new()
	var worn: PackedInt32Array = PackedInt32Array([0, 3, 0, 0, 0, 0])
	var held_slot_now: Callable = func() -> int: return 4
	var text_scale: float = 1.0

	func clothing_slots() -> Array:
		return ["head", "body", "legs", "feet", "hands", "back"]

	func _px(size: int) -> int:
		return size

	func _item_label(number: int) -> String:
		return table.name_of(number)

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
	check(part.wells.size() == 8, "eight gear wells: head, body, legs, feet, hands, back and both hands")
	check(part.wells["head"].is_empty() and (part.wells["head"].get_node("Ghost") as Control).visible, "an empty well shows its silhouette")
	check(not part.wells["body"].is_empty() and not (part.wells["body"].get_node("Ghost") as Control).visible, "the worn shirt sits in the body well")
	check(not part.wells["right"].is_empty(), "the item in hand shows in the right hand")
	check(part.wells["left"].is_empty(), "the left hand is empty until the game has an off-hand item")
	check(part.wells["head"].custom_minimum_size.is_equal_approx(Vector2(96.0, 96.0)), "gear wells are 96 px")
	check(built.get_combined_minimum_size().x <= ArtKit.YOU.size.x - 2.0 * ArtKit.INSET + 1.0, "gear and figure fit the You column's 408 px")
	check(part.preview.render_target_update_mode == SubViewport.UPDATE_DISABLED, "the preview does not render while the window is shut")
	part.set_active(true)
	check(part.preview.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "it renders while the window is open")
	part.set_active(false)
	built.queue_free()
	await process_frame
	print("you column: %d failures" % failures)
	quit(1 if failures > 0 else 0)
