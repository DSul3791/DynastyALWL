extends SceneTree

# PLAYTEST-001 (Dave, 12 Nov 2026): TEST-005 a click on a recipe row only selects it, Shift-click makes exactly one, the Craft button makes the
# box's quantity; TEST-001 the 0.4 s hold that queued everything the stock allowed is gone; TEST-012 the work sound keeps on clip after clip while
# a craft runs and stops when the queue is done or the craft waits.
#   godot --headless --path . --script res://src/worldgen/tools/test_craft_click.gd

const RecipeList := preload("res://src/client/ui/inventory/recipe_list.gd")
const ItemSounds := preload("res://src/client/item_sounds.gd")


class FakeRecipes:
	func recipe(number: int) -> Dictionary:
		return {"number": number, "id": "wooden_spear" if number == 5 else "campfire"}


# Just enough of an InventoryView for row clicks: what was asked to be crafted and what is selected.
class FakeView:
	var recipes: FakeRecipes = FakeRecipes.new()
	var _selected_recipe: int = 0
	var crafted: Array = []   # [[recipe, count], ...] as _start_craft was asked
	var refreshes: int = 0

	func _start_craft(number: int, count: int = 1, _variant: int = 0) -> void:
		crafted.append([number, count])

	func _refresh() -> void:
		refreshes += 1

	func craft_variants(_recipe: Dictionary) -> Array:
		return []


class FakeInventory:
	var numbers: PackedInt32Array = PackedInt32Array()
	var counts: PackedInt32Array = PackedInt32Array()


class FakeTable:
	func entry(_id: String) -> Dictionary:
		return {}

	func id_of(_number: int) -> String:
		return ""

	func number_of(_id: String) -> int:
		return 0


# Just enough of an InventoryView for ItemSounds.watch.
class FakeItems:
	var inventory: FakeInventory = FakeInventory.new()
	var table: FakeTable = FakeTable.new()
	var recipes: FakeRecipes = FakeRecipes.new()
	var open: bool = false   # the window is shut: the sound must run all the same
	var chest_mode: bool = false
	var _crafting: int = 0
	var _craft_head_end_msec: int = 0


var failures: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func _initialize() -> void:
	_check_clicks()
	_check_sounds()
	print("craft click tests: %d failures" % failures)
	quit(1 if failures > 0 else 0)


func _check_clicks() -> void:
	var view: FakeView = FakeView.new()
	var list = RecipeList.new(view)
	list.row_clicked(5, false)
	check(view.crafted.is_empty() and view._selected_recipe == 5 and view.refreshes == 1, "a click on a recipe selects it and shows its card; nothing is crafted")
	list.row_clicked(5, false)
	list.row_clicked(7, false)
	check(view.crafted.is_empty() and view._selected_recipe == 7, "clicking again, or another recipe, still crafts nothing")
	list.row_clicked(5, true)
	check(view.crafted == [[5, 1]] and view._selected_recipe == 5, "shift-click makes exactly one, and selects it")
	view._selected_recipe = 0
	list.craft_selected()
	check(view.crafted.size() == 1, "the Craft button with nothing selected makes nothing")
	view._selected_recipe = 7
	list.craft_selected()
	check(view.crafted.size() == 2 and view.crafted[1] == [7, 1], "the Craft button makes the box's quantity (1 with no box shown)")


func _check_sounds() -> void:
	var now: int = Time.get_ticks_msec()
	check(not ItemSounds.work_running(0, now, now + 5000), "nothing queued: no work sound")
	check(ItemSounds.work_running(5, now, now + 3000), "a craft under way: the work sound plays")
	check(ItemSounds.work_running(5, now, now - ItemSounds.WORK_GRACE_MSEC + 10), "a moment past the expected end (the server's update is on its way): it keeps on")
	check(not ItemSounds.work_running(5, now, now - ItemSounds.WORK_GRACE_MSEC - 10), "well past it (the craft waits: away from the station, no room): it stops")

	var fx = ItemSounds.new()
	root.add_child(fx)
	fx.setup(null)
	var items: FakeItems = FakeItems.new()
	fx.watch(items)
	check(fx.work_played == 0, "no craft: no work sound")
	items._crafting = 5
	items._craft_head_end_msec = Time.get_ticks_msec() + 20000   # a queue of several spears
	fx.watch(items)
	check(fx.played == 1, "the craft_start cue sounds (its clips live with the item sounds)")
	check(fx.work_played == 1 and fx.last_work.begins_with("craft_carve"), "the queue starts: the spear's carving sound (%s)" % fx.last_work)
	fx._work.stop()   # the 4.5 s clip ran out
	fx.watch(items)
	check(fx.work_played == 2, "the clip ran out while the craft runs: the next one starts, window shut")
	items._crafting = 6
	fx.watch(items)
	check(fx.work_played == 3 and fx.last_work.begins_with("craft_stack"), "the next recipe in the queue: its own sound (%s)" % fx.last_work)
	items._craft_head_end_msec = Time.get_ticks_msec() - ItemSounds.WORK_GRACE_MSEC - 100   # the craft waits
	fx.watch(items)
	var waited: int = fx.work_played
	fx.watch(items)
	check(not fx._work.playing and fx.work_played == waited, "a craft that waits: the sound stops and does not come back")
	items._craft_head_end_msec = Time.get_ticks_msec() + 3000   # the server's update: it runs again
	fx.watch(items)
	check(fx.work_played == waited + 1, "it runs again: the sound comes back")
	OS.delay_msec(ItemSounds.MIN_GAP_MSEC + 10)
	var cues: int = fx.played
	items._crafting = 0   # the queue is done (or cancelled)
	fx.watch(items)
	var done_at: int = fx.work_played
	fx.watch(items)
	check(not fx._work.playing and fx.work_played == done_at and fx.played == cues + 1 and fx.last.begins_with("craft_done"), "the queue done: the work sound stops and craft_done plays once (%s)" % fx.last)
	fx.free()
