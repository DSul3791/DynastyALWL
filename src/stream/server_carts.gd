extends RefCounted

# The Handcart and loaded crates as cargo (master s3.11 [D11] and s3.13 [D13]; STORAGE_WAREHOUSING_DESIGN.md s4 to s6; Mission 001 phase 10, M001-T17).
# The first persistent movable world entity. A cart is a placed structure with slots (its own cargo store, a chests.json entry by uid, like any chest)
# and a structures.json "vehicle" row. One player at a time holds its handle (the puller; s3.11 RECOMMEND: the player is the puller of the shared vehicle
# controller). Each position report of the puller moves the cart toward the point hitch_m from them on the line back to the cart, so it swings in behind
# like a towed trailer (wide turns) and is pushed when walked into; never faster than its pace (speed_mps, slowed by load, grade and rough ground, times
# pace_slack for network jitter), never onto a grade steeper than slope_max, into water deeper than water_max_m, through a wall or a heavy station
# (structure_blocks) or a tree trunk. When it cannot follow and the puller is more than slack_m past the handle, the handle slips: the cart parks where it
# is. Letting go, disconnecting and dying park it the same way. Nothing runs for a cart nobody pulls: the only per-report cost is one dictionary look-up.
# A loaded crate (structures.json "cargo": the Crate and the Warehouse crate) stays the same world record with its uid, owner, lock and contents. On a
# cart it carries struct "on" (the cart's uid) and "spot" (its place on the bed, vehicle crate_spots) and rides with the cart; it ages at the cart's
# place_mult and belongs to no storage view while it rides (the cart neither), and set down it joins the view that covers its new spot (views are
# location-derived, _view_boxes). Lifting, setting down and pulling a cart that carries a locked crate obey the lock (_may_access, s3.13 locked-crate rule).
# The cart's payload (its max_kg) counts its cargo store and every crate on it with the crate's own wood (its blueprint's materials) and contents.

const CarryRules := preload("res://src/shared/carry_rules.gd")
const Interact := preload("res://src/shared/interact_rules.gd")
const OP_GRAB := 0      # ACT_CART b: take the handle of cart a
const OP_RELEASE := 1   # let go of the handle (a ignored)
const OP_LOAD := 2      # a = a crate's world id: lift it onto the nearest free cart within that cart's load_reach_m of it
const OP_UNLOAD := 3    # a = the world id of a crate on a cart: set it down beside the cart

var host = null                  # the items module (server_items.gd)
var pulls: Dictionary = {}       # cart world id -> {"peer", "t": unix seconds of the last look, "cap": m/s, "sent": tenths of m/s last sent, "share": load share, "why": why it could not follow, "riders": [crate world ids]}
var puller_of: Dictionary = {}   # peer -> cart world id
var follow_usec: int = 0         # time spent following (the test reads it for the per-report cost)
var follows: int = 0


func vehicle_of(it: Dictionary) -> Dictionary:
	if not it.has("struct") or it["struct"].has("site"):
		return {}

	return host._structures.get(str(it["struct"]["kind"]), {}).get("vehicle", {})


func is_cargo(it: Dictionary) -> bool:
	return it.has("struct") and not it["struct"].has("site") and bool(host._structures.get(str(it["struct"]["kind"]), {}).get("cargo", false))


# The world id of the cart with this uid, 0 none.
func cart_of_uid(uid: int) -> int:
	for id in host._items:
		var it: Dictionary = host._items[id]

		if it.has("struct") and int(it["struct"].get("uid", 0)) == uid and not vehicle_of(it).is_empty():
			return id

	return 0


# The crates riding on a cart: their world ids by spot.
func riders_of(cart_id: int) -> Array:
	var uid: int = int(host._items.get(cart_id, {}).get("struct", {}).get("uid", 0))
	var out: Array = []

	if uid <= 0:
		return out

	for id in host._items:
		if host._items[id].has("struct") and int(host._items[id]["struct"].get("on", 0)) == uid:
			out.append(id)

	return out


# Kilograms a crate (or any placed container) weighs with its contents: its own wood (the materials of its blueprint; a made thing never weighs more
# than what went into it) plus what it holds.
func box_kg(id: int) -> float:
	var it: Dictionary = host._items.get(id, {})
	var kg: float = 0.0
	var def: Dictionary = host._structures.get(str(it.get("struct", {}).get("kind", "")), {})

	if host._blueprint_of_kit.has(str(def.get("kit", ""))):
		for need in host._blueprints[int(host._blueprint_of_kit[str(def["kit"])])].get("cost", []):
			kg += CarryRules.weight_of(str(need[0]), host._carry_cfg) * float(need[1])

	var box = host._chests.get(int(it.get("struct", {}).get("uid", 0)))
	return kg + (CarryRules.carried_kg(box, host.table, host._carry_cfg) if box != null else 0.0)


# The payload on a cart: its cargo store and every crate riding on it (`riders`: those crates when known, so a pulled cart does not look them up).
func load_kg(cart_id: int, riders: Variant = null) -> float:
	var it: Dictionary = host._items.get(cart_id, {})
	var box = host._chests.get(int(it.get("struct", {}).get("uid", 0)))
	var kg: float = CarryRules.carried_kg(box, host.table, host._carry_cfg) if box != null else 0.0

	for rider in (riders if riders != null else riders_of(cart_id)):
		if host._items.has(rider):
			kg += box_kg(rider)

	return kg


func payload_kg(cart: Dictionary) -> float:
	return float(host._structures.get(str(cart["struct"]["kind"]), {}).get("max_kg", 0.0))


# Kilograms more a container may take before the cart it is or rides on is full; INF for one not on a cart (its own max_kg still applies).
func room_kg(id: int) -> float:
	var it: Dictionary = host._items.get(id, {})

	if not it.has("struct"):
		return INF

	var cart_id: int = id if not vehicle_of(it).is_empty() else (cart_of_uid(int(it["struct"]["on"])) if it["struct"].has("on") else 0)

	if cart_id == 0:
		return INF

	return maxf(payload_kg(host._items[cart_id]) - load_kg(cart_id), 0.0)


# The place_mult kind a container ages at (spoilage.json): the cart's for a crate riding on one (s3.13: contents keep ageing in transit), else its own.
func place_kind(it: Dictionary, kind_of_uid: Dictionary) -> String:
	return str(kind_of_uid.get(int(it["struct"]["on"]), it["struct"]["kind"])) if it["struct"].has("on") else str(it["struct"]["kind"])


func action(peer: int, op: int, a: int) -> void:
	if op == OP_GRAB:
		_grab(peer, a)
	elif op == OP_RELEASE:
		release(peer, "")
	elif op == OP_LOAD:
		_load(peer, a)
	elif op == OP_UNLOAD:
		_unload(peer, a)


func _grab(peer: int, id: int) -> void:
	var cart: Dictionary = host._items.get(id, {})
	var v: Dictionary = vehicle_of(cart)

	if v.is_empty() or not host._peer_pos.has(peer) or (host._peer_pos[peer] as Vector3).distance_to(cart["pos"]) > Interact.server_reach_m():
		return

	if pulls.has(id):
		host._say(peer, "Someone else has the handle." if int(pulls[id]["peer"]) != peer else "You already have the handle.")
		return

	if host.shoulder_of(peer) != "":
		host._say(peer, "Put your log down first (Q).")
		return

	var riders: Array = riders_of(id)

	for rider in riders:
		if not host._may_access(peer, host._items[rider]):
			host._say(peer, "A locked crate rides on it: only its owner or a player with access may move it.")
			return

	release(peer, "")   # one cart at a time
	pulls[id] = {"peer": peer, "t": host._unix(), "cap": 0.0, "sent": -1, "share": 0.0, "why": "", "riders": riders}
	puller_of[peer] = id
	var here: Vector3 = host._peer_pos[peer]
	_note_pace(id, cart, v, _grade(cart["pos"], Vector2(here.x - cart["pos"].x, here.z - cart["pos"].z).normalized()))


# Lets go of the handle: the cart parks where it stands. `why` is said to the puller ("" says nothing).
func release(peer: int, why: String) -> void:
	var id: int = int(puller_of.get(peer, 0))

	if id == 0:
		return

	puller_of.erase(peer)
	pulls.erase(id)

	if why != "":
		host._say(peer, why)

	if host.send_cart_pull.is_valid():
		host.send_cart_pull.call(peer, 0, 0)

	host._dirty = true


func peer_left(peer: int) -> void:
	release(peer, "")   # disconnecting parks the cart where it is


# The puller reported where they are: the cart follows (server_items.report_position).
func follow(peer: int) -> void:
	var id: int = int(puller_of.get(peer, 0))

	if id == 0:
		return

	var t0: int = Time.get_ticks_usec()
	_follow(peer, id)
	follow_usec += Time.get_ticks_usec() - t0
	follows += 1


func _follow(peer: int, id: int) -> void:
	var cart: Dictionary = host._items.get(id, {})
	var v: Dictionary = vehicle_of(cart)
	var rec: Dictionary = pulls.get(id, {})

	if v.is_empty() or rec.is_empty() or not host._peer_pos.has(peer):
		release(peer, "")
		return

	var here: Vector3 = host._peer_pos[peer]
	var from: Vector3 = cart["pos"]
	var now: float = host._unix()
	var pace: float = float(rec["cap"]) * float(v.get("pace_slack", 1.3))
	# The cart may travel pace x elapsed time, not a fixed bit per report: a client sending reports faster gets no further (at most half a second saved up).
	rec["budget"] = minf(float(rec.get("budget", 0.0)) + pace * clampf(now - float(rec["t"]), 0.0, 1.0), pace * 0.5)
	rec["t"] = now
	var hitch: float = float(v.get("hitch_m", 1.7))
	var away: Vector2 = Vector2(from.x - here.x, from.z - here.z)

	if away.length() > hitch + float(v.get("slack_m", 1.5)):
		release(peer, str(rec["why"]) if str(rec["why"]) != "" else "You lose hold of the handcart.")
		return

	for rider in rec["riders"]:   # a crate locked after the grab stops a player who may not open it (s3.13: only the owner or a player with access moves it)
		if host._items.has(rider) and not host._may_access(peer, host._items[rider]):
			release(peer, "A locked crate rides on it: only its owner or a player with access may move it.")
			return

	var goal: Vector2 = Vector2(here.x, here.z) + (away.normalized() if away.length() > 0.01 else Vector2(0.0, -1.0)) * hitch
	var step: Vector2 = goal - Vector2(from.x, from.z)

	if step.length() > float(rec["budget"]):
		step = step.normalized() * float(rec["budget"])   # the cart goes no faster than its pace: a puller who runs on loses the handle

	if step.length() < 0.02:
		return

	var to: Vector3 = Vector3(from.x + step.x, from.y, from.z + step.y)
	var heading: Vector2 = Vector2(here.x - to.x, here.z - to.z).normalized()
	var why: String = _blocked(from, to, heading, v)

	if why != "":
		rec["why"] = why
		return

	rec["why"] = ""
	rec["budget"] = float(rec["budget"]) - step.length()
	to.y = _rest_y(to, from.y)
	_move(id, cart, to, rad_to_deg(atan2(heading.x, heading.y)), rec["riders"])
	_note_pace(id, cart, v, _grade(to, heading))


# Why the cart cannot go from `from` to `to` heading `heading` ("" when it can): no ground, too steep, deep water, a wall or a tree in the way.
func _blocked(from: Vector3, to: Vector3, heading: Vector2, v: Dictionary) -> String:
	if not host.ground_height.is_valid() or is_nan(float(host.ground_height.call(to.x, to.z))):
		return "The handcart cannot go there."

	var grade: float = _grade(to, heading)

	# Over slope_max a step must be less steep than where the cart stands: a cart left on a steep spot may come off it, but never creeps up a
	# ramp that steepens a little at a time.
	if grade > float(v.get("slope_max", 0.36)) and grade >= _grade(from, heading):
		return "Too steep for the handcart."

	if host.water_depth_at.is_valid() and float(host.water_depth_at.call(Vector3(to.x, float(host.ground_height.call(to.x, to.z)), to.z))) > float(v.get("water_max_m", 0.5)):
		return "The water is too deep for the handcart."

	var fit: float = float(v.get("fit_m", 0.6))

	if host.structure_blocks(to.x, to.z, fit) or host.structure_blocks_step(from.x, from.z, to.x, to.z, fit):   # the step too: a thin wall is never jumped
		return "The handcart will not fit through there."

	if host.trunks_near.is_valid():
		for trunk in host.trunks_near.call(to, fit + 2.0):
			if Vector2(to.x - trunk[0].x, to.z - trunk[0].z).length() < fit + float(trunk[1]):
				return "The handcart will not fit through there."

	return ""


# The height the cart rests at: the ground with its digs and fills (floor_below, as a dropped item comes to rest), from a metre over the
# generated surface or where the cart stood; the generated surface when that is not known.
# shortcut: floor_below steps down 5 cm at a time through the edits near it, one call per moving report; measured only with stand-ins (see
# T17_RESULTS.md); revisit with a cached column height if the slow-action line shows pulled carts.
func _rest_y(at: Vector3, was_y: float) -> float:
	var surface: float = float(host.ground_height.call(at.x, at.z))

	if host.floor_below.is_valid():
		var rest: float = float(host.floor_below.call(Vector3(at.x, maxf(surface, was_y) + 1.0, at.z)))

		if not is_nan(rest):
			return rest

	return surface


# The ground's rise over run along the heading, across one metre of the cart's length (0 where the ground is unknown).
func _grade(at: Vector3, heading: Vector2) -> float:
	if not host.ground_height.is_valid():
		return 0.0

	var front: float = float(host.ground_height.call(at.x + heading.x * 0.5, at.z + heading.y * 0.5))
	var back: float = float(host.ground_height.call(at.x - heading.x * 0.5, at.z - heading.y * 0.5))
	return 0.0 if is_nan(front) or is_nan(back) else absf(front - back)


# Moves the cart and the crates on it; the players who see them hear of it at once (items_moved), the rest at the next world sync.
func _move(id: int, cart: Dictionary, to: Vector3, yaw_deg: float, riders: Array) -> void:
	cart["pos"] = to
	cart["struct"]["yaw"] = fposmod(yaw_deg, 360.0)
	var ids: PackedInt32Array = PackedInt32Array([id])
	var at: PackedVector3Array = PackedVector3Array([to])
	var yaws: PackedFloat32Array = PackedFloat32Array([cart["struct"]["yaw"]])

	for rider in riders:
		if not host._items.has(rider):
			continue

		var crate: Dictionary = host._items[rider]
		crate["pos"] = spot_pos(cart, int(crate["struct"].get("spot", 0)))
		crate["struct"]["yaw"] = cart["struct"]["yaw"]
		ids.append(rider)
		at.append(crate["pos"])
		yaws.append(crate["struct"]["yaw"])

	host._dirty = true

	if not host.send_items_moved.is_valid():
		return

	for peer in host._known:
		if (host._known[peer] as Dictionary).has(id):
			host.send_items_moved.call(peer, ids, at, yaws)


# Where a crate at spot `spot` rides on the cart (vehicle crate_spots: right, up, forward in the cart's frame).
func spot_pos(cart: Dictionary, spot: int) -> Vector3:
	var spots: Array = vehicle_of(cart).get("crate_spots", [[0.0, 0.55, 0.0]])
	var local: Array = spots[clampi(spot, 0, spots.size() - 1)]
	return cart["pos"] + Basis(Vector3.UP, deg_to_rad(float(cart["struct"]["yaw"]))) * Vector3(float(local[0]), float(local[1]), float(local[2]))


# The cart's pace now (m/s): speed_mps slowed by its load (load_slow at full payload), the grade (slope_slow at slope_max) and rough ground (vehicle
# rough: the wheels drag on rock, sand, mud and snow). Sent to the puller, whose client walks no faster, when it changes by a tenth.
func _note_pace(id: int, cart: Dictionary, v: Dictionary, grade: float) -> void:
	var rec: Dictionary = pulls[id]
	var payload: float = maxf(payload_kg(cart), 1.0)
	rec["share"] = clampf(load_kg(id, rec["riders"]) / payload, 0.0, 1.0)
	var rough: float = 1.0

	if host.ground_material.is_valid():
		rough = float(v.get("rough", {}).get(str(host.ground_material.call(cart["pos"].x, cart["pos"].z)), 1.0))

	var cap: float = float(v.get("speed_mps", 3.2)) * (1.0 - float(v.get("load_slow", 0.4)) * float(rec["share"])) * (1.0 - float(v.get("slope_slow", 0.5)) * clampf(grade / maxf(float(v.get("slope_max", 0.36)), 0.01), 0.0, 1.0)) * rough
	rec["cap"] = maxf(cap, 0.3)
	var tenths: int = int(round(float(rec["cap"]) * 10.0))

	if tenths != int(rec["sent"]) and host.send_cart_pull.is_valid():
		rec["sent"] = tenths
		host.send_cart_pull.call(int(rec["peer"]), id, tenths)


# The extra effort of pulling (exertion, as a loaded pack frame's): the vehicle's pull_effort times its load share.
func pull_effort(peer: int) -> float:
	var id: int = int(puller_of.get(peer, 0))

	if id == 0 or not pulls.has(id):
		return 0.0

	return float(vehicle_of(host._items.get(id, {})).get("pull_effort", 0.0)) * float(pulls[id]["share"])


# OP_LOAD: lift a crate onto the nearest cart within its load_reach_m, with everything in it, if the player may move it.
func _load(peer: int, crate_id: int) -> void:
	var crate: Dictionary = host._items.get(crate_id, {})

	if not is_cargo(crate) or crate["struct"].has("on") or not host._peer_pos.has(peer) or (host._peer_pos[peer] as Vector3).distance_to(crate["pos"]) > host.CHEST_REACH_M:
		return

	if not host._may_access(peer, crate):
		host._say(peer, "It is locked.")   # s3.13: only the owner or a player with access lifts or moves a locked crate
		host._send_lock_info(peer, crate_id)
		return

	var best: int = 0
	var best_d: float = INF

	for id in host._items:
		var v: Dictionary = vehicle_of(host._items[id])
		var d: float = (host._items[id]["pos"] as Vector3).distance_to(crate["pos"])

		if not v.is_empty() and d <= float(v.get("load_reach_m", 3.0)) and d < best_d:
			best = id
			best_d = d

	if best == 0:
		host._say(peer, "There is no handcart close enough.")
		return

	if pulls.has(best):
		host._say(peer, "Someone has the handle: the handcart must stand still to load.")
		return

	var cart: Dictionary = host._items[best]
	var spots: int = vehicle_of(cart).get("crate_spots", []).size()
	var taken: Dictionary = {}

	for rider in riders_of(best):
		taken[int(host._items[rider]["struct"].get("spot", 0))] = true

	var spot: int = -1

	for s in spots:
		if spot < 0 and not taken.has(s):
			spot = s

	if spot < 0:
		host._say(peer, "The handcart has no room for another crate.")
		return

	if load_kg(best) + box_kg(crate_id) > payload_kg(cart):
		host._say(peer, "The crate is too heavy for the handcart. Take some out first.")
		return

	crate["struct"]["on"] = int(cart["struct"]["uid"])
	crate["struct"]["spot"] = spot
	crate["pos"] = spot_pos(cart, spot)
	crate["struct"]["yaw"] = cart["struct"]["yaw"]
	host._dirty = true


# OP_UNLOAD: set a crate down off its cart, beside it.
func _unload(peer: int, crate_id: int) -> void:
	var crate: Dictionary = host._items.get(crate_id, {})

	if not crate.has("struct") or not crate["struct"].has("on") or not host._peer_pos.has(peer) or (host._peer_pos[peer] as Vector3).distance_to(crate["pos"]) > host.CHEST_REACH_M:
		return

	if not host._may_access(peer, crate):
		host._say(peer, "It is locked.")
		host._send_lock_info(peer, crate_id)
		return

	var cart_id: int = cart_of_uid(int(crate["struct"]["on"]))

	if pulls.has(cart_id):
		host._say(peer, "The handcart must stand still to unload: let go of the handle first.")
		return

	var spot: Vector3 = set_down_spot(cart_id, crate_id, false)

	if is_nan(spot.y):
		host._say(peer, "Too many of these stand here already." if _chunk_full(crate_id, crate["pos"]) else "There is no room to set it down here.")
		return

	_set_down(crate, spot)


func _set_down(crate: Dictionary, spot: Vector3) -> void:
	crate["struct"].erase("on")
	crate["struct"].erase("spot")
	crate["pos"] = spot
	host._dirty = true


# True when the crate's kind already stands its structures.json cap_per_chunk times in the chunk of `at` (placement's rule; riding crates are not counted).
func _chunk_full(crate_id: int, at: Vector3) -> bool:
	var kind: String = str(host._items[crate_id]["struct"]["kind"])
	var chunk: Vector2i = host._chunk_of(at)
	var standing: int = 0

	for id in host._items:
		var it: Dictionary = host._items[id]

		if id != crate_id and it.has("struct") and not it["struct"].has("on") and str(it["struct"]["kind"]) == kind and host._chunk_of(it["pos"]) == chunk:
			standing += 1

	return standing >= int(host._structures.get(kind, {}).get("cap_per_chunk", 1000000))


# Ground beside the cart for a crate: to its sides, then behind and before it; the first with ground, shallow water, no wall between it and the
# cart, nothing standing within the crate's half size and room under the kind's cap_per_chunk. `anywhere`: when nothing is free, the cart's own spot
# (it is being taken down, so its place comes free; the cap is not asked then, so nothing is ever lost). NAN y when none.
func set_down_spot(cart_id: int, crate_id: int, anywhere: bool) -> Vector3:
	var cart: Dictionary = host._items.get(cart_id, {})

	if cart.is_empty():
		var lone: Vector3 = host._items[crate_id]["pos"]
		return Vector3(lone.x, float(host.ground_height.call(lone.x, lone.z)) if host.ground_height.is_valid() else lone.y, lone.z)

	var turn: Basis = Basis(Vector3.UP, deg_to_rad(float(cart["struct"]["yaw"])))
	var def: Dictionary = host._structures.get(str(host._items[crate_id]["struct"]["kind"]), {})
	var half: float = maxf(float(def.get("footprint_x", 1.0)), float(def.get("footprint_z", 1.0))) * 0.5
	var v: Dictionary = vehicle_of(cart)

	for local in [Vector3(1.5, 0.0, 0.0), Vector3(-1.5, 0.0, 0.0), Vector3(0.0, 0.0, -2.0), Vector3(0.0, 0.0, 2.0)]:
		var at: Vector3 = cart["pos"] + turn * local
		var y: float = float(host.ground_height.call(at.x, at.z)) if host.ground_height.is_valid() else NAN

		if is_nan(y) or (host.water_depth_at.is_valid() and float(host.water_depth_at.call(Vector3(at.x, y, at.z))) > float(v.get("water_max_m", 0.5))) or host.structure_blocks(at.x, at.z, half) or host.structure_blocks_step(cart["pos"].x, cart["pos"].z, at.x, at.z, 0.1) or _chunk_full(crate_id, at):
			continue

		var clear: bool = true

		for other_id in host._items:
			var other: Dictionary = host._items[other_id]

			if other_id != cart_id and other_id != crate_id and other.has("struct") and not other["struct"].has("on") and Vector2(other["pos"].x - at.x, other["pos"].z - at.z).length() < half + 0.4:
				clear = false
				break

		if clear:
			return Vector3(at.x, _rest_y(Vector3(at.x, y, at.z), cart["pos"].y), at.z)

	if anywhere:
		var y0: float = float(host.ground_height.call(cart["pos"].x, cart["pos"].z)) if host.ground_height.is_valid() else cart["pos"].y
		return Vector3(cart["pos"].x, y0 if not is_nan(y0) else cart["pos"].y, cart["pos"].z)

	return Vector3(0.0, NAN, 0.0)


# Taking a cart down (server_items._take_down hands every vehicle here): it comes apart into its blueprint materials, all of them; the crates on it
# are set down on the ground with everything in them (so a locked one must be the player's to move), and its cargo goes into the pack, all or nothing (the pack's slots and the carry limit), so
# nothing is ever lost: when it does not fit, nothing happens and the player is told to empty the cart first.
func dismantle(peer: int, inv, id: int) -> void:
	var cart: Dictionary = host._items[id]

	if pulls.has(id) and int(pulls[id]["peer"]) != peer:
		host._say(peer, "Someone has the handle.")
		return

	for rider in riders_of(id):
		if not host._may_access(peer, host._items[rider]):
			host._say(peer, "A locked crate rides on it: only its owner or a player with access may set it down.")
			return

	var box = host._chests.get(int(cart["struct"].get("uid", 0)))
	var row: Dictionary = host._blueprints.get(int(host._blueprint_of_kit.get(str(host._structures[str(cart["struct"]["kind"])].get("kit", "")), -1)), {})

	if row.is_empty():
		return

	var logs: int = 0

	for slot in (box.slot_count if box != null else 0):
		if host.is_shoulder_item(box.numbers[slot]):
			logs += box.counts[slot]

	if logs > 1 or (logs == 1 and host.shoulder_of(peer) != ""):   # one large log at a time, on the shoulder
		host._say(peer, "Take the large logs off the handcart first: you can carry only one.")
		return

	var cargo_kg: float = CarryRules.carried_kg(box, host.table, host._carry_cfg) if box != null and not host._carry_cfg.is_empty() else 0.0

	if cargo_kg > 0.0 and host.carried_kg_of(peer) + cargo_kg > CarryRules.cap_kg(host._carry_body(peer), host._carry_cfg):
		host._say(peer, "Empty the handcart first: you cannot carry its load.")
		return

	var trial = inv.copy()

	if not _unpack(trial, box, row):
		host._say(peer, "Make room in your pack first: the handcart's load and its parts must all fit.")
		return

	if host._load_over_cap(peer, trial):   # the pack grows (protocol 113): the carry limit is what must hold the parts and the load
		host._say(peer, "Too heavy: you cannot carry the handcart's parts and its load.")
		return

	release(peer, "")
	_unpack(inv, box, row)

	for rider in riders_of(id):
		_set_down(host._items[rider], set_down_spot(id, rider, true))

	host._chests.erase(int(cart["struct"].get("uid", 0)))
	host._items.erase(id)
	host._dirty = true


# Puts the cart's cargo and its blueprint materials into `inv`; false when something does not fit (inv is then partly filled: only call on a copy first).
func _unpack(inv, box, row: Dictionary) -> bool:
	if box != null:
		for slot in box.slot_count:
			if box.numbers[slot] != 0 and inv.add(box.numbers[slot], box.counts[slot], box.wear[slot], box.inst_of(slot)) > 0:
				return false

	for need in row.get("cost", []):
		if inv.add(host._refund_number(host.table.number_of(str(need[0]))), int(need[1])) > 0:
			return false

	return true


# After a load: a crate whose cart is gone (a damaged save) stands on the ground where it was, so it is never lost.
func after_load() -> void:
	var carts: Dictionary = {}

	for id in host._items:
		if not vehicle_of(host._items[id]).is_empty() and host._items[id]["struct"].has("uid"):
			carts[int(host._items[id]["struct"]["uid"])] = true

	for id in host._items:
		var it: Dictionary = host._items[id]

		if it.has("struct") and it["struct"].has("on") and not carts.has(int(it["struct"]["on"])):
			_set_down(it, set_down_spot(0, id, true))
