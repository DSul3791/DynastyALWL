extends SceneTree

# Admin mode is OFF at the start of every session (Dave 11 Nov 2026). Normal crafting takes the ingredients, needs the recipe known and
# the station near; Admin mode, switched on in Esc > Admin, makes it free; switching it off restores the rules at once, a queued free
# craft included. Each case runs on an isolated, prefilled test pack (no gathering), with the admin check off as in local play.
#   godot --headless --path . --script res://src/worldgen/tools/test_admin_mode_crafting.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const ViewScript := preload("res://src/client/inventory_view.gd")
const Net := preload("res://src/stream/terrain_net.gd")

const KEY := "adminmodekey01"
const TWINE := 1            # 3 plant fibre, by hand, known
const CUT_STONE_BLOCK := 127   # 8 stone at a workbench, known
const FISH_TRAP := 390      # 10 sticks + 4 twine, not known and locked: never learned

var failures: int = 0
var said: Array = []
var items


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func n(id: String) -> int:
	return items.table.number_of(id)


func have(id: String) -> int:
	return items.inventory_of(1).count_of(n(id))


func queue(recipe: int, count: int) -> void:
	items._last_queue_act.clear()   # the server ignores queue requests closer than 100 ms apart
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe, 0, count, Vector3.ZERO)


func run_ticks(seconds: float) -> void:
	for t in range(ceili(seconds / 0.25)):
		items._craft_tick(0.25)


func admin_mode(on: bool, peer: int = 1) -> void:
	items.action(peer, Net.ACT_ADMIN_MODE, 1 if on else 0, 0, 0, Vector3.ZERO)


func heard(part: String) -> bool:
	return said.any(func(t): return str(t).contains(part))


func _init() -> void:
	var dir: String = "user://test_admin_mode_crafting"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_craft_queue = func(_p, _e, _l): pass
	items.send_step_to = func(_p, _s, _y): pass
	items.send_notice = func(_p, text): said.append(text)
	items.ground_height = func(_x, _z): return 10.0
	items.admin_ok = func(p: int) -> bool: return p == 1   # peer 1 is an admin (local play: everybody is); peer 2 is not
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, KEY)
	items.peer_connected_hello(2, "adminmodekey02")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.report_position(2, Vector3(0.0, 10.0, 60.0))
	items.vitals_of(1)["weight"] = 2000.0   # a strong test character: carry limits are not under test
	check(items.inventory_of(1).is_empty(), "the test character starts with an empty pack")

	check(str(items.recipes.recipe(TWINE)["id"]) == "twine" and str(items.recipes.recipe(CUT_STONE_BLOCK)["id"]) == "cut_stone_block" and str(items.recipes.recipe(FISH_TRAP)["id"]) == "fish_trap", "the test recipes are the ones named here")
	check(str(items.recipes.recipe(CUT_STONE_BLOCK).get("station", "")) == "workbench" and not bool(items.recipes.recipe(FISH_TRAP).get("known", true)) and bool(items.recipes.recipe(FISH_TRAP).get("locked", false)), "cut stone needs a workbench; the fish trap is unknown and locked")

	# --- A new session: Admin mode is off, on the server and on the client ---
	check(not items.free_craft_for(1) and not items.free_craft_for(2), "a new session starts with Admin mode off, even for an admin")
	var view = ViewScript.new()
	check(not view.admin_craft and not view._free_craft(), "the client starts with Admin mode off and greys the list by the rules")
	view.admin_craft = true
	check(view._free_craft(), "the client's switch on makes its list free")
	view.free()

	# --- Normal mode: missing ingredients ---
	queue(TWINE, 1)
	check(items.craft_queue_of(1).is_empty() and heard("You do not have what that needs"), "an empty pack cannot make twine")
	items.inventory_of(1).add(n("plant_fibre"), 2)
	queue(TWINE, 1)
	check(items.craft_queue_of(1).is_empty() and have("plant_fibre") == 2, "2 of the 3 fibre is refused and nothing is taken")

	# --- Normal mode: exact consumption and quantities ---
	items.inventory_of(1).add(n("plant_fibre"), 8)   # 10 fibre
	queue(TWINE, 3)
	check(items.craft_queue_of(1) == [[TWINE, 3]] and have("plant_fibre") == 1, "3 twine take exactly 9 of the 10 fibre (%d left)" % have("plant_fibre"))
	run_ticks(20.0)
	check(have("twine") == 3 and items.craft_queue_of(1).is_empty(), "3 twine are made (%d)" % have("twine"))
	items.inventory_of(1).add(n("plant_fibre"), 5)   # 6 fibre: enough for 2
	said.clear()
	queue(TWINE, 5)
	check(items.craft_queue_of(1) == [[TWINE, 2]] and have("plant_fibre") == 0 and heard("You only have enough for 2"), "asking 5 with fibre for 2 queues 2 and takes 6")
	run_ticks(20.0)
	check(have("twine") == 5, "5 twine in all (%d)" % have("twine"))

	# --- Normal mode: stations ---
	items.inventory_of(1).add(n("stone"), 8)
	said.clear()
	queue(CUT_STONE_BLOCK, 1)
	check(items.craft_queue_of(1).is_empty() and have("stone") == 8 and heard("nearby"), "cut stone with no workbench near is refused and the stone stays (%s)" % str(said))
	var bench: int = items.dev_place("workbench@1,0,0")
	check(bench != 0 and items.station_near(1, "workbench"), "a workbench stands beside the player")
	queue(CUT_STONE_BLOCK, 1)
	check(items.craft_queue_of(1) == [[CUT_STONE_BLOCK, 1]] and have("stone") == 0, "at the bench the craft is queued and takes the 8 stone")
	run_ticks(60.0)
	check(have("cut_stone_block") == 1, "the cut stone block is made at the bench")

	# --- Normal mode: a recipe that is not known ---
	items.inventory_of(1).add(n("stick"), 10)
	queue(FISH_TRAP, 1)
	check(items.craft_queue_of(1).is_empty() and have("stick") == 10 and have("twine") == 5, "an unknown recipe is refused even with every ingredient in the pack")

	# --- A non-admin cannot switch Admin mode on ---
	admin_mode(true, 2)
	check(not items.free_craft_for(2), "a non-admin's switch is refused by the server")

	# --- Admin mode on: free, unknown, no station, the pack untouched ---
	admin_mode(true)
	check(items.free_craft_for(1), "Esc > Admin switches Admin mode on")
	items.report_position(1, Vector3(0.0, 10.0, 200.0))   # far from the bench
	queue(FISH_TRAP, 1)
	queue(CUT_STONE_BLOCK, 2)
	check(items.craft_queue_of(1) == [[FISH_TRAP, 1], [CUT_STONE_BLOCK, 2]], "Admin mode queues an unknown recipe and a station recipe with no station (%s)" % str(items.craft_queue_of(1)))
	run_ticks(120.0)
	check(have("fish_trap") == 1 and have("cut_stone_block") == 3, "both are made free (%d trap, %d blocks)" % [have("fish_trap"), have("cut_stone_block")])
	check(have("stick") == 10 and have("twine") == 5 and have("stone") == 0, "and nothing was taken from the pack")

	# --- Switching off restores the rules at once, a queued free craft included ---
	queue(CUT_STONE_BLOCK, 1)
	admin_mode(false)
	said.clear()
	run_ticks(60.0)
	check(have("cut_stone_block") == 3 and items.craft_queue_of(1).is_empty() and heard("Admin mode is off"), "a free craft still queued when Admin mode goes off is dropped, not made")
	queue(FISH_TRAP, 1)
	check(items.craft_queue_of(1).is_empty() and have("stick") == 10, "the unknown recipe is refused again")
	queue(CUT_STONE_BLOCK, 1)
	check(items.craft_queue_of(1).is_empty(), "the station recipe is refused again away from the bench with no stone")

	# --- A new session starts off again, and a free craft left in the queue is not made ---
	admin_mode(true)
	queue(CUT_STONE_BLOCK, 1)
	items.peer_left(1)
	items.peer_connected_hello(1, KEY)
	items.report_position(1, Vector3(0.0, 10.0, 200.0))
	check(not items.free_craft_for(1), "logging in again starts with Admin mode off")
	run_ticks(60.0)
	check(have("cut_stone_block") == 3 and items.craft_queue_of(1).is_empty(), "the free craft queued last session is dropped at the next login")

	# --- Play as a new player switches it off too ---
	admin_mode(true)
	items.action(1, Net.ACT_NEW_PLAYER, 0, 0, 0, Vector3.ZERO)
	check(not items.free_craft_for(1), "starting over as a new player turns Admin mode off")

	if failures == 0:
		print("Test done: all pass")
	else:
		print("Test done: ", failures, " fail")

	quit(1 if failures > 0 else 0)
