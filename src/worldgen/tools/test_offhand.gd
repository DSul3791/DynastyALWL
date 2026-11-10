extends SceneTree
# Headless check of the left hand (src/client/held_item.gd): a torch or a shield goes in the left hand beside the right-hand tool,
# the same key stows it, a shield raises with B, and the hotbar key picks the item up (keys point at items: inventory step 4).

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

	var keys: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]   # the pointer hotbar (inventory step 4): each key holds an item number

	func key_slot(key: int) -> int:
		return inventory.numbers.find(keys[key]) if key >= 0 and key < keys.size() and int(keys[key]) != 0 else -1


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
	view.keys[0] = table.number_of("stone_axe")
	view.keys[1] = table.number_of("torch")
	view.keys[2] = 9999
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
	_check(held._caption() == "", "the HUD names neither hand's item (Dave 10 Nov 2026)")
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
	_check(held._caption() == "", "nor the shield")
	held.press_slot(1)
	_check(held.off_slot == 1 and held.off_id() == "torch", "another left-hand item replaces it")
	view.inventory.numbers[1] = 0
	_check(held.off_number() == 0, "an emptied slot leaves the left hand empty")

	# A carried lantern (buildables plan B4): a made-up burning lantern hangs upright in the left hand with one light of its light_m; gone dark, it has none.
	var lantern: Dictionary = {"id": "test_lantern", "number": 9998, "name": "Test lantern", "kind": "tool", "tool_class": "lantern", "offhand": true, "stack": 1, "flame": true, "light_m": 8.0, "fuel": "candle", "burn_s": 3600.0, "doused_item": "test_lantern_dark"}
	var dark: Dictionary = {"id": "test_lantern_dark", "number": 9997, "name": "Test lantern", "kind": "tool", "tool_class": "lantern_dark", "offhand": true, "stack": 1, "relit_item": "test_lantern"}
	table._by_id["test_lantern"] = lantern
	table._by_number[9998] = lantern
	table._by_id["test_lantern_dark"] = dark
	table._by_number[9997] = dark
	view.inventory.numbers[3] = 9998
	view.keys[3] = 9998
	held.press_slot(3)
	_check(held.off_holding and held.off_id() == "test_lantern", "a lantern goes in the left hand")
	held._process(0.1)
	var lamp: OmniLight3D = held._off_model.get_node_or_null("Light") as OmniLight3D if held._off_model != null else null
	_check(lamp != null and is_equal_approx(lamp.omni_range, 8.0), "the lantern gives one light of its light_m")
	_check(held._off_model != null and held._off_model.is_inside_tree() and held._off_model.global_basis.y.dot(Vector3.UP) > 0.99, "it hangs upright from the fist")
	view.inventory.numbers[3] = 9997
	held._process(0.1)
	_check(held._off_model != null and held._off_model.get_node_or_null("Light") == null, "a dark lantern has no light")
	print("offhand: %d failures" % failures)
	quit(1 if failures > 0 else 0)
