extends SceneTree
# Headless check of the left hand (src/client/held_item.gd): a torch or a shield goes in the left hand beside the right-hand tool,
# the same key stows it, a shield raises with B, and the hotbar picks the slot up.

const HeldItem := preload("res://src/client/held_item.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var failures: int = 0


class FakeInventory:
	extends RefCounted
	var numbers: Array = []
	var counts: Array = []


class FakeView:
	extends Node
	var table
	var inventory = FakeInventory.new()
	var notices: Array = []
	var refreshed: int = 0

	func refresh_hotbar() -> void:
		refreshed += 1

	func _on_notice(text: String) -> void:
		notices.append(text)

	func text_px(size: int) -> int:
		return size

	func fire_light_near(_point: Vector3, _radius: float) -> bool:
		return false

	func edible_slot(_slot: int) -> bool:
		return false

	func is_broken(_slot: int) -> bool:
		return false


func _check(ok: bool, what: String) -> void:
	if ok:
		print("ok   ", what)
	else:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	run.call_deferred()


func run() -> void:
	var table = ItemTableScript.load_default()
	var view: FakeView = FakeView.new()
	view.table = table
	view.inventory.numbers.resize(30)
	view.inventory.numbers.fill(0)
	view.inventory.counts.resize(30)
	view.inventory.counts.fill(0)
	view.inventory.numbers[0] = table.number_of("stone_axe")
	view.inventory.numbers[1] = table.number_of("torch")
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
	_check(held.is_offhand(table.number_of("torch")) and not held.is_offhand(table.number_of("stone_axe")), "a torch is a left-hand item, an axe is not")
	held.holding = false
	held.press_slot(0)
	_check(held.holding and held.held_slot == 0 and held.held_id() == "stone_axe", "the axe is in the right hand")
	held.press_slot(1)
	_check(held.off_holding and held.off_slot == 1 and held.off_id() == "torch", "the torch goes in the left hand")
	_check(held.holding and held.held_id() == "stone_axe", "the axe stays in the right hand")
	held._process(0.1)
	_check(held._off_model != null and held._off_model.get_parent() == held._arms.hand_mount_l, "the torch model sits on the left hand mount")
	_check(held._off_model.get_node_or_null("Light") != null, "with its light")
	_check(held._model != null and held._model.get_parent() == held._arms.hand_mount_r, "the axe model is still in the right hand")
	_check(held._caption().contains("Left hand: Basic torch"), "the caption names the left-hand item")
	_check(not held.blocking, "not blocking without a shield")
	held.set_first_person(false)
	_check(held._off_model.get_parent() != null, "the left-hand model survives the camera switch")
	held.set_first_person(true)
	held.press_slot(1)
	_check(not held.off_holding and held.off_number() == 0, "the same key stows the torch")
	held._process(0.1)
	_check(held._off_model == null, "the left-hand model is gone")
	_check(held.holding and held.held_id() == "stone_axe", "the axe is untouched")

	# A shield: a made-up item with the "offhand" mark and the shield class.
	var shield: Dictionary = {"id": "test_shield", "number": 9999, "name": "Test shield", "kind": "tool", "tool_class": "shield", "offhand": true, "stack": 1}
	table._by_id["test_shield"] = shield
	table._by_number[9999] = shield
	view.inventory.numbers[2] = 9999
	held.press_slot(2)
	_check(held.off_holding and held.off_id() == "test_shield", "a marked item goes in the left hand")
	held._process(0.1)
	_check(held._off_model != null and held._off_model.get_node_or_null("Light") == null, "a shield has no light")
	_check(held._caption().contains("hold B to block"), "the caption tells how to block")
	held.press_slot(1)
	_check(held.off_slot == 1 and held.off_id() == "torch", "another left-hand item replaces it")
	view.inventory.numbers[1] = 0
	_check(held.off_number() == 0, "an emptied slot leaves the left hand empty")
	print("offhand: %d failures" % failures)
	quit(1 if failures > 0 else 0)
