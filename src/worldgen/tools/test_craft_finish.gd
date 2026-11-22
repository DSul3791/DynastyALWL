extends SceneTree

# A craft that runs its countdown either gives its product or says why not (Dave 17 Nov 2026, build 826: a Wooden - Shovel made at the river with his
# supplies on the ground ran its countdown, took nothing and gave nothing). The wooden shovel keeps a Stone; a kept item that is not a hand tool may
# lie on the ground within reach, as the queue already allowed, and the finish now asks the same. And the countdown the client is sent is the time the
# server finishes on: the head craft's time is fixed when it starts, so it never runs past zero.
#   godot --headless --path . --script res://src/worldgen/tools/test_craft_finish.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")

var failures: int = 0
var items
var said: Array = []
var left_sent: int = -1
var shovel_recipe: int = 0
var stick: int = 0
var stone: int = 0
var shovel: int = 0


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func pack(number: int) -> int:
	return items.inventory_of(1).count_of(number)


func ground(number: int) -> int:
	var n: int = 0

	for id in items._items:
		var it: Dictionary = items._items[id]

		if int(it.get("number", 0)) == number and not it.has("struct") and not it.has("scatter"):
			n += int(it["count"])

	return n


func reset() -> void:
	for k in items._items.keys():
		var it: Dictionary = items._items[k]

		if not it.has("scatter") and not it.has("tree") and not it.has("boulder"):
			items._items.erase(k)

	var inv = items.inventory_of(1)

	for number in [stick, stone, shovel]:
		inv.remove(number, inv.count_of(number))

	items._craft_queues[items._peer_key[1]] = {"entries": [], "elapsed": 0.0}
	said.clear()
	left_sent = -1


func queue_shovel() -> void:
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, shovel_recipe, 0, 1, CraftHand.at(items, 1, shovel_recipe))


func _init() -> void:
	var dir: String = "user://test_craft_finish"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, t): said.append(str(t))
	items.send_carry = func(_p, _id): pass
	items.send_chest = func(_p, _id, _b): pass
	items.send_craft_stock = func(_p, _n, _c): pass
	items.send_craft_queue = func(_p, _entries, left_ms): left_sent = int(left_ms)
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.peer_connected_hello(1, "craftfinish001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items.vitals_of(1)["weight"] = 2000.0
	items.admin_mode_on = func(_p): return false
	stick = items.table.number_of("stick")
	stone = items.table.number_of("stone")
	shovel = items.table.number_of("wooden_shovel")

	for k in items.recipes.numbers():
		var r: Dictionary = items.recipes.recipe(int(k))

		if not r.get("gives", []).is_empty() and int(r["gives"][0]) == shovel and not bool(r.get("retired", false)):
			shovel_recipe = int(k)

	check(stick > 0 and stone > 0 and shovel > 0 and shovel_recipe > 0, "the Wooden - Shovel recipe (2 sticks, keeps a stone) is in the table")
	reset()

	# 1. Dave's case: sticks in the pack, the stone it keeps lying on the ground beside him.
	items.inventory_of(1).add(stick, 2)
	items.drop_in_world(stone, 1, Vector3(1.5, 10.0, 0.0))
	queue_shovel()
	check(items.craft_queue_of(1).size() == 1 and pack(stick) == 0, "with the stone on the ground the shovel is queued and its sticks taken")
	items._craft_tick(float(left_sent) / 1000.0 + 0.01)
	check(pack(shovel) == 1 and items.craft_queue_of(1).is_empty(), "at the end of the countdown the shovel is in the pack (was: refunded, nothing given)")
	check(ground(stone) == 1 and pack(stone) == 0, "the kept stone stays where it lay")

	# 2. The stone is taken away during the countdown: refunded, and the player is told which item, plainly.
	reset()
	items.inventory_of(1).add(stick, 2)
	items.drop_in_world(stone, 1, Vector3(1.5, 10.0, 0.0))
	queue_shovel()

	for k in items._items.keys():
		if int(items._items[k].get("number", 0)) == stone and not items._items[k].has("scatter"):
			items._items.erase(k)

	said.clear()
	items._craft_tick(float(left_sent) / 1000.0 + 0.01)
	var last: String = str(said[said.size() - 1]) if not said.is_empty() else ""
	check(pack(shovel) == 0 and pack(stick) == 2 and items.craft_queue_of(1).is_empty(), "no stone at the end: no shovel, the sticks come back")
	check(last.contains("stone") and last.contains("Nothing was used"), "and it says so: \"%s\"" % last)

	# 3. A stone in the pack still works.
	reset()
	items.inventory_of(1).add(stick, 2)
	items.inventory_of(1).add(stone, 1)
	queue_shovel()
	items._craft_tick(float(left_sent) / 1000.0 + 0.01)
	check(pack(shovel) == 1 and pack(stone) == 1, "a stone in the pack: the shovel is made and the stone kept")

	# 4. The countdown is the finish: a change of pace during the craft (here the recipe's time itself) no longer moves the end.
	reset()
	items.inventory_of(1).add(stick, 2)
	items.inventory_of(1).add(stone, 1)
	queue_shovel()
	var promised_ms: int = left_sent
	var craft_s: float = float(items.recipes.recipe(shovel_recipe).get("craft_s", 3.0))
	check(promised_ms > 0, "the client is told %d ms" % promised_ms)
	items._craft_tick(0.1)   # the craft starts: its time is fixed
	check(left_sent > 0 and absi(left_sent - (promised_ms - 100)) <= 5, "starting re-sends the same countdown (%d ms)" % left_sent)
	items.recipes.recipe(shovel_recipe)["craft_s"] = craft_s * 3.0   # slower pace mid-craft (cold, the Rested buff ending)
	items._craft_tick(float(promised_ms) / 1000.0 - 0.4)
	check(pack(shovel) == 0, "not done before the countdown ends")
	items._craft_tick(0.31)
	check(pack(shovel) == 1, "done when the countdown ends, not later")
	items.recipes.recipe(shovel_recipe)["craft_s"] = craft_s

	# 5. Queuing more of the craft that is last in the queue never takes ingredients it will not use: the entry holds at most
	# CRAFT_QUEUE_MAX_COUNT, the rest starts a new entry (was: 15 then 10 took 25 crafts' sticks and made 20).
	reset()
	items.inventory_of(1).add(stick, 50)
	items.inventory_of(1).add(stone, 1)
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, shovel_recipe, 0, 15, CraftHand.at(items, 1, shovel_recipe))
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, shovel_recipe, 0, 10, CraftHand.at(items, 1, shovel_recipe))
	var queued: int = 0

	for e in items._craft_queues[items._peer_key[1]]["entries"]:
		queued += int(e[1])

	check(queued == 25 and pack(stick) == 0, "15 then 10 shovels: 25 queued for the 50 sticks taken (%d queued, %d sticks left)" % [queued, pack(stick)])
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_CANCEL, 0, 0, 0, Vector3.ZERO)
	check(pack(stick) == 50 and items.craft_queue_of(1).is_empty(), "cancelling both gives every stick back (%d)" % pack(stick))

	print("test_craft_finish: %s (%d failures)" % ["PASS" if failures == 0 else "FAIL", failures])
	quit(1 if failures > 0 else 0)
