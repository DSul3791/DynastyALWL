extends SceneTree

# Nothing is made or lost by moving things about (to-do sweep 23 Nov 2026: hunt item loss and duplication in the first hours).
# Two players stand by a chest and a heap of ground stacks and do thousands of random everyday actions on the real server: move and split
# pack slots, drop and pick up, put into and take from the chest (both of them, the same chest open at once), Take all, Store all,
# Stack to nearby, Sort, leave and come back, and the server saving and restarting. After every action each item's total over both packs,
# what they wear, every container and the ground must be what it was. A broken total prints the last actions. A yard run adds a Loom and a
# Handcart: they weave Fibre cloth into the loom's store, put into and take from the loom and the cart, take the cart's handle and pull it about
# with things in it, lift the crate onto it and set it down, let go, take the cart and the loom down for their materials, and the server
# restarts with the cart loaded or held.
#   godot --headless --path . --script res://src/worldgen/tools/test_item_conservation.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const BagRules := preload("res://src/shared/bag_rules.gd")
const Carts := preload("res://src/stream/server_carts.gd")
const DIR := "user://test_item_conservation"
const HERE := Vector3(5.0, 10.0, 0.0)
const KEYS := {1: "conserveone01", 2: "conservetwo02"}
const STEPS := 1500
const SEEDS := [11, 23, 57]
const BURN_OK := ["stick", "plant_fibre", "firewood", "linseed", "twine"]
const GROW_OK := ["charcoal"]
const FIRE_SEEDS := [5, 31]
const YARD_SEEDS := [7, 41, 88]
const LATE_STEP := 1000   # yard runs take the cart, the crate and the loom down only from this step on

var failures: int = 0
var items
var chest_id: int = 0
var crate_id: int = 0
var log_lines: Array = []
var fire_mode: bool = false   # a run that lights, feeds, puts out and cooks at the fire, hours passing: wood and tinder may only go down, charcoal only up
var yard_mode: bool = false   # a run with a Loom and a Handcart (stations and carts)
var clock: Array = [1.0e6]
var said: Dictionary = {}     # peer -> the last notice, for the log
var step_at: int = 0          # the run's step: the cart, the crate and the loom come down only in its last third
var seen: Dictionary = {}     # what the yard runs did, over all seeds: each must have happened, or the run tested nothing


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
	s.send_notice = func(p, t): said[p] = str(t)
	s.send_carry = func(_p, _id): pass
	s.send_chest = func(_p, _id, _b): pass
	s.send_chest_info = func(_p, _id, _k, _m): pass
	s.send_chest_lock = func(_p, _id, _l, _m, _o, _w, _a): pass
	s.send_craft_stock = func(_p, _n, _c): pass
	s.send_bulk_done = func(_p, _k, _s, _c, _i): pass
	s.send_cart_pull = func(_p, _id, _pace): pass
	s.send_items_moved = func(_p, _ids, _at, _yaws): pass
	s.ground_height = func(_x, _z): return 10.0

	if yard_mode:
		s.water_depth_at = func(_pos: Vector3) -> float: return 0.0
		s.unix_now = func(): return clock[0]

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
	var cloth: int = n("fibre_cloth")
	var add = func(number: int, count: int) -> void:
		if number == twine:   # a Twine is the 3 Plant fibre it is twisted from (recipe 1), so twisting and cancelling keep the totals
			out[fibre] = int(out.get(fibre, 0)) + 3 * count
		elif number == cloth:   # a Fibre cloth is the 8 Plant fibre the loom weaves it from
			out[fibre] = int(out.get(fibre, 0)) + 8 * count
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

		if it.has("struct") and str(it["struct"]["kind"]) == "remains":
			continue   # a body: only what lies on it counts (its store, above)

		if it.has("struct"):
			var kit_id: String = str(items._structures.get(str(it["struct"]["kind"]), {}).get("kit", ""))

			if items._blueprint_of_kit.has(kit_id):   # a built piece (the Loom, the Handcart) is the materials it gives back when taken down
				var row: Dictionary = items._blueprints[int(items._blueprint_of_kit[kit_id])]

				for need in row["cost"]:
					var count: int = int(need[1])

					for burnt in row.get("spent", []):   # a lantern's candle burns away (_refund_blueprint)
						if str(burnt[0]) == str(need[0]):
							count = maxi(count - int(burnt[1]), 0)

					for pair in items._kinds_back(str(need[0]), count, it["struct"].get("kinds", {})):
						add.call(int(pair[0]), int(pair[1]))

				continue

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


func cart_id() -> int:
	for id in items._items:
		if not items._carts.vehicle_of(items._items[id]).is_empty():
			return id

	return 0


func loom_id() -> int:
	for id in items._items:
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "loom":
			return id

	return 0


func recipe_number(id: String) -> int:
	for r in items.recipes.numbers():
		if str(items.recipes.recipe(int(r)).get("id", "")) == id:
			return int(r)

	return 0


func totals_has_cloth() -> bool:
	for key in items._inventories:
		if items._inventories[key].count_of(n("fibre_cloth")) > 0:
			return true

	for uid in items._chests:
		if items._chests[uid].count_of(n("fibre_cloth")) > 0:
			return true

	return false


func home(peer: int) -> Vector3:
	return HERE + Vector3(float(peer) * 0.5, 0.0, 0.0)


# One station or cart action: weave at the loom, take or let go of the cart's handle, pull it a few metres and back, lift the crate on or
# set it down.
func yard_step(peer: int, rng: RandomNumberGenerator) -> String:
	var cart: int = cart_id()
	var what: int = rng.randi() % 6

	for id in items._items:   # the crate taken down and laid again has a new world id
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "wooden_crate":
			crate_id = id

	for id in ground_ids():   # weaving and pulling pass time: loose stacks would despawn (WORLD_ITEM_LIFETIME_S), which is not what this run checks
		items._items[id]["left"] = maxf(float(items._items[id]["left"]), 1.0e7)

	if step_at >= LATE_STEP and rng.randf() < 0.03:   # empty the cart or the loom into the pack and take it down for its materials
		var id: int = cart if cart != 0 and rng.randf() < 0.5 else loom_id()

		if id == 0:
			return "p%d nothing to take down" % peer

		items.action(peer, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
		var store = items._chest_of(peer, id)

		for slot in (store.slot_count if store != null else 0):
			if store.numbers[slot] != 0:
				items.action(peer, Net.ACT_CHEST_TAKE, slot, id, store.counts[slot], Vector3.ZERO)

		items.action(peer, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)
		items.action(peer, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)
		return "p%d empties and takes down %d%s" % [peer, id, " (stands: %s)" % said.get(peer, "") if items._items.has(id) else ""]

	if what == 0:
		var r: int = recipe_number("fibre_cloth")
		var c: int = 1 + rng.randi() % 3
		items._last_queue_act.clear()
		var queued: int = items.craft_queue_of(peer).size()
		items.action(peer, Net.ACT_CRAFT_QUEUE, r, 0, c, Vector3.ZERO)

		if items.craft_queue_of(peer).size() > queued:
			seen["weave queued"] = int(seen.get("weave queued", 0)) + 1

		for k in range(31 * c if rng.randf() < 0.5 else 5):   # often long enough to weave it (30 s a cloth), else cut short by what comes next
			items.tick(1.0)

		return "p%d weave cloth x%d (loom %d)" % [peer, c, loom_id()]

	if cart == 0:
		return "p%d no cart" % peer

	if what == 1:
		items.action(peer, Net.ACT_CART, cart, Carts.OP_GRAB, 0, Vector3.ZERO)
		return "p%d grab cart %d%s" % [peer, cart, " (holds it)" if int(items._carts.puller_of.get(peer, 0)) == cart else ""]
	elif what == 2:
		items.action(peer, Net.ACT_CART, 0, Carts.OP_RELEASE, 0, Vector3.ZERO)
		return "p%d let go" % peer
	elif what == 3:
		items.action(peer, Net.ACT_CART, crate_id, Carts.OP_LOAD, 0, Vector3.ZERO)
		return "p%d lift crate %d on%s" % [peer, crate_id, (" (on)" if items._items[crate_id]["struct"].has("on") else " (stays: %s)" % said.get(peer, "")) if items._items.has(crate_id) else " (gone)"]
	elif what == 4:
		items.action(peer, Net.ACT_CART, crate_id, Carts.OP_UNLOAD, 0, Vector3.ZERO)
		return "p%d set crate %d down" % [peer, crate_id]

	# A walk of up to 4 m and back in 0.2 s reports of 0.4 m: a puller pulls the cart along.
	var dir := Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized()
	var metres: float = rng.randf_range(1.0, 4.0)
	var at: Vector3 = home(peer)
	var steps: int = int(ceil(metres / 0.4))
	var was: Vector3 = items._items[cart]["pos"]

	for k in range(steps * 2):
		at += dir * (0.4 if k < steps else -0.4)
		clock[0] += 0.2
		items.report_position(peer, at)
		items.tick(0.2)

	items.report_position(peer, home(peer))

	if items._items.has(cart) and items._items[cart]["pos"].distance_to(was) > 0.5:
		seen["cart pulled"] = int(seen.get("cart pulled", 0)) + 1

		if not items._carts.riders_of(cart).is_empty():
			seen["cart pulled with the crate on"] = int(seen.get("cart pulled with the crate on", 0)) + 1

		if not items._struct_empty(cart):
			seen["cart pulled loaded"] = int(seen.get("cart pulled loaded", 0)) + 1

	return "p%d walks %.1f m and back%s" % [peer, metres, " pulling" if int(items._carts.puller_of.get(peer, 0)) != 0 else ""]


func restart() -> void:
	items.save()
	items._finish_writer()
	items = make_server()
	join(1)
	join(2)
	crate_id = 0

	for id in items._items:   # world ids are given out again at load
		if items._items[id].has("struct") and str(items._items[id]["struct"]["kind"]) == "wooden_crate":
			crate_id = id


# One random everyday action; returns what it was, for the log.
func step(rng: RandomNumberGenerator) -> String:
	var peer: int = 1 + rng.randi() % 2
	var inv = items.inventory_of(peer)
	var roll: int = rng.randi() % 120

	if yard_mode and rng.randf() < 0.2:
		return yard_step(peer, rng)

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
	elif roll >= 100 and yard_mode and rng.randf() < 0.7:
		return yard_step(peer, rng)
	elif roll >= 100 and fire_mode and rng.randf() < 0.6:
		var fires: Array = boxes.filter(func(i): return items._items.has(i) and items._items[i].has("fire"))

		if fires.is_empty():
			return "p%d no fire" % peer

		var f: int = int(fires[rng.randi() % fires.size()])
		var what: int = rng.randi() % 4
		var names: Array = ["light", "fuel", "put out", "cook"]
		var acts: Array = [Net.ACT_LIGHT, Net.ACT_FUEL, Net.ACT_USE_STRUCT, Net.ACT_COOK]
		items.action(peer, acts[what], f, 0, 0, Vector3.ZERO)
		return "p%d %s fire %d (state %d)" % [peer, names[what], f, int(items._items[f]["fire"]["state"]) if items._items.has(f) else -1]
	elif roll >= 100:
		var secs: int = (1 + rng.randi() % 3) * (60 if fire_mode else 1)

		if fire_mode or yard_mode:
			for id in ground_ids():   # hours pass: loose stacks would despawn (WORLD_ITEM_LIFETIME_S, a rule of its own, for Dave), which is not what this run checks
				items._items[id]["left"] = maxf(float(items._items[id]["left"]), 1.0e7)

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

		if yard_mode and (id == crate_id or id == cart_id()) and (step_at < LATE_STEP or rng.randf() < 0.9):
			return "p%d keeps %d standing" % [peer, id]   # the cart and the crate come down now and then, late enough to have been pulled about

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
	elif roll < 99 and rng.randf() < 0.25:
		var died: bool = items.kill(peer, "test")
		items.report_position(peer, HERE + Vector3(float(peer) * 0.5, 0.0, 0.0))
		return "p%d died%s" % [peer, "" if died else " (refused)"]
	elif roll < 99:
		items.peer_left(peer)
		join(peer)
		return "p%d left and came back" % peer
	else:
		restart()
		return "server restart"


func run(run_seed: int) -> void:
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

	if yard_mode:
		var loom: int = items.dev_place("loom@8,-1")
		var cart: int = items.dev_place("handcart@4.5,2.5")
		check(loom > 0 and cart > 0, "seed %d: a Loom and a Handcart stand in the yard (%d, %d)" % [run_seed, loom, cart])

		if loom > 0 and cart > 0:
			items._items[loom]["struct"]["owner"] = KEYS[1]
			items._items[cart]["struct"]["owner"] = KEYS[1]

		for peer in [1, 2]:
			items.give(peer, n("plant_fibre"), 80)

	for k in range(6):
		items.drop_in_world(n("stone"), 5, HERE + Vector3(float(k) - 3.0, 0.0, 2.0))
		items.drop_in_world(n("stick"), 7, HERE + Vector3(float(k) - 3.0, 0.0, -2.0))

	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	var start: Dictionary = totals()
	var broke: String = ""
	log_lines.clear()

	for i in STEPS:
		step_at = i
		var had_cart: bool = cart_id() != 0
		var had_loom: bool = loom_id() != 0
		var did: String = step(rng)

		if yard_mode:
			var notes: Dictionary = {"cart taken down": had_cart and cart_id() == 0, "loom taken down": had_loom and loom_id() == 0, "crate on the cart": items._items.has(crate_id) and items._items[crate_id]["struct"].has("on"), "cloth woven": totals_has_cloth(), "restart with the crate on": did == "server restart" and items._items.has(crate_id) and items._items[crate_id]["struct"].has("on")}

			for k in notes:
				if notes[k]:
					seen[k] = int(seen.get(k, 0)) + 1

		log_lines.append("%d %s" % [i, did])
		var now: Dictionary = totals()

		if fire_mode:
			var bad: String = ""

			for number in start.keys() + now.keys():
				var id: String = items.table.id_of(number)
				var a0: int = int(start.get(number, 0))
				var a1: int = int(now.get(number, 0))

				if (a1 > a0 and not GROW_OK.has(id)) or (a1 < a0 and not BURN_OK.has(id)):
					bad += "%s %d -> %d " % [id, a0, a1]

			if bad != "":
				broke = "step %d (%s): %s" % [i, did, bad]
				print("  last actions:\n    " + "\n    ".join(log_lines.slice(maxi(log_lines.size() - 12, 0))))
				break

			start = now
			continue

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
	check(broke == "", "seed %d: %d random actions by two players keep every total (%s)" % [run_seed, STEPS, broke if broke != "" else "%d kinds" % start.size()])
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

	for lap in range(3):   # before the fix each round came back a whole kit and laid 4 more sticks; now the first round ends it
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
	# Laid and left: when it goes (FIRE_LAID_S unlit), its sticks and the kit's parts lie where it stood (the kit used to vanish with it).
	items.action(1, Net.ACT_PLACE, inv.numbers.find(n("campfire_kit")), 0, 0, HERE + Vector3(0.0, 0.0, -1.5))
	start = totals()

	for k in range(int(ItemsScript.FIRE_LAID_S / 60.0) + 2):
		items.tick(60.0)

	check(box_ids().is_empty() and totals() == start, "a laid fire left unlit goes and leaves its parts and sticks (%s)" % diff(start, totals()))
	items._finish_writer()


func _init() -> void:
	campfire_round()

	for one_seed in SEEDS:
		run(one_seed)

	fire_mode = true

	for one_seed in FIRE_SEEDS:
		run(one_seed)

	fire_mode = false
	yard_mode = true

	for one_seed in YARD_SEEDS:
		run(one_seed)

	print("  yard runs did: ", seen)

	for k in ["weave queued", "cloth woven", "cart pulled", "cart pulled loaded", "cart pulled with the crate on", "crate on the cart", "restart with the crate on", "cart taken down", "loom taken down"]:
		check(int(seen.get(k, 0)) > 0, "the yard runs did this at least once: %s (%d steps)" % [k, int(seen.get(k, 0))])

	print("item conservation: %d failures" % failures)
	quit(1 if failures > 0 else 0)
