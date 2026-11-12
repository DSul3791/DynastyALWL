extends SceneTree
# Headless check of the spear and the shoulder log in src/client/held_item.gd (Dave's playtest 12 Nov 2026):
# TEST-004: a jab ends and the next one can start (the jab clock stuck once the spear was in the hand, so attacks stopped),
# and the spear points ahead from the fist instead of along the fingers like a knife.
# TEST-010: with a log on the shoulder the right-hand tool is put away, and it comes back when the log is laid down.
#   godot --headless --path . --script res://src/worldgen/tools/test_spear_hold.gd

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
	var keys: Array = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

	func refresh_hotbar() -> void:
		pass

	func _on_notice(_text: String) -> void:
		pass

	func text_px(size: int) -> int:
		return size

	func fire_light_near(_point: Vector3, _radius: float) -> bool:
		return false

	func edible_slot(_slot: int) -> bool:
		return false

	func is_broken(_slot: int) -> bool:
		return false

	func key_slot(key: int) -> int:
		return inventory.numbers.find(keys[key]) if key >= 0 and key < keys.size() and int(keys[key]) != 0 else -1


func _check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


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
	view.inventory.numbers[0] = table.number_of("wooden_spear")
	view.inventory.numbers[1] = table.number_of("stone_axe")
	view.keys[0] = table.number_of("wooden_spear")
	view.keys[1] = table.number_of("stone_axe")
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
	held.set_first_person(true)
	held.holding = false
	held.press_slot(0)
	held._process(0.05)
	_check(held.held_id() == "wooden_spear" and held._model != null and held._mounted, "the spear is in the first-person hand")

	# TEST-004: three jabs in a row, each ending on its own clock.
	for n in range(3):
		_check(held._jab_t < 0.0, "jab %d can start (no jab running)" % (n + 1))
		held._jab_t = 0.0   # what a left click starts (mouse_button), without the server call

		for f in range(10):
			held._process(0.05)

		_check(held._jab_t < 0.0, "jab %d has ended after %.1f s (the jab is %.2f s)" % [n + 1, 0.5, HeldItem.JAB_S])

	# The spear points ahead from the fist: at rest level with the body's facing and a little up, its point SPEAR_GRIP_Z ahead of the hand.
	held._arm_up = 0.0
	held._aim_spear()
	var tip: Vector3 = -held._model.global_basis.z.normalized()
	var ahead: Vector3 = -camera.global_basis.z
	ahead.y = 0.0
	_check(tip.dot(ahead.normalized()) > 0.98 and tip.y > 0.0 and tip.y < 0.3, "at rest the spear points ahead and a little up (%s)" % str(tip))
	var hand: Vector3 = (held._model.get_parent() as Node3D).global_position
	_check(held._model.global_position.distance_to(hand + tip * HeldItem.SPEAR_GRIP_Z) < 0.001, "the hand holds it %.1f m behind the middle of the shaft" % HeldItem.SPEAR_GRIP_Z)
	camera.rotation_degrees = Vector3(-30.0, 40.0, 0.0)
	held._arm_up = 1.0
	held._aim_spear()
	tip = -held._model.global_basis.z.normalized()
	_check(tip.dot(-camera.global_basis.z) > 0.999, "with the arms up to jab it points where the view looks (%s)" % str(tip))
	_check(is_equal_approx(held._model.global_basis.x.length(), 1.0) and absf(held._model.global_basis.x.dot(held._model.global_basis.y)) < 0.001, "drawn at its own size, not stretched")

	# TEST-010: a log on the shoulder puts the right-hand tool away; laid down, it comes back.
	held.press_slot(1)
	held._process(0.05)
	_check(held.held_id() == "stone_axe" and held._model != null, "the axe is in hand")
	held.carrying_log = true
	held._process(0.05)
	_check(held.held_number() == 0 and held._model == null and held.holding, "carrying a log: the axe is put away, the key still chosen")
	_check(not held._is_axe(), "and cannot be swung")
	held.carrying_log = false
	held._process(0.05)
	_check(held.held_id() == "stone_axe" and held._model != null, "the log laid down: the axe is back in hand")
	print("test_spear_hold: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
