extends SceneTree

# Every recipe and every blueprint a player can use is made or built through the real server (Dave 22 Nov 2026, rush mode before the first friends'
# test play: "address all the things that can make the test play best for the players ... just make things work"; coordinator: "for every step a
# player must take, confirm the recipe, station, tool, resource and goal hint exist and connect").
# tools/encyclopedia_reach.py says on paper that every goal can be reached; this plays each step on the server, so a recipe whose station, kept tool,
# group need or fuel the server does not accept, or a blueprint whose site the hammer cannot finish, shows here by name with what the server said.
#   1. every recipe that is not locked or retired: a new player beside a fresh station of the level it asks (a lit campfire for "campfire", fuel in a
#      smithy's fuel slot), its needs and kept tools given (a group need: its first member), queued with the tool in hand, the clock run past its time,
#      the station's store taken: the player has its product;
#   2. every blueprint a player is offered (known, not locked or retired): a new player with its cost, a hammer (or knife) of its tier and a chisel of
#      its tier, beside its station or "near" piece: placed and hit, it stands (no site left).
# Raw materials are handed out: gathering them is the world's job (the reach model, the scatter tests and test_playability_bot).
#   godot --headless --path . --script res://src/worldgen/tools/test_every_recipe.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")
const CraftHand := preload("res://src/worldgen/tools/craft_hand.gd")
const HeldTool := preload("res://src/worldgen/tools/held_tool.gd")

const SPACING := 256.0   # one yard to a 256 m chunk (server_items CHUNK_M): no station serves another yard, and no cap_per_chunk is met

var failures: int = 0
var items
var said: Dictionary = {}   # peer -> what the server told it
var next_peer: int = 100


# Refusals that are the piece's own placing rule, not a break: it needs a frame this bare yard has not got (a door its doorway, a roof panel
# its wall tops, a mill its tall foundation). Printed as SKIP with the rule, never counted.
const FRAME_RULES := ["A door goes in a doorway", "A roof panel rests", "A roof corner goes", "It needs a tall foundation"]
var skipped: int = 0


func check(ok: bool, what: String, peer: int = 0) -> void:
	var told: Array = said.get(peer, [])

	if not ok and not told.is_empty() and FRAME_RULES.any(func(rule): return str(told[-1]).begins_with(rule)):
		skipped += 1
		print("SKIP " + what + ": " + str(told[-1]))
		return

	print(("ok   " if ok else "FAIL ") + what)

	if not ok:
		failures += 1
		print("     the server said: ", str(told.slice(maxi(told.size() - 3, 0))) if not told.is_empty() else "nothing")


# A new player standing in their own yard, far from every other.
func new_player() -> int:
	next_peer += 1
	var peer: int = next_peer
	items.peer_connected_hello(peer, "every%07d" % peer)
	items.report_position(peer, yard(peer))
	items.vitals_of(peer)["weight"] = 1.0e6   # carrying is not under test
	items.vitals_of(peer)["food"] = 100.0
	items.vitals_of(peer)["water"] = 100.0
	return peer


func yard(peer: int) -> Vector3:
	var n: int = peer - 100
	return Vector3(128.0 + float(n % 40) * SPACING, 10.0, 128.0 + floorf(float(n) / 40.0) * SPACING)


func have(peer: int, number: int) -> int:
	return items.inventory_of(peer).count_of(number)


# Gives `count` of `number`; a group (Any nails, Any knife) gives its first live member, not its own plain id. Returns the number given.
func give_any(peer: int, number: int, count: int) -> int:
	for member in items.table.group_members(number):   # a group lists its own id first (the plain "knife", a material): a real live member
		var e: Dictionary = items.table.entry(items.table.id_of(int(member)))

		if int(member) != number and not bool(e.get("retired", false)) and not bool(e.get("future", false)):
			number = int(member)
			break

	if str(items.table.entry(items.table.id_of(number)).get("kind", "")) == "tool":
		items.give(peer, number, count)   # a tool, with its wear
	elif items.table.id_of(number).begins_with("log"):   # logs ride on the shoulder and a full shoulder swings no hammer: they lie at the feet,
		for one in range(count):                        # where a craft and a hammered site take them from (CraftStock LOOSE_STOCK_M)
			items.drop_in_world(number, 1, yard(peer) + Vector3(0.5 + 0.3 * float(one % 5), 0.0, -1.0 - 0.3 * floorf(float(one) / 5.0)))
	else:
		items.inventory_of(peer).add(number, count)   # a material into the pack

	return number


# The structure kind that gives `station` at `level` or more (its own station level, or an "also" row), the lowest that does.
func station_kind(station: String, level: int) -> String:
	var best: String = ""
	var best_lv: int = 99

	for kind in items._structures:
		var def: Dictionary = items._structures[kind]
		var lv: int = 0

		if str(def.get("station", "")) == station:
			lv = int(def.get("station_level", 1))
		elif def.get("also", {}) is Dictionary and (def.get("also", {}) as Dictionary).has(station):
			lv = int(def["also"][station])

		if lv >= level and lv < best_lv and str(def.get("kit", "")) != "" and (items._blueprint_of_kit.has(str(def["kit"])) or items.table.has_id(str(def["kit"]))):
			best = kind
			best_lv = lv

	return best


func newest_struct(kind: String) -> int:
	var best: int = -1

	for id in items._items:
		var it: Dictionary = items._items[id]

		if it.has("struct") and str(it["struct"]["kind"]) == kind and not it["struct"].has("site") and int(id) > best:
			best = int(id)

	return best


# A station of `station` at `level` beside the player, ready to work: fuel in its fuel slot, lit if it lights. "" when nothing gives it.
func set_station(peer: int, station: String, level: int) -> String:
	var at: Vector3 = yard(peer) + Vector3(1.5, 0.0, 0.0)

	if station == "campfire" and level <= 1:
		lay_fire(at)
		return "campfire"

	var kind: String = station_kind(station, level)

	if kind == "":
		return ""

	if kind == "campfire_pot":   # it hangs over a small fire: lay the fire first
		lay_fire(at)

	var kit: String = str(items._structures[kind]["kit"])

	if items._blueprint_of_kit.has(kit):
		items.place_piece(peer, kit, at)
	else:   # a station made as an item (the Mortar and pestle) is set down from the pack
		items.give(peer, items.table.number_of(kit), 1)
		items.place_item(peer, items.table.number_of(kit), at)

	var id: int = newest_struct(kind)

	if id < 0:
		return ""

	var def: Dictionary = items._structures[kind]

	if str(def.get("fuel_slot", "")) != "":
		var fuel: int = give_any(peer, items.table.number_of(str(def["fuel_slot"])), 20)
		put_in(peer, id, fuel, 20)

	return kind


func lay_fire(at: Vector3) -> void:
	items._items[items._next_id] = {"number": items.table.number_of("campfire_kit"), "count": 1, "pos": at, "left": 1.0e9, "fire": {"state": 1, "burn_left": 1.0e6, "covered": false, "recheck": 5.0}}
	items._next_id += 1


func put_in(peer: int, id: int, number: int, count: int) -> void:
	items.action(peer, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
	items.action(peer, Net.ACT_CHEST_PUT, items.inventory_of(peer).numbers.find(number), id, count, Vector3.ZERO)
	items.action(peer, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)


# Takes everything out of the station stores beside the player (open, Take all, close), as after a craft.
func collect(peer: int) -> void:
	for id in items._items.keys():
		var it: Dictionary = items._items.get(id, {})

		if it.has("struct") and items._is_station_store(it) and (it["pos"] as Vector3).distance_to(yard(peer)) <= 4.0:
			items.action(peer, Net.ACT_CHEST_OPEN, id, 0, 0, Vector3.ZERO)
			items.action(peer, Net.ACT_BULK, ItemsScript.BULK_TAKE_ALL, 0, 0, Vector3.ZERO)
			items.action(peer, Net.ACT_CHEST_CLOSE, 0, 0, 0, Vector3.ZERO)


# Loose stacks of `number` on the ground beside the player, picked up.
func pick_up_near(peer: int, number: int) -> void:
	for id in items._items.keys():
		var it: Dictionary = items._items.get(id, {})

		if int(it.get("number", 0)) == number and not it.has("struct") and not it.has("scatter") and not it.has("fire") and (it["pos"] as Vector3).distance_to(yard(peer)) <= 5.0:
			items.action(peer, Net.ACT_PICKUP, int(id), 0, int(it["count"]), Vector3.ZERO)


func craft_one(number: int, r: Dictionary) -> void:
	var rid: String = str(r.get("id", ""))
	var peer: int = new_player()
	var station: String = str(r.get("station", ""))
	var level: int = int(r.get("station_level", 1))

	if station != "" and set_station(peer, station, level) == "":
		check(false, "recipe %s: no structure gives the station %s at level %d" % [rid, station, level], peer)
		return

	for row in r.get("keeps", []):
		give_any(peer, int(row[0]), int(row[1]))

	for row in r.get("needs", []):
		give_any(peer, int(row[0]), int(row[1]))

	for row in r.get("needs", []):   # a need that matures in a jar (Sauerkraut) is not ripe when handed out: the jar is test_goal_events'
		for maker in items.recipes.makers_of(int(row[0])):
			if float(items.recipes.recipe(int(maker)).get("ready_age", 0.0)) > 0.0:
				skipped += 1
				print("SKIP recipe %s: needs a matured %s" % [rid, items.table.id_of(int(row[0]))])
				return

	var gives: Array = r.get("gives", [0, 1])
	var out_n: int = int(gives[0])
	var before: int = have(peer, out_n)
	items._last_queue_act.clear()
	items.action(peer, Net.ACT_CRAFT_QUEUE, number, 0, 1, CraftHand.at(items, peer, number))

	items.tick(1.0)

	for s in range(900):   # a craft runs its time (craft_s, slowed by skill and station): until the queue is empty
		if items.craft_queue_of(peer).is_empty():
			break

		items.tick(1.0)

	items.tick(1.0)

	if OS.get_environment("EVERY_ONLY") != "":
		print("  queue ", items.craft_queue_of(peer), " said ", said.get(peer, []), " near ", items._items.values().filter(func(it): return (it["pos"] as Vector3).distance_to(yard(peer)) < 5.0).map(func(it): return [items.table.id_of(int(it.get("number", 0))), it.get("struct", {}).get("kind", "")]))

	collect(peer)
	pick_up_near(peer, out_n)
	var got: int = have(peer, out_n) - before
	check(got >= int(gives[1]), "recipe %s%s gives %d %s (%d)" % [rid, " at %s L%d" % [station, level] if station != "" else "", int(gives[1]), items.table.id_of(out_n), got], peer)


func build_one(number: int, bp: Dictionary) -> void:
	var bid: String = str(bp.get("id", items.table.id_of(number)))
	var peer: int = new_player()
	var kind: String = str(bp.get("structure", ""))

	for key in [["station", "station_level"], ["near", "near_level"]]:
		if str(bp.get(key[0], "")) != "" and set_station(peer, str(bp[key[0]]), int(bp.get(key[1], 1))) == "":
			check(false, "blueprint %s: no structure gives its %s %s" % [bid, key[0], str(bp[key[0]])], peer)
			return

	var tool_class: String = "knife" if str(bp.get("tool", "")) == "knife" else "hammer"
	give_tool(peer, tool_class, int(bp.get("hammer", 1)) if tool_class == "hammer" else 1)

	if tool_class == "knife":
		give_tool(peer, "hammer", 1)   # the knife sets the site down; only a hammer fills it (Dave 18 Nov 2026)

	if int(bp.get("chisel", 0)) > 0:
		give_tool(peer, "chisel", int(bp["chisel"]))

	for c in bp.get("cost", []):
		give_any(peer, items.table.number_of(str(c[0])), int(c[1]))

	var at: Vector3 = yard(peer) + Vector3(-3.0, 0.0, 2.0)

	if kind == "campfire_pot":   # it hangs over a small fire
		lay_fire(at)
	items.action(peer, Net.ACT_PLACE_BLUEPRINT, number, 0, 0, at)
	var site: int = HeldTool.site_of(items, kind)

	if site >= 0 and items._items[site]["pos"].distance_to(at) > 1.5:
		site = -1

	var stands: bool = false

	if site >= 0:
		for hit in range(6):
			if HeldTool.hit_site(items, site, peer):
				stands = true
				break

	if site < 0:
		var built: int = newest_struct(kind)
		stands = built >= 0 and items._items[built]["pos"].distance_to(at) <= 1.5

	check(stands, "blueprint %s builds a %s (%s)" % [bid, kind, str(bp.get("cost", []))], peer)


# The cheapest live hand tool of `tool_class` at `tier` or above, given into the hotbar.
func give_tool(peer: int, tool_class: String, tier: int) -> void:
	var best: String = ""
	var best_tier: int = 99

	for id in items.table.ids():
		var e: Dictionary = items.table.entry(id)

		if str(e.get("tool_class", "")) == tool_class and not bool(e.get("retired", false)) and int(e.get("tier", 1)) >= tier and int(e.get("tier", 1)) < best_tier:
			best = str(id)
			best_tier = int(e.get("tier", 1))

	if best != "":
		items.give(peer, items.table.number_of(best), 1)


func _init() -> void:
	var dir: String = "user://test_every_recipe"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_reject = func(p, r): said.get_or_add(p, []).append("reject " + str(r))
	items.send_notice = func(p, text): said.get_or_add(p, []).append(str(text))
	items.ground_height = func(_x, _z): return 10.0
	items.setup(ItemTableScript.load_default(), dir)
	items.admin_mode_on = func(_p): return false
	var clock: Array = [1000.0 * 86400.0 + 12.0 * 3600.0]
	items.game_seconds = func(): return clock[0]
	items.skill_level = func(_p, _s): return 1.0
	items.dig_ground = func(_centre, _radius): return null
	items.ground_material = func(_x, _z): return "soil"

	var recipes_n: int = 0
	var only: String = OS.get_environment("EVERY_ONLY")   # debugging: one recipe or blueprint id (comma list)

	for n in items.recipes.numbers():
		var r: Dictionary = items.recipes.recipe(int(n))

		if bool(r.get("locked", false)) or bool(r.get("retired", false)) :
			continue

		if only != "" and not only.split(",").has(str(r.get("id", ""))):
			continue

		recipes_n += 1
		craft_one(int(n), r)
		items.peer_left(next_peer)   # each player leaves when done, so the clock does not run every earlier one

	var bps_n: int = 0

	for n in items._blueprints:
		var bp: Dictionary = items._blueprints[n]

		if bool(bp.get("locked", false)) or bool(bp.get("retired", false)) or not bool(bp.get("known", true)):   # known false: not offered
			continue

		if only != "" and not only.split(",").has(str(bp.get("id", ""))):
			continue

		bps_n += 1
		build_one(int(n), bp)
		items.peer_left(next_peer)

	print("%d recipes and %d blueprints played, %d skipped (a frame or a jar)" % [recipes_n, bps_n, skipped])
	print("Test done: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
