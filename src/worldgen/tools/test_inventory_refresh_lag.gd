extends SceneTree

# Lag fix (Sal, 2 Nov 2026): a slot update while the inventory window is shut must not rebuild the slot buttons and the recipe list (55 to 87 ms each).
# The stand-in view has a panel but NO recipe list or slot buttons: a rebuild would fail on them, a skipped one does nothing. Opening rebuilds (toggle).
#   godot --headless --path . --script res://src/worldgen/tools/test_inventory_refresh_lag.gd

const InventoryViewScript := preload("res://src/client/inventory_view.gd")
const InventoryScript := preload("res://src/shared/inventory.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _init() -> void:
	var view = InventoryViewScript.new()
	view.table = ItemTableScript.load_default()
	view.inventory = InventoryScript.new(view.table)
	view._panel = PanelContainer.new()
	view.open = false
	view._refresh()
	check(view._recipe_list == null, "closed window: _refresh does not build or touch the recipe list")
	view.open = true
	view.chest_mode = true
	view._refresh()
	check(view._recipe_list == null, "chest screen up: the hidden inventory panel is not rebuilt either")
	view._queue_refresh()
	view._queue_refresh()
	check(view._refresh_queued, "two slot updates in a frame queue ONE refresh")
	print("test_inventory_refresh_lag: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)
