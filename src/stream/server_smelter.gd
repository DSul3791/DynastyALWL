extends RefCounted

# The Smelters (master s2.5 and s2.7; CATALOG_IMPLEMENTATION_PLAN R2 to R4; GOALS-REPAIR WP-METAL). A placed smelter is a station store whose
# structures.json row has "use": "smelt" and a "smelt" block; the jobs and the fuel are structures.json "smelting". It works by itself, like
# the Kiln, never through the player's craft queue:
#   - the store's first smelt.hopper_slots slots are the fuel hopper (Coal or Charcoal only, at most smelt.hopper units), the rest of its
#     `slots` the material input (the ore its jobs take, and at a smelt.carbon station the steel carbon, at most smelt.input units together),
#     and its out_slots (if any) the output rack (at most smelt.output ingots);
#   - Coal and Charcoal go to the hopper. At a smelt.carbon station (the Advanced smelter) Coal or Charcoal put onto an input slot (dragged
#     there, protocol 121) goes into the input as carbon: a separate ingredient, never fuel, and nothing moves fuel between the two (plan P3);
#   - it works smelt.lanes jobs at once (the Advanced smelter's two), each lane the first possible job in its smelt.jobs order, a lane's ore
#     kept for it while it works (another lane does not start on the same ore);
#   - a job takes smelt.ingot_s / smelt.speed real seconds an ingot (a job that gives two takes twice as long);
#   - a finished job takes its ore, its carbon and its fuel (smelting.fuel_per_ore hopper fuel a unit of ore) only when it delivers: into the
#     output rack, or, with no rack (the Primitive Smelter), onto the ground in front. Nothing is held in between, so taking ore or fuel out
#     never loses anything, and a job that cannot deliver (a full rack, a crowded ground) waits with its time kept;
#   - a job may need air from bellows (smelting.jobs[...].bellows: Iron and Steel). At a smelt.bellows station (the Improved smelter) a player gives it by
#     working the bellows (E beside it; they stop when they press E again, walk away or leave), which also speeds every job by
#     smelt.bellows_speed. An unfinished air job keeps its time when the bellows stop and goes on when they start again (master s2.7 item 4);
#   - a smelt.wind station (the Advanced smelter's built-in windmill and two bellows) gives air and works at all only while the wind turns
#     its windmill (smelting.wind_min_mps): in a calm nothing moves, every lane keeping its job and time, and it goes on by itself when the
#     wind comes back (master s2.7 item 7, plan P3).
# struct["smelt_t"] / struct["smelt_job"] are lane 0's seconds banked toward its next delivery and its job, struct["smelt_lanes"] the same
# [seconds, job] for lanes 1 and on; saved in smelters.json by the store's uid as [seconds, job, seconds, job, ...]. Who works the bellows
# is not saved.

const NEAR_M := 1.0          # beyond the station's reach_m: how far a bellows worker may stand
# PROVISIONAL (GOALS-REPAIR A-11): ingots a smelter drops in front last as long as a pile (server_items.PILE_LIFETIME_S), not the 20 minutes of a
# loose item, so a player back from a long run still finds them. To change it, change this value.
const GROUND_S := 7200.0

const Weather := preload("res://src/shared/weather.gd")

var host = null              # the items module (server_items.gd)
var _cfg: Dictionary = {}    # structures.json "smelting"
var _bellows: Dictionary = {}   # world id -> the peer working its bellows
var _ids: Dictionary = {}       # world id -> true for every placed smelter (note() at placing and loading; tick_all forgets the gone ones)


func setup(structures_cfg: Dictionary) -> void:
	_cfg = structures_cfg.get("smelting", {})


func is_smelter(def: Dictionary) -> bool:
	return str(def.get("use", "")) == "smelt" and typeof(def.get("smelt", null)) == TYPE_DICTIONARY


# --- The store's parts ---

func _hopper_slots(def: Dictionary) -> int:
	return int(def["smelt"].get("hopper_slots", 1))


func is_fuel(number: int) -> bool:
	for id in _cfg.get("fuel", []):
		if host.table.number_of(str(id)) == number:
			return true

	return false


func _carbon_station(def: Dictionary) -> bool:
	return bool(def["smelt"].get("carbon", false))


# The ore this station's jobs take (the input's items; carbon is the fuel items, see part_for).
func _takes_ore(def: Dictionary, number: int) -> bool:
	for job_id in def["smelt"].get("jobs", []):
		for need in _job(str(job_id)).get("in", []):
			if host.table.number_of(str(need[0])) == number:
				return true

	return false


func _job(job_id: String) -> Dictionary:
	return _cfg.get("jobs", {}).get(job_id, {})


# [first slot, end slot) of a part: "hopper", "input" or "output".
func _span(def: Dictionary, part: String) -> Vector2i:
	var hs: int = _hopper_slots(def)
	var slots: int = int(def.get("slots", 0))

	if part == "hopper":
		return Vector2i(0, hs)

	if part == "input":
		return Vector2i(hs, slots)

	return Vector2i(slots, slots + int(def.get("out_slots", 0)))


func _units(box, span: Vector2i, number: int = 0) -> int:
	var total: int = 0

	for i in range(span.x, mini(span.y, box.slot_count)):
		if box.numbers[i] != 0 and (number == 0 or box.numbers[i] == number):
			total += box.counts[i]

	return total


# Carbon in the input: its fuel items (Coal, Charcoal).
func _carbon_units(def: Dictionary, box) -> int:
	var total: int = 0

	for id in _cfg.get("fuel", []):
		total += _units(box, _span(def, "input"), host.table.number_of(str(id)))

	return total


# Takes `count` of `number` out of a part's slots (the last slots first). The caller checked there are enough.
func _take(box, span: Vector2i, number: int, count: int) -> void:
	var left: int = count

	for i in range(mini(span.y, box.slot_count) - 1, span.x - 1, -1):
		if left > 0 and box.numbers[i] == number:
			var take: int = mini(left, box.counts[i])
			box.counts[i] -= take
			left -= take

			if box.counts[i] == 0:
				box.clear_slot(i)


# The part an item goes into, "" when the station takes none of it. `target` is the store slot a put was dragged onto (-1: none, a plain
# put, F, Store all, a storage view, Stack to nearby or an automatic pull): only Coal or Charcoal dragged onto an input slot of a carbon
# station goes into the input, as carbon; every other put of fuel goes to the hopper.
func part_for(def: Dictionary, number: int, target: int = -1) -> String:
	if is_fuel(number):
		var input: Vector2i = _span(def, "input")
		return "input" if _carbon_station(def) and target >= input.x and target < input.y else "hopper"

	return "input" if _takes_ore(def, number) else ""


# How many of `amount` the station still takes (every put path: a put, Store all, a storage view's deposit, Stack to nearby).
func room(def: Dictionary, box, number: int, amount: int, target: int = -1) -> int:
	var part: String = part_for(def, number, target)

	if part == "" or box == null:
		return 0

	var span: Vector2i = _span(def, part)
	var stack: int = host.table.stack_of(number)
	var fits: int = 0   # what its slots still hold: a hopper slot or an ore slot holds one kind (as host._out_room)

	for i in range(span.x, mini(span.y, box.slot_count)):
		if box.numbers[i] == 0:
			fits += stack
		elif box.numbers[i] == number and box.inst[i].is_empty() and box._mergeable(number, box.wear[i], 0):
			fits += maxi(stack - box.counts[i], 0)

	return clampi(mini(int(def["smelt"].get(part, 0)) - _units(box, span), fits), 0, amount)


# Why room() is 0, said to the player.
func refusal(def: Dictionary, box, number: int, target: int = -1) -> String:
	var part: String = part_for(def, number, target)

	if part == "":
		return "It takes only Coal or Charcoal and ore it can smelt."

	if box != null and _units(box, _span(def, part)) >= int(def["smelt"].get(part, 0)):
		return "Its fuel slot is full." if part == "hopper" else "Its ore is full."

	return "Each of its fuel slots holds one kind of fuel." if part == "hopper" else "Each of its ore slots holds one kind of ore."


# Puts up to `amount` into the right part (the caller checked room). Returns what did not go in.
func put(def: Dictionary, box, number: int, amount: int, item_wear: int = 0, item_inst: Dictionary = {}, target: int = -1) -> int:
	var part: String = part_for(def, number, target)

	if part == "":
		return amount

	var span: Vector2i = _span(def, part)
	var was: int = box.usable
	box.usable = mini(span.y, box.slot_count)
	var left: int = box.add(number, amount, item_wear, item_inst, span.x)
	box.usable = was
	return left


# --- Working ---

# E on a smelter: a station with bellows starts or stops this player working them; any other says how it is fed.
func use(peer: int, id: int, it: Dictionary, def: Dictionary) -> void:
	if bool(def["smelt"].get("wind", false)):
		host._say(peer, "Coal or Charcoal in its fuel slots, ore in the others; for steel, drag Coal or Charcoal onto an ore slot too. %s" % ("Its windmill turns." if _wind_turns(def) else "The wind is too weak to turn its windmill: it waits."))
		return

	if not bool(def["smelt"].get("bellows", false)):
		host._say(peer, "Put Coal or Charcoal in its fuel slot and ore in the others (F). It smelts by itself; the ingots drop in front.")
		return

	if int(_bellows.get(id, -1)) == peer:
		_bellows.erase(id)
		host._say(peer, "You leave the bellows.")
		return

	if _bellows.has(id) and _working(id, it, def):
		host._say(peer, "Someone is already working these bellows.")
		return

	_bellows[id] = peer
	host._say(peer, "You work the bellows: it smelts faster and can work iron while you stay at it (E again to stop).")


# True while a player works the station's bellows: still connected and beside it.
func _working(id: int, it: Dictionary, def: Dictionary) -> bool:
	if not _bellows.has(id):
		return false

	var peer: int = int(_bellows[id])

	if not host._peer_pos.has(peer) or (host._peer_pos[peer] as Vector3).distance_to(it["pos"]) > float(def.get("reach_m", 3.0)) + NEAR_M:
		_bellows.erase(id)

		if host._peer_pos.has(peer):
			host._say(peer, "You have left the bellows.")

		return false

	return true


func bellows_worked(id: int) -> bool:
	return _bellows.has(id)


# The world's wind in metres a second (Weather.state "wind", 0..1); 0 with no weather.
func wind_mps() -> float:
	var weather: Dictionary = host.weather_now.call() if host.weather_now.is_valid() else {}
	return Weather.wind_mps(float(weather.get("wind", 0.0)))


# True while the wind turns a windmill station's windmill (smelting.wind_min_mps).
func _wind_turns(def: Dictionary) -> bool:
	return bool(def["smelt"].get("wind", false)) and wind_mps() >= float(_cfg.get("wind_min_mps", 4.0))


# The job a lane works on now ("" none). A started job (`current`, with time banked) goes on while its ore is in; a started air job whose
# air stops waits for it, holding the lane (master s2.7 item 4: it pauses, it is not lost or overtaken). Otherwise the first job in its list
# whose ore (and carbon) is in the input beyond what the other lanes hold (`held`: item number -> units), an air job only with air.
func _pick(def: Dictionary, box, air: bool, current: String, held: Dictionary) -> String:
	if current != "" and _has_ore(def, box, _job(current), held):
		return current if air or not bool(_job(current).get("bellows", false)) else ""

	for job_id in def["smelt"].get("jobs", []):
		var job: Dictionary = _job(str(job_id))

		if not job.is_empty() and (air or not bool(job.get("bellows", false))) and _has_ore(def, box, job, held):
			return str(job_id)

	return ""


func _has_ore(def: Dictionary, box, job: Dictionary, held: Dictionary = {}) -> bool:
	if job.is_empty():
		return false

	for need in job.get("in", []):
		var number: int = host.table.number_of(str(need[0]))

		if _units(box, _span(def, "input"), number) - int(held.get(number, 0)) < int(need[1]):
			return false

	return _carbon_units(def, box) - int(held.get(-1, 0)) >= int(job.get("carbon", 0))


# What a lane's job holds of the input (item number -> units; -1 the carbon), added to `held`.
func _hold(job: Dictionary, held: Dictionary) -> void:
	for need in job.get("in", []):
		var number: int = host.table.number_of(str(need[0]))
		held[number] = int(held.get(number, 0)) + int(need[1])

	held[-1] = int(held.get(-1, 0)) + int(job.get("carbon", 0))


func _ore_of(job: Dictionary) -> int:
	var ore: int = 0

	for need in job.get("in", []):
		ore += int(need[1])

	return ore


# Fuel a job burns (smelting.fuel_per_ore hopper fuel a unit of its ore; the carbon is not ore).
func _fuel_of(job: Dictionary) -> int:
	return maxi(int(ceil(float(_cfg.get("fuel_per_ore", 1.0)) * float(_ore_of(job)))), 0)


# Takes `count` of the fuel items out of a part, cheapest kind first in smelting.fuel order. The caller checked there is enough.
func _burn(def: Dictionary, box, count: int, part: String = "hopper") -> void:
	var span: Vector2i = _span(def, part)
	var left: int = count

	for id in _cfg.get("fuel", []):
		var number: int = host.table.number_of(str(id))
		var take: int = mini(left, _units(box, span, number))

		if take > 0:
			_take(box, span, number, take)
			left -= take


# A smelter placed or loaded (a blueprint site too: it is skipped until built).
func note(id: int) -> void:
	_ids[id] = true


# One slow tick of every placed smelter (server_items.tick). A record taken down, reset or no longer a smelter is forgotten here.
func tick_all(spent: float) -> void:
	for id in _ids.keys():
		var it: Dictionary = host._items.get(id, {})
		var def: Dictionary = host._structures.get(str(it.get("struct", {}).get("kind", "")), {}) if it.has("struct") else {}

		if not is_smelter(def):
			_ids.erase(id)
			_bellows.erase(id)
		elif not it["struct"].has("site"):
			tick(int(id), it, def, spent)


# The lanes' [seconds, job] (lane 0 from smelt_t / smelt_job, the others from smelt_lanes), smelt.lanes of them.
func _lanes_of(it: Dictionary, def: Dictionary) -> Array:
	var lanes: Array = [[float(it["struct"].get("smelt_t", 0.0)), str(it["struct"].get("smelt_job", ""))]]
	var more: Array = it["struct"].get("smelt_lanes", [])

	for k in range(1, maxi(int(def["smelt"].get("lanes", 1)), 1)):
		var row: Variant = more[k - 1] if k - 1 < more.size() else null
		lanes.append([float(row[0]), str(row[1])] if typeof(row) == TYPE_ARRAY and (row as Array).size() >= 2 else [0.0, ""])

	for lane in lanes:
		if float(lane[0]) <= 0.0:
			lane[0] = 0.0
			lane[1] = ""   # a lane with no time banked has no job yet

	return lanes


func _set_lanes(it: Dictionary, lanes: Array) -> void:
	it["struct"]["smelt_t"] = float(lanes[0][0])
	it["struct"]["smelt_job"] = str(lanes[0][1])

	if lanes.size() > 1:
		it["struct"]["smelt_lanes"] = lanes.slice(1)
	else:
		it["struct"].erase("smelt_lanes")


func tick(id: int, it: Dictionary, def: Dictionary, spent: float) -> void:
	var box = host._chests.get(int(it["struct"].get("uid", 0)))

	if box == null:
		return

	var smelt: Dictionary = def["smelt"]
	var windmill: bool = bool(smelt.get("wind", false))
	var worked: bool = _working(id, it, def)
	var air: bool = _wind_turns(def) if windmill else worked

	var rate: float = float(smelt.get("speed", 1.0)) * (float(smelt.get("bellows_speed", 1.0)) if worked else 1.0)
	var lanes: Array = _lanes_of(it, def)
	var jobs_before: Array = lanes.map(func(l): return str(l[1]))
	var changed: bool = false

	# A lane whose job lost its ore forgets it first, so its ore and time are not held against the others.
	for lane in lanes:
		if str(lane[1]) != "" and not _has_ore(def, box, _job(str(lane[1]))):
			lane[0] = 0.0
			lane[1] = ""

	if windmill and not air:
		rate = 0.0   # a calm: the windmill stands and nothing moves; every lane keeps its job and time

	for k in lanes.size():
		var held: Dictionary = {}   # what the other lanes' jobs hold of the input

		for j in lanes.size():
			if j != k and str(lanes[j][1]) != "":
				_hold(_job(str(lanes[j][1])), held)

		var t: float = float(lanes[k][0])
		var current: String = str(lanes[k][1])
		var budget: float = spent * rate

		for _step in 100:   # a slow tick is a quarter second: one delivery at most; the cap only bounds a long jump
			var job_id: String = _pick(def, box, air, current, held)

			if job_id == "":
				# Nothing to do. A paused air job (its ore still in) keeps its time for when the air comes back; otherwise it is forgotten.
				if t > 0.0 and not _has_ore(def, box, _job(current), held):
					t = 0.0
					current = ""

				break

			if job_id != current:
				t = 0.0   # a different job starts from nothing (the one before lost its ore)
				current = job_id

			var job: Dictionary = _job(job_id)
			var out: Array = job.get("out", ["", 0])
			var count: int = int(out[1])
			var need_s: float = maxf(float(smelt.get("ingot_s", 20.0)) * float(count), 0.01)
			var fuel: int = _fuel_of(job)

			if _units(box, _span(def, "hopper")) < fuel:
				break   # no fuel: it waits, its time kept

			var add: float = minf(budget, maxf(need_s - t, 0.0))
			t += add
			budget -= add

			if t < need_s:
				break

			if not _deliver(id, it, def, host.table.number_of(str(out[0])), count):
				t = need_s   # nowhere to put it: it waits
				break

			for need in job.get("in", []):
				_take(box, _span(def, "input"), host.table.number_of(str(need[0])), int(need[1]))

			_burn(def, box, int(job.get("carbon", 0)), "input")
			_burn(def, box, fuel)
			t = 0.0
			current = ""
			changed = true
			_credit(it, host.table.number_of(str(out[0])), count)

		lanes[k] = [t if current != "" else 0.0, current]

	if lanes.map(func(l): return str(l[1])) != jobs_before:
		host._dirty = true   # a job started or ended; time alone does not force a save (a crash loses at most the time since the last one)

	_set_lanes(it, lanes)

	if changed:
		host._push_box(id, box)
		host._dirty = true


# Ingots into the output rack, or on the ground in front with no rack. False (nothing moved) when there is no room.
func _deliver(id: int, it: Dictionary, def: Dictionary, number: int, count: int) -> bool:
	if int(def.get("out_slots", 0)) > 0:
		var box = host._chests.get(int(it["struct"].get("uid", 0)))

		# The rack holds smelt.output ingots (a slot holds any number, item_table.stack_of; the 80-ingot rack is master s2.7 item 4).
		if host._out_room(it, number) < count or box == null or _units(box, _span(def, "output")) + count > int(def["smelt"].get("output", 0)):
			return false

		host._out_add(id, number, count)
		return true

	return host.drop_in_world(number, count, front_of(it, def), 0, GROUND_S)


# The spot in front of the station: its model's front (Godot's +Z turned by the yaw, as server_items._step_spot), past its footprint.
func front_of(it: Dictionary, def: Dictionary) -> Vector3:
	var yaw: float = deg_to_rad(float(it["struct"].get("yaw", 0.0)))
	return (it["pos"] as Vector3) + Vector3(sin(yaw), 0.0, cos(yaw)) * (float(def.get("footprint_z", 1.0)) * 0.5 + 0.6)


# The station's owner, when they are on, counts the ingots as made (goals "made:", as a craft does).
func _credit(it: Dictionary, number: int, count: int) -> void:
	var owner: String = str(it["struct"].get("owner", ""))

	if owner == "":
		return

	for peer in host._peer_key:
		if str(host._peer_key[peer]) == owner:
			host._goal_made(int(peer), number, count)   # one "made:" an ingot delivered (a 2-Bronze smelt counts 2; lead-ruled); paused in admin mode

			return


# --- Saving ---

func save_rows() -> Dictionary:
	var rows: Dictionary = {}

	for id in host._items:
		var it: Dictionary = host._items[id]
		var def: Dictionary = host._structures.get(str(it.get("struct", {}).get("kind", "")), {}) if it.has("struct") else {}

		if def.is_empty() or not it["struct"].has("uid") or not is_smelter(def) or it["struct"].has("site"):
			continue

		var row: Array = []
		var any: bool = false

		for lane in _lanes_of(it, def):
			row.append_array([float(lane[0]), str(lane[1])])
			any = any or float(lane[0]) > 0.0

		if any:
			rows[str(it["struct"]["uid"])] = row

	return rows


# After the chests and world items: each smelter's banked time back, and its store laid out as its row says (_fix_layout).
func load_rows(parsed: Variant) -> void:
	var rows: Dictionary = parsed.get("smelters", {}) if typeof(parsed) == TYPE_DICTIONARY and typeof(parsed.get("smelters", null)) == TYPE_DICTIONARY else {}
	var ids: Array = []

	for id in host._items:
		var it: Dictionary = host._items[id]

		if it.has("struct") and it["struct"].has("uid") and is_smelter(host._structures.get(str(it["struct"]["kind"]), {})):
			ids.append(int(id))

	for id in ids:
		note(id)
		var it: Dictionary = host._items[id]
		var def: Dictionary = host._structures[str(it["struct"]["kind"])]

		if it["struct"].has("site"):
			continue   # a blueprint site holds nothing yet

		var need_max: float = float(def["smelt"].get("ingot_s", 20.0)) * 4.0   # no job gives more than a few ingots
		var row: Variant = rows.get(str(it["struct"]["uid"]), null)
		var lanes: Array = []

		for k in maxi(int(def["smelt"].get("lanes", 1)), 1):
			var t: float = 0.0
			var job: String = ""

			if typeof(row) == TYPE_ARRAY and (row as Array).size() >= 2 * k + 2 and def["smelt"].get("jobs", []).has(str(row[2 * k + 1])):
				t = clampf(float(row[2 * k]), 0.0, need_max)
				job = str(row[2 * k + 1])

			lanes.append([t, job])

		_set_lanes(it, lanes)
		_fix_layout(id, it, def)


# A store saved under another layout (the Smelter's old 4 input + 4 output slots, a hopper over its units, the old Blast furnace's store) is
# laid out again: everything comes out and goes back through put() (and the output rack for what was in it; carbon back into the input);
# what does not fit lies in front of it. Nothing is lost or made.
func _fix_layout(id: int, it: Dictionary, def: Dictionary) -> void:
	var box = host._chests.get(int(it["struct"]["uid"]))

	if box == null or _laid_out(def, box):
		return

	var out_span: Vector2i = _span(def, "output")
	var in_span: Vector2i = _span(def, "input")
	var rows: Array = []

	for i in box.slot_count:
		if box.numbers[i] != 0:
			rows.append([box.numbers[i], box.counts[i], box.wear[i], box.inst_of(i), i >= out_span.x and i < out_span.y, in_span.x if i >= in_span.x and i < in_span.y else -1])
			box.clear_slot(i)

	for row in rows:
		var left: int = int(row[1])

		if bool(row[4]):
			left = host._out_add(id, int(row[0]), left, int(row[2]), row[3])

		if left > 0:
			var fit: int = room(def, box, int(row[0]), left, int(row[5]))
			left = put(def, box, int(row[0]), fit, int(row[2]), row[3], int(row[5])) + (left - fit)

		if left > 0 and not host.drop_in_world(int(row[0]), left, front_of(it, def), int(row[2]), GROUND_S, NAN, NAN, "", row[3]):
			_lay_down(int(row[0]), left, front_of(it, def), int(row[2]), row[3])   # crowded ground: this one-time move still loses nothing

	host._dirty = true


# A ground item put down past drop_in_world's crowd limit (fields as drop_in_world writes them).
func _lay_down(number: int, count: int, at: Vector3, item_wear: int, item_inst: Dictionary) -> void:
	host._items[host._next_id] = {"number": number, "count": count, "pos": at, "left": GROUND_S, "wear": item_wear}

	if not item_inst.is_empty():
		host._items[host._next_id]["inst"] = item_inst.duplicate(true)

	host._next_id += 1
	host._dirty = true


# True when every stack is in its part (carbon in the input of a carbon station counts as in place) and each part within its units.
func _laid_out(def: Dictionary, box) -> bool:
	for part in ["hopper", "input"]:
		if _units(box, _span(def, part)) > int(def["smelt"].get(part, 0)):
			return false

	var out_span: Vector2i = _span(def, "output")

	for i in box.slot_count:
		var number: int = box.numbers[i]

		if number == 0 or (i >= out_span.x and i < out_span.y):
			continue

		var part: String = part_for(def, number, i)

		if part == "":
			return false

		var span: Vector2i = _span(def, part)

		if i < span.x or i >= span.y:
			return false

	return true
