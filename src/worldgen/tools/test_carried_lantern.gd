extends SceneTree

# The carried lantern (buildables plan B4, Steve's hotbar rule, approved 10 Nov 2026): a left-hand light like the torch that burns only while in hand. Its
# candle (Wooden - Lantern, 1 game day) or lamp oil (Iron - Lantern, 3 game days) is counted in the slot's wear; when it is used up the lantern goes dark
# (its "doused_item") and is kept, and its key loads the next candle or lamp oil from the pack. The rain never puts it out; water does, and the key lights it
# again with the fuel it had. Until Jamie's rows for wooden_lantern and iron_lantern land, stand-in rows are used; once they exist they are checked too.
#   godot --headless --path . --script res://src/worldgen/tools/test_carried_lantern.gd

const ItemTableScript := preload("res://src/shared/item_table.gd")
const ItemsScript := preload("res://src/stream/server_items.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const FlameRules := preload("res://src/shared/flame_rules.gd")

const LIT := 99801
const DARK := 99802
const BURN_S := 3600.0

var failures: int = 0


func check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL ", what)


func _add(table, id: String, number: int, row: Dictionary) -> void:
	var entry: Dictionary = row.duplicate()
	entry["id"] = id
	entry["number"] = number
	entry["stack"] = 1
	table._by_id[id] = entry
	table._by_number[number] = entry


# Jamie's real rows, once they are in items.json: a burning lantern goes in the left hand, has a dark twin that lights back into it, and burns a fuel item.
func _real_rows(table) -> void:
	for id in ["wooden_lantern", "iron_lantern"]:
		var row: Dictionary = table.entry(id)

		if str(row.get("doused_item", "")) == "":
			print("%s: no lantern rows yet (Jamie's data), stand-ins only" % id)
			continue

		var dark: Dictionary = table.entry(str(row["doused_item"]))
		check(bool(row.get("offhand", false)) and str(row.get("tool_class", "")) == "lantern", "%s goes in the left hand as a lantern" % id)
		check(bool(row.get("flame", false)) and float(row.get("burn_s", 0.0)) > 0.0 and not bool(row.get("rain_douses", false)), "%s burns, for a time, and not out in the rain" % id)
		check(table.number_of(str(row.get("fuel", ""))) > 0, "%s burns a real fuel item" % id)
		check(not dark.is_empty() and str(dark.get("relit_item", "")) == id and bool(dark.get("offhand", false)), "%s has a dark twin that lights back into it" % id)
		check(str(dark.get("name", "")) == str(row.get("name", "")), "%s keeps its name when it goes out" % id)


func _init() -> void:
	var table = ItemTableScript.load_default()
	var candle: int = table.number_of("candle")
	_add(table, "test_lantern", LIT, {"name": "Test - Lantern", "kind": "tool", "tool_class": "lantern", "offhand": true, "unstackable": true, "flame": true, "light_m": 8.0, "burn_s": BURN_S, "fuel": "candle", "doused_item": "test_lantern_dark"})
	_add(table, "test_lantern_dark", DARK, {"name": "Test - Lantern", "kind": "tool", "tool_class": "lantern_dark", "offhand": true, "unstackable": true, "relit_item": "test_lantern"})
	var lit_row: Dictionary = table.entry("test_lantern")
	var torch: Dictionary = table.entry("torch")
	var grace: float = FlameRules.RAIN_GRACE_S

	check(FlameRules.flame_word(lit_row) == "lantern" and FlameRules.flame_word(table.entry("test_lantern_dark")) == "lantern", "a lantern is called a lantern, lit or dark")
	check(FlameRules.flame_word(torch) == "torch" and FlameRules.flame_word(table.entry("torch_doused")) == "torch", "a torch is a torch")
	check(not FlameRules.out_of_fuel(lit_row, 0) and FlameRules.out_of_fuel(lit_row, int(BURN_S * 10.0)), "a lantern's fuel is used up at burn_s")
	check(not FlameRules.out_of_fuel(torch, 1000000000), "a torch never waits for fuel")
	check(FlameRules.douse_reason(lit_row, false, 1.0, false, grace * 2.0) == "", "the rain does not put a lantern out")
	check(FlameRules.douse_reason(lit_row, true, 0.0, false, 0.0) == "water", "water does")
	_real_rows(table)

	var dir: String = "user://test_carried_lantern"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.setup(table, dir)
	items.peer_connected_hello(7, "lanterntest123")
	items.report_position(7, Vector3(100.0, 5.0, 100.0))
	var inv = items.inventory_of(7)

	for n in range(inv.SLOTS):
		if inv.numbers[n] == candle:
			inv.numbers[n] = 0
			inv.counts[n] = 0

	items.action(7, Net.ACT_ADMIN_GIVE, LIT, 0, 1, Vector3.ZERO)
	var slot: int = inv.numbers.find(LIT)
	check(slot >= 0, "the lantern is in the pack")

	# The open rain: the server will not put a lantern out, even when it rains.
	items.rain_now = func(): return 0.9
	items.cover_at = func(_p): return 0.0
	items.action(7, Net.ACT_DOUSE, slot, 1, 0, Vector3.ZERO)
	check(inv.numbers[slot] == LIT, "open rain: the lantern keeps burning")

	# Water: it goes dark with the fuel it had, and its key lights it again with no candle used.
	items.rain_now = func(): return 0.0
	inv.wear[slot] = 1000
	items.action(7, Net.ACT_DOUSE, slot, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == DARK and inv.wear[slot] == 1000, "under water the lantern goes dark and keeps its fuel")
	items.set_swimming(7, true)
	items.action(7, Net.ACT_RELIGHT, 0, slot + 1, 0, Vector3.ZERO)
	check(inv.numbers[slot] == DARK, "it cannot be lit in the water")
	items.set_swimming(7, false)
	items.action(7, Net.ACT_RELIGHT, 0, slot + 1, 0, Vector3.ZERO)
	check(inv.numbers[slot] == LIT and inv.wear[slot] == 1000, "out of the water its key lights it again, the same fuel burning")

	# Burning in hand: the wear counts tenths of a second; at burn_s the lantern goes dark and stays in the pack.
	inv.wear[slot] = int(BURN_S * 10.0) - 5
	items.action(7, Net.ACT_TORCH_BURN, slot, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == DARK and inv.counts[slot] == 1, "the candle burns out: the lantern goes dark and is kept")
	check(FlameRules.out_of_fuel(lit_row, inv.wear[slot]), "and its fuel is used up")
	check(not items._torch_seen.has(7), "a dark lantern keeps nothing off")

	# The key with no candle in the pack: it stays dark. With one: the candle goes in and it burns from the start.
	items.action(7, Net.ACT_RELIGHT, 0, slot + 1, 0, Vector3.ZERO)
	check(inv.numbers[slot] == DARK, "no candle in the pack: the lantern stays dark")
	items.action(7, Net.ACT_ADMIN_GIVE, candle, 0, 2, Vector3.ZERO)
	items.action(7, Net.ACT_RELIGHT, 0, slot + 1, 0, Vector3.ZERO)
	check(inv.numbers[slot] == LIT and inv.wear[slot] == 0 and inv.count_of(candle) == 1, "with a candle: one goes in and the lantern burns afresh")

	# E at a burning fire with a spent lantern and a doused torch: the fire lights the torch; the lantern waits for its own key and fuel.
	inv.numbers[slot] = DARK
	inv.wear[slot] = int(BURN_S * 10.0)
	var held_candle: int = inv.numbers.find(candle)
	inv.numbers[held_candle] = 0
	inv.counts[held_candle] = 0
	items.action(7, Net.ACT_ADMIN_GIVE, table.number_of("torch_doused"), 0, 1, Vector3.ZERO)
	var torch_slot: int = inv.numbers.find(table.number_of("torch_doused"))
	items._items[900001] = {"pos": Vector3(101.0, 5.0, 100.0), "fire": {"state": 1}}
	items.action(7, Net.ACT_RELIGHT, 900001, 0, 0, Vector3.ZERO)
	check(inv.numbers[slot] == DARK and torch_slot >= 0 and inv.numbers[torch_slot] == table.number_of("torch"), "a fire lights the torch and skips the lantern with no fuel")
	items._items.erase(900001)

	# A torch still burns down to nothing.
	inv.wear[torch_slot] = int(float(torch.get("burn_s", 1800.0)) * 10.0) - 5
	items._torch_seen.erase(7)
	items.action(7, Net.ACT_TORCH_BURN, torch_slot, 0, 0, Vector3.ZERO)
	check(inv.numbers[torch_slot] == 0, "a torch still burns down to nothing")

	if failures == 0:
		print("test_carried_lantern: all passed")

	quit(1 if failures > 0 else 0)
