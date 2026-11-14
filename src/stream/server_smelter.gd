extends RefCounted

# The Smelters (master s2.5 and s2.7; CATALOG_IMPLEMENTATION_PLAN R2/R3; GOALS-REPAIR WP-METAL). A placed smelter is a station store whose
# structures.json row has "use": "smelt" and a "smelt" block; the jobs and the fuel are structures.json "smelting". It works by itself, like
# the Kiln, never through the player's craft queue:
#   - the store's first smelt.hopper_slots slots are the fuel hopper (Coal or Charcoal only, at most smelt.hopper units), the rest of its
#     `slots` the material input (the ore its jobs take, at most smelt.input units), and its out_slots (if any) the output rack;
#   - while the hopper holds fuel and the input holds a job's ore, it smelts: smelt.ingot_s real seconds an ingot (a job that gives two
#     takes twice as long), the first possible job in smelting.jobs order;
#   - a finished job takes its ore and its fuel (smelting.fuel_per_ore a unit of ore) only when it delivers: into the output rack, or, with
#     no rack (the Primitive Smelter), onto the ground in front. Nothing is held in between, so taking ore or fuel out never loses anything,
#     and a job that cannot deliver (a full rack, a crowded ground) waits with its time kept;
#   - a job may need the bellows worked (smelting.jobs[...].bellows, Iron): only a station with smelt.bellows does it, and only while a player
#     works them (E beside it; they stop when they press E again, walk away or leave). Worked bellows also speed it by smelt.bellows_speed.
#     An unfinished bellows job keeps its time when the bellows stop and goes on when they start again (master s2.7 item 4).
# struct["smelt_t"] = seconds banked toward the next delivery of the job struct["smelt_job"]; saved in smelters.json by the store's uid as
# [seconds, job]. Who works the bellows is not saved.

const NEAR_M := 1.0
# PROVISIONAL (GOALS-REPAIR A-11): ingots a smelter drops in front last as long as a pile (server_items.PILE_LIFETIME_S), not the 20 minutes of a
# loose item, so a player back from a long run still finds them. To change it, change this value.
const GROUND_S := 7200.0          # beyond the station's reach_m: how far a bellows worker may stand

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


# The ore this station's jobs take (the input's items).
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


# The part an item goes into, "" when the station takes none of it.
func part_for(def: Dictionary, number: int) -> String:
	if is_fuel(number):
		return "hopper"

	return "input" if _takes_ore(def, number) else ""


# How many of `amount` the station still takes (every put path: a put, Store all, a storage view's deposit, Stack to nearby).
func room(def: Dictionary, box, number: int, amount: int) -> int:
	var part: String = part_for(def, number)

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
func refusal(def: Dictionary, box, number: int) -> String:
	var part: String = part_for(def, number)

	if part == "":
		return "It takes only Coal or Charcoal and ore it can smelt."

	if box != null and _units(box, _span(def, part)) >= int(def["smelt"].get(part, 0)):
		return "Its fuel slot is full." if part == "hopper" else "Its ore is full."

	return "Each of its fuel slots holds one kind of fuel." if part == "hopper" else "Each of its ore slots holds one kind of ore."


# Puts up to `amount` into the right part (the caller checked room). Returns what did not go in.
func put(def: Dictionary, box, number: int, amount: int, item_wear: int = 0, item_inst: Dictionary = {}) -> int:
	var part: String = part_for(def, number)

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


# The job the station works on now ("" none). A started job (`current`, with time banked) goes on while its ore is in; a started bellows job
# whose bellows stop waits for them, holding the furnace (master s2.7 item 4: it pauses, it is not lost or overtaken). Otherwise the first job
# in its list whose ore is in the input, a bellows job only while they are worked.
func _pick(def: Dictionary, box, worked: bool, current: String) -> String:
	if current != "" and _has_ore(def, box, _job(current)):
		return current if worked or not bool(_job(current).get("bellows", false)) else ""

	for job_id in def["smelt"].get("jobs", []):
		var job: Dictionary = _job(str(job_id))

		if not job.is_empty() and (worked or not bool(job.get("bellows", false))) and _has_ore(def, box, job):
			return str(job_id)

	return ""


func _has_ore(def: Dictionary, box, job: Dictionary) -> bool:
	if job.is_empty():
		return false

	for need in job.get("in", []):
		if _units(box, _span(def, "input"), host.table.number_of(str(need[0]))) < int(need[1]):
			return false

	return true


func _ore_of(job: Dictionary) -> int:
	var ore: int = 0

	for need in job.get("in", []):
		ore += int(need[1])

	return ore


# Fuel a job burns (smelting.fuel_per_ore a unit of its ore).
func _fuel_of(job: Dictionary) -> int:
	return maxi(int(ceil(float(_cfg.get("fuel_per_ore", 1.0)) * float(_ore_of(job)))), 0)


# Takes `count` fuel out of the hopper, cheapest kind first in smelting.fuel order. The caller checked there is enough.
func _burn(def: Dictionary, box, count: int) -> void:
	var hopper: Vector2i = _span(def, "hopper")
	var left: int = count

	for id in _cfg.get("fuel", []):
		var number: int = host.table.number_of(str(id))
		var take: int = mini(left, _units(box, hopper, number))

		if take > 0:
			_take(box, hopper, number, take)
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


func tick(id: int, it: Dictionary, def: Dictionary, spent: float) -> void:
	var box = host._chests.get(int(it["struct"].get("uid", 0)))

	if box == null:
		return

	var worked: bool = _working(id, it, def)
	var budget: float = spent * (float(def["smelt"].get("bellows_speed", 1.0)) if worked else 1.0)
	var t: float = float(it["struct"].get("smelt_t", 0.0))
	var current: String = str(it["struct"].get("smelt_job", "")) if t > 0.0 else ""
	var changed: bool = false

	for _step in 100:   # a slow tick is a quarter second: one delivery at most; the cap only bounds a long jump
		var job_id: String = _pick(def, box, worked, current)

		if job_id == "":
			# Nothing to do. A paused bellows job (its ore still in) keeps its time for when the bellows start again; otherwise it is forgotten.
			if t > 0.0 and not _has_ore(def, box, _job(current)):
				t = 0.0
				current = ""
				changed = true

			break

		if job_id != current:
			t = 0.0   # a different job starts from nothing (the one before lost its ore)
			current = job_id

		var job: Dictionary = _job(job_id)
		var out: Array = job.get("out", ["", 0])
		var count: int = int(out[1])
		var need_s: float = maxf(float(def["smelt"].get("ingot_s", 20.0)) * float(count), 0.01)
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

		_burn(def, box, fuel)
		t = 0.0
		current = ""
		changed = true
		_credit(it, host.table.number_of(str(out[0])), count)

	if current != str(it["struct"].get("smelt_job", "")):
		host._dirty = true   # a job started or ended; time alone does not force a save (a crash loses at most the time since the last one)

	it["struct"]["smelt_t"] = t
	it["struct"]["smelt_job"] = current

	if changed:
		host._push_box(id, box)
		host._dirty = true


# Ingots into the output rack, or on the ground in front with no rack. False (nothing moved) when there is no room.
func _deliver(id: int, it: Dictionary, def: Dictionary, number: int, count: int) -> bool:
	if int(def.get("out_slots", 0)) > 0:
		if host._out_room(it, number) < count:
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
			for _i in count:
				host._goal_made(int(peer), number)

			return


# --- Saving ---

func save_rows() -> Dictionary:
	var rows: Dictionary = {}

	for id in host._items:
		var it: Dictionary = host._items[id]

		if it.has("struct") and it["struct"].has("uid") and float(it["struct"].get("smelt_t", 0.0)) > 0.0 and is_smelter(host._structures.get(str(it["struct"]["kind"]), {})):
			rows[str(it["struct"]["uid"])] = [float(it["struct"]["smelt_t"]), str(it["struct"].get("smelt_job", ""))]

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

		if typeof(row) == TYPE_ARRAY and (row as Array).size() >= 2 and def["smelt"].get("jobs", []).has(str(row[1])):
			it["struct"]["smelt_t"] = clampf(float(row[0]), 0.0, need_max)
			it["struct"]["smelt_job"] = str(row[1])

		_fix_layout(id, it, def)


# A store saved under another layout (the Smelter's old 4 input + 4 output slots, a hopper over its units) is laid out again: everything comes
# out and goes back through put() (and the output rack for what was in it); what does not fit lies in front of it. Nothing is lost or made.
func _fix_layout(id: int, it: Dictionary, def: Dictionary) -> void:
	var box = host._chests.get(int(it["struct"]["uid"]))

	if box == null or _laid_out(def, box):
		return

	var out_span: Vector2i = _span(def, "output")
	var rows: Array = []

	for i in box.slot_count:
		if box.numbers[i] != 0:
			rows.append([box.numbers[i], box.counts[i], box.wear[i], box.inst_of(i), i >= out_span.x and i < out_span.y])
			box.clear_slot(i)

	for row in rows:
		var left: int = int(row[1])

		if bool(row[4]):
			left = host._out_add(id, int(row[0]), left, int(row[2]), row[3])

		if left > 0:
			var fit: int = room(def, box, int(row[0]), left)
			left = put(def, box, int(row[0]), fit, int(row[2]), row[3]) + (left - fit)

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


# True when every stack is in its part and each part within its units.
func _laid_out(def: Dictionary, box) -> bool:
	for part in ["hopper", "input"]:
		if _units(box, _span(def, part)) > int(def["smelt"].get(part, 0)):
			return false

	var out_span: Vector2i = _span(def, "output")

	for i in box.slot_count:
		var number: int = box.numbers[i]

		if number == 0 or (i >= out_span.x and i < out_span.y):
			continue

		var part: String = part_for(def, number)

		if part == "":
			return false

		var span: Vector2i = _span(def, part)

		if i < span.x or i >= span.y:
			return false

	return true
