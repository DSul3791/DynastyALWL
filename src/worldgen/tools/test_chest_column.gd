extends SceneTree

# Chest mode, redesign step 3e (docs/ui/inventory_crafting_redesign.md section 4.4): an open container takes the Craft column with
# the same 100 px wells 6 across, the "keep out" tick and its lock on the bar, Take all and Store all, Sort both and Stack into my chests
# under the grid; its name goes on the Craft plate; slots past its capacity are hidden; the column fits the panel.
#   godot --headless --path . --script res://src/worldgen/tools/test_chest_column.gd

const ArtKit := preload("res://src/client/ui/art_kit.gd")
const InventoryFrame := preload("res://src/client/ui/inventory/inventory_frame.gd")
const ContainerPanel := preload("res://src/client/ui/inventory/container_panel.gd")


class FakeTable:
	func id_of(number: int) -> String:
		return {5: "storage_chest", 9: "stick"}.get(number, "")

	func name_of(number: int) -> String:
		return {5: "Storage chest", 9: "Stick"}.get(number, "")

	func entry(item_id: String) -> Dictionary:
		return {"slots": 12} if item_id == "storage_chest" else {}

	func shelf_units(_number: int) -> int:
		return 0


class FakeStore:
	const SLOTS := 36
	var numbers: PackedInt32Array = PackedInt32Array()
	var counts: PackedInt32Array = PackedInt32Array()
	var wear: PackedInt32Array = PackedInt32Array()

	func _init() -> void:
		numbers.resize(SLOTS)
		counts.resize(SLOTS)
		wear.resize(SLOTS)


class FakePack:
	var shown: int = 0

	func show_info() -> void:
		shown += 1


class FakeView:
	var table: FakeTable = FakeTable.new()
	var inventory: FakeStore = FakeStore.new()
	var chest_inv: FakeStore = FakeStore.new()
	var chest_mode: bool = true
	var chest_id: int = 40
	var chest_keep_out: bool = true
	var chest_may_keep_out: bool = true
	var _world: Dictionary = {40: {"number": 5, "state": 0}}
	var _frame: Control
	var _chest_panel: Control
	var _chest_buttons: Array = []
	var _pack_buttons: Array = []
	var _pack_view: Array = []
	var _chest_hover: Array = []
	var _chest_last: Array = []
	var _cooking_cfg: Dictionary = {}
	var bulks: Array = []
	var _pack_part: FakePack = FakePack.new()
	var text_scale: float = 1.0

	func _px(size: int) -> int:
		return size

	func _tooltip(_number: int, _count: int, _wear: int) -> String:
		return ""

	func _item_label(number: int) -> String:
		return table.name_of(number)

	func bulk(kind: int) -> void:
		bulks.append(kind)

	func set_keep_out(on: bool) -> void:
		chest_keep_out = on


var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _hints(node: Node, into: Dictionary) -> void:
	if node is Button and (node as Button).flat:
		into[(node as Button).text] = node

	for child in node.get_children():
		_hints(child, into)


func _initialize() -> void:
	var view: FakeView = FakeView.new()
	var frame: InventoryFrame = InventoryFrame.new()
	view._frame = frame
	root.add_child(frame)
	view.chest_inv.numbers[0] = 9
	view.chest_inv.counts[0] = 4
	var part: ContainerPanel = ContainerPanel.new(view)
	part.build()
	view._chest_panel.visible = true
	part.refresh()
	await process_frame
	await process_frame

	check(view._chest_panel.get_parent() == frame.craft_column, "the container shows in the Craft column")
	check(view._chest_buttons.size() == FakeStore.SLOTS, "a well for every slot the store has")
	check((view._chest_buttons[0] as Control).custom_minimum_size.is_equal_approx(Vector2(ArtKit.SLOT, ArtKit.SLOT)), "the same 100 px wells as the pack")
	check(not view._chest_buttons[0].is_empty(), "the sticks in the chest show in its first well")
	check((view._chest_buttons[11] as Control).visible and not (view._chest_buttons[12] as Control).visible, "slots past the chest's 12 are hidden")
	var first: Control = view._chest_buttons[0]
	var seventh: Control = view._chest_buttons[6]
	check(is_equal_approx(seventh.position.y - first.position.y, ArtKit.SLOT + ArtKit.SLOT_GAP) and is_equal_approx(seventh.position.x, first.position.x), "6 across with 10 px gaps")
	check(frame.columns_fit(), "the container column fits the Craft panel")
	check(part.title() == "STORAGE CHEST", "the plate takes the container's name")
	check(view._pack_view.size() == FakeStore.SLOTS and view._pack_buttons.is_empty(), "a chest shows every pack slot in place, in the Pack column")
	first.mouse_entered.emit()
	check(view._chest_hover == [true, 0] and view._chest_last == [true, 0], "the pointer over a chest well is the chest hover (the transfer key's target)")
	check(view._pack_part.shown == 1, "and the info strip under the pack is asked to show it")
	part.fire_takes("stick")
	check(not view._cooking_cfg.is_empty(), "a fire's rule reads cooking.json once")
	check(part._keep_out.visible and part._keep_out.button_pressed, "the owner sees the keep out tick, ticked")
	check(part._lock.visible, "the lock shows while it is kept out")
	var hints: Dictionary = {}
	_hints(view._chest_panel, hints)

	for label in ["Take all", "Store all", "Sort both", "Stack into my chests"]:
		check(hints.has(label), "the %s key hint is there" % label)

	(hints["Take all"] as Button).pressed.emit()
	(hints["Store all"] as Button).pressed.emit()
	(hints["Stack into my chests"] as Button).pressed.emit()
	(hints["Sort both"] as Button).pressed.emit()
	check(view.bulks == [0, 1, 2, 3], "the four hints send bulk 0 to 3")
	view.chest_keep_out = false
	view._world[40]["state"] = -1
	part.refresh()
	check(not part._lock.visible, "the lock goes when it is no longer kept out")
	frame.queue_free()
	await process_frame
	print("chest column: %d failures" % failures)
	quit(1 if failures > 0 else 0)
