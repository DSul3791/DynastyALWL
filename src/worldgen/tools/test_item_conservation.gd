extends SceneTree

# Nothing is made or lost by moving things about (to-do sweep 23 Nov 2026: hunt item loss and duplication in the first hours).
# Two players stand by a chest and a heap of ground stacks and do thousands of random everyday actions on the real server: move and split
# pack slots, drop and pick up, put into and take from the chest (both of them, the same chest open at once), Take all, Store all,
# Stack to nearby, Sort, leave and come back, and the server saving and restarting. After every action each item's total over both packs,
# what they wear, every container and the ground must be what it was. A broken total prints the last actions.
#   godot --headless --path . --script res://src/worldgen/tools/test_item_conservation.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const BagRules := preload("res://src/shared/bag_rules.gd")
const DIR := "user://test_item_conservation"
const HERE := Vector3(5.0, 10.0, 0.0)
const KEYS := {1: "conserveone01", 2: "conservetwo02"}
const STEPS := 1500
const SEEDS := [11, 23, 57]

var failures: int = 0
var items
var chest_id: int = 0
var crate_id: int = 0
var log_lines: Array = []


func check(ok: bool, what: String) -> void:
	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1


func make_server():
	var s = ItemsScript.new()
	s.send_full = func(_p, _b): pass
	s.send_slots = func(_p, _b): pass
	s.send_world_items = func(_p, _a, _r): pass
	s.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	s.send_reject = func(_p, _r): pass
	s.send_notice = func(_p, _t): pass
	s.send_carry = func(_p, _id): pass
	s.send_chest = func(_p, _id, _b): pass
	s.send_chest_info = func(_p, _id, _k, _m): pass
	s.send_chest_lock = func(_p, _id, _l, _m, _o, _w, _a): pass
	s.send_craft_stock = func(_p, _n, _c): pass
	s.send_bulk_done = func(_p, _k, _s, _c, _i): pass
	s.ground_height = func(_x, _z): return 10.0
	s.setup(ItemTableScript.load_default(), DIR)
	s.admin_mode_on = func(_p): return false
	s.game_seconds = func(): return 1000.0 * 86400.0
	s.skill_level = func(_p, _s): return 1.0
	return s


func join(peer: int) -> void:
	items.peer_connected_hello(peer, KEYS[peer])
	items.report_position(peer, HERE + Vector3(float(peer) * 0.5, 0.0, 0.0))
	items.vitals_of(peer)["weight"] = 200.0   # a big frame: the carry limit is not what is tested


func n(id: String) -> int:
	return items.table.number_of(id)


# number -> total over packs, worn, containers and loose ground stacks.
func totals() -> Dictionary:
	var out: Dictionary = {}
	var kit: int = n("campfire_kit")
	var stone: int = n("stone")
	var stick: int = n("stick")
	var start: int = items._fire_start_sticks()
	var twine: int = n("twine")
	var fibre: int = n("plant_fibre")
	var add = func(number: int, count: int) -> void:
		if number == twine:   # a Twine is the 3 Plant fibre it is twisted from (recipe 1), so twisting and cancelling keep the totals
			out[fibre] = int(out.get(fibre, 0)) + 3 * count
		elif number == kit:   # a Campfire kit is what it is made of (16 stones, 6 sticks): a laid fire keeps its first sticks in its store
			out[stone] = int(out.get(stone, 0)) + 16 * count
			out[stick] = int(out.get(stick, 0)) + 6 * count
		elif number > 0 and count > 0:
			out[number] = int(out.get(number, 0)) + count

	for key in items._inventories:
		var inv = items._inventories[key]

		for i in inv.slot_count:
			add.call(inv.numbers[i], inv.counts[i])

	for peer in [1, 2]:
		items._end_bag_edit(peer)   # a worn bag's open copy written back to what it wears

	for key in items._characters:
		for raw in items._characters[key].get("worn", []):
			var entry: Array = ItemsScript._worn_entry(raw)
			add.call(int(entry[0]), int(entry[1]))

			if int(entry[0]) > 0 and BagRules.slots_of(items.table, int(entry[0])) > 0:
				var bag = BagRules.open(items.table, int(entry[0]), entry[3])

				for i in bag.slot_count:
					add.call(bag.numbers[i], bag.counts[i])

	for uid in items._chests:
		var box = items._chests[uid]

		for i in box.slot_count:
			add.call(box.numbers[i], box.counts[i])

	for key in items._craft_queues:   # what a queued craft has taken and holds until it finishes or is cancelled
		for entry in items._craft_queues[key]["entries"]:
			for need in entry[2]:
				add.call(int(need[0]), int(need[1]) * int(entry[1]))

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct"):
			var kit_id: String = str(items._structures.get(str(it["struct"]["kind"]), {}).get("kit", ""))
			add.call(items.table.number_of(kit_id) if kit_id != "" else int(it["number"]), 1)
			continue

		if it.has("fire"):   # the laid fire's stones and the sticks that are not its first fuel
			add.call(stone, 16)
			add.call(stick, 6 - start)
			continue

		if it.has("tree") or it.has("scatter") or it.has("boulder"):
			continue

		add.call(int(it["number"]), int(it["count"]))

	return out


func diff(a: Dictionary, b: Dictionary) -> String:
	var bad: Array = []

	for number in a.keys() + b.keys():
		if int(a.get(number, 0)) != int(b.get(number, 0)) and not bad.has(number):
			bad.append(number)

	return ", ".join(bad.map(func(number): return "%s %d -> %d" % [items.table.id_of(number), int(a.get(number, 0)), int(b.get(number, 0))]))


func filled_slot(inv, rng: RandomNumberGenerator) -> int:
	var full: Array = []

	for i in inv.slot_count:
		if inv.numbers[i] != 0:
			full.append(i)

	return -1 if full.is_empty() else int(full[rng.randi() % full.size()])


func box_slot(box, rng: RandomNumberGenerator) -> int:
	var full: Array = []

	for i in box.slot_count:
		if box.numbers[i] != 0:
			full.append(i)

	return -1 if full.is_empty() else int(full[rng.randi() % full.size()])


func box_ids() -> Array:
	var out: Array = []

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("fire") or (it.has("struct") and it["struct"].has("uid")):
			out.append(id)

	return out


func ground_ids() -> Array:
	var out: Array = []

	for id in items._items:
		var it: Dictionary = items._items[id]

		if not (it.has("struct") or it.has("tree") or it.has("scatter") or it.has("fire") or it.has("boulder")):
			out.append(id)

	return out


func restart() -> void:
	items.save()
	items._finish_writer()
	items = make_server()
	join(1)
	join(2)


# One random everyday action; returns what it was, for the log.
func step(rng: RandomNumberGenerator) -> String:
	var peer: int = 1 + rng.randi() % 2
	var inv = items.inventory_of(peer)
	var roll: int = rng.randi() % 120
	var boxes: Array = box_ids()
	var box_id: int = int(boxes[rng.randi() % boxes.size()]) if not boxes.is_empty() else 0

	if rng.randf() < 0.15:
		box_id = -1 - rng.randi() % 12   # a worn position: a worn bag, or nothing
		items._chest_viewer[peer] = box_id

	var box = items._chest_of(peer, box_id) if box_id != 0 else null

	if roll >= 112:
		items._last_queue_act.clear()
		var c: int = 1 + rng.randi() % 4
		items.action(peer, Net.ACT_CRAFT_QUEUE, 1, 0, c, Vector3.ZERO)
		return "p%d queue twine x%d" % [peer, c]
	elif roll >= 106:
		items._last_queue_act.clear()
		var at: int = rng.randi() % 3
		items.action(peer, Net.ACT_CRAFT_CANCEL, at, 0, 0, Vector3.ZERO)
		return "p%d cancel %d" % [peer, at]
	elif roll >= 100:
		var secs: int = 1 + rng.randi() % 3

		for k in secs:
			items.tick(1.0)

		return "%d s pass" % secs
	elif roll < 12:
		var a: int = rng.randi() % inv.slot_count
		var b: int = rng.randi() % inv.slot_count
		items.action(peer, Net.ACT_MOVE, a, b, 0, Vector3.ZERO)
		return "p%d move %d->%d" % [peer, a, b]
	elif roll < 20:
		var s: int = filled_slot(inv, rng)
		var c: int = 1 + rng.randi() % 8
		items.action(peer, Net.ACT_SPLIT, s, 0, c, Vector3.ZERO)
		return "p%d split %d by %d" % [peer, s, c]
	elif roll < 30:
		var s: int = filled_slot(inv, rng)
		var c: int = 1 + rng.randi() % 10
		items.action(peer, Net.ACT_DROP, s, 0, c, HERE + Vector3(rng.randf_range(-2.0, 2.0), 0.0, rng.randf_range(-2.0, 2.0)))
		return "p%d drop %d x%d" % [peer, s, c]
	elif roll < 42:
		var ids: Array = ground_ids()

		if ids.is_empty():
			return "p%d pickup none" % peer

		var id: int = int(ids[rng.randi() % ids.size()])
		items.action(peer, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
		return "p%d pickup %d" % [peer, id]
	elif roll < 48:
		items.action(peer, Net.ACT_CHEST_OPEN, box_id, 0, 0, Vector3.ZERO)
		return "p%d open %d" % [peer, box_id]
	elif roll < 62:
		var s: int = filled_slot(inv, rng)
		var c: int = 1 + rng.randi() % 12
		var target: int = rng.randi() % 6 if rng.randf() < 0.3 else -1
		items.action(peer, Net.ACT_CHEST_PUT, s, box_id, c, Vector3(float(target + 1), 0.0, 0.0))
		return "p%d put %d x%d into %d (at %d)" % [peer, s, c, box_id, target]
	elif roll < 76:
		if box == null:
			return "p%d take none" % peer

		var s: int = box_slot(box, rng)
		var c: int = 1 + rng.randi() % 12
		items.action(peer, Net.ACT_CHEST_TAKE, s, box_id, c, Vector3.ZERO)
		return "p%d take %d x%d from %d" % [peer, s, c, box_id]
	elif roll < 82:
		var kind: int = rng.randi() % 4
		items.action(peer, Net.ACT_BULK, kind, rng.randi() % 3, 0, Vector3.ZERO)
		return "p%d bulk %d" % [peer, kind]
	elif roll < 86:
		items.action(peer, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
		return "p%d close" % peer
	elif roll < 89:
		var s: int = filled_slot(inv, rng)
		items.action(peer, Net.ACT_FAVOURITE, s, 1 if rng.randf() < 0.5 else 0, 0, Vector3.ZERO)
		return "p%d fav %d" % [peer, s]
	elif roll < 93:
		var s: int = filled_slot(inv, rng)
		items.action(peer, Net.ACT_WEAR, s, 0, 0, Vector3.ZERO)
		return "p%d wear %d" % [peer, s]
	elif roll < 96:
		var place: int = rng.randi() % 12
		items.action(peer, Net.ACT_UNWEAR, place, 0, 0, Vector3.ZERO)
		return "p%d unwear %d" % [peer, place]
	elif roll < 97 and not boxes.is_empty():
		var id: int = int(boxes[rng.randi() % boxes.size()])
		items.action(peer, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
		return "p%d take down %d%s" % [peer, id, "" if items._items.has(id) else " (taken)"]
	elif roll < 98:
		var s: int = -1

		for i in inv.slot_count:
			if inv.numbers[i] in [n("chest"), n("wooden_crate"), n("campfire_kit")]:
				s = i

		if s < 0:
			return "p%d place none" % peer

		var spot: Vector3 = HERE + Vector3(rng.randf_range(-3.0, 3.0), 0.0, rng.randf_range(1.5, 3.5))
		items.action(peer, Net.ACT_PLACE, s, 0, 0, spot)
		return "p%d place slot %d at %s" % [peer, s, spot]
	elif roll < 99:
		items.peer_left(peer)
		join(peer)
		return "p%d left and came back" % peer
	else:
		restart()
		return "server restart"


func run(seed: int) -> void:
	DirAccess.make_dir_recursive_absolute(DIR + "/" + ItemsScript.AREA_DIR)

	for sub in [DIR, DIR + "/" + ItemsScript.AREA_DIR]:
		for file in DirAccess.get_files_at(sub):
			DirAccess.remove_absolute(sub + "/" + file)

	items = make_server()
	join(1)
	join(2)
	chest_id = items.dev_place("chest@6,1")
	crate_id = items.dev_place("wooden_crate@4,1")
	items._items[chest_id]["struct"]["owner"] = KEYS[1]
	items._items[crate_id]["struct"]["owner"] = KEYS[2]
	items.give(1, n("campfire_kit"), 1)
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(n("campfire_kit")), 0, 0, HERE + Vector3(0.0, 0.0, -1.5))   # laid as a player lays it, its first sticks in its store

	for peer in [1, 2]:
		var give: Array = [["stone", 30], ["stick", 40], ["plant_fibre", 60], ["twine", 6], ["stone_axe", 1], ["leather_cap", 1], ["wicker_basket", 1], ["linseed", 50], ["campfire_kit", 1], ["chest", 1]]

		for pair in give:
			if n(pair[0]) > 0:
				items.give(peer, n(pair[0]), int(pair[1]))

	for k in range(6):
		items.drop_in_world(n("stone"), 5, HERE + Vector3(float(k) - 3.0, 0.0, 2.0))
		items.drop_in_world(n("stick"), 7, HERE + Vector3(float(k) - 3.0, 0.0, -2.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var start: Dictionary = totals()
	var broke: String = ""
	log_lines.clear()

	for i in STEPS:
		var did: String = step(rng)
		log_lines.append("%d %s" % [i, did])
		var now: Dictionary = totals()

		if now != start:
			broke = "step %d (%s): %s" % [i, did, diff(start, now)]
			print("  last actions:\n    " + "\n    ".join(log_lines.slice(maxi(log_lines.size() - 12, 0))))
			break

	var in_boxes: int = 0
	var worn: int = 0
	for uid in items._chests:
		for i in items._chests[uid].slot_count:
			in_boxes += items._chests[uid].counts[i]
	for key in items._characters:
		for raw in items._characters[key].get("worn", []):
			worn += int(ItemsScript._worn_entry(raw)[1])
	var twined: int = 0

	for key in items._inventories:
		twined += items._inventories[key].count_of(n("twine"))

	print("  end: %d in containers, %d ground stacks, %d worn, %d twine in packs (12 given)" % [in_boxes, ground_ids().size(), worn, twined])
	check(broke == "", "seed %d: %d random actions by two players keep every total (%s)" % [seed, STEPS, broke if broke != "" else "%d kinds" % start.size()])
	items._finish_writer()


# Lay a Campfire kit, take its first sticks out, pick it up and lay it again: no sticks come from nowhere. Picked up with its first sticks
# still in it, it is a whole kit again.
func campfire_round() -> void:
	DirAccess.make_dir_recursive_absolute(DIR + "/" + ItemsScript.AREA_DIR)

	for sub in [DIR, DIR + "/" + ItemsScript.AREA_DIR]:
		for file in DirAccess.get_files_at(sub):
			DirAccess.remove_absolute(sub + "/" + file)

	items = make_server()
	join(1)
	items.give(1, n("campfire_kit"), 1)
	var inv = items.inventory_of(1)
	var start: Dictionary = totals()

	for round in range(3):   # before the fix each round came back a whole kit and laid 4 more sticks; now the first round ends it
		items.action(1, Net.ACT_PLACE, inv.numbers.find(n("campfire_kit")), 0, 0, HERE + Vector3(0.0, 0.0, -1.5))
		var fire_id: int = box_ids()[0] if not box_ids().is_empty() else 0
		items.action(1, Net.ACT_CHEST_OPEN, fire_id, 0, 0, Vector3.ZERO)
		var box = items._chest_of(1, fire_id)
		items.action(1, Net.ACT_CHEST_TAKE, box.numbers.find(n("stick")), fire_id, 99, Vector3.ZERO)
		items.action(1, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
		items.action(1, Net.ACT_PICKUP, fire_id, 0, 0, Vector3.ZERO)

		if inv.count_of(n("campfire_kit")) == 0:
			break

	check(totals() == start, "lay, empty and pick up a campfire keeps every total (%s)" % diff(start, totals()))
	check(inv.count_of(n("campfire_kit")) == 0 and inv.count_of(n("stone")) == 16 and inv.count_of(n("stick")) == 6, "the empty campfire comes back as its parts: 16 stones, 6 sticks (%d kits, %d stones, %d sticks)" % [inv.count_of(n("campfire_kit")), inv.count_of(n("stone")), inv.count_of(n("stick"))])
	items.give(1, n("campfire_kit"), 1)
	start = totals()
	items.action(1, Net.ACT_PLACE, inv.numbers.find(n("campfire_kit")), 0, 0, HERE + Vector3(0.0, 0.0, -1.5))
	items.action(1, Net.ACT_PICKUP, box_ids()[0], 0, 0, Vector3.ZERO)
	check(box_ids().is_empty() and inv.count_of(n("campfire_kit")) == 1 and totals() == start, "a laid campfire still holding its first sticks comes back as a whole kit")
	# Some of its sticks, or other wood with them: not picked up (nothing given) until it is emptied, then the kit's parts.
	items.give(1, n("firewood"), 1)
	start = totals()
	items.action(1, Net.ACT_PLACE, inv.numbers.find(n("campfire_kit")), 0, 0, HERE + Vector3(0.0, 0.0, -1.5))
	var laid: int = box_ids()[0]
	items.action(1, Net.ACT_CHEST_OPEN, laid, 0, 0, Vector3.ZERO)
	var store = items._chest_of(1, laid)
	items.action(1, Net.ACT_CHEST_TAKE, store.numbers.find(n("stick")), laid, 2, Vector3.ZERO)
	items.action(1, Net.ACT_PICKUP, laid, 0, 0, Vector3.ZERO)
	check(items._items.has(laid) and store.count_of(n("stick")) == 2 and totals() == start, "a fire holding 2 of its 4 sticks is not picked up and gives nothing")
	items.action(1, Net.ACT_CHEST_PUT, inv.numbers.find(n("stick")), laid, 2, Vector3.ZERO)
	items.action(1, Net.ACT_CHEST_PUT, inv.numbers.find(n("firewood")), laid, 1, Vector3.ZERO)
	items.action(1, Net.ACT_PICKUP, laid, 0, 0, Vector3.ZERO)
	check(items._items.has(laid) and store.count_of(n("stick")) == 4 and store.count_of(n("firewood")) == 1 and totals() == start, "a fire holding its 4 sticks and a Firewood is not picked up and gives nothing")
	items.action(1, Net.ACT_CHEST_TAKE, store.numbers.find(n("firewood")), laid, 1, Vector3.ZERO)
	items.action(1, Net.ACT_PICKUP, laid, 0, 0, Vector3.ZERO)
	check(not items._items.has(laid) and inv.count_of(n("campfire_kit")) == 1 and inv.count_of(n("firewood")) == 1 and totals() == start, "with the Firewood out it comes back as a whole kit")
	items._finish_writer()


func _init() -> void:
	campfire_round()

	for seed in SEEDS:
		run(seed)

	print("item conservation: %d failures" % failures)
	quit(1 if failures > 0 else 0)
