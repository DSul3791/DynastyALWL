extends SceneTree

# Playability bot (Tyler, 31 Oct 2026): a headless player who follows the first-hour steps of PLAYTHROUGH_GUIDE.md on the server logic and STOPS at the first step
# that cannot be done, saying which step and why. Steps: spawn, gather sticks and fibre and stones, twist twine, make the stone axe, chop a tree and work the
# trunk, make and light a fire, build a lean-to. Recipes are found by NAME (the id in data/items/recipes.json), never by number, and the gather amounts come from
# the recipes themselves, so a changed recipe is followed; a recipe that grows past what a first hour can reasonably gather, or needs a station or an unknown
# material, stops the bot at that step. test_first_hour stays as the vitals-curve check; this one is the "can a new player get through it" check.
# What it cannot see: the real terrain (whether sticks lie within reach of the spawn is the world-alive metrics tool's job) and the client's hands.
#   godot --headless --path . --script res://src/worldgen/tools/test_playability_bot.gd

const ItemsScript := preload("res://src/stream/server_items.gd")
const ItemTableScript := preload("res://src/shared/item_table.gd")
const Net := preload("res://src/stream/terrain_net.gd")

# What a first hour can fairly ask of the hands (the guide's pace: about 10 minutes of gathering). The bot fails when the recipes ask for more.
const GATHER_BUDGET := {"stick": 60, "stone": 40, "plant_fibre": 90, "leaves": 20}
const STARTING_MATERIALS := ["stick", "stone", "plant_fibre", "leaves", "log"]

var items
var step_no: int = 0
var step_name: String = ""
var bot_start: int = 0
var halted: bool = false


func stop(why: String) -> void:
	halted = true
	print("BOT STOPPED at step %d (%s): %s" % [step_no, step_name, why])
	print("playability bot: FAILED at step %d" % step_no)
	quit(1)


func step(name: String) -> void:
	step_no += 1
	step_name = name
	print("bot step %d: %s" % [step_no, name])


func need(ok: bool, why: String) -> void:
	if not ok:
		stop(why)


func count(id: String) -> int:
	return items.inventory_of(1).count_of(items.table.number_of(id))


func pass_time(seconds: float, exertion: float) -> void:
	for s in range(int(seconds)):
		items._exertion[1] = exertion
		items.tick(1.0)


func recipe_by_id(id: String) -> Dictionary:
	for n in items.recipes.numbers():
		var r: Dictionary = items.recipes.recipe(int(n))

		if str(r.get("id", "")) == id:
			return r

	return {}


# Ask the craft queue for a recipe by id and let the time pass; returns the reason it could not be done, or "".
func craft(id: String, crafts: int) -> String:
	var r: Dictionary = recipe_by_id(id)

	if r.is_empty():
		return "there is no recipe '%s' in data/items/recipes.json (renamed or retired?)" % id

	if str(r["station"]) != "":
		return "recipe '%s' needs the station '%s', which a new player does not have" % [id, r["station"]]

	if not bool(r["known"]) and not items.recipes.numbers().is_empty() and not _is_open(int(r["number"])):
		return "recipe '%s' is not known from the first minute (see data/items/open_recipes.json)" % id

	var gives: int = items.table.number_of(str(items.table.name_of(int(r["gives"][0]))))
	var before: int = items.inventory_of(1).count_of(int(r["gives"][0]))

	for part in r["needs"]:
		var have: int = items.inventory_of(1).count_fill(int(part[0])) if int(part[0]) > 0 else 0

		if have < int(part[1]) * crafts:
			return "recipe '%s' needs %d x %s, the pack holds %d" % [id, int(part[1]) * crafts, items.table.name_of(int(part[0])), have]

	items._last_queue_act.clear()
	items.action(1, Net.ACT_CRAFT_QUEUE, int(r["number"]), 0, crafts, Vector3.ZERO)
	pass_time(float(r["craft_s"]) * float(crafts) + 6.0, 0.2)
	var made: int = items.inventory_of(1).count_of(int(r["gives"][0])) - before

	if made < int(r["gives"][1]) * crafts:
		return "recipe '%s' ran but gave %d, not %d (gives %s)" % [id, made, int(r["gives"][1]) * crafts, items.table.name_of(gives)]

	return ""


func _is_open(number: int) -> bool:
	var opened: Variant = items.recipes.get("_open")
	return opened == null or (opened is Dictionary and opened.has(number)) or (opened is Array and opened.has(number))


# The raw materials a recipe chain needs, expanded down to the starting materials; returns {item id: count}, or sets "unknown" when a part has no source.
func raw_need(id: String, crafts: int, into: Dictionary) -> void:
	var r: Dictionary = recipe_by_id(id)

	if r.is_empty():
		into["unknown:" + id] = 1
		return

	for part in r["needs"]:
		var part_id: String = str(items.table.name_of(int(part[0])))
		var key: String = _id_of(int(part[0]))
		var total: int = int(part[1]) * crafts

		if key in STARTING_MATERIALS:
			into[key] = int(into.get(key, 0)) + total
		elif not recipe_by_id(key).is_empty():
			raw_need(key, total, into)
		else:
			into["unknown:" + key + " (" + part_id + ")"] = total


func _id_of(number: int) -> String:
	for id in STARTING_MATERIALS + ["twine", "stone_axe", "campfire_kit", "lean_to_kit", "wooden_spear"]:
		if items.table.number_of(id) == number:
			return id

	return "item_%d" % number


func _init() -> void:
	bot_start = Time.get_ticks_msec()
	var dir: String = "user://test_playability_bot"
	DirAccess.make_dir_recursive_absolute(dir)

	for file in DirAccess.get_files_at(dir):
		DirAccess.remove_absolute(dir + "/" + file)

	items = ItemsScript.new()
	items.send_full = func(_p, _b): pass
	items.send_slots = func(_p, _b): pass
	items.send_world_items = func(_p, _a, _r): pass
	items.send_vitals = func(_p, _h, _he, _w, _t, _l, _f): pass
	items.send_notice = func(_p, _t): pass
	items.ground_height = func(_x, _z): return 10.0
	var standing: Dictionary = {7: true}
	items.tree_info = func(_chunk, id): return {"name": "oak", "position": Vector3(10.0, 10.0, 0.0), "height": 18.0, "trunk": 0.1} if standing.has(id) else {}
	items.cut_tree = func(_chunk, id): standing.erase(id); return true
	items.water_near = func(_pos, _reach): return false
	items.setup(ItemTableScript.load_default(), dir)

	step("spawn: a new character arrives")
	items.peer_connected_hello(1, "playbot00001")
	items.report_position(1, Vector3(0.0, 10.0, 0.0))
	items._vitals_cfg["eat_pace_ms"] = 0
	items.vitals_of(1)["weight"] = 120.0
	var start: Array = items._vitals_points(items.vitals_of(1))
	need(start[0] == 100 and start[3] == 100, "the new character does not start with full hunger and thirst (%d, %d)" % [start[0], start[3]])
	if halted:
		return
	need(count("stone") == 0 and count("stick") == 0, "the new character does not start empty-handed")
	if halted:
		return

	step("plan: what the first hour asks of the hands")
	var raw: Dictionary = {}
	raw_need("stone_axe", 1, raw)
	raw_need("campfire", 1, raw)
	raw_need("lean_to_kit", 1, raw)

	for key in raw:
		need(not str(key).begins_with("unknown:"), "a recipe needs %s, which a new player cannot gather or make from the starting materials" % str(key).trim_prefix("unknown:"))
		if halted:
			return

	for key in GATHER_BUDGET:
		var asked: int = int(raw.get(key, 0))
		need(asked <= int(GATHER_BUDGET[key]), "the axe, the fire and the lean-to together ask for %d x %s by hand; a first hour should ask for at most %d (GATHER_BUDGET in this test)" % [asked, key, GATHER_BUDGET[key]])
		if halted:
			return

	print("bot plan: raw materials for axe + fire + lean-to: %s" % str(raw))

	step("gather: sticks, stones and fibre lie around and are picked up")
	var wanted: Dictionary = {"stick": int(raw.get("stick", 0)) + 2, "stone": int(raw.get("stone", 0)) + 2, "plant_fibre": int(raw.get("plant_fibre", 0)) + 3, "leaves": int(raw.get("leaves", 0))}
	var spot: int = 0

	for key in wanted:
		var left: int = int(wanted[key])

		while left > 0:
			var piece: int = mini(left, 8)
			# Heaps lying less than a metre apart merge into one: three rings, 6 / 10 / 14 places, each place more than 1.4 m from the next.
			var ring: int = 0 if spot < 6 else (1 if spot < 16 else 2)
			var places: int = [6, 10, 14][ring]
			var first: int = [0, 6, 16][ring]
			var angle: float = TAU * float(spot - first) / float(places)
			var around: Vector3 = Vector3(cos(angle), 0.0, sin(angle))
			items.drop_in_world(items.table.number_of(key), piece, Vector3(0.0, 10.0, 0.0) + around * (1.5 + float(ring)))
			left -= piece
			spot += 1

	pass_time(60.0, 0.3)

	for round in range(3):
		for id in items._items.keys():
			var it: Dictionary = items._items[id]

			if not (it.has("scatter") or it.has("tree") or it.has("fire") or it.has("struct")):
				items.action(1, Net.ACT_PICKUP, id, 0, 0, Vector3.ZERO)

	for key in wanted:
		if key == "leaves":
			continue

		need(count(key) >= int(raw.get(key, 0)), "after picking up everything, the pack holds %d x %s of the %d the first hour needs (weight limit or pickup problem)" % [count(key), key, int(raw.get(key, 0))])
		if halted:
			return

	step("twine: twist fibre into twine by hand")
	var twine_total: int = int(raw_twine())
	var why: String = craft("twine", twine_total)
	need(why == "", why)
	if halted:
		return

	step("axe: make the stone axe by hand")
	why = craft("stone_axe", 1)
	need(why == "", why)
	if halted:
		return
	items.action(1, Net.ACT_MOVE, items.inventory_of(1).numbers.find(items.table.number_of("stone_axe")), 0, 0, Vector3.ZERO)

	step("chop: fell the tree, cut a log off the trunk, pick it up")
	items.report_position(1, Vector3(8.0, 10.0, 0.0))

	for n in range(200):   # as many blows as it takes (the count is tuned by the felling design, so the bot does not depend on it)
		if standing.is_empty():
			break

		items._last_hit.clear()
		items.action(1, Net.ACT_HIT, 7, 0, 0, Vector3.ZERO)

	need(standing.is_empty(), "the tree did not fall to 200 axe blows")
	if halted:
		return

	pass_time(60.0, 0.8)
	var trunk_id: int = 0

	for k in items._items:
		if items._items[k].has("tree") and items._items[k]["tree"]["state"] == 3:
			trunk_id = k

	need(trunk_id != 0, "the felled tree left no trunk on the ground to work")
	if halted:
		return

	items.report_position(1, Vector3(14.0, 10.0, 0.0))
	var guard: int = 0
	var log_on_ground: int = 0
	var log_numbers: PackedInt32Array = items.table.group_members(items.table.number_of("log"))

	# Chopping the lying trunk cuts logs off its end; they fall on the ground and are not picked up by themselves (branches, bark and sticks are).
	while log_on_ground == 0 and guard < 300:
		if items._items.has(trunk_id):
			items.report_position(1, items.cut_line_point(trunk_id))   # the player walks to the cut line (the server says "Walk along the trunk" otherwise)

		items._last_process.clear()
		items.action(1, Net.ACT_PROCESS, trunk_id, 0, 0, Vector3.ZERO)
		guard += 1
		items.tick(1.0)

		for k in items._items:
			var it: Dictionary = items._items[k]

			if not (it.has("tree") or it.has("fire") or it.has("struct") or it.has("scatter")) and log_numbers.has(int(it.get("number", 0))):
				log_on_ground = k

	need(log_on_ground != 0, "%d chops on the trunk cut no log that lies on the ground" % guard)
	if halted:
		return

	pass_time(30.0, 0.8)
	need(count("leaves") >= int(raw.get("leaves", 0)), "working the trunk gave %d leaves, the lean-to needs %d" % [count("leaves"), int(raw.get("leaves", 0))])
	if halted:
		return

	items.action(1, Net.ACT_PICKUP, log_on_ground, 0, 0, Vector3.ZERO)
	var carried: bool = items.shoulder_of(1) != "" or items.inventory_of(1).count_fill(items.table.number_of("log")) > 0
	need(carried, "the log on the ground could not be picked up (shoulder empty, none in the pack)")
	if halted:
		return

	items.lay_down_shoulder(1)
	items.report_position(1, Vector3(0.0, 10.0, 0.0))

	step("fire: make the campfire kit, place it and light it")
	why = craft("campfire", 1)
	need(why == "", why)
	if halted:
		return
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("campfire_kit")), 0, 0, Vector3(2.0, 10.0, 0.0))
	var lit: int = 0
	var laid: int = 0

	for k in items._items:
		if items._items[k].has("fire"):
			laid += 1
			items.action(1, Net.ACT_LIGHT, k, 0, 0, Vector3.ZERO)

	need(laid == 1, "placing the campfire kit put %d fires in the world, not 1" % laid)
	if halted:
		return

	for k in items._items:
		lit += 1 if items._items[k].has("fire") and items.fire_is_lit(int(items._items[k]["fire"]["state"])) else 0

	need(lit == 1, "the fire was placed but could not be lit with tinder from the pack")
	if halted:
		return

	step("shelter: make the lean-to and put it up")
	why = craft("lean_to_kit", 1)
	need(why == "", why)
	if halted:
		return
	items.action(1, Net.ACT_PLACE, items.inventory_of(1).numbers.find(items.table.number_of("lean_to_kit")), 0, 0, Vector3(-3.0, 10.0, 0.0))
	var shelters: int = 0

	for k in items._items:
		shelters += 1 if items._items[k].has("struct") and str(items._items[k]["struct"]["kind"]) == "lean_to" else 0

	need(shelters == 1, "placing the lean-to kit put %d lean-tos in the world, not 1" % shelters)
	if halted:
		return

	step("docs: CONTROLS.md says what the data and the code do (guide finding F-04)")
	var controls: String = FileAccess.get_file_as_string("res://CONTROLS.md")
	var camp: Dictionary = recipe_by_id("campfire")
	var sticks: int = 0
	var stones: int = 0

	for part in camp["needs"]:
		sticks += int(part[1]) if int(part[0]) == items.table.number_of("stick") else 0
		stones += int(part[1]) if int(part[0]) == items.table.number_of("stone") else 0

	need(controls.contains("campfire kit (%d sticks and %d stones)" % [sticks, stones]), "CONTROLS.md does not say that a campfire kit costs %d sticks and %d stones (the recipe)" % [sticks, stones])
	if halted:
		return

	need(not controls.contains("starts lit"), "CONTROLS.md says a placed campfire 'starts lit'; it is placed laid and lit with E")
	if halted:
		return

	need(not controls.contains("Splits one log into 4 firewood"), "CONTROLS.md says the chopping block splits a log into 4 firewood; it splits one wooden block into one firewood")
	if halted:
		return

	step("well: still healthy after the hour")
	need(float(items.vitals_of(1)["health"]) >= 99.0, "the character was hurt during the first hour (health %.0f)" % float(items.vitals_of(1)["health"]))
	if halted:
		return
	var took: float = float(Time.get_ticks_msec() - bot_start) / 1000.0
	print("playability bot: all %d steps done in %.1f s" % [step_no, took])
	quit(0)


# Twine the plan needs: every recipe in the chain that asks for twine (the axe, the lean-to) counted once each.
func raw_twine() -> int:
	var total: int = 0

	for id in ["stone_axe", "campfire", "lean_to_kit"]:
		var r: Dictionary = recipe_by_id(id)

		for part in r.get("needs", []):
			if int(part[0]) == items.table.number_of("twine"):
				total += int(part[1])

	return total
