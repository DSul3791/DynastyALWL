extends SceneTree

# The first town loop (Radar, 2026-10-21; Steve's refill 11 item 1): a new character arrives, meets Hob, gathers, crafts an axe and a
# chopping block, splits firewood, does Hob's quest, trades, cooks, eats, sleeps, learns a trade, and the vitals curve is printed.
# Every step runs on the real server code (items, NPCs, dialogue, trade). Fails loudly when any step is impossible.
#   godot --headless --path . --script res://src/worldgen/tools/test_first_town.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const NpcsScript := preload("res://src/stream/server_npcs.gd")
const DialogueScript := preload("res://src/stream/server_dialogue.gd")
const TradeScript := preload("res://src/stream/server_trade.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const SkillWebScript := preload("res://src/shared/skill_web.gd")
const Net := preload("res://src/stream/terrain_net.gd")

var failures: int = 0
var step: int = 0
var items
var talk
var said: Array = []
var curve: Array = []


func check(ok: bool, what: String) -> void:
	step += 1

	if not ok:
		failures += 1
		print("FAIL step %d: %s" % [step, what])


func count(id: String) -> int:
	return items.count_for(1, id)


func slot_of(id: String) -> int:
	return items.inventory_of(1).numbers.find(items.table.number_of(id))


func mark(label: String) -> void:
	var v: Dictionary = items.vitals_of(1)
	curve.append("%-22s health %5.1f  fed %6.0f  energy %5.1f  warmth %5.1f  purse %d" % [label, float(v["health"]), float(v["fed"]), items.energy_of(1), float(v.get("warmth", 100.0)), items.coins_of(1)])


func pass_time(seconds: float, exertion: float) -> void:
	for _s in range(int(seconds)):
		items._exertion[1] = exertion
		items.tick(1.0)


func craft(recipe: int, crafts: int) -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, recipe, 0, crafts, Vector3.ZERO)
	pass_time(10.0 * float(crafts), 0.2)


func say(choice: int) -> Dictionary:
	talk._last_msec.clear()
	talk.talk(1, "hob", choice)
	return said.back() if not said.is_empty() else {}


func choice_index(label: String) -> int:
	var c: Array = said.back()["choices"] if not said.is_empty() else []

	for i in c.size():
		if str(c[i]) == label:
			return i

	return -1


func _init() -> void:
	var dir: String = "user://test_first_town"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	var table = ItemTableScript.load_default()
	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.ground_height = func(_x, _z): return 10.0
	items.respawn_point = Vector3(5.0, 10.0, 5.0)
	items.setup(table, dir)
	items.peer_connected_hello(1, "first-town-key01")
	items._vitals_cfg["eat_pace_ms"] = 0
	items.vitals_of(1)["weight"] = 90.0
	var npcs = NpcsScript.new()
	NpcsScript.test_hold_off = true
	var hour: Array = [12.5]
	npcs.hour_now = func(): return hour[0]
	npcs.ground_height = func(_x, _z): return 10.0
	npcs.player_positions = func(): return items.peer_positions()
	npcs.setup(dir)
	talk = DialogueScript.new()
	talk.items = items
	talk.npcs = npcs
	talk.hour_now = func(): return hour[0]
	talk.send_say = func(peer, id, npc_name, text, voice, choices, ends): said.append({"peer": peer, "id": id, "name": npc_name, "text": text, "voice": voice, "choices": choices, "ends": ends})
	talk.setup(dir)
	var trade = TradeScript.new()
	trade.items = items
	trade.npcs = npcs
	trade.setup()
	var window: Array = []
	trade.send_shop = func(_p, _npc, _title, ids, pay, got, _buys, _ti, _tm, _st, _su, _tp):
		window.clear()
		window.append_array([ids, pay, got])
	var chair: Dictionary = npcs.markers["chair_1"]

	# 1. Arrive at the spawn: healthy, empty-handed, the purse empty.
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	check(items.vitals_of(1)["health"] >= 99.0 and count("stone") == 0 and items.coins_of(1) == 0, "a new character arrives healthy, empty-handed and with an empty purse")
	mark("arrive")

	# 2. Walk to Hob and talk.
	items.report_position(1, Vector3(float(chair["x"]) + 1.0, 10.0, float(chair["z"])))
	npcs.tick(0.2)
	npcs.tick(0.2)
	check(npcs.npcs["hob"]["placed"], "Hob is there when the player walks up")
	var first: Dictionary = say(-1)
	check(not first.is_empty() and str(first["text"]).contains("Hob") and not first["choices"].is_empty(), "Hob introduces himself and offers choices")
	say(2)   # Goodbye
	mark("met Hob")

	# 3. Gather what lies about, craft a knife, an axe and a chopping block (a log lies at the camp), place the block.
	var camp: Vector3 = Vector3(float(chair["x"]) + 1.0, 10.0, float(chair["z"]))

	items.drop_in_world(table.number_of("log"), 2, camp + Vector3(0.5, 0.0, 0.5))

	for n in range(4):
		items.drop_in_world(table.number_of("stone"), 4, camp + Vector3(float(n) * 0.3, 0.0, 1.0))
		items.drop_in_world(table.number_of("stick"), 6, camp + Vector3(float(n) * 0.3, 0.0, -1.0))
		items.drop_in_world(table.number_of("plant_fibre"), 3, camp + Vector3(float(n) * 0.3, 0.0, 1.5))

	for id in items._items.keys():
		items.action(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)

	check(count("stone") >= 14 and count("stick") >= 20 and count("log") == 2, "gathering fills the pack (%d stones, %d sticks, %d logs)" % [count("stone"), count("stick"), count("log")])
	craft(2, 1)
	craft(6, 1)
	craft(15, 1)
	check(count("stone_axe") == 1 and count("stone_knife") == 1 and count("chopping_block_kit") == 1, "an axe, a knife and a chopping block kit are made by hand")
	items.action(1, Net.ACT_MOVE, slot_of("stone_axe"), 0, 0, Vector3.ZERO)   # the axe goes on the hotbar
	items.action(1, Net.ACT_PLACE, slot_of("chopping_block_kit"), 0, 0, Vector3(float(chair["x"]) + 2.0, 10.0, float(chair["z"])))
	var block: int = 0

	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "chopping_block":
			block = id

	check(block != 0, "the chopping block is placed in the camp")
	mark("crafted")

	# 4. Split logs into firewood at the block.
	items.report_position(1, items._items[block]["pos"] + Vector3(1.0, 0.0, 0.0))
	items._last_use.clear()
	items.action(1, Net.ACT_USE_STRUCT, block, 0, 0, Vector3.ZERO)
	check(count("firewood") == 4 and count("log") == 0, "a log splits into four firewood at the block (%d firewood, %d logs)" % [count("firewood"), count("log")])
	items.action(1, Net.ACT_ADMIN_GIVE, table.number_of("log"), 0, 1, Vector3.ZERO)   # a second log was dragged in from the woods
	mark("split wood")

	# 5. Hob's quest: ask, hand over the firewood, get the reward and the reputation.
	items.report_position(1, Vector3(float(chair["x"]) + 1.0, 10.0, float(chair["z"])))
	npcs.tick(0.2)
	say(-1)
	check(choice_index("Can I help with anything?") >= 0, "a known visitor is offered the quest")
	say(choice_index("Can I help with anything?"))
	say(0)
	say(-1)
	var give: int = choice_index("I have your firewood.")
	check(give >= 0, "with the firewood in the pack the hand-over choice appears")
	say(give)
	check(count("firewood") == 1 and count("roast_forage") == 2 and items.coins_of(1) == 5 and items.rep_points(1, "hob") == 1, "the reward is two roast forage, five copper and a reputation point")
	mark("quest done")

	# 6. Trade: sell some stones and the spare log, then buy a bandage.
	check(trade.open(1, "hob") and not window.is_empty(), "Hob's stall opens")
	var before_sale: int = items.coins_of(1)
	trade.deal(1, "hob", 1, items.inventory_of(1).numbers.find(table.number_of("log")), 1)
	check(items.coins_of(1) > before_sale, "the spare log sells for coin (%d to %d)" % [before_sale, items.coins_of(1)])
	items.add_coins(1, 20)   # a day's small earnings
	var bandage: int = (window[0] as PackedStringArray).find("bandage")
	var purse: int = items.coins_of(1)
	trade.deal(1, "hob", 0, bandage, 1)
	check(count("bandage") == 1 and items.coins_of(1) < purse, "a bandage is bought with the coin")
	mark("traded")

	# 7. Cook at a campfire and eat: a fire kit, placed, roasts a hunted piece of meat.
	items.action(1, Net.ACT_ADMIN_GIVE, table.number_of("campfire_kit"), 0, 1, Vector3.ZERO)
	var fire_spot: Vector3 = Vector3(float(chair["x"]) + 3.0, 10.0, float(chair["z"]) + 3.0)
	items.report_position(1, fire_spot + Vector3(1.5, 0.0, 0.0))
	items.action(1, Net.ACT_PLACE, slot_of("campfire_kit"), 0, 0, fire_spot)
	var fire: int = 0

	for id in items._items:
		if items._items[id].has("fire") and int(items._items[id]["fire"]["state"]) == 1:
			fire = id

	check(fire != 0, "the campfire burns")
	items.action(1, Net.ACT_ADMIN_GIVE, table.number_of("raw_meat"), 0, 2, Vector3.ZERO)
	items.report_position(1, items._items[fire]["pos"] + Vector3(1.0, 0.0, 0.0))
	items._last_cook.clear()
	items.action(1, Net.ACT_COOK, fire, 0, 0, Vector3.ZERO)
	check(count("roast_meat") >= 1, "the fire roasts the meat (%d roast)" % count("roast_meat"))
	items.vitals_of(1)["fed"] = 700.0
	var fed_before: float = float(items.vitals_of(1)["fed"])
	items._last_eat.clear()
	items.action(1, Net.ACT_EAT, slot_of("roast_meat"), 0, 0, Vector3.ZERO)
	check(float(items.vitals_of(1)["fed"]) > fed_before, "the roast meat is eaten and feeds")
	mark("cooked and ate")

	# 8. Sleep: tired, lie down by the fire, wake rested and warm.
	items.vitals_of(1)["energy"] = 30.0
	items.action(1, Net.ACT_STANCE, 3, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_SLEEP, 1, 0, 0, Vector3.ZERO)
	check(items.sleeping_of(1), "lying down, the character falls asleep")
	pass_time(200.0, 0.0)
	check(items.energy_of(1) > 30.0 and float(items.vitals_of(1)["health"]) >= 99.0, "sleep restores energy and health stays full (%.1f)" % items.energy_of(1))
	items.action(1, Net.ACT_SLEEP, 0, 0, 0, Vector3.ZERO)
	items.action(1, Net.ACT_STANCE, 0, 0, 0, Vector3.ZERO)
	mark("slept")

	# 9. Train: practice trades to the cap, then Hob's lesson raises the training level.
	var rec: Dictionary = items._skill_records(1)
	rec["trades"] = {"p": SkillWebScript.units_for(items._skills_cfg, "trades", 22.0), "peak": 0.0, "t": 0}
	items.action(1, Net.ACT_ADMIN_GIVE, table.number_of("stone"), 0, 3, Vector3.ZERO)
	items.report_position(1, Vector3(float(chair["x"]) + 1.0, 10.0, float(chair["z"])))
	say(-1)
	var lesson: int = choice_index("Teach me the trade.")
	check(lesson >= 0, "near the cap, with the stones, the lesson is offered")
	say(lesson)
	check(int(items._skill_records(1)["trades"]["t"]) == 1, "the lesson raises the training level")
	mark("trained")

	print("")

	for line in curve:
		print(line)

	items._finish_writer()
	print("first town: %d steps, %d failures" % [step, failures])
	quit(1 if failures > 0 else 0)
