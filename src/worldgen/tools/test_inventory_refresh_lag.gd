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
	_station_checks()
	print("test_inventory_refresh_lag: ", "FAIL (%d)" % failures if failures > 0 else "ok")
	quit(1 if failures > 0 else 0)


# The craft list stall (Dave 10 Nov 2026: opening the crafting menu, a click or D took 2 to 3 s): station_near and nearby_logs walked every world
# row several times per recipe, and each row looked its structure up by a walk over structures.json. The lookup is a map now, and the answers hold for a
# frame until the world changes or the window refreshes. The golden "usable here" line shows only while a station's own window is open.
func _station_checks() -> void:
	var view = InventoryViewScript.new()
	view.table = ItemTableScript.load_default()
	view.inventory = InventoryScript.new(view.table)
	view._player_position = func() -> Vector3: return Vector3.ZERO
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/items/structures.json"))
	var kinds: Dictionary = parsed["structures"]
	var same: bool = true

	for kind in kinds:
		var state: int = int(kinds[kind].get("state", -1))
		var first: Dictionary = {}

		for other in kinds:
			if int(kinds[other].get("state", -1)) == state:
				first = kinds[other]
				break

		same = same and view._structure_by_state(state) == first

	check(same and view._structure_by_state(-12345).is_empty(), "the state lookup map gives what the old walk over structures.json gave")

	var bench: int = int(kinds["workbench"]["state"])
	view._world = {}

	for n in 3000:   # stones and sticks lying about, as a real world has
		view._world[10000 + n] = {"node": null, "number": 1, "count": 1, "pos": Vector3(float(n % 60), 0.0, float(floori(float(n) / 60.0))), "state": 0, "light": null}

	check(not view.station_near("workbench"), "no bench, no workbench")
	view._world[1] = {"node": null, "number": 0, "count": 1, "pos": Vector3(1.0, 0.0, 0.0), "state": bench, "light": null}
	check(not view.station_near("workbench"), "within one frame the answer is kept")
	view._forget_near()
	check(view.station_near("workbench"), "after the world changes (it drops the kept answers) the bench is found")
	var t0: int = Time.get_ticks_usec()

	for n in 2000:   # the craft list's asks for 350 recipes, several each
		view.station_near("workbench")
		view.station_near("forge", 2)

	var took_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	check(took_ms < 200.0, "4000 station asks over 3000 world rows take under 0.2 s (%.1f ms)" % took_ms)

	# The golden line: only while a station's window is open.
	view.open = true
	view.chest_mode = false
	view._world[2] = {"node": null, "number": 0, "count": 1, "pos": Vector3(0.5, 0.0, 0.0), "state": 1, "light": null}   # a lit fire beside the player
	check(view.station_use().is_empty(), "the pack open on its own beside a fire lights nothing")
	view.chest_mode = true
	view.chest_id = 2
	var at_fire: Dictionary = view.station_use()
	check(at_fire.has(view.table.number_of("stick")), "the fire's own window open: sticks are lit as fuel")
	view._world[3] = {"node": null, "number": 0, "count": 1, "pos": Vector3(0.0, 0.0, 0.5), "state": int(kinds["chest"]["state"]), "light": null}
	view.chest_id = 3
	check(view.station_use().is_empty(), "a plain chest open beside the fire lights nothing")
	view.open = false
	view.chest_id = 2
	check(view.station_use().is_empty(), "window shut: nothing")
